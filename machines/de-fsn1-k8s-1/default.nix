{ nixos-hardware, ... }:

{ lib, ... }:

{
  deployment.targetHost = lib.mkDefault "in.de-fsn1.cianfr.one";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-de" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "de-fsn1-k8s-1";
  time.timeZone = "Europe/Berlin";

  services.k3s.extraFlags = lib.mkAfter [
    "--node-ip=178.105.247.117,2a01:4f8:c015:3d43::1"
    "--tls-san=de-fsn1-k8s-1.tail2ff90.ts.net"
  ];

  # Override cilium k8sServiceHost (hardcoded to 10.0.1.1 in modules/k3s/cilium.nix).
  services.k3s.autoDeployCharts.cilium.values.k8sServiceHost = lib.mkForce "178.105.247.117";

  # Override tailscale operator hostname (hardcoded to "nl-k8s" in modules/k3s/tailscale.nix).
  services.k3s.autoDeployCharts.tailscale-operator.values.operatorConfig.hostname = lib.mkForce "de-fsn1-k8s";

  # Override manifests: drop the default kube/ ApplicationSet, include the kube-hetzner one.
  services.k3s.manifests = lib.mkForce {
    "00-namespace-networking" = {
      enable = true;
      source = ../../modules/k3s/manifests/00-namespace-networking.yaml;
    };
    "00-cluster-admin-serviceaccount" = {
      enable = true;
      source = ../../modules/k3s/manifests/00-cluster-admin-serviceaccount.yaml;
    };
    "01-clusterrolebinding-cluster-admin" = {
      enable = true;
      source = ../../modules/k3s/manifests/01-clusterrolebinding-cluster-admin.yaml;
    };
    "11-argocd-homelab-kube-application-set" = {
      enable = true;
      source = ./argocd-homelab-kube-application-set.yaml;
    };
  };

  imports = [
    ../../modules/server.nix
    ../../modules/k3s/server-main.nix
    ./disko.nix
    ./networking.nix
    ./tailscale.nix
  ];
}
