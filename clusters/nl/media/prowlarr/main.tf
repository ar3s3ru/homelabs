resource "kubernetes_persistent_volume_v1" "prowlarr_config" {
  metadata {
    name = "prowlarr-config-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "100M" # NOTE: this is the size of the partition.
    }

    persistent_volume_source {
      host_path {
        path = "/media/config/prowlarr"
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

resource "kubernetes_persistent_volume_claim_v1" "prowlarr_config" {
  metadata {
    name      = "prowlarr-config-pvc"
    namespace = "media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.prowlarr_config.metadata[0].name

    resources {
      requests = {
        storage = "100M"
      }
    }
  }
}

resource "helm_release" "prowlarr" {
  depends_on = [helm_release.flaresolverr]

  name            = "prowlarr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.7.3"
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
              repository = "ghcr.io/linuxserver/prowlarr"
              tag        = "1.35.1"
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
            port = 9696
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-prowlarr",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-prowlarr"] }]
      }
    }

    persistence = {
      config = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.prowlarr_config.metadata[0].name
        globalMounts  = [{ path = "/config" }]
      }
    }
  })]
}

resource "helm_release" "flaresolverr" {
  name            = "flaresolverr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "3.7.3"
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
        type     = "deployment"
        replicas = 1

        annotations = {
          "reloader.stakater.com/auto" = "true"
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/flaresolverr/flaresolverr"
              tag        = "v3.3.21"
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
            port = 8191
          }
        }
      }
    }
  })]
}
