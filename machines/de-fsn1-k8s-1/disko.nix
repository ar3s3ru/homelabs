{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_119168480";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "256M";
          type = "EF00";
          content.type = "filesystem";
          content.format = "vfat";
          content.mountpoint = "/boot";
        };
        nixos = {
          size = "100%";
          content.type = "lvm_pv";
          content.vg = "nixos";
        };
      };
    };
  };

  disko.devices.lvm_vg.nixos = {
    type = "lvm_vg";

    lvs.root = {
      size = "10G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/";
    };

    lvs.swap = {
      size = "4G";
      content.type = "swap";
    };

    lvs.nix = {
      size = "30G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/nix";
    };

    lvs.var = {
      size = "30G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/var";
    };

    lvs.data = {
      size = "+100%FREE";
    };
  };
}
