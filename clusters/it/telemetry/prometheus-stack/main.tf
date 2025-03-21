resource "kubernetes_namespace" "telemetry" {
  metadata {
    name = "telemetry"
  }
}

resource "kubernetes_persistent_volume" "telemetry" {
  metadata {
    name = "telemetry-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "35Gi"
    }

    persistent_volume_source {
      host_path {
        path = "/files/telemetry"
      }
    }
  }
}

resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "70.2.0"
  namespace  = kubernetes_namespace.telemetry.metadata[0].name
  values     = [file("values.yaml")]
}
