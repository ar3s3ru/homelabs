resource "helm_release" "metallb" {
  name            = "metallb"
  repository      = "https://metallb.github.io/metallb"
  chart           = "metallb"
  namespace       = "networking"
  version         = "0.14.9"
  cleanup_on_fail = true

  values = [yamlencode({
    speaker = {
      frr = { enabled = true }
    }
  })]
}

resource "kubernetes_manifest" "ip_address_pool" {
  depends_on = [helm_release.metallb]

  manifest = yamldecode(<<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: networking
spec:
  addresses:
  - 192.168.2.200-192.168.2.253
  EOF
  )
}

resource "kubernetes_manifest" "l2_advertisement" {
  depends_on = [kubernetes_manifest.ip_address_pool]

  manifest = yamldecode(<<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: networking
spec:
  ipAddressPools:
  - default
  EOF
  )
}
