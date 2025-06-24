{
  # NOTE: list is used for machines that have multiple interfaces,
  # but should resolve with the same domain name.
  "eq14-001" = [
    {
      mac = "E8:FF:1E:DA:82:41";
      ip4 = "192.168.3.2";
      ip6 = [ "fd00:3::2" ];
    }
    # {
    #   mac = "";
    #   ip4 = "";
    #   ip6 = [ "" ];
    # }
  ];
  "momonoke" = [{
    mac = "54:E1:AD:A5:1D:0F";
    ip4 = "192.168.3.4";
    ip6 = [ "fd00:3::4" ];
  }];
  # Networking devices
  "eap245" = [{
    mac = "7C:F1:7E:74:FD:6E";
    ip4 = "192.168.3.20";
    ip6 = [ "fd00:3::20" ];
  }];
  "ac1200g" = [{
    mac = "34:97:F6:3E:A5:50";
    ip4 = "192.168.3.21";
    ip6 = [ "fd00:3::21" ];
  }];
  # Home automation devices
  "slimmelezer" = [{
    mac = "CC:7B:5C:4B:EF:8F";
    ip4 = "192.168.3.30";
    ip6 = [ "fd00:3::30" ];
  }];
  "xiaomi-vacuum" = [{
    mac = "70:C9:32:F5:30:DB";
    ip4 = "192.168.3.31";
    ip6 = [ "fd00:3::31" ];
  }];
  "e1-zoom-01" = [{
    mac = "24:3F:75:DD:7D:FB";
    ip4 = "192.168.3.32";
    ip6 = [ "fd00:3::32" ];
  }];
  "e1-zoom-02" = [{
    mac = "EC:71:DB:59:96:BB";
    ip4 = "192.168.3.33";
    ip6 = [ "fd00:3::33" ];
  }];
  "google-home-mini" = [{
    mac = "44:07:0B:90:CE:B6";
    ip4 = "192.168.3.34";
    ip6 = [ "fd00:3::34" ];
  }];
  # Other devices
  "bambu-lab-p1s" = [{
    mac = "DC:DA:0C:28:B1:20";
    ip4 = "192.168.3.40";
    ip6 = [ "fd00:3::40" ];
  }];
}
