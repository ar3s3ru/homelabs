include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "kyverno" { # Needed to apply the NixOS patch for the Longhorn PATH value.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kyverno-system/kyverno"
  skip_outputs = true
}

inputs = {
  longhorn_crypto = yamldecode(sops_decrypt_file("crypto.yaml"))
}
