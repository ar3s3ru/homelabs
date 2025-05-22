variable "jellyfin_host" {
  type        = string
  description = "Jellyfin public hostname"
}

module "volumes" {
  source = "../../../../modules/local-persistent-mount"

  for_each = {
    "jellyfin-config" = "/media/config/jellyfin"
    "jellyfin-media"  = "/media/jellyfin"
  }

  volume_name          = each.key
  kubernetes_namespace = "media"
  kubernetes_node      = "eq14-001"
  host_path            = each.value
}

# NOTE(ar3s3ru): the following steps are done manually
# - Enable hardware acceleration for transcoding
# - Add https://github.com/9p4/jellyfin-plugin-sso for auth
# - Configure jellyfin-plugin-sso
# - Add library folders
resource "helm_release" "jellyfin" {
  name            = "jellyfin"
  repository      = "https://jellyfin.github.io/jellyfin-helm"
  chart           = "jellyfin"
  namespace       = "media"
  version         = "2.3.0"
  cleanup_on_fail = true

  values = [yamlencode({
    securityContext = {
      # TODO(ar3s3ru): can we do something to remove this requirement?
      runAsUser           = 1000
      runAsGroup          = 1000
      fsGroup             = 1000
      fsGroupChangePolicy = "OnRootMismatch"
      supplementalGroups = [
        26, # Video
        303 # Render group
      ]
    }

    podAnnotations = {
      "reloader.stakater.com/auto" = "true" # Restarts the Deployment if the configmaps change.
    }

    podSecurityContext = {
      priviledged = true # Necessary for hw acceleration.
      fsGroup     = 1000
      supplementalGroups = [
        26, # Video
        303 # Render group
      ]
    }

    ingress = {
      enabled = true
      annotations = {
        "cert-manager.io/cluster-issuer" = "acme"
      }
      hosts = [
        {
          host = var.jellyfin_host
          paths = [{
            path     = "/"
            pathType = "Prefix"
          }]
        }
      ]
      tls = [{
        hosts      = [var.jellyfin_host]
        secretName = "jellyfin-tls"
      }]
    }

    # Requests the Intel GPU resource for hardware acceleration.
    resources = {
      limits = {
        "gpu.intel.com/i915" = "1"
      }
      requests = {
        "gpu.intel.com/i915" = "1"
      }
    }

    # metrics = {
    #   enabled        = true
    #   serviceMonitor = { enabled = true }
    # }

    persistence = {
      config = {
        enabled       = true
        existingClaim = "jellyfin-config"
      }
      media = {
        enabled       = true
        existingClaim = "jellyfin-media"
      }
    }
  })]
}
