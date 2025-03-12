locals {
  zigbee_dongle_path = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_76fad97b4a4eef11986846b3174bec31-if00-port0"
}

resource "helm_release" "zigbee2mqtt" {
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
      nodeSelector = {
        "kubernetes.io/hostname" = "momonoke"
      }

      volumes = [{
        name     = "zigbee-antenna"
        hostPath = { path = local.zigbee_dongle_path }
      }]

      volumeMounts = [{
        name      = "zigbee-antenna"
        mountPath = local.zigbee_dongle_path
      }]
    }

    zigbee2mqtt = {
      permit_join = true

      mqtt = {
        server = "mqtt://emqx.home-automation.svc.cluster.local:1883"
      }

      serial = {
        port    = local.zigbee_dongle_path
        adapter = "ezsp" # Sonoff dongle is based on Silicon Labs.
      }
    }
  })]
}
