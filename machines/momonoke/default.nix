{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "momonoke.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-agent" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "momonoke";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-x270
    ../../modules/nix/server.nix
    ../../modules/nix/k3s/agent.nix
    ./disable-docked-sleep.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./intel-gpu-hw-acceleration.nix
    ./power-management.nix
    ./tailscale.nix
  ];
}
