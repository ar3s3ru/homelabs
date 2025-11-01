resource "kubernetes_persistent_volume_claim_v1" "persistence_v2" {
  for_each = {
    "sabnzbd-config-v2" = "500M"
  }

  metadata {
    name      = each.key
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = each.value
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "downloads_v2" {
  metadata {
    name      = "sabnzbd-downloads"
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme-1-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "120Gi"
      }
    }
  }
}

resource "helm_release" "sabnzbd" {
  name            = "sabnzbd"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "4.3.0"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}
