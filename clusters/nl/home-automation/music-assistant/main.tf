resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "music-assistant-data" = "1Gi"
    "music-assistant-media" = "10G"
  }

  metadata {
    name      = each.key
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "longhorn-nvme"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = each.value
      }
    }
  }
}

resource "helm_release" "music_assistant" {
  name            = "music-assistant"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "home-automation"
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true # Required for certain network features.
    }

    controllers = {
      main = {
        type     = "deployment"
        replicas = 1

        annotations = {
          "reloader.stakater.com/auto" = "true"
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/music-assistant/server"
              tag        = "2.5.2"
            }
            env = {
              LOG_LEVEL = "info"
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

    service = {
      main = {
        controller = "main"
        type       = "ClusterIP"
        ports = {
          http = {
            port = 8095 # Source: https://github.com/music-assistant/server/blob/dev/Dockerfile#L71
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-mass",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-mass"] }]
      }
    }

    persistence = {
      tmp = {
        enabled      = true
        type         = "emptyDir"
        globalMounts = [{ path = "/tmp" }]
      }
      data = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = "music-assistant-data"
        globalMounts  = [{ path = "/data" }]
      }
      media = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = "music-assistant-media"
        globalMounts  = [{ path = "/media" }]
      }
    }
  })]
}
