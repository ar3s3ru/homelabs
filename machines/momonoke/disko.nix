{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "256MiB";
          type = "EF00";
          content.type = "filesystem";
          content.format = "vfat";
          content.mountpoint = "/boot";
        };
        cryptroot = {
          size = "100%";
          content.type = "luks";
          content.name = "cryptroot";
          content.settings.keyFile = "/tmp/cryptroot.key";
          content.content.type = "lvm_pv";
          content.content.vg = "nixos";
        };
      };
    };
  };

  disko.devices.lvm_vg.nixos = {
    type = "lvm_vg";

    lvs.root = {
      size = "5G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/";
    };

    lvs.swap = {
      size = "8G";
      content.type = "swap";
    };

    lvs.var = {
      size = "30G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/var";
    };

    lvs.nix = {
      size = "200G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/nix";
    };

    lvs.home = {
      size = "157G";
      content.type = "filesystem";
      content.format = "ext4";
      content.mountpoint = "/home";
    };
  };
}
