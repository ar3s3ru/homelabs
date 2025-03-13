let
  ext4Partition = {
    type = "filesystem";
    format = "ext4";
  };

  mkExt4Partition = (mountpoint: ext4Partition // {
    inherit mountpoint;
  });
in
{
  # Samsung 870 QVO 1TB SSD.
  # Main server disk, boot partition and LVM mountpoint.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_QVO_1TB_S5RRNF0TC03724D";
    content = {
      type = "gpt";
      partitions = {
        # Main boot partition for the server.
        boot = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };

        # Main LVM volume group.
        primary = {
          size = "100%";
          content = {
            type = "lvm_pv";
            vg = "dejima";
          };
        };
      };
    };
  };

  # Main server partition layout: home folders, Nix store, etc.
  disko.devices.lvm_vg.dejima = {
    type = "lvm_vg";

    lvs.root = {
      size = "5G";
      content = mkExt4Partition "/";
    };

    lvs.swap = {
      size = "16G";
      content.type = "swap";
    };

    lvs.nix = {
      size = "300G";
      content = mkExt4Partition "/nix";
    };

    lvs.var = {
      size = "350G";
      content = mkExt4Partition "/var";
    };

    lvs.home = {
      size = "+100%FREE";
      content = mkExt4Partition "/home";
    };
  };

  # Western Digital Black 1TB HDD.
  # Used for storing large objects that do not require fast access times.
  disko.devices.disk.sda = {
    type = "disk";
    device = "/dev/disk/by-id/ata-WDC_WD1002FAEX-00Z3A0_WD-WCATRA460090";
    content = {
      type = "gpt";
      partitions = {
        # Used to store any sort of media, like TV series, movies, etc.
        media = {
          size = "750G";
          content = mkExt4Partition "/media";
        };
        # Unpartitioned, we can use it to mount it on a VM.
        vm-slow = {
          size = "100%";
          content = ext4Partition;
        };
      };
    };
  };

  # Western Digital Red 3TB HDD.
  # Used for storing large objects that do not require fast access times,
  # such as photos, videos, etc.
  fileSystems."/files" = {
    device = "/dev/disk/by-uuid/7811f863-87b6-4926-8443-147d9fcdf004";
    options = [
      # If you don't have this options attribute, it'll default to "defaults"
      # boot options for fstab. Search up fstab mount options you can use
      "nofail" # Prevent system from failing if this drive doesn't mount
    ];
  };
  # disko.devices.disk.sda = {
  #   type = "disk";
  #   device = "/dev/disk/by-id/ata-WDC_WD30EFRX-68EUZN0_WD-WCC4N2UCEJ17";
  #   content = {
  #     type = "gpt";
  #     partitions = {};
  #   };
  # };
}
