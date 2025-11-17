{
  # Do not use DHCP on any interface - this node only gets static addresses.
  networking.useDHCP = false;

  # Static IP configuration to prevent ARP conflicts
  # Using /16 netmask so only 10.10.0.0/16 is considered local
  networking.interfaces.enp0s20f0u1.ipv4.addresses = [{
    address = "10.10.0.2";
    prefixLength = 16;
  }];

  networking.interfaces.enp0s20f0u1.ipv6.addresses = [{
    address = "fd00:cafe:10::2";
    prefixLength = 64;
  }];

  networking.nameservers = [ "10.0.0.1" ];
  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "enp0s20f0u1";
  };
}
