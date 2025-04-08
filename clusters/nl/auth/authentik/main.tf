resource "random_password" "authentik_bootstrap_password" {
  length  = 16
  special = true
}

resource "random_password" "postgres_password" {
  length  = 16
  special = false
}

resource "random_password" "authentik_secret_key" {
  length  = 50
  special = true
}

variable "smtp_email" {
  type        = string
  description = "Email to use for Authentik SMTP configuration"
}

variable "smtp_password" {
  type        = string
  description = "Password to use for Authentik SMTP configuration"
  sensitive   = true
}

resource "helm_release" "authentik" {
  name             = "authentik"
  repository       = "https://charts.goauthentik.io"
  chart            = "authentik"
  version          = "2025.2.4"
  namespace        = "auth"
  create_namespace = true

  values = [
    yamlencode({
      authentik = {
        error_reporting           = { enabled = false }
        disable_update_check      = true
        disable_startup_analytics = true

        email = {
          host     = "smtp.google.com"
          username = var.smtp_email
          password = var.smtp_password
          use_tls  = true
        }
      }

      server = {
        metrics        = { enabled = true }
        serviceMonitor = { enabled = true }

        ingress = {
          enabled     = true
          annotations = { "cert-manager.io/cluster-issuer" = "acme" }
          hosts       = ["auth.nl.ar3s3ru.dev"]
          tls         = [{ hosts = ["auth.nl.ar3s3ru.dev"], secretName = "authentik-tls" }]
        }
      }

      postgresql = { enabled = true }
      redis      = { enabled = true }

      prometheus = {
        rules = { enabled = true }
      }
    })
  ]

  set_sensitive {
    name  = "authentik.secret_key"
    value = random_password.authentik_secret_key.result
  }

  set_sensitive {
    name  = "authentik.bootstrap_password"
    value = random_password.authentik_bootstrap_password.result
  }

  set_sensitive {
    name  = "authentik.postgresql.password"
    value = random_password.postgres_password.result
  }

  set_sensitive {
    name  = "postgresql.auth.password"
    value = random_password.postgres_password.result
  }
}
