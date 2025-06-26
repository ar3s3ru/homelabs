{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "gladius.tail2ff90.ts.net";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "gladius";
  networking.domain = "ar3s3ru.dev";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";


  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=fast"
  ];

  imports = [
    nixos-hardware.nixosModules.common-pc-ssd
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-intel
    ../../modules/nix/server.nix
    ../../modules/nix/aarch64-cross-compile.nix
    ../../modules/nix/intel-gpu-hwaccel.nix
    ../../modules/nix/k3s/server.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./tailscale.nix
  ];
}
