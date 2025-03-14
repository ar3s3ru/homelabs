resource "authentik_group" "media_viewer" {
  name = "media-viewer"
  users = [
    data.authentik_user.ss_sa_469923_at_gmail_com.id
  ]
}

resource "authentik_group" "media_admin" {
  name = "media-admin"
  users = [
    data.authentik_user.danilocianfr_at_gmail_com.id
  ]
}
