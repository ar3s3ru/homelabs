{ pkgs, ... }:

{
  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;

  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = true;

  boot.tmp.useTmpfs = true;

  # Source: https://github.com/bdew/nanopi-image/blob/8949a34/modules/r5c.nix
  hardware.deviceTree.name = "rockchip/rk3568-nanopi-r5c.dtb";

  # Source: https://github.com/bdew/nanopi-image/blob/8949a346a11120769823fe70212fdddab514c4c8/modules/common.nix
  hardware.firmware = [ pkgs.linux-firmware ];

  # Most Rockchip CPUs (especially with hybrid cores) work best with "schedutil"
  powerManagement.cpuFreqGovernor = "schedutil";

  # Let's blacklist the Rockchips RTC module so that the
  # battery-powered HYM8563 (rtc_hym8563 kernel module) will be used
  # by default
  boot.blacklistedKernelModules = [ "rtc_rk808" ];

  boot.kernelParams = [
    "console=tty1"
    "console=ttyS2,1500000"
    "earlycon=uart8250,mmio32,0xfe660000"
  ];

  boot.initrd.availableKernelModules = [
    "sdhci_of_dwcmshc"
    "dw_mmc_rockchip"
    "analogix_dp"
    "io-domain"
    "rockchip_saradc"
    "rockchip_thermal"
    "rockchipdrm"
    "rockchip-rga"
    "pcie_rockchip_host"
    "phy-rockchip-pcie"
    "phy_rockchip_snps_pcie3"
    "phy_rockchip_naneng_combphy"
    "phy_rockchip_inno_usb2"
    "dwmac_rk"
    "dw_wdt"
    "dw_hdmi"
    "dw_hdmi_cec"
    "dw_hdmi_i2s_audio"
    "dw_mipi_dsi"
  ];
}
