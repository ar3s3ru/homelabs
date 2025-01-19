generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "kubernetes" {
    secret_suffix = "${basename(get_working_dir())}"
    config_path   = "${get_path_to_repo_root()}/kubeconfig.yaml"
    config_context = "it"
  }
}
EOF
}

locals {
  tailscale_domain = "tail2ff90.ts.net"
}

inputs = {
  kubernetes_context = "it"
  authentik_host     = "auth.nl.ar3s3ru.dev"
}
