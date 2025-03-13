{
  disko.devices = {
    disk.sda = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            name = "ESP";
            start = "1MiB";
            end = "256MiB";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          }
          {
            name = "luks";
            start = "256MiB";
            end = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              keyFile = "/tmp/cryptroot.key";
              content = {
                type = "lvm_pv";
                vg = "nixos";
              };
            };
          }
        ];
      };
    };

    lvm_vg.nixos = {
      type = "lvm_vg";
      lvs = {
        root = {
          size = "5G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
        swap = {
          size = "8G";
          content = {
            type = "swap";
          };
        };
        var = {
          size = "30G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/var";
          };
        };
        nix = {
          size = "200G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
          };
        };
        home = {
          size = "157G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/home";
          };
        };
      };
    };
  };
}
