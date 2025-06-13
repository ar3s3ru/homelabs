resource "helm_release" "rook_ceph_cluster" {
  name            = "rook-ceph-cluster"
  repository      = "https://charts.rook.io/release"
  chart           = "rook-ceph-cluster"
  namespace       = "rook-ceph"
  create_namespace = true
  cleanup_on_fail = true

  # From https://github.com/rook/rook/blob/release-1.14/deploy/charts/rook-ceph-cluster/values.yaml
  values = [yamlencode({
    monitoring = { enabled = true }
    toolbox = { enabled = true }

    cephClusterSpec = {
      # FIXME(ar3s3ru): 2-node cluster, so one of the nodes will have 2 MONs.
      mon = { count = 2 }
      mgr = { count = 1 }

      dashboard = {
        enabled = true
        ssl     = true
      }

      storage = {
        useAllNodes = false
        useAllDevices = false
        nodes = [
          {
            name = "eq14-001"
            devices = [
              {
                name = "/dev/disk/by-id/nvme-Lexar_SSD_NM620_2TB_QBS830R005759P1125"
                config = { osdsPerDevice = "2" }
              }
            ]
          }
        ]
      }
    }

    cephBlockPools = [
      {
        name = "nvme"
        spec = {
          failureDomain = "host"
          replicated = {
            size = 1
          }
          crushRule = {
            name         = "replicated-nvme"
            root         = "default"
            failureDomain = "host"
            deviceClass  = "nvme"
          }
        }
        storageClass = {
          enabled                = true
          name                   = "rook-block-nvme"
          isDefault              = true
          reclaimPolicy          = "Delete"
          allowVolumeExpansion   = true
          volumeBindingMode      = "Immediate"
          parameters = {
            "csi.storage.k8s.io/provisioner-secret-name"         = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/provisioner-secret-namespace"    = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/controller-expand-secret-name"   = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/controller-expand-secret-namespace" = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/node-stage-secret-name"          = "rook-csi-rbd-node"
            "csi.storage.k8s.io/node-stage-secret-namespace"     = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/fstype"                          = "ext4"
          }
        }
      },
      {
        name = "ssd"
        spec = {
          failureDomain = "host"
          replicated = {
            size = 1
          }
          crushRule = {
            name         = "replicated-ssd"
            root         = "default"
            failureDomain = "host"
            deviceClass  = "ssd"
          }
        }
        storageClass = {
          enabled                = true
          name                   = "rook-block-ssd"
          isDefault              = false
          reclaimPolicy          = "Delete"
          allowVolumeExpansion   = true
          volumeBindingMode      = "Immediate"
          parameters = {
            "csi.storage.k8s.io/provisioner-secret-name"         = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/provisioner-secret-namespace"    = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/controller-expand-secret-name"   = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/controller-expand-secret-namespace" = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/node-stage-secret-name"          = "rook-csi-rbd-node"
            "csi.storage.k8s.io/node-stage-secret-namespace"     = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/fstype"                          = "ext4"
          }
        }
      },
      {
        name = "hdd"
        spec = {
          failureDomain = "host"
          replicated = {
            size = 1
          }
          crushRule = {
            name         = "replicated-hdd"
            root         = "default"
            failureDomain = "host"
            deviceClass  = "hdd"
          }
        }
        storageClass = {
          enabled                = true
          name                   = "rook-block-hdd"
          isDefault              = false
          reclaimPolicy          = "Delete"
          allowVolumeExpansion   = true
          volumeBindingMode      = "Immediate"
          parameters = {
            "csi.storage.k8s.io/provisioner-secret-name"         = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/provisioner-secret-namespace"    = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/controller-expand-secret-name"   = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/controller-expand-secret-namespace" = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/node-stage-secret-name"          = "rook-csi-rbd-node"
            "csi.storage.k8s.io/node-stage-secret-namespace"     = "{{ .Release.Namespace }}"
            "csi.storage.k8s.io/fstype"                          = "ext4"
          }
        }
      }
    ]

    # FIXME(ar3s3ru): unused for now
    cephFileSystems  = []
    cephObjectStores = []
  })]
}
