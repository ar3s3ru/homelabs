{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "momonoke.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type:server" "k8s:server" "region:nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "momonoke";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-x270
    ../../modules/nix/server.nix
    ./hardware-configuration.nix
    ./disable-docked-sleep.nix
    ./disko.nix
    ./intel-gpu-hw-acceleration.nix
    ./kubernetes.nix
    ./power-management.nix
    ./tailscale.nix
  ];
}
