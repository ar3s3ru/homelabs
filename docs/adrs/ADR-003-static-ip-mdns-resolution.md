# Static IP Allocation with mDNS and Unicast `.lan.cianfr.one` Resolution

## Context and Problem Statement

Homelab nodes (`nl-k8s-01..04`) currently obtain their IP addresses from the Mikrotik (RouterOS) DHCP server via static MAC-based reservations. ADR-002 (written for OpenWrt/dnsmasq) framed DHCP as a convenient *coordination point* for hostname-to-IP mapping, with DNS records derived from active leases. That framing was already a stretch — DHCP cannot be a real source of truth, since the assignment depends on the client showing up with a recognized identifier — but on Mikrotik the gap between "convenient coordination point" and "actually reliable" is wider than ADR-002 anticipated, for two compounding reasons:

1. **MAC-address instability**. NICs are not stable identifiers:
   - VMs on Proxmox can change MAC if the VM is recreated or the bridge config is altered.
   - Some baremetal NICs randomize MAC on certain firmware paths or after BIOS updates.
   - USB NICs (e.g. on `nl-k8s-01`) are particularly fragile here.
   When the MAC changes, the static lease no longer matches and the node receives a fallback dynamic address — exactly the failure mode that triggered [INC-0003](../postmortems/INC-0003-kubernetes-cluster-down-dhcp-arp-conflict.md).

2. **RouterOS does not natively translate DHCP leases into DNS entries**. Unlike dnsmasq (which integrates DHCP and DNS in a single process and creates A records automatically as leases bind), Mikrotik's DHCP server and DNS server are separate subsystems with no built-in linkage. The only way to get `<host>.home.arpa` resolvable from a DHCP lease is to run a custom RouterOS script (typically on `dhcp-server lease-script` or scheduled) that scrapes leases and writes `/ip dns static` entries. In practice this script is fragile: it races with lease renewals, doesn't always clean up stale entries, and silently fails on edge cases (lease expiry vs. static binding semantics, hostname containing characters Mikrotik rejects, etc.). The current setup exhibits this today — A/AAAA queries for some node FQDNs intermittently return NXDOMAIN even while the lease is bound and the node is online.

Combined, these mean the existing setup is unreliable in two independent dimensions: the IP assignment itself can drift (problem 1), and even when it doesn't, the DNS view of it can be wrong (problem 2). INC-0003 already prescribed migrating infrastructure nodes to static IPs, but that migration was reverted at some point and not documented. Each `machines/nl-k8s-XX/networking.nix` still carries a commented-out static-IP block as a relic. This ADR commits to the static-IP approach again, and pairs it with a deliberate name-resolution strategy so that node identity is no longer dependent on either DHCP lease binding or a brittle Mikrotik script.

### Key questions

- How do nodes get a stable, declarative IP without depending on DHCP?
- How do other devices on the LAN discover and reach those nodes by name?
- What unicast namespace becomes the canonical FQDN for k3s flags (`--tls-san`, `--server`), SSH targets, and other infrastructure consumers, given the existing `.home.arpa` references?
- Where is the source of truth for IP↔hostname, given we want to avoid drift?

## Decision Drivers

- **Resilience**: Node identity must not depend on a DHCP lease binding. Cluster must survive a router reboot or a NIC MAC change.
- **Single source of truth**: One place in the repo defines `nl-k8s-XX → IPv4/IPv6/iface`. Every consumer (Colmena `targetHost`, k3s `--node-ip`, OS interface config, future Mikrotik DNS provisioning) derives from it.
- **Automatic LAN discovery**: New devices on the network (or my laptop after a reboot) should resolve `nl-k8s-XX` without me touching the router.
- **Bounded migration cost**: Existing `.home.arpa` references (k3s `serverAddr`, `--tls-san`, `truenas.home.arpa` in `kube/`) are touchpoints to consider; bulk surgery on all of them at once is undesirable. Cluster-init (`nl-k8s-01`) regenerating its server certificate is acceptable; mass cert/PV rewrite in the same change is not.
- **Operational simplicity for now**: 4 nodes — manual Mikrotik DNS entries are acceptable. Automation comes later.
- **Safe rollout**: Tailscale tailnet remains as out-of-band access during migration.

## Considered Options

1. **Pure mDNS (`.local` only)** — drop `.home.arpa`, rewrite k3s flags, regenerate certs.
2. **Unicast-only on Mikrotik with `.home.arpa`** — static IPs on the OS, hostname only via Mikrotik static DNS, no mDNS.
3. **Hybrid: mDNS for `.local` + unicast Mikrotik DNS for `.home.arpa`**.
4. **Stay on DHCP static leases** — status quo, accepted in ADR-002.
5. **Single namespace under owned domain (`<host>.lan.cianfr.one`)** — static IPs on the OS, all hostnames as a subdomain of an owned public domain served via Mikrotik static DNS (split-horizon). No mDNS.
6. **Hybrid: mDNS for `.local` + unicast `<host>.lan.cianfr.one`** — same as Option 3 but the unicast namespace becomes a subdomain of an owned public domain instead of `.home.arpa`. ✅ Chosen.

## Decision Outcome

Chosen option: **"Option 6: Hybrid mDNS + Unicast `<host>.lan.cianfr.one`"**. It gives automatic LAN discovery via mDNS (`<host>.local`) while moving the canonical FQDN to a subdomain of an already-owned public domain, served via Mikrotik static DNS (split-horizon: Mikrotik authoritative locally, public DNS silent for `lan.cianfr.one`).

The two namespaces live side-by-side and serve different roles:

- `<host>.local` — multicast, automatic, opportunistic, used by humans and zero-config tooling on the LAN.
- `<host>.lan.cianfr.one` — unicast, deterministic, used by infrastructure (k3s `--server`, `--tls-san`, scripts).

`.local` is the correct (and only) namespace per [RFC 6762](https://datatracker.ietf.org/doc/html/rfc6762) for multicast DNS; using a subdomain of an owned public domain for the unicast suffix is the long-standing best practice (Microsoft / ICANN guidance for new AD/Entra-ID deployments, mirrored in [the Veeam community piece](https://community.veeam.com/blogs-and-podcasts-57/why-using-local-as-your-domain-name-extension-is-a-bad-idea-4828)) and avoids the foot-guns of repurposing reserved TLDs for unicast use.

Why Option 6 over Option 3 (`.home.arpa` instead of `.lan.cianfr.one`):

- The unicast suffix change is mechanically simple in this homelab. Only k3s server certificates and `services.k3s.serverAddr` actually carry the suffix; `truenas.home.arpa` references in `kube/` PVs can be kept resolvable via Mikrotik static DNS during rollout and migrated in a follow-up.
- k3s server certificates auto-regenerate when `--tls-san` changes and the server is restarted (`/var/lib/rancher/k3s/server/tls/dynamic-cert.json` driven by the configured SANs).
- Single namespace beats two namespaces for cognitive load and tooling reliability — `.home.arpa` and `.lan.cianfr.one` are equally valid technically; the latter is just more conventional and unlocks future options.
- Unlocks publicly-trusted TLS for internal services (Let's Encrypt DNS-01 against the public `cianfr.one` zone) as a future improvement. Nice-to-have, not a goal of this ADR; mTLS for internal services remains the primary TLS goal and is hostname-suffix-agnostic.

`cianfr.one` is already owned and operational: `cloudflare-ddns` syncs the public IP to `in.nl.cianfr.one`, `external-dns` creates CNAMEs to that record from nginx ingresses. `lan.cianfr.one` becomes a new sibling subdomain served only locally (split-horizon).

### Addressing decisions

- **Stay on `10.0.1.0/24`** with `/16` netmask. ADR-001 plans `10.10.0.0/16` for the infra zone but reality is `10.0.1.X`. Realignment is deferred to a separate migration to keep this change focused and reversible.
- **IPv6**: keep ULA `fd00:cafe::1:X/64` static on the OS for predictable internal addressing (used by k3s `--node-ip`); leave Router Advertisements enabled so SLAAC GUA + link-local addresses still flow from Mikrotik. Per-interface `accept_ra=2` is required because k3s enables IP forwarding, which would otherwise cause the kernel to drop RAs.
- **Interfaces** retain their existing per-machine names (`enp0s20f0u1`, `ens18`, `enp0s31f6`). NIC renames are a separate problem; addressing them now would expand the blast radius.
- **Source of truth**: a `hosts` attrset centralized in `machines/default.nix` (or a sibling module), plumbed to each machine via `specialArgs`. Eliminates the duplication that exists today between `deployment.targetHost`, `--node-ip`, `--tls-san`, and the (commented) static interface block.
- **Domain string**: also centralized — `domain = "lan.cianfr.one"` in the same module, consumed by k3s flags and `networking.domain`.

### Resolution stack on each node

- `systemd-resolved` enabled with `MulticastDNS=resolve`, `LLMNR=no`, `DNSSEC=no`. Upstream is the Mikrotik (`10.0.0.1`).
- `avahi` enabled and bound only to the LAN interface (so `.local` is not published on `tailscale0`, `cni0`, `flannel.1`, `cilium_*`, etc.).
- `nss-mdns` (v4 + v6) enabled as a fallback path for tools that don't speak resolved.
- `networking.search = [ "lan.cianfr.one" ]` — bare `nl-k8s-02` resolves to `nl-k8s-02.lan.cianfr.one` via unicast.

### Mikrotik DNS

- `<host>.lan.cianfr.one` A and AAAA records added manually to `/ip dns static` (8 entries: 4× A + 4× AAAA for the cluster nodes). Snapshot of the resulting config exported to `networking/rb5009upr/snapshots/`.
- Existing `truenas.home.arpa` (and any other `*.home.arpa` references currently in `kube/`) are kept in Mikrotik static DNS during this migration. Migration of those records to `.lan.cianfr.one` is tracked as a follow-up — out of scope here.
- Public DNS for `cianfr.one` (Cloudflare) is **not** updated to publish `lan.cianfr.one` — Mikrotik is locally authoritative; from outside the LAN those names return NXDOMAIN. This is the split-horizon arrangement.
- DHCP static leases for the four k8s nodes are removed, since they no longer request DHCP.
- Future automation via `terraform-routeros` driven by the same Nix `hosts` attrset is left as a follow-up.

### Consequences

#### Positive

- Node identity becomes self-contained — survives router reboots, NIC MAC changes, and DHCP failures.
- Single source of truth for addressing and domain in `machines/default.nix`. Adding a node = one diff.
- Automatic LAN discovery via `<host>.local` for ad-hoc clients.
- Canonical FQDN under an owned, globally-unique namespace — eliminates RFC-collision and tooling-edge-case concerns of reserved TLDs.
- Unlocks future publicly-trusted TLS for internal services (Let's Encrypt DNS-01 against `cianfr.one`) without further DNS-side changes — only cert-manager / Cloudflare-credential plumbing.
- Eliminates the class of failure described in INC-0003 (DHCP DECLINE → fallback dynamic IP → cluster split-brain).
- IPv6 dual-addressing (static ULA + RA-derived SLAAC GUA) preserves both internal stability and external reachability.

#### Negative

- Manual maintenance of Mikrotik static DNS entries — 8 records for the cluster nodes plus existing `truenas.home.arpa` retained during transition. Mitigated by being a one-time operation; future automation tracked as a follow-up.
- mDNS adds a new failure surface (multicast traffic, avahi reflection, interface bindings). Mitigated by binding avahi to a single interface and explicit verification steps in rollout.
- Two parallel name systems (`.local` for mDNS, `.lan.cianfr.one` for unicast). Tooling and humans need to know which to use. Mitigated via documentation in `AGENTS.md`.
- Domain ownership becomes load-bearing for cluster identity. Lapsed registration or Cloudflare account loss → `lan.cianfr.one` references break (LAN-side resolution still works since Mikrotik is locally authoritative; the dependency is on the parent zone's continued ownership). Mitigated by the existing infra already depending on `cianfr.one` (cloudflare-ddns, external-dns), so this is not a *new* dependency.
- Migration churn beyond network config: k3s server certificates regenerate (verified-trivial: just remove and restart), `--tls-san` updated in two places, `services.k3s.serverAddr` updated in two places, kubeconfig server URL updated for the user.
- Drift from ADR-001 (still `10.0.1.X` instead of `10.10.0.X`) is preserved, not fixed.

#### Neutral

- Tailscale MagicDNS continues to provide a third namespace (`<host>.tail2ff90.ts.net`). That's by design — out-of-band access.
- ADR-002 becomes effectively superseded by this ADR for infrastructure nodes; client devices may still use DHCP-with-leases and the OpenWrt-era reasoning in ADR-002 no longer applies on Mikrotik anyway.
- `truenas.home.arpa` and other `*.home.arpa` consumers in `kube/` keep working unchanged for the duration of the migration; they get retired in a separate follow-up.

### Confirmation

**Validation plan** — for each node, after the migration:

1. `ip -4 addr show <iface>` reports only the static `10.0.1.X/16` (no DHCP lease line).
2. `ip -6 addr show <iface>` reports both the static ULA `fd00:cafe::1:X/64` **and** an RA-derived SLAAC address with a non-zero valid lifetime.
3. `ip route` shows default via `10.0.0.1`; `ip -6 route` shows a default via the Mikrotik link-local.
4. `resolvectl status <iface>` shows `MulticastDNS: resolve`, `LLMNR: no`, `Current DNS Server: 10.0.0.1`.
5. From another node: `getent hosts nl-k8s-XX.local` returns `10.0.1.X` (mDNS path).
6. From any LAN client: `dig nl-k8s-XX.lan.cianfr.one @10.0.0.1` returns both A and AAAA (unicast path).
7. From outside the LAN (e.g. a workstation off-tailnet using public resolvers): `dig nl-k8s-XX.lan.cianfr.one` returns NXDOMAIN — confirms split-horizon is working.
8. `avahi-browse -art` from another LAN host shows each node exactly once, with only its LAN IP — not pod or tailnet addresses.
9. `kubectl get nodes -o wide` reports all four nodes `Ready` with their expected `INTERNAL-IP`.
10. `openssl s_client -connect nl-k8s-01.lan.cianfr.one:6443 -showcerts </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 'Subject Alternative Name'` lists `nl-k8s-01.lan.cianfr.one` (and `nl-k8s-01`) — confirms cert regeneration picked up the new SAN.
11. `truenas.home.arpa` still resolves and NFS PVs in the cluster keep mounting — confirms the legacy `.home.arpa` references are unaffected.
12. SSH by short name (`ssh root@nl-k8s-02`), by `.local`, by `.lan.cianfr.one`, and by tailnet name all succeed.

**Success criteria**:

- Cluster remains operational throughout migration, one node at a time.
- After a Mikrotik reboot, all four nodes remain reachable by both `.local` and `.lan.cianfr.one` immediately, with no DHCP renewal needed.
- Removing all four static leases from the Mikrotik DHCP server has no effect on cluster health.
- Existing `*.home.arpa` references continue working until they are migrated in a follow-up.

## Pros and Cons of the Options

### Note on `.local` vs. owned-domain critiques

A common critique (popularised in posts like [this Veeam community piece](https://community.veeam.com/blogs-and-podcasts-57/why-using-local-as-your-domain-name-extension-is-a-bad-idea-4828)) is that `.local` is "a bad idea" for internal naming and that a subdomain of an owned public domain is the best practice. That argument conflates two distinct uses of `.local`:

- **(A) `.local` as a *unicast* DNS suffix** — i.e. configuring an internal recursive resolver to be authoritative for a `.local` zone, AD-style. **This is genuinely a bad idea**: it collides with mDNS, breaks Avahi/Bonjour expectations, and triggers RFC 6762 §3 / §4 conflict-resolution behaviour on any client that implements mDNS correctly.
- **(B) `<host>.local` as an *mDNS-published* hostname** — i.e. avahi answering multicast queries on `224.0.0.251` / `ff02::fb` for the `.local` namespace. **This is exactly what RFC 6762 specifies `.local` is for**, and is standards-compliant.

The hybrid options below (3 and 6) only ever use `.local` for case (B). Mikrotik is *not* asked to serve unicast `.local` records, and `.local` is *not* added to `networking.search`. The Veeam-article concerns therefore mostly apply to *AD-style* misuse, not to the configuration proposed here. They remain partially relevant — see "Bad, because tooling occasionally treats `.local` specially" in the option scorings — but they do not invalidate the hybrid approach.

The owned-domain alternative (Options 5 and 6, `<host>.lan.cianfr.one`) is still genuinely interesting on its own merits, mainly because it is the only path that allows publicly-trusted TLS certificates for internal services. It is scored separately below.

### Option 1: Pure mDNS (`.local` only)

- Good, because automatic discovery without any router-side configuration.
- Good, because eliminates dependency on Mikrotik DNS for internal naming.
- Bad, because requires rewriting `services.k3s.serverAddr`, `--tls-san`, and regenerating k3s server certs. Invasive.
- Bad, because `.local` doesn't traverse all paths reliably — multicast can be filtered on certain VLAN setups, sleeping macOS clients miss queries, some Linux distros disable mDNS by default.
- Bad, because Tailscale and other tooling sometimes treat `.local` as a special case.
- Bad, because public-trust TLS for internal services is impossible (no CA will issue for `.local`).

### Option 2: Unicast-only on Mikrotik with `.home.arpa`

- Good, because simplest possible setup; functionally equivalent to today after switching to OS-static IPs.
- Good, because no new daemons (no avahi, no resolved tweaks).
- Good, because RFC 8375 reserves `.home.arpa` precisely for this use → no collision risk now or in the future.
- Bad, because every new device requires a manual Mikrotik DNS entry — same drawback that motivated ADR-002 in the first place.
- Bad, because no automatic discovery for ad-hoc clients (laptop on guest VLAN, ephemeral debug VM, etc.).
- Bad, because public-trust TLS is impossible (`.home.arpa` is forbidden from public CA issuance per RFC 8375 + CA/Browser Forum baseline requirements).

### Option 3: Hybrid mDNS + Unicast `.home.arpa`

- Good, because preserves `.home.arpa` as canonical FQDN — zero changes to k3s config, SSH habits, certificates.
- Good, because adds automatic LAN discovery via `.local` without sacrificing the unicast path.
- Good, because both namespaces fail independently: if mDNS breaks, unicast still works (and vice versa).
- Good, because matches RFC 8375 (`.home.arpa` for unicast home networks) and RFC 6762 (`.local` for mDNS) intent — uses each namespace exactly as the RFCs prescribe.
- Good, because no domain-ownership dependency: nothing breaks if `cianfr.one` ever lapses or is transferred.
- Neutral, because requires one-time manual setup of Mikrotik static DNS entries and one new shared NixOS module for avahi/resolved.
- Bad, because two namespaces for the same hosts can confuse newcomers — must be documented.
- Bad, because mDNS adds a new failure surface (interface-binding hygiene, multicast pollution on CNI/tailnet interfaces).
- Bad, because public-trust TLS for internal services is impossible (neither `.local` nor `.home.arpa` qualifies). Internal mTLS is unaffected — that path uses our own CA regardless of the hostname suffix — but a future "browser-trusted Grafana on the LAN" use case is closed off without further work.

### Option 4: Stay on DHCP Static Leases (status quo)

- Good, because no migration cost.
- Bad, because INC-0003 root cause remains live: NIC MAC change → no static lease match → fallback dynamic IP → cluster failure.
- Bad, because hostname resolution depends on lease activity after router reboot.
- Bad, because Mikrotik does not natively translate DHCP leases into DNS entries (requires a fragile lease-script; see Context).

### Option 5: Single namespace `<host>.lan.cianfr.one`

`cianfr.one` is already owned and operational — currently used for internet-facing services (`cloudflare-ddns` syncs the public IP to `in.nl.cianfr.one`, `external-dns` creates CNAMEs to that record from nginx ingresses). A `lan.cianfr.one` subdomain would be served only by Mikrotik for LAN clients (split-horizon), with public DNS either omitting it entirely or returning private IPs (a debate of its own — see "Note on split-horizon" below).

- Good, because a single namespace covers every host from every context — lowest cognitive load.
- Good, because globally unique by construction; zero collision risk now or ever.
- Good, because **publicly-trusted TLS certificates can be issued for `*.lan.cianfr.one` via Let's Encrypt DNS-01** against the public `cianfr.one` zone. This is the headline differentiator vs. all `.home.arpa`/`.local` options. (The user has flagged this as a *nice-to-have, not a must-have*; mTLS for internal services is the real goal and is independent of the hostname suffix — so this advantage is real but not decisive.)
- Good, because no mDNS protocol surface → no avahi/interface-binding hazards.
- Good, because aligns with the article's recommended best practice ("subdomain of a domain you own") and with current Microsoft / ICANN guidance for new AD/Entra-ID deployments.
- Neutral, because requires one Mikrotik static DNS entry per host (same operational cost as Option 3 for the unicast layer).
- Bad, because **migration cost is higher than Option 3**: rewrite `services.k3s.serverAddr`, all `--tls-san` flags, `networking.domain`; re-issue k3s server certificates; risk of an etcd member rotation if mishandled.
- Bad, because no automatic LAN discovery for ad-hoc clients — adding a device requires editing Mikrotik DNS.
- Bad, because domain ownership becomes load-bearing for cluster operation. A lapsed registration or DNS provider outage at `cianfr.one`'s authoritative side could affect public-facing resolution of `lan.cianfr.one` from outside the LAN. Internal LAN resolution remains independent (Mikrotik is authoritative for the subdomain locally) — but this needs to be designed in, not assumed.
- Bad, because either we publish `lan.cianfr.one` records publicly (leaks internal hostnames, undesirable) or we maintain a true split-horizon setup (Mikrotik authoritative for `lan.cianfr.one`, public DNS silent) — the latter is more configuration than today's `.home.arpa` story.
- Bad, because TLS-by-name for internal services would require a non-trivial cert-distribution path (Let's Encrypt DNS-01 against Cloudflare → cert-manager → workloads), which is itself an additional moving piece. Not done as part of this ADR's scope; just an option this ADR keeps open.

### Option 6: Hybrid mDNS + Unicast `<host>.lan.cianfr.one` ✅ Chosen

Same architecture as Option 3, but with `.lan.cianfr.one` substituted for `.home.arpa` on the unicast side. mDNS publishes `<host>.local` as in Option 3.

- Good, because keeps automatic LAN discovery via mDNS (Option 3's biggest pro).
- Good, because the unicast suffix lives under an already-owned, globally-unique namespace — no reliance on reserved-TLD semantics, no risk of future RFC churn.
- Good, because keeps the namespace-independence property: mDNS and unicast can fail independently.
- Good, because unlocks publicly-trusted TLS for internal services (Let's Encrypt DNS-01 against `cianfr.one`) — not a goal for this ADR, but the option is preserved at zero additional cost.
- Good, because aligns with the conventional best practice ("subdomain of a domain you own") flagged in the Veeam article and current Microsoft / ICANN guidance.
- Neutral, because requires both the avahi/resolved module (Option 3) and the split-horizon DNS setup (Option 5).
- Bad, because migration touches k3s server certificates and `services.k3s.serverAddr`. Mitigated: k3s regenerates server certs automatically when `--tls-san` changes and the server is restarted.
- Bad, because introduces a domain-ownership dependency for cluster identity. Mitigated: existing cluster infra (cloudflare-ddns, external-dns) already depends on `cianfr.one` continuing to be owned and reachable, so this is not a *new* dependency.
- Bad, because is the most configuration-heavy of the six options — every concern of 3 and 5 combined.

### Why Option 6 over Option 3 (the closest alternative)

Option 6 differs from Option 3 only in the unicast suffix (`.lan.cianfr.one` vs. `.home.arpa`). Trade-off summary:

| Axis | Option 3 (`.home.arpa`) | Option 6 (`.lan.cianfr.one`) |
|---|---|---|
| Migration cost | Lower (no k3s cert change, just static DNS entries) | Higher (k3s server cert regenerates, `--tls-san` and `serverAddr` updates) |
| Namespace ownership | RFC-reserved | Globally owned |
| Public-trust TLS for internal services | Impossible | Possible (future improvement) |
| Domain-ownership dependency | None | Yes — but already present in repo (`cloudflare-ddns`, `external-dns`) |
| Tooling edge cases | `.home.arpa` is well-handled but obscure; some tools still ignore it | Conventional, no edge cases |

Option 6 is chosen because:

- The migration cost is real but bounded: only `services.k3s.serverAddr`, `--tls-san`, and `networking.domain` change. The cluster init node (`nl-k8s-01`) regenerates server certificates automatically on restart with the new SAN; no manual cert surgery required.
- `truenas.home.arpa` and other `*.home.arpa` references in `kube/` PVs are kept resolvable on Mikrotik during the transition, so the migration does not block on retiring those names.
- The domain-ownership dependency is already implicit in the cluster's ingress story; making it explicit for cluster identity does not add a new failure mode.
- Public-trust TLS is preserved as a future capability at no additional ADR-level cost.

## Implementation Plan

The migration is broken into seven phases. Each phase is independently reversible up to phase 6.

### Phase 0 — Pre-migration safety

1. Export current Mikrotik DHCP and DNS state as a `.rsc` snapshot, commit to `networking/rb5009upr/snapshots/pre-static-ip-migration.rsc`.
2. Verify out-of-band paths:
   - SSH by IP (`ssh root@10.0.1.X`) works for all four nodes.
   - SSH via Tailscale tailnet works for all four nodes.
3. Verify cluster baseline: `kubectl --context=nl get nodes -o wide` shows four `Ready` nodes with expected `INTERNAL-IP` values.

### Phase 1 — Centralize the host registry

1. Add a `hosts` attrset in `machines/default.nix` (or a new `machines/hosts.nix` imported from `default.nix`):

   ```nix
   hosts = {
     nl-k8s-01 = { ipv4 = "10.0.1.1"; ipv6 = "fd00:cafe::1:1"; iface = "enp0s20f0u1"; };
     nl-k8s-02 = { ipv4 = "10.0.1.2"; ipv6 = "fd00:cafe::1:2"; iface = "ens18";       };
     nl-k8s-03 = { ipv4 = "10.0.1.3"; ipv6 = "fd00:cafe::1:3"; iface = "ens18";       };
     nl-k8s-04 = { ipv4 = "10.0.1.4"; ipv6 = "fd00:cafe::1:4"; iface = "enp0s31f6";   };
   };
   gateway = { ipv4 = "10.0.0.1"; };
   domain  = "lan.cianfr.one";
   ```

2. Pass `hosts`, `gateway`, `domain` into per-machine modules via Colmena `specialArgs` (or via the existing `inputs@{ ... }: { ... }: { ... }` plumbing). Each `machines/nl-k8s-XX/default.nix` reads its own record:

   ```nix
   { hosts, gateway, domain, ... }: { ... }:
   let host = hosts.${config.networking.hostName}; in
   {
     deployment.targetHost = host.ipv4;
     networking.domain = domain;
     services.k3s.extraFlags = lib.mkAfter [
       "--node-ip=${host.ipv4},${host.ipv6}"
       # Only on nl-k8s-01:
       "--tls-san=${config.networking.hostName}.${domain}"
     ];
     ...
   }
   ```

3. Update the join targets to use `domain` from the registry. Two files carry the hardcoded `nl-k8s-01.home.arpa:6443`:
   - `modules/k3s/server-join.nix`: `services.k3s.serverAddr = "https://nl-k8s-01.${domain}:6443";`
   - `modules/k3s/agent.nix`: same change.

   Both modules need to receive `domain` via the same `specialArgs` plumbing (or via a sibling `lib` exposing it).

4. Build-only check: `nix flake check` (and a Colmena dry-run if available) to confirm evaluation succeeds. **No deploy yet.**

### Phase 2 — New shared module: static IP configuration

1. Create `modules/networking-static.nix`:

   ```nix
   { hosts, gateway, domain, ... }: { config, lib, ... }:
   let host = hosts.${config.networking.hostName}; in
   {
     networking.useDHCP = lib.mkForce false;

     networking.interfaces.${host.iface} = {
       useDHCP = false;
       ipv4.addresses = [{ address = host.ipv4; prefixLength = 16; }];
       ipv6.addresses = [{ address = host.ipv6; prefixLength = 64; }];
     };

     networking.defaultGateway = {
       address = gateway.ipv4;
       interface = host.iface;
     };

     # Keep RA on for SLAAC GUA + link-local.
     # accept_ra=2 is required because k3s enables forwarding.
     boot.kernel.sysctl = {
       "net.ipv6.conf.${host.iface}.accept_ra" = 2;
       "net.ipv6.conf.${host.iface}.autoconf"  = 1;
     };

     networking.nameservers = [ gateway.ipv4 ];
     # `domain` is fed via specialArgs alongside `hosts` and `gateway`.
     networking.search = [ domain ];
   }
   ```

2. Each `machines/nl-k8s-XX/networking.nix` is replaced with a thin wrapper that imports the shared module (or removed entirely, with the import moved into `machines/nl-k8s-XX/default.nix`). The commented-out historical block is deleted.

3. Build-only check.

### Phase 3 — New shared module: mDNS publish + resolve

1. Create `modules/mdns.nix`:

   ```nix
   { hosts, domain, ... }: { config, ... }:
   let host = hosts.${config.networking.hostName}; in
   {
     services.avahi = {
       enable = true;
       nssmdns4 = true;
       nssmdns6 = true;
       interfaces = [ host.iface ];   # avoid publishing on tailscale0/cni0/flannel.1
       publish = {
         enable = true;
         addresses = true;
         domain = true;
         hinfo = false;
         userServices = false;
         workstation = false;
       };
       openFirewall = true;            # opens UDP 5353
     };

     services.resolved = {
       enable = true;
       extraConfig = ''
         MulticastDNS=resolve
         LLMNR=no
         DNSSEC=no
         Domains=lan.cianfr.one ~.
       '';
     };
   }
   ```

   The `Domains=lan.cianfr.one ~.` line tells systemd-resolved that the upstream Mikrotik resolver is the preferred answerer for `lan.cianfr.one` (and `~.` makes it the default fallback for everything else, since it's our only DNS). This stays intentional split-horizon — `lan.cianfr.one` queries leave the node only on the `10.0.0.1` lookup, never to public DNS.

2. Import `modules/mdns.nix` from `modules/server.nix` so all servers in the homelab inherit it.

3. Build-only check.

### Phase 4 — Mikrotik unicast DNS

Manual, on the RouterBoard, **before** any OS-side deploy in Phase 6:

```routeros
/ip dns static
add name=nl-k8s-01.lan.cianfr.one address=10.0.1.1 type=A
add name=nl-k8s-02.lan.cianfr.one address=10.0.1.2 type=A
add name=nl-k8s-03.lan.cianfr.one address=10.0.1.3 type=A
add name=nl-k8s-04.lan.cianfr.one address=10.0.1.4 type=A
add name=nl-k8s-01.lan.cianfr.one address=fd00:cafe::1:1 type=AAAA
add name=nl-k8s-02.lan.cianfr.one address=fd00:cafe::1:2 type=AAAA
add name=nl-k8s-03.lan.cianfr.one address=fd00:cafe::1:3 type=AAAA
add name=nl-k8s-04.lan.cianfr.one address=fd00:cafe::1:4 type=AAAA
```

Existing `*.home.arpa` entries (`truenas.home.arpa` and any other consumed by `kube/`) are **left in place**. They keep working unchanged for the duration of this migration; retiring them is tracked as a follow-up.

Verify:

- `dig nl-k8s-04.lan.cianfr.one @10.0.0.1` returns `10.0.1.4` and the AAAA record from inside the LAN.
- `dig nl-k8s-04.lan.cianfr.one @1.1.1.1` returns NXDOMAIN — confirms split-horizon: public DNS is silent for `lan.cianfr.one`.
- `dig truenas.home.arpa @10.0.0.1` still resolves — confirms the legacy entries are preserved.
- `/ip dns set allow-remote-requests=yes` is still set.
- Save running config; export to `networking/rb5009upr/snapshots/post-static-dns-migration.rsc`.

### Phase 5 — DHCP cleanup on Mikrotik (deferred until after Phase 6 completes)

1. Remove static leases for `nl-k8s-01..04` from `/ip dhcp-server lease`.
2. Either exclude `10.0.1.0/24` from the dynamic DHCP pool, or shrink the pool so `.1.1..1.4` are not handed to other devices.
3. If a custom DHCP-lease-to-DNS script is in place on the router, either remove its handling for the cluster nodes or retire it entirely. Verify no leftover stale `/ip dns static` entries remain for `nl-k8s-XX.home.arpa` (replaced by the `.lan.cianfr.one` entries populated in Phase 4) and that the eight `nl-k8s-XX.lan.cianfr.one` entries are the only authoritative ones for these nodes.

### Phase 6 — Per-node rollout

Order: **`nl-k8s-04` → `nl-k8s-03` → `nl-k8s-02` → `nl-k8s-01`** (init node last). Init node has the lowest tolerance for failure during migration; deploying it last means we have three healthy migrated peers to fall back on.

For each node:

1. `nix run github:zhaofengli/colmena -- apply --on <node>`.
2. Validate the checklist from "Confirmation" (sections 1–12) on the freshly migrated node.
3. From a different node, validate `.local` resolution and avahi browse output.
4. From the migrated node, validate `kubectl get nodes -o wide` and that flannel/etcd peers are still healthy.
5. If any check fails: revert via `git revert` + `colmena apply --on <node>` over Tailscale; the previous DHCP-based config returns the node to the prior working state.

After deploying `nl-k8s-01` (the init node), the k3s server's serving certificate must reflect the new `--tls-san=nl-k8s-01.lan.cianfr.one` SAN. k3s regenerates the dynamic serving cert on the next server start when SAN list changes:

1. After Colmena applies the new config, the systemd unit restarts k3s automatically.
2. Verify the SAN with `openssl s_client -connect nl-k8s-01.lan.cianfr.one:6443 -showcerts </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName` — expect `DNS:nl-k8s-01.lan.cianfr.one`.
3. If the SAN is still missing (e.g. the dynamic cert was cached from before): `rm /var/lib/rancher/k3s/server/tls/dynamic-cert.json` on `nl-k8s-01` and `systemctl restart k3s`. k3s rebuilds the dynamic cert from the current SAN list on next start.
4. Update local kubeconfig server URL on the user workstation: `kubectl config set-cluster nl --server=https://nl-k8s-01.lan.cianfr.one:6443` (the cluster CA is unchanged — k3s only regenerates the *serving* cert, not the CA — so existing client credentials remain valid).
5. Existing join nodes (`nl-k8s-02..04`) already point at `https://nl-k8s-01.${domain}:6443` via the centralized `domain` variable; their `--server` URL is updated by the same Colmena rollout, no manual action needed.

After all four nodes are migrated and verified, proceed to Phase 5.

### Phase 7 — Documentation

1. Mark **ADR-002** as `Status: Superseded by ADR-003` for infrastructure nodes (its OpenWrt/dnsmasq context no longer applies on Mikrotik).
2. Add a note to **ADR-001** that current addressing is `10.0.1.0/24` (drift from the planned `10.10.0.0/16`); flag the realignment as a separate, future migration.
3. Create `docs/runbooks/add-new-node-to-lan.md` describing the steps to add a fifth node:
   - Append to the `hosts` attrset.
   - Add A + AAAA entries on Mikrotik for `<host>.lan.cianfr.one`.
   - Run `colmena apply --on <new-node>`.
4. Update `AGENTS.md` SSH section to mention all four name paths (`<short>`, `<short>.local`, `<short>.lan.cianfr.one`, `<short>.tail2ff90.ts.net`) and which is appropriate when.
5. Add a follow-up tracking item: migrate remaining `*.home.arpa` references in `kube/` (NFS PVs for `truenas`, Longhorn backup target) to `*.lan.cianfr.one`. Out of scope here — gets its own small ADR or runbook.

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Wrong static IP/netmask isolates node from LAN | Medium | Tailscale SSH still reaches the node; rollback via `colmena apply` over tailnet. |
| mDNS publishing on CNI/flannel/tailscale interfaces, polluting `.local` | High if not constrained | Bind avahi to `host.iface` only via `services.avahi.interfaces`. Verify with `avahi-browse -art`. |
| `.lan.cianfr.one` resolution breaks because Mikrotik static DNS not populated | Medium | Phase 4 happens **before** Phase 6. Verify with `dig` from a workstation before deploying any node. |
| `accept_ra` reset to default after k3s enables forwarding, SLAAC GUA disappears | Medium | Per-interface `accept_ra=2`. Verify both ULA and SLAAC are present after deploy. |
| ARP conflict reminiscent of INC-0003 | Low | IPs unchanged from current — only ownership moves from DHCP to OS. One node at a time. Verify Mikrotik ARP table after each. |
| k3s server cert does not pick up new SAN, join nodes fail TLS validation against `nl-k8s-01.lan.cianfr.one` | Medium | Verify SAN with `openssl s_client` after `nl-k8s-01` deploy (Phase 6 step 2). If missing, delete `dynamic-cert.json` and restart k3s. Tailscale tailnet remains as an out-of-band path while the cluster reconciles. |
| Cross-cluster join fails because `serverAddr` resolution stops working before TLS SAN updates | Medium | Roll out join nodes (`02..04`) **before** `nl-k8s-01`, so they still trust the old cert against the new hostname during their own deploy (DNS for both old `.home.arpa` entries — if still present — and new `.lan.cianfr.one` entries resolves). Final `nl-k8s-01` deploy is the cert switch. |
| `*.home.arpa` references in `kube/` PVs break before follow-up migration | Low | Mikrotik retains the `truenas.home.arpa` static entry through this migration; nothing in this ADR removes it. |
| `nss-mdns` and `systemd-resolved` interact poorly, causing slow lookups | Low | If observed, drop `nssmdns4/6` and rely on resolved alone. Easy to back out. |
| `cianfr.one` registration lapses → `lan.cianfr.one` LAN-side resolution unaffected, but conceptually the cluster's identity becomes orphaned | Very Low | Existing infra (cloudflare-ddns, external-dns) already depends on the registration. Domain renewal is a single payment that protects the whole stack, not just this ADR. |

## Out of Scope

- Realigning IPs to `10.10.0.0/16` per ADR-001 (separate migration).
- Provisioning Mikrotik static DNS via `terraform-routeros` driven by the Nix host registry (mechanical follow-up once the manual list is stable).
- Adding mDNS / static IPs to non-k8s machines (Proxmox hosts, NAS, switches).
- Migrating client devices (phones, laptops, IoT) off DHCP — they should keep using DHCP with leases.
- Migrating remaining `*.home.arpa` references in `kube/` (e.g. `truenas.home.arpa` in NFS PVs and Longhorn backup target) to `*.lan.cianfr.one`. Tracked as a follow-up; entries stay in Mikrotik DNS until then.
- Configuring publicly-trusted TLS certificates for internal services via Let's Encrypt DNS-01 against `cianfr.one`. Enabled by Option 6 but not implemented here; gets its own ADR/runbook when the need arises.

## Additional Links

- [ADR-001 Network Architecture](./ADR-001-network-architecture.md)
- [ADR-002 DHCP/DNS Configuration Strategy](./ADR-002-dhcp-dns-configuration-strategy.md) (Superseded by this ADR for infrastructure nodes)
- [INC-0003 DHCP ARP Conflict](../postmortems/INC-0003-kubernetes-cluster-down-dhcp-arp-conflict.md)
- [RFC 6762 — Multicast DNS](https://datatracker.ietf.org/doc/html/rfc6762)
- [RFC 8375 — `.home.arpa` Domain Name Reservation](https://datatracker.ietf.org/doc/html/rfc8375)
