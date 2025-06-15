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
    "auth.ar3s3ru.dev",
    "auth.nl.ar3s3ru.dev",
    "photos2.ar3s3ru.dev",
    "jellyfin.nl.ar3s3ru.dev",
    "jellyseerr.nl.ar3s3ru.dev"
  ]
}
