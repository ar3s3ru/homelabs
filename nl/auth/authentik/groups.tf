resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = true
  users = [
    data.authentik_user.danilocianfr_at_gmail_com.id
  ]
}
