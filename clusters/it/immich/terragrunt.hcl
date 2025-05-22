include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/tailscale"
  skip_outputs = true
}

dependency "authentik" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authentik-config"
}

inputs = {
  oauth_client_id     = dependency.authentik.outputs.immich_client_id
  oauth_client_secret = dependency.authentik.outputs.immich_client_secret
}
