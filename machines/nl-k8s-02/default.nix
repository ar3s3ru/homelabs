{ nixos-hardware, ... }:

{ pkgs, ... }:

{
  deployment.targetHost = "10.0.1.2";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "nl-k8s-02";
  networking.domain = "home.arpa";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=fast"
    "--node-ip=10.0.1.2,fd00:cafe::1:2"
  ];

  imports = [
    nixos-hardware.nixosModules.common-pc-ssd
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-intel
    ../../modules/nix/server.nix
    ../../modules/nix/intel-gpu-hwaccel.nix
    ../../modules/nix/k3s/server.nix
    ./disko.nix
    ./networking.nix
    ./hardware-configuration.nix
    ./tailscale.nix
  ];
}
