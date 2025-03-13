{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "both";
  services.tailscale.authKeyFile = ./secrets/tailscale-preauth-key;
  services.tailscale.extraUpFlags = [
    "--ssh"
    "--accept-dns"
    "--accept-risk=all"
    "--advertise-exit-node"
    "--advertise-routes=192.168.178.0/24" # To access the local router.
    "--hostname=dejima.ar3s3ru.dev"
  ];
}
