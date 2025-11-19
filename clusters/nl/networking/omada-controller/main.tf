resource "helm_release" "omada_controller" {
  name            = "omada-controller"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "networking"
  version         = "4.4.0"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]
}
