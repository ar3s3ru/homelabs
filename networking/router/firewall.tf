# IPv4 firewall filter rules ---------------------------------------------------
#
# All defconf rules and homelab-specific rules. Order matters: rules are
# evaluated top-down. Resource declaration order in this file mirrors the
# desired router order (and matches the imported state).

# ipv4 input chain ------------------------------------------------------------

resource "routeros_ip_firewall_filter" "input_accept_established" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related,untracked"
}

resource "routeros_ip_firewall_filter" "input_drop_invalid" {
  chain            = "input"
  action           = "drop"
  connection_state = "invalid"
  comment          = "defconf: drop invalid"
}

resource "routeros_ip_firewall_filter" "input_accept_icmp" {
  chain    = "input"
  action   = "accept"
  protocol = "icmp"
  comment  = "defconf: accept ICMP"
}

resource "routeros_ip_firewall_filter" "input_accept_loopback" {
  chain       = "input"
  action      = "accept"
  dst_address = "127.0.0.1"
  comment     = "defconf: accept to local loopback (for CAPsMAN)"
}

resource "routeros_ip_firewall_filter" "input_guest_dns_dhcp" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  in_interface_list = "GUEST"
  dst_port          = "53,67"
  log               = true
  log_prefix        = "GUEST-ALLOW:"
  comment           = "allow guest DNS/DHCP"
}

resource "routeros_ip_firewall_filter" "input_guest_mdns" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_address       = "224.0.0.251"
  in_interface_list = "GUEST"
  dst_port          = "5353"
  log               = false
  log_prefix        = "MDNS-GUEST-ALLOW:"
  comment           = "allow mDNS from GUEST for AirPlay discovery (IPv4)"
}

resource "routeros_ip_firewall_filter" "input_iot_mdns" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_address       = "224.0.0.251"
  in_interface_list = "IOT"
  dst_port          = "5353"
  log               = false
  log_prefix        = "MDNS-IOT-ALLOW:"
  comment           = "allow mDNS from IOT for AirPlay discovery (IPv4)"
}

resource "routeros_ip_firewall_filter" "input_iot_dns_dhcp_udp" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  in_interface_list = "IOT"
  dst_port          = "53,67"
  comment           = "iot: allow DNS/DHCP to router"
}

resource "routeros_ip_firewall_filter" "input_iot_dns_tcp" {
  chain             = "input"
  action            = "accept"
  protocol          = "tcp"
  in_interface_list = "IOT"
  dst_port          = "53"
  comment           = "iot: allow DNS TCP to router"
}

resource "routeros_ip_firewall_filter" "input_drop_not_lan" {
  chain             = "input"
  action            = "drop"
  in_interface_list = "!LAN"
  log               = false
  log_prefix        = ""
  comment           = "defconf: drop all not coming from LAN"
}

resource "routeros_ip_firewall_filter" "input_drop_guest_to_router" {
  chain             = "input"
  action            = "drop"
  in_interface_list = "GUEST"
  log               = true
  log_prefix        = ""
  comment           = "drop guest to router traffic"
}

resource "routeros_move_items" "ip_firewall_input" {
  resource_name = "routeros_ip_firewall_filter"
  sequence = [
    routeros_ip_firewall_filter.input_guest_dns_dhcp.id,
    routeros_ip_firewall_filter.input_guest_mdns.id,
    routeros_ip_firewall_filter.input_iot_mdns.id,
    routeros_ip_firewall_filter.input_iot_dns_dhcp_udp.id,
    routeros_ip_firewall_filter.input_iot_dns_tcp.id,
    routeros_ip_firewall_filter.input_drop_not_lan.id,
  ]
}

# ipv4 forward chain ----------------------------------------------------------

resource "routeros_ip_firewall_filter" "forward_accept_ipsec_in" {
  chain        = "forward"
  action       = "accept"
  ipsec_policy = "in,ipsec"
  comment      = "defconf: accept in ipsec policy"
}

resource "routeros_ip_firewall_filter" "forward_accept_ipsec_out" {
  chain        = "forward"
  action       = "accept"
  ipsec_policy = "out,ipsec"
  comment      = "defconf: accept out ipsec policy"
}

resource "routeros_ip_firewall_filter" "forward_fasttrack" {
  chain            = "forward"
  action           = "fasttrack-connection"
  connection_state = "established,related"
  hw_offload       = true
  comment          = "defconf: fasttrack"
}

resource "routeros_ip_firewall_filter" "forward_accept_established" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related, untracked"
}

resource "routeros_ip_firewall_filter" "forward_drop_invalid" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  log              = true
  log_prefix       = "IPv4-DROP: "
  comment          = "defconf: drop invalid"
}

resource "routeros_ip_firewall_filter" "forward_allow_ingress_nginx" {
  chain             = "forward"
  action            = "accept"
  connection_state  = "new"
  protocol          = "tcp"
  dst_address_list  = "ipv4-k8s-ingress-controller"
  in_interface_list = "WAN"
  dst_port          = "80,443"
  log               = false
  log_prefix        = ""
  comment           = "allow port forwarding to k8s ingress controller"
}

resource "routeros_ip_firewall_filter" "forward_allow_slskd" {
  chain             = "forward"
  action            = "accept"
  protocol          = "tcp"
  dst_address_list  = "ipv4-slskd"
  in_interface_list = "WAN"
  dst_port          = "50429"
  log               = false
  log_prefix        = ""
  comment           = "allow port forwarding to slskd"
}

resource "routeros_ip_firewall_filter" "forward_allow_qbittorrent" {
  chain             = "forward"
  action            = "accept"
  protocol          = "tcp"
  dst_address_list  = "ipv4-qbittorrent"
  in_interface_list = "WAN"
  dst_port          = "30963"
  log               = false
  log_prefix        = ""
  comment           = "allow port forwarding to qbittorrent"
}

resource "routeros_ip_firewall_filter" "forward_drop_wan_not_dstnated" {
  chain                = "forward"
  action               = "drop"
  connection_state     = "new"
  connection_nat_state = "!dstnat"
  in_interface_list    = "WAN"
  log                  = true
  log_prefix           = "IPv4-DROP: "
  comment              = "defconf: drop all from WAN not DSTNATed"
}

resource "routeros_ip_firewall_filter" "forward_guest_to_internet" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "GUEST"
  out_interface_list = "WAN"
  log                = true
  log_prefix         = "GUEST-ALLOW: "
  comment            = "allow guest to internet"
}

resource "routeros_ip_firewall_filter" "forward_guest_to_ingress" {
  chain             = "forward"
  action            = "accept"
  protocol          = "tcp"
  dst_address_list  = "ipv4-k8s-ingress-controller"
  in_interface_list = "GUEST"
  dst_port          = "80,443"
  comment           = "allow guest to k8s ingress"
}

resource "routeros_ip_firewall_filter" "forward_airplay_return" {
  chain              = "forward"
  action             = "accept"
  protocol           = "udp"
  src_address_list   = "airplay-targets"
  in_interface_list  = "GUEST"
  out_interface_list = "LAN"
  dst_port           = "49152-65535"
  log                = false
  log_prefix         = "AIRPLAY-RET-UDP:"
  comment            = "allow AirPlay UDP return stream from airplay-targets to LAN"
}

resource "routeros_ip_firewall_filter" "forward_block_guest_to_lan" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = "GUEST"
  out_interface_list = "LAN"
  log                = false
  log_prefix         = ""
  comment            = "block guest to LAN"
}

resource "routeros_ip_firewall_filter" "forward_iot_lan_to_iot" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "LAN"
  out_interface_list = "IOT"
  comment            = "iot: allow LAN to IOT"
}

resource "routeros_ip_firewall_filter" "forward_iot_block_to_lan" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = "IOT"
  out_interface_list = "LAN"
  comment            = "iot: block IOT to LAN"
}

resource "routeros_ip_firewall_filter" "forward_iot_block_to_wan" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = "IOT"
  out_interface_list = "WAN"
  comment            = "iot: block IOT to WAN"
}

resource "routeros_ip_firewall_filter" "forward_guest_lan_to_guest" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "LAN"
  out_interface_list = "GUEST"
  comment            = "guest: allow LAN to GUEST"
}

resource "routeros_move_items" "ip_firewall_forward" {
  resource_name = "routeros_ip_firewall_filter"
  sequence = [
    routeros_ip_firewall_filter.forward_allow_ingress_nginx.id,
    routeros_ip_firewall_filter.forward_allow_slskd.id,
    routeros_ip_firewall_filter.forward_allow_qbittorrent.id,
    routeros_ip_firewall_filter.forward_drop_wan_not_dstnated.id,
    routeros_ip_firewall_filter.forward_guest_to_ingress.id,
    routeros_ip_firewall_filter.forward_airplay_return.id,
    routeros_ip_firewall_filter.forward_block_guest_to_lan.id,
  ]
}

# ipv4 nat chain --------------------------------------------------------------

resource "routeros_ip_firewall_nat" "srcnat_masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = "WAN"
  ipsec_policy       = "out,none"
  log                = false
  log_prefix         = ""
  comment            = "defconf: masquerade"
}

resource "routeros_ip_firewall_nat" "dstnat_bypass_router_mgmt" {
  chain             = "dstnat"
  action            = "accept"
  protocol          = "tcp"
  dst_address       = "10.0.0.1"
  in_interface_list = "LAN"
  dst_port          = "22,80,443"
  log               = false
  log_prefix        = ""
  comment           = "bypass dstnat for router mgmt (LAN)"
}

resource "routeros_ip_firewall_nat" "dstnat_ingress_http" {
  chain             = "dstnat"
  action            = "dst-nat"
  protocol          = "tcp"
  dst_address_type  = "local"
  in_interface_list = "all"
  dst_port          = "80"
  to_addresses      = "10.0.3.1"
  to_ports          = "80"
  log               = false
  log_prefix        = ""
  comment           = "port forward http to k8s ingress controller"
}

resource "routeros_ip_firewall_nat" "dstnat_ingress_https" {
  chain             = "dstnat"
  action            = "dst-nat"
  protocol          = "tcp"
  dst_address_type  = "local"
  in_interface_list = "all"
  dst_port          = "443"
  to_addresses      = "10.0.3.1"
  to_ports          = "443"
  log               = false
  log_prefix        = ""
  comment           = "port forward https to k8s ingress controller"
}

resource "routeros_ip_firewall_nat" "dstnat_slskd" {
  chain             = "dstnat"
  action            = "dst-nat"
  protocol          = "tcp"
  dst_address_type  = "local"
  in_interface_list = "all"
  to_addresses      = "10.0.3.2"
  to_ports          = "50429"
  log               = false
  log_prefix        = ""
  comment           = "port forward soulseek to slskd"
}

resource "routeros_ip_firewall_nat" "dstnat_qbittorrent" {
  chain             = "dstnat"
  action            = "dst-nat"
  protocol          = "tcp"
  dst_address_type  = "local"
  in_interface_list = "all"
  to_addresses      = "10.0.3.3"
  to_ports          = "30963"
  log               = false
  log_prefix        = ""
  comment           = "port forward qbittorrent"
}

resource "routeros_ip_firewall_nat" "srcnat_hairpin_http" {
  chain            = "srcnat"
  action           = "masquerade"
  protocol         = "tcp"
  src_address_list = "ipv4-local"
  dst_address_list = "ipv4-k8s-ingress-controller"
  dst_port         = "80"
  log              = false
  log_prefix       = ""
  comment          = "hairpin NAT http to k8s ingress controller"
}

resource "routeros_ip_firewall_nat" "srcnat_hairpin_https" {
  chain            = "srcnat"
  action           = "masquerade"
  protocol         = "tcp"
  src_address_list = "ipv4-local"
  dst_address_list = "ipv4-k8s-ingress-controller"
  dst_port         = "443"
  log              = false
  log_prefix       = ""
  comment          = "hairpin NAT https to k8s ingress controller"
}

resource "routeros_move_items" "ip_firewall_nat" {
  resource_name = "routeros_ip_firewall_nat"
  sequence = [
    routeros_ip_firewall_nat.dstnat_bypass_router_mgmt.id,
    routeros_ip_firewall_nat.dstnat_ingress_http.id,
    routeros_ip_firewall_nat.dstnat_ingress_https.id,
    routeros_ip_firewall_nat.dstnat_slskd.id,
    routeros_ip_firewall_nat.dstnat_qbittorrent.id,
  ]
}

# IPv6 firewall filter rules ---------------------------------------------------

# ipv6 input chain ------------------------------------------------------------

resource "routeros_ipv6_firewall_filter" "input_accept_established_v6" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related,untracked"
}

resource "routeros_ipv6_firewall_filter" "input_drop_invalid_v6" {
  chain            = "input"
  action           = "drop"
  connection_state = "invalid"
  comment          = "defconf: drop invalid"
}

resource "routeros_ipv6_firewall_filter" "input_accept_icmpv6" {
  chain    = "input"
  action   = "accept"
  protocol = "icmpv6"
  comment  = "defconf: accept ICMPv6"
}

resource "routeros_ipv6_firewall_filter" "input_accept_traceroute_v6" {
  chain    = "input"
  action   = "accept"
  protocol = "udp"
  dst_port = "33434-33534"
  comment  = "defconf: accept UDP traceroute"
}

resource "routeros_ipv6_firewall_filter" "input_accept_dhcpv6_pd" {
  chain       = "input"
  action      = "accept"
  protocol    = "udp"
  src_address = "fe80::/10"
  dst_port    = "546"
  comment     = "defconf: accept DHCPv6-Client prefix delegation."
}

resource "routeros_ipv6_firewall_filter" "input_accept_ike_v6" {
  chain    = "input"
  action   = "accept"
  protocol = "udp"
  dst_port = "500,4500"
  comment  = "defconf: accept IKE"
}

resource "routeros_ipv6_firewall_filter" "input_accept_ipsec_ah_v6" {
  chain    = "input"
  action   = "accept"
  protocol = "ipsec-ah"
  comment  = "defconf: accept ipsec AH"
}

resource "routeros_ipv6_firewall_filter" "input_accept_ipsec_esp_v6" {
  chain    = "input"
  action   = "accept"
  protocol = "ipsec-esp"
  comment  = "defconf: accept ipsec ESP"
}

resource "routeros_ipv6_firewall_filter" "input_accept_ipsec_policy_v6" {
  chain        = "input"
  action       = "accept"
  ipsec_policy = "in,ipsec"
  comment      = "defconf: accept all that matches ipsec policy"
}

resource "routeros_ipv6_firewall_filter" "input_guest_dns_dhcpv6_udp" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  in_interface_list = "GUEST"
  dst_port          = "53,547"
  log               = false
  log_prefix        = ""
  comment           = "guest: allow DNS/DHCPv6 to router"
}

resource "routeros_ipv6_firewall_filter" "input_guest_dns_tcp_v6" {
  chain             = "input"
  action            = "accept"
  protocol          = "tcp"
  in_interface_list = "GUEST"
  dst_port          = "53"
  log               = false
  log_prefix        = ""
  comment           = "guest: allow DNS TCP to router"
}

resource "routeros_ipv6_firewall_filter" "input_iot_dns_dhcpv6_udp" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  in_interface_list = "IOT"
  dst_port          = "53,547"
  comment           = "iot: allow DNS/DHCPv6 to router"
}

resource "routeros_ipv6_firewall_filter" "input_iot_dns_tcp_v6" {
  chain             = "input"
  action            = "accept"
  protocol          = "tcp"
  in_interface_list = "IOT"
  dst_port          = "53"
  comment           = "iot: allow DNS TCP to router"
}

resource "routeros_ipv6_firewall_filter" "input_guest_mdns_v6" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_address       = "ff02::fb/128"
  in_interface_list = "GUEST"
  dst_port          = "5353"
  log               = false
  log_prefix        = "MDNS-GUEST-ALLOW:"
  comment           = "allow mDNS from GUEST for AirPlay discovery (IPv6)"
}

resource "routeros_ipv6_firewall_filter" "input_iot_mdns_v6" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_address       = "ff02::fb/128"
  in_interface_list = "IOT"
  dst_port          = "5353"
  log               = false
  log_prefix        = "MDNS-IOT-ALLOW:"
  comment           = "allow mDNS from IOT for AirPlay discovery (IPv6)"
}

resource "routeros_ipv6_firewall_filter" "input_drop_not_lan_v6" {
  chain             = "input"
  action            = "drop"
  in_interface_list = "!LAN"
  log               = false
  log_prefix        = "IPv6-DROP: "
  comment           = "defconf: drop everything else not coming from LAN"
}

resource "routeros_move_items" "ipv6_firewall_input" {
  resource_name = "routeros_ipv6_firewall_filter"
  sequence = [
    routeros_ipv6_firewall_filter.input_guest_dns_dhcpv6_udp.id,
    routeros_ipv6_firewall_filter.input_guest_dns_tcp_v6.id,
    routeros_ipv6_firewall_filter.input_iot_dns_dhcpv6_udp.id,
    routeros_ipv6_firewall_filter.input_iot_dns_tcp_v6.id,
    routeros_ipv6_firewall_filter.input_guest_mdns_v6.id,
    routeros_ipv6_firewall_filter.input_iot_mdns_v6.id,
    routeros_ipv6_firewall_filter.input_drop_not_lan_v6.id,
  ]
}

# ipv6 forward chain ----------------------------------------------------------

resource "routeros_ipv6_firewall_filter" "forward_fasttrack_v6" {
  chain            = "forward"
  action           = "fasttrack-connection"
  connection_state = "established,related"
  log              = false
  log_prefix       = ""
  comment          = "defconf: fasttrack6"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_established_v6" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related,untracked"
  log              = false
  log_prefix       = "IPv6-EST-REL: "
  comment          = "defconf: accept established,related,untracked"
}

resource "routeros_ipv6_firewall_filter" "forward_lan_to_wan_v6" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "LAN"
  out_interface_list = "WAN"
  log                = false
  log_prefix         = "IPv6-LAN-WAN: "
  comment            = "lan: allow WAN outbound"
}

resource "routeros_ipv6_firewall_filter" "forward_drop_invalid_v6" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  log              = false
  log_prefix       = "IPv6-DROP-INVALID: "
  comment          = "defconf: drop invalid"
}

resource "routeros_ipv6_firewall_filter" "forward_drop_bad_src_v6" {
  chain            = "forward"
  action           = "drop"
  src_address_list = "bad_ipv6"
  comment          = "defconf: drop packets with bad src ipv6"
}

resource "routeros_ipv6_firewall_filter" "forward_drop_bad_dst_v6" {
  chain            = "forward"
  action           = "drop"
  dst_address_list = "bad_ipv6"
  comment          = "defconf: drop packets with bad dst ipv6"
}

resource "routeros_ipv6_firewall_filter" "forward_drop_hop_limit_1" {
  chain     = "forward"
  action    = "drop"
  protocol  = "icmpv6"
  hop_limit = "equal:1"
  comment   = "defconf: rfc4890 drop hop-limit=1"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_icmpv6" {
  chain    = "forward"
  action   = "accept"
  protocol = "icmpv6"
  comment  = "defconf: accept ICMPv6"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_hip_v6" {
  chain    = "forward"
  action   = "accept"
  protocol = "139"
  comment  = "defconf: accept HIP"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_ike_v6" {
  chain    = "forward"
  action   = "accept"
  protocol = "udp"
  dst_port = "500,4500"
  comment  = "defconf: accept IKE"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_ipsec_ah_v6" {
  chain    = "forward"
  action   = "accept"
  protocol = "ipsec-ah"
  comment  = "defconf: accept ipsec AH"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_ipsec_esp_v6" {
  chain    = "forward"
  action   = "accept"
  protocol = "ipsec-esp"
  comment  = "defconf: accept ipsec ESP"
}

resource "routeros_ipv6_firewall_filter" "forward_accept_ipsec_policy_v6" {
  chain        = "forward"
  action       = "accept"
  ipsec_policy = "in,ipsec"
  comment      = "defconf: accept all that matches ipsec policy"
}

resource "routeros_ipv6_firewall_filter" "forward_guest_to_wan_v6" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "GUEST"
  out_interface_list = "WAN"
  log                = false
  log_prefix         = ""
  comment            = "guest: allow WAN outbound"
}

resource "routeros_ipv6_firewall_filter" "forward_airplay_return_v6" {
  chain              = "forward"
  action             = "accept"
  protocol           = "udp"
  src_address_list   = "airplay-targets"
  in_interface_list  = "GUEST"
  out_interface_list = "LAN"
  dst_port           = "49152-65535"
  log                = false
  log_prefix         = "AIRPLAY-RET-UDP:"
  comment            = "allow AirPlay UDP return stream from airplay-targets to LAN (IPv6)"
}

resource "routeros_ipv6_firewall_filter" "forward_allow_ingress_nginx_v6" {
  chain             = "forward"
  action            = "accept"
  protocol          = "tcp"
  in_interface_list = "WAN"
  dst_address_list  = "ipv6-k8s-ingress-controller"
  dst_port          = "80,443"
  comment           = "allow port forwarding to k8s ingress controller (IPv6)"
}

resource "routeros_ipv6_firewall_filter" "forward_allow_slskd_v6" {
  chain             = "forward"
  action            = "accept"
  protocol          = "tcp"
  in_interface_list = "WAN"
  dst_address_list  = "ipv6-slskd"
  dst_port          = "50429"
  comment           = "allow port forwarding to slskd (IPv6)"
}

resource "routeros_ipv6_firewall_filter" "forward_allow_qbittorrent_v6" {
  chain             = "forward"
  action            = "accept"
  protocol          = "tcp"
  in_interface_list = "WAN"
  dst_address_list  = "ipv6-qbittorrent"
  dst_port          = "30963"
  comment           = "allow port forwarding to qbittorrent (IPv6)"
}

resource "routeros_ipv6_firewall_filter" "forward_drop_not_lan_v6" {
  chain             = "forward"
  action            = "drop"
  in_interface_list = "!LAN"
  comment           = "defconf: drop everything else not coming from LAN"
}

resource "routeros_ipv6_firewall_filter" "forward_iot_block_to_lan_v6" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = "IOT"
  out_interface_list = "LAN"
  comment            = "iot: block IOT to LAN (v6)"
}

resource "routeros_ipv6_firewall_filter" "forward_iot_block_to_wan_v6" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = "IOT"
  out_interface_list = "WAN"
  comment            = "iot: block IOT to WAN (v6)"
}

resource "routeros_ipv6_firewall_filter" "forward_iot_lan_to_iot_v6" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "LAN"
  out_interface_list = "IOT"
  comment            = "iot: allow LAN to IOT (v6)"
}

resource "routeros_ipv6_firewall_filter" "forward_guest_lan_to_guest_v6" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = "LAN"
  out_interface_list = "GUEST"
  comment            = "guest: allow LAN to GUEST (v6)"
}

resource "routeros_ipv6_firewall_filter" "forward_lan_ra_guard_v6" {
  chain             = "forward"
  action            = "drop"
  protocol          = "icmpv6"
  in_interface_list = "LAN"
  icmp_options      = "134:0"
  log               = false
  log_prefix        = ""
  comment           = "lan: RA guard for non-router devices"
}

resource "routeros_ipv6_firewall_filter" "forward_guest_ra_guard_v6" {
  chain             = "forward"
  action            = "drop"
  protocol          = "icmpv6"
  in_interface_list = "GUEST"
  icmp_options      = "134:0"
  log               = false
  log_prefix        = ""
  comment           = "guest: RA guard for non-router devices"
}

resource "routeros_ipv6_firewall_filter" "forward_iot_ra_guard_v6" {
  chain             = "forward"
  action            = "drop"
  protocol          = "icmpv6"
  in_interface_list = "IOT"
  icmp_options      = "134:0"
  log               = false
  log_prefix        = ""
  comment           = "iot: RA guard for non-router devices"
}

resource "routeros_move_items" "ipv6_firewall_forward" {
  resource_name = "routeros_ipv6_firewall_filter"
  sequence = [
    routeros_ipv6_firewall_filter.forward_drop_invalid_v6.id,
    routeros_ipv6_firewall_filter.forward_drop_bad_src_v6.id,
    routeros_ipv6_firewall_filter.forward_drop_bad_dst_v6.id,
    routeros_ipv6_firewall_filter.forward_drop_hop_limit_1.id,
    routeros_ipv6_firewall_filter.forward_accept_icmpv6.id,
    routeros_ipv6_firewall_filter.forward_accept_hip_v6.id,
    routeros_ipv6_firewall_filter.forward_accept_ike_v6.id,
    routeros_ipv6_firewall_filter.forward_accept_ipsec_ah_v6.id,
    routeros_ipv6_firewall_filter.forward_accept_ipsec_esp_v6.id,
    routeros_ipv6_firewall_filter.forward_accept_ipsec_policy_v6.id,
    routeros_ipv6_firewall_filter.forward_guest_to_wan_v6.id,
    routeros_ipv6_firewall_filter.forward_airplay_return_v6.id,
    routeros_ipv6_firewall_filter.forward_allow_ingress_nginx_v6.id,
    routeros_ipv6_firewall_filter.forward_allow_slskd_v6.id,
    routeros_ipv6_firewall_filter.forward_allow_qbittorrent_v6.id,
    routeros_ipv6_firewall_filter.forward_drop_not_lan_v6.id,
  ]
}
