include "root" {
  path = find_in_parent_folders("root.hcl")
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
