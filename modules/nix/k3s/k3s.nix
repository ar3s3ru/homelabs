{ pkgs, ... }:

{
  imports = [
    ./storage-csi.nix
  ];

  services.k3s.enable = true;
  services.k3s.extraFlags = [
    "--disable=traefik" # Using ingress-nginx instead.
    # FIXME: should be re-disabled when moving to Cilium.
    # "--disable servicelb" # Using metallb instead.
  ];

  sops.secrets."clusters/nl/token" = { };

  # Add the necessary packages for the Kubernetes experience.
  environment.systemPackages = with pkgs; [
    k3s
    k9s # To have a better experience
    openssl # Used to generate user account CSRs.
    kubectl
    kubernetes-helm
    docker
    runc
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
    8095 # music-assistant hostNetwork
    8097 # chromecast
    8123 # home-assistant hostNetwork
    8443 # ingress-nginx admission controller
    9100 # metallb
    10250 # metrics-server
    30963 # qbittorrent
  ];

  networking.firewall.allowedUDPPorts = [
    8472 # k3s flannel
  ];

  # Increase inotify limits for applications that watch many files.
  # Max impact on memory: ~512MB
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 512;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_queued_events" = 32768;
  };
}
