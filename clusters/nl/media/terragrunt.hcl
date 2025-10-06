include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "democratic-csi" { # Necessary for library PVC provisioning.
  config_path = "${get_path_to_repo_root()}/clusters/nl/democratic-csi"
  skip_outputs = true
}
