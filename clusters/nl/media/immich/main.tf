locals {
  namespace = "media"
}

resource "kubernetes_persistent_volume_claim_v1" "backup" {
  metadata {
    name      = "immich-backup"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-1-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "480Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "immich_library_v3" {
  metadata {
    name      = "immich-library-v3"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "zfs-generic-nfs-csi"
    access_modes       = ["ReadWriteMany"] # NOTE: required for RollingUpdate strategy.
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "1Ti"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "immich-ml-cache-v3" {
  metadata {
    name      = "immich-ml-cache-v3"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "10Gi"
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
  namespace       = local.namespace
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
