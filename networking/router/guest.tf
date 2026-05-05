locals {
  ipv4_guest_address_cidr    = "10.80.0.1/24"
  ipv4_guest_network         = "10.80.0.0"
  ipv4_guest_address_gateway = "10.80.0.1"
  ipv4_guest_dhcp_pool       = "10.80.0.10-10.80.0.254"

  ipv6_guest_ula_address_gateway = "fd00:cafe:80::1"
  ipv6_guest_ula_prefix          = "fd00:cafe:80::/64"
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

resource "routeros_interface_list_member" "guest_vlan80" {
  list      = routeros_interface_list.guest.name
  interface = routeros_interface_vlan.vlan80-guest.name
}

# IPv4 networking --------------------------------------------------------------

resource "routeros_ip_address" "ipv4_guest" {
  address   = local.ipv4_guest_address_cidr
  interface = routeros_interface_vlan.vlan80-guest.name
  network   = local.ipv4_guest_network
  comment   = "guest network"
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
  lease_time      = "30m"
}

# IPv6 networking --------------------------------------------------------------

resource "routeros_ipv6_pool" "pool-dhcp-v6-ula-guest" {
  name          = "pool-dhcp-v6-ula-guest"
  prefix        = local.ipv6_guest_ula_prefix
  prefix_length = 128
}

resource "routeros_ipv6_address" "ula_guest" {
  interface = routeros_interface_vlan.vlan80-guest.name
  address   = "${local.ipv6_guest_ula_address_gateway}/64"
  advertise = false
  comment   = "guest: ULA addresses"
}

# EUI-64 GUA address on the guest VLAN, derived from the PPPoE prefix
# delegation. Advertised to clients via SLAAC for outbound IPv6 connectivity.
resource "routeros_ipv6_address" "gua_guest" {
  interface = routeros_interface_vlan.vlan80-guest.name
  address   = "::"
  eui_64    = true
  from_pool = routeros_ipv6_dhcp_client.pppoe-kpn.pool_name
  advertise = true

  # Assigned by the DHCPv6 client pool automatically.
  lifecycle {
    ignore_changes = [address]
  }
}

# Stateful DHCPv6 server on the guest VLAN — issues static-only ULA bindings.
resource "routeros_ipv6_dhcp_server" "dhcp-v6-ula-guest" {
  name         = "dhcp-v6-ula-guest"
  interface    = routeros_interface_vlan.vlan80-guest.name
  address_pool = routeros_ipv6_pool.pool-dhcp-v6-ula-guest.name
  prefix_pool  = "static-only"
  lease_time   = "3d"
  rapid_commit = true
  preference   = 255
  comment      = "guest: DHCPv6 ULA server"
}

# Router advertisements on the guest VLAN — managed-address signals stateful
# DHCPv6, DNS pushes the router ULA as resolver.
resource "routeros_ipv6_neighbor_discovery" "guest" {
  interface                     = routeros_interface_vlan.vlan80-guest.name
  managed_address_configuration = true
  other_configuration           = true
  dns                           = local.ipv6_guest_ula_address_gateway
}

# Advertise the ULA prefix on-link (autonomous=false because addressing is
# handled by stateful DHCPv6, not SLAAC).
resource "routeros_ipv6_nd_prefix" "ula_guest" {
  interface  = routeros_interface_vlan.vlan80-guest.name
  prefix     = local.ipv6_guest_ula_prefix
  on_link    = true
  autonomous = false
}
