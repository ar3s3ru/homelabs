{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "dejima.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-it" ];

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
    ../../modules/nix/server.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./tailscale.nix
    ./nvidia.nix
    ./group-media.nix
    ./kubernetes.nix
  ];
}
