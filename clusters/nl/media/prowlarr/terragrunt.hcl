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

dependency "qbittorrent" { # Ensure the torrent dependency is up.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/qbittorrent"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}

dependency "flaresolverr" { # Necessary for solving Cloudflare challenges.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/flaresolverr"
  skip_outputs = true
}
