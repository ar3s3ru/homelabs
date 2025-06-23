{ nixos-hardware, ... }:

{ ... }:

{
  deployment.targetHost = "192.168.65.2";
  deployment.targetUser = "root";
  deployment.tags = [ "type-vm" "region-nl" ];

  nixpkgs.system = "aarch64-linux";

  networking.hostName = "utm-vm";
  networking.domain = "home.arpa";

  time.timeZone = "Europe/Amsterdam";

  imports = [
    ../../modules/nix/systemd-boot.nix
    ./hardware-configuration.nix
    ./disko.nix
  ];
}
