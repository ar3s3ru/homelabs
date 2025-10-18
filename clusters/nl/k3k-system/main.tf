resource "helm_release" "k3k" {
  name             = "k3k"
  repository       = "https://rancher.github.io/k3k"
  chart            = "k3k"
  version          = "0.3.5"
  namespace        = "k3k-system"
  create_namespace = true
}

resource "kubernetes_manifest" "manifests" {
  for_each = fileset("${path.module}/clusters", "*.yaml")
  manifest = yamldecode(file("${path.module}/clusters/${each.value}"))

  depends_on = [
    helm_release.k3k
  ]
}
