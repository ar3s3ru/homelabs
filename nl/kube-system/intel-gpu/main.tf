resource "helm_release" "intel_device_plugins_operator" {
  name            = "intel-device-plugins-operator"
  repository      = "https://intel.github.io/helm-charts/"
  chart           = "intel-device-plugins-operator"
  namespace       = "kube-system"
  version         = "0.32.0"
  cleanup_on_fail = true
}

resource "helm_release" "intel_device_plugins_gpu" {
  depends_on = [helm_release.intel_device_plugins_operator]

  name            = "intel-device-plugins-gpu"
  repository      = "https://intel.github.io/helm-charts/"
  chart           = "intel-device-plugins-gpu"
  namespace       = "kube-system"
  version         = "0.32.0"
  cleanup_on_fail = true

  values = [yamlencode({
    sharedDevNum    = 4
    nodeFeatureRule = true
  })]
}
