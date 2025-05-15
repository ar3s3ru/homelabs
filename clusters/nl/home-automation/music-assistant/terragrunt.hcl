include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "home-automation" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/home-automation"
  skip_outputs = true
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/tailscale"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}
