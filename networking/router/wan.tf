variable "pppoe_kpn_username" {
  type        = string
  description = "The username for authenticating with the KPN PPPoE service"
}

variable "pppoe_kpn_password" {
  type        = string
  description = "The password for authenticating with the KPN PPPoE service"
  sensitive   = true
}

# KPN uses VLAN 6 for the WAN connection out of the ONT.
resource "routeros_interface_vlan" "vlan6-ether8" {
  interface = routeros_interface_ethernet.ether8.name
  name      = "vlan6-ether8"
  vlan_id   = 6
}

resource "routeros_interface_pppoe_client" "pppoe-kpn" {
  interface         = routeros_interface_vlan.vlan6-ether8.name
  name              = "pppoe-kpn"
  user              = var.pppoe_kpn_username
  password          = var.pppoe_kpn_password
  add_default_route = true
  use_peer_dns      = false
}

resource "routeros_interface_list" "wan" {
  name    = "WAN"
  comment = "defconf"
}

resource "routeros_interface_list_member" "wan_pppoe_kpn" {
  list      = routeros_interface_list.wan.name
  interface = routeros_interface_pppoe_client.pppoe-kpn.name
}

resource "routeros_interface_list_member" "wan_vlan6_ether8" {
  list      = routeros_interface_list.wan.name
  interface = routeros_interface_vlan.vlan6-ether8.name
}

# DHCPv6 client on the PPPoE interface — requests a /48 prefix delegation from
# KPN. The received prefix is added to pool-dhcp-v6-prefix-delegation, from
# which interface-specific GUA addresses are derived.
resource "routeros_ipv6_dhcp_client" "pppoe-kpn" {
  interface              = routeros_interface_pppoe_client.pppoe-kpn.name
  request                = ["prefix"]
  pool_name              = "pool-dhcp-v6-prefix-delegation"
  pool_prefix_length     = 64
  prefix_hint            = "::/0"
  add_default_route      = true
  default_route_distance = 1
  default_route_tables   = ["default"]
  use_peer_dns           = false
  allow_reconfigure      = true
  validate_server_duid   = true
}
