{ pkgs, config, ... }:

{
  # Source: https://github.com/NixOS/nixpkgs/blob/fb6d337506f963e8ba4fedeaa9cc08d301ed4630/pkgs/applications/networking/cluster/k3s/docs/examples/STORAGE.md

  environment.systemPackages = with pkgs; [
    nfs-utils
  ];

  services.openiscsi.enable = true;
  services.openiscsi.name = "${config.networking.hostName}-initiatorhost";

  # For Longhorn - source: https://longhorn.io/docs/1.9.0/v2-data-engine/prerequisites/#memory
  boot.kernelModules = [
    "vfio_pci"
    "uio_pci_generic"
    "nvme-tcp"
  ];

  # Longhorn v2 Data Engine requires hugepages (1024 pages × 2MB = 2GiB).
  # Using sysctl instead of kernelParams for more reliable configuration.
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 1024;
  };

  # To be able to mount NFS volumes in all nodes.
  boot.supportedFilesystems = [ "nfs" ];
}
