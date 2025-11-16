resource "kubernetes_namespace" "cnpg_system" {
  metadata {
    name = "cnpg-system"
  }
}

resource "helm_release" "cloudnative_pg" {
  name            = "cloudnative-pg"
  repository      = "https://cloudnative-pg.github.io/charts"
  chart           = "cloudnative-pg"
  namespace       = kubernetes_namespace.cnpg_system.metadata[0].name
  cleanup_on_fail = true

  # FIXME: re-enable monitoring after prometheus is installed
  set {
    name  = "monitoring.podMonitorEnabled"
    value = "false"
  }
}
