resource "kubernetes_namespace" "media" {
  metadata {
    name = "media"
  }
}
