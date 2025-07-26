locals {
  namespace = "productivity"
}

resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "user_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "debezium_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret_v1" "affine_postgresql_passwords" {
  metadata {
    name      = "affine-postgresql-passwords"
    namespace = local.namespace
  }

  data = {
    "postgres-password"    = random_password.postgres_password.result
    "password"             = random_password.user_password.result
    "replication-password" = random_password.debezium_password.result
  }
}

resource "kubernetes_persistent_volume_claim_v1" "affine_postgresql" {
  metadata {
    name      = "affine-postgresql"
    namespace = local.namespace
  }

  spec {
    storage_class_name = "longhorn-nvme-3-replicas"
    access_modes       = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "helm_release" "affine" {
  name            = "affine"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = local.namespace
  version         = "4.1.1"
  cleanup_on_fail = true
  values          = [file("./values-affine.yaml")]

  set_sensitive {
    name  = "controllers.main.containers.main.env.DATABASE_URL"
    value = "postgresql://postgres:${random_password.postgres_password.result}@affine-postgresql.productivity.svc.cluster.local:5432/main"
  }

  depends_on = [
    helm_release.postgresql,
    helm_release.redis
  ]
}

resource "helm_release" "redis" {
  name            = "affine-redis"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "redis"
  version         = "21.2.13"
  namespace       = local.namespace
  cleanup_on_fail = true
  values          = [file("./values-redis.yaml")]
}

resource "helm_release" "postgresql" {
  name            = "affine-postgresql"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "postgresql"
  version         = "16.7.21"
  namespace       = local.namespace
  cleanup_on_fail = true
  values          = [file("./values-postgres.yaml")]

  depends_on = [
    kubernetes_secret_v1.affine_postgresql_passwords,
    kubernetes_persistent_volume_claim_v1.affine_postgresql
  ]
}
