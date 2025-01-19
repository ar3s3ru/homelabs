# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
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
  config_path = "../../kubeconfig.yaml"
  config_context = var.kubernetes_context
}

provider "helm" {
  kubernetes {
    config_path = "../../kubeconfig.yaml"
    config_context = var.kubernetes_context
  }
}
