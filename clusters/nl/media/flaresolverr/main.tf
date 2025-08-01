resource "helm_release" "flaresolverr" {
  name            = "flaresolverr"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "media"
  version         = "4.1.2"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
