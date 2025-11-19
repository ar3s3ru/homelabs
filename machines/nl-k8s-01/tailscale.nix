{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "both";
  # services.tailscale.authKeyFile = ./secrets/tailscale-preauth-key;
  services.tailscale.extraUpFlags = [
    "--ssh"
    "--accept-dns"
    "--accept-risk=all"
    "--advertise-exit-node"
    "--advertise-tags=tag:server,tag:region-nl"
  ];
}
