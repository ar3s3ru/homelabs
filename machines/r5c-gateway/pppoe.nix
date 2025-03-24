{
  sops.secrets."pppoe/kpn-secrets" = {
    sopsFile = ./secrets.yaml;
    path = "/etc/pppd/chap-secrets";
  };

  services.pppd.enable = true;
  services.pppd.peers."kpn".autostart = true;
  services.pppd.peers."kpn".enable = true;
  services.pppd.peers."kpn".config = ''
    plugin rp-pppoe.so

    # The name of the WAN interface.
    wan0

    # Source: https://juniorfox.net/article/diy-linux-router-part-2-network-and-internet#4-pppoe-connection
    noipdefault
    defaultroute

    lcp-echo-interval 5
    lcp-echo-failure 3

    noauth
    persist
    noaccomp

    default-asyncmap
  '';
}
