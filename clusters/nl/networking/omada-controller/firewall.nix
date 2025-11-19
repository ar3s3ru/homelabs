{
  networking.firewall.allowedTCPPorts = [
    8088 # manage-http
    8043 # manage-https
    8843 # portal-https
    29812 # adopt-v1
    29813 # upgrade-v1
    29811 # manager-v1
    29814 # manager-v2
    29815 # transfer-v2
    29816 # rtty
    29817 # device-monitor
  ];

  networking.firewall.allowedUDPPorts = [
    27001 # app-discovery
    29810 # udp-discovery
    19810 # udp-management
  ];
}
