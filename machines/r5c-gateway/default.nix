{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "192.168.2.46";
  deployment.targetUser = "nix";
  deployment.tags = [ "type-gateway" "region-nl" ];
  deployment.buildOnTarget = true;

  nixpkgs.system = "aarch64-linux";

  networking.hostName = "r5c-gateway";
  networking.domain = "ar3s3ru.dev";

  time.timeZone = "Europe/Amsterdam";

  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
  ];
}
