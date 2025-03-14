# NOTE(ar3s3ru): turns out we cannot set the configuration ahead of time.
#
# jellyfin-plugin-sso tries to write to the content of SSO-Auth.xml after first auth,
# so the approach with a ConfigMap won't really work.

# variable "authentik_host" {
#   type        = string
#   description = "Authentik public hostname"
# }

# variable "oauth_client_id" {
#   type        = string
#   description = "OAuth client id for Jellyfin provider"
# }

# variable "oauth_client_secret" {
#   type        = string
#   description = "OAuth client secret for Jellyfin provider"
#   sensitive   = true
# }

# resource "kubernetes_config_map_v1" "jellyfin_sso_auth_config" {
#   metadata {
#     name      = "jellyfin-sso-auth-config"
#     namespace = "media"
#   }

#   data = {
#     "SSO-Auth.xml" = templatefile("./configurations/SSO-Auth.xml", {
#       host          = var.authentik_host
#       client_id     = var.oauth_client_id
#       client_secret = var.oauth_client_secret
#     })
#   }
# }
