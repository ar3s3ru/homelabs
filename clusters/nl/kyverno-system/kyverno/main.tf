resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno"
  chart            = "kyverno"
  namespace        = "kyverno-system"
  version          = "3.4.4"
  create_namespace = true
  cleanup_on_fail  = true
}
