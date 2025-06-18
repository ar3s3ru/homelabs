resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  version          = "1.9.0"
  create_namespace = true
  cleanup_on_fail  = true

  values = [yamlencode({
    defaultSettings = {
      defaultDataLocality = true
      defaultReplicaCount = 1
      defaultStorageClass = true
      defaultSchedulingPolicy = {
        allowVolumeExpansion  = true
        allowVolumeScheduling = true
      }
    }

    longhornUI = { replicas = 1 }

    ingress = {
      enabled          = true
      ingressClassName = "tailscale"
      host             = "nl-longhorn"
      tls              = true
    }
  })]
}

variable "longhorn_crypto" {
  type = map(string)
  description = "Encryption at rest parameters for Longhorn volumes"
  sensitive = true
}

resource "kubernetes_secret_v1" "longhorn_crypto" {
  metadata {
    name = "longhorn-crypto"
    namespace = "longhorn-system"
  }

  data = var.longhorn_crypto
}

resource "kubernetes_config_map_v1" "longhorn_nixos_path" {
  depends_on = [helm_release.longhorn]

  metadata {
    name      = "longhorn-nixos-path"
    namespace = "longhorn-system"
  }

  data = {
    "PATH" = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
  }
}

resource "kubernetes_manifest" "longhorn_add_nixos_path" {
  depends_on = [
    helm_release.longhorn,
    kubernetes_config_map_v1.longhorn_nixos_path
  ]

  manifest = yamldecode(file("./longhorn-add-nixos-path.yaml"))
}

resource "kubernetes_manifest" "longhorn_storage_classes" {
  depends_on = [helm_release.longhorn]

  for_each = fileset("./storageClasses", "*.yaml")
  manifest = yamldecode(file("./storageClasses/${each.key}"))
}
