resource "helm_release" "nvidia_device_plugin" {
  name            = "nvidia-device-plugin"
  repository      = "https://nvidia.github.io/k8s-device-plugin"
  chart           = "nvidia-device-plugin"
  namespace       = "default"
  version         = "0.17.0"
  cleanup_on_fail = true

  values = [yamlencode({
    allowDefaultNamespace  = true
    deviceDiscoverStrategy = "nvml"
    gfd                    = { enabled = true }
    nfs                    = { enabled = true }
  })]
}
