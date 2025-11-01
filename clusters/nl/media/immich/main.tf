locals {
  namespace = "media"
  config    = yamldecode(file("${path.module}/config.yaml"))
  oauth     = local.config["oauth"]
}

resource "kubernetes_persistent_volume_claim_v1" "immich_library_v3" {
  metadata {
    name      = "immich-library-v3"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "zfs-generic-nfs-csi"
    access_modes       = ["ReadWriteMany"] # NOTE: required for RollingUpdate strategy.
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "1Ti"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "immich-ml-cache-v3" {
  metadata {
    name      = "immich-ml-cache-v3"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client secret for Immich provider"
  sensitive   = true
}

resource "kubernetes_config_map_v1" "immich_config" {
  metadata {
    name      = "immich-config"
    namespace = local.namespace
  }

  data = {
    # If you're wondering why:
    # https://github.com/immich-app/immich/discussions/14815
    "immich-config.yaml" = yamlencode(merge(
      local.config,
      {
        oauth = merge(local.oauth, {
          clientSecret = var.oauth_client_secret
        })
      }
    ))
  }
}

resource "kubernetes_manifest" "cnpg_cluster" {
  manifest = yamldecode(file("${path.module}/immich-cnpg-cluster.yaml"))
}

resource "helm_release" "immich_server" {
  name            = "immich-server"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = local.namespace
  version         = "4.4.0"
  cleanup_on_fail = true
  values          = [file("${path.module}/values-server.yaml")]

  depends_on = [
    kubernetes_config_map_v1.immich_config,
    kubernetes_persistent_volume_claim_v1.immich_library_v3,
  ]
}

resource "helm_release" "immich_machine_learning" {
  name            = "immich-machine-learning"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = local.namespace
  version         = "4.4.0"
  cleanup_on_fail = true
  values          = [file("${path.module}/values-machine-learning.yaml")]

  depends_on = [
    kubernetes_persistent_volume_claim_v1.immich-ml-cache-v3
  ]
}
