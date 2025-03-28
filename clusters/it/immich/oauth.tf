variable "oauth_client_id" {
  type        = string
  description = "OAuth client id for Jellyfin provider"
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client secret for Jellyfin provider"
  sensitive   = true
}
