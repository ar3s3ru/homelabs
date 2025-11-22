include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "victoriametrics" { # Needed for service monitors
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/victoriametrics"
  skip_outputs = true
}
