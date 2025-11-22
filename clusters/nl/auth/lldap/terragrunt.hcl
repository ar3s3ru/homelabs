include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "auth" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/auth"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}

dependency "victoriametrics" { # Needed for service monitors
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/victoriametrics"
  skip_outputs = true
}

locals {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
  credentials = yamldecode(sops_decrypt_file("credentials.yaml"))
}

inputs = merge(
  local.credentials,
  {
    secrets = local.secrets
  }
)
