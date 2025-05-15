variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where to deploy the module resources"
}

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
  name = "tailscale-operator"
  # NOTE: switched to the "unstable" Helm chart to fix https://github.com/tailscale/tailscale/issues/15081
  repository       = "https://pkgs.tailscale.com/unstable/helmcharts"
  version          = "1.83.106"
  chart            = "tailscale-operator"
  namespace        = var.kubernetes_namespace
  cleanup_on_fail  = true

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
