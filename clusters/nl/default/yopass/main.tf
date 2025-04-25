locals {
  service_name = "yopass"
}

variable "tailscale_domain" {
  type        = string
  description = "Tailscale tailnet domain, used for CORS"
}

resource "helm_release" "yopass_redis" {
  name            = "yopass-redis"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "redis"
  namespace       = "default"
  version         = "20.13.2"
  cleanup_on_fail = true

  values = [yamlencode({
    architecture = "standalone"
    auth         = { enabled = false }
  })]
}

resource "helm_release" "yopass" {
  depends_on = [helm_release.yopass_redis]

  name            = "yopass"
  repository      = "https://bjw-s.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "default"
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      securityContext = {
        runAsUser  = 1000
        runAsGroup = 1000
      }
    }

    controllers = {
      main = {
        type     = "deployment"
        replicas = 1

        containers = {
          main = {
            image = {
              repository = "docker.io/jhaals/yopass"
              tag        = "master"
            }
            args = [
              "--database", "redis",
              "--redis", "redis://yopass-redis-master.default.svc.cluster.local:6379/0",
            ]
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
            port = 1337
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = local.service_name,
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = [local.service_name] }]
      }
    }
  })]
}
