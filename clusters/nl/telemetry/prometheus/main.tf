resource "helm_release" "prometheus" {
  name            = "kps"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  namespace       = "telemetry"
  version         = "76.5.1"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
