resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = true
}

resource "authentik_group" "home_member" {
  name = "home-member"
}

resource "authentik_group" "home_admin" {
  name = "home-admin"
}

resource "authentik_group" "media_viewer" {
  name = "media-viewer"
}

resource "authentik_group" "media_admin" {
  name = "media-admin"
}
