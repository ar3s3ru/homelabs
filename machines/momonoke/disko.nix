{
  # Main server disk, boot partition and LVM mountpoint.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-CT2000P3PSSD8_2503E99F5716";
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
      size = "60G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/";
    };

    lvs.swap = {
      size = "8G";
      content.type = "swap";
    };

    lvs.nix = {
      size = "60G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/nix";
    };

    lvs.data = {
      size = "+100%FREE";
    };
  };
}
