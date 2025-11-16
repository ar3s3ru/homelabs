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

dependency "longhorn-system" { # Necessary for PVC provisioning.
  config_path = "${get_path_to_repo_root()}/clusters/nl/longhorn-system"
  skip_outputs = true
}

dependency "cert-manager" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/networking/cert-manager"
  skip_outputs = true
}

dependency "cloudflare-ddns" {
  config_path = "${get_path_to_repo_root()}/clusters/nl/networking/cloudflare-ddns"
  skip_outputs = true
}

inputs = {
  secrets = merge(
    yamldecode(sops_decrypt_file("secrets.yaml")),
    {}
  )
}
