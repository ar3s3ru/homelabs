locals {
  namespace = "networking"
}

variable "ar3s3ru_dev_cloudflare_api_token" {
  type        = string
  description = "ar3s3ru.dev Cloudflare API token to use for DNS01 challenges"
  sensitive   = true
}

variable "cianfr_one_cloudflare_api_token" {
  type        = string
  description = "cianfr.one Cloudflare API token to use for DNS01 challenges"
  sensitive   = true
}

variable "deprecated_cloudflare_api_token" {
  type        = string
  description = "(Deprecated) All Zones Cloudflare API token to use for DNS01 challenges"
  sensitive   = true
}

resource "helm_release" "cert_manager" {
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  namespace       = local.namespace
  version         = "v1.18.2"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}

resource "kubernetes_secret" "cert_manager_cloudflare_tokens" {
  metadata {
    name      = "cert-manager-cloudflare-tokens"
    namespace = local.namespace
  }

  data = {
    "all-zones"   = var.deprecated_cloudflare_api_token
    "ar3s3ru.dev" = var.ar3s3ru_dev_cloudflare_api_token
    "cianfr.one"  = var.cianfr_one_cloudflare_api_token
  }
}

resource "kubernetes_manifest" "cert_manager_cluster_issuers" {
  for_each = fileset("${path.module}/cluster-issuers", "*.yaml")
  manifest = yamldecode(file("${path.module}/cluster-issuers/${each.value}"))

  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.cert_manager_cloudflare_tokens
  ]
}
