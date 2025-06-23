resource "kubernetes_manifest" "akri_sonoff_zigbee_antenna" {
  manifest = yamldecode(file("./sonoff-antenna.yaml"))
}

resource "helm_release" "zigbee2mqtt" {
  depends_on = [kubernetes_manifest.akri_sonoff_zigbee_antenna]

  name            = "zigbee2mqtt"
  repository      = "https://charts.zigbee2mqtt.io/"
  chart           = "zigbee2mqtt"
  namespace       = "home-automation"
  version         = "2.4.0"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
