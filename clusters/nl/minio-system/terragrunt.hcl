include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "longhorn" { # Necessary for persistent storage.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/longhorn-system/longhorn"
  skip_outputs = true
}
