include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

locals {
  driver_config_file_yaml = sops_decrypt_file("driver-config-file.yaml")
}

inputs = {
  driver_config_file_yaml = local.driver_config_file_yaml
}
