include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

inputs = merge(
  yamldecode(sops_decrypt_file("secrets.yaml")),
  {
    # Additional inputs.
  }
)
