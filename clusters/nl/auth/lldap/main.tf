locals {
  namespace = "auth"
}

variable "secrets" {
  type        = map(string)
  description = "Environment variables to mount on the pod as secrets"
  sensitive   = true
}

resource "kubernetes_secret_v1" "lldap_secrets" {
  metadata {
    name      = "lldap-secrets"
    namespace = local.namespace
  }

  data = var.secrets
}

variable "groups" {
  type        = list(object({ name = string }))
  description = "List of groups to create in LDAP"
  sensitive   = true
}

resource "kubernetes_secret_v1" "lldap_groups" {
  metadata {
    name      = "lldap-groups"
    namespace = local.namespace
  }

  data = { for group in var.groups : "${group.name}.json" => jsonencode(group) }
}

variable "users" {
  type = list(object({
    id          = string
    email       = string
    displayName = optional(string)
    firstName   = optional(string)
    lastName    = optional(string)
    password    = optional(string)
    groups      = optional(list(string), [])
  }))

  description = "List of users to create in LDAP"
  sensitive   = true
}

resource "kubernetes_secret_v1" "lldap_users" {
  metadata {
    name      = "lldap-users"
    namespace = local.namespace
  }

  data = { for i, user in var.users : "user-${i}.json" => jsonencode(user) }
}

resource "helm_release" "lldap" {
  name            = "lldap"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = local.namespace
  version         = "4.1.2"
  cleanup_on_fail = true
  values          = [file("${path.module}/values-lldap.yaml")]

  depends_on = [
    helm_release.postgresql
  ]
}
