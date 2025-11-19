# INC-0004: Temporary Cluster Connectivity Loss - Router Connection Tracking Table Full

**Date**: 2025-01-26
**Severity**: High (Cluster accessibility impacted)
**Duration**: ~5-10 minutes (self-recovered)
**Affected Systems**: All k8s nodes (nl-k8s-01 through nl-k8s-04), SSH access, etcd raft

## Summary

Temporary loss of SSH connectivity to nl-k8s-01.lan and etcd raft message drops across the cluster. Issue self-recovered but root cause investigation revealed the OpenWrt router's connection tracking table (nf_conntrack) was completely exhausted at 65,536 connections, causing new connection attempts to be dropped.

## Timeline

### Detection Phase
- **~22:20 UTC**: User reports inability to SSH to nl-k8s-01.lan (10.10.0.2)
- **22:20-22:25 UTC**: SSH via Tailscale hostnames still functional
- **22:25 UTC**: etcd logs show raft message drops: "dropped stream MsgApp...failed to send out heartbeat on time...send buffer is full"
- **22:25 UTC**: Verified all 4 nodes in Ready state via kubectl
- **22:27 UTC**: Connectivity restored, issue self-recovered

### Investigation Phase
- **22:30 UTC**: Router logs analyzed
  - Kernel message `[119088.495653] nf_conntrack: table full, dropping packet`
  - DNS SYN flood warnings on port 53
  - Zero packet drops on br-lan interface (rx/tx both 0)
- **22:35 UTC**: K8s node logs checked
  - nl-k8s-02: Critical NVMe/disk I/O errors on Longhorn v2 volumes
  - nl-k8s-03: Multiple EXT4 journal I/O errors on Longhorn volumes
  - No network-related errors on nodes themselves
- **22:40 UTC**: Router connection tracking limits confirmed:
  - `nf_conntrack_max = 65,536` (extremely low)
  - Current usage: ~1,000 connections
  - Table full event occurred ~33 hours ago (timestamp correlation)

### Resolution Phase
- **22:42 UTC**: Increased router connection tracking limit to 262,144 (4x)
- **22:43 UTC**: Verified new limit active and utilization at 0.6%
- **22:45 UTC**: Secondary issue identified: 2 Longhorn volumes in `unknown` state
- **22:50 UTC**: Disk I/O investigation completed
  - nl-k8s-02: NVMe-oF device (`nvme0c0n1`) errors occurred at 22:23:38, device no longer exists (cleaned up)
  - nl-k8s-03: EXT4 I/O errors occurred at 20:48 (~2 hours before connectivity loss)
  - Mass replica failures detected at ~22:30 (12 min after connectivity loss) across all nodes
  - 2 volumes remain in `unknown` state: jellyseerr-config-v2 and lidarr-config-v2 (not yet deployed)

## Root Cause

The OpenWrt router (r5c.lan) had a default connection tracking table limit of **65,536 connections**, which is insufficient for a network with:
- 4 Kubernetes nodes running dozens of services
- Stateful firewall tracking every TCP/UDP connection
- etcd requiring frequent heartbeat connections between nodes
- Various persistent connections (Tailscale, monitoring, etc.)

When the table reached capacity, the kernel started dropping **new connection attempts** (not existing connections), causing:
1. SSH connection failures (new TCP handshakes dropped)
2. etcd raft heartbeat failures (new connections between etcd peers dropped)
3. Transient connectivity issues that appeared as network instability

The issue self-recovered because:
- Existing connections remained functional
- Connection tracking entries eventually timed out (TCP: 5 days, UDP: 120s, etc.)
- Once space became available, new connections could be established again

## Secondary Issues Discovered

### Longhorn Disk I/O Failures

#### Investigation Summary (22:50 UTC)
Post-incident analysis revealed disk I/O errors that occurred around the time of the connectivity loss, but further investigation determined these were **transient failures caused by the connection tracking table exhaustion**, not underlying storage issues.

#### Timeline Correlation
1. **20:48 UTC** (~2h before incident): Initial EXT4 I/O errors on nl-k8s-03
   - Journal superblock update failures on dm-16, dm-17, dm-7
   - Likely caused by earlier connection tracking pressure
2. **22:23:38 UTC** (~3 min after connectivity loss): NVMe-oF errors on nl-k8s-02
   - `nvme0c0n1` device (NVMe over Fabrics) experienced "operation not supported" errors
   - Device was a temporary Longhorn v2 NVMe-oF target that failed and was cleaned up
3. **22:30 UTC** (~12 min after connectivity loss): Mass Longhorn replica failures
   - Multiple replica error events across all nodes
   - "Detected replica in error" warnings for ~15-20 volumes
   - Failed to delete unknown replicas (connection issues preventing cleanup)

#### Root Cause Analysis
The disk I/O errors were **secondary symptoms** of the connection tracking table exhaustion:
- Longhorn v2 uses NVMe-oF (TCP-based) for replica communication
- When router dropped new connection attempts, NVMe-oF targets became unreachable
- Failed NVMe-oF connections resulted in I/O errors at the block device layer
- EXT4 filesystems reported journal failures due to lost write operations
- Once connection tracking freed up, Longhorn recovered and cleaned up failed connections

#### Current Status
- **nl-k8s-02**: `nvme0c0n1` device no longer exists (temporary NVMe-oF target cleaned up)
- **nl-k8s-03**: No current I/O errors, filesystems healthy, no readonly mounts
- **All nodes**: No pods in error state, cluster fully operational
- **2 volumes in `unknown` state**:
  - `pvc-6ad9f3dd-dc53-403f-a796-546aa8c466ec` - jellyseerr-config-v2 (144Mi, media namespace)
  - `pvc-f1b2b4a1-17ab-4379-85e9-eefc2f0cc28f` - lidarr-config-v2 (288Mi, media namespace)
  - Both volumes are for workloads not yet deployed (PVCs exist but pods don't)
  - No data loss risk as applications haven't been deployed

#### Key Findings
- No underlying hardware issues detected
- No permanent filesystem corruption
- Disk I/O errors were transient, caused by network connectivity loss to NVMe-oF targets
- Longhorn successfully recovered after connection tracking table was expanded
- 2 affected volumes are for undeployed workloads (no production impact)

## Resolution

### Immediate Fix
```bash
# Applied on r5c.lan (OpenWrt router)
# Increase connection tracking limit immediately
sysctl -w net.netfilter.nf_conntrack_max=262144

# Make it persistent across reboots
echo "net.netfilter.nf_conntrack_max=262144" >> /etc/sysctl.d/99-nf-conntrack.conf
```

**Result**: Connection tracking capacity increased from 65,536 → 262,144 (4x increase)

**Note**: The UCI command `uci set firewall.@defaults[0].nf_conntrack_max=262144` is **invalid** - this option does not exist in OpenWrt fw4 firewall configuration. Use sysctl.conf instead.

### Verification
- Current utilization: 0.6% (1,484 / 262,144)
- Provides ~260x headroom for connection growth
- Change persists across reboots via /etc/sysctl.d/99-nf-conntrack.conf

## Action Items

### Completed
- [x] Increase router connection tracking limit to 262,144
- [x] Make persistent via /etc/sysctl.d/99-nf-conntrack.conf
- [x] Investigate disk I/O errors (confirmed transient, caused by connection tracking exhaustion)

### High Priority
- [ ] **Monitor connection tracking usage** over 7 days to determine optimal sizing
  - Track peak utilization during high-load periods
  - Consider further increase if utilization exceeds 50%
- [ ] **Set up Prometheus alerts for connection tracking**:
  ```promql
  (node_nf_conntrack_entries / node_nf_conntrack_entries_limit) > 0.8
  ```

### Medium Priority
- [ ] Tune connection tracking timeout values (if needed):
  - `net.netfilter.nf_conntrack_tcp_timeout_established` (default: 432000s / 5 days)
  - `net.netfilter.nf_conntrack_udp_timeout` (default: 30s)
- [ ] Document router connection tracking sizing guidelines for k8s clusters
- [ ] Consider disabling connection tracking for internal-only traffic (10.0.0.0/8)
  - Use iptables NOTRACK rules for intra-cluster traffic
  - Reduces table pressure for non-NAT traffic

### Low Priority
- [ ] Remove static DHCP leases for k8s nodes (no longer using DHCP)
- [ ] Update DHCP server to assign /16 netmasks to general LAN clients

## Lessons Learned

### What Went Well
- Cluster self-recovered without manual intervention
- etcd remained stable despite heartbeat issues
- Tailscale overlay network provided alternative access path during outage
- Static IP configuration (from INC-0003) prevented cascading DHCP issues

### What Didn't Go Well
- Default OpenWrt connection tracking limits too low for k8s workloads
- No monitoring/alerting for connection tracking table exhaustion
- Disk I/O errors initially appeared as separate storage issue, complicating diagnosis
- NVMe-oF (TCP-based) storage vulnerable to network connectivity issues

### What We Learned
- Connection tracking is a **stateful firewall limitation**, not just NAT
- 65,536 connections insufficient for 4-node k8s cluster with NVMe-oF storage
- Router resource limits impact cluster stability
- **Longhorn v2 NVMe-oF is sensitive to network issues**: TCP-based storage replication means network connectivity problems manifest as disk I/O errors
- Need proactive monitoring of network infrastructure metrics
- Cascading failures: single network resource exhaustion (connection tracking) caused disk I/O errors, replica failures, and volume state issues

## Related Incidents
- **INC-0003**: Kubernetes Cluster Down - DHCP ARP Conflict (2025-01-26)
  - Same cluster, different day
  - Fixed with static IP migration
  - This incident occurred 24 hours after INC-0003 resolution

## References
- OpenWrt nf_conntrack documentation: https://openwrt.org/docs/guide-user/firewall/netfilter_conntrack
- Kubernetes etcd performance tuning: https://etcd.io/docs/v3.5/tuning/
- Linux connection tracking tunables: `sysctl -a | grep conntrack`
