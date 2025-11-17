# INC-0003: Kubernetes Cluster Down - DHCP ARP Conflict

## Incident Summary

**Date**: 2025-11-17
**Duration**: ~2 hours
**Severity**: Critical (P1)
**Impact**: Complete Kubernetes cluster outage - nl-k8s-01 (cluster init node) unable to start k3s service

## Timeline

- **20:00:07** - nl-k8s-01 received DHCP offer for static lease 10.10.0.2
- **20:00:07** - nl-k8s-01 sent DHCPDECLINE due to Address Conflict Detection (ACD) failure
- **20:00:07** - dnsmasq disabled static lease 10.10.0.2 for 10 minutes
- **20:00:21** - nl-k8s-01 assigned fallback dynamic IP 10.0.0.109 from DHCP pool
- **20:06:28** - k3s service stuck in "activating" state, unable to form etcd quorum
- **Investigation begins** - User noticed cluster completely down via k9s
- **Root cause identified** - nl-k8s-04 responding to ARP requests for 10.10.0.2 due to /8 netmask
- **Resolution implemented** - Migrated all k8s nodes to static IPs with /16 netmask

## Root Cause

### Network Configuration Issue

The router LAN interface was configured with a /8 netmask (255.0.0.0), which was propagated to all DHCP clients:

```
Router: 10.0.0.1/8
DHCP clients received: 10.x.x.x/8
```

This caused all devices to believe the entire 10.0.0.0/8 range was on the local network, leading to:

1. **Improper ARP behavior**: nl-k8s-04 (configured as 10.10.0.3/8) responded to ARP probes for 10.10.0.2
2. **Address Conflict Detection failure**: When nl-k8s-01 tried to claim 10.10.0.2, it detected a conflict (nl-k8s-04 responding)
3. **DHCP fallback**: nl-k8s-01 declined 10.10.0.2 and received dynamic IP 10.0.0.109 instead
4. **etcd failure**: k3s tried to form cluster with wrong IP (10.0.0.109 instead of 10.10.0.2)
5. **Complete cluster outage**: nl-k8s-01 couldn't reach nl-k8s-02 (10.10.0.4) and nl-k8s-03 (10.10.0.5)

### Design Context

The network was designed with subnet-based segmentation without VLANs:

- 10.0.0.0/16 - General LAN devices
- 10.10.0.0/16 - Kubernetes nodes
- 10.11.0.0/16 - Proxmox hosts
- 10.20.0.0/16 - MetalLB services

However, the /8 netmask prevented proper subnet isolation at Layer 2, causing ARP to span all subnets.

## Investigation

### Key Evidence

**dnsmasq logs on router (r5c.lan)**:
```
Mon Nov 17 20:00:07 2025 daemon.info dnsmasq-dhcp[1]: DHCPREQUEST(br-lan) 10.10.0.2 6c:1f:f7:57:07:49
Mon Nov 17 20:00:07 2025 daemon.info dnsmasq-dhcp[1]: DHCPACK(br-lan) 10.10.0.2 6c:1f:f7:57:07:49 nl-k8s-01
Mon Nov 17 20:00:07 2025 daemon.info dnsmasq-dhcp[1]: DHCPDECLINE(br-lan) 10.10.0.2 6c:1f:f7:57:07:49 acd failed
Mon Nov 17 20:00:07 2025 daemon.warn dnsmasq-dhcp[1]: disabling DHCP static address 10.10.0.2 for 10m
```

**ARP table on router**:
```
10.10.0.2 dev br-lan lladdr 54:e1:ad:a5:1d:0f ref 1 used 0/0/0 probes 1 REACHABLE
```
MAC 54:e1:ad:a5:1d:0f belongs to nl-k8s-04, not nl-k8s-01.

**k3s service on nl-k8s-01**:
```
etcd client: failed to publish local member to cluster through raft
ClientURLs=[https://10.0.0.109:2379]
dial tcp 10.10.0.4:2380: i/o timeout
dial tcp 10.10.0.5:2380: i/o timeout
```

## Resolution

### Immediate Fix

Migrated all Kubernetes nodes from DHCP with static leases to static IP configuration with proper /16 netmask:

**Configuration changes**:
- Disabled NetworkManager and dhcpcd on all k8s nodes
- Configured static IPs with /16 netmask in NixOS:
  - nl-k8s-01: 10.10.0.2/16
  - nl-k8s-02: 10.10.0.4/16
  - nl-k8s-03: 10.10.0.5/16
  - nl-k8s-04: 10.10.0.3/16
- Set default gateway to 10.0.0.1
- Set DNS to 10.0.0.1

**Example configuration** (machines/nl-k8s-04/networking.nix):
```nix
{
  networking.networkmanager.enable = false;
  networking.useDHCP = false;

  networking.interfaces.enp0s31f6.useDHCP = false;
  networking.interfaces.enp0s31f6.ipv4.addresses = [{
    address = "10.10.0.3";
    prefixLength = 16;
  }];

  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "enp0s31f6";
  };

  networking.nameservers = [ "10.0.0.1" ];
}
```

### Verification

- All nodes successfully configured with /16 netmask
- ARP conflicts resolved (nodes only respond to ARP within their /16 subnet)
- Kubernetes cluster restored to operational state
- Inter-subnet routing functional (k8s nodes can reach Proxmox hosts and general LAN)

## Impact Assessment

### Services Affected
- Complete Kubernetes cluster outage
- All workloads running on k8s cluster unavailable
- No ingress traffic served
- Monitoring and alerting impacted

### Duration
- Approximately 2 hours from initial failure to resolution

### User Impact
- All services hosted on Kubernetes cluster unreachable
- Home automation services disrupted
- Media services (Jellyfin) unavailable

## Lessons Learned

### What Went Well
- Root cause analysis was systematic and thorough
- Investigation revealed design flaw rather than hardware failure
- Solution was implemented incrementally (tested on nl-k8s-04 first)
- NixOS declarative configuration made rollback possible if needed

### What Could Be Improved
- Should have recognized /8 netmask issue during initial network design
- DHCP-based management for infrastructure nodes created unnecessary dependency

### Preventive Measures
- Use static IPs for all infrastructure components (servers, switches, routers)
- Reserve DHCP for client devices only
- Implement monitoring for k3s service status, not just node reachability
- Consider proper VLAN segmentation when upgrading to managed switches

## Action Items

### Completed
- Migrate nl-k8s-01, nl-k8s-02, nl-k8s-03, nl-k8s-04 to static IPs with /16 netmask
- Verify Kubernetes cluster health
- Test inter-subnet routing

### Pending
- Migrate Proxmox hosts (nl-pve-01, nl-pve-02) to static IPs with 10.11.0.x/16
- Document final network architecture and IP allocation scheme
- Add monitoring for k3s service status on all nodes
- Add alerting for etcd cluster health

### Future Considerations
- Evaluate managed switch purchase for true VLAN segmentation (Layer 2 isolation, broadcast domain separation, enhanced security)

## Notes

### Network Design Decision

The original goal was to use DHCP with static leases for centralized IP management across all network devices. However, this approach proved problematic for infrastructure components due to:

- Dependency on DHCP service availability
- ARP conflicts in flat network design without VLANs
- Complexity in troubleshooting address assignment issues

**Decision**: Infrastructure nodes (Kubernetes, Proxmox, network equipment) should use static IPs configured at the OS level. DHCP should be reserved for client devices only.

### VLAN vs Static IP Netmask

Two approaches were considered for subnet segmentation:

1. **VLANs with 802.1Q tagging**:
   - Requires VLAN-transparent or managed switches
   - Provides true Layer 2 isolation
   - More complex to configure and troubleshoot
   - Better long-term architecture

2. **Static IPs with proper netmasks** (implemented):
   - Works with unmanaged switches
   - Provides routing-based segmentation
   - Simpler to configure and maintain
   - No Layer 2 isolation (shared broadcast domain)
   - Adequate for current requirements

The static IP approach was chosen as it solves the immediate ARP conflict issue without requiring hardware upgrades or risking additional network instability.
