# Network Segmentation and VLAN Architecture

## Context and Problem Statement

The homelab network currently operates on a flat architecture with limited segmentation. As the infrastructure grows to include Kubernetes clusters, Proxmox hypervisors, IoT devices, and guest access, there's a need for proper network segmentation to improve security, manageability, and operational clarity.

Key challenges:
- How to segment different device classes (infrastructure, trusted devices, IoT, guests) while maintaining operational simplicity?
- How to implement secure firewall policies without creating configuration complexity?
- How to balance security isolation with practical access requirements?
- How to design the network to be resilient and easy to manage as nodes are added or moved?

## Decision Drivers

- **Security**: Isolate untrusted devices (IoT, guests) from critical infrastructure
- **Operational Clarity**: Easy identification of device roles by IP address
- **Manageability**: DHCP-based configuration to avoid static IP complexity on nodes
- **Performance**: Efficient inter-VLAN routing without bottlenecks
- **Resilience**: Homelab connectivity should survive router failures in utility closet
- **Future Growth**: Support for 10GbE fiber uplink between utility closet and office
- **Hardware Constraints**: Limited budget, existing 2-port router (r5c), PoE requirements for AP and cameras

## Considered Options

1. **Flat Network (Current State)** - Single subnet, minimal segmentation
2. **3-VLAN Design** - Merge all infrastructure (K8s + Proxmox + VMs), separate trusted/guest
3. **6-VLAN Design** - Full segmentation with dedicated VLANs for each service class
4. **Hybrid Approach** - Use VLANs for physical segmentation + firewall groups for logical segmentation

## Decision Outcome

Chosen option: **"Simplified 4-Zone Design"**, because it balances security, performance, and operational simplicity. After evaluating 10GbE networking requirements, consolidating infrastructure into a single high-performance zone eliminates routing bottlenecks while maintaining clear security boundaries.

### Network Zones

| Zone        | Network      | Purpose                                                                    | Link                          |
| ----------- | ------------ | -------------------------------------------------------------------------- | ----------------------------- |
| `trusted`   | 10.0.0.0/16  | General LAN devices (phones, tablets, printers, general devices)           | 1 GbE                         |
| `infra`     | 10.10.0.0/16 | High-performance infrastructure (K8s, Proxmox, VMs, storage, workstations) | 1GbE (management), 2.5/10 GbE |
| `untrusted` | 10.80.0.0/16 | Cloud-first IoT devices, guest network (internet-only, isolated)           | 1 GbE                         |
| `local`     | 10.90.0.0/16 | Local-only IoT (3D printers, smart lights, no internet access)             | 1 GbE                         |

### Infra Zone (10.10.0.0/16) Detailed Allocation

Infrastructure devices are organized into /24 subnets for future flexibility while maintaining a single firewall zone for optimal 10G performance.

All devices within 10.10.0.0/16 can communicate at full 10G speeds without router involvement, regardless of /24 subnet boundaries. The /24 organization is logical only and can be converted to VLANs later if needed.

| Subnet        | Purpose                     | Address Range   | Example Assignments                                               |
| ------------- | --------------------------- | --------------- | ----------------------------------------------------------------- |
| 10.10.0.0/24  | Kubernetes nodes            | .0.1 - .0.254   | .0.1=vmbr1 gateway, .0.2=nl-k8s-01, .0.4=nl-k8s-02, .0.10=TrueNAS |
| 10.10.1.0/24  | MetalLB LoadBalancer pool   | .1.0 - .1.254   | 254 IPs for K8s LoadBalancer services                             |
| 10.10.10.0/24 | Proxmox hosts               | .10.1 - .10.20  | .10.1=nl-pve-01, .10.2=nl-pve-02                                  |
| 10.10.11.0/24 | Proxmox VMs (non-K8s)       | .11.1 - .11.100 | Database VMs, application VMs, storage VMs                        |
| 10.10.20.0/24 | Infrastructure workstations | .20.1 - .20.50  | .20.10=laptop-1, .20.11=laptop-2                                  |

**Rationale:**
- **10.10.0.0/24 for K8s nodes:** Preserves existing cluster configuration (nl-k8s-01=.0.2, nl-k8s-02=.0.4, TrueNAS=.0.10) to avoid cluster rebuild
- **10.10.1.0/24 for MetalLB:** Adjacent to K8s nodes subnet for logical grouping, provides 254 LoadBalancer IPs
- **10.10.11.x for VMs:** Adjacent to Proxmox hosts for logical association

### Firewall Policy Matrix

| Source    | Destination | Policy            | Justification                                      |
| --------- | ----------- | ----------------- | -------------------------------------------------- |
| Trusted   | Infra       | Allow             | Administrators need full access to infrastructure  |
| Trusted   | Untrusted   | Allow             | Can manage IoT devices                             |
| Trusted   | Local       | Allow             | Can manage local IoT                               |
| Trusted   | WAN         | Allow             | Internet access                                    |
| Infra     | Infra       | Allow             | All infra devices trust each other @ 10G speeds    |
| Infra     | Trusted     | Allow established | Reply to requests from trusted zone                |
| Infra     | Local       | Allow             | K8s/VMs can control local IoT devices              |
| Infra     | WAN         | Allow             | Updates, external APIs, image pulls                |
| Infra     | Untrusted   | Deny              | Infrastructure should not access untrusted devices |
| Untrusted | WAN         | Allow             | Internet-only access (cloud IoT, guests)           |
| Untrusted | All else    | Deny              | Complete isolation from internal networks          |
| Local     | Infra       | Allow             | Local IoT can be controlled by K8s services        |
| Local     | Trusted     | Allow established | Reply to management requests                       |
| Local     | WAN         | Deny              | No internet access by design                       |
| Local     | Untrusted   | Deny              | Isolation from untrusted devices                   |

**Key Design Principles:**
- **Infra zone is a single firewall zone:** All devices in 10.10.0.0/16 can communicate freely without firewall inspection, enabling 10G performance
- **Trusted manages everything:** Admin zone can access all networks for management and troubleshooting
- **Untrusted is isolated:** Guest and cloud IoT devices have no access to internal networks
- **Local is controlled:** LAN-only IoT can be managed from trusted and controlled by infra services

### IP Address Management Strategy

**Static Leases (Primary Method):**
- All infrastructure devices use DHCP with MAC-based reservations
- Organized by /24 subnets within 10.10.0.0/16 for clear categorization
- Benefit: Predictable IPs without manual configuration on each device
- Configuration: Maintained on router DHCP server

**Migration from Old Scheme:**
- Old: Separate /16 subnets for K8s (10.10), Proxmox (10.11), VMs (10.12), MetalLB (10.20)
- New: Consolidated into 10.10.0.0/16 with /24 logical groupings
- Benefit: All infra traffic stays within single subnet = no router hairpin = full 10G performance

### Hardware Architecture

**Utility Closet:**
- Router r5c (existing): Handles WAN, inter-zone routing, firewall, DHCP
- Managed PoE Switch (new): 8-port GbE with PoE+ (for AP and cameras) and 10GbE uplink (either RJ45, SFP+ or both)
- Connection: Router LAN → Switch, Switch → Office via CAT6 (< 20m)

**Office (High-Performance Zone):**
- 10GbE Switch: Connects all infra devices
  - Connects to Proxmox hosts via SFP+ (10G)
  - Connects to baremetal K8s nodes via 2.5G/10G
- All devices in 10.10.0.0/16 network on same Layer 2 segment
- Direct switching at 10G speeds (no router involvement for intra-zone traffic)

**Proxmox Bridge Configuration:**
```
vmbr0: 10.0.0.X/16   - Connected to 1G network, access from trusted zone
vmbr1: 10.10.0.1/16  - Connected to 10G SFP+ network, infra zone gateway

Key: vmbr1 has an IP in the infra subnet, enabling it to route infra traffic
     directly without external router involvement.
```

**Network Topology:**
```
[Internet] ← [Router r5c] → [1G Switch] → Trusted devices (10.0.0.0/16)
                ↓
          [10G Switch/vmbr1] → Infra devices (10.10.0.0/16)
                ↓
          [nl-pve-01, nl-k8s-01, nl-k8s-02, TrueNAS, etc.]
          All communicate at 10G without router bottleneck
```

**Uplink Strategy:**
- Current: CAT6 connections, 1-2.5G links
- Phase 1: Implement 10G SFP+ between Proxmox hosts and infra switch
- Phase 2: Add 10G NICs to baremetal K8s nodes
- Future: Consider 10G fiber between utility closet and office if inter-zone bandwidth becomes bottleneck

### Consequences

**Good:**
- **10G performance without routing bottlenecks:** All infra devices in single subnet (10.10.0.0/16) = direct Layer 2 switching at full speed
- **Clear IP-based identification:** Organized /24 subnets indicate device roles (10.10.1.x = Proxmox, 10.10.2.x = K8s nodes)
- **Operational simplicity:** 4 zones instead of 6-7 VLANs reduces configuration complexity
- **No MetalLB/DHCP conflicts:** MetalLB pool (10.10.100.0/22) is separate from DHCP ranges
- **Strong security boundaries:** Untrusted and local zones properly isolated from infrastructure
- **Future-proof:** /24 subnets within infra can become VLANs later if stricter isolation needed
- **Static lease management:** Predictable IPs without manual node configuration

**Bad:**
- **No Layer 3 isolation within infra:** K8s, Proxmox, storage, and VMs all trust each other (mitigated by pod network policies and VM firewalls)
- **Single firewall zone = single failure domain:** Compromise in one infra device could spread (acceptable risk for homelab)
- **Access to trusted network from VMs limited to 1G:** Traffic from 10.10.x.x → 10.0.x.x must route through router (can be mitigated with IP forwarding on Proxmox or dual NICs)

**Neutral:**
- **Requires 10G-capable switch:** Investment needed but already planned
- **Static lease maintenance:** Must track MAC addresses for DHCP reservations
- **Network topology must be documented:** Critical for troubleshooting and future expansion

### Confirmation

**Validation Plan:**
1. Configure 10G bridge (vmbr1) with 10.10.0.1/16 IP address on Proxmox hosts
2. Assign static DHCP leases for all infra devices in appropriate /24 subnets
3. Test intra-zone throughput with iperf3 (target: 2.5-10 Gbps depending on NIC)
4. Verify firewall rules isolate untrusted and local zones correctly
5. Test access from trusted zone to infra devices
6. Document MAC addresses and IP assignments in infrastructure-as-code

**Success Criteria:**
- Infra zone devices achieve >2 Gbps throughput to each other (proof of no router hairpin)
- Untrusted zone devices cannot reach infra or trusted networks
- Local zone devices can be controlled by K8s services but have no internet access
- Trusted zone can manage all devices across all zones
- Network survives router reboot with minimal downtime (<5 minutes)
- 10G SFP+ links negotiate at full speed (verified with `ethtool`)

## Pros and Cons of the Options

### Option 1: Flat Network (Current State)

**Description:** Single subnet (10.0.0.0/16) with no segmentation.

- Good, because simplest configuration (no routing complexity)
- Good, because no switch upgrades needed
- Bad, because no security isolation (IoT devices can access K8s/Proxmox)
- Bad, because broadcast domain includes all devices (performance impact)
- Bad, because no clear IP-based role identification
- Bad, because DHCP exhaustion risk with single large pool

### Option 2: 4-Zone Design ✅ Chosen

**Description:** Four firewall zones with consolidated infrastructure zone (10.10.0.0/16) for 10G performance.

- Good, because all high-performance traffic stays within single subnet (no router bottleneck)
- Good, because clear security boundaries (trusted, infra, untrusted, local)
- Good, because operational simplicity (4 zones vs 6-7 VLANs)
- Good, because organized /24 subnets allow future VLAN segmentation without renumbering
- Good, because proven working configuration (2.35 Gbps achieved between nl-k8s-01 and nl-k8s-02)
- Neutral, because requires 10G switch investment (already planned)
- Bad, because no Layer 3 isolation within infra zone (acceptable for homelab trust model)

### Option 3: 6-VLAN Design (Full Segmentation)

**Description:** Dedicated VLANs for Trusted, K8s, Proxmox, VMs, MetalLB, IoT, Guest.

- Good, because strongest security boundaries (Layer 3 isolation)
- Good, because very clear IP-based identification per service type
- Bad, because inter-VLAN traffic bottlenecked by router (1G limitation)
- Bad, because complex firewall rule matrix (6x6 = 36 potential rules)
- Bad, because discovered during testing: creates hairpin routing (VM → router @ 1G → VM on same host)
- Bad, because higher router CPU load
- Bad, because more DHCP servers to manage

### Option 4: Hybrid (VLANs + Firewall Groups)

**Description:** Fewer VLANs (3-4) but use firewall groups (ipsets) for logical segmentation.

- Good, because reduces VLAN complexity
- Good, because flexible (move devices between groups without re-IP)
- Bad, because harder to troubleshoot (segmentation not visible at network layer)
- Bad, because firewall becomes single point of policy enforcement
- Bad, because IP addresses don't clearly indicate device role
- Bad, because still suffers from inter-VLAN routing bottlenecks

## Additional Links

- [Proxmox 10GbE Network Configuration](../troubleshooting/proxmox-10gbe-network-configuration.md)
- [Tailscale Subnet Routing](../troubleshooting/tailscale-subnet-routing-not-working.md)
