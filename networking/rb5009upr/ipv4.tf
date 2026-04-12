locals {
  ipv4_local_address_cidr    = "10.0.0.1/16"
  ipv4_local_network         = "10.0.0.0"
  ipv4_local_address_gateway = "10.0.0.1"
  ipv4_local_dhcp_pool       = "10.0.0.100-10.0.0.254"
}

resource "routeros_ip_address" "ipv4_local" {
  address   = local.ipv4_local_address_cidr
  interface = routeros_interface_bridge.bridge.name
  network   = local.ipv4_local_network
  comment   = "defconf" # FIXME(ar3s3ru): should change this?
}

resource "routeros_ip_pool" "pool-dhcp-v4" {
  name   = "pool-dhcp-v4"
  ranges = [local.ipv4_local_dhcp_pool]
}

resource "routeros_ip_dhcp_server" "dhcp-v4" {
  name            = "defconf"
  interface       = routeros_interface_bridge.bridge.name
  address_pool    = routeros_ip_pool.pool-dhcp-v4.name
  use_reconfigure = true
}

locals {
  ipv4_local_leases_by_mac_address = {
    "04:F4:1C:84:3C:E8" = { addr : "10.0.0.2", comment : "CRS310-8G+2S+" }
    "7C:F1:7E:74:FD:6E" = { addr : "10.0.0.3", comment : "EAP-245" }
    "34:97:F6:3E:A5:50" = { addr : "10.0.0.4", comment : "ASUS AP" }
    "AE:15:95:A0:DC:09" = { addr : "10.0.0.5", comment : "NanoPi R5C" }
    "DC:DA:0C:28:B1:20" = { addr : "10.0.0.10", comment : "Bambu Lab P1S" }
    "CC:7B:5C:4B:EF:8F" = { addr : "10.0.0.11", comment : "Slimmelezer" }
    "44:07:0B:90:CE:B6" = { addr : "10.0.0.12", comment : "Google Home Mini" }
    "24:3F:75:DD:7D:FB" = { addr : "10.0.0.20", comment : "E1-Zoom-01" }
    "EC:71:DB:59:96:BB" = { addr : "10.0.0.21", comment : "E1-Zoom-02" }
    "F8:B9:5A:65:E2:36" = { addr : "10.0.0.179", comment : "LG BX 55" }
    "BC:24:11:DE:69:E3" = { addr : "10.0.1.20", comment : "nl-pve-01 TrueNAS" }
    "6C:1F:F7:57:07:49" = { addr : "10.0.1.1", comment : "nl-k8s-01" }
    "BC:24:11:A2:94:61" = { addr : "10.0.1.2", comment : "nl-k8s-02" }
    "BC:24:11:07:69:C7" = { addr : "10.0.1.3", comment : "nl-k8s-03" }
    "54:E1:AD:A5:1D:0F" = { addr : "10.0.1.4", comment : "nl-k8s-04" }
    "58:47:CA:7F:76:99" = { addr : "10.0.2.1", comment : "nl-pve-01" }
    "98:FA:9B:13:C8:E8" = { addr : "10.0.2.2", comment : "nl-pve-02" }
  }
}

resource "routeros_ip_dhcp_server_lease" "dhcp-v4-lease" {
  for_each    = local.ipv4_local_leases_by_mac_address
  address     = each.value.addr
  comment     = each.value.comment
  mac_address = each.key
  server      = routeros_ip_dhcp_server.dhcp-v4.name

  lifecycle {
    ignore_changes = [client_id, block_access]
  }
}
