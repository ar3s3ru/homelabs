locals {
  ipv4_lan_address_cidr    = "10.0.0.1/16"
  ipv4_lan_network         = "10.0.0.0"
  ipv4_lan_address_gateway = "10.0.0.1"
  ipv4_lan_dhcp_pool       = "10.0.0.100-10.0.0.254"

  ipv6_lan_ula_prefix = "fd00:cafe::/64"
  ipv6_lan_ula_addr   = "fd00:cafe::1"
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

# IPv6 networking --------------------------------------------------------------

# ULA pool for static DHCPv6 bindings on the LAN.
resource "routeros_ipv6_pool" "pool-dhcp-v6-ula-lan" {
  name          = "pool-dhcp-v6-ula-lan"
  prefix        = local.ipv6_lan_ula_prefix
  prefix_length = 128
}

# Router ULA address on bridge.
resource "routeros_ipv6_address" "ula_lan" {
  interface = routeros_interface_bridge.bridge.name
  address   = "${local.ipv6_lan_ula_addr}/64"
  advertise = false
}

# Router GUA address derived from the PPPoE prefix delegation, advertised to
# clients on the LAN segment for outbound IPv6 connectivity.
resource "routeros_ipv6_address" "gua_lan" {
  interface = routeros_interface_bridge.bridge.name
  address   = "::1"
  from_pool = routeros_ipv6_dhcp_client.pppoe-kpn.pool_name
  advertise = true

  # Assigned by the DHCPv6 client pool automatically.
  lifecycle {
    ignore_changes = [address]
  }
}

# Stateful DHCPv6 server on the LAN — issues static-only ULA bindings (no
# dynamic addressing; clients get GUA via SLAAC from the ND prefix below).
resource "routeros_ipv6_dhcp_server" "dhcp-v6-ula-lan" {
  name         = "dhcp-v6-ula-lan"
  interface    = routeros_interface_bridge.bridge.name
  address_pool = routeros_ipv6_pool.pool-dhcp-v6-ula-lan.name
  prefix_pool  = "static-only"
  lease_time   = "3d"
  rapid_commit = true
  preference   = 255
}

# Router advertisements on the LAN — managed-address signals stateful DHCPv6,
# DNS pushes the router ULA as resolver.
resource "routeros_ipv6_neighbor_discovery" "lan" {
  interface                     = routeros_interface_bridge.bridge.name
  managed_address_configuration = true
  other_configuration           = true
  dns                           = local.ipv6_lan_ula_addr
}

# Advertise the ULA prefix on-link (autonomous=false because addressing is
# handled by stateful DHCPv6, not SLAAC).
resource "routeros_ipv6_nd_prefix" "ula_lan" {
  interface  = routeros_interface_bridge.bridge.name
  prefix     = local.ipv6_lan_ula_prefix
  on_link    = true
  autonomous = false
}

