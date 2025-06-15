resource "kubernetes_manifest" "akri_sonoff_zigbee_antenna" {
  manifest = yamldecode(file("./sonoff-antenna.yaml"))
}

resource "helm_release" "zigbee2mqtt" {
  depends_on = [kubernetes_manifest.akri_sonoff_zigbee_antenna]

  name            = "zigbee2mqtt"
  repository      = "https://charts.zigbee2mqtt.io/"
  chart           = "zigbee2mqtt"
  namespace       = "home-automation"
  version         = "2.3.0"
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

    service = {
      type = "ClusterIP"
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
        storageClassName = "longhorn-nvme"
        size = "1Gi"
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

      availability = {
        enabled = true
        # Time after which an active device will be marked as offline in
        # minutes (default = 10 minutes)
        active = { timeout = 10 }
        # Time after which a passive device will be marked as offline in
        # minutes (default = 1500 minutes aka 25 hours)
        passive = { timeout = 1500 }
      }
    }
  })]
}
