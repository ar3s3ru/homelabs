resource "authentik_group" "home_member" {
  name = "home-member"
}

resource "authentik_group" "home_admin" {
  name = "home-admin"
  users = [
    data.authentik_user.danilocianfr_at_gmail_com.id
  ]
}
