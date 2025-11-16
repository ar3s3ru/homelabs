variable "secrets" {
  type        = map(string)
  description = "Secrets for the Vaultwarden deployment"
  sensitive   = true
}

resource "kubernetes_secret_v1" "vaultwarden_secrets" {
  metadata {
    name      = "vaultwarden-secrets"
    namespace = "auth"
  }

  data = var.secrets
}

resource "kubernetes_persistent_volume_claim_v1" "vaultwarden_v2" {
  metadata {
    name      = "vaultwarden-v2"
    namespace = "auth"
  }

  spec {
    storage_class_name = "longhorn-nvme-encrypted-3-replicas"
    access_modes       = ["ReadWriteMany"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "helm_release" "vaultwarden" {
  name            = "vaultwarden"
  repository      = "https://gissilabs.github.io/charts"
  chart           = "vaultwarden"
  version         = "1.2.6"
  namespace       = "auth"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}
