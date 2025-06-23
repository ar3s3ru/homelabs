{ lib, ... }:

{
  imports = [
    ./luks.nix
    ./systemd-boot.nix
  ];

  # Enable firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  # Enable Bluetooth on hosts.
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;

  # Enable netboot.xyz for booting images over the network.
  boot.loader.systemd-boot.netbootxyz.enable = true;

  # Disable NetworkManager wait-online target, which always inevitably fails.
  systemd.network.wait-online.enable = lib.mkForce false;
  boot.initrd.systemd.network.wait-online.enable = lib.mkForce false;
}
