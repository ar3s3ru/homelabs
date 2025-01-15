include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/nl/networking/tailscale"
  skip_outputs = true
}

dependency "prometheus" { # Necessary for data source.
  config_path  = "${get_path_to_repo_root()}/nl/telemetry/prometheus"
  skip_outputs = true
}
