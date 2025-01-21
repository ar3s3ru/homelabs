locals {
  hostname = "jellyseerr.nl.ar3s3ru.dev"
}

resource "helm_release" "jellyseerr" {
  name            = "jellyseerr"
  repository      = "https://bjw-s.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.6.1"
  cleanup_on_fail = true

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
              repository = "docker.io/fallenbagel/jellyseerr"
              tag        = "2.3.0"
            }
            env = {
              TZ        = "Europe/Amsterdam"
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
            port = 5055
          }
        }
      }
    }

    ingress = {
      main = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = "acme"
        }
        hosts = [{
          host = local.hostname,
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{
          hosts      = [local.hostname],
          secretName = "jellyseerr-tls"
        }]
      }
    }

    persistence = {
      config = {
        enabled      = true
        type         = "persistentVolumeClaim"
        accessMode   = "ReadWriteOnce"
        size         = "1G"
        globalMounts = [{ path = "/app/config" }]
      }
    }
  })]
}
