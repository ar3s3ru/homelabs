resource "kubernetes_persistent_volume_claim_v1" "persistence_v2" {
  for_each = {
    "jellyseerr-config-v2" = "150M"
  }

  metadata {
    name      = each.key
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteMany"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = each.value
      }
    }
  }
}

resource "helm_release" "jellyseerr" {
  name            = "jellyseerr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "4.4.0"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
