{ config, ... }:

{
  services.k3s.autoDeployCharts.argocd = {
    enable = false;
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
    };
  };
}
