locals {
  namespace = "home-automation"
}

variable "secrets" {
  type        = map(string)
  description = "Environment variables to mount on the pod as secrets"
  sensitive   = true
}

resource "kubernetes_secret_v1" "frigate_secrets" {
  metadata {
    name      = "frigate-secrets"
    namespace = local.namespace
  }

  data = var.secrets
}

resource "kubernetes_persistent_volume_claim_v1" "frigate_media_v2" {
  metadata {
    name      = "frigate-media-v2"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-1-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "178Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "frigate_config_v2" {
  metadata {
    name      = "frigate-config-v2"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "100Mi"
      }
    }
  }
}



resource "helm_release" "frigate" {
  name            = "frigate"
  repository      = "https://blakeblackshear.github.io/blakeshome-charts"
  chart           = "frigate"
  namespace       = local.namespace
  version         = "7.8.0"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}
