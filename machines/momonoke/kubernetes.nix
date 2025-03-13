{ pkgs, lib, config, ... }:
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
    runc
    lsof # To inspect the number of open files.
  ];

  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  # This is necessary to authenticate with the private Container Registry where
  # the application images are uploaded.
  environment.etc."rancher/k3s/registries.yaml" = {
    source = ./secrets/k3s-config-registries.yaml;
  };

  environment.etc."rancher/k3s/config.yaml".text = ''
    ---
    # Source: https://devops.stackexchange.com/questions/16069/k3s-eviction-manager-attempting-to-reclaim-resourcename-ephemeral-storage
    kubelet-arg:
      - "eviction-minimum-reclaim=imagefs.available=2%,nodefs.available=2%"
      - "eviction-hard=memory.available<500Mi,nodefs.available<1Gi"
  '';

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
    role = "server";
    token = clusterToken;
    clusterInit = true;
  };

  # Disable limits for the number of open files by k3s containers,
  # or the telemetry stack will complain.
  systemd.services.k3s.serviceConfig.LimitNOFILE = lib.mkIf config.services.k3s.enable (lib.mkForce "infinity");
  systemd.services.k3s.serviceConfig.LimitNOFILESoft = lib.mkIf config.services.k3s.enable (lib.mkForce "infinity");
}
