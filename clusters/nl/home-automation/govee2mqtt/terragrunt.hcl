include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "home-automation" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/home-automation"
  skip_outputs = true
}

dependency "emqx" {
  config_path  = "${get_path_to_repo_root()}/clusters/nl/home-automation/emqx"
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
