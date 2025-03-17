include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/tailscale"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}

dependency "authentik" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authentik"
}

dependency "emqx" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/home-automation/emqx"
  skip_outputs = true
}

dependency "zigbee2mqtt" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/home-automation/zigbee2mqtt"
  skip_outputs = true
}

dependency "govee2mqtt" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/home-automation/govee2mqtt"
  skip_outputs = true
}

dependency "music-assistant" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/home-automation/music-assistant"
  skip_outputs = true
}

inputs = {
  oauth_client_id     = dependency.authentik.outputs.home_assistant_client_id
  oauth_client_secret = dependency.authentik.outputs.home_assistant_client_secret
}
