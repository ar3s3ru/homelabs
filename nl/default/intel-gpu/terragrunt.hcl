include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "cert-manager" { # Necessary for TLS certificates.
  config_path  = "${get_path_to_repo_root()}/nl/networking/cert-manager"
  skip_outputs = true
}

dependency "node-feature-discovery" { # Necessary for GPU detection.
  config_path  = "${get_path_to_repo_root()}/nl/default/node-feature-discovery"
  skip_outputs = true
}
