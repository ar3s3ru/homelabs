generate "provider_variables" {
  path      = "provider_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "kubernetes_context" {
  type        = string
  description = "Cluster context for Kubernetes access"
}
  EOF
}

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}

provider "kubernetes" {
  config_path    = "${get_path_to_repo_root()}/clusters/kubeconfig.yaml"
  config_context = var.kubernetes_context
}

provider "helm" {
  kubernetes {
    config_path    = "${get_path_to_repo_root()}/clusters/kubeconfig.yaml"
    config_context = var.kubernetes_context
  }
}
  EOF
}
