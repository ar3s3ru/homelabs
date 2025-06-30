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

dependency "minio-system" { # Necessary for data backend.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/minio-system"
}

inputs = {
  minio_access_key = dependency.minio-system.outputs.user_loki_access_key
  minio_secret_key = dependency.minio-system.outputs.user_loki_secret_key
}
