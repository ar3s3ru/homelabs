{ disko, nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "dejima-ar3s3ru-dev.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "k8s:server" "region:it" ];
  deployment.buildOnTarget = true;

  nixpkgs.system = "x86_64-linux";
  nixpkgs.config.allowUnfree = true; # NVIDIA stuff.

  networking.hostName = "dejima";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Rome";

  imports = [
    nixos-hardware.nixosModules.common-pc-ssd
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    disko.nixosModules.disko
    ./hardware-configuration.nix
    ./disko.nix
    ./tailscale.nix
    ./nvidia.nix
    ./group-media.nix
    ./kubernetes.nix
  ];
}
