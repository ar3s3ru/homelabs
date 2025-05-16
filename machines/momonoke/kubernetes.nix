{ pkgs, lib, config, ... }:

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
  sops.secrets."k3s-config-registries" = {
    sopsFile = ./secrets.yaml;
    path = "/etc/rancher/k3s/registries.yaml";
  };

  networking.firewall.allowedTCPPorts = [
    2379
    2380 # k3s etcd cluster coordination
    6443 # k8s apiserver
    8056 # govee2mqtt
    8095 # music-assistant webserver
    8097 # music-assistant streams
    8123 # home-assistant hostNetwork
    10250 # metrics-server
  ];

  networking.firewall.allowedUDPPorts = [
    8472 # k3s flannel
  ];

  sops.secrets."clusters/nl/token" = { };

  # Kubernetes through K3S.
  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.clusterInit = true;

  # Disable limits for the number of open files by k3s containers,
  # or the telemetry stack will complain.
  systemd.services.k3s.serviceConfig.LimitNOFILE = lib.mkIf config.services.k3s.enable (lib.mkForce "infinity");
  systemd.services.k3s.serviceConfig.LimitNOFILESoft = lib.mkIf config.services.k3s.enable (lib.mkForce "infinity");
}
