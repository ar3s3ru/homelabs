resource "kubernetes_persistent_volume_v1" "jellyfin_media" {
  metadata {
    name = "jellyfin-media-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "700G"
    }

    persistent_volume_source {
      host_path {
        path = "/media"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "jellyfin_media" {
  metadata {
    name      = "jellyfin-media-pvc"
    namespace = "media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.jellyfin_media.metadata[0].name

    resources {
      requests = {
        storage = "700G"
      }
    }
  }
}

variable "jellyfin_host" {
  type        = string
  description = "Jellyfin public hostname"
}

# NOTE(ar3s3ru): the following steps are done manually
# - Enable hardware acceleration for transcoding
# - Add https://github.com/9p4/jellyfin-plugin-sso for auth
# - Configure jellyfin-plugin-sso
# - Add library folders
resource "helm_release" "jellyfin" {
  name             = "jellyfin"
  repository       = "https://jellyfin.github.io/jellyfin-helm"
  chart            = "jellyfin"
  namespace        = "media"
  version          = "2.1.0"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    securityContext = {
      # TODO(ar3s3ru): can we do something to remove this requirement?
      runAsUser           = 1000
      runAsGroup          = 1000
      fsGroup             = 1000
      fsGroupChangePolicy = "OnRootMismatch"
      # supplementalGroups = [
      #   26, # Video
      #   303 # Render group
      # ]
    }

    podAnnotations = {
      "reloader.stakater.com/auto" = "true" # Restarts the Deployment if the configmaps change.
    }

    podSecurityContext = {
      # priviledged = true # Necessary for hw acceleration.
      fsGroup = 1000
      # supplementalGroups = [
      #   26, # Video
      #   303 # Render group
      # ]
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

    # metrics = {
    #   enabled        = true
    #   serviceMonitor = { enabled = true }
    # }

    persistence = {
      config = {
        enabled    = true
        accessMode = "ReadWriteOnce"
        size       = "1G"
      }
      media = {
        enabled       = true
        existingClaim = kubernetes_persistent_volume_claim_v1.jellyfin_media.metadata[0].name
      }
    }
  })]
}
