locals {
  ipv4_lan_address_cidr    = "10.0.0.1/16"
  ipv4_lan_network         = "10.0.0.0"
  ipv4_lan_address_gateway = "10.0.0.1"
  ipv4_lan_dhcp_pool       = "10.0.0.100-10.0.0.254"
}

resource "routeros_ip_address" "ipv4_local" {
  address   = local.ipv4_lan_address_cidr
  interface = routeros_interface_bridge.bridge.name
  network   = local.ipv4_lan_network
  comment   = "defconf" # FIXME(ar3s3ru): should change this?
}

resource "routeros_interface_list" "lan" {
  name    = "LAN"
  comment = "defconf"
}

locals {
  lan_member_interfaces = toset([
    routeros_interface_ethernet.ether1.name,
    routeros_interface_ethernet.ether2.name,
    routeros_interface_ethernet.ether3.name,
    routeros_interface_ethernet.ether4.name,
    routeros_interface_ethernet.ether5.name,
    routeros_interface_ethernet.ether6.name,
    routeros_interface_ethernet.ether7.name,
    routeros_interface_ethernet.sfp-sfpplus1.name,
    routeros_interface_bridge.bridge.name,
  ])
}

resource "routeros_interface_list_member" "lan" {
  for_each  = local.lan_member_interfaces
  list      = routeros_interface_list.lan.name
  interface = each.value
}

resource "routeros_ip_pool" "pool-dhcp-v4" {
  name   = "pool-dhcp-v4"
  ranges = [local.ipv4_lan_dhcp_pool]
}

resource "routeros_ip_dhcp_server" "dhcp-v4" {
  name            = "defconf"
  interface       = routeros_interface_bridge.bridge.name
  address_pool    = routeros_ip_pool.pool-dhcp-v4.name
  use_reconfigure = true
  lease_time      = "30m"
}

