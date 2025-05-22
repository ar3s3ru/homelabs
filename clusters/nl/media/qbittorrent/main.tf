locals {
  webui_port = 8080
}

module "volumes" {
  source = "../../../../modules/local-persistent-mount"

  for_each = {
    "qbittorrent-config" = "/media/config/qbittorrent"
    "qbittorrent-media"  = "/media"
  }

  volume_name          = each.key
  kubernetes_namespace = "media"
  kubernetes_node      = "eq14-001"
  host_path            = each.value
}

resource "helm_release" "qbittorrent" {
  name            = "qbittorrent"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true
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
              repository = "ghcr.io/linuxserver/qbittorrent"
              tag        = "5.1.0"
            }
            env = {
              TZ              = "Europe/Amsterdam"
              PGUID           = 1000
              PGID            = 1000
              WEBUI_PORT      = local.webui_port
              TORRENTING_PORT = 6881
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
            port = local.webui_port
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-torrent",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-torrent"] }]
      }
    }

    persistence = {
      config = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = "qbittorrent-config"
        globalMounts  = [{ path = "/config" }]
      }
      downloads = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = "qbittorrent-media"
        globalMounts  = [{ path = "/media" }]
      }
    }
  })]
}
