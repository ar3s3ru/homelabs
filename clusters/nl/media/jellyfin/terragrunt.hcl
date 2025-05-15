include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "media" { # Creates the namespace
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media"
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

dependency "intel-gpu" { # Necessary for hardware acceleration.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/intel-gpu"
  skip_outputs = true
}

dependency "authentik" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authentik-config"

  mock_outputs = {
    jellyfin_client_id = "mock-client-id"
    jellyfin_client_secret = "mock-client-secret"
  }
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}

inputs = {
  oauth_client_id     = dependency.authentik.outputs.jellyfin_client_id
  oauth_client_secret = dependency.authentik.outputs.jellyfin_client_secret
}
