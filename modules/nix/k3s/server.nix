{ pkgs, lib, config, ... }:

{
  # For Rook/Ceph support.
  boot.kernelModules = [ "rbd" ];

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
    6881 # qbittorrent
    8056 # govee2mqtt
    8095 # music-assistant webserver
    8097 # music-assistant streams
    8123 # home-assistant hostNetwork
    10250 # metrics-server
  ];

  networking.firewall.allowedUDPPorts = [
    8472 # k3s flannel
  ];

  # Kubernetes through K3S.
  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.clusterInit = true;

  services.k3s.manifests =
    let
      dir = ./manifests;
      files = builtins.attrNames (builtins.readDir dir);
    in
    builtins.listToAttrs (map
      (filename: {
        name = builtins.replaceStrings [ ".yaml" ] [ "" ] filename; # Strips the suffix.
        value = { enable = true; source = ./. + "/manifests/${filename}"; };
      })
      files);

  sops.secrets."tailscale/oauth-client-id".sopsFile = ./secrets.yaml;
  sops.secrets."tailscale/oauth-client-secret".sopsFile = ./secrets.yaml;

  sops.templates.tailscale-operator-oauth = {
    path = "/var/lib/rancher/k3s/server/manifests/01-tailscale-operator-oauth.json";
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = "operator-oauth";
        namespace = "networking";
      };
      stringData = {
        "client_id" = config.sops.placeholder."tailscale/oauth-client-id";
        "client_secret" = config.sops.placeholder."tailscale/oauth-client-secret";
      };
    };
  };

  services.k3s.autoDeployCharts.tailscale-operator = {
    # NOTE: switched to the "unstable" Helm chart to fix https://github.com/tailscale/tailscale/issues/15081
    name = "tailscale-operator";
    repo = "https://pkgs.tailscale.com/unstable/helmcharts";
    version = "1.85.21";
    hash = "sha256-oPAV1s2Yn+oeT6xzYQEDhhf0dy/kMacmbvewQiWsMSw=";
    targetNamespace = "networking";
    values = {
      operatorConfig.hostname = "nl-k8s";
      apiServerProxyConfig.mode = "true";
    };
  };

  # Disable limits for the number of open files by k3s containers,
  # or the telemetry stack will complain.
  systemd.services.k3s.serviceConfig.LimitNOFILE = lib.mkIf config.services.k3s.enable (lib.mkForce "infinity");
  systemd.services.k3s.serviceConfig.LimitNOFILESoft = lib.mkIf config.services.k3s.enable (lib.mkForce "infinity");
}
