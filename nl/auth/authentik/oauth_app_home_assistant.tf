data "authentik_certificate_key_pair" "self_signed" {
  name = "authentik Self-signed Certificate"
}

data "authentik_property_mapping_provider_scope" "oauth_scope_email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_property_mapping_provider_scope" "oauth_scope_profile" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}

resource "authentik_provider_oauth2" "home_assistant" {
  name                       = "Home Assistant"
  client_id                  = "home-assistant"
  client_type                = "confidential"
  authentication_flow        = data.authentik_flow.default_authentication_flow.id
  authorization_flow         = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow          = data.authentik_flow.default_provider_invalidation_flow.id
  include_claims_in_id_token = true
  issuer_mode                = "per_provider"
  signing_key                = data.authentik_certificate_key_pair.self_signed.id

  allowed_redirect_uris = [{
    url           = "https://nl-hass.tail2ff90.ts.net/auth/oidc/callback"
    matching_mode = "strict"
  }]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.oauth_scope_email.id,
    data.authentik_property_mapping_provider_scope.oauth_scope_profile.id,
  ]
}

output "home_assistant_client_id" {
  value = authentik_provider_oauth2.home_assistant.client_id
}

output "home_assistant_client_secret" {
  value     = authentik_provider_oauth2.home_assistant.client_secret
  sensitive = true
}

resource "authentik_application" "home_assistant" {
  name              = "Home Assistant"
  slug              = "home-assistant"
  protocol_provider = authentik_provider_oauth2.home_assistant.id
}
