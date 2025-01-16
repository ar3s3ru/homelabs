variable "google_oauth_client_id" {
  type        = string
  description = "Google OAuth client ID for the Authentik source"
  sensitive   = true
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Google OAuth client secret for the Authentik source"
  sensitive   = true
}

resource "authentik_source_oauth" "name" {
  name                = "Google"
  slug                = "google"
  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = data.authentik_flow.default_source_enrollment.id

  provider_type   = "google"
  consumer_key    = var.google_oauth_client_id
  consumer_secret = var.google_oauth_client_secret
}

# Source: https://docs.goauthentik.io/docs/users-sources/sources/social-logins/google/
#
# NOTE: some of the mentioned setup has been made manually.
# FIXME: find a way to port those here in automation.
resource "authentik_policy_expression" "username_as_email" {
  name       = "username-as-email"
  expression = <<EOT
email = request.context["prompt_data"]["email"]
request.context["prompt_data"]["username"] = email
return False
  EOT
}
