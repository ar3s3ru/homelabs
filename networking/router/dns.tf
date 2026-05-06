# DNS server configuration for the router.
#
# IMPORTANT: routeros_ip_dns is NOT importable — first apply will overwrite the
# router's current /ip dns settings with whatever is declared here. The HCL
# below mirrors the current router state exactly to make the first apply a
# no-op. Do NOT change any field without understanding the operational impact
# on every client that uses the router as their resolver.
#
# References:
#   - mDNS repeater on bridge/guest/iot enables AirPlay/Chromecast/etc. across
#     VLANs while firewall rules gate which directions can initiate traffic.
#   - Upstream resolvers are Cloudflare (1.1.1.1, 1.0.0.1, with v6 equivalents).
resource "routeros_ip_dns" "dns" {
  allow_remote_requests = true

  servers = [
    "2606:4700:4700::1111,1.1.1.1",
    "2606:4700:4700::1001,1.0.0.1",
  ]

  mdns_repeat_ifaces = [
    routeros_interface_bridge.bridge.name,
    routeros_interface_vlan.vlan80-guest.name,
    routeros_interface_vlan.vlan90-iot.name,
  ]
}
