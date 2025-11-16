{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "both";
  # services.tailscale.authKeyFile = ./secrets/tailscale-preauth-key;
  services.tailscale.extraUpFlags = [
    "--ssh"
    "--accept-dns"
    "--accept-risk=all"
    "--advertise-routes=192.168.2.0/24"
    "--advertise-exit-node"
    "--advertise-tags=tag:server,tag:region-nl"
  ];
}
