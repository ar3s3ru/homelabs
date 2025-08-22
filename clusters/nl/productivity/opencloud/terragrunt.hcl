include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "productivity" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/productivity"
  skip_outputs = true
}

dependency "cert-manager" { # Necessary for TLS certificates.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/cert-manager"
  skip_outputs = true
}

dependency "cloudflare-ddns" { # Necessary to ensure DNS records are set.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/cloudflare-ddns"
  skip_outputs = true
}

dependency "authelia" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authelia"
  skip_outputs = true
  # mock_outputs = {
  #   ocis_client_id     = "mock-client-id"
  #   ocis_client_secret = "mock-client-secret"
  # }
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}

dependency "longhorn" { # Necessary for PVC provisioning.
  config_path = "${get_path_to_repo_root()}/clusters/nl/longhorn-system/longhorn"
  skip_outputs = true
}

locals {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
}

inputs = merge(
  local.secrets,
  {
      # "ocis.client_id.key"     = dependency.authelia.outputs.ocis_client_id
      # "ocis.client_secret.key" = dependency.authelia.outputs.ocis_client_secret
  }
)
