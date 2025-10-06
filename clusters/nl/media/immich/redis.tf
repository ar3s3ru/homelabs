resource "helm_release" "immich_redis" {
  name             = "immich-redis"
  repository       = "https://ot-container-kit.github.io/helm-charts/"
  chart            = "redis"
  version          = "0.16.6"
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true

  values = [
    file("${path.module}/values-redis.yaml")
  ]
}
