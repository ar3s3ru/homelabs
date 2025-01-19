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

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/nl/default/reloader"
  skip_outputs = true
}

dependency "emqx" {
  config_path  = "${get_path_to_repo_root()}/nl/home-automation/emqx"
  skip_outputs = true
}

dependency "govee2mqtt" {
  config_path  = "${get_path_to_repo_root()}/nl/home-automation/govee2mqtt"
  skip_outputs = true
}

dependency "authentik" {
  config_path = "${get_path_to_repo_root()}/nl/auth/authentik"
}

inputs = {
  oauth_client_id     = dependency.authentik.outputs.home_assistant_client_id
  oauth_client_secret = dependency.authentik.outputs.home_assistant_client_secret
}
