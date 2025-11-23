{
  sops.secrets."argocd-homelab-repo" = {
    key = "";
    format = "yaml";
    sopsFile = ./secrets/10-argocd-homelab-repo.yaml;
    path = "/var/lib/rancher/k3s/server/manifests/10-argocd-homelab-repo.yaml";
  };

  services.k3s.autoDeployCharts.argocd = {
    name = "argo-cd";
    repo = "https://argoproj.github.io/argo-helm";
    version = "9.1.3";
    hash = "sha256-OG74wEZuXyqT5S98lhj/E+t+KScJZycVWeLORPs8J7I=";
    targetNamespace = "argo-system";
    createNamespace = true;
    values = {
      redis-ha = {
        enabled = true;
      };
      controller = {
        replicas = 1;
      };
      server = rec {
        autoscaling = {
          enabled = true;
          minReplicas = 2;
        };
        ingress = {
          enabled = true;
          ingressClassName = "tailscale";
          hostname = "nl-argocd";
          tls = true;
        };
        ingressGrpc = ingress // {
          hostname = "nl-argocd-grpc";
        };
      };
      repoServer = {
        autoscaling = {
          enabled = true;
          minReplicas = 2;
        };
      };
      applicationSet = {
        replicas = 2;
      };
      configs = {
        cm = {
          # Kustomize build options
          # --enable-helm: Enabling Helm chart rendering with Kustomize
          # --load-restrictor LoadRestrictionsNone: Local kustomizations may load files from outside their root
          "kustomize.buildOptions" = "--enable-helm --load-restrictor LoadRestrictionsNone";
          # Exclude certain resources from ArgoCD management
          # https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#resource-exclusioninclusion
          # Ignore VolumeSnapshot and VolumeSnapshotContent: Created by backup processes.
          "resource.exclusions" = ''
            - apiGroups:
                - snapshot.storage.k8s.io
              kinds:
                - VolumeSnapshot
                - VolumeSnapshotContent
              clusters:
                - "*"
            - apiGroups:
                - cilium.io
              kinds:
                - CiliumIdentity
              clusters:
                - "*"
          '';
        };
      };
    };
  };
}
