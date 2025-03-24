{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "192.168.2.51";
  deployment.targetUser = "root";
  deployment.tags = [ "network:gateway" "k8s:agent" "region:nl" ];
  deployment.buildOnTarget = true;

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
