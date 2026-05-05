include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "routeros" {
  path = find_in_parent_folders("routeros.hcl")
}

locals {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
}

inputs = {
  routeros_hosturl  = local.secrets.routeros_hosturl
  routeros_username = local.secrets.routeros_username
  routeros_password = local.secrets.routeros_password
  pppoe_kpn_username = local.secrets.pppoe_kpn_username
  pppoe_kpn_password = local.secrets.pppoe_kpn_password
}
