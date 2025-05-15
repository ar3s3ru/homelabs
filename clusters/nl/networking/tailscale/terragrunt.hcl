include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "networking" { # Creates the namespace
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking"
  skip_outputs = true
}

locals {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
}

inputs = merge(
  local.secrets,
  {
    # additional inputs
  }
)
