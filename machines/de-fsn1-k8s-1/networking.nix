{
  networking.useDHCP = false;

  networking.interfaces.eth0.ipv4.addresses = [{
    address = "178.105.247.117";
    prefixLength = 32;
  }];

  networking.interfaces.eth0.ipv6.addresses = [{
    address = "2a01:4f8:c015:3d43::1";
    prefixLength = 64;
  }];

  networking.defaultGateway = {
    address = "172.31.1.1";
    interface = "eth0";
  };

  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "eth0";
  };

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
}
