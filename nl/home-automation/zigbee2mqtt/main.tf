resource "kubernetes_manifest" "akri_sonoff_zigbee_antenna" {
  manifest = yamldecode(file("./sonoff-antenna.yaml"))
}

resource "kubernetes_persistent_volume_v1" "zigbee2mqtt" {
  metadata {
    name = "zigbee2mqtt-pv"
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "1Gi"
    }

    persistent_volume_source {
      host_path {
        path = "/home/k3s/home-automation/zigbee2mqtt"
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

resource "helm_release" "zigbee2mqtt" {
  depends_on = [kubernetes_manifest.akri_sonoff_zigbee_antenna]

  name            = "zigbee2mqtt"
  repository      = "https://charts.zigbee2mqtt.io/"
  chart           = "zigbee2mqtt"
  namespace       = "home-automation"
  version         = "2.1.3"
  cleanup_on_fail = true

  values = [yamlencode({
    ingress = {
      enabled          = true
      ingressClassName = "tailscale"
      hosts = [{
        host  = "nl-z2m"
        paths = [{ path = "/", pathType = "Prefix" }]
      }]
      tls = [{ hosts = ["nl-z2m"] }]
    }

    statefulset = {
      resources = {
        requests = {
          "akri.sh/sonoff-zigbee-antenna" = "1"
        }
        limits = {
          "akri.sh/sonoff-zigbee-antenna" = "1"
        }
      }

      storage = {
        enabled          = true
        storageClassName = "local-path"
        existingVolume   = kubernetes_persistent_volume_v1.zigbee2mqtt.metadata[0].name
      }
    }

    zigbee2mqtt = {
      permit_join = true

      mqtt = {
        server = "mqtt://emqx.home-automation.svc.cluster.local:1883"
      }

      serial = {
        port    = "/dev/ttyUSB0"
        adapter = "ezsp" # Sonoff dongle is based on Silicon Labs.
      }
    }
  })]
}
