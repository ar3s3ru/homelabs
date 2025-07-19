resource "helm_release" "minio_operator" {
  name             = "minio-operator"
  repository       = "https://operator.min.io"
  chart            = "operator"
  namespace        = "minio-system"
  version          = "7.1.1"
  cleanup_on_fail  = true
  create_namespace = true
  values           = [file("./values-operator.yaml")]
}
