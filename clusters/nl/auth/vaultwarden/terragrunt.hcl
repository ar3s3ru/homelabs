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

dependency "authelia" { # Necessary for authentication.
  config_path = "${get_path_to_repo_root()}/clusters/nl/auth/authelia"
}

inputs = {
  secrets = merge(
    yamldecode(sops_decrypt_file("secrets.yaml")),
    # Additional secrets.
    {
      "sso-client-secret" = dependency.authelia.outputs.vaultwarden_client_secret
    }
  )
}
