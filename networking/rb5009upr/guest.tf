locals {
  ipv4_guest_address_cidr    = "10.80.0.1/24"
  ipv4_guest_network         = "10.80.0.0"
  ipv4_guest_address_gateway = "10.80.0.1"
  ipv4_guest_dhcp_pool       = "10.80.0.10-10.80.0.254"
}

resource "routeros_ip_address" "ipv4_guest" {
  address   = local.ipv4_guest_address_cidr
  interface = routeros_interface_vlan.vlan80-guest.name
  network   = local.ipv4_guest_network
  comment   = "guest network"
}

resource "routeros_interface_vlan" "vlan80-guest" {
  interface = routeros_interface_bridge.bridge.name
  name      = "vlan80-guest"
  vlan_id   = 80
  comment   = "guest network"
}

resource "routeros_interface_list" "guest" {
  name    = "GUEST"
  comment = "guest network"
}

resource "routeros_ip_pool" "pool-dhcp-v4-guest" {
  name   = "pool-dhcp-v4-guest"
  ranges = [local.ipv4_guest_dhcp_pool]
}

resource "routeros_ip_dhcp_server" "dhcp-v4-guest" {
  name            = "dhcp-v4-guest"
  interface       = routeros_interface_vlan.vlan80-guest.name
  address_pool    = routeros_ip_pool.pool-dhcp-v4-guest.name
  use_reconfigure = true
}
