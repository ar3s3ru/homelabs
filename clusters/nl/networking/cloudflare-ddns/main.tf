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
    "idp.cianfr.one",
    "photos.cianfr.one",
    "media.cianfr.one",
    "vault.cianfr.one",
    "requests.cianfr.one"
  ]
}
