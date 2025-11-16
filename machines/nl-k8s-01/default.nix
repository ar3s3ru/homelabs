{ nixos-hardware, ... }:

{ pkgs, ... }:

{
  deployment.targetHost = "10.10.0.2";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "nl-k8s-01";
  networking.domain = "lan";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=fast"
    "--tls-san=nl-k8s-01.lan"
  ];

  imports = [
    nixos-hardware.nixosModules.common-pc-ssd
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-intel
    ../../modules/nix/server.nix
    ../../modules/nix/aarch64-cross-compile.nix
    ../../modules/nix/intel-gpu-hwaccel.nix
    ../../modules/nix/k3s/server-main.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./tailscale.nix
  ];
}
