resource "kubernetes_namespace_v1" "home_automation" {
  metadata {
    name = "home-automation"
  }
}
