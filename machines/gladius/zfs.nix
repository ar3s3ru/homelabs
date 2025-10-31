{
  # Required for ZFS - must be unique per machine
  # Generated: head -c 8 /etc/machine-id
  networking.hostId = "79658f96";

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  boot.zfs.extraPools = [ "zpool-nl-01" ];

  # ZFS services (weekly, default)
  services.zfs.autoScrub.enable = true;

  # NFS server for democratic-csi
  services.nfs.server.enable = true;
  services.nfs.server.hostName = "gladius.home";

  # Backup dataset for Longhorn volumes.
  # Created manually with:
  #   zfs create zpool-nl-01/longhorn-backups
  #   mkfs.ext4 /dev/zvol/zpool-nl-01/longhorn-backups
  fileSystems."/mnt/zpool-nl-01/longhorn-backups" = {
    device = "/dev/zvol/zpool-nl-01/longhorn-backups";
    fsType = "ext4";
    options = [ "defaults" ];
  };
  services.nfs.server.exports = ''
    /mnt/zpool-nl-01/longhorn-backups 192.168.2.0/24(rw,sync,no_subtree_check,no_root_squash)
    /mnt/zpool-nl-01/longhorn-backups 10.42.0.0/16(rw,sync,no_subtree_check,no_root_squash)
    /mnt/zpool-nl-01/longhorn-backups 10.43.0.0/16(rw,sync,no_subtree_check,no_root_squash)
  '';

  # Source: https://wiki.nixos.org/wiki/NFS#Firewall
  networking.firewall.allowedTCPPorts = [ 111 2049 20048 ];
  networking.firewall.allowedUDPPorts = [ 111 2049 20048 ];

  # Add the democratic-csi SSH key for root access.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPrcCCbxkLl9WDaXxpMkrqmpSg3H+ftyCxr9H8rEekCKu682fvbNKL6fTOyJ24oYU/ZjKAP6iL5T0GJIIuV7EaTkU3mLricB4tUYJqVbtaIXSPRwBmi+p68eqvlHg7vO67Koy4I7PWFBozNeY6XGMhPCPsbc9czQdLWH7uEKaDcgX5qctq2Q2Isv3ePZI2GsYYPirZFwI0QVvxOxYoiC0b1BQssrw8UgWtfns7CVgrdKZcTNG0BgtS0eTz1RlM3mpwypIf3PYDawGEL42hpsZmNz3rR88DejfoKjunLu8i7HFtPYeuhnAr64dpZhVGLMuf6pzsjDIECm3nyT4hdkUTyZ+kAD/LQu+pZi2zgH+Ics7dOXwArBHBtyK1RKNC8xrsmxnfbe+QbaLuLxuBgd+swuuSAvyhvbS5dGLF6PtE1jcclRufjeY4d25y2EXuLcivrX/gsB/2WkTq9+jjkVHAnZUwUnuBT94DBgBhHy8s5GoTshGM6umdN90MPtSX8mcymxA6e4NsE9XEM51YJZetx9+ltFnfOFuEDdpyXudBPh4XYGJ5Lk7hwGM7Sh6MwWSrsii38G/+mwAYYJmPzgslc3xzzhAUBnTKetow4SfYrgELYjHAGhn/9FGTQh+E8rjDwuqKfvXWxpULW9hMQrKqrjDMDhARjDVUctcjC42/zQ== democratic-csi@clusters-nl"
  ];
}
