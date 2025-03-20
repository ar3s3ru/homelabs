resource "kubernetes_persistent_volume_v1" "radarr_media" {
  metadata {
    name = "radarr-media-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "263.7G" # NOTE: this is the size of the partition.
    }

    persistent_volume_source {
      host_path {
        path = "/media"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["eq14-001"]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "radarr_media" {
  metadata {
    name      = "radarr-media-pvc"
    namespace = "media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.radarr_media.metadata[0].name

    resources {
      requests = {
        storage = "263.7G" # NOTE: this is the size of the partition.
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "radarr_config" {
  metadata {
    name = "radarr-config-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "50M"
    }

    persistent_volume_source {
      host_path {
        path = "/media/config/radarr"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["eq14-001"]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "radarr_config" {
  metadata {
    name      = "radarr-config-pvc"
    namespace = "media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.radarr_config.metadata[0].name

    resources {
      requests = {
        storage = "50M"
      }
    }
  }
}

resource "helm_release" "radarr" {
  name             = "radarr"
  repository       = "https://bjw-s.github.io/helm-charts"
  chart            = "app-template"
  namespace        = "media"
  version          = "3.7.3"
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
              repository = "ghcr.io/linuxserver/radarr"
              tag        = "5.20.2"
            }
            env = {
              TZ    = "Europe/Amsterdam"
              PGUID = 1000
              PGID  = 1000
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
            port = 7878
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-radarr",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-radarr"] }]
      }
    }

    persistence = {
      config = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.radarr_config.metadata[0].name
        globalMounts  = [{ path = "/config" }]
      }
      # NOTE: using the TRaSH guide on directory structure.
      # Source: https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
      media = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.radarr_media.metadata[0].name
        globalMounts  = [{ path = "/media" }]
      }
    }
  })]
}
