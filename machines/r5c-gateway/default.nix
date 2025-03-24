{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "192.168.2.50";
  deployment.targetUser = "root";
  deployment.tags = [ "type-gateway" "region-nl" ];

  nixpkgs.system = "aarch64-linux";

  networking.hostName = "r5c-gateway";
  networking.domain = "ar3s3ru.dev";

  time.timeZone = "Europe/Amsterdam";

  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
    ./ethernet.nix
    ./network.nix
    ./pppoe.nix
  ];
}
