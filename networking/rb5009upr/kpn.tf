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
