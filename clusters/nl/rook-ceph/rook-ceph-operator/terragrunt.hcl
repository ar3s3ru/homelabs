include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "rook-ceph" { # Creates the namespace
  config_path  = "${get_path_to_repo_root()}/clusters/nl/rook-ceph"
  skip_outputs = true
}

dependency "prometheus" { # Needed for ServiceMonitors.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/prometheus"
  skip_outputs = true
}
