resource "helm_release" "akri" {
  name             = "akri"
  repository       = "https://project-akri.github.io/akri/"
  chart            = "akri"
  namespace        = "kube-system"
  version          = "0.13.8"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    # Expose metrics.
    prometheus = { enabled = true }
  })]
}
