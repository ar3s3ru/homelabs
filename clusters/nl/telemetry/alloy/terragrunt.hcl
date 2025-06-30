include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "telemetry" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry"
  skip_outputs = true
}

dependency "loki" { # Necessary for data backend.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/loki"
  skip_outputs = true
}
