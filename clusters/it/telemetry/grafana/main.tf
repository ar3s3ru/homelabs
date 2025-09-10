resource "helm_release" "grafana" {
  name            = "grafana"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  version         = "9.4.4"
  namespace       = "telemetry"
  cleanup_on_fail = true

  values = [yamlencode({
    ingress = {
      enabled          = true
      ingressClassName = "tailscale"
      hosts            = ["it-grafana"]
      tls              = [{ hosts = ["it-grafana"] }]
    }

    sidecar = {
      datasources = {
        enabled         = true
        searchNamespace = "ALL"
      }
      dashboards = {
        enabled         = true
        searchNamespace = "ALL"
      }
      alerts = {
        enabled         = true
        searchNamespace = "ALL"
      }
      plugins = {
        enabled         = true
        searchNamespace = "ALL"
      }
      notifiers = {
        enabled         = true
        searchNamespace = "ALL"
      }
    }

    datasources = {
      "datasources.yaml" = {
        apiVersion = 1
        datasources = [
          {
            name      = "Prometheus"
            type      = "prometheus"
            uid       = "prometheus"
            url       = "http://prometheus-operated.telemetry.svc.cluster.local:9090"
            access    = "proxy"
            isDefault = true
            editable  = false
            basicAuth = false
          },
          {
            name      = "AlertManager"
            type      = "alertmanager"
            uid       = "alertmanager"
            url       = "http://alertmanager-operated.telemetry.svc.cluster.local:9093"
            access    = "proxy"
            editable  = false
            basicAuth = false
          }
        ]
      }
    }

    dashboardProviders = {
      "dashboardproviders.yaml" = {
        apiVersion = 1
        providers = [{
          name            = "default"
          orgId           = 1
          type            = "file"
          disableDeletion = false
          editable        = false
          options = {
            path = "/var/lib/grafana/dashboards/default"
          }
        }]
      }
    }
  })]
}

# NOTE(ar3s3ru): Terraform for some reason is not able to apply these manifests.
# Therefore they have been applied using kubectl apply manually.
#
# locals {
#   grafana_dashboards = {
#     for manifest in yamldecode(file("dashboards-patched.yaml")).items :
#     manifest.metadata.name => manifest
#   }
# }
#
# resource "kubernetes_manifest" "grafana_dashboards" {
#   for_each   = local.grafana_dashboards
#   manifest   = each.value
#   depends_on = [helm_release.grafana]
# }
