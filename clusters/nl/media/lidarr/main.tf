# TODO(ar3s3ru): re-enable once the lidarr metadata server is fixed.

# resource "kubernetes_persistent_volume_claim_v1" "persistence_v2" {
#   for_each = {
#     "lidarr-config-v2" = "300M"
#   }

#   metadata {
#     name      = each.key
#     namespace = "media"
#   }

#   spec {
#     storage_class_name = "longhorn-nvme-3-replicas"
#     access_modes       = ["ReadWriteOnce"]
#     volume_mode        = "Filesystem"

#     resources {
#       requests = {
#         storage = each.value
#       }
#     }
#   }
# }

# resource "helm_release" "lidarr" {
#   name            = "lidarr"
#   repository      = "https://bjw-s-labs.github.io/helm-charts"
#   chart           = "app-template"
#   namespace       = "media"
#   version         = "4.1.1"
#   cleanup_on_fail = true
#   values          = [file("./values.yaml")]
# }
