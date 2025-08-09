locals {
  namespace = "home-automation"
}

variable "oauth_client_id" {
  type        = string
  description = "OAuth client ID to use for Home Assistant authentication"
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client ID to use for Home Assistant authentication"
  sensitive   = true
}

variable "home_assistant_hostname" {
  type        = string
  description = "Ingress hostname for Home Assistant on Tailscale"
}

resource "kubernetes_secret_v1" "home_assistant_oauth_secrets" {
  metadata {
    name      = "home-assistant-oauth-secrets"
    namespace = local.namespace
  }

  data = {
    "HASS_OAUTH_CLIENT_ID"     = var.oauth_client_id
    "HASS_OAUTH_CLIENT_SECRET" = var.oauth_client_secret
  }
}

resource "kubernetes_config_map_v1" "home_assistant_configuration" {
  metadata {
    name      = "home-assistant-configuration"
    namespace = local.namespace
  }

  data = { for file in fileset("./config", "*.yaml") : file => file("./config/${file}") }
}

variable "config_secrets_yaml" {
  type        = string
  description = "Content of secrets.yaml file for Home Assistant"
  sensitive   = true
}

resource "kubernetes_secret_v1" "home_assistant_secrets" {
  metadata {
    name      = "home-assistant-secrets"
    namespace = local.namespace
  }

  data = {
    "secrets.yaml" = var.config_secrets_yaml
  }
}

resource "kubernetes_persistent_volume_claim_v1" "home_assistant_config_v2" {
  metadata {
    name      = "home-assistant-config-v2"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteOnce"]
    volume_mode        = "Filesystem"

    resources {
      requests = {
        storage = "8Gi"
      }
    }
  }
}

resource "helm_release" "home_assistant" {
  name            = "home-assistant"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = local.namespace
  version         = "4.1.2"
  cleanup_on_fail = true
  values          = [file("${path.module}/values.yaml")]

  depends_on = [
    kubernetes_persistent_volume_claim_v1.home_assistant_config_v2
  ]
}
