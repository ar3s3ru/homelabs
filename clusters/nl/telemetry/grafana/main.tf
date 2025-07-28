variable "secrets_env" {
  type        = map(string)
  description = "Secrets for Grafana to be mounted as environment variables"
  sensitive   = true
}

resource "kubernetes_secret_v1" "grafana_secrets_env" {
  metadata {
    name      = "grafana-secrets-env"
    namespace = "telemetry"
  }

  data = var.secrets_env
}

resource "helm_release" "grafana" {
  name            = "grafana"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  version         = "9.3.0"
  namespace       = "telemetry"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}

# Doesn't work - must apply with kubectl manually.
#
# resource "helm_release" "grafana_dashboards" {
#   depends_on      = [helm_release.grafana]
#   name            = "grafana-dashboards"
#   repository      = "https://bedag.github.io/helm-charts/"
#   chart           = "raw"
#   version         = "2.0.0"
#   namespace       = "telemetry"
#   cleanup_on_fail = true
#   values          = [file("./values-dashboards.yaml")]
# }
