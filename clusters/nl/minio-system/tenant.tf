resource "helm_release" "minio_tenant" {
  depends_on = [helm_release.minio_operator]

  name            = "minio-tenant"
  repository      = "https://operator.min.io"
  chart           = "tenant"
  namespace       = "minio-system"
  version         = "7.1.1"
  cleanup_on_fail = true
  values          = [file("./values-tenant.yaml")]
}
