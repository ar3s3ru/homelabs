{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "eq14-001.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "k8s:agent" "region:nl" ];
  deployment.buildOnTarget = true;

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "eq14-001";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  imports = [
    nixos-hardware.nixosModules.common-pc-ssd
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-intel
    ./hardware-configuration.nix
    ./disko.nix
    ./tailscale.nix
    ./kubernetes.nix
  ];
}
