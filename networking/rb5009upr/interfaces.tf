resource "routeros_interface_bridge" "bridge" {
  name           = "bridge"
  comment        = "defconf"
  vlan_filtering = true
}

resource "routeros_interface_ethernet" "ether1" {
  factory_name = "ether1"
  name         = "ether1"
  comment      = "Office"
}

# resource "routeros_interface_list_member" "ether1" {
#   interface = "ether1"
#   list      = "LAN"
# }

resource "routeros_interface_ethernet" "ether2" {
  factory_name = "ether2"
  name         = "ether2"
  comment      = "Living Room (EAP245)"
}

resource "routeros_interface_ethernet" "ether3" {
  factory_name = "ether3"
  name         = "ether3"
  comment      = "Bedroom"
}

resource "routeros_interface_ethernet" "ether4" {
  factory_name = "ether4"
  name         = "ether4"
  comment      = "Living Room (E1-Zoom)"
}

resource "routeros_interface_ethernet" "ether5" {
  factory_name = "ether5"
  name         = "ether5"
}

resource "routeros_interface_ethernet" "ether6" {
  factory_name = "ether6"
  name         = "ether6"
}

resource "routeros_interface_ethernet" "ether7" {
  factory_name = "ether7"
  name         = "ether7"
}

resource "routeros_interface_ethernet" "ether8" {
  factory_name = "ether8"
  name         = "ether8"
  comment      = "WAN port"
}

resource "routeros_interface_ethernet" "sfp-sfpplus1" {
  factory_name = "sfp-sfpplus1"
  name         = "sfp-sfpplus1"
}
