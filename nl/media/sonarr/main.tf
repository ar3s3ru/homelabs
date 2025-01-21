resource "helm_release" "sonarr" {
  name             = "sonarr"
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
        type     = "statefulset"
        replicas = 1

        annotations = {
          "reloader.stakater.com/auto" = "true"
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/linuxserver/sonarr"
              tag        = "4.0.12"
            }
            env = {
              TZ    = "Europe/Amsterdam"
              PGUID = 1000
              PGID  = 1000
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
            port = 8989
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-sonarr",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-sonarr"] }]
      }
    }

    persistence = {
      config = {
        enabled      = true
        type         = "persistentVolumeClaim"
        accessMode   = "ReadWriteOnce"
        size         = "100M"
        globalMounts = [{ path = "/config" }]
      }
      # NOTE: using the TRaSH guide on directory structure.
      # Source: https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
      media = {
        enabled      = true
        type         = "hostPath"
        hostPath     = "/home/k3s/media/jellyfin"
        globalMounts = [{ path = "/data/media" }]
      }
      downloads = {
        enabled      = true
        type         = "hostPath"
        hostPath     = "/home/k3s/media/qbittorrent"
        globalMounts = [{ path = "/data/torrents" }]
      }
    }
  })]
}
