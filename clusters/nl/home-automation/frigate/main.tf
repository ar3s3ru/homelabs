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

resource "kubernetes_persistent_volume_claim_v1" "persistence" {
  for_each = {
    "frigate-config" = "100Mi"
    "frigate-media"  = "60Gi"
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

    podAnnotations = {
      "reloader.stakater.com/auto" = "true" # Restarts the Deployment if the configmaps/secrets change.
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
