
resource "kubernetes_cluster_role_v1" "flugg_infra_telemetry_role" {
  metadata {
    name   = "flugg-infra-telemetry-role"
    labels = local.default_labels
  }

  rule {
    api_groups = ["monitoring.coreos.com"]
    resources  = ["prometheusrules", "servicemonitors", "podmonitors"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch"]
  }
}
