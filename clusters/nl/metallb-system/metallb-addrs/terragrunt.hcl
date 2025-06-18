include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "metallb-system" { # For the MetalLB deployment.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/metallb-system"
  skip_outputs = true
}
