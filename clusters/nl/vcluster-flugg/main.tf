resource "helm_release" "vcluster_flugg" {
  name       = "vcluster-flugg"
  repository = "https://charts.loft.sh"
  chart      = "vcluster"
  namespace  = "vcluster-flugg"
  # version          = "1.29.6"
  cleanup_on_fail  = true
  create_namespace = true
  values           = [file("${path.module}/values.yaml")]
}
