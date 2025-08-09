{ nixos-hardware, ... }:

{ pkgs, ... }:

{
  deployment.targetHost = "eq14-001.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "eq14-001";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";


  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=fast"
    "--tls-san=eq14-1.home"
    "--tls-san=k8s.flugg.app" # Necessary to reach the cluster from flugg tenant.
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
