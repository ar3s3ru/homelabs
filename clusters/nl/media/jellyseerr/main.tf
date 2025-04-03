locals {
  hostname = "jellyseerr.nl.ar3s3ru.dev"
}


resource "kubernetes_persistent_volume_v1" "jellyseerr_config" {
  metadata {
    name = "jellyseerr-config-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "50M"
    }

    persistent_volume_source {
      host_path {
        path = "/media/config/jellyseerr"
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

resource "kubernetes_persistent_volume_claim_v1" "jellyseerr_config" {
  metadata {
    name      = "jellyseerr-config-pvc"
    namespace = "media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.jellyseerr_config.metadata[0].name

    resources {
      requests = {
        storage = "50M"
      }
    }
  }
}

resource "helm_release" "jellyseerr" {
  name            = "jellyseerr"
  repository      = "https://bjw-s.github.io/helm-charts"
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
              repository = "docker.io/fallenbagel/jellyseerr"
              tag        = "2.5.2"
            }
            env = {
              TZ        = "Europe/Amsterdam"
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
            port = 5055
          }
        }
      }
    }

    ingress = {
      main = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = "acme"
        }
        hosts = [{
          host = local.hostname,
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{
          hosts      = [local.hostname],
          secretName = "jellyseerr-tls"
        }]
      }
    }

    persistence = {
      config = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.jellyseerr_config.metadata[0].name
        globalMounts  = [{ path = "/app/config" }]
      }
    }
  })]
}
