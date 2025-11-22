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

dependency "lldap" { # Necessary for the authorization backend.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/auth/lldap"
  skip_outputs = true
}

dependency "victoriametrics" { # Needed for service monitors
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/victoriametrics"
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

inputs = {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
  oidc_client_secrets = yamldecode(sops_decrypt_file("oidc-client-secrets.yaml"))
}
