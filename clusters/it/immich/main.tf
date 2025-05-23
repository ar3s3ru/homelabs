resource "kubernetes_namespace" "immich" {
  metadata {
    name = "immich"
  }
}

module "volumes" {
  source = "../../../modules/local-persistent-mount"

  for_each = {
    "immich-library"  = "/files/immich"
    "immich-postgres" = "/home/k3s/immich/postgres"
    "immich-redis"    = "/home/k3s/immich/redis"
  }

  volume_name          = each.key
  kubernetes_namespace = kubernetes_namespace.immich.metadata[0].name
  kubernetes_node      = "dejima"
  host_path            = each.value
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client secret for Immich provider"
  sensitive   = true
}

resource "helm_release" "immich" {
  name            = "immich"
  repository      = "https://immich-app.github.io/immich-charts"
  chart           = "immich"
  version         = "0.9.3"
  namespace       = kubernetes_namespace.immich.metadata[0].name
  cleanup_on_fail = true
  values = [
    file("values.yaml"),
    yamlencode({
      immich = {
        configuration = {
          oauth = {
            clientSecret = var.oauth_client_secret
          }
        }
      }
    })
  ]
}
