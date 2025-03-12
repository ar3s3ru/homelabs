include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/nl/networking/tailscale"
  skip_outputs = true
}

dependency "emqx" { # Necessary for MQTT broker.
  config_path  = "${get_path_to_repo_root()}/nl/home-automation/emqx"
  skip_outputs = true
}
