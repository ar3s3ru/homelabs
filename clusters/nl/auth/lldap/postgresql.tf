resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret_v1" "lldap_cnpg_postgres" {
  metadata {
    name      = "lldap-cnpg-postgres"
    namespace = local.namespace
  }

  data = {
    username = "postgres"
    password = random_password.postgres_password.result
  }
}

resource "kubernetes_manifest" "cnpg_cluster" {
  manifest = yamldecode(file("${path.module}/values-cnpg.yaml"))

  depends_on = [
    kubernetes_secret_v1.lldap_cnpg_postgres
  ]
}
