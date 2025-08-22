resource "helm_release" "nats" {
  name       = "opencloud-nats"
  repository = "https://nats-io.github.io/k8s/helm/charts"
  chart      = "nats"
  # version         = "16.7.21"
  namespace       = local.namespace
  cleanup_on_fail = true
  values          = [file("${path.module}/values-nats.yaml")]
}
