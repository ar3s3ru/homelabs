resource "kubernetes_persistent_volume_v1" "home_assistant_config" {
  metadata {
    name = "home-assistant-config"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/home-automation/home-assistant/config"
      }
    }
  }
}

resource "kubernetes_config_map_v1" "home_assistant_configuration" {
  metadata {
    name      = "home-assistant-configuration"
    namespace = "home-automation"
  }

  data = {
    "configuration.yaml" = file("./configuration.yaml")
  }
}

resource "helm_release" "home_assistant" {
  name            = "home-assistant"
  repository      = "https://bjw-s.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "home-automation"
  version         = "3.6.1"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true # Required for certain network features.
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
              repository = "ghcr.io/home-assistant/home-assistant"
              tag        = "2025.1.2"
            }
            env = {
              TZ               = "Europe/Amsterdam"
              PYTHONPATH       = "/config/deps"
              UV_SYSTEM_PYTHON = "true"
              UV_NO_CACHE      = "true"
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
            port = 8123
          }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "nl-hass",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = ["nl-hass"] }]
      }
    }

    persistence = {
      tmp = {
        enabled      = true
        type         = "emptyDir"
        globalMounts = [{ path = "/tmp" }]
      }
      udev = { # This is used for access to Bluetooth.
        enabled      = true
        type         = "hostPath"
        hostPath     = "/run/udev"
        globalMounts = [{ path = "/run/udev" }]
      }
      dbus = { # This is used for access to Bluetooth.
        enabled      = true
        type         = "hostPath"
        hostPath     = "/run/dbus"
        globalMounts = [{ path = "/run/dbus", readOnly = true }]
      }
      config = {
        enabled      = true
        type         = "persistentVolumeClaim"
        accessMode   = "ReadWriteOnce"
        size         = "10G"
        globalMounts = [{ path = "/config" }]
        volumeName   = kubernetes_persistent_volume_v1.home_assistant_config.metadata[0].name
      }
      configuration = {
        enabled      = true
        type         = "configMap"
        name         = kubernetes_config_map_v1.home_assistant_configuration.metadata[0].name
        globalMounts = [{ path = "/config/configuration.yaml", subPath = "configuration.yaml", readOnly = true }]
      }
    }
  })]
}
