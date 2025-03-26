resource "kubernetes_namespace" "immich" {
  metadata {
    name = "immich"
  }
}

resource "kubernetes_persistent_volume" "immich" {
  metadata {
    name = "immich-pv"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]

    capacity = {
      storage = "1Ti"
    }

    claim_ref {
      name      = "immich-pvc"
      namespace = kubernetes_namespace.immich.metadata[0].name
    }

    persistent_volume_source {
      host_path {
        path = "/files/immich"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "immich" {
  metadata {
    name      = kubernetes_persistent_volume.immich.spec[0].claim_ref[0].name
    namespace = kubernetes_persistent_volume.immich.spec[0].claim_ref[0].namespace
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Ti"
      }
    }
  }
}

resource "helm_release" "immich" {
  name       = "immich"
  repository = "https://immich-app.github.io/immich-charts"
  chart      = "immich"
  version    = "0.9.2"
  namespace  = kubernetes_namespace.immich.metadata[0].name
  values = [
    file("values.yaml")
  ]
  depends_on = [kubernetes_persistent_volume_claim.immich]
}
