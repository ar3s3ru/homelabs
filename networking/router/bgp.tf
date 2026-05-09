locals {
  k8s_nodes = {
    "nl-k8s-01" = { v4 = "10.0.1.1", v6 = "fd00:cafe::1:1" }
    "nl-k8s-02" = { v4 = "10.0.1.2", v6 = "fd00:cafe::1:2" }
    "nl-k8s-03" = { v4 = "10.0.1.3", v6 = "fd00:cafe::1:3" }
    "nl-k8s-04" = { v4 = "10.0.1.4", v6 = "fd00:cafe::1:4" }
  }
}

resource "routeros_routing_bgp_connection" "metallb_v4" {
  for_each = local.k8s_nodes

  name             = "metallb-${each.key}-v4"
  as               = "64512"
  address_families = "ip"
  use_bfd          = false

  remote {
    address = each.value.v4
    as      = "64512"
    port    = 179
  }

  local {
    address = "10.0.0.1"
    role    = "ibgp"
    port    = 179
  }

  connect = true
  listen  = true
}

resource "routeros_routing_bgp_connection" "metallb_v6" {
  for_each = local.k8s_nodes

  name             = "metallb-${each.key}-v6"
  as               = "64512"
  address_families = "ipv6"
  use_bfd          = false

  remote {
    address = each.value.v6
    as      = "64512"
    port    = 179
  }

  local {
    address = "fd00:cafe::1"
    role    = "ibgp"
    port    = 179
  }

  connect = true
  listen  = true
}
