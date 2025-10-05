{
  # Required for ZFS - must be unique per machine
  # Generated: head -c 8 /etc/machine-id
  networking.hostId = "79658f96";

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  # boot.zfs.extraPools = [ "zpool-nl-01" ];

  # # ZFS services (weekly, default)
  # services.zfs.autoScrub.enable = true;

  # # NFS server for democratic-csi
  # services.nfs.server.enable = true;

  # networking.firewall.allowedTCPPorts = [
  #   2049 # NFS
  #   111 # RPC
  #   20048 # mountd
  # ];

  # networking.firewall.allowedUDPPorts = [
  #   2049 # NFS
  #   111 # RPC
  #   20048 # mountd
  # ];
}
