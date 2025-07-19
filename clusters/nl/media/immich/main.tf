resource "kubernetes_namespace" "immich" {
  metadata {
    name = "immich"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "immich-postgres" = "2Gi"
    "immich-redis"    = "200Mi"
  }

  metadata {
    name      = each.key
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = each.value
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "persistence_v2" {
  for_each = {
    "immich-library-v2" = "1Ti"
  }

  metadata {
    name      = each.key
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-hdd-single-replica"
    access_modes       = ["ReadWriteOnce", "ReadWriteMany"] # NOTE: required for RollingUpdate strategy.
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = each.value
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "persistence_v3" {
  for_each = {
    "immich-ml-cache-v2" = "10Gi"
  }

  metadata {
    name      = each.key
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme-replicated"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = each.value
      }
    }
  }
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
  namespace       = "media"
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
