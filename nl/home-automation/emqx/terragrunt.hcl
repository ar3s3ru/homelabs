include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "home-automation-common" {
  config_path  = "${get_path_to_repo_root()}/nl/home-automation/home-automation-common"
  skip_outputs = true
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/nl/networking/tailscale"
  skip_outputs = true
}
