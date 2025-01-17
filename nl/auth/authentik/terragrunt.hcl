include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "cloudflare" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/external/cloudflare"
  skip_outputs = true
}

dependency "cert-manager" { # Necessary for TLS certificates.
  config_path  = "${get_path_to_repo_root()}/nl/networking/cert-manager"
  skip_outputs = true
}
