variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token to use for DNS01 challenges"
  sensitive   = true
}

module "cloudflare_ddns" {
  source               = "../../../../modules/cloudflare-ddns"
  kubernetes_namespace = "networking"
  api_token            = var.cloudflare_api_token
  domains = [
    "jellyfin.it.ar3s3ru.dev",
    "photos.ar3s3ru.dev"
  ]
}
