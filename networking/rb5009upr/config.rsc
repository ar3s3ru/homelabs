[admin@RB5009UPr] > /export
# 2026-02-08 18:44:49 by RouterOS 7.19.6
# software id = 4GBB-HN8L
#
# model = RB5009UPr+S+
# serial number = HKJ0ARDSMWY
/interface bridge
add admin-mac=04:F4:1C:F3:B4:AB auto-mac=no comment=defconf name=bridge vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] comment=Office
set [ find default-name=ether2 ] comment="Living Room (EAP245)"
set [ find default-name=ether3 ] comment=Bedroom
set [ find default-name=ether4 ] comment="Living Room (E1-Zoom)"
set [ find default-name=ether8 ] comment="WAN port"
/interface vlan
add interface=ether8 name=vlan6-ether8 vlan-id=6
add comment="guest network" interface=bridge name=vlan80-guest vlan-id=80
/interface pppoe-client
add add-default-route=yes disabled=no interface=vlan6-ether8 name=pppoe-kpn user=F0-4D-D4-38-4B-20@internet
/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
add comment="guest network" name=GUEST
/ip pool
add name=pool-dhcp-v4 ranges=10.0.0.100-10.0.0.254
add name=pool-dhcp-v4-guest ranges=10.80.0.10-10.80.0.254
/ip dhcp-server
add address-pool=pool-dhcp-v4 interface=bridge name=defconf use-reconfigure=yes
add address-pool=pool-dhcp-v4-guest interface=vlan80-guest name=dhcp-v4-guest use-reconfigure=yes
/ipv6 dhcp-server
add address-pool=pool-dhcp-v6-ula-lan interface=bridge name=dhcp-v6-ula-lan
/ipv6 pool
add name=pool-dhcp-v6-ula-lan prefix=fd00:cafe::/64 prefix-length=128
/disk settings
set auto-media-interface=bridge auto-media-sharing=yes auto-smb-sharing=yes
/interface bridge port
add bridge=bridge comment=defconf interface=ether1
add bridge=bridge comment=defconf interface=ether2
add bridge=bridge comment=defconf interface=ether3
add bridge=bridge comment=defconf interface=ether4
add bridge=bridge comment=defconf interface=ether5
add bridge=bridge comment=defconf interface=ether6
add bridge=bridge comment=defconf interface=ether7
add bridge=bridge comment=defconf interface=sfp-sfpplus1
/ip neighbor discovery-settings
set discover-interface-list=LAN
/interface bridge vlan
add bridge=bridge tagged=bridge,ether2 untagged=none vlan-ids=80
/interface detect-internet
set detect-interface-list=all
/interface list member
add interface=ether2 list=LAN
add interface=ether3 list=LAN
add interface=ether4 list=LAN
add interface=ether5 list=LAN
add interface=ether6 list=LAN
add interface=ether7 list=LAN
add interface=ether1 list=LAN
add interface=sfp-sfpplus1 list=LAN
add interface=pppoe-kpn list=WAN
add interface=bridge list=LAN
add interface=vlan80-guest list=GUEST
add interface=vlan6-ether8 list=WAN
/ip address
add address=10.0.0.1/16 comment=defconf interface=bridge network=10.0.0.0
add address=10.80.0.1/24 comment="guest network" interface=vlan80-guest network=10.80.0.0
/ip dhcp-server lease
add address=10.0.0.2 client-id=1:4:f4:1c:84:3c:e8 comment=CRS310-8G+2S+ mac-address=04:F4:1C:84:3C:E8 server=defconf
add address=10.0.0.3 comment=EAP-245 mac-address=7C:F1:7E:74:FD:6E server=defconf
add address=10.0.0.4 comment="ASUS AP" mac-address=34:97:F6:3E:A5:50 server=defconf
add address=10.0.0.10 comment="Bambu Lab P1S" mac-address=DC:DA:0C:28:B1:20 server=defconf
add address=10.0.0.11 comment=Slimmelezer mac-address=CC:7B:5C:4B:EF:8F server=defconf
add address=10.0.0.12 comment="Google Home Mini" mac-address=44:07:0B:90:CE:B6 server=defconf
add address=10.0.0.20 comment=E1-Zoom-01 mac-address=24:3F:75:DD:7D:FB server=defconf
add address=10.0.0.21 comment=E1-Zoom-02 mac-address=EC:71:DB:59:96:BB server=defconf
add address=10.0.1.20 comment="nl-pve-01 TrueNAS" mac-address=BC:24:11:DE:69:E3 server=defconf
add address=10.0.1.1 comment=nl-k8s-01 mac-address=6C:1F:F7:57:07:49 server=defconf
add address=10.0.1.2 comment=nl-k8s-02 mac-address=BC:24:11:A2:94:61 server=defconf
add address=10.0.1.3 comment=nl-k8s-03 mac-address=BC:24:11:07:69:C7 server=defconf
add address=10.0.1.4 comment=nl-k8s-04 mac-address=54:E1:AD:A5:1D:0F server=defconf
add address=10.0.2.1 comment=nl-pve-01 mac-address=58:47:CA:7F:76:99 server=defconf
add address=10.0.2.2 comment=nl-pve-02 mac-address=98:FA:9B:13:C8:E8 server=defconf
add address=10.0.0.179 comment="LG BX 55" mac-address=F8:B9:5A:65:E2:36 server=defconf
add address=10.0.0.5 comment="NanoPi R5C" mac-address=AE:15:95:A0:DC:09 server=defconf
/ip dhcp-server network
add address=10.0.0.0/16 comment=defconf dns-server=10.0.0.1 domain=home.arpa gateway=10.0.0.1
add address=10.80.0.0/24 comment="guest network" dns-server=10.80.0.1 gateway=10.80.0.1
/ip dns
set allow-remote-requests=yes servers=1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001
/ip dns static
add address=10.0.0.1 comment=defconf name=router.home.arpa type=A
add address=10.0.1.20 name=truenas.home.arpa type=A
add address=10.0.1.1 name=nl-k8s-01.home.arpa type=A
add address=10.0.1.2 name=nl-k8s-02.home.arpa type=A
add address=10.0.1.3 name=nl-k8s-03.home.arpa type=A
add address=10.0.1.4 name=nl-k8s-04.home.arpa type=A
add address=10.0.2.1 name=nl-pve-01.home.arpa type=A
add address=10.0.2.2 name=nl-pve-02.home.arpa type=A
add address=10.0.0.3 name=eap245-7c-f1-7e-74-fd-6e.home.arpa type=A
add address=10.0.0.2 comment="from-dhcp (04:F4:1C:84:3C:E8)" name=CRS310-8G+2S+.home.arpa ttl=10m type=A
add address=10.0.0.3 comment="from-dhcp (7C:F1:7E:74:FD:6E)" name=EAP245-7C-F1-7E-74-FD-6E.home.arpa ttl=10m type=A
add address=10.0.0.11 comment="from-dhcp (CC:7B:5C:4B:EF:8F)" name=slimmelezer.home.arpa ttl=10m type=A
add address=10.0.0.12 comment="from-dhcp (44:07:0B:90:CE:B6)" name=Google-Home-Mini.home.arpa ttl=10m type=A
add address=10.0.0.20 comment="from-dhcp (24:3F:75:DD:7D:FB)" name=e1-zoom-01.home.arpa ttl=10m type=A
add address=10.0.0.21 comment="from-dhcp (EC:71:DB:59:96:BB)" name=e1-zoom-02.home.arpa ttl=10m type=A
add address=10.0.0.179 comment="from-dhcp (F8:B9:5A:65:E2:36)" name=LGwebOSTV.home.arpa ttl=10m type=A
add address=10.0.0.5 comment="from-dhcp (AE:15:95:A0:DC:09)" name=r5c.home.arpa ttl=10m type=A
add address=10.0.0.155 comment="from-dhcp (B4:E6:2D:EF:64:C5)" name=esp32-bluetooth-proxy-ef64c5.home.arpa ttl=10m type=A
add address=10.0.0.154 comment="from-dhcp (80:64:6F:F5:EF:E8)" name=Litter-Robot4.home.arpa ttl=10m type=A
add address=10.0.0.151 comment="from-dhcp (70:C9:32:F5:30:DB)" name=xiaomi_vacuum_c102gl.home.arpa ttl=10m type=A
/ip firewall address-list
add address=10.0.0.0/8 list=ipv4-local
add address=10.0.3.1 list=ipv4-k8s-ingress-controller
add address=10.0.3.2 list=ipv4-slskd
add address=10.0.3.3 list=ipv4-qbittorrent
/ip firewall filter
add action=accept chain=input comment="defconf: accept established,related,untracked" connection-state=established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=invalid
add action=accept chain=input comment="defconf: accept ICMP" protocol=icmp
add action=accept chain=input comment="defconf: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1
add action=accept chain=input comment="allow guest DNS/DHCP" dst-port=53,67 in-interface-list=GUEST log=yes log-prefix=GUEST-ALLOW: protocol=udp
add action=drop chain=input comment="defconf: drop all not coming from LAN" in-interface-list=!LAN
add action=accept chain=forward comment="defconf: accept in ipsec policy" ipsec-policy=in,ipsec
add action=accept chain=forward comment="defconf: accept out ipsec policy" ipsec-policy=out,ipsec
add action=fasttrack-connection chain=forward comment="defconf: fasttrack" connection-state=established,related hw-offload=yes
add action=accept chain=forward comment="defconf: accept established,related, untracked" connection-state=established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" connection-state=invalid log=yes log-prefix="IPv4-DROP: "
add action=accept chain=forward comment="allow port forwarding to k8s ingress controller" connection-state=new dst-address-list=ipv4-k8s-ingress-controller dst-port=80,443 \
    in-interface-list=WAN protocol=tcp
add action=accept chain=forward comment="allow port forwarding to slskd" dst-address-list=ipv4-slskd dst-port=50429 in-interface-list=WAN protocol=tcp
add action=accept chain=forward comment="allow port forwarding to qbittorrent" dst-address-list=ipv4-qbittorrent dst-port=30963 in-interface-list=WAN protocol=tcp
add action=drop chain=forward comment="defconf: drop all from WAN not DSTNATed" connection-nat-state=!dstnat connection-state=new in-interface-list=WAN log=yes log-prefix=\
    "IPv4-DROP: "
add action=accept chain=forward comment="allow guest to internet" in-interface-list=GUEST log=yes log-prefix="GUEST-ALLOW: " out-interface-list=WAN
add action=accept chain=forward comment="allow guest to k8s ingress" dst-address-list=ipv4-k8s-ingress-controller dst-port=80,443 in-interface-list=GUEST protocol=tcp
add action=drop chain=forward comment="block guest to LAN" in-interface-list=GUEST out-interface-list=LAN
add action=drop chain=input comment="drop guest to router traffic" in-interface-list=GUEST log=yes
/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" ipsec-policy=out,none out-interface-list=WAN
add action=dst-nat chain=dstnat comment="port forward http to k8s ingress controller" dst-address-list=ipv4-wan dst-address-type=local dst-port=80 in-interface-list=all protocol=\
    tcp to-addresses=10.0.3.1 to-ports=80
add action=dst-nat chain=dstnat comment="port forward https to k8s ingress controller" dst-address-list=ipv4-wan dst-address-type=local dst-port=443 in-interface-list=all \
    protocol=tcp to-addresses=10.0.3.1 to-ports=443
add action=dst-nat chain=dstnat comment="port forward soulseek to slskd" dst-address-list=ipv4-wan in-interface-list=all protocol=tcp to-addresses=10.0.3.2 to-ports=50429
add action=dst-nat chain=dstnat comment="port forward qbittorrent" dst-address-list=ipv4-wan in-interface-list=all protocol=tcp to-addresses=10.0.3.3 to-ports=30963
add action=masquerade chain=srcnat comment="hairpin NAT http to k8s ingress controller" dst-address-list=ipv4-k8s-ingress-controller dst-port=80 protocol=tcp src-address-list=\
    ipv4-local
add action=masquerade chain=srcnat comment="hairpin NAT https to k8s ingress controller" dst-address-list=ipv4-k8s-ingress-controller dst-port=443 protocol=tcp src-address-list=\
    ipv4-local
/ip firewall service-port
set ftp disabled=yes
set h323 disabled=yes
set pptp disabled=yes
set rtsp disabled=no
/ip upnp
set enabled=yes
/ipv6 address
add address=::1 from-pool=pool-dhcp-v6-prefix-delegation interface=bridge
add address=fd00:cafe::1 advertise=no interface=bridge
add address=fd00:cafe:80::1 advertise=no interface=vlan80-guest
add address=::6f4:1cff:fef3:b4ab eui-64=yes from-pool=pool-dhcp-v6-prefix-delegation interface=vlan80-guest
/ipv6 dhcp-client
add add-default-route=yes allow-reconfigure=yes interface=pppoe-kpn pool-name=pool-dhcp-v6-prefix-delegation prefix-address-lists="" request=prefix use-peer-dns=no
/ipv6 firewall address-list
add address=::/128 comment="defconf: unspecified address" list=bad_ipv6
add address=::1/128 comment="defconf: lo" list=bad_ipv6
add address=fec0::/10 comment="defconf: site-local" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: ipv4-mapped" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: discard only " list=bad_ipv6
add address=2001:db8::/32 comment="defconf: documentation" list=bad_ipv6
add address=2001:10::/28 comment="defconf: ORCHID" list=bad_ipv6
add address=3ffe::/16 comment="defconf: 6bone" list=bad_ipv6
/ipv6 firewall filter
add action=accept chain=input comment="defconf: accept established,related,untracked" connection-state=established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" dst-port=33434-33534 protocol=udp
add action=accept chain=input comment="defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=ipsec-esp
add action=accept chain=input comment="defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=accept chain=input comment="allow DHCPv6 on GUEST" dst-port=547 in-interface-list=GUEST protocol=udp
add action=accept chain=input comment="allow DNS UDP requests on GUEST" dst-port=53 in-interface-list=GUEST protocol=udp
add action=accept chain=input comment="allow DNS TCP requests on GUEST" dst-port=53 in-interface-list=GUEST protocol=tcp
add action=drop chain=input comment="defconf: drop everything else not coming from LAN" in-interface-list=!LAN log-prefix="IPv6-DROP: "
add action=fasttrack-connection chain=forward comment="defconf: fasttrack6" connection-state=established,related
add action=accept chain=forward comment="defconf: accept established,related,untracked" connection-state=established,related,untracked log-prefix="IPv6-EST-REL: "
add action=accept chain=forward comment="allow LAN to WAN outbound" in-interface-list=LAN log-prefix="IPv6-LAN-WAN: " out-interface-list=WAN
add action=drop chain=forward comment="defconf: drop invalid" connection-state=invalid log-prefix="IPv6-DROP-INVALID: "
add action=drop chain=forward comment="defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=ipsec-esp
add action=accept chain=forward comment="defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=accept chain=forward comment="allow WAN access from GUEST" in-interface-list=GUEST out-interface-list=WAN
add action=drop chain=forward comment="defconf: drop everything else not coming from LAN" in-interface-list=!LAN
/ipv6 firewall mangle
add action=change-mss chain=forward comment="IPv6 MSS clamp for PPPoE" new-mss=clamp-to-pmtu out-interface=pppoe-kpn protocol=tcp tcp-flags=syn
/ipv6 nd
set [ find default=yes ] disabled=yes other-configuration=yes
add dns=fd00:cafe::1 interface=bridge managed-address-configuration=yes other-configuration=yes
add dns=fd00:cafe:80::1 interface=vlan80-guest managed-address-configuration=yes other-configuration=yes
/ipv6 nd prefix
add autonomous=no interface=bridge prefix=fd00:cafe::/64
add interface=vlan80-guest prefix=fd00:cafe:80::/64
/system clock
set time-zone-name=Europe/Amsterdam
/system identity
set name=RB5009UPr
/system logging
add topics=dhcp,debug
/system script
add dont-require-permissions=no name=dynamic-wan-nat-address-list owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=":local interfaceName \
    \"pppoe-kpn\";\
    \n:local addressListName \"ipv4-wan\";\
    \n:local comment \"WAN IP\"\
    \n\
    \n:local wanIP [/ip address get [find interface=\$interfaceName] address];\
    \n/ip firewall address-list remove [find list=\$addressListName dynamic=yes];\
    \n\
    \n:if ([:len [/ip firewall address-list find list=\$addressListName dynamic=yes]] = 0) do={\
    \n    /ip firewall address-list add list=\$addressListName address=\$wanIP comment=\$comment dynamic=yes;\
    \n} else={\
    \n    /ip firewall address-list set [find list=\$addressListName dynamic=yes] address=\$wanIP comment=\$comment;\
    \n}"
add dont-require-permissions=no name=dhcp-to-dns owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="# SPDX-License-Identifier: CC0-1.0\
    \n# DHCP to DNS synchronization script\
    \n# Handles multiple host addresses using MAC address tracking\
    \n# Author: SoupGlasses\
    \n# Version: 2.2.0\
    \n\
    \n:local domains [:toarray \"home.arpa\"]\
    \n:local dnsttl \"10m\"\
    \n:local magiccommentbase \"from-dhcp\"\
    \n\
    \n# Track active MAC addresses for the cleanup process.\
    \n:local activemacs [:toarray \"\"]\
    \n\
    \n# Process phase:\
    \n:foreach lease in [/ip dhcp-server lease find] do={\
    \n  :local hostname [/ip dhcp-server lease get value-name=host-name \$lease]\
    \n  :local hostaddr [/ip dhcp-server lease get value-name=address \$lease]\
    \n  :local hostmac [/ip dhcp-server lease get value-name=mac-address \$lease]\
    \n\
    \n  # Only process leases with a valid hostname and MAC.\
    \n  :if ([:len \$hostname] > 0 && [:len \$hostmac] > 0) do={\
    \n    :local magiccomment \"\$magiccommentbase (\$hostmac)\"\
    \n    :set activemacs (\$activemacs, \$hostmac)\
    \n\
    \n    :foreach domain in \$domains do={\
    \n      :local fqdn \"\$hostname.\$domain\"\
    \n\
    \n      :local existingentry [/ip dns static find where name=\$fqdn comment=\$magiccomment]\
    \n\
    \n      :if ([:len \$existingentry] = 0) do={\
    \n        :do {\
    \n          :log info \"DNS: Adding \$fqdn -> \$hostaddr (\$hostmac)\"\
    \n          /ip dns static add name=\$fqdn address=\$hostaddr comment=\$magiccomment ttl=\$dnsttl\
    \n        } on-error={\
    \n          :log warning \"DNS: Failed to add \$fqdn -> \$hostaddr (\$hostmac) - entry already exists\"\
    \n        }\
    \n      } else={\
    \n        :local currentaddr \"\"\
    \n        :do {\
    \n          :set currentaddr [/ip dns static get value-name=address [:pick \$existingentry 0]]\
    \n        } on-error={\
    \n          :set currentaddr \"\"\
    \n        }\
    \n\
    \n        :if (\$currentaddr != \$hostaddr) do={\
    \n          :log info \"DNS: Updating \$fqdn: \$currentaddr -> \$hostaddr (\$hostmac)\"\
    \n          /ip dns static set address=\$hostaddr [:pick \$existingentry 0]\
    \n        } else={\
    \n          # Entry is already correct, simply continue.\
    \n        }\
    \n      }\
    \n    }\
    \n  }\
    \n}\
    \n\
    \n# Cleanup phase:\
    \n:foreach dnsentry in [/ip dns static find where comment~\"^\$magiccommentbase \\\\(\"] do={\
    \n  :local entrycomment [/ip dns static get value-name=comment \$dnsentry]\
    \n  :local entryname [/ip dns static get value-name=name \$dnsentry]\
    \n\
    \n  :local macstart ([:find \$entrycomment \"(\"] + 1)\
    \n  :local macend [:find \$entrycomment \")\" \$macstart]\
    \n\
    \n  :if (\$macstart > 0 && \$macend > \$macstart) do={\
    \n    :local extractedmac [:pick \$entrycomment \$macstart \$macend]\
    \n\
    \n    :if ([:type [:find \$activemacs \$extractedmac]] = \"nil\") do={\
    \n      :log info \"DNS: Removing stale entry \$entryname (\$extractedmac)\"\
    \n      /ip dns static remove \$dnsentry\
    \n    }\
    \n  } else={\
    \n    :log warning \"DNS: Found entry with malformed comment: \$entryname - \$entrycomment\"\
    \n  }\
    \n}"
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
