{ pkgs, ... }:

{
  # Enable vaapi on OS-level
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    intel-vaapi-driver
    vaapiVdpau
    intel-compute-runtime
    # vpl-gpu-rt # QSV on 11th gen or newer
    intel-media-sdk # QSV up to 11th gen
  ];

  environment.systemPackages = with pkgs; [
    libva-utils
    jellyfin-ffmpeg
    clinfo
  ];
}
