# System-level router configuration: identity, clock, neighbor discovery,
# MAC server access lists, internet detection, logging.

resource "routeros_system_identity" "identity" {
  name = "RB5009UPr"
}

resource "routeros_system_clock" "clock" {
  time_zone_name       = "Europe/Amsterdam"
  time_zone_autodetect = true
}

# CDP/LLDP/MNDP neighbor discovery — restricted to LAN-side interfaces only.
resource "routeros_ip_neighbor_discovery_settings" "settings" {
  discover_interface_list  = routeros_interface_list.lan.name
  protocol                 = ["cdp", "lldp", "mndp"]
  mode                     = "tx-and-rx"
  lldp_mac_phy_config      = false
  lldp_max_frame_size      = false
  lldp_med_net_policy_vlan = "disabled"
  lldp_poe_power           = true
  lldp_vlan_info           = false
}

# MAC Telnet / MAC Winbox access — both restricted to LAN.
resource "routeros_tool_mac_server" "mac_server" {
  allowed_interface_list = routeros_interface_list.lan.name
}

resource "routeros_tool_mac_server_winbox" "mac_winbox" {
  allowed_interface_list = routeros_interface_list.lan.name
}

# Detect Internet — currently observes all interfaces but doesn't auto-add to
# any list (internet/lan/wan_interface_list all "none"). Mostly defconf.
resource "routeros_interface_detect_internet" "detect" {
  detect_interface_list = "all"
}

# System logging — defconf entries plus an extra dhcp,debug topic for tracing
# DHCPv4/DHCPv6 lease activity.
# Note: defconf entries (info, error, warning, critical) are pre-populated and
# will be imported separately; only dhcp,debug declared here.
resource "routeros_system_logging" "dhcp_debug" {
  topics = ["dhcp", "debug"]
  action = "memory"
}
