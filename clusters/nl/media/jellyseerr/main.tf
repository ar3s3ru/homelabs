resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "jellyseerr-config" = "100M"
  }

  metadata {
    name      = each.key
    namespace = "media"
  }

  spec {
    storage_class_name = "longhorn-nvme"
    access_modes       = ["ReadWriteMany"] # NOTE: required for RollingUpdate strategy.
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
  version         = "4.1.1"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
