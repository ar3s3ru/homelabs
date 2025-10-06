resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "immich_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret_v1" "immich_postgresql_passwords" {
  for_each = {
    postgres = random_password.postgres_password.result
    immich   = random_password.immich_password.result
  }

  metadata {
    name      = "immich-postgresql-${each.key}"
    namespace = local.namespace
  }

  data = {
    username = each.key
    password = each.value
  }
}

resource "helm_release" "postgresql" {
  name            = "immich-postgresql"
  repository      = "https://cloudnative-pg.github.io/charts"
  chart           = "cluster"
  namespace       = local.namespace
  cleanup_on_fail = true
  values          = [file("${path.module}/values-postgresql.yaml")]

  depends_on = [
    kubernetes_secret_v1.immich_postgresql_passwords
  ]
}
