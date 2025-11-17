{
  # Do not use DHCP on any interface - this node only gets static addresses.
  networking.useDHCP = false;

  # Static IP configuration to prevent ARP conflicts
  # Using /16 netmask so only 10.10.0.0/16 is considered local
  networking.interfaces.enp0s31f6.ipv4.addresses = [{
    address = "10.10.0.3";
    prefixLength = 16;
  }];

  networking.interfaces.enp0s31f6.ipv6.addresses = [{
    address = "fd00:cafe:10::3";
    prefixLength = 64;
  }];

  networking.nameservers = [ "10.0.0.1" ];
  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "enp0s31f6";
  };
}
