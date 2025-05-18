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
          items = [{
            key  = "notifier.smtp.password.txt"
            path = "notifier.smtp.password.txt"
            }, {
            key  = "storage.postgres.password.txt"
            path = "storage.postgres.password.txt"
            }, {
            key  = "authentication.ldap.password.txt"
            path = "authentication.ldap.password.txt"
          }]
        }
      }
    }
  })]
}
