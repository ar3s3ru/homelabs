resource "kubernetes_ingress_v1" "kube_api" {
  metadata {
    name = "flugg-kube-api"
    annotations = {
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/ssl-passthrough"  = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"
    rule {
      host = "k8s.flugg.app"
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kubernetes"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}
