{ nixos-hardware, ... }:

{ lib, ... }:

{
  deployment.targetHost = "192.168.3.1";
  deployment.targetUser = "root";
  deployment.tags = [ "type-gateway" "region-nl" ];

  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.system = "aarch64-linux";
  # nixpkgs.hostPlatform.system = "aarch64-linux";
  # nixpkgs.buildPlatform.system = "x86_64-linux";

  networking.hostName = "r5c-gateway";
  networking.domain = "home.arpa";

  time.timeZone = "Europe/Amsterdam";

  # Disable NetworkManager wait-online target, which always inevitably fails.
  systemd.network.wait-online.enable = lib.mkForce false;
  boot.initrd.systemd.network.wait-online.enable = lib.mkForce false;

  # Additional authorized key from the dedicated UTM VM.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2Tt5C8o0k37fcrDsUOCiFBCakaSuRvMsmGFoBmhA5V root@utm-vm"
  ];

  imports = [
    ./hardware-configuration.nix
    ./dhcp.nix
    ./dns.nix
    ./ethernet.nix
    ./kernel.nix
    ./network.nix
    ./pppoe.nix
  ];
}
