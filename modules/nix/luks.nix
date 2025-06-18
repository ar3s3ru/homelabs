{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cryptsetup
  ];

  boot.kernelModules = [ "dm_crypt" ];
}
