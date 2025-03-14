resource "helm_release" "reloader" {
  name            = "reloader"
  repository      = "https://stakater.github.io/stakater-charts"
  chart           = "reloader"
  namespace       = "kube-system"
  version         = "1.3.0"
  cleanup_on_fail = true
}
