# INC-0006: IPv6 HTTPS Connections Failing — Rogue RDNSS from OpenWrt AP

**Date**: February 11, 2026
**Severity**: Medium (IPv6 HTTPS connectivity broken for LAN clients)
**Duration**: ~4 days, intermittent (when NanoPi R5C is plugged in)
**Affected Systems**: LAN clients using IPv6 DNS (polus, potentially others)

## Summary

IPv6 HTTPS connections from LAN clients were timing out during TLS handshake. Initial suspicion was a repeat of the earlier IPv6 PMTUD black hole (see MSS clamp rules added previously), but investigation revealed the root cause was an OpenWrt access point (r5c, 10.0.0.5) broadcasting **Router Advertisements with RDNSS** pointing to itself as a DNS server. The AP had been running AdGuard Home, which was since stopped — but odhcpd continued sending RAs advertising the AP's IPv6 GUA address as an available DNS resolver. Clients that picked up this rogue RDNSS entry were sending DNS queries to a non-functional DNS server, causing resolution failures or timeouts on IPv6.

## Timeline

— User reports `curl -v https://controlplane.tailscale.com` hanging after TLS ClientHello, eventually timing out with `Recv failure: Operation timed out`,

— Initial hypothesis: IPv6 PMTUD black hole (PPPoE MTU 1492). Checked existing MSS clamp rules — both present and matching traffic. Bridge MTU confirmed at 1500 (correct),

— Router can ping `2606:b740:49::105` with 1452-byte packets successfully. IPv6 default route healthy. PPPoE interface up with MTU 1492,

— Reset mangle counters. User tested `curl -4` (works) and `curl -6` (fails). MSS clamp rules did match traffic from the IPv6 test — ruling out MSS clamping as the problem,

— Checked IPv6 connection tracking: many other LAN devices have working HTTPS (port 443) IPv6 connections to Tailscale IPs. Problem appears client-specific,

— User notices an unexpected IPv6 address in macOS Wi-Fi DNS server list. Suspects it's the GUA SLAAC address of the OpenWrt AP (r5c.home.arpa / 10.0.0.5),

— Inspected AP configuration via SSH. Found `dhcp.lan.ra='hybrid'` and `dhcp.lan.dhcpv6='hybrid'` — odhcpd was sending Router Advertisements with RDNSS on the LAN bridge, advertising the AP as a DNS server,

Disabled RA and DHCPv6 on the AP. User toggled Wi-Fi to flush stale DNS. IPv6 HTTPS connections immediately working.

## Root Cause

The OpenWrt access point (r5c, 10.0.0.5) had **odhcpd** configured in `hybrid` mode for both RA and DHCPv6 on its LAN interface:

```
dhcp.lan.ra='hybrid'
dhcp.lan.dhcpv6='hybrid'
dhcp.lan.ra_flags='managed-config'
```

This caused odhcpd to send **Router Advertisements** on the bridge containing an **RDNSS option (RFC 8106)** advertising the AP's own IPv6 GUA (SLAAC-derived) address as a DNS recursive resolver.

The AP had previously been running AdGuard Home as a DNS server on port 54 (dnsmasq) / port 53 (AdGuard Home). AdGuard Home was stopped and disabled, but **odhcpd's RA/RDNSS advertisement is independent of the DNS software** — it continued broadcasting the AP as a DNS server regardless.

### Why this caused HTTPS timeouts specifically

1. macOS picked up the AP's IPv6 GUA as a DNS server via RDNSS in Router Advertisements
2. When resolving `controlplane.tailscale.com`, the OS attempted to use this rogue DNS server
3. The DNS server was non-functional (AdGuard Home stopped, dnsmasq on port 54 only)
4. DNS queries over IPv6 to the AP timed out
5. TCP connection to the resolved IP established (from cached/fallback DNS), but subsequent TLS data transfer appeared to hang because the client was still waiting on DNS for certificate validation / OCSP checks
6. The failure presented as a TLS handshake timeout, masking the underlying DNS issue

### Why other devices were unaffected

Other LAN devices (k8s nodes) were configured with static DNS (e.g., via Tailscale at `100.100.100.100`) or had obtained DNS from DHCPv4 (`10.0.0.1`), bypassing the rogue RDNSS. macOS aggressively adopts RDNSS from RAs, especially for IPv6-capable connections.

## Resolution

### Immediate Fix

Disabled RA and DHCPv6 on the AP's LAN interface — it has no business sending RAs since the MikroTik router is the sole RA/DHCPv6 authority on the network:

```bash
# Applied on r5c (OpenWrt AP at 10.0.0.5)
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra_flags='none'
uci commit dhcp
/etc/init.d/odhcpd restart
```

User toggled Wi-Fi on macOS to flush the stale RDNSS entry. IPv6 HTTPS connections restored immediately.

### Verification

```bash
curl -6 -v https://controlplane.tailscale.com  # Working
```

## Action Items

### Completed
- [x] Disabled RA and DHCPv6 on AP LAN interface
- [x] Restarted odhcpd on AP
- [x] Verified IPv6 HTTPS connectivity restored

### High Priority
- [x] **Add RA guard on MikroTik bridge**: configure IPv6 RA guard to drop RAs from non-router ports on all VLANs, preventing any rogue RA from bridge members:
  ```routeros
  /ipv6 firewall filter add chain=forward protocol=icmpv6 icmp-options=134:0 in-interface-list=LAN action=drop comment="RA guard: drop RAs from LAN devices"
  /ipv6 firewall filter add chain=forward protocol=icmpv6 icmp-options=134:0 in-interface-list=GUEST action=drop comment="RA guard: drop RAs from GUEST devices"
  /ipv6 firewall filter add chain=forward protocol=icmpv6 icmp-options=134:0 in-interface-list=IOT action=drop comment="RA guard: drop RAs from IOT devices"
  ```

### Medium Priority
- [ ] **Document AP role**: the AP should operate as a dumb AP (bridge mode only) — no DHCP, no DHCPv6, no RA, no DNS
- [ ] Consider replacing OpenWrt's default odhcpd configuration with a minimal profile for dumb AP mode

## References
- RFC 8106: IPv6 Router Advertisement Options for DNS Configuration (RDNSS/DNSSL)
- OpenWrt odhcpd documentation: https://openwrt.org/docs/techref/odhcpd
- MikroTik IPv6 ND configuration: https://help.mikrotik.com/docs/spaces/ROS/pages/328129/IPv6+Neighbor+Discovery
