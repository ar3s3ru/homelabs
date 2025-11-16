include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "media" { # Creates the namespace.
  config_path = "${get_path_to_repo_root()}/clusters/nl/media"
  skip_outputs = true
}

dependency "authelia" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authelia"
}

dependency "cert-manager" { # Necessary for HTTPS certificates.
  config_path = "${get_path_to_repo_root()}/clusters/nl/networking/cert-manager"
  skip_outputs = true
}

dependency "cloudflare-ddns" { # Necessary for DNS entry.
  config_path = "${get_path_to_repo_root()}/clusters/nl/networking/cloudflare-ddns"
  skip_outputs = true
}

dependency "longhorn-system" { # Necessary for PVC provisioning.
  config_path = "${get_path_to_repo_root()}/clusters/nl/longhorn-system"
  skip_outputs = true
}

dependency "democratic-csi" { # Necessary for library PVC provisioning.
  config_path = "${get_path_to_repo_root()}/clusters/nl/democratic-csi"
  skip_outputs = true
}

dependency "cnpg-system" { # Necessary for PostgreSQL cluster provisioning
  config_path = "${get_path_to_repo_root()}/clusters/nl/cnpg-system"
  skip_outputs = true
}

dependency "redis-system" { # Necessary for Redis cluster provisioning
  config_path = "${get_path_to_repo_root()}/clusters/nl/redis-system"
  skip_outputs = true
}

inputs = {
  oauth_client_secret = dependency.authelia.outputs.immich_client_secret
}
