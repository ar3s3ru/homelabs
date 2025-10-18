include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "media" { # Creates the namespace
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}

dependency "metallb-system" { # For the LoadBalancer service.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/metallb-system"
  skip_outputs = true
}

dependency "longhorn" { # For persistent storage.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/longhorn-system/longhorn"
  skip_outputs = true
}
