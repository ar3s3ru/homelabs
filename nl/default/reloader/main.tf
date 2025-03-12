resource "helm_release" "reloader" {
  name            = "reloader"
  repository      = "https://stakater.github.io/stakater-charts"
  chart           = "reloader"
  namespace       = "default"
  version         = "2.0.0"
  cleanup_on_fail = true
}
