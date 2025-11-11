{ config, ... }:
let
  nfsFirewallPorts = [
    111
    2049
    20048
    config.services.nfs.server.lockdPort
    config.services.nfs.server.mountdPort
    config.services.nfs.server.statdPort
  ];
in
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

  # Backup dataset for Longhorn volumes.
  # Created manually with:
  #   zfs create zpool-nl-01/longhorn-backups
  #   mkfs.ext4 /dev/zvol/zpool-nl-01/longhorn-backups
  fileSystems."/mnt/zpool-nl-01/longhorn-backups" = {
    device = "/dev/zvol/zpool-nl-01/longhorn-backups";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  # NFS server for democratic-csi
  services.nfs.server.enable = true;
  services.nfs.server.hostName = "gladius.home";
  services.nfs.server.nproc = 16;

  # Fix ports so we can expose over the firewall.
  services.nfs.server.lockdPort = 4001;
  services.nfs.server.mountdPort = 4002;
  services.nfs.server.statdPort = 4000;

  services.nfs.server.exports = ''
    /mnt/zpool-nl-01/longhorn-backups 192.168.2.0/24(rw,sync,no_subtree_check,no_root_squash)
    /mnt/zpool-nl-01/longhorn-backups 10.42.0.0/16(rw,sync,no_subtree_check,no_root_squash)
    /mnt/zpool-nl-01/longhorn-backups 10.43.0.0/16(rw,sync,no_subtree_check,no_root_squash)
  '';

  # Systemd hardening to prevent hung processes from blocking forever
  systemd.services.nfs-server.serviceConfig.TimeoutStopSec = "30s";
  # Send SIGKILL after timeout instead of waiting forever
  systemd.services.nfs-server.serviceConfig.KillMode = "mixed";
  # Ensure process dies even if in uninterruptible sleep
  systemd.services.nfs-server.serviceConfig.SendSIGKILL = "yes";

  # Wait for network to be fully up before starting NFS
  systemd.services.nfs-server.after = [ "network-online.target" ];
  systemd.services.nfs-server.wants = [ "network-online.target" ];
  
  # Force NFS to bind only to IPv4 and wait for address availability
  systemd.services.nfs-server.serviceConfig.ExecStart = [
    "" # Clear the default ExecStart
    "${config.systemd.package}/bin/rpc.nfsd --host 0.0.0.0 --tcp --no-udp ${toString config.services.nfs.server.nproc}"
  ];

  # NFS kernel tuning to improve stability under load
  boot.kernel.sysctl = {
    # Increase NFS server cache to handle more concurrent operations
    "fs.nfs.nlm_tcpport" = 32803;
    "fs.nfs.nlm_udpport" = 32769;
    # Prevent file handle exhaustion
    "fs.file-max" = 2097152;
    # Increase network buffer sizes for NFS traffic
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
  };

  # Source: https://wiki.nixos.org/wiki/NFS#Firewall
  networking.firewall.allowedTCPPorts = nfsFirewallPorts;
  networking.firewall.allowedUDPPorts = nfsFirewallPorts;

  # Add the democratic-csi SSH key for root access.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPrcCCbxkLl9WDaXxpMkrqmpSg3H+ftyCxr9H8rEekCKu682fvbNKL6fTOyJ24oYU/ZjKAP6iL5T0GJIIuV7EaTkU3mLricB4tUYJqVbtaIXSPRwBmi+p68eqvlHg7vO67Koy4I7PWFBozNeY6XGMhPCPsbc9czQdLWH7uEKaDcgX5qctq2Q2Isv3ePZI2GsYYPirZFwI0QVvxOxYoiC0b1BQssrw8UgWtfns7CVgrdKZcTNG0BgtS0eTz1RlM3mpwypIf3PYDawGEL42hpsZmNz3rR88DejfoKjunLu8i7HFtPYeuhnAr64dpZhVGLMuf6pzsjDIECm3nyT4hdkUTyZ+kAD/LQu+pZi2zgH+Ics7dOXwArBHBtyK1RKNC8xrsmxnfbe+QbaLuLxuBgd+swuuSAvyhvbS5dGLF6PtE1jcclRufjeY4d25y2EXuLcivrX/gsB/2WkTq9+jjkVHAnZUwUnuBT94DBgBhHy8s5GoTshGM6umdN90MPtSX8mcymxA6e4NsE9XEM51YJZetx9+ltFnfOFuEDdpyXudBPh4XYGJ5Lk7hwGM7Sh6MwWSrsii38G/+mwAYYJmPzgslc3xzzhAUBnTKetow4SfYrgELYjHAGhn/9FGTQh+E8rjDwuqKfvXWxpULW9hMQrKqrjDMDhARjDVUctcjC42/zQ== democratic-csi@clusters-nl"
  ];
}
