resource "kubernetes_persistent_volume_v1" "music_assistant_data" {
  metadata {
    name = "music-assistant-data"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/home-automation/music-assistant/data"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["momonoke"]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "music_assistant_data" {
  metadata {
    name      = "music-assistant-data"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.music_assistant_data.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "music_assistant_media" {
  metadata {
    name = "music-assistant-media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/home-automation/music-assistant/media"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["momonoke"]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "music_assistant_media" {
  metadata {
    name      = "music-assistant-media"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.music_assistant_media.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}

resource "helm_release" "music_assistant" {
  name            = "music-assistant"
  repository      = "https://bjw-s.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "home-automation"
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true # Required for certain network features.
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
              repository = "ghcr.io/music-assistant/server"
              tag        = "2.5.0b16"
            }
            env = {
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
            port = 8095 # Source: https://github.com/music-assistant/server/blob/dev/Dockerfile#L71
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-mass",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-mass"] }]
      }
    }

    persistence = {
      tmp = {
        enabled      = true
        type         = "emptyDir"
        globalMounts = [{ path = "/tmp" }]
      }
      data = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.music_assistant_data.metadata[0].name
        globalMounts  = [{ path = "/data" }]
      }
      media = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.music_assistant_media.metadata[0].name
        globalMounts  = [{ path = "/media" }]
      }
    }
  })]
}
