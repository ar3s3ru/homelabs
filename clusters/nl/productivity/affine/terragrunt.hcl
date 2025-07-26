include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "productivity" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/productivity"
  skip_outputs = true
}
