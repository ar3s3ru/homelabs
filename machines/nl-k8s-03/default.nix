{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "10.0.1.3";
  deployment.targetUser = "root";
  deployment.tags = [ "type-server" "k8s-server" "region-nl" ];

  nixpkgs.system = "x86_64-linux";

  networking.hostName = "nl-k8s-03";
  networking.domain = "home.arpa";

  time.timeZone = "Europe/Amsterdam";

  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=medium"
    "--node-label cianfr.one/gpu.transcoding.speed=medium"
    "--node-label cianfr.one/networking.linkspeed=1000Mbits"
    "--node-ip=10.0.1.3,fd00:cafe::1:3"
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
