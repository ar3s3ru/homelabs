{ pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    ppp # for some manual debugging of pppd
    conntrack-tools # view network connection states
  ];

  # Set up IP forwarding on the kernel.
  boot.kernel.sysctl = {
    # Forward on all interfaces.
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    # Deny martian packets.
    "net.ipv4.conf.all.rp_filter" = 1;

    # By default, do not automatically configure any IPv6 addresses.
    "net.ipv6.conf.all.accept_ra" = 1;
    "net.ipv6.conf.all.autoconf" = 1;
    "net.ipv6.conf.all.use_tempaddr" = 0;

    # On wired WAN, allow IPv6 autoconfiguration and temporary address use.
    "net.ipv6.conf.wan0.accept_ra" = 2;
  };

  # People suggest to use networkd - not sure why.
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;

  networking.useDHCP = false;
  networking.interfaces.lan0.useDHCP = true;
  networking.interfaces.wan0.useDHCP = true;
  networking.interfaces.wlp1s0.useDHCP = true;

  # PPPoE connection on KPN must go through VLAN 6.
  # Source: https://www.kpn.com/zakelijk/service/kpn-een-mkb/internet/eigen-apparatuur-aansluiten
  networking.vlans.veth6.id = 6;
  networking.vlans.veth6.interface = "wan0";

  networking.bridges.br-lan.interfaces = [ "lan0" "wlp1s0" ];
  networking.interfaces.br-lan.ipv4.addresses = [{ address = "192.168.3.1"; prefixLength = 24; }];
  networking.interfaces.br-lan.ipv6.addresses = [{ address = "fd00:3::1"; prefixLength = 64; }];

  systemd.network.networks."30-br-lan" = {
    matchConfig.Name = "br-lan";

    address = [
      "192.168.3.1/24"
      "fd00:3::1/64"
    ];

    networkConfig.ConfigureWithoutCarrier = true; # Allow br-lan to be up without carrier
    networkConfig.IPv6AcceptRA = false; # Disable accepting Router Advertisements
    networkConfig.IPv6SendRA = true; # Enable sending Router Advertisements
    networkConfig.DHCPPrefixDelegation = true;

    ipv6Prefixes = [{
      Prefix = "fd00:3::/64";
    }];

    # Advertise the prefix and set flags for DHCPv6
    ipv6SendRAConfig = {
      Managed = true; # Tell clients to use DHCPv6 for addresses
      EmitDNS = true; # Tell clients to use DNS from DHCPv6
      DNS = "fd00:3::1"; # DNS server address
      RouterLifetimeSec = 1800;
    };
  };

  # Trust all traffic on br-lan.
  # FIXME(ar3s3ru): move to nftables when the time comes.
  networking.firewall.trustedInterfaces = [ "br-lan" ];

  networking.nat.enable = true;
  networking.nat.externalInterface = "veth6";
  networking.nat.internalInterfaces = [ "br-lan" ];
  networking.nat.internalIPs = [ "192.168.3.0/24" ];
  networking.nat.internalIPv6s = [ "fd00:3::/64" ];
}
