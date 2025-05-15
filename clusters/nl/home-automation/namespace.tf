resource "kubernetes_namespace" "home-automation" {
  metadata {
    name = "home-automation"
  }
}
