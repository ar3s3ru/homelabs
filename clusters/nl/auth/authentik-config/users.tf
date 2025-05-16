resource "authentik_user" "danilocianfr_at_gmail_com" {
  username = "danilocianfr@gmail.com"
  email    = "danilocianfr@gmail.com"
  name     = "Danilo Cianfrone"
  path     = "goauthentik.io/sources/google"

  groups = [
    authentik_group.admin.id,
    authentik_group.home_admin.id,
    authentik_group.media_admin.id,
  ]

  attributes = jsonencode({
    "goauthentik.io/user/sources" = [
      "Google"
    ]
  })
}

# resource "authentik_user" "ss_sa_469923_at_gmail_com" {
#   username = "ssa469923@gmail.com"
#   groups = [
#     authentik_group.home_member.id,
#     authentik_group.media_viewer.id,
#   ]
# }
