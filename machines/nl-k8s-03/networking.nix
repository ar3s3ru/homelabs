{
  # Do not use DHCP on any interface - this node only gets static addresses.
  networking.useDHCP = false;

  # Static IP configuration to prevent ARP conflicts
  # Using /16 netmask with static routes for other subnets
  networking.interfaces.ens18.ipv4.addresses = [{
    address = "10.10.0.5";
    prefixLength = 16;
  }];

  # Static routes to access other subnets without requiring /8 prefix
  networking.interfaces.ens18.ipv4.routes = [
    { address = "10.0.0.0"; prefixLength = 16; via = "10.0.0.1"; }
    { address = "10.11.0.0"; prefixLength = 16; via = "10.0.0.1"; }
    { address = "10.20.0.0"; prefixLength = 16; via = "10.0.0.1"; }
  ];

  networking.interfaces.ens18.ipv6.addresses = [{
    address = "fd00:cafe:10::5";
    prefixLength = 64;
  }];

  networking.nameservers = [ "10.0.0.1" ];
  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "ens18";
  };
}
