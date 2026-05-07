resource "routeros_ip_dns" "dns" {
  allow_remote_requests = true

  servers = [
    "2606:4700:4700::1111",
    "1.1.1.1",
    "2606:4700:4700::1001",
    "1.0.0.1",
  ]

  mdns_repeat_ifaces = [
    routeros_interface_bridge.bridge.name,
    routeros_interface_vlan.vlan80-guest.name,
    routeros_interface_vlan.vlan90-iot.name,
  ]
}
