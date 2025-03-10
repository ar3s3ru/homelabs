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

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/nl/default/reloader"
  skip_outputs = true
}

dependency "authentik" {
  config_path = "${get_path_to_repo_root()}/nl/auth/authentik"
}

inputs = {
  oauth_client_id     = dependency.authentik.outputs.home_assistant_client_id
  oauth_client_secret = dependency.authentik.outputs.home_assistant_client_secret
}
