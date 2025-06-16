variable "secrets" {
  type        = map(string)
  description = "Secrets for the Vaultwarden deployment"
  sensitive   = true
}

resource "kubernetes_secret_v1" "vaultwarden_secrets" {
  metadata {
    name      = "vaultwarden-secrets"
    namespace = "auth"
  }

  data = var.secrets
}

resource "helm_release" "vaultwarden" {
  name            = "vaultwarden"
  repository      = "https://gissilabs.github.io/charts"
  chart           = "vaultwarden"
  version         = "1.2.5"
  namespace       = "auth"
  cleanup_on_fail = true
  values = [
    file("values.yaml")
  ]
}
