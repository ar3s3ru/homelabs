resource "helm_release" "nvidia_device_plugin" {
  name            = "nvidia-device-plugin"
  repository      = "https://nvidia.github.io/k8s-device-plugin"
  chart           = "nvidia-device-plugin"
  namespace       = "default"
  version         = "0.17.4"
  cleanup_on_fail = true

  values = [yamlencode({
    allowDefaultNamespace   = true
    deviceDiscoveryStrategy = "nvml"
    gfd                     = { enabled = true }
    nfd                     = { enabled = true }
  })]
}
