resource "kubernetes_persistent_volume_v1" "prometheus" {
  metadata {
    name = "prometheus-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/telemetry/prometheus"
      }
    }
  }
}

resource "helm_release" "prometheus" {
  name             = "kps"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "telemetry"
  version          = "68.1.0"
  create_namespace = true

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        // Enables remote write receiver so that Alloy can push metrics to it.
        enableRemoteWriteReceiver = true

        retention     = "7d"
        retentionSize = "10GB" // Should match the PersistentVolume space request.

        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              volumeName  = kubernetes_persistent_volume_v1.prometheus.metadata[0].name
              resources = {
                requests = {
                  storage = kubernetes_persistent_volume_v1.prometheus.spec[0].capacity.storage
                }
              }
            }
          }
        }

        # This is necessary to fix permissions of the PersistentVolumeClaim created.
        initContainers = [{
          name  = "prometheus-fix-permissions-pv"
          image = "busybox"
          command = [
            "chown",
            "-R",
            "1000:2000",
            "/prometheus"
          ]
          volumeMounts = [{
            name      = "prometheus-kps-kube-prometheus-stack-prometheus-db"
            mountPath = "/prometheus"
          }]
          securityContext = {
            runAsUser    = 0
            runAsNonRoot = false
            runAsGroup   = 0
            fsGroup      = 0
          }
        }]

        # Scrape pod/service monitors and rules from all namespaces.
        podMonitorSelector     = {}
        ruleSelector           = {}
        serviceMonitorSelector = {}

        podMonitorNamespaceSelector     = { any = true }
        ruleNamespaceSelector           = { any = true }
        serviceMonitorNamespaceSelector = { any = true }

        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        serviceMonitorSelectorNilUsesHelmValues = false
      }

      ingress = {
        enabled          = true
        ingressClassName = "tailscale"
        hosts            = ["nl-prometheus"]
        tls              = [{ hosts = ["nl-prometheus"] }]
      }
    }

    # NOTE: the Grafana deployment is handled in its own chart.
    grafana = { enabled = false }
  })]
}
