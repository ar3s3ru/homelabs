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
  version         = "3.7.3"
  cleanup_on_fail = true

  values = [yamlencode({
    defaultPodOptions = {
      securityContext = {
        runAsNonRoot        = true
        runAsUser           = 1000
        runAsGroup          = 1000
        fsGroup             = 1000
        fsGroupChangePolicy = "OnRootMismatch"
      }
    }

    controllers = {
      main = {
        type     = "deployment"
        strategy = "RollingUpdate"
        replicas = 1

        annotations = {
          "reloader.stakater.com/auto" = "true"
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/lldap/lldap"
              tag        = "latest-alpine-rootless"
            }
            env = {
              TZ                 = "Europe/Amsterdam"
              VERBOSE            = "true"
              LLDAP_LDAP_BASE_DN = "dc=ar3s3ru,dc=dev"
            }
            envFrom = [
              { secretRef = { name = kubernetes_secret_v1.lldap_secrets.metadata[0].name } }
            ]
            probes = {
              # FIXME(ar3s3ru): find a way to enable these?
              liveness  = { enabled = false }
              readiness = { enabled = false }
              startup   = { enabled = true }
            }
          }
        }
      }
      bootstrap = {
        type = "job"

        annotations = {
          "reloader.stakater.com/auto" = "true"
          "helm.sh/hook-delete-policy" = "before-hook-creation"
        }

        containers = {
          main = {
            image = {
              repository = "ghcr.io/lldap/lldap"
              tag        = "latest-alpine-rootless"
            }

            command = ["./bootstrap.sh"]

            env = {
              LLDAP_URL  = "http://lldap.auth.svc.cluster.local:17170"
              DO_CLEANUP = "true"
              LLDAP_ADMIN_USERNAME = {
                valueFrom = {
                  secretKeyRef = {
                    name = kubernetes_secret_v1.lldap_secrets.metadata[0].name,
                    key  = "LLDAP_LDAP_USER_DN"
                  }
                }
              }
              LLDAP_ADMIN_PASSWORD = {
                valueFrom = {
                  secretKeyRef = {
                    name = kubernetes_secret_v1.lldap_secrets.metadata[0].name,
                    key  = "LLDAP_LDAP_USER_PASS"
                  }
                }
              }
            }
          }
        }
      }
    }

    service = {
      main = {
        controller = "main"
        type       = "ClusterIP"
        ports = {
          ldap = { port = 3890 }
          web  = { port = 17170 }
        }
      }
    }

    ingress = {
      tailscale = {
        enabled   = true
        className = "tailscale"

        hosts = [{
          host = "ldap",
          paths = [{
            path     = "/",
            pathType = "Prefix",
            service = {
              identifier = "main",
              port       = "web"
            }
          }]
        }]

        tls = [{ hosts = ["ldap"] }]
      }
    }

    persistence = {
      groups = {
        type = "secret"
        name = kubernetes_secret_v1.lldap_groups.metadata[0].name
        advancedMounts = {
          bootstrap = {
            main = [{ path = "/bootstrap/group-configs", readOnly = true }]
          }
        }
      }
      users = {
        type = "secret"
        name = kubernetes_secret_v1.lldap_users.metadata[0].name
        advancedMounts = {
          bootstrap = {
            main = [{ path = "/bootstrap/user-configs", readOnly = true }]
          }
        }
      }
    }
  })]
}
