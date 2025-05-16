data "authentik_flow" "default_source_authentication" {
  slug = "default-source-authentication"
}

data "authentik_flow" "default_source_enrollment" {
  slug = "default-source-enrollment"
}

data "authentik_flow" "default_authentication_flow" {
  slug = "default-authentication-flow"
}

data "authentik_stage" "default_authentication_identification" {
  name = "default-authentication-identification"
}

data "authentik_flow" "default_provider_authorization_implicit_consent" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_provider_authorization_explicit_consent" {
  slug = "default-provider-authorization-explicit-consent"
}

data "authentik_flow" "default_provider_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}
