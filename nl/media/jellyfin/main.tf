resource "kubernetes_persistent_volume_v1" "jellyfin_media" {
  metadata {
    name = "jellyfin-media-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "100G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/media/jellyfin"
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
        storage = "100G"
      }
    }
  }
}

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
      priviledged = true # Necessary for hw acceleration.
    }

    ingress = {
      enabled = true
      annotations = {
        "cert-manager.io/cluster-issuer" = "acme"
      }
      hosts = [
        {
          host = "jellyfin.nl.ar3s3ru.dev"
          paths = [{
            path     = "/"
            pathType = "Prefix"
          }]
        }
      ]
      tls = [{
        hosts      = ["jellyfin.nl.ar3s3ru.dev"]
        secretName = "jellyfin-tls"
      }]
    }

    # metrics = {
    #   enabled        = true
    #   serviceMonitor = { enabled = true }
    # }

    volumes = [{
      enabled = true
      name    = "hw-accel-dri"
      type    = "hostPath"
      hostPath = {
        path = "/dev/dri"
        type = "Directory"
      }
    }]

    volumeMounts = [{
      name      = "hw-accel-dri"
      mountPath = "/dev/dri"
    }]

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
