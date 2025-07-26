resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "bazarr-config" = "300M"
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

resource "helm_release" "bazarr" {
  name            = "bazarr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "4.1.2"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
