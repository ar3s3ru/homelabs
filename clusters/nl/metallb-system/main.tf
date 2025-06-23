resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  version          = "0.15.2"
  cleanup_on_fail  = true
  create_namespace = true
  values           = [file("./values.yaml")]
}
