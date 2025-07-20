resource "kubernetes_role_binding_v1" "flugg_infra_sa_role_binding" {
  metadata {
    name      = "flugg-infra-sa-role-binding"
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
    labels    = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flugg_infra_sa.metadata[0].name
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "flugg_infra_sa_role_binding_flugg_system" {
  metadata {
    name      = "flugg-infra-sa-role-binding"
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
    labels    = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flugg_infra_sa.metadata[0].name
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "flugg_infra_sa_role_binding_default" {
  metadata {
    name      = "flugg-infra-sa-role-binding"
    namespace = "default"
    labels    = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flugg_infra_sa.metadata[0].name
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "flugg_infra_sa_telemetry_binding" {
  metadata {
    name   = "flugg-infra-sa-telemetry-binding"
    labels = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.flugg_infra_telemetry_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flugg_infra_sa.metadata[0].name
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "flugg_system_sa_role_binding" {
  metadata {
    name      = "flugg-system-sa-role-binding"
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
    labels    = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flugg_system_sa.metadata[0].name
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "flugg_system_sa_role_binding_infra_viewer" {
  metadata {
    name      = "flugg-system-sa-role-binding"
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
    labels    = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flugg_system_sa.metadata[0].name
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
  }
}
