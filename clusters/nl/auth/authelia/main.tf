variable "secrets" {
  type        = map(string)
  description = "Secrets for the Authelia deployment"
  sensitive   = true
}

resource "kubernetes_secret_v1" "authelia_secrets" {
  metadata {
    name      = "authelia-secrets"
    namespace = "auth"
  }

  data = var.secrets
}

variable "oidc_client_secrets" {
  type        = map(string)
  description = "OIDC client secrets for the Authelia deployment"
  sensitive   = true
}

resource "kubernetes_secret_v1" "authelia_oidc_secrets" {
  metadata {
    name      = "authelia-oidc-secrets"
    namespace = "auth"
  }

  data = var.oidc_client_secrets
}

output "immich_client_secret" {
  value     = var.oidc_client_secrets["immich.client_secret.key"]
  sensitive = true
}

output "home_assistant_client_id" {
  value = "home-assistant"
}

output "home_assistant_client_secret" {
  value     = var.oidc_client_secrets["hass.client_secret.key"]
  sensitive = true
}

resource "helm_release" "authelia" {
  name            = "authelia"
  repository      = "https://charts.authelia.com"
  chart           = "authelia"
  namespace       = "auth"
  version         = "0.10.4"
  cleanup_on_fail = true

  values = [yamlencode({
    ingress = {
      enabled = true

      annotations = {
        "cert-manager.io/cluster-issuer" = "acme"
      }

      tls        = { enabled = true }
      traefikCRD = { enabled = true, disableIngressRoute = true }
    }

    pod = {
      kind = "Deployment" # Only need a single deployment/replica for now.

      annotations = {
        "reloader.stakater.com/auto" = "true" # Restarts the Deployment if the configmaps/secrets change.
      }

      env = [{
        name  = "TZ"
        value = "Europe/Amsterdam"
      }]
    }

    configMap = yamldecode(file("configuration.yaml"))

    secret = {
      additionalSecrets = {
        "${kubernetes_secret_v1.authelia_secrets.metadata[0].name}" = {
          items = [for k, v in var.secrets : { key : k, path : k }]
        },
        "${kubernetes_secret_v1.authelia_oidc_secrets.metadata[0].name}" = {
          items = [for k, v in var.oidc_client_secrets : { key : k, path : k }]
        }
      }
    }
  })]
}
