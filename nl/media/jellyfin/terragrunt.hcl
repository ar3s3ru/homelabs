include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "cert-manager" { # Necessary for TLS certificates.
  config_path  = "${get_path_to_repo_root()}/nl/networking/cert-manager"
  skip_outputs = true
}

dependency "cloudflare-ddns" { # Necessary to ensure DNS records are set.
  config_path  = "${get_path_to_repo_root()}/nl/networking/cloudflare-ddns"
  skip_outputs = true
}

dependency "intel-gpu" { # Necessary for hardware acceleration.
  config_path  = "${get_path_to_repo_root()}/nl/default/intel-gpu"
  skip_outputs = true
}

dependency "authentik" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/nl/auth/authentik"
}

inputs = {
  oauth_client_id     = dependency.authentik.outputs.jellyfin_client_id
  oauth_client_secret = dependency.authentik.outputs.jellyfin_client_secret
}
