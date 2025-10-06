resource "kubernetes_persistent_volume_claim_v1" "media_data_v3" {
  metadata {
    name      = "media-data-v3"
    namespace = kubernetes_namespace.media.metadata[0].name
  }

  spec {
    storage_class_name = "zfs-generic-nfs-csi"
    access_modes       = ["ReadWriteMany"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "2Ti"
      }
    }
  }
}
