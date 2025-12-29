{ config, ... }:

{
  imports = [
    ./k3s.nix
  ];

  # Kubernetes through K3S.
  services.k3s.role = "agent";
  services.k3s.tokenFile = config.sops.secrets."clusters/nl/token".path;
  services.k3s.serverAddr = "https://nl-k8s-01.home.arpa:6443";
}
