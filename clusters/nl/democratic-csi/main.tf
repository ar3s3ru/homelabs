locals {
  namespace = "democratic-csi"
}

variable "truenas_api_key" {
  type        = string
  description = "API key for TrueNAS Scale for democratic-csi driver ot use"
  sensitive   = true
}

resource "helm_release" "truenas_nfs" {
  name       = "truenas-nfs"
  repository = "https://democratic-csi.github.io/charts/"
  chart      = "democratic-csi"
  # version          = "0.14.6"
  namespace        = local.namespace
  cleanup_on_fail  = true
  create_namespace = true

  values = [
    file("${path.module}/values.yaml")
  ]

  set_sensitive {
    name  = "driver.config.httpConnection.apiKey"
    value = var.truenas_api_key
  }
}
