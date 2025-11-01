locals {
  namespace = "redis-system"
}

resource "helm_release" "redis_operator" {
  name             = "redis-operator"
  repository       = "https://ot-container-kit.github.io/helm-charts/"
  chart            = "redis-operator"
  version          = "0.22.2"
  namespace        = local.namespace
  create_namespace = true
  cleanup_on_fail  = true
}
