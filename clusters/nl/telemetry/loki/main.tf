variable "minio_access_key" {
  type        = string
  description = "MinIO access key for Loki storage"
  sensitive   = true
}

variable "minio_secret_key" {
  type        = string
  description = "MinIO secret key for Loki storage"
  sensitive   = true
}

resource "helm_release" "loki" {
  name            = "loki"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "loki"
  version         = "6.30.1"
  namespace       = "telemetry"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]

  set_sensitive {
    name  = "loki.storage.s3.accessKeyId"
    value = var.minio_access_key
  }

  set_sensitive {
    name  = "loki.storage.s3.secretAccessKey"
    value = var.minio_secret_key
  }
}
