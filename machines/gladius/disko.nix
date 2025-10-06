{
  # Main server disk, boot partition and LVM mountpoint.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-KINGSTON_OM8TAP41024K1-A00_50026B7383D8F63B";
    content = {
      type = "gpt";
      partitions = {
        # Main boot partition for the server.
        boot = {
          size = "256M";
          type = "EF00";
          content.type = "filesystem";
          content.format = "vfat";
          content.mountpoint = "/boot";
        };
        # Main LVM volume group.
        nixos = {
          size = "100%";
          content.type = "lvm_pv";
          content.vg = "nixos";
        };
      };
    };
  };

  # Main server partition layout: home folders, Nix store, etc.
  disko.devices.lvm_vg.nixos = {
    type = "lvm_vg";

    lvs.root = {
      size = "100G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/";
    };

    lvs.swap = {
      size = "8G";
      content.type = "swap";
    };

    lvs.var = {
      size = "100G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/var";
    };

    lvs.data = {
      size = "+100%FREE";
    };
  };

  # ZFS pool for Kubernetes persistent volumes.
  #
  # NOTE: created manually using:
  #
  #   zpool create \
  #   -o ashift=12 \
  #   -O compression=lz4 \
  #   -O atime=off \
  #   -O xattr=sa \
  #   -O acltype=posixacl \
  #   -O mountpoint=/mnt/zpool-nl-01 \
  #   zpool-nl-01 \
  #   /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW63GZ8A
  #
  disko.devices.zpool.zpool-nl-01 = {
    type = "zpool";
    mode = ""; # Single disk initially (no RAID)

    options = {
      ashift = "12"; # 4K sector size (standard for modern HDDs)
      autotrim = "off"; # HDDs don't support TRIM
    };

    # Root dataset options
    rootFsOptions = {
      compression = "lz4"; # Enable compression
      atime = "off"; # Disable access time updates (performance)
      xattr = "sa"; # Store extended attributes efficiently
      acltype = "posixacl"; # POSIX ACLs for NFS
      mountpoint = "/mnt/zpool-nl-01"; # Mount pool root
    };

    # No child datasets - democratic-csi will create them directly under pool root
    datasets = { };
  };
}
