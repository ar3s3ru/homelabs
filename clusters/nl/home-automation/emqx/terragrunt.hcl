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
