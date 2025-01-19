generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}

provider "kubernetes" {
  config_path = "${get_path_to_repo_root()}/kubeconfig.yaml"
  config_context = "it"
}

provider "helm" {
  kubernetes {
    config_path = "${get_path_to_repo_root()}/kubeconfig.yaml"
    config_context = "it"
  }
}
  EOF
}

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

# locals {
#   tailscale_domain        = "tail2ff90.ts.net"
#   home_assistant_hostname = "nl-hass"
# }

# inputs = {
#   authentik_host          = "auth.nl.ar3s3ru.dev"
#   home_assistant_hostname = local.home_assistant_hostname
#   home_assistant_host     = "${local.home_assistant_hostname}.${local.tailscale_domain}"
#   jellyfin_host           = "jellyfin.nl.ar3s3ru.dev"
# }
