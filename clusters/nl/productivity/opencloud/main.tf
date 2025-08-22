locals {
  namespace = "productivity"
}

variable "smtp_username" {
  type        = string
  description = "SMTP username for the OpenCloud deployment"
  sensitive   = true
}

variable "smtp_password" {
  type        = string
  description = "SMTP password for the OpenCloud deployment"
  sensitive   = true
}

resource "kubernetes_secret_v1" "opencloud_smtp" {
  metadata {
    name      = "opencloud-smtp-secrets"
    namespace = local.namespace
  }

  data = {
    "smtpUser"     = var.smtp_username
    "smtpPassword" = var.smtp_password
  }
}

resource "random_password" "opencloud_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret_v1" "opencloud_admin" {
  metadata {
    name      = "opencloud-secrets"
    namespace = local.namespace
  }

  data = {
    "adminPassword" = random_password.opencloud_admin_password.result
  }
}

# FIXME(ar3s3ru): this workaround is only necessary due to the chart
# hardcoding the requirement for MinIO credentials (and usage).
resource "kubernetes_secret_v1" "opencloud_minio" {
  metadata {
    name      = "opencloud-minio"
    namespace = local.namespace
  }

  data = {
    "rootUser"     = ""
    "rootPassword" = ""
  }
}

data "helm_template" "opencloud_template" {
  name       = "opencloud"
  repository = "oci://ghcr.io/opencloud-eu/helm-charts"
  chart      = "opencloud"
  version    = "0.2.3"
  namespace  = local.namespace
  values     = [file("${path.module}/values-opencloud.yaml")]
}

resource "local_file" "opencloud_manifests" {
  for_each = data.helm_template.opencloud_template.manifests
  content  = each.value
  filename = "${path.module}/${each.key}"
}

resource "helm_release" "opencloud" {
  name            = "opencloud"
  repository      = "oci://ghcr.io/opencloud-eu/helm-charts"
  chart           = "opencloud"
  version         = "0.2.3"
  namespace       = local.namespace
  cleanup_on_fail = true
  values          = [file("${path.module}/values-opencloud.yaml")]

  depends_on = [
    helm_release.nats,
    kubernetes_secret_v1.opencloud_admin,
    kubernetes_secret_v1.opencloud_smtp
  ]
}
