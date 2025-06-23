variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where to deploy the module resources"
}

variable "api_token" {
  type        = string
  description = "Tailscale OAuth client ID for the Kubernetes operator"
  sensitive   = true
}

variable "domains" {
  type        = list(string)
  description = "List of domains to update on Cloudflare"
}

resource "kubernetes_secret_v1" "cloudflare_ddns_secrets" {
  metadata {
    name      = "cloudflare-ddns-secrets"
    namespace = var.kubernetes_namespace
  }

  data = {
    CLOUDFLARE_API_TOKEN = var.api_token
  }
}

resource "kubernetes_config_map_v1" "cloudflare_ddns_env" {
  metadata {
    name      = "cloudflare-ddns-env"
    namespace = var.kubernetes_namespace
  }

  data = {
    "DOMAINS" = join(",", var.domains)
  }
}

resource "helm_release" "cloudflare_ddns" {
  name            = "cloudflare-ddns"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = var.kubernetes_namespace
  version         = "4.1.1"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}
