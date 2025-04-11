variable "volume_name" {
  type        = string
  description = "Name of the volume, used for both PersistentVolume and PersistentVolumeClaim"
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace to use for the PersistentVolumeClaim"
}

variable "host_path" {
  type        = string
  description = "Path on the host to use for the PersistentVolume"
}

variable "kubernetes_node" {
  type        = string
  description = "Kubernetes node to use for the PersistentVolume mount"
}

resource "kubernetes_persistent_volume_v1" "pv" {
  metadata {
    name = var.volume_name
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "10G"
    }

    persistent_volume_source {
      host_path {
        path = var.host_path
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = [var.kubernetes_node]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "pvc" {
  metadata {
    name      = var.volume_name
    namespace = var.kubernetes_namespace
  }

  spec {
    storage_class_name = "local-path"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.pv.metadata[0].name

    resources {
      requests = {
        storage = "10G"
      }
    }
  }
}
