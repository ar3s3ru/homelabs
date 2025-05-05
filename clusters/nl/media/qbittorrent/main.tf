locals {
  webui_port = 8080
}

resource "kubernetes_persistent_volume_v1" "qbittorrent" {
  metadata {
    name = "qbittorrent-pv"
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

resource "kubernetes_persistent_volume_claim_v1" "qbittorrent" {
  metadata {
    name      = "qbittorrent-pvc"
    namespace = "media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.qbittorrent.metadata[0].name

    resources {
      requests = {
        storage = "263.7G" # NOTE: this is the size of the partition.
      }
    }
  }
}

resource "helm_release" "qbittorrent" {
  name             = "qbittorrent"
  repository       = "https://bjw-s.github.io/helm-charts"
  chart            = "app-template"
  namespace        = "media"
  version          = "3.7.3"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true
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
              repository = "ghcr.io/linuxserver/qbittorrent"
              tag        = "5.1.0"
            }
            env = {
              TZ              = "Europe/Amsterdam"
              PGUID           = 1000
              PGID            = 1000
              WEBUI_PORT      = local.webui_port
              TORRENTING_PORT = 6881
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
            port = local.webui_port
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-torrent",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-torrent"] }]
      }
    }

    persistence = {
      config = {
        enabled      = true
        type         = "persistentVolumeClaim"
        accessMode   = "ReadWriteOnce"
        size         = "50M"
        globalMounts = [{ path = "/config" }]
      }
      downloads = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.qbittorrent.metadata[0].name
        globalMounts  = [{ path = "/media" }]
      }
    }
  })]
}
