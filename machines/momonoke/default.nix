{ nixos-hardware, ... }:

{ pkgs, ... }:

{
  deployment.targetHost = "momonoke.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-agent" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "momonoke";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  networking.firewall.allowedTCPPorts = [
    40000 # NOTE: not sure where this is coming from... It was the router (192.168.2.254)
  ];

  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=medium"
  ];

  environment.systemPackages = with pkgs; [
    immich-cli
  ];

  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-x270
    ../../modules/nix/server.nix
    ../../modules/nix/aarch64-cross-compile.nix
    ../../modules/nix/intel-gpu-hwaccel.nix
    ../../modules/nix/k3s/server.nix
    ./disable-docked-sleep.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./power-management.nix
    ./tailscale.nix
  ];
}
