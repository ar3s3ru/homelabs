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

- `<host>.lan.cianfr.one` A and AAAA records added manually to `/ip dns static` on the RB5009 (8 entries: 4× A + 4× AAAA for the cluster nodes). Snapshot of the resulting config exported to `networking/rb5009upr/snapshots/`.
- Existing `truenas.home.arpa` (and any other `*.home.arpa` references currently in `kube/`) are kept in Mikrotik static DNS during this migration. Migration of those records to `.lan.cianfr.one` is tracked as a follow-up — out of scope here.
- Public DNS for `cianfr.one` (Cloudflare) is **not** updated to publish `lan.cianfr.one` — Mikrotik is locally authoritative; from outside the LAN those names return NXDOMAIN. This is the split-horizon arrangement.
- DHCP static leases for the four k8s nodes are removed, since they no longer request DHCP.
- Future automation via `terraform-routeros` driven by the same Nix `hosts` attrset is left as a follow-up.

#### LAN DNS authority and ad-blocking topology

The unicast `lan.cianfr.one` zone needs an authoritative answerer on the LAN, and ad-blocking is desirable for general-purpose DNS. Both roles are handled by the Mikrotik itself — no separate component is needed.

**Architecture**:

```
LAN client → 10.0.0.1 (Mikrotik, advertised via DHCP/RA)
  │
  ├─ lan.cianfr.one zone     → /ip dns static     (authoritative locally)
  ├─ truenas.home.arpa etc.  → /ip dns static     (legacy entries kept)
  ├─ ad/tracker domains      → /ip dns adlist     (RouterOS native ad-blocking, NXDOMAIN/0.0.0.0)
  │
  └─ everything else         → /ip dns servers    (1.1.1.1, 1.0.0.1 — or Quad9 / DoH)
```

RouterOS 7.x ships a native DNS Adlist feature ([docs](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS#DNS-adlistAdlist)) that loads hosts-format blocklists from URLs and serves them as part of the router's DNS responses. The community-curated [IgorKha/mikrotik-adlist](https://github.com/IgorKha/mikrotik-adlist) repo (auto-generated weekly from AdGuard's HostlistsRegistry) provides MikroTik-compatible blocklist URLs that can be plugged in directly.

**Why this is the right shape**:

- **Single component, single failure domain**. Mikrotik already serves DNS; adding `/ip dns adlist` entries is configuration on the same daemon. No new VM, no new container, no extra critical-path dependency.
- **`lan.cianfr.one` resolution and ad-blocking share their fate**. Both die only when Mikrotik dies — and at that point all LAN DNS is dead anyway. No new SPOF introduced.
- **No reliability concerns from the user's "nl-pve-02 usually has downtimes" note**. nl-pve-02 is irrelevant here.
- **Auto-updating blocklists**. RouterOS refreshes adlist URLs periodically; the curated repo updates weekly. No manual maintenance.
- **Sidesteps every prerequisite of the alternatives**: no USB SSD, no `container` package install, no device-mode toggle, no VM provisioning.

**Mikrotik configuration changes** (extension of Phase 4):

```routeros
# 8 lan.cianfr.one entries (already covered in Phase 4)
/ip dns static
add name=nl-k8s-01.lan.cianfr.one address=10.0.1.1 type=A
# ... (rest as previously specified)

# Native ad-blocking via DNS Adlist
/ip dns adlist
add url=https://raw.githubusercontent.com/IgorKha/mikrotik-adlist/main/hosts/<list>.txt ssl-verify=yes
# (one or more lists; pick the curated set that suits the noise profile)

# DNS upstream servers — straight to Cloudflare (or Quad9 / DoH)
/ip dns set servers=1.1.1.1,1.0.0.1 allow-remote-requests=yes
```

**Cache sizing note**: large adlists need DNS cache headroom. Per Mikrotik docs ([DNS configuration](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS#DNS-DNSconfiguration)), bump `/ip dns set cache-size` to a value comfortable for the chosen blocklists (start at e.g. 10240 KiB and tune from there based on `/ip dns print` cache stats). The RB5009 has 1 GiB RAM with ~880 MiB free, so cache size is not a constraint.

**Failure modes**:

| Down | Effect on `lan.cianfr.one` | Effect on ad-blocking | Effect on general DNS |
|---|---|---|---|
| Mikrotik | All DNS dead | n/a | All DNS dead (existing SPOF, unchanged) |
| Adlist source URL unreachable at refresh time | None | Existing list keeps working from RouterOS cache; no new list pulled until source recovers | None |
| Cloudflare upstreams | None | None (handled locally by adlist before forwarding) | Resolution fails for non-cached non-blocked names |

**Alternatives considered and rejected**:

- **Mikrotik-only with no ad-blocker**: doesn't meet the user's ad-blocking requirement. Rejected.
- **Pi-hole as a Proxmox VM on nl-pve-02**: previously sketched as Phase 4b. Rejected because RouterOS native Adlist is functionally sufficient for ad-blocking and avoids the new VM entirely. nl-pve-02 downtime correlates with Phase 6 of this very migration (`nl-k8s-03` lives there) — making LAN ad-blocking dependent on it would be operationally awkward.
- **Pi-hole as a RouterOS App on the RB5009** (`/app pihole`): blocked on prerequisites (USB SSD, `container` package, device-mode toggle requiring physical access). Native `/ip dns adlist` is the simpler path for the same outcome.
- **Pi-hole as primary LAN resolver** or **Pi-hole serving `lan.cianfr.one`**: both would couple LAN-wide DNS to a non-router host. Rejected on reliability grounds.

**When Pi-hole or an external resolver becomes interesting again** (out of scope here):

- Per-client filtering rules (different blocklists for the kids' devices vs. yours) — RouterOS Adlist is global per-router.
- Query analytics / per-client query logs — Adlist has minimal observability.
- DNS-level rewrite rules for split-horizon overrides of `*.cianfr.one` ingresses (the hairpin-NAT bypass discussed elsewhere) — RouterOS `/ip dns static` can do this too, but a dedicated UI like Pi-hole or AdGuard Home scales better past ~10–20 records.
- Conditional-forwarding scenarios (different upstreams per client/zone).

If any of those become priorities, the natural path is Pi-hole or AdGuard Home as a Proxmox VM, layered *additionally* — Mikrotik would forward selected zones/clients to it while keeping the local zone authoritative on the router. That's a future ADR.

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

The migration is broken into eight phases. Each phase is independently reversible up to phase 6.

### Phase 0 — Pre-migration safety

1. Export current Mikrotik DHCP and DNS state as a `.rsc` snapshot, commit to `networking/rb5009upr/snapshots/pre-static-ip-migration.rsc`.
2. Verify out-of-band paths:
   - SSH by IP (`ssh root@10.0.1.X`) works for all four nodes.
   - SSH via Tailscale tailnet works for all four nodes.
3. Verify cluster baseline: `kubectl --context=nl get nodes -o wide` shows four `Ready` nodes with expected `INTERNAL-IP` values.

### Phase 0a — Land the `terraform-mikrotik` branch on main (prerequisite)

The Mikrotik configuration touched by this ADR (DHCP leases for cluster nodes, DNS static records, DNS server settings, DNS adlist) overlaps with the work-in-progress `terraform-mikrotik` branch. That branch already contains:

- Terragrunt scaffolding (`root.hcl`, `networking/routeros.hcl`, `networking/rb5009upr/terragrunt.hcl`).
- Provider config + SOPS-encrypted secrets (`secrets.yaml` with `routeros_hosturl`, `routeros_username`, `routeros_password`).
- Resources for interfaces, IPv4 addressing, the DHCP server, DHCP static leases for all cluster + infrastructure devices, IoT/Guest VLANs, and KPN PPPoE.
- Provider pinned at `terraform-routeros/routeros 1.99.0`.
- State already initialised in the Kubernetes secret backend (`secret_suffix=rb5009upr` in `networking/rb5009upr/backend.tf` on `main`).

Doing the ADR-003 work as further-out-of-tree manual `/ip` commands while the branch sits unmerged guarantees drift between TF state and reality. Phase 0a closes that gap before Phase 4 starts.

Steps:

1. **Verify REST API prerequisites on the router** (the provider uses REST). Today on the RB5009 (verified via SSH):
   - `/ip service` → `www-ssl` is **disabled**, `api` (port 8728) is enabled, `api-ssl` (port 8729) is enabled but with no certificate set.
   - No dedicated Terraform user exists yet (only `admin` and `mktxp_user`).

   To enable REST cleanly:
   ```routeros
   /certificate add name=local-ca common-name=rb5009-ca key-usage=key-cert-sign,crl-sign
   /certificate sign local-ca
   /certificate add name=rest-api common-name=10.0.0.1 key-usage=tls-server
   /certificate sign rest-api ca=local-ca
   /ip service set www-ssl certificate=rest-api disabled=no
   /ip service set www disabled=yes
   ```

   Alternatively the `terraform-mikrotik` branch can be configured to use legacy `api://` (port 8728) via `hosturl=api://10.0.0.1` and skip cert work entirely — simpler if no other reason to enable REST. Decision lives in the branch.

2. **Create a dedicated TF user** (also handled by the branch if not already):
   ```routeros
   /user group add name=tfgroup policy=read,write,policy,test,api,rest-api,!ssh,!ftp,!telnet,!winbox,!web,!sniff,!sensitive,!romon
   /user add name=terraform group=tfgroup password=<long-random> address=<workstation-LAN-IP-or-tailnet-CIDR>
   ```
   Update `networking/rb5009upr/secrets.yaml` (SOPS) with the new credential before merging.

3. **Test the branch end-to-end on a workstation**:
   - `cd networking/rb5009upr && terragrunt init && terragrunt plan`
   - Plan should be **empty** if the branch's resources accurately reflect current router state.
   - If the plan shows changes, the branch needs to be brought up to date with the router's current state via `terraform import` or by editing the `.tf` files to match reality. Do not apply a non-empty plan in this phase — the goal is to take ownership of existing config without disturbing it.

4. **Merge `terraform-mikrotik` to `main`** once the plan is empty. `main` now has:
   - All current Mikrotik config codified.
   - DHCP leases for `nl-k8s-01..04` declared in `local.ipv4_local_leases_by_mac_address` in `networking/rb5009upr/ipv4.tf`. **These get removed in Phase 5** of this ADR (after the OS-static rollout completes).

5. **Snapshot of post-merge router config** (`/export file=post-tf-takeover`), commit to `networking/rb5009upr/snapshots/`. This snapshot is the new baseline; subsequent ADR-003 phases modify TF resources rather than running `/ip` commands on the router.

After this phase, all Mikrotik changes in Phase 4 / 4b / 5 are TF-driven (`terragrunt apply`), not manual.

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

### Phase 4 — Mikrotik unicast DNS for `lan.cianfr.one` (TF-managed)

Done via the `terraform-mikrotik` machinery (now on `main` after Phase 0a). All changes happen as a Terragrunt plan/apply cycle from `networking/rb5009upr/`. **Before any OS-side deploy in Phase 6.**

1. **Add a new `dns.tf`** (or similarly-named file) in `networking/rb5009upr/` declaring `/ip dns` settings. Important: `routeros_ip_dns` cannot be imported and overwrites whatever is on the router, so the resource must mirror the *currently-running* `/ip dns print` output before adding any new fields. Verified state today:

   ```hcl
   resource "routeros_ip_dns" "main" {
     allow_remote_requests = true
     servers = [
       "1.1.1.1",
       "1.0.0.1",
       "2606:4700:4700::1111",
       "2606:4700:4700::1001",
     ]
     # mDNS repeater currently active on bridge + IoT/Guest VLANs — preserve.
     mdns_repeat_ifaces = ["bridge", "vlan80-guest", "vlan90-iot"]
     # cache_size and other timeouts are at defaults today; declare explicitly to
     # take ownership of the resource without accidental drift on apply.
     cache_size = 2048   # KiB; bumped in Phase 4b alongside adlist activation.
   }
   ```

2. **Add a new `dns_static.tf`** declaring the eight `lan.cianfr.one` records and bringing the existing `*.home.arpa` records under TF management via `terraform import` (they are static today and must not be deleted):

   ```hcl
   locals {
     cluster_nodes = {
       "nl-k8s-01" = { ipv4 = "10.0.1.1", ipv6 = "fd00:cafe::1:1" }
       "nl-k8s-02" = { ipv4 = "10.0.1.2", ipv6 = "fd00:cafe::1:2" }
       "nl-k8s-03" = { ipv4 = "10.0.1.3", ipv6 = "fd00:cafe::1:3" }
       "nl-k8s-04" = { ipv4 = "10.0.1.4", ipv6 = "fd00:cafe::1:4" }
     }
     domain = "lan.cianfr.one"

     # Existing static records on the router today (verified via /ip dns static print).
     # These are imported into TF state, not recreated — preserves resolution during migration.
     legacy_records = {
       "router"            = { name = "router.home.arpa",    address = "10.0.0.1", type = "A" }
       "truenas"           = { name = "truenas.home.arpa",   address = "10.0.1.20", type = "A" }
       "nl-pve-01"         = { name = "nl-pve-01.home.arpa", address = "10.0.2.1", type = "A" }
       "nl-pve-02"         = { name = "nl-pve-02.home.arpa", address = "10.0.2.2", type = "A" }
       "eap245"            = { name = "eap245-7c-f1-7e-74-fd-6e.home.arpa", address = "10.0.0.3", type = "A" }
       "e1-zoom-01"        = { name = "e1-zoom-01.home.arpa", address = "10.90.0.11", type = "A" }
       "e1-zoom-02"        = { name = "e1-zoom-02.home.arpa", address = "10.90.0.12", type = "A" }
       # nl-k8s-XX.home.arpa entries are NOT included here — they get superseded
       # by the new .lan.cianfr.one records below and removed from the router during this phase.
     }
   }

   resource "routeros_ip_dns_record" "cluster_a" {
     for_each = local.cluster_nodes
     name     = "${each.key}.${local.domain}"
     address  = each.value.ipv4
     type     = "A"
     comment  = "managed by terraform; ADR-003 cluster identity"
   }

   resource "routeros_ip_dns_record" "cluster_aaaa" {
     for_each = local.cluster_nodes
     name     = "${each.key}.${local.domain}"
     address  = each.value.ipv6
     type     = "AAAA"
     comment  = "managed by terraform; ADR-003 cluster identity"
   }

   resource "routeros_ip_dns_record" "legacy" {
     for_each = local.legacy_records
     name     = each.value.name
     address  = each.value.address
     type     = each.value.type
     comment  = "imported existing static record"
   }
   ```

3. **Import the existing legacy records** into state without recreating them. Use IDs from `/ip dns static print show-ids` or import-by-name:

   ```sh
   cd networking/rb5009upr
   terragrunt import 'routeros_ip_dns_record.legacy["router"]'    'name=router.home.arpa'
   terragrunt import 'routeros_ip_dns_record.legacy["truenas"]'   'name=truenas.home.arpa'
   terragrunt import 'routeros_ip_dns_record.legacy["nl-pve-01"]' 'name=nl-pve-01.home.arpa'
   # ... one per legacy record
   ```

4. **Plan and apply**:
   ```sh
   terragrunt plan
   ```
   Expected diff:
   - Add: 8 `routeros_ip_dns_record.cluster_a / cluster_aaaa` resources (the new `.lan.cianfr.one` entries).
   - Add: `routeros_ip_dns.main` (TF takes ownership; values match current router state, so this should be a "no real change" add).
   - No diff on imported legacy records.

   The 5 existing `nl-k8s-XX.home.arpa` records remain on the router *un-managed by TF* during the migration — they're not in the `legacy_records` map, so TF won't touch them. They are removed manually as the *very last step* of Phase 5, after the new entries are confirmed working.

   ```sh
   terragrunt apply
   ```

5. **Verify** (from a LAN client):
   - `dig nl-k8s-04.lan.cianfr.one @10.0.0.1` → A `10.0.1.4` + AAAA `fd00:cafe::1:4`.
   - `dig nl-k8s-04.lan.cianfr.one @1.1.1.1` → NXDOMAIN (split-horizon).
   - `dig truenas.home.arpa @10.0.0.1` → still `10.0.1.20` (legacy preserved via TF).
   - `dig nl-k8s-01.home.arpa @10.0.0.1` → still `10.0.1.1` (still-unmanaged-by-TF; gets removed in Phase 5).

6. **Snapshot**: `/export file=post-adr003-phase4` from the router, commit to `networking/rb5009upr/snapshots/`.

### Phase 4b — Ad-blocking via TF-managed DNS Adlist

Same TF workflow. Independent of the cluster-identity migration; can run before, during, or after the per-node rollout. Does **not** gate Phase 6.

1. **Bump DNS cache** in `dns.tf` (the existing `routeros_ip_dns.main` resource added in Phase 4):

   ```hcl
   resource "routeros_ip_dns" "main" {
     # ... existing fields ...
     cache_size = 10240   # was 2048; bumped to fit adlist entries
   }
   ```

2. **Add `dns_adlist.tf`** in `networking/rb5009upr/`:

   ```hcl
   locals {
     adlists = [
       # Pick from https://github.com/IgorKha/mikrotik-adlist/tree/main/hosts
       # Start conservative; grow after observing for false positives.
       "https://raw.githubusercontent.com/IgorKha/mikrotik-adlist/main/hosts/<list-1>.txt",
       # Add more URLs here as needed.
     ]
   }

   resource "routeros_ip_dns_adlist" "lists" {
     for_each   = toset(local.adlists)
     url        = each.value
     ssl_verify = true
   }
   ```

3. **Plan and apply**:
   ```sh
   cd networking/rb5009upr
   terragrunt plan    # expect: cache_size update on routeros_ip_dns.main + N adlist additions
   terragrunt apply
   ```

4. **Verify on the router**:
   ```routeros
   /ip dns adlist print
   /ip dns cache print count-only
   ```
   Adlists should show non-zero `match-count` after a few queries; cache should reflect a sizeable number of loaded entries.

5. **Test from a LAN client**:
   - `dig doubleclick.net @10.0.0.1` → NXDOMAIN or `0.0.0.0` (depending on adlist policy).
   - `dig google.com @10.0.0.1` → resolves normally.
   - `dig nl-k8s-01.lan.cianfr.one @10.0.0.1` → resolves (ad-blocking has no effect on local zone).

6. **Snapshot**: `/export file=post-adr003-phase4b`, commit.

Reversible: remove URL entries from `local.adlists` and `terragrunt apply` to drop them; the rest of the DNS config is unaffected.

### Phase 5 — DHCP and stale DNS cleanup on Mikrotik (TF-managed, deferred until after Phase 6 completes)

All cleanup happens via Terragrunt against the now-merged `terraform-mikrotik` config.

1. **Remove the four cluster nodes' DHCP leases** from `networking/rb5009upr/ipv4.tf`. The branch currently declares them in `local.ipv4_local_leases_by_mac_address`:

   ```hcl
   # Delete these four entries from the map:
   "6C:1F:F7:57:07:49" = { addr : "10.0.1.1", comment : "nl-k8s-01" }
   "BC:24:11:A2:94:61" = { addr : "10.0.1.2", comment : "nl-k8s-02" }
   "BC:24:11:07:69:C7" = { addr : "10.0.1.3", comment : "nl-k8s-03" }
   "54:E1:AD:A5:1D:0F" = { addr : "10.0.1.4", comment : "nl-k8s-04" }
   ```

   `terragrunt plan` should show 4× `routeros_ip_dhcp_server_lease.dhcp-v4-lease` deletions; nothing else.

2. **Reserve the static range from the DHCP pool**. Update `local.ipv4_local_dhcp_pool` (or the pool resource directly) so `10.0.1.0/24` is not handed to dynamic clients. Today the pool is `10.0.0.100-10.0.0.254`, which already doesn't overlap `10.0.1.X` — verify this is still the case and explicitly comment why:

   ```hcl
   locals {
     # 10.0.1.0/24 is reserved for static infra (cluster nodes per ADR-003,
     # TrueNAS, future infra). Pool intentionally excludes it.
     ipv4_local_dhcp_pool = "10.0.0.100-10.0.0.254"
   }
   ```

   No TF change needed if the pool is already sized correctly — just document.

3. **Remove the now-stale `nl-k8s-XX.home.arpa` static records** from the router. These were left in place during Phase 4 to keep `serverAddr` resolution working for join nodes mid-migration. After Phase 6 completes successfully, they're redundant and confusing.

   Two paths:

   - **Direct**: `/ip dns static remove [find name~"nl-k8s.*\\.home\\.arpa"]` from the router. Simple but leaves the records as un-managed-and-now-deleted.
   - **TF-tracked deletion** (preferred): briefly add the records to `local.legacy_records` in `dns_static.tf`, `terragrunt import` them into state, then immediately remove them from the locals map and `terragrunt apply` to delete. This way the deletion event is visible in TF state history.

4. **Verify**:
   - `/ip dhcp-server lease print where address~"10.0.1\\."` → empty.
   - `/ip dns static print where name~"nl-k8s.*home.arpa"` → empty.
   - `/ip dns static print where name~"lan.cianfr.one"` → 8 entries (4× A + 4× AAAA).
   - LAN clients still resolve `truenas.home.arpa` and other preserved legacy entries.

5. **Snapshot**: `/export file=post-adr003-phase5`, commit.

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
   - Append to the Nix `hosts` attrset.
   - Append to `local.cluster_nodes` in `networking/rb5009upr/dns_static.tf`; `terragrunt apply` to add the A/AAAA records.
   - (If the new node also needs a DHCP reservation for first-boot bootstrap before NixOS-static takes over: add a temporary lease to `local.ipv4_local_leases_by_mac_address` in `ipv4.tf`, then remove after rollout.)
   - Run `colmena apply --on <new-node>`.
4. Update `AGENTS.md` SSH section to mention all four name paths (`<short>`, `<short>.local`, `<short>.lan.cianfr.one`, `<short>.tail2ff90.ts.net`) and which is appropriate when.
5. Add a follow-up tracking item: migrate remaining `*.home.arpa` references in `kube/` (NFS PVs for `truenas`, Longhorn backup target) to `*.lan.cianfr.one`. Out of scope here — gets its own small ADR or runbook.
6. Add a brief note to `AGENTS.md` (or a sibling ops doc) that LAN ad-blocking is provided via RouterOS `/ip dns adlist` (TF-managed under `networking/rb5009upr/dns_adlist.tf`) with curated lists from [IgorKha/mikrotik-adlist](https://github.com/IgorKha/mikrotik-adlist) — so it's discoverable when troubleshooting "why is this domain not resolving from the LAN".
7. Update `AGENTS.md` to document the Mikrotik change workflow: changes to router config now go through `terragrunt apply` from `networking/rb5009upr/` rather than direct `/ip` commands. Direct router edits cause TF drift on the next plan and should be avoided except for emergency recovery.

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
| Adlist source URL (GitHub raw) unreachable at refresh time | Low | RouterOS keeps the previously-loaded list in cache; no new pull until the URL is reachable. Worst case: list goes stale. No effect on resolution itself. |
| Adlist contains a false positive that blocks a legitimate domain | Medium | Use `/ip dns adlist disable [find url~"<bad-list>"]` to disable, or add an explicit allow override via `/ip dns static` (static entries take precedence). Curated lists from AdGuard registry are generally well-vetted. |
| DNS cache exhaustion under heavy adlist + recursive load | Low | Tune `/ip dns set cache-size`. Monitor `/ip dns print` cache statistics. RB5009 has 1 GiB RAM — cache is not memory-constrained. |
| `routeros_ip_dns` resource on first apply overwrites unmanaged settings (timeouts, DoH config, mDNS repeater list, etc.) | Medium | Phase 4 step 1 explicitly mirrors the *currently-running* `/ip dns print` output before adding new fields. Run `terragrunt plan` and inspect the diff carefully before the first apply. Snapshot the router immediately before. |
| `terraform-mikrotik` branch's plan is non-empty against current router state at merge time | Medium | Phase 0a step 3 requires an empty plan as the merge gate. If the plan shows unexpected changes, fix the branch (via `terraform import` or `.tf` edits) before merging — never apply a non-empty plan as the takeover step. |
| TF user `address=` filter blocks applies from tailnet/workstation that needs to run them | Medium | When provisioning the TF user, set `address=` to a CIDR covering both LAN and the relevant tailnet IPs (or 0.0.0.0/0 if access is otherwise restricted via auth). Test from intended apply locations before relying on it. |
| K8s state backend (`secret_suffix=rb5009upr`) unreachable when the cluster is down — blocks emergency router changes | Medium | For emergency router changes during cluster downtime, fall back to direct `/ip` commands; subsequent `terragrunt plan` will show drift and require reconciliation (re-import or re-edit). Document this fallback in the new runbook. |

## Out of Scope

- Realigning IPs to `10.10.0.0/16` per ADR-001 (separate migration).
- Generating the TF `local.cluster_nodes` map from the Nix `hosts` registry automatically (e.g. via a flake app emitting JSON consumed by `jsondecode`). Currently the Nix and TF lists are duplicated by hand. Acceptable for 4 nodes; worth automating if the count grows.
- Adding mDNS / static IPs to non-k8s machines (Proxmox hosts, NAS, switches).
- Migrating client devices (phones, laptops, IoT) off DHCP — they should keep using DHCP with leases.
- Migrating remaining `*.home.arpa` references in `kube/` (e.g. `truenas.home.arpa` in NFS PVs and Longhorn backup target) to `*.lan.cianfr.one`. Tracked as a follow-up; entries stay in Mikrotik DNS until then.
- Configuring publicly-trusted TLS certificates for internal services via Let's Encrypt DNS-01 against `cianfr.one`. Enabled by Option 6 but not implemented here; gets its own ADR/runbook when the need arises.
- Eliminating hairpin NAT for public-named ingresses (`media.cianfr.one`, `vault.cianfr.one`, etc.) by adding LAN-side DNS overrides pointing them at `10.0.3.1` (the ingress LB IP). Implementable now via TF-managed `routeros_ip_dns_record` entries (each public hostname → `10.0.3.1`); deferred because it's a separate concern from cluster identity.
- Per-client filtering, query analytics, or split-horizon override UIs at scale — would justify revisiting Pi-hole / AdGuard Home as a Proxmox VM layered on top of the current setup. Not needed today; native `/ip dns adlist` is sufficient.

## Additional Links

- [ADR-001 Network Architecture](./ADR-001-network-architecture.md)
- [ADR-002 DHCP/DNS Configuration Strategy](./ADR-002-dhcp-dns-configuration-strategy.md) (Superseded by this ADR for infrastructure nodes)
- [INC-0003 DHCP ARP Conflict](../postmortems/INC-0003-kubernetes-cluster-down-dhcp-arp-conflict.md)
- [RFC 6762 — Multicast DNS](https://datatracker.ietf.org/doc/html/rfc6762)
- [RFC 8375 — `.home.arpa` Domain Name Reservation](https://datatracker.ietf.org/doc/html/rfc8375)
- [MikroTik DNS — Adlist documentation](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS#DNS-adlistAdlist)
- [IgorKha/mikrotik-adlist](https://github.com/IgorKha/mikrotik-adlist) — curated AdGuard hostlists in MikroTik-compatible format, weekly auto-updated
- [terraform-routeros provider docs](https://github.com/terraform-routeros/terraform-provider-routeros/tree/main/docs) — provider reference (registry equivalent: `https://registry.terraform.io/providers/terraform-routeros/routeros/latest/docs`)
- [`routeros_ip_dns_adlist` resource docs](https://github.com/terraform-routeros/terraform-provider-routeros/blob/main/docs/resources/ip_dns_adlist.md)
- [`routeros_ip_dns_record` resource docs](https://github.com/terraform-routeros/terraform-provider-routeros/blob/main/docs/resources/ip_dns_record.md)
- [`routeros_ip_dns` resource docs](https://github.com/terraform-routeros/terraform-provider-routeros/blob/main/docs/resources/ip_dns.md) — note: cannot be imported, overwrites unmanaged settings on first apply
