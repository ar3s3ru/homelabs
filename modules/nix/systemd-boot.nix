{ lib, ... }:

{
  # Use the systemd-boot EFI boot loader.
  services.acpid.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.systemd-boot.configurationLimit = 3;
}
