variable "jellyfin_host" {
  type        = string
  description = "Jellyfin public hostname"
}

resource "kubernetes_persistent_volume_claim_v1" "persistence_v2" {
  for_each = {
    "jellyfin-config-v2" = "2Gi"
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

# NOTE(ar3s3ru): the following steps are done manually
# - Enable hardware acceleration for transcoding
# - Add https://github.com/9p4/jellyfin-plugin-sso for auth
# - Configure jellyfin-plugin-sso
# - Add library folders
resource "helm_release" "jellyfin" {
  name            = "jellyfin"
  repository      = "https://jellyfin.github.io/jellyfin-helm"
  chart           = "jellyfin"
  namespace       = "media"
  version         = "2.4.0"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}
