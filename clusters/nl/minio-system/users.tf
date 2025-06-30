locals {
  users = toset([
    "loki"
  ])
}

resource "random_password" "access_key" {
  for_each = local.users
  length   = 16
  special  = false
}

resource "random_password" "secret_key" {
  for_each = local.users
  length   = 32
  special  = true
}

resource "kubernetes_secret_v1" "minio_user" {
  for_each = local.users

  metadata {
    name      = "minio-user-${each.key}"
    namespace = "minio-system"
  }

  data = {
    CONSOLE_ACCESS_KEY = random_password.access_key[each.key].result
    CONSOLE_SECRET_KEY = random_password.secret_key[each.key].result
  }
}

output "user_loki_access_key" {
  sensitive = true
  value     = random_password.access_key["loki"].result
}

output "user_loki_secret_key" {
  sensitive = true
  value     = random_password.secret_key["loki"].result
}
