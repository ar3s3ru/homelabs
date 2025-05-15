variable "jellyfin_host" {
  type        = string
  description = "Jellyfin public hostname"
}

locals {
  jellyfin_provider_name = "Authentik" # This is set on Jellyfin SSO plugin!
}

data "authentik_property_mapping_provider_scope" "oauth_scope_openid" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

resource "authentik_provider_oauth2" "jellyfin" {
  name                       = "Jellyfin"
  client_id                  = "jellyfin"
  client_type                = "confidential"
  authentication_flow        = data.authentik_flow.default_authentication_flow.id
  authorization_flow         = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow          = data.authentik_flow.default_provider_invalidation_flow.id
  include_claims_in_id_token = true
  issuer_mode                = "per_provider"
  signing_key                = data.authentik_certificate_key_pair.self_signed.id

  allowed_redirect_uris = [{
    url           = "https://${var.jellyfin_host}/sso/OID/redirect/${local.jellyfin_provider_name}"
    matching_mode = "strict"
  }]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.oauth_scope_openid.id,
    data.authentik_property_mapping_provider_scope.oauth_scope_profile.id,
  ]
}

output "jellyfin_client_id" {
  value = authentik_provider_oauth2.jellyfin.client_id
}

output "jellyfin_client_secret" {
  value     = authentik_provider_oauth2.jellyfin.client_secret
  sensitive = true
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_oauth2.jellyfin.id
}
