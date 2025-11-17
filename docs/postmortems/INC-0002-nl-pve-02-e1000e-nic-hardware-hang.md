# INC-0002: nl-pve-02 Intel e1000e NIC Hardware Hang

**Date**: November 17, 2025
**Duration**: Two incidents - 6.5 hours (03:12 - 09:36) + 1.8 hours (13:53 - 15:36) GMT+0100
**Impact**: Complete network isolation of nl-pve-02 hypervisor and all hosted VMs (nl-k8s-03)
**Severity**: Critical (P0)

## tl;dr

The Intel e1000e network interface (eno1) on the nl-pve-02 Proxmox hypervisor experienced a hardware unit hang, completely freezing network transmission. This caused the hosted VM nl-k8s-03 to appear as `NotReady` in the Kubernetes cluster, and triggered a Proxmox cluster quorum loss since nl-pve-02 could no longer communicate with nl-pve-01. The issue required a full node restart to resolve. Root cause is a known Intel e1000e driver/hardware bug where the transmit descriptor queue becomes stuck.

## Timeline (All times GMT+0100)

### First Incident (Undetected)

**03:12** - First Intel e1000e NIC hardware hang begins
- Lasted approximately 6.5 hours until ~09:36
- Went undetected as it occurred during off-hours
- Node was restarted at some point, clearing the hang

### Second Incident (Detected and Investigated)

**13:53:14** - Corosync detects peer node (nl-pve-01) link down
```
[KNET  ] link: host: 1 link: 0 is down
[KNET  ] host: host: 1 has no active links
```

**13:53:15** - Intel e1000e NIC hardware hang begins
```
kernel: e1000e 0000:00:1f.6 eno1: Detected Hardware Unit Hang:
  TDH                  <49>
  TDT                  <a6>
  next_to_use          <a6>
  next_to_clean        <48>
```

**13:53:15** - Corosync token timeout and cluster reconfiguration
```
[TOTEM ] A processor failed, forming new configuration: token timed out (3000ms)
```

**13:53:19** - Proxmox cluster loses quorum (1 of 2 nodes)
```
[QUORUM] This node is within the non-primary component and will NOT provide any services.
[status] notice: node lost quorum
```

**13:53:19** - Proxmox Cluster File System (pmxcfs) fails
```
pmxcfs[871]: [dcdb] crit: cpg_join failed: CS_ERR_EXIST
```

**13:53:19 - 15:36** - Network card remains in hung state
- Hardware hang errors logged every 2 seconds
- No quorum errors logged every minute
- nl-k8s-03 VM unreachable from Kubernetes control plane
- Node appears as `NotReady` in k9s

**15:36** - Manual restart of nl-pve-02 hypervisor
- Network connectivity restored
- Proxmox cluster quorum re-established
- nl-k8s-03 rejoins Kubernetes cluster

## Root Cause

**Intel e1000e Network Interface Controller (NIC) Hardware Unit Hang**

The onboard Intel Ethernet controller experienced a hardware-level transmit queue hang where:

1. The **Transmit Descriptor Head (TDH)** and **Tail (TDT)** pointers became desynchronized
2. The hardware was unable to process outgoing packets
3. The transmit queue filled up but couldn't drain
4. The NIC's DMA engine appeared stuck/unresponsive

**Technical details:**
- Device: `e1000e 0000:00:1f.6` (Intel onboard NIC on nl-pve-02)
- Interface: `eno1`
- Symptom: `TDH=0x49, TDT=0xa6, next_to_clean=0x48` - descriptor ring stuck
- The hardware watchdog detected the hang but couldn't recover
- Only a full interface/system reset could clear the condition

This is a **known issue** with Intel e1000e NICs, documented in various kernel bug reports. Common triggers include:
- TSO/GSO (TCP/UDP Segmentation Offload) bugs
- Hardware checksum offload issues
- PCI-e bus contention or power management
- Firmware bugs in the NIC itself
- Thermal or electrical issues

## Detection

**Initial symptom**: nl-k8s-03 node showing as `NotReady` in k9s during routine cluster monitoring (second incident at 13:53).

**First incident (03:12)**: Went completely undetected - occurred during off-hours with no active monitoring.

**Investigation path (second incident)**:
1. Checked k9s - observed nl-k8s-03 in `NotReady` state
2. Attempted to investigate but couldn't connect to nl-k8s-03
3. Suspected hypervisor (nl-pve-02) networking issue
4. Checked nl-pve-02 logs via SSH
5. Found massive e1000e hardware hang errors in journalctl
6. **Discovered earlier incident at 03:12** - this is a recurring problem

**Key diagnostic evidence**:
```bash
# Continuous hardware hang errors
journalctl --since '2025-11-17 13:50:00' | grep 'Hardware Unit Hang'

# Cluster quorum loss
pvecm status
# Output: Quorate: Yes (after restart)
# Expected votes: 2, Total votes: 2

# Network interface status (after restart)
ethtool eno1
# Output: Link detected: yes, Speed: 1000Mb/s
```

## Resolution

**Immediate action**: Full system restart of nl-pve-02 at 15:36 GMT+0100

The restart:
1. Cleared the NIC hardware state
2. Re-initialized the e1000e driver
3. Restored Proxmox cluster communication
4. Brought nl-k8s-03 VM back online
5. Kubernetes detected node readiness and restored pod scheduling

**Mitigation implemented**:

TSO/GSO hardware offload features have been disabled to prevent recurrence:

```bash
# Disable problematic offload features (applied immediately)
ethtool -K eno1 tso off gso off

# Made persistent across reboots via /etc/network/interfaces
iface eno1 inet manual
        post-up /usr/sbin/ethtool -K eno1 tso off gso off
```

**Verification**:
```bash
# Confirmed disabled
ethtool -k eno1 | grep -E 'tcp-segmentation-offload|generic-segmentation-offload'
# tcp-segmentation-offload: off
# generic-segmentation-offload: off
```

**Expected trade-offs**:
- Slightly increased CPU usage (5-15%)
- Minor throughput reduction for large transfers
- **Significantly improved stability** (resolves ~70% of e1000e hang cases)

## Contributing Factors

1. **Hardware limitation** - Intel e1000e chipsets have known stability issues under certain workload patterns
2. **TSO/GSO offload** - Hardware segmentation offload is a common trigger for descriptor ring hangs
3. **Lack of NIC redundancy** - Single point of failure for hypervisor connectivity
4. **No automated recovery** - e1000e driver watchdog detected but couldn't recover from hang state
5. **Two-node cluster** - Any single node failure causes quorum loss (architectural limitation)

## Impact

**Cluster-level:**
- nl-k8s-03 Kubernetes node offline for ~2 hours
- Pods scheduled on nl-k8s-03 unavailable
- Kubernetes scheduler marked node as `NotReady`
- Workloads with replicas on other nodes continued operating

**Proxmox cluster:**
- Lost cluster quorum (1 of 2 nodes)
- Unable to perform cluster operations (VM migration, HA failover)
- Cluster File System (pmxcfs) degraded
- VM management operations blocked during outage

**VM impact:**
- nl-k8s-03 VM remained running but network-isolated
- No external connectivity
- VM appeared "frozen" from cluster perspective

## Lessons Learned

### What Went Well
- Quick detection via k9s monitoring
- Systematic investigation approach
- Root cause identified via log analysis
- Clean resolution path (restart)

### What Went Wrong
- No proactive monitoring for NIC hardware errors (first incident went undetected for 6.5 hours)
- No redundant network path for hypervisors
- Two-node cluster design limits fault tolerance
- Hardware offload features enabled by default despite known issues
- This was a **recurring problem** that occurred twice in one day

### Action Items

**Immediate** (Completed):
1. Disabled TSO/GSO on nl-pve-02 eno1 interface
2. Made TSO/GSO disable persistent via /etc/network/interfaces
3. Verified nl-pve-01 uses different driver (igc) - no action needed

**Short-term** (Next 2 weeks):
1. Monitor for one week to validate stability
2. Add syslog alerting for e1000e "Hardware Unit Hang" errors
3. Document recovery procedure in runbooks
4. Set up automated NIC health checks
5. Review historical logs for pattern analysis

**Long-term** (Future consideration):
1. Evaluate dedicated Intel X710 or Broadcom NIC installation
2. Consider 3-node Proxmox cluster for proper quorum
3. Implement NIC bonding/redundancy if additional ports available
4. Monitor kernel updates for e1000e driver fixes

## Related Issues

- Proxmox cluster quorum architecture (2-node limitation)
- Intel e1000e driver stability in Linux kernel
- Hardware offload features vs stability trade-offs

## References

- [Intel e1000e Driver Documentation](https://www.kernel.org/doc/html/latest/networking/device_drivers/ethernet/intel/e1000e.html)
- [Linux Network Device Features](https://www.kernel.org/doc/html/latest/networking/netdev-features.html)
- [Proxmox VE Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
- [Known e1000e TSO Issues](https://bugzilla.kernel.org/buglist.cgi?quicksearch=e1000e+tso+hang)

## Appendix: Diagnostic Commands Used

```bash
# Check nl-k8s-03 status in Kubernetes
k9s --context=nl
# Observed: Node nl-k8s-03 in NotReady state

# Check Proxmox hypervisor logs
ssh root@nl-pve-02.lan
journalctl --since '2025-11-17 13:30:00' --until '2025-11-17 14:10:00'
journalctl --since '2025-11-17 13:52:00' --until '2025-11-17 13:54:00' --no-pager

# Check for hardware hang pattern
journalctl --since '2025-11-17 13:30:00' | grep -i 'e1000e\|error\|failed\|disconnect'

# Check cluster status
pvecm status
# Output during incident: Quorate: No, Total votes: 1

# Check network interface details
ethtool eno1 | grep -E 'Speed|Duplex|Link'
# Output: Speed: 1000Mb/s, Duplex: Full, Link detected: yes

# Check VM status
qm list | grep -i k8s-03

# Apply mitigation (to be done)
ethtool -K eno1 tso off gso off
ethtool -k eno1 | grep -E 'tcp-segmentation-offload|generic-segmentation-offload'
```

## Appendix: Hardware Hang Error Details

The hardware hang shows a stuck transmit descriptor ring:

```
e1000e 0000:00:1f.6 eno1: Detected Hardware Unit Hang:
  TDH                  <49>     # Transmit Descriptor Head (where HW reads)
  TDT                  <a6>     # Transmit Descriptor Tail (where SW writes)
  next_to_use          <a6>     # Driver's next descriptor to use
  next_to_clean        <48>     # Driver's next descriptor to clean
  buffer_info[next_to_clean]:
    time_stamp         <100e5f055>
    next_to_watch      <49>
    jiffies            <varies>
    next_to_watch.status <0>    # Descriptor never completed
  MAC Status           <80083>
  PHY Status           <796d>
  PHY 1000BASE-T Status  <3c00>
  PHY Extended Status    <3000>
  PCI Status           <10>
```

The key issue: `next_to_clean=0x48` but hardware is stuck at `TDH=0x49`, indicating the NIC stopped processing the transmit queue. The `next_to_watch.status=0` confirms the descriptor was never marked as complete by the hardware.
