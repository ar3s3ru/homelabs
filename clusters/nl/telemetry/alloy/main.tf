# FIXME: disabled for now, while investigating the 'too many open files' issue
#
# resource "helm_release" "alloy" {
#   name            = "alloy"
#   repository      = "https://grafana.github.io/helm-charts"
#   chart           = "alloy"
#   version         = "1.1.2"
#   namespace       = "telemetry"
#   cleanup_on_fail = true

#   values = [yamlencode({
#     alloy = {
#       configMap = {
#         content = file("./config.alloy")
#       }
#     }
#   })]
# }
