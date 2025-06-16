resource "kubernetes_persistent_volume_claim_v1" "media_data" {
  metadata {
    name      = "media-data"
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme"
    access_modes       = ["ReadWriteMany"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "1.5Ti"
      }
    }
  }
}
