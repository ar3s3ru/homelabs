variable "secrets" {
  type        = map(string)
  description = "Environment variables to mount on the pod as secrets"
  sensitive   = true
}

resource "kubernetes_secret_v1" "lldap_secrets" {
  metadata {
    name      = "lldap-secrets"
    namespace = "auth"
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
    namespace = "auth"
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
    namespace = "auth"
  }

  data = { for i, user in var.users : "user-${i}.json" => jsonencode(user) }
}

resource "helm_release" "lldap" {
  name            = "lldap"
  repository      = "https://bjw-s-labs.github.io/helm-charts"
  chart           = "app-template"
  namespace       = "auth"
  version         = "4.1.1"
  cleanup_on_fail = true
  values          = [file("./values.yaml")]
}
