locals {
  immich_hostname = "immich.tail2ff90.ts.net"
}

resource "authentik_provider_oauth2" "immich" {
  name                       = "Immich"
  client_id                  = "immich"
  client_type                = "confidential"
  authentication_flow        = data.authentik_flow.default_authentication_flow.id
  authorization_flow         = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow          = data.authentik_flow.default_provider_invalidation_flow.id
  include_claims_in_id_token = true
  issuer_mode                = "per_provider"
  signing_key                = data.authentik_certificate_key_pair.self_signed.id

  allowed_redirect_uris = [
    {
      url           = "https://${local.immich_hostname}/auth/login"
      matching_mode = "strict"
    },
    {
      url           = "https://${local.immich_hostname}/user-settings"
      matching_mode = "strict"
    },
    {
      url           = "app.immich:///oauth-callback" # Mobile app redirect
      matching_mode = "strict"
    },
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.oauth_scope_openid.id,
    data.authentik_property_mapping_provider_scope.oauth_scope_email.id,
    data.authentik_property_mapping_provider_scope.oauth_scope_profile.id,
  ]
}

output "immich_client_id" {
  value = authentik_provider_oauth2.immich.client_id
}

output "immich_client_secret" {
  value     = authentik_provider_oauth2.immich.client_secret
  sensitive = true
}

resource "authentik_application" "immich" {
  name              = authentik_provider_oauth2.immich.name
  slug              = authentik_provider_oauth2.immich.client_id
  protocol_provider = authentik_provider_oauth2.immich.id
}
