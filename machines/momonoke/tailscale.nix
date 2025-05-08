{ config, ... }:

{
  sops.secrets."tailscale/preauthKey".sopsFile = ./secrets.yaml;

  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "both";
  services.tailscale.authKeyFile = config.sops.secrets."tailscale/preauthKey".path;
  services.tailscale.extraUpFlags = [
    "--ssh"
    "--accept-dns"
    "--accept-risk=all"
    "--advertise-exit-node"
    "--advertise-routes=192.168.2.0/24"
    "--advertise-tags=tag:server"
    "--hostname=momonoke.ar3s3ru.dev"
  ];
}
