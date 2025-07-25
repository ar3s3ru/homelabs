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

dependency "prowlarr" { # Ensure the indexer dependency is up.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/prowlarr"
  skip_outputs = true
}

dependency "radarr" { # Ensure the movie dependency is up.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/radarr"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}
