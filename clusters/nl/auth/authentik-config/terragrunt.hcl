include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "authentik" {
  config_path  = "${get_path_to_repo_root()}/clusters/nl/auth/authentik"
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
