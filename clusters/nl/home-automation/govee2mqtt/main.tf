variable "govee_email" {
  type        = string
  description = "Govee cloud account email address"
  sensitive   = false
}

variable "govee_password" {
  type        = string
  description = "Govee cloud account password"
  sensitive   = true
}

variable "govee_api_key" {
  type        = string
  description = "API key for the Undocumented Govee API"
  sensitive   = true
}

resource "kubernetes_secret_v1" "govee_secrets" {
  metadata {
    name      = "govee-secrets"
    namespace = "home-automation"
  }

  data = {
    "GOVEE_EMAIL"    = var.govee_email
    "GOVEE_PASSWORD" = var.govee_password
    "GOVEE_API_KEY"  = var.govee_api_key
  }
}

resource "helm_release" "govee2mqtt" {
  name             = "govee2mqtt"
  repository       = "https://bjw-s-labs.github.io/helm-charts"
  chart            = "app-template"
  namespace        = "home-automation"
  version          = "3.7.3"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true # Required for certain network features.
      securityContext = {
        runAsUser           = 1000
        runAsGroup          = 1000
        fsGroup             = 1000
        fsGroupChangePolicy = "OnRootMismatch"
      }
    }

    controllers = {
      main = {
        type     = "deployment"
        replicas = 1
        strategy = "Recreate"

        annotations = {
          "reloader.stakater.com/auto" = "true"
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/wez/govee2mqtt"
              tag        = "2025.01.04-2c39a50f"
            }
            probes = {
              # FIXME(ar3s3ru): find a way to enable these?
              liveness  = { enabled = false }
              readiness = { enabled = false }
              startup   = { enabled = true }
            }
            env = {
              TZ                      = "Europe/Amsterdam"
              GOVEE_MQTT_HOST         = "emqx.home-automation.svc.cluster.local"
              GOVEE_MQTT_PORT         = "1883"
              GOVEE_TEMPERATURE_SCALE = "C"
            }
            envFrom = [{
              secretRef = {
                name = kubernetes_secret_v1.govee_secrets.metadata[0].name
              }
            }]
          }
        }
      }
    }

    service = {
      main = {
        controller = "main"
        type       = "ClusterIP"
        ports = {
          http = {
            port = 8056
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-g2m",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-g2m"] }]
      }
    }
  })]
}
