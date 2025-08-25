variable "govee_email" {
  type        = string
  description = "Govee cloud account email address"
  sensitive   = false
}

variable "govee_password" {
  type        = string
  description = "Govee cloud account password"
  sensitive   = true
}

variable "govee_api_key" {
  type        = string
  description = "API key for the Undocumented Govee API"
  sensitive   = true
}

resource "kubernetes_secret_v1" "govee_secrets" {
  metadata {
    name      = "govee-secrets"
    namespace = "home-automation"
  }

  data = {
    "GOVEE_EMAIL"    = var.govee_email
    "GOVEE_PASSWORD" = var.govee_password
    "GOVEE_API_KEY"  = var.govee_api_key
  }
}

resource "helm_release" "govee2mqtt" {
  name            = "govee2mqtt"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "home-automation"
  version         = "4.2.0"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
