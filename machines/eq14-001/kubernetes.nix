{ pkgs, lib, ... }:
let
  clusterToken = lib.readFile ../secrets/nl-homelab-k3s-token;
in
{
  # Add the necessary packages for the Kubernetes experience.
  environment.systemPackages = with pkgs; [
    k3s
    k9s # To have a better experience
    openssl # Used to generate user account CSRs.
    kubectl
    kubernetes-helm
    docker
    runc
    lsof # To inspect the number of open files.
  ];

  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  networking.firewall.allowedTCPPorts = [
    2379
    2380 # k3s etcd cluster coordination
    6443 # k8s apiserver
    8123 # home-assistant hostNetwork
  ];

  networking.firewall.allowedUDPPorts = [
    8472 # k3s flannel
  ];

  # Kubernetes through K3S.
  services.k3s = {
    enable = true;
    role = "agent";
    token = clusterToken;
    serverAddr = "https://192.168.2.109:6443";
  };
}
