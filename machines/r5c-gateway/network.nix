{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ppp # for some manual debugging of pppd
    conntrack-tools # view network connection states
  ];

  # Set up IP forwarding on the kernel.
  boot.kernel.sysctl = {
    # Forward on all interfaces.
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;

    # By default, do not automatically configure any IPv6 addresses.
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.all.use_tempaddr" = 0;

    # On wired WAN, allow IPv6 autoconfiguration and tempory address use.
    "net.ipv6.conf.wan0.accept_ra" = 2;
    "net.ipv6.conf.wan0.autoconf" = 1;
  };

  networking.useDHCP = false;
  networking.lan0.useDHCP = false;
  networking.wan0.useDHCP = false;

  # PPPoE connection on KPN must go through VLAN 6.
  # Source: https://www.kpn.com/zakelijk/service/kpn-een-mkb/internet/eigen-apparatuur-aansluiten
  networking.vlans.wan.id = 6;
  networking.vlans.wan.interface = "wan0";

  networking.vlans.lan.id = 20;
  networking.vlans.lan.interface = "lan0";
}
