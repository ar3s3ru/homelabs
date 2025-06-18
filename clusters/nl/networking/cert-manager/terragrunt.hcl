include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "metallb-system" { # MetalLB gives out an IP address to Traefik, which uses CertManager certificate.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/metallb-system"
  skip_outputs = true
}

dependency "prometheus" { # Needed for service monitors
  config_path  = "${get_path_to_repo_root()}/clusters/nl/telemetry/prometheus"
  skip_outputs = true
}

locals {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
}

inputs = merge(
  local.secrets,
  {
    # additional inputs
  }
)
