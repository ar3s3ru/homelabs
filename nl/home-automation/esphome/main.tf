resource "kubernetes_persistent_volume_v1" "esphome_config" {
  metadata {
    name = "esphome-config-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "100M" # NOTE: this is the size of the partition.
    }

    persistent_volume_source {
      host_path {
        path = "/media/config/esphome"
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

resource "kubernetes_persistent_volume_claim_v1" "esphome_config" {
  metadata {
    name      = "esphome-config-pvc"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.esphome_config.metadata[0].name

    resources {
      requests = {
        storage = "100M" # NOTE: this is the size of the partition.
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "esphome_cache" {
  metadata {
    name = "esphome-cache-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/media/cache/esphome"
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

resource "kubernetes_persistent_volume_claim_v1" "esphome_cache" {
  metadata {
    name      = "esphome-cache-pvc"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.esphome_cache.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}

resource "helm_release" "esphome" {
  name             = "esphome"
  repository       = "https://bjw-s.github.io/helm-charts"
  chart            = "app-template"
  namespace        = "home-automation"
  version          = "3.7.2"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
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
              repository = "ghcr.io/esphome/esphome"
              tag        = "2025.2.2"
            }
            securityContext = {
              privileged = true # Required to access the /dev/ttyUSB0 device
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
            port = 6052
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-esphome",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-esphome"] }]
      }
    }

    persistence = {
      cache = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.esphome_cache.metadata[0].name
        globalMounts  = [{ path = "/cache" }]
      }
      config = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.esphome_config.metadata[0].name
        globalMounts  = [{ path = "/config" }]
      }
      dev-ttyusb0 = {
        enabled      = true
        type         = "hostPath"
        hostPath     = "/dev/ttyUSB0"
        globalMounts = [{ path = "/dev/ttyUSB0" }]
      }
    }
  })]
}
