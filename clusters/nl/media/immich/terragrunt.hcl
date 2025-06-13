include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "media" { # Creates the namespace.
  config_path = "${get_path_to_repo_root()}/clusters/nl/media"
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

dependency "rook-ceph-cluster" { # Necessary for rook-ceph storage provisioning.
  config_path = "${get_path_to_repo_root()}/clusters/nl/rook-ceph/rook-ceph-cluster"
  skip_outputs = true
}

inputs = {
  oauth_client_secret = dependency.authelia.outputs.immich_client_secret
}
