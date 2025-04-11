module "volumes" {
  source = "../../../../modules/local-persistent-mount"

  for_each = {
    "frigate-config" = "/home/k3s/home-automation/frigate/config"
    "frigate-media"  = "/home/k3s/home-automation/frigate/media"
  }

  volume_name          = each.key
  kubernetes_namespace = "home-automation"
  kubernetes_node      = "momonoke"
  host_path            = each.value
}

variable "secrets" {
  type        = map(string)
  description = "Environment variables to mount on the pod as secrets"
  sensitive   = true
}

resource "kubernetes_secret_v1" "frigate_secrets" {
  metadata {
    name      = "frigate-secrets"
    namespace = "home-automation"
  }

  data = var.secrets
}

resource "helm_release" "frigate" {
  name            = "frigate"
  repository      = "https://blakeblackshear.github.io/blakeshome-charts"
  chart           = "frigate"
  namespace       = "home-automation"
  version         = "7.8.0"
  cleanup_on_fail = true

  values = [yamlencode({
    config = file("config.yaml")

    env = {
      "TZ" = "Europe/Amsterdam"
    }

    envFromSecrets = [
      kubernetes_secret_v1.frigate_secrets.metadata[0].name
    ]

    securityContext = {
      privileged = true # Needs this to access the GPU for hwaccel!
    }

    # Hardware acceleration for ffmpeg
    resources = {
      requests = {
        "gpu.intel.com/i915" = "1"
      }
      limits = {
        "gpu.intel.com/i915" = "1"
      }
    }

    ingress = {
      enabled          = true
      ingressClassName = "tailscale"
      tls              = [{ hosts = ["nl-frigate"] }]
      hosts = [{
        host  = "nl-frigate"
        paths = [{ path = "/", portName = "http" }]
      }]
    }

    persistence = {
      config = {
        enabled       = true
        existingClaim = "frigate-config"
      }
      media = {
        enabled       = true
        existingClaim = "frigate-media"
      }
    }
  })]
}
