resource "helm_release" "emqx" {
  name            = "emqx"
  repository      = "https://repos.emqx.io/charts"
  chart           = "emqx"
  namespace       = "home-automation"
  version         = "5.8.7"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
