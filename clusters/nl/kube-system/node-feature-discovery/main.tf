resource "helm_release" "node_feature_discovery" {
  name            = "node-feature-discovery"
  repository      = "https://kubernetes-sigs.github.io/node-feature-discovery/charts"
  chart           = "node-feature-discovery"
  namespace       = "kube-system"
  version         = "0.17.4"
  cleanup_on_fail = true
}
