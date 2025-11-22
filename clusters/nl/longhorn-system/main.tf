resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  version          = "1.10.0"
  create_namespace = true
  cleanup_on_fail  = true
  values           = [file("${path.module}/values.yaml")]
}

variable "longhorn_crypto" {
  type        = map(string)
  description = "Encryption at rest parameters for Longhorn volumes"
  sensitive   = true
}

resource "kubernetes_secret_v1" "longhorn_crypto" {
  metadata {
    name      = "longhorn-crypto"
    namespace = "longhorn-system"
  }

  data = var.longhorn_crypto
}

resource "kubernetes_config_map_v1" "longhorn_nixos_path" {
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
    kubernetes_config_map_v1.longhorn_nixos_path
  ]

  manifest = yamldecode(file("${path.module}/longhorn-add-nixos-path.yaml"))
}

resource "kubernetes_manifest" "longhorn_storage_classes" {
  depends_on = [helm_release.longhorn]

  for_each = fileset("${path.module}/storageClasses", "*.yaml")
  manifest = yamldecode(file("${path.module}/storageClasses/${each.key}"))
}

resource "kubernetes_manifest" "longhorn_recurring_jobs" {
  depends_on = [helm_release.longhorn]

  for_each = fileset("${path.module}/recurringJobs", "*.yaml")
  manifest = yamldecode(file("${path.module}/recurringJobs/${each.key}"))
}
