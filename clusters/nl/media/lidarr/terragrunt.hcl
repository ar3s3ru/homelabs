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

dependency "prowlarr" { # Ensure the indexer dependency is up.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/prowlarr"
  skip_outputs = true
}
