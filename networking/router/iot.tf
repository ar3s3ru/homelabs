# IoT Network setup:
#   - No WAN access, fully airgapped
#   - VLAN 90
#   - 10.90.0.0/24 IPv4 subnet
#   - No IPv6 GUA, ULA only through DHCPv6
#   - LAN -> IOT allowed for home automation and monitoring

locals {
  ipv4_iot_address_cidr    = "10.90.0.1/24"
  ipv4_iot_network         = "10.90.0.0"
  ipv4_iot_address_gateway = "10.90.0.1"
  ipv4_iot_dhcp_pool       = "10.90.0.10-10.90.0.254"

  ipv6_iot_ula_prefix = "fd00:cafe:90::/64"
  ipv6_iot_ula_addr   = "fd00:cafe:90::1"
}

resource "routeros_interface_vlan" "vlan90-iot" {
  name      = "vlan90-iot"
  comment   = "iot network"
  interface = routeros_interface_bridge.bridge.name
  vlan_id   = 90
}

resource "routeros_interface_list" "iot" {
  name    = "IOT"
  comment = "iot: IoT interface list"
}

resource "routeros_interface_list_member" "iot_vlan90" {
  list      = routeros_interface_list.iot.name
  interface = routeros_interface_vlan.vlan90-iot.name
}

resource "routeros_interface_bridge_vlan" "vlan90-iot" {
  bridge   = routeros_interface_bridge.bridge.name
  vlan_ids = ["${routeros_interface_vlan.vlan90-iot.vlan_id}"]
  tagged = [
    routeros_interface_bridge.bridge.name,
    routeros_interface_ethernet.ether2.name,
    routeros_interface_ethernet.ether5.name
  ]
  untagged = ["none"]
}

resource "routeros_interface_bridge_port" "ether4" {
  bridge    = routeros_interface_bridge.bridge.name
  interface = routeros_interface_ethernet.ether4.name
  pvid      = routeros_interface_vlan.vlan90-iot.vlan_id
  comment   = "E1-Zoom camera with physical Ethernet cable to vlan90-iot"
}

# IPv4 networking --------------------------------------------------------------

resource "routeros_ip_address" "vlan90-iot" {
  comment   = "iot network"
  address   = local.ipv4_iot_address_cidr
  interface = routeros_interface_vlan.vlan90-iot.name
}

resource "routeros_ip_pool" "pool-dhcp-v4-iot" {
  name    = "pool-dhcp-v4-iot"
  comment = "iot: DHCPv4 pool"
  ranges  = [local.ipv4_iot_dhcp_pool]
}

resource "routeros_ip_dhcp_server" "dhcp-v4-iot" {
  name         = "dhcp-v4-iot"
  comment      = "iot: DHCPv4 server"
  address_pool = routeros_ip_pool.pool-dhcp-v4-iot.name
  interface    = routeros_interface_vlan.vlan90-iot.name
  lease_time   = "30m"
}

resource "routeros_ip_dhcp_server_network" "iot" {
  address    = "${local.ipv4_iot_network}/24"
  gateway    = local.ipv4_iot_address_gateway
  dns_server = [local.ipv4_iot_address_gateway]
  comment    = "iot: DHCPv4 network"
}

# IPv6 networking --------------------------------------------------------------

# IoT is fully airgapped — no GUA address (the network has no upstream IPv6
# connectivity), only ULA. Clients get ULA via stateful DHCPv6 for static
# bindings (no autonomous SLAAC).


# ULA pool for static DHCPv6 bindings on the IoT network.
resource "routeros_ipv6_pool" "pool-dhcp-v6-ula-iot" {
  name          = "pool-dhcp-v6-ula-iot"
  prefix        = local.ipv6_iot_ula_prefix
  prefix_length = 128
}

# Router ULA address on the IoT VLAN.
resource "routeros_ipv6_address" "ula_iot" {
  interface = routeros_interface_vlan.vlan90-iot.name
  address   = "${local.ipv6_iot_ula_addr}/64"
  advertise = false
  comment   = "iot: ULA addresses"
}

# DHCPv6 option 23 (DNS servers, RFC 3646) carrying the IoT router ULA.
# Value is the 16-byte network-order hex encoding of fd00:cafe:90::1.
resource "routeros_ipv6_dhcp_server_option" "dns-iot" {
  name  = "dns-server-iot"
  code  = 23
  value = "0xfd00cafe009000000000000000000001"
}

resource "routeros_ipv6_dhcp_server" "dhcp-v6-ula-iot" {
  name         = "dhcp-v6-ula-iot"
  interface    = routeros_interface_vlan.vlan90-iot.name
  address_pool = routeros_ipv6_pool.pool-dhcp-v6-ula-iot.name
  prefix_pool  = "static-only"
  lease_time   = "3d"
  rapid_commit = true
  preference   = 255
  dhcp_option  = [routeros_ipv6_dhcp_server_option.dns-iot.name]
}

resource "routeros_ipv6_neighbor_discovery" "iot" {
  interface                     = routeros_interface_vlan.vlan90-iot.name
  managed_address_configuration = true
  other_configuration           = true
  advertise_dns                 = false # No RA RDNSS, we use DHCPv6 for it.
}

# Advertise the ULA prefix on-link (autonomous=false because addressing is
# handled by stateful DHCPv6, not SLAAC).
resource "routeros_ipv6_nd_prefix" "ula_iot" {
  interface  = routeros_interface_vlan.vlan90-iot.name
  prefix     = local.ipv6_iot_ula_prefix
  on_link    = true
  autonomous = false
}

# Firewall address-list entries -----------------------------------------------

locals {
  ipv4_address_lists_iot = {
    (local.address_list_internal_ipv4) = [
      { address = "${local.ipv4_iot_network}/24", comment = "iot: internal IPv4 supernet" },
    ]
  }

  ipv4_address_entries_iot = merge([
    for list_name, entries in local.ipv4_address_lists_iot : {
      for e in entries : "${list_name}/${e.address}" => merge({ list = list_name }, e)
    }
  ]...)
}

resource "routeros_ip_firewall_addr_list" "iot" {
  for_each = local.ipv4_address_entries_iot
  list     = each.value.list
  address  = each.value.address
  comment  = lookup(each.value, "comment", null)
}

# Static DHCP leases ----------------------------------------------------------
#
# NOTE: DHCPv6 static leases not supported by terraform-routeros yet, leaving
# these as documentation mostly. Check the router directly for the actual
# source of truth.

locals {
  iot_leases_by_mac_address = {
    "CC:7B:5C:4B:EF:8F" = { v4 = "10.90.0.253", v6_ula = null, v6_duid = null, comment = "slimmelezer" }
    "EC:71:DB:59:96:BB" = { v4 = "10.90.0.12", v6_ula = null, v6_duid = null, comment = "e1-zoom-02" }
    "24:3F:75:DD:7D:FB" = { v4 = "10.90.0.11", v6_ula = null, v6_duid = null, comment = "e1-zoom-01" }
    "DC:DA:0C:28:B1:20" = { v4 = "10.90.0.13", v6_ula = null, v6_duid = null, comment = "Bambu Lab P1S" }
  }
}

resource "routeros_ip_dhcp_server_lease" "iot" {
  for_each    = local.iot_leases_by_mac_address
  address     = each.value.v4
  comment     = each.value.comment
  mac_address = each.key
  server      = routeros_ip_dhcp_server.dhcp-v4-iot.name

  lifecycle {
    ignore_changes = [client_id, block_access]
  }
}
