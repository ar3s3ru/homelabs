resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "music-assistant-data"  = "1Gi"
    "music-assistant-media" = "10G"
  }

  metadata {
    name      = each.key
    namespace = "home-automation"
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

resource "helm_release" "music_assistant" {
  name            = "music-assistant"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "home-automation"
  version         = "3.7.3"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
