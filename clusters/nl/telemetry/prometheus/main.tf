resource "helm_release" "prometheus" {
  name            = "kps"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  namespace       = "telemetry"
  version         = "77.14.0"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
