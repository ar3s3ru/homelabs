# IoT Network setup:
#   - No WAN access, fully airgapped
#   - VLAN 90
#   - 10.90.0.0/24 IPv4 subnet
#   - No IPv6 GUA, ULA only through DHCPv6
#   - LAN -> IOT allowed for home automation and monitoring

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
  address   = "10.90.0.1/24"
  interface = routeros_interface_vlan.vlan90-iot.name
}

resource "routeros_ip_pool" "pool-dhcp-v4-iot" {
  name    = "pool-dhcp-v4-iot"
  comment = "iot: DHCPv4 pool"
  ranges  = ["10.90.0.10-10.90.0.254"]
}

resource "routeros_ip_dhcp_server" "dhcp-v4-iot" {
  name         = "dhcp-v4-iot"
  comment      = "iot: DHCPv4 server"
  address_pool = routeros_ip_pool.pool-dhcp-v4-iot.name
  interface    = routeros_interface_vlan.vlan90-iot.name
  lease_time   = "30m"
}
