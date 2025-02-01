locals {
  webui_port      = 8080
  torrenting_port = 6881
}

resource "helm_release" "qbittorrent" {
  name             = "qbittorrent"
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
              repository = "ghcr.io/linuxserver/qbittorrent"
              tag        = "5.0.3"
            }
            env = {
              TZ              = "Europe/Amsterdam"
              PGUID           = 1000
              PGID            = 1000
              WEBUI_PORT      = local.webui_port
              TORRENTING_PORT = local.torrenting_port
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
      bittorrent = {
        controller = "main"
        type       = "LoadBalancer"
        ports = {
          bittorrent-tcp = {
            enabled    = true
            port       = local.torrenting_port
            protocol   = "TCP"
            targetPort = local.torrenting_port
          }
          bittorrent-udp = {
            enabled    = true
            port       = local.torrenting_port
            protocol   = "UDP"
            targetPort = local.torrenting_port
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
        enabled      = true
        type         = "persistentVolumeClaim"
        accessMode   = "ReadWriteOnce"
        size         = "50M"
        globalMounts = [{ path = "/config" }]
      }
      downloads = {
        enabled      = true
        type         = "hostPath"
        hostPath     = "/home/k3s/media"
        globalMounts = [{ path = "/media" }]
      }
    }
  })]
}
