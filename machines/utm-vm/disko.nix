{
  # Main server disk, boot partition and LVM mountpoint.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
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

  disko.devices.lvm_vg.nixos = {
    type = "lvm_vg";

    lvs.root = {
      size = "+100%FREE";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/";
    };

    lvs.swap = {
      size = "8G";
      content.type = "swap";
    };
  };
}
