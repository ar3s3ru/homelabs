resource "kubernetes_namespace" "flugg_infra" {
  metadata {
    name   = "flugg-infra"
    labels = local.default_labels
  }
}

resource "kubernetes_namespace" "flugg_system" {
  metadata {
    name   = "flugg-system"
    labels = local.default_labels
  }
}
