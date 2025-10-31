resource "kubernetes_manifest" "cnpg_cluster" {
  manifest = yamldecode(file("${path.module}/values-cnpg.yaml"))
}
