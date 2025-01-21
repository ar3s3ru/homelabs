resource "helm_release" "configarr" {
  name             = "configarr"
  repository       = "https://bjw-s.github.io/helm-charts"
  chart            = "app-template"
  namespace        = "media"
  version          = "3.6.1"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    defaultPodOptions = {
      securityContext = {
        runAsUser           = 1000
        runAsGroup          = 1000
        fsGroup             = 1000
        fsGroupChangePolicy = "OnRootMismatch"
      }
    }

    controllers = {
      main = {
        type = "cronjob"

        annotations = {
          "reloader.stakater.com/auto" = "true"
        }

        cronjob = {
          schedule              = "0 * * * *"
          successfulJobsHistory = 1
          failedJobsHistory     = 1
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/raydak-labs/configarr"
              tag        = "1.10.0"
            }
            probes = {
              # FIXME(ar3s3ru): find a way to enable these?
              liveness  = { enabled = false }
              readiness = { enabled = false }
              startup   = { enabled = true }
            }
          }
        }
      }
    }

    persistence = {
      app-data = {
        enabled    = true
        type       = "persistentVolumeClaim"
        accessMode = "ReadWriteOnce"
        size       = "1G"
        globalMounts = [
          { path = "/app/repos", subPath = "configarr-repos" },
        ]
      }
      config = {
        enabled      = true
        type         = "configMap"
        name         = kubernetes_config_map.configarr_config.metadata[0].name
        globalMounts = [{ path = "/app/config/config.yml", subPath = "config.yml", readOnly = true }]
      }
      secrets = {
        enabled      = true
        type         = "secret"
        name         = kubernetes_secret.configarr_secrets.metadata[0].name
        globalMounts = [{ path = "/app/config/secrets.yml", subPath = "secrets.yml", readOnly = true }]
      }
    }
  })]
}

resource "kubernetes_config_map" "configarr_config" {
  metadata {
    name      = "configarr-config"
    namespace = "media"
  }

  data = {
    "config.yml" = file("config.yml")
  }
}

variable "sonarr_api_key" {
  type        = string
  description = "Sonarr API Key for API access"
  sensitive   = true
}

resource "kubernetes_secret" "configarr_secrets" {
  metadata {
    name      = "configarr-secrets"
    namespace = "media"
  }

  data = {
    "secrets.yml" = <<EOF
---
SONARR_API_KEY: "${var.sonarr_api_key}"
    EOF
  }
}
