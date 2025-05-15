resource "kubernetes_namespace" "telemetry" {
  metadata {
    name = "telemetry"
  }
}
