resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "qbittorrent-config" = "24M"
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


resource "helm_release" "qbittorrent" {
  name            = "qbittorrent"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.7.3"
  cleanup_on_fail = true
  values          = [file("values.yaml")]
}
