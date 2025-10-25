locals {
  namespace = "auth"
}

variable "secrets" {
  type        = map(string)
  description = "Secrets for the Authelia deployment"
  sensitive   = true
}

resource "kubernetes_secret_v1" "authelia_secrets" {
  metadata {
    name      = "authelia-secrets"
    namespace = local.namespace
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
    namespace = local.namespace
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

output "jellyfin_client_id" {
  value = "jellyfin"
}

output "jellyfin_client_secret" {
  value     = var.oidc_client_secrets["jellyfin.client_secret.key"]
  sensitive = true
}

output "vaultwarden_client_secret" {
  value     = var.oidc_client_secrets["vaultwarden.client_secret.key"]
  sensitive = true
}

output "grafana_client_secret" {
  value     = var.oidc_client_secrets["grafana.client_secret.key"]
  sensitive = true
}

resource "helm_release" "authelia" {
  name            = "authelia"
  repository      = "https://charts.authelia.com"
  chart           = "authelia"
  namespace       = local.namespace
  version         = "0.10.47"
  cleanup_on_fail = true

  values = [
    file("${path.module}/values-authelia.yaml"),
    yamlencode({
      secret = {
        additionalSecrets = {
          "${kubernetes_secret_v1.authelia_secrets.metadata[0].name}" = {
            items = [for k, v in var.secrets : { key : k, path : k }]
          }
          "${kubernetes_secret_v1.authelia_oidc_secrets.metadata[0].name}" = {
            items = [for k, v in var.oidc_client_secrets : { key : k, path : k }]
          }
        }
      }
    })
  ]
}

# data "helm_template" "authelia" {
#   name       = "authelia"
#   repository = "https://charts.authelia.com"
#   chart      = "authelia"
#   namespace  = local.namespace
#   version    = "0.10.41"
#   values = [
#     file("${path.module}/values-authelia.yaml"),
#     yamlencode({
#       secret = {
#         additionalSecrets = {
#           "${kubernetes_secret_v1.authelia_secrets.metadata[0].name}" = {
#             items = [for k, v in var.secrets : { key : k, path : k }]
#           }
#           "${kubernetes_secret_v1.authelia_oidc_secrets.metadata[0].name}" = {
#             items = [for k, v in var.oidc_client_secrets : { key : k, path : k }]
#           }
#         }
#       }
#     })
#   ]
# }

# resource "local_file" "authelia_manifests" {
#   for_each = data.helm_template.authelia.manifests
#   content  = each.value
#   filename = "${path.module}/${each.key}"
# }
