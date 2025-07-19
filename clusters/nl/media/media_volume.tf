resource "kubernetes_persistent_volume_claim_v1" "media_data_v2" {
  metadata {
    name      = "media-data-v2"
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-hdd-1-replicas"
    access_modes       = ["ReadWriteMany"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "2Ti"
      }
    }
  }
}
