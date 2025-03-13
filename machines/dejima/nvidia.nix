{ config, pkgs, ... }:

{
  # Enable OpenGL
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # Modesetting is required.
  hardware.nvidia.modesetting.enable = true;

  # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
  hardware.nvidia.powerManagement.enable = false;

  # Fine-grained power management. Turns off GPU when not in use.
  # Experimental and only works on modern Nvidia GPUs (Turing or newer).
  hardware.nvidia.powerManagement.finegrained = false;

  # Use the NVidia open source kernel module (not to be confused with the
  # independent third-party "nouveau" open source driver).
  # Support is limited to the Turing and later architectures. Full list of
  # supported GPUs is at:
  # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
  # Only available from driver 515.43.04+
  # Currently alpha-quality/buggy, so false is currently the recommended setting.
  hardware.nvidia.open = false;

  # Enable the Nvidia settings menu,
  # accessible via `nvidia-settings`.
  hardware.nvidia.nvidiaSettings = true;

  # Optionally, you may need to select the appropriate driver version for your specific GPU.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;

  # Pass the GPU to Docker and Kubernetes.
  hardware.nvidia-container-toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    libva-utils
    vdpauinfo
    jellyfin-ffmpeg
    clinfo
  ];
}
