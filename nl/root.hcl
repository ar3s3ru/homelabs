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
  config_path = "${path_relative_from_include()}/../kubeconfig.yaml"
  config_context = "nl"

  # NOTE: in case of loss of access to tailscale-operator, use this.
  # config_context = "nl-private-admin-init"
}

provider "helm" {
  kubernetes {
    config_path = "${path_relative_from_include()}/../kubeconfig.yaml"
    config_context = "nl"

    # NOTE: read the notes in the "kubernetes" provider.
    # config_context = "nl-private-admin-init"
  }
}
  EOF
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "kubernetes" {
    secret_suffix = "terraform-state"
    config_path   = "${path_relative_from_include()}/../kubeconfig.yaml"
    config_context = "nl"

    # NOTE: read the notes in the "kubernetes" provider.
    # config_context = "nl-private-admin-init"
  }
}
EOF
}
