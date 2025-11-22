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

dependency "victoriametrics" { # Needed for service monitors
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/victoriametrics"
  skip_outputs = true
}

# dependency "loki" { # Necessary for data source.
#   config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/loki"
#   skip_outputs = true
# }

dependency "authelia" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authelia"
}

inputs = {
  secrets_env = {
    "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET" = dependency.authelia.outputs.grafana_client_secret
  }
}
