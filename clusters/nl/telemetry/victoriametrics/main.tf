# Add the prometheys CRDs so that vm can scrape servicemonitors, etc.
resource "helm_release" "prometheus_crds" {
  name       = "prometheus-crds"
  namespace  = "telemetry"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  version    = "22.0.1"
  atomic     = true
}

resource "helm_release" "victoriametrics" {
  name             = "victoriametrics"
  namespace        = "telemetry"
  create_namespace = false
  repository       = "https://victoriametrics.github.io/helm-charts/"
  chart            = "victoria-metrics-k8s-stack"
  # To update: https://github.com/VictoriaMetrics/helm-charts/releases?q=victoria-metrics-k8s-stack&expanded=true
  # https://docs.victoriametrics.com/helm/victoriametrics-k8s-stack/#upgrade-guide
  version = "0.63.6"
  atomic  = true
  values  = [file("${path.module}/values.yaml")]

  depends_on = [
    helm_release.prometheus_crds
  ]
}
