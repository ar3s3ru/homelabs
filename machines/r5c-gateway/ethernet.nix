{
  systemd.network.links."10-lan0" = {
    matchConfig.Path = "platform-3c0400000.pcie-pci-0001:01:00.0";
    linkConfig.Name = "lan0";
  };

  systemd.network.links."10-wan0" = {
    matchConfig.Path = "platform-3c0800000.pcie-pci-0002:01:00.0";
    linkConfig.Name = "wan0";
  };
}
