{ ... }:
let
  routerIpV4 = "192.168.2.1";
  routerIpV6 = "fd00:2::1";
in
{
  networking.interfaces.lan0.ipv4.addresses = [{ address = routerIpV4; prefixLength = 24; }];
  networking.interfaces.lan0.ipv6.addresses = [{ address = routerIpV6; prefixLength = 64; }];
}
