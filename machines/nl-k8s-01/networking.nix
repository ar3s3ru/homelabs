{
  # Do not use DHCP on any interface - this node only gets static addresses.
  networking.useDHCP = true;

  # # Static IP configuration to prevent ARP conflicts
  # # Using /16 netmask with static routes for other subnets
  # networking.interfaces.enp0s20f0u1.ipv4.addresses = [{
  #   address = "10.0.1.1";
  #   prefixLength = 16;
  # }];

  # networking.interfaces.enp0s20f0u1.ipv6.addresses = [{
  #   address = "fd00:cafe::1:1";
  #   prefixLength = 64;
  # }];

  # networking.nameservers = [ "10.0.0.1" ];
  # networking.defaultGateway = {
  #   address = "10.0.0.1";
  #   interface = "enp0s20f0u1";
  # };
}
