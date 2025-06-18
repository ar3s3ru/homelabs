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


  services.k3s.extraFlags = [
    "--node-label media.transcoding.gpu=fast"
    # Add the tailnet address for the main node, so that
    # nodes outside the home network (e.g. hetzner cloud machines)
    # can still connect to this main node.
    "--tls-san=eq14-001.tail2ff90.ts.net"
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
