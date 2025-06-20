{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "eq14-001.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "eq14-001";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  imports = [
    nixos-hardware.nixosModules.common-pc-ssd
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-intel
    ../../modules/nix/server.nix
    ../../modules/nix/k3s/server-main.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./tailscale.nix
  ];
}
