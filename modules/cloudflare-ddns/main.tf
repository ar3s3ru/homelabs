variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where to deploy the module resources"
}

variable "api_token" {
  type        = string
  description = "Tailscale OAuth client ID for the Kubernetes operator"
  sensitive   = true
}

variable "domains" {
  type        = list(string)
  description = "List of domains to update on Cloudflare"
}

resource "kubernetes_secret_v1" "cloudflare_ddns_secrets" {
  metadata {
    name      = "cloudflare-ddns-secrets"
    namespace = var.kubernetes_namespace
  }

  data = {
    CLOUDFLARE_API_TOKEN = var.api_token
  }
}

resource "helm_release" "cloudflare_ddns" {
  name            = "cloudflare-ddns"
  repository      = "https://bjw-s.github.io/helm-charts"
  chart           = "app-template"
  namespace       = var.kubernetes_namespace
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true # Required for IPv6 detection.
      securityContext = {
        runAsUser  = 1000
        runAsGroup = 1000
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
              repository = "docker.io/favonia/cloudflare-ddns"
              tag        = "edge-alpine"
            }
            probes = {
              # FIXME(ar3s3ru): find a way to enable these?
              liveness  = { enabled = false }
              readiness = { enabled = false }
              startup   = { enabled = true }
            }
            env = {
              DOMAINS = join(",", var.domains)
              PROXIED = false
            }
            envFrom = [{
              secretRef = {
                name = kubernetes_secret_v1.cloudflare_ddns_secrets.metadata[0].name
              }
            }]
          }
        }
      }
    }
  })]
}
