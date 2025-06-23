{ config, ... }:

{
  services.kea.dhcp4.enable = true;
  services.kea.dhcp4.settings = {
    interfaces-config.interfaces = [ "br-lan" ];

    lease-database.name = "/var/lib/kea/dhcp4.leases";
    lease-database.persist = true;
    lease-database.type = "memfile";

    subnet4 = [
      {
        id = 100;
        subnet = "192.168.3.0/24";
        pools = [
          { pool = "192.168.3.2 - 192.168.3.199"; }
        ];
        option-data = [
          {
            name = "routers";
            data = "192.168.3.1";
          }
          {
            name = "domain-name-servers";
            data = "192.168.3.1";
          }
          {
            name = "domain-name";
            data = config.networking.domain;
          }
        ];
      }
    ];

    renew-timer = 3600;
    rebind-timer = 7200;
    valid-lifetime = 14400;
  };
}
