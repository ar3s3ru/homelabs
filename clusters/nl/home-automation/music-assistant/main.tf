locals {
  namespace = "home-automation"
}

resource "kubernetes_persistent_volume_claim_v1" "persistence_v2" {
  for_each = {
    "music-assistant-data-v2" = "1Gi"
  }

  metadata {
    name      = each.key
    namespace = local.namespace
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

resource "helm_release" "music_assistant" {
  name            = "music-assistant"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = local.namespace
  version         = "4.2.0"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
