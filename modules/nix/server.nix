{ lib, ... }:

{
  # Enable firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  # Enable Bluetooth on hosts.
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;

  # Use the systemd-boot EFI boot loader.
  services.acpid.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.systemd-boot.configurationLimit = 3;

  # Enable netboot.xyz for booting images over the network.
  boot.loader.systemd-boot.netbootxyz.enable = true;

  # Disable NetworkManager wait-online target, which always inevitably fails.
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
}
