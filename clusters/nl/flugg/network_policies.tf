resource "kubernetes_network_policy_v1" "flugg_infra_network_policy" {
  metadata {
    name      = "flugg-infra-network-policy"
    namespace = kubernetes_namespace.flugg_infra.metadata[0].name
    labels    = local.default_labels
  }

  spec {
    # It should technically apply to all pods in the namespace.
    pod_selector {}

    ingress {
      from {
        namespace_selector {
          match_labels = local.default_labels
        }
      }
    }

    ingress {
      # Used for scraping telemetry data in Prometheus and OTLP.
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "telemetry"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = local.default_labels
        }
      }
    }

    egress {
      # Used for scraping telemetry data in Prometheus and OTLP.
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "telemetry"
          }
        }
      }
    }

    # Allows DNS resolution through coredns.
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "flugg_system_network_policy" {
  metadata {
    name      = "flugg-system-network-policy"
    namespace = kubernetes_namespace.flugg_system.metadata[0].name
    labels    = local.default_labels
  }

  spec {
    # It should technically apply to all pods in the namespace.
    pod_selector {}

    ingress {
      from {
        namespace_selector {
          match_labels = local.default_labels
        }
      }
    }

    ingress {
      # Used for scraping telemetry data in Prometheus and OTLP.
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "telemetry"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = local.default_labels
        }
      }
    }

    egress {
      # Used for scraping telemetry data in Prometheus and OTLP.
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "telemetry"
          }
        }
      }
    }

    # Allows DNS resolution through coredns.
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}
