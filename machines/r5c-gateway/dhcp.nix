{ lib, config, ... }:
let
  mkLeaseDatabase = name: {
    type = "memfile";
    name = "/var/lib/kea/${name}";
    persist = true;
  };

  mkLogger = name: {
    name = "kea-${name}";
    severity = "WARN";
    output_options = [{ output = "stderr"; }];
    debuglevel = 0;
  };

  # Source: https://github.com/reckenrode/nixos-configs/blob/907ecf4d0f05211d0da171f88ffd175c8ff4f2fb/hosts/zhloe/kea.nix#L119
  # TODO(ar3s3ru): review these values.
  defaultLeasesProcessing = {
    reclaim-timer-wait-time = 10;
    flush-reclaimed-timer-wait-time = 25;
    hold-reclaimed-time = 3600;
    max-reclaim-leases = 100;
    max-reclaim-time = 250;
    unwarned-reclaim-cycles = 5;
  };

  staticLeasesByHost = import ./static-leases.nix;
  allLeases = lib.flatten (lib.mapAttrsToList (name: value: value) staticLeasesByHost);
in
{
  # NOTE: the approach used here is to reserve the lower part of the subnet
  # for static IPs and MetalLB addresses, and the upper part for dynamic.

  services.kea.dhcp4.enable = true;
  services.kea.dhcp4.settings = {
    interfaces-config.interfaces = [ "br-lan" ];

    loggers = [ (mkLogger "kea-dhcp4") ];
    lease-database = mkLeaseDatabase "dhcp4.leases";
    expired-leases-processing = defaultLeasesProcessing;

    renew-timer = 3600;
    rebind-timer = 7200;
    valid-lifetime = 14400;

    subnet4 = [
      {
        id = 1;
        subnet = "192.168.3.0/24";
        # Structure of the IPv4 subnet:
        # - 192.168.3.2 - 192.168.3.49 -> reserved for static IPs
        # - 192.168.3.50 - 192.168.3.128 -> MetalLB addresses on the local cluster
        # - 192.168.3.129 - 192.168.3.254 -> dynamic IPs for clients
        pools = [
          { pool = "192.168.3.129 - 192.168.3.254"; }
        ];
        reservations = map
          (lease: {
            hw-address = lease.mac;
            ip-address = lease.ip4;
          })
          allLeases;
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
  };

  services.kea.dhcp6.enable = true;
  services.kea.dhcp6.settings = {
    interfaces-config.interfaces = [ "br-lan" ];

    loggers = [ (mkLogger "kea-dhcp6") ];
    lease-database = mkLeaseDatabase "dhcp6.leases";
    expired-leases-processing = defaultLeasesProcessing;

    # TODO(ar3s3ru): review these values.
    renew-timer = 3600;
    rebind-timer = 7200;
    preferred-lifetime = 604800;
    valid-lifetime = 2592000;

    subnet6 = [
      {
        id = 1;
        subnet = "fd00:3::/64";
        # Structure of the IPv6 ULA subnet:
        # - fd00:3::2 - fd00:3::1000 -> reserved for static IPs
        # - fd00:3::2000 - fd00:3::3000 -> MetalLB addresses on the local cluster
        # - fd00:3::4000 - fd00:3::ffff -> dynamic IPs for clients
        pools = [
          { pool = "fd00:3::4000 - fd00:3::ffff"; }
        ];
        reservations = map
          (lease: {
            hw-address = lease.mac;
            ip-addresses = lease.ip6;
          })
          allLeases;
        option-data = [
          {
            name = "dns-servers";
            data = "fd00:3::1";
          }
          {
            name = "domain-search";
            data = config.networking.domain;
          }
        ];
      }
    ];
  };
}
