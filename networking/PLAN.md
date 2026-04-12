# Network Segmentation Plan: 3-VLAN Setup

## Context

The home network currently has 3 VLANs (LAN/Guest/IoT) but device placement is inconsistent and the firewall rules need cleanup. This plan restructures into a clean 3-VLAN segmentation: **Trusted**, **Untrusted** (replaces Guest), and **IoT** with client isolation.

## Target Architecture

| Segment | VLAN ID | Subnet (IPv4) | Subnet (IPv6 ULA) | Subnet (IPv6 GUA) | Purpose |
|---------|---------|---------------|--------------------|--------------------|---------|
| **Trusted** | 1 (PVID, untagged) | 10.0.0.0/16 | fd00:cafe::/64 | 2a02:a469:9060::/64 | Servers, APs, switches, admin devices. Full access to all segments. |
| **Untrusted** | 80 | 10.80.0.0/24 | fd00:cafe:80::/64 | 2a02:a469:9060:1::/64 | Phones, TVs, guests, personal devices. Internet only. |
| **IoT** | 90 | 10.90.0.0/24 | fd00:cafe:90::/64 | None (ULA only) | All IoT devices. Client isolation via firewall. Per-device internet allow/deny. |

### Design Decisions

- **Trusted = existing bridge PVID 1**: Servers keep their current IPs (10.0.1.x, 10.0.2.x, 10.0.3.x). No re-addressing needed.
- **Untrusted = existing VLAN 80 (renamed from Guest)**: Merges guest and personal device segments. Same VLAN ID, just renamed.
- **IoT = existing VLAN 90 (unchanged)**: IoT client isolation enforced via L3 firewall rule (IoT-to-IoT drop). Per-device internet access controlled via address list.
- **CRS310 switch**: Stays as flat L2 (no VLAN filtering). All devices on it are Trusted. Acts as DHCP/DNS fallback for rack resilience (see Phase 0).
- **EAP-245 AP**: Supports VLAN-per-SSID. Does NOT support true L2 client isolation (no ebtables exposed). Client isolation handled at MikroTik firewall.

## Hardware Topology

```
KPN ONT
  └─ ether8 (WAN, PPPoE via VLAN 6)

RB5009 Router (10.0.0.1)
  ├─ ether1 → CRS310 ether1 (trunk: PVID 1 only, all Trusted devices)
  │            ├─ ether2 → nl-pve-02
  │            ├─ ether3 → Desk (admin laptop)
  │            ├─ ether4 → nl-k8s-04
  │            ├─ ether6 → nl-k8s-01
  │            └─ sfp-sfpplus2 → nl-pve-01
  ├─ ether2 → EAP-245 AP (trunk: PVID 1, tagged 80 + 90)
  ├─ ether3 → Bedroom (unused/inactive)
  ├─ ether4 → Living Room wired IoT (PVID 90, untagged)
  ├─ ether5 → NanoPi R5C (PVID 1, tagged 90)
  └─ ether8 → WAN (KPN ONT)
```

## Phase 0: CRS310 DHCP/DNS Fallback (Rack Resilience)

If the RB5009 router goes down (e.g. power cut in the utility closet), the CRS310 switch in the server rack continues L2 switching. However, DHCP leases (30m lifetime) will expire and DNS will stop resolving, breaking intra-cluster communication and causing Longhorn data corruption.

This phase sets up the CRS310 as a DHCP and DNS fallback so the rack stays self-sufficient.

### Current CRS310 State

- **RouterOS 7.18.2**, 256MB RAM, 2-core ARM
- **IP**: 10.0.0.2/16 via DHCP (static lease on router), plus disabled static 10.0.0.5/16
- **No DHCP server** configured
- **DNS**: forwarding to 10.0.0.1 only, `allow-remote-requests=no`

### 0.1 Give CRS310 a static IP

The CRS310 currently gets its IP via DHCP from the router. If the router dies, the CRS310 would eventually lose its own address. Enable its static IP.

```routeros
# On CRS310 (10.0.0.2):
/ip address set [find address="10.0.0.5/16"] address=10.0.0.2/16 interface=bridge disabled=no comment="static fallback address"
/ip dhcp-client set [find] disabled=yes
```

> The DHCP-assigned 10.0.0.2 and the static 10.0.0.2 will coexist briefly. Once the DHCP client is disabled, only the static remains.

### 0.2 Configure DNS forwarder on CRS310

Point the CRS310 directly at upstream DNS (not the router — otherwise it's circular when the router is down).

```routeros
# On CRS310:
/ip dns set servers=1.1.1.1,1.0.0.1 allow-remote-requests=yes
```

### 0.3 Shrink RB5009 DHCP pool (make room for fallback pool)

```routeros
# On RB5009 (10.0.0.1):
/ip pool set [find name=pool-dhcp-v4] ranges=10.0.0.100-10.0.0.199
```

### 0.4 Configure DHCP fallback server on CRS310

```routeros
# On CRS310:
/ip pool add name=pool-dhcp-v4-fallback ranges=10.0.0.200-10.0.0.254
/ip dhcp-server add name=dhcp-v4-fallback interface=bridge address-pool=pool-dhcp-v4-fallback lease-time=1h
/ip dhcp-server network add address=10.0.0.0/16 gateway=10.0.0.1 dns-server=10.0.0.1,10.0.0.2 domain=home.arpa
```

### 0.5 Mirror static leases on CRS310

Server devices must get the same IP regardless of which DHCP server responds.

```routeros
# On CRS310:
/ip dhcp-server lease add address=10.0.1.1  mac-address=6C:1F:F7:57:07:49 server=dhcp-v4-fallback comment="nl-k8s-01"
/ip dhcp-server lease add address=10.0.1.2  mac-address=BC:24:11:A2:94:61 server=dhcp-v4-fallback comment="nl-k8s-02"
/ip dhcp-server lease add address=10.0.1.3  mac-address=BC:24:11:07:69:C7 server=dhcp-v4-fallback comment="nl-k8s-03"
/ip dhcp-server lease add address=10.0.1.4  mac-address=54:E1:AD:A5:1D:0F server=dhcp-v4-fallback comment="nl-k8s-04"
/ip dhcp-server lease add address=10.0.2.1  mac-address=58:47:CA:7F:76:99 server=dhcp-v4-fallback comment="nl-pve-01"
/ip dhcp-server lease add address=10.0.2.2  mac-address=98:FA:9B:13:C8:E8 server=dhcp-v4-fallback comment="nl-pve-02"
/ip dhcp-server lease add address=10.0.1.20 mac-address=BC:24:11:DE:69:E3 server=dhcp-v4-fallback comment="nl-pve-01 TrueNAS"
```

### 0.6 Update RB5009 DHCP network to hand out both DNS servers

```routeros
# On RB5009:
/ip dhcp-server network set [find comment="defconf"] dns-server=10.0.0.1,10.0.0.2
```

### 0.7 Terraform: Single source of truth for lease mirroring

To avoid maintaining leases in two places, manage both devices from Terraform. The existing Terragrunt setup uses:
- `root.hcl` — generates Kubernetes backend (secret_suffix = directory name)
- `routeros.hcl` — generates provider config + variables
- Per-device `terragrunt.hcl` — includes both, decrypts SOPS secrets, passes inputs

#### Shared lease definitions

Create a shared file that both device configs reference. Two approaches:

**Approach A: Shared Terragrunt variable (recommended)**

Create `networking/leases.hcl` with the shared lease map, included by both device configs:

```hcl
# networking/leases.hcl
locals {
  # Static DHCP leases mirrored on both RB5009 and CRS310.
  # Single source of truth — edit here, apply to both devices.
  trusted_leases = {
    "6C:1F:F7:57:07:49" = { addr = "10.0.1.1",  comment = "nl-k8s-01" }
    "BC:24:11:A2:94:61" = { addr = "10.0.1.2",  comment = "nl-k8s-02" }
    "BC:24:11:07:69:C7" = { addr = "10.0.1.3",  comment = "nl-k8s-03" }
    "54:E1:AD:A5:1D:0F" = { addr = "10.0.1.4",  comment = "nl-k8s-04" }
    "58:47:CA:7F:76:99" = { addr = "10.0.2.1",  comment = "nl-pve-01" }
    "98:FA:9B:13:C8:E8" = { addr = "10.0.2.2",  comment = "nl-pve-02" }
    "BC:24:11:DE:69:E3" = { addr = "10.0.1.20", comment = "nl-pve-01 TrueNAS" }
  }
}
```

Then in each device's `terragrunt.hcl`:

```hcl
# networking/rb5009upr/terragrunt.hcl
include "leases" {
  path   = find_in_parent_folders("leases.hcl")
  expose = true
}

inputs = {
  # ...existing inputs...
  trusted_leases = include.leases.locals.trusted_leases
}
```

```hcl
# networking/crs310-8g-2s/terragrunt.hcl
include "leases" {
  path   = find_in_parent_folders("leases.hcl")
  expose = true
}

inputs = {
  # ...existing inputs...
  trusted_leases = include.leases.locals.trusted_leases
}
```

Then in each device's Terraform:

```hcl
# In both rb5009upr/*.tf and crs310-8g-2s/*.tf:
variable "trusted_leases" {
  type = map(object({
    addr    = string
    comment = string
  }))
}

resource "routeros_ip_dhcp_server_lease" "trusted" {
  for_each    = var.trusted_leases
  address     = each.value.addr
  mac_address = each.key
  server      = "<device-specific-server-name>"  # "defconf" on RB5009, "dhcp-v4-fallback" on CRS310
  comment     = each.value.comment
}
```

#### CRS310 Terragrunt setup

Create the CRS310 Terraform config at `networking/crs310-8g-2s/`:

```hcl
# networking/crs310-8g-2s/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "routeros" {
  path = find_in_parent_folders("routeros.hcl")
}

include "leases" {
  path   = find_in_parent_folders("leases.hcl")
  expose = true
}

locals {
  secrets = yamldecode(sops_decrypt_file("secrets.yaml"))
}

inputs = {
  routeros_hosturl  = local.secrets.routeros_hosturl   # https://10.0.0.2 (or API URL)
  routeros_username = local.secrets.routeros_username
  routeros_password = local.secrets.routeros_password
  trusted_leases    = include.leases.locals.trusted_leases
}
```

### 0.8 Failure scenario summary

| Scenario | DHCP | DNS | Intra-rack L3 |
|----------|------|-----|---------------|
| **Everything up** | Router responds (fast), switch also responds | Router (primary), switch (secondary) | Works via switch |
| **Router down** | Switch responds from fallback pool; static-leased servers keep same IPs | Switch forwards to Cloudflare (few sec delay on first query per client) | Works via switch |
| **Switch down** | Router responds normally | Router | Broken — servers lose L2 connectivity |
| **Both down** | Nothing | Nothing | Nothing |

## Phase 1: Rename Guest → Untrusted

Non-disruptive renaming of existing resources. No connectivity impact.

### 1.1 Rename VLAN interface

```routeros
/interface vlan set [find name=vlan80-guest] name=vlan80-untrusted comment="untrusted network"
```

### 1.2 Rename interface list

```routeros
/interface list set [find name=GUEST] name=UNTRUSTED comment="untrusted network"
```

> Note: Interface list members and firewall rules referencing the list name update automatically when the list is renamed.

### 1.3 Rename IPv4 resources

```routeros
/ip address set [find comment="guest network"] comment="untrusted network"
/ip pool set [find name=pool-dhcp-v4-guest] name=pool-dhcp-v4-untrusted
/ip dhcp-server set [find name=dhcp-v4-guest] name=dhcp-v4-untrusted
/ip dhcp-server network set [find comment="guest network"] comment="untrusted network"
```

### 1.4 Rename IPv6 resources

```routeros
/ipv6 pool set [find name=pool-dhcp-v6-ula-guest] name=pool-dhcp-v6-ula-untrusted comment="untrusted: DHCPv6 ULA pool"
/ipv6 dhcp-server set [find name=dhcp-v6-ula-guest] name=dhcp-v6-ula-untrusted comment="untrusted: DHCPv6 ULA server"
```

### 1.5 Update firewall rule comments

```routeros
# IPv4
/ip firewall filter set [find comment="allow guest DNS/DHCP"] comment="untrusted: allow DNS/DHCP"
/ip firewall filter set [find comment="allow guest to internet"] comment="untrusted: allow internet"
/ip firewall filter set [find comment="allow guest to k8s ingress"] comment="untrusted: allow k8s ingress"
/ip firewall filter set [find comment="block guest to LAN"] comment="untrusted: block to LAN"
/ip firewall filter set [find comment="drop guest to router traffic"] comment="untrusted: drop non-DNS/DHCP to router"
/ip firewall filter set [find comment="guest: allow LAN to GUEST"] comment="untrusted: allow LAN to UNTRUSTED"

# IPv6
/ipv6 firewall filter set [find comment="guest: allow DNS/DHCPv6 to router"] comment="untrusted: allow DNS/DHCPv6 to router"
/ipv6 firewall filter set [find comment="guest: allow DNS TCP to router"] comment="untrusted: allow DNS TCP to router"
/ipv6 firewall filter set [find comment="guest: allow WAN outbound"] comment="untrusted: allow WAN outbound"
/ipv6 firewall filter set [find comment="guest: allow LAN to GUEST (v6)"] comment="untrusted: allow LAN to UNTRUSTED (v6)"
/ipv6 firewall filter set [find comment="guest: RA guard for non-router devices"] comment="untrusted: RA guard for non-router devices"
```

### 1.6 Update ND prefix comments (if applicable)

ND references the interface name, so these auto-update when the VLAN interface is renamed.

## Phase 2: IPv4 Firewall Restructure

Replace the current firewall rules with a clean, correctly-ordered ruleset.

### 2.1 Current IPv4 firewall issues

- Guest-specific rules are scattered (rules 5, 16-19, 25)
- No explicit UNTRUSTED → IOT drop
- No IoT-to-IoT isolation rule
- No per-device IoT internet allowlist
- Input drop for guest (rule 19) comes AFTER the general !LAN drop (rule 6), making it dead

### 2.2 Target IPv4 input chain

```routeros
# Clear and rebuild input chain
/ip firewall filter

# --- INPUT CHAIN ---
# Rule 1: accept established,related,untracked
add chain=input action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"

# Rule 2: drop invalid
add chain=input action=drop connection-state=invalid comment="defconf: drop invalid"

# Rule 3: accept ICMP
add chain=input action=accept protocol=icmp comment="defconf: accept ICMP"

# Rule 4: accept loopback
add chain=input action=accept dst-address=127.0.0.1 comment="defconf: accept to local loopback (for CAPsMAN)"

# Rule 5: allow UNTRUSTED DNS/DHCP
add chain=input action=accept protocol=udp in-interface-list=UNTRUSTED dst-port=53,67 comment="untrusted: allow DNS/DHCP"

# Rule 6: allow IOT DNS/DHCP (UDP)
add chain=input action=accept protocol=udp in-interface-list=IOT dst-port=53,67 comment="iot: allow DNS/DHCP"

# Rule 7: allow IOT DNS (TCP)
add chain=input action=accept protocol=tcp in-interface-list=IOT dst-port=53 comment="iot: allow DNS TCP"

# Rule 8: allow UNTRUSTED DNS (TCP) -- needed for DNSSEC/large responses
add chain=input action=accept protocol=tcp in-interface-list=UNTRUSTED dst-port=53 comment="untrusted: allow DNS TCP"

# Rule 9: drop all input not from LAN
add chain=input action=drop in-interface-list=!LAN comment="defconf: drop all not coming from LAN"
```

### 2.3 Target IPv4 forward chain

```routeros
# --- FORWARD CHAIN ---
# Rule F0: (dynamic) fasttrack counters passthrough

# Rule F1: fasttrack established,related
add chain=forward action=fasttrack-connection connection-state=established,related hw-offload=yes comment="defconf: fasttrack"

# Rule F2: accept established,related,untracked
add chain=forward action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"

# Rule F3: drop invalid
add chain=forward action=drop connection-state=invalid comment="defconf: drop invalid"

# Rule F4: accept ipsec in
add chain=forward action=accept ipsec-policy=in,ipsec comment="defconf: accept in ipsec policy"

# Rule F5: accept ipsec out
add chain=forward action=accept ipsec-policy=out,ipsec comment="defconf: accept out ipsec policy"

# --- Port forwards from WAN ---
# Rule F6: accept port forward to k8s ingress
add chain=forward action=accept connection-state=new protocol=tcp dst-address-list=ipv4-k8s-ingress-controller in-interface-list=WAN dst-port=80,443 comment="wan: allow port forward to k8s ingress"

# Rule F7: accept port forward to slskd
add chain=forward action=accept protocol=tcp dst-address-list=ipv4-slskd in-interface-list=WAN dst-port=50429 comment="wan: allow port forward to slskd"

# Rule F8: accept port forward to qbittorrent
add chain=forward action=accept protocol=tcp dst-address-list=ipv4-qbittorrent in-interface-list=WAN dst-port=30963 comment="wan: allow port forward to qbittorrent"

# Rule F9: drop WAN not DSTNATed
add chain=forward action=drop connection-state=new connection-nat-state=!dstnat in-interface-list=WAN comment="defconf: drop all from WAN not DSTNATed"

# --- Trusted (LAN) outbound ---
# Rule F10: LAN → UNTRUSTED
add chain=forward action=accept in-interface-list=LAN out-interface-list=UNTRUSTED comment="trusted: allow LAN to UNTRUSTED"

# Rule F11: LAN → IOT
add chain=forward action=accept in-interface-list=LAN out-interface-list=IOT comment="trusted: allow LAN to IOT"

# --- Untrusted rules ---
# Rule F12: UNTRUSTED → WAN (internet)
add chain=forward action=accept in-interface-list=UNTRUSTED out-interface-list=WAN comment="untrusted: allow internet"

# Rule F13: UNTRUSTED → k8s ingress (for accessing self-hosted services)
add chain=forward action=accept protocol=tcp dst-address-list=ipv4-k8s-ingress-controller in-interface-list=UNTRUSTED dst-port=80,443 comment="untrusted: allow k8s ingress"

# Rule F14: drop UNTRUSTED → LAN
add chain=forward action=drop in-interface-list=UNTRUSTED out-interface-list=LAN comment="untrusted: block to LAN"

# Rule F15: drop UNTRUSTED → IOT
add chain=forward action=drop in-interface-list=UNTRUSTED out-interface-list=IOT comment="untrusted: block to IOT"

# --- IoT rules ---
# Rule F16: drop IoT-to-IoT (client isolation)
add chain=forward action=drop src-address=10.90.0.0/24 dst-address=10.90.0.0/24 comment="iot: block IoT-to-IoT (client isolation)"

# Rule F17: allow IoT with internet permission → WAN
add chain=forward action=accept src-address-list=iot-internet-allowed in-interface-list=IOT out-interface-list=WAN comment="iot: allow internet for permitted devices"

# Rule F18: drop IOT → LAN
add chain=forward action=drop in-interface-list=IOT out-interface-list=LAN comment="iot: block to LAN"

# Rule F19: drop IOT → WAN (default deny internet)
add chain=forward action=drop in-interface-list=IOT out-interface-list=WAN comment="iot: block internet (default)"
```

### 2.4 IoT internet allow list

Create the address list for IoT devices that need cloud access. Populate later with specific IPs.

```routeros
# Create the address list (empty for now, add devices as needed)
# Example:
# /ip firewall address-list add list=iot-internet-allowed address=10.90.0.X comment="Litter Robot"
```

### 2.5 NAT rules

NAT rules stay unchanged:
- srcnat masquerade on WAN (rule 0)
- dstnat bypass for router mgmt (rule 1)
- dstnat port forwards for k8s ingress, slskd, qbittorrent (rules 2-5)
- hairpin NAT for k8s ingress (rules 6-7)

## Phase 3: IPv6 Firewall Restructure

### 3.1 Current IPv6 firewall issues

- Rules 30-33 (IoT/Guest specific forward rules) come AFTER the catch-all `!LAN` drop at rule 29, making them dead/unreachable
- No UNTRUSTED → IOT drop
- No IoT-to-IoT isolation
- Missing explicit inter-VLAN drop rules

### 3.2 Target IPv6 input chain

```routeros
/ipv6 firewall filter

# --- INPUT CHAIN ---
add chain=input action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"
add chain=input action=drop connection-state=invalid comment="defconf: drop invalid"
add chain=input action=accept protocol=icmpv6 comment="defconf: accept ICMPv6"
add chain=input action=accept protocol=udp dst-port=33434-33534 comment="defconf: accept UDP traceroute"
add chain=input action=accept protocol=udp src-address=fe80::/10 dst-port=546 comment="defconf: accept DHCPv6-Client prefix delegation"
add chain=input action=accept protocol=udp dst-port=500,4500 comment="defconf: accept IKE"
add chain=input action=accept protocol=ipsec-ah comment="defconf: accept ipsec AH"
add chain=input action=accept protocol=ipsec-esp comment="defconf: accept ipsec ESP"
add chain=input action=accept ipsec-policy=in,ipsec comment="defconf: accept all that matches ipsec policy"

# UNTRUSTED DNS/DHCPv6
add chain=input action=accept protocol=udp in-interface-list=UNTRUSTED dst-port=53,547 comment="untrusted: allow DNS/DHCPv6"
add chain=input action=accept protocol=tcp in-interface-list=UNTRUSTED dst-port=53 comment="untrusted: allow DNS TCP"

# IOT DNS/DHCPv6
add chain=input action=accept protocol=udp in-interface-list=IOT dst-port=53,547 comment="iot: allow DNS/DHCPv6"
add chain=input action=accept protocol=tcp in-interface-list=IOT dst-port=53 comment="iot: allow DNS TCP"

# Drop everything else
add chain=input action=drop in-interface-list=!LAN comment="defconf: drop everything else not coming from LAN"
```

### 3.3 Target IPv6 forward chain

```routeros
# --- FORWARD CHAIN ---
# (dynamic) fasttrack6 counters passthrough

add chain=forward action=fasttrack-connection connection-state=established,related comment="defconf: fasttrack6"
add chain=forward action=accept connection-state=established,related,untracked comment="defconf: accept established,related,untracked"
add chain=forward action=drop connection-state=invalid comment="defconf: drop invalid"
add chain=forward action=drop src-address-list=bad_ipv6 comment="defconf: drop packets with bad src ipv6"
add chain=forward action=drop dst-address-list=bad_ipv6 comment="defconf: drop packets with bad dst ipv6"
add chain=forward action=drop protocol=icmpv6 hop-limit=equal:1 comment="defconf: rfc4890 drop hop-limit=1"
add chain=forward action=accept protocol=icmpv6 comment="defconf: accept ICMPv6"
add chain=forward action=accept protocol=139 comment="defconf: accept HIP"
add chain=forward action=accept protocol=udp dst-port=500,4500 comment="defconf: accept IKE"
add chain=forward action=accept protocol=ipsec-ah comment="defconf: accept ipsec AH"
add chain=forward action=accept protocol=ipsec-esp comment="defconf: accept ipsec ESP"
add chain=forward action=accept ipsec-policy=in,ipsec comment="defconf: accept all that matches ipsec policy"

# --- Trusted (LAN) outbound ---
add chain=forward action=accept in-interface-list=LAN out-interface-list=WAN comment="trusted: allow LAN to WAN"
add chain=forward action=accept in-interface-list=LAN out-interface-list=UNTRUSTED comment="trusted: allow LAN to UNTRUSTED"
add chain=forward action=accept in-interface-list=LAN out-interface-list=IOT comment="trusted: allow LAN to IOT"

# --- Untrusted rules ---
add chain=forward action=accept in-interface-list=UNTRUSTED out-interface-list=WAN comment="untrusted: allow internet"
add chain=forward action=drop in-interface-list=UNTRUSTED out-interface-list=LAN comment="untrusted: block to LAN"
add chain=forward action=drop in-interface-list=UNTRUSTED out-interface-list=IOT comment="untrusted: block to IOT"

# --- IoT rules ---
add chain=forward action=drop src-address=fd00:cafe:90::/64 dst-address=fd00:cafe:90::/64 comment="iot: block IoT-to-IoT (client isolation)"
# Future: add chain=forward action=accept src-address-list=iot-internet-allowed-v6 in-interface-list=IOT out-interface-list=WAN comment="iot: allow internet for permitted devices"
add chain=forward action=drop in-interface-list=IOT out-interface-list=LAN comment="iot: block to LAN"
add chain=forward action=drop in-interface-list=IOT out-interface-list=WAN comment="iot: block internet (default)"

# --- RA guard (prevent rogue RAs from non-router devices) ---
add chain=forward action=drop protocol=icmpv6 in-interface-list=LAN icmp-options=134:0 comment="lan: RA guard"
add chain=forward action=drop protocol=icmpv6 in-interface-list=UNTRUSTED icmp-options=134:0 comment="untrusted: RA guard"
add chain=forward action=drop protocol=icmpv6 in-interface-list=IOT icmp-options=134:0 comment="iot: RA guard"

# --- Catch-all (MOVED TO END) ---
add chain=forward action=drop in-interface-list=!LAN comment="defconf: drop everything else"
```

## Phase 4: Device Migration (DHCP Leases)

### 4.1 Devices to move to IoT VLAN (10.90.0.0/24)

These devices need their static DHCP leases moved from the `defconf` (LAN) server to `dhcp-v4-iot`, and need to be reconfigured to connect to the IoT Wi-Fi SSID.

| Device | Current IP | New IP (IoT) | MAC |
|--------|-----------|--------------|-----|
| Xiaomi Vacuum | 10.0.0.151 | 10.90.0.20 | 70:C9:32:F5:30:DB |
| ESP32 BT Proxy | 10.0.0.155 | 10.90.0.21 | B4:E6:2D:EF:64:C5 |
| Google Home Mini | 10.0.0.12 | 10.90.0.22 | 44:07:0B:90:CE:B6 |

```routeros
# Remove old leases
/ip dhcp-server lease remove [find mac-address=70:C9:32:F5:30:DB]
/ip dhcp-server lease remove [find mac-address=B4:E6:2D:EF:64:C5]
/ip dhcp-server lease remove [find mac-address=44:07:0B:90:CE:B6]

# Add new IoT leases
/ip dhcp-server lease add address=10.90.0.20 mac-address=70:C9:32:F5:30:DB server=dhcp-v4-iot comment="Xiaomi Vacuum"
/ip dhcp-server lease add address=10.90.0.21 mac-address=B4:E6:2D:EF:64:C5 server=dhcp-v4-iot comment="ESP32 BT Proxy"
/ip dhcp-server lease add address=10.90.0.22 mac-address=44:07:0B:90:CE:B6 server=dhcp-v4-iot comment="Google Home Mini"
```

### 4.2 Devices to move to Untrusted VLAN (10.80.0.0/24)

The LG TV is already on VLAN 80 (10.80.0.249) — no change needed.

The Litter Robot is also already on VLAN 80 (10.80.0.251, dynamic) — it should stay here or move to IoT depending on whether it needs cloud access. **Decision needed: should Litter Robot go to IoT?** If so, it needs an `iot-internet-allowed` entry.

### 4.3 Stale leases to clean up

Remove static leases for decommissioned devices:
- ASUS AP (10.0.0.4) — decommissioned
- NanoPi R5C Slimmelezer lease on LAN (10.0.0.11, if exists) — already on IoT

## Phase 5: EAP-245 SSID Configuration (Manual)

This must be done manually through the EAP-245 standalone web UI (http://10.0.0.3).

### 5.1 Target SSIDs

| SSID Name | Band | VLAN ID | Purpose |
|-----------|------|---------|---------|
| (your trusted SSID) | 2.4 + 5 GHz | 0 (untagged) | Admin laptop, trusted wireless devices |
| (your untrusted SSID) | 2.4 + 5 GHz | 80 | Phones, TV, guests |
| (your IoT SSID) | 2.4 GHz only | 90 | IoT devices (most are 2.4 GHz only) |

### 5.2 Configuration steps

1. Log into EAP-245 web UI at http://10.0.0.3
2. Go to **Wireless > Wireless Settings**
3. For each band (2.4 GHz, 5 GHz):
   - Edit or create SSIDs
   - Set **Wireless VLAN ID** for each SSID (0 for trusted, 80 for untrusted, 90 for IoT)
4. For the IoT SSID: consider enabling the **Guest Network** feature (blocks inter-client L3 on same AP — partial client isolation, better than nothing)
5. For the Untrusted SSID: do NOT enable Guest Network (phones need to cast to TV on same VLAN)

### 5.3 Important notes

- The RB5009 ether2 port is already configured as a trunk carrying PVID 1 + tagged 80 + 90 — no switch changes needed
- After changing SSIDs, devices will need to reconnect to the correct SSID
- The EAP-245 management interface stays on VLAN 1 (Trusted) by default

## Phase 6: IoT Internet Allow List (Populate Later)

Create the address list and add devices as the user specifies:

```routeros
/ip firewall address-list add list=iot-internet-allowed address=<IP> comment="<device name>"
```

Candidate devices that likely need internet:
- Litter Robot (if moved to IoT)
- Xiaomi Vacuum (cloud features)
- Google Home Mini (requires internet)

Devices that should remain airgapped:
- Slimmelezer (P1 meter reader, local only)
- E1-Zoom cameras (local only)
- Bambu Lab P1S (can work local-only via LAN mode)
- ESP32 BT Proxy (local ESPHome device)

## Verification Checklist

### Phase 0 (rack resilience)

- [ ] CRS310 has static IP 10.0.0.2 (`/ip address print` — no DHCP client)
- [ ] CRS310 DNS resolves external names (`/tool dns-query name=google.com server=10.0.0.2` from RB5009)
- [ ] CRS310 DHCP server is running (`/ip dhcp-server print` on CRS310)
- [ ] Static leases match on both devices (compare `/ip dhcp-server lease print` on both)
- [ ] RB5009 DHCP network hands out DNS `10.0.0.1,10.0.0.2`
- [ ] **Simulate router outage**: disable RB5009 DHCP server, verify a server still gets correct IP from CRS310
- [ ] **Simulate router outage**: verify DNS resolution works via 10.0.0.2 from a server

### Segmentation

- [ ] Trusted device (admin laptop on LAN) can reach all VLANs
- [ ] Trusted device has IPv4 + IPv6 internet
- [ ] Untrusted device (phone on VLAN 80) has IPv4 + IPv6 internet
- [ ] Untrusted device CANNOT ping 10.0.0.1 (router mgmt) — wait, it needs DNS. Verify it can do DNS (udp/tcp 53) and DHCP (udp 67) but nothing else to the router
- [ ] Untrusted device CANNOT reach 10.0.1.x (servers)
- [ ] Untrusted device CANNOT reach 10.90.0.x (IoT)
- [ ] Untrusted device CAN reach k8s ingress (10.0.3.1:80, 10.0.3.1:443)
- [ ] IoT device with internet permission can reach the internet
- [ ] IoT device without internet permission CANNOT reach the internet
- [ ] IoT device CANNOT reach 10.0.x.x (trusted)
- [ ] IoT device CANNOT reach 10.80.0.x (untrusted)
- [ ] IoT device CANNOT reach other IoT devices (10.90.0.x → 10.90.0.x blocked)
- [ ] Trusted device CAN reach IoT devices (for Home Assistant)
- [ ] Port forwards from WAN still work (k8s ingress, slskd, qbittorrent)
- [ ] IPv6 prefix delegation still works (check `/ipv6 dhcp-client print`)
- [ ] All DHCP servers operational (`/ip dhcp-server print`)
- [ ] No unexpected traffic in firewall logs

## Rollback Plan

If things go wrong during firewall restructure:

1. SSH into router from a Trusted wired device (always on PVID 1, unaffected by firewall changes)
2. Reset firewall to defaults: `/ip firewall filter remove [find]` then re-add default rules
3. Or use MikroTik safe mode: start changes with `/system safe-mode`, if disconnected, changes auto-revert after timeout
