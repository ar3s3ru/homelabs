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

# NOTE: this is only necessary for sabnzbd because it destroys the NFS server
# when unpacking compressed files from all articles.
module "media_data_v3_local" {
  source = "../../../modules/local-persistent-mount"

  volume_name          = "media-data-v3-local"
  kubernetes_namespace = kubernetes_namespace.media.metadata[0].name
  kubernetes_node      = "gladius"
  host_path            = "/mnt/zpool-nl-01/pvc-fccb9cfc-aef5-4d93-a9db-5a6314e0796a"
  storage_size         = kubernetes_persistent_volume_claim_v1.media_data_v3.spec[0].resources[0].requests.storage
}
