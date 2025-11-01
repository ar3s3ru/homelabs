resource "helm_release" "redis" {
  name             = "authelia-redis"
  repository       = "https://ot-container-kit.github.io/helm-charts/"
  chart            = "redis"
  version          = "0.16.7"
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true

  values = [
    file("${path.module}/values-redis.yaml")
  ]
}
