{ config, ... }:

{
  imports = [
    ./k3s.nix
  ];

  # Kubernetes through K3S.
  services.k3s.role = "agent";
  services.k3s.tokenFile = config.sops.secrets."clusters/nl/token".path;
  services.k3s.serverAddr = "https://192.168.2.38:6443";
}
