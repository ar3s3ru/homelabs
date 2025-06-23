variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace in which to deploy these resources"
}

resource "helm_release" "cert_manager" {
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  namespace       = var.kubernetes_namespace
  version         = "v1.18.1"
  cleanup_on_fail = true

  values = [yamlencode({
    crds = { enabled = true }
    prometheus = {
      enabled        = true
      servicemonitor = { enabled = true }
    }
  })]
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token to use for DNS01 challenges"
  sensitive   = true
}

resource "kubernetes_secret" "cert_manager_cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = var.kubernetes_namespace
  }

  data = {
    api-token = var.cloudflare_api_token
  }
}

resource "kubernetes_manifest" "cert_manager_acme_issuer" {
  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"

    metadata = {
      name = "acme"
    }

    spec = {
      acme = {
        email  = "danilocianfr+letsencrypt@gmail.com"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "cert-manager-acme-issuer-account-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = kubernetes_secret.cert_manager_cloudflare_api_token.metadata[0].name
                key  = "api-token"
              }
            }
          }
        }]
      }
    }
  }
}
