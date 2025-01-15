variable "oauth_client_id" {
  type        = string
  description = "Tailscale OAuth client ID for the Kubernetes operator"
  sensitive   = true
}

variable "oauth_client_secret" {
  type        = string
  description = "Tailscale OAuth client secret for the Kubernetes operator"
  sensitive   = true
}

resource "kubernetes_cluster_role_binding" "ar3s3ru_cluster_admin" {
  metadata {
    name = "ar3s3ru-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = "danilocianfr@gmail.com"
  }
}

resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  version          = "1.78.3"
  chart            = "tailscale-operator"
  namespace        = "networking"
  create_namespace = true

  values = [
    yamlencode({
      apiServerProxyConfig = {
        mode = "true"
      }
    })
  ]

  # TODO(ar3s3ru): this should be moved to a proper Kubernetes secret through pass.
  set_sensitive {
    name  = "oauth.clientId"
    value = var.oauth_client_id
  }

  set_sensitive {
    name  = "oauth.clientSecret"
    value = var.oauth_client_secret
  }
}
