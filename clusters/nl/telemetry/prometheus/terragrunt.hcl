include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "telemetry" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry"
  skip_outputs = true
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/tailscale"
  skip_outputs = true
}
