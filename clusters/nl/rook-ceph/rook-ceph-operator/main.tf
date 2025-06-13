resource "helm_release" "rook_ceph" {
  name            = "rook-ceph"
  repository      = "https://charts.rook.io/release"
  chart           = "rook-ceph"
  namespace       = "rook-ceph"
  create_namespace = true
  cleanup_on_fail = true

  values = [yamlencode({
    monitoring = { enabled = true }
    csi = {
      # NixOS-specific settings.
      csiRBDPluginVolume = [
        {
          name = "lib-modules",
          hostPath = { path = "/run/booted-system/kernel-modules/lib/modules/" }
        },
        {
          name = "host-nix",
          hostPath = { path = "/nix" }
        }
      ],
      csiRBDPluginVolumeMount = [
        {
          name = "host-nix",
          mountPath = "/nix",
          readOnly = true
        }
      ]
      csiCephFSPluginVolume = [
        {
          name = "lib-modules",
          hostPath = { path = "/run/booted-system/kernel-modules/lib/modules/" }
        },
        {
          name = "host-nix",
          hostPath = { path = "/nix" }
        }
      ],
      csiCephFSPluginVolumeMount = [
        {
          name = "host-nix",
          mountPath = "/nix",
          readOnly = true
        }
      ]
    }
  })]
}
