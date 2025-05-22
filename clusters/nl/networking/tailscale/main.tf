variable "oauth_client_id" {
  type        = string
  description = "Tailscale OAuth client ID for the Kubernetes operator"
  sensitive   = true
}

variable "oauth_client_secret" {
  type        = string
  description = "Tailscale OAuth client secret for the Kubernetes operator"
  sensitive   = true
}

module "tailscale" {
  source               = "../../../../modules/tailscale"
  kubernetes_namespace = "networking"
  operator_hostname    = "tailscale-operator-1"
  oauth_client_id      = var.oauth_client_id
  oauth_client_secret  = var.oauth_client_secret
}
