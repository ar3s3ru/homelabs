# https://kubernetes.github.io/ingress-nginx/deploy/
resource "helm_release" "ingress_nginx" {
  name            = "ingress-nginx"
  repository      = "https://kubernetes.github.io/ingress-nginx"
  chart           = "ingress-nginx"
  version         = "4.13.2"
  namespace       = "networking"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
