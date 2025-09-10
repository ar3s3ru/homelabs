resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "authelia_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret_v1" "authelia_postgresql_passwords" {
  metadata {
    name      = "authelia-postgresql-passwords"
    namespace = local.namespace
  }

  data = {
    "postgres-password" = random_password.postgres_password.result
    "password"          = random_password.authelia_password.result
  }
}

resource "helm_release" "postgresql" {
  name            = "authelia-postgresql"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "postgresql"
  version         = "16.7.27"
  namespace       = local.namespace
  cleanup_on_fail = true
  values          = [file("${path.module}/values-postgresql.yaml")]

  depends_on = [
    kubernetes_secret_v1.authelia_postgresql_passwords
  ]
}
