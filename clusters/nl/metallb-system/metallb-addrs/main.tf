resource "kubernetes_manifest" "manifests" {
  for_each = fileset("./", "*.yaml")
  manifest = yamldecode(file("./${each.key}"))
}
