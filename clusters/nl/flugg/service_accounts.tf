resource "kubernetes_service_account_v1" "flugg_infra_sa" {
  metadata {
    name      = "flugg-infra-sa"
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
    labels    = local.default_labels
  }
}

resource "kubernetes_secret_v1" "flugg_infra_sa_token" {
  metadata {
    name      = "flugg-infra-sa-token"
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
    labels    = local.default_labels
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.flugg_infra_sa.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_service_account_v1" "flugg_system_sa" {
  metadata {
    name      = "flugg-system-sa"
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
    labels    = local.default_labels
  }
}

resource "kubernetes_secret_v1" "flugg_system_sa_token" {
  metadata {
    name      = "flugg-system-sa-token"
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
    labels    = local.default_labels
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.flugg_system_sa.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}
