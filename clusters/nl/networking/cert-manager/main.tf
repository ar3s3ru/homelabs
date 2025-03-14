variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token to use for DNS01 challenges"
  sensitive   = true
}

module "cert_manager" {
  source               = "../../../../modules/cert-manager"
  kubernetes_namespace = "networking"
  cloudflare_api_token = var.cloudflare_api_token
}
