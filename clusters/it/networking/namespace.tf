resource "kubernetes_namespace" "networking" {
  metadata {
    name = "networking"
  }
}
