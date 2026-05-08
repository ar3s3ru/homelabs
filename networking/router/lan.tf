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

resource "routeros_ip_dhcp_server_network" "lan" {
  address    = "${local.ipv4_lan_network}/16"
  gateway    = local.ipv4_lan_address_gateway
  dns_server = [local.ipv4_lan_address_gateway]
  domain     = "home.arpa"
  comment    = "defconf"
}

# IPv6 networking --------------------------------------------------------------

resource "routeros_ipv6_pool" "pool-dhcp-v6-ula-lan" {
  name          = "pool-dhcp-v6-ula-lan"
  prefix        = local.ipv6_lan_ula_prefix
  prefix_length = 128
}

resource "routeros_ipv6_address" "ula_lan" {
  interface = routeros_interface_bridge.bridge.name
  address   = "${local.ipv6_lan_ula_addr}/64"
  advertise = false
}

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

# DHCPv6 option 23 (DNS servers, RFC 3646) carrying the LAN router ULA.
# Value is the 16-byte network-order hex encoding of fd00:cafe::1.
resource "routeros_ipv6_dhcp_server_option" "dns-lan" {
  name  = "dns-server-lan"
  code  = 23
  value = "0xfd00cafe000000000000000000000001"
}

resource "routeros_ipv6_dhcp_server" "dhcp-v6-ula-lan" {
  name         = "dhcp-v6-ula-lan"
  interface    = routeros_interface_bridge.bridge.name
  address_pool = routeros_ipv6_pool.pool-dhcp-v6-ula-lan.name
  prefix_pool  = "static-only"
  lease_time   = "3d"
  rapid_commit = true
  preference   = 255
  dhcp_option  = [routeros_ipv6_dhcp_server_option.dns-lan.name]
}

resource "routeros_ipv6_neighbor_discovery" "lan" {
  interface                     = routeros_interface_bridge.bridge.name
  managed_address_configuration = true
  other_configuration           = true
  advertise_dns                 = false # No RA RDNSS, we use DHCPv6 for it.
}

# Advertise the ULA prefix on-link (autonomous=false because addressing is
# handled by stateful DHCPv6, not SLAAC).
resource "routeros_ipv6_nd_prefix" "ula_lan" {
  interface  = routeros_interface_bridge.bridge.name
  prefix     = local.ipv6_lan_ula_prefix
  on_link    = true
  autonomous = false
}

# Firewall address-list entries -----------------------------------------------

locals {
  # Internal-IPv4 supernet aggregate covering all locally-managed VLANs
  # (LAN, guest, IoT). Replaces the older defconf "ipv4-local" (10.0.0.0/8)
  # with a tighter, explicit definition that only matches actually-used
  # subnets. Firewall rules should prefer this over ipv4-local.
  address_list_internal_ipv4 = "internal-ipv4"

  # MetalLB-assigned LoadBalancer IPs for k8s services exposed on the LAN.
  # IPs are hardcoded here to mirror MetalLB IPAddressPool config in
  # kube/networking/metallb. If those change, both sides must be updated.
  # NOTE: These are referenced by manually-configured firewall rules on the
  # router (port-forwarding to ingress-nginx, slskd, qbittorrent).
  address_list_k8s_ingress = "ipv4-k8s-ingress-controller"
  address_list_slskd       = "ipv4-slskd"
  address_list_qbittorrent = "ipv4-qbittorrent"

  address_list_k8s_ingress_v6 = "ipv6-k8s-ingress-controller"
  address_list_slskd_v6       = "ipv6-slskd"
  address_list_qbittorrent_v6 = "ipv6-qbittorrent"

  ipv4_address_lists_lan = {
    (local.address_list_internal_ipv4) = [
      { address = "${local.ipv4_lan_network}/16", comment = "lan: internal IPv4 supernet" },
    ]
    (local.address_list_k8s_ingress) = [
      { address = "10.0.3.1" },
    ]
    (local.address_list_slskd) = [
      { address = "10.0.3.2" },
    ]
    (local.address_list_qbittorrent) = [
      { address = "10.0.3.3" },
    ]
  }

  ipv6_address_lists_lan = {
    (local.address_list_k8s_ingress_v6) = [
      # FIXME(ar3s3ru): Hardcoded KPN GUA prefix. Must update after moving to new ISP.
      { address = "2a02:a469:9060:3::1", comment = "k8s: ingress-nginx GUA" },
    ]
    (local.address_list_slskd_v6) = [
      # FIXME(ar3s3ru): Hardcoded KPN GUA prefix. Must update after moving to new ISP.
      { address = "2a02:a469:9060:3::2", comment = "k8s: slskd GUA" },
    ]
    (local.address_list_qbittorrent_v6) = [
      # FIXME(ar3s3ru): Hardcoded KPN GUA prefix. Must update after moving to new ISP.
      { address = "2a02:a469:9060:3::3", comment = "k8s: qbittorrent GUA" },
    ]
  }

  ipv4_address_entries_lan = merge([
    for list_name, entries in local.ipv4_address_lists_lan : {
      for e in entries : "${list_name}/${e.address}" => merge({ list = list_name }, e)
    }
  ]...)

  ipv6_address_entries_lan = merge([
    for list_name, entries in local.ipv6_address_lists_lan : {
      for e in entries : "${list_name}/${e.address}" => merge({ list = list_name }, e)
    }
  ]...)
}

resource "routeros_ip_firewall_addr_list" "lan" {
  for_each = local.ipv4_address_entries_lan
  list     = each.value.list
  address  = each.value.address
  comment  = lookup(each.value, "comment", null)
}

resource "routeros_ipv6_firewall_addr_list" "lan" {
  for_each = local.ipv6_address_entries_lan
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
  lan_leases_by_mac_address = {
    "04:F4:1C:84:3C:E8" = { v4 = "10.0.0.2", v6_ula = null, v6_duid = null, comment = "CRS310-8G+2S+" }
    "7C:F1:7E:74:FD:6E" = { v4 = "10.0.0.3", v6_ula = null, v6_duid = null, comment = "EAP-245" }
    "34:97:F6:3E:A5:50" = { v4 = "10.0.0.4", v6_ula = null, v6_duid = null, comment = "ASUS AP" }
    "AE:15:95:A0:DC:09" = { v4 = "10.0.0.5", v6_ula = "fd00:cafe::1:e", v6_duid = "0xae1595a0dc09", comment = "NanoPi R5C" }
    "44:07:0B:90:CE:B6" = { v4 = "10.0.0.12", v6_ula = null, v6_duid = null, comment = "Google Home Mini" }
    "BC:24:11:DE:69:E3" = { v4 = "10.0.1.20", v6_ula = null, v6_duid = null, comment = "nl-pve-01 TrueNAS" }
    "6C:1F:F7:57:07:49" = { v4 = "10.0.1.1", v6_ula = "fd00:cafe::1:1", v6_duid = "0x30cc9a646c1ff7570749", comment = "nl-k8s-01" }
    "BC:24:11:A2:94:61" = { v4 = "10.0.1.2", v6_ula = "fd00:cafe::1:2", v6_duid = "0x30cc9793bc2411a29461", comment = "nl-k8s-02" }
    "BC:24:11:07:69:C7" = { v4 = "10.0.1.3", v6_ula = "fd00:cafe::1:3", v6_duid = "0x30cc94bbbc24110769c7", comment = "nl-k8s-03" }
    "54:E1:AD:A5:1D:0F" = { v4 = "10.0.1.4", v6_ula = "fd00:cafe::1:4", v6_duid = "0x30ae39387a830ccf2c25", comment = "nl-k8s-04" }
    "58:47:CA:7F:76:99" = { v4 = "10.0.2.1", v6_ula = null, v6_duid = null, comment = "nl-pve-01" }
    "98:FA:9B:13:C8:E8" = { v4 = "10.0.2.2", v6_ula = null, v6_duid = null, comment = "nl-pve-02" }
  }
}

resource "routeros_ip_dhcp_server_lease" "lan" {
  for_each    = local.lan_leases_by_mac_address
  address     = each.value.v4
  comment     = each.value.comment
  mac_address = each.key
  server      = routeros_ip_dhcp_server.dhcp-v4.name

  lifecycle {
    ignore_changes = [client_id, block_access]
  }
}

