resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "networking"
  version          = "0.14.9"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    speaker = {
      frr = { enabled = true }
    }
  })]
}
