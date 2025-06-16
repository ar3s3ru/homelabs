{ pkgs, ... }:

{
  imports = [
    ./fix-open-file-limit.nix
    ./storage-csi.nix
  ];

  # Add the necessary packages for the Kubernetes experience.
  environment.systemPackages = with pkgs; [
    k3s
    k9s # To have a better experience
    openssl # Used to generate user account CSRs.
    kubectl
    kubernetes-helm
    runc
    lsof # To inspect the number of open files.
    sqlite
  ];

  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  networking.firewall.allowedTCPPorts = [
    2379
    2380 # k3s etcd cluster coordination
    6443 # k8s apiserver
    7946
    8056 # govee2mqtt
    8095 # music-assistant webserver
    8097 # music-assistant streams
    8123 # home-assistant hostNetwork
    9100 # metallb
    10250 # metrics-server
    30963 # qbittorrent
  ];

  networking.firewall.allowedUDPPorts = [
    8472 # k3s flannel
  ];

  # Kubernetes through K3S.
  services.k3s.enable = true;
  services.k3s.role = "server";
}
