{ pkgs, ... }:

{
  # Source: https://wiki.nixos.org/wiki/Intel_Graphics

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD"; # Prefer the modern iHD backend
    # VDPAU_DRIVER = "va_gl"; # Only if using libvdpau-va-gl
  };

  hardware.enableRedistributableFirmware = true;
  boot.kernelParams = [ "i915.enable_guc=3" ];

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    intel-vaapi-driver
    libva-vdpau-driver
    intel-compute-runtime
    vpl-gpu-rt # QSV on 11th gen or newer
  ];

  environment.systemPackages = with pkgs; [
    libva-utils
    nvtopPackages.intel
  ];
}
