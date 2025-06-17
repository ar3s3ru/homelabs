resource "kubernetes_persistent_volume_claim_v1" "prowlarr_config" {
  for_each = {
    "prowlarr-config" = "100M"
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

resource "helm_release" "prowlarr" {
  depends_on = [helm_release.flaresolverr]

  name            = "prowlarr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.7.3"
  cleanup_on_fail = true
  values = [file("./values.yaml")]
}

resource "helm_release" "flaresolverr" {
  name            = "flaresolverr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.7.3"
  cleanup_on_fail = true
  values = [file("./values-flaresolverr.yaml")]
}
