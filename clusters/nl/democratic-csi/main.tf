locals {
  namespace = "democratic-csi"
}

variable "driver_config_file_yaml" {
  type        = string
  description = "The content of the driver config file for democratic-csi."
  sensitive   = true
}

resource "kubernetes_namespace_v1" "democratic_csi" {
  metadata {
    name = local.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "kubernetes_secret_v1" "democratic_csi_driver_config_file" {
  metadata {
    name      = "democratic-csi-driver-config-file"
    namespace = kubernetes_namespace_v1.democratic_csi.metadata[0].name
  }

  data = {
    "driver-config-file.yaml" = var.driver_config_file_yaml
  }
}

resource "helm_release" "democratic_csi_zfs_nfs" {
  name       = "zfs-nfs"
  repository = "https://democratic-csi.github.io/charts/"
  chart      = "democratic-csi"
  # version          = "0.14.6"
  namespace        = kubernetes_namespace_v1.democratic_csi.metadata[0].name
  cleanup_on_fail  = true
  create_namespace = false

  values = [
    file("${path.module}/values.yaml")
  ]

  depends_on = [
    kubernetes_secret_v1.democratic_csi_driver_config_file
  ]
}
