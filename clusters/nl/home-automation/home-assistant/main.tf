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

resource "kubernetes_persistent_volume_claim_v1" "home_assistant_config" {
  metadata {
    name      = "home-assistant-config"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.home_assistant_config.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "home_assistant_media" {
  metadata {
    name = "home-assistant-media"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/home-automation/home-assistant/media"
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

resource "kubernetes_persistent_volume_claim_v1" "home_assistant_media" {
  metadata {
    name      = "home-assistant-media"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.home_assistant_media.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "home_assistant_recordings" {
  metadata {
    name = "home-assistant-recordings"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/home-automation/home-assistant/recordings"
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

resource "kubernetes_persistent_volume_claim_v1" "home_assistant_recordings" {
  metadata {
    name      = "home-assistant-recordings"
    namespace = "home-automation"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.home_assistant_recordings.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}

variable "oauth_client_id" {
  type        = string
  description = "OAuth client ID to use for Home Assistant authentication"
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client ID to use for Home Assistant authentication"
  sensitive   = true
}

variable "home_assistant_hostname" {
  type        = string
  description = "Ingress hostname for Home Assistant on Tailscale"
}

resource "kubernetes_secret_v1" "home_assistant_secrets" {
  metadata {
    name      = "home-assistant-secrets"
    namespace = "home-automation"
  }

  data = {
    "HASS_OAUTH_CLIENT_ID"     = var.oauth_client_id
    "HASS_OAUTH_CLIENT_SECRET" = var.oauth_client_secret
  }
}

resource "kubernetes_config_map_v1" "home_assistant_configuration" {
  metadata {
    name      = "home-assistant-configuration"
    namespace = "home-automation"
  }

  data = {
    "configuration.yaml" = file("./config/configuration.yaml")
    "automations.yaml"   = file("./config/automations.yaml")
    "scenes.yaml"        = file("./config/scenes.yaml")
    "scripts.yaml"       = file("./config/scripts.yaml")
  }
}

resource "helm_release" "home_assistant" {
  name            = "home-assistant"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "home-automation"
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      hostNetwork = true # Required for certain network features.
      # NOTE: seems like this doesn't play well with custom components sadly...
      # securityContext = {
      #   runAsUser           = 1000
      #   runAsGroup          = 1000
      #   fsGroup             = 1000
      #   fsGroupChangePolicy = "OnRootMismatch"
      # }
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
              tag        = "2025.5.0"
            }
            env = {
              TZ               = "Europe/Amsterdam"
              PYTHONPATH       = "/config/deps"
              UV_SYSTEM_PYTHON = "true"
              UV_NO_CACHE      = "true"
            }
            envFrom = [
              { secretRef = { name = kubernetes_secret_v1.home_assistant_secrets.metadata[0].name } }
            ]
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
          host = var.home_assistant_hostname,
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "http"
            }
          }]
        }]

        tls = [{ hosts = [var.home_assistant_hostname] }]
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
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.home_assistant_config.metadata[0].name
        globalMounts  = [{ path = "/config" }]
      }
      media = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.home_assistant_media.metadata[0].name
        globalMounts  = [{ path = "/media" }]
      }
      recordings = {
        enabled       = true
        type          = "persistentVolumeClaim"
        existingClaim = kubernetes_persistent_volume_claim_v1.home_assistant_recordings.metadata[0].name
        globalMounts  = [{ path = "/mnt/recordings" }]
      }
      configuration = {
        enabled = true
        type    = "configMap"
        name    = kubernetes_config_map_v1.home_assistant_configuration.metadata[0].name
        globalMounts = [
          { path = "/config/configuration.yaml", subPath = "configuration.yaml", readOnly = true },
          { path = "/config/automations.yaml", subPath = "automations.yaml", readOnly = true },
          { path = "/config/scenes.yaml", subPath = "scenes.yaml", readOnly = true },
          { path = "/config/scripts.yaml", subPath = "scripts.yaml", readOnly = true }
        ]
      }
    }
  })]
}
