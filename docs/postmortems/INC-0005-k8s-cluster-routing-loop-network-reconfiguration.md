# INC-0004: K8s Cluster Routing Loop During Network Reconfiguration

**Date**: November 22, 2025
**Duration**: ~30 minutes
**Severity**: High (Complete cluster outage)

**Impact**: Complete Kubernetes cluster outage due to routing loops and connectivity loss to nl-k8s-01 during network prefix length reconfiguration

## Timeline

**19:52 CET** - nl-k8s-01 k3s service stopped due to unresponsiveness (etcd timeouts)
**20:00 CET** - User unable to reach nl-k8s-01 (10.10.0.2) from any network location
**20:10 CET** - Investigation revealed routing loops with ICMP redirects and TTL exceeded errors
**20:15 CET** - Root cause identified: inconsistent network prefix lengths during reconfiguration
**20:20 CET** - Network configuration corrected to /8 across all nodes
**20:25 CET** - Connectivity restored temporarily
**20:40 CET** - User restarted k3s service, all nodes became unreachable again
**20:45 CET** - Second root cause identified: flannel VXLAN incompatible with /8 prefix
**20:50 CET** - Router neighbor cache showed all nodes with same MAC address (VXLAN confusion)
**21:00 CET** - Final resolution: Revert to /16 prefix with static routes to other subnets## Root Cause

**Primary:** Flannel VXLAN is fundamentally incompatible with /8 prefix configuration. When k3s starts with VXLAN backend, it creates MAC address confusion at the switch/router level, causing all nodes to be learned with the same MAC address.

**Secondary:** During initial reconfiguration (from /16 to /8), nodes had **inconsistent routing tables** causing asymmetric routing and routing loops.

### Technical Details

**Network Topology:**
- **nl-k8s-01** (10.10.0.2): Baremetal, connected via 2.5G USB Ethernet to main network switch → router (r5c) at 10.0.0.1/8
- **nl-k8s-02** (10.10.0.4): VM on nl-pve-01, connected to vmbr1 (10G SFP+ network) with gateway 10.10.0.1/8
- **nl-k8s-03** (10.10.0.5): VM on nl-pve-02, connected to vmbr1
- **nl-k8s-04** (10.10.0.3): Baremetal, connected to main network switch

**The Routing Loop:**
1. During reconfiguration, nl-k8s-01 was temporarily configured with incorrect or transitional prefix length
2. Nodes had inconsistent views of which addresses were "local" vs requiring gateway
3. Router (10.0.0.1/8) and nodes with /8 thought 10.10.0.2 was directly reachable
4. Stale ARP cache entries pointed to wrong MAC addresses or interfaces
5. Packets bounced between nodes (nl-k8s-04 → nl-k8s-02 → router) creating TTL exceeded errors
6. ICMP redirects sent: "Redirect Host (New nexthop: 10.10.0.2)" from 10.10.0.4
7. etcd cluster lost quorum due to timeouts: "dial tcp 10.10.0.4:2380: i/o timeout"

**Observed Symptoms:**
```
From 10.10.0.3 icmp_seq=1 Time to live exceeded
From 10.10.0.4 icmp_seq=2 Redirect Host(New nexthop: 10.10.0.2)
```

**etcd Failures:**
```
{"msg":"prober detected unhealthy status","remote-peer-id":"e14246ca563de8af","error":"dial tcp 10.10.0.4:2380: i/o timeout"}
{"msg":"waiting for ReadIndex response took too long, retrying","sent-request-id":7583105939963956480,"retry-timeout":"500ms"}
```

**Flannel VXLAN + /8 Prefix Issue (Second Incident):**

When k3s restarted with /8 configuration:
1. Flannel VXLAN created overlay network on UDP port 8472
2. VXLAN encapsulation caused router to learn incorrect MAC addresses
3. Router neighbor cache showed all k8s nodes (10.10.0.2, 10.10.0.3, 10.10.0.4, 10.10.0.5) with **same MAC address**: `54:e1:ad:a5:1d:0f`
4. Traffic to any node routed to wrong physical host
5. Complete cluster network failure
6. Clearing router neighbor cache temporarily fixed issue, but problem recurred on k3s restart

**Why /8 + VXLAN Fails:**
- With /8, nodes think all 10.x.x.x addresses are local (no gateway forwarding)
- Flannel VXLAN creates 10.42.x.x/24 pod networks and advertises them via VXLAN tunnels
- This creates routing ambiguity: should traffic go direct or through VXLAN?
- Switches/routers see VXLAN encapsulated frames and learn wrong MAC addresses
- Result: MAC address table pollution, packets sent to wrong hosts

## Resolution

**Temporary Fix (First Incident):**
1. Connected directly to nl-k8s-01 via IP address (10.10.0.2) bypassing hostname resolution
2. Verified network configuration was set to /8 on all nodes
3. Updated remaining nodes (nl-k8s-03, nl-k8s-04) to /8 prefix length
4. Cleared router ARP cache
5. Connectivity temporarily restored

**Permanent Fix (After Second Incident):**
1. Identified flannel VXLAN incompatibility with /8 prefix
2. Reverted all nodes to /16 prefix (10.10.0.x/16)
3. Added static routes to reach other subnets:
   - 10.0.0.0/16 via 10.0.0.1 (trusted zone - smart home devices)
   - 10.11.0.0/16 via 10.0.0.1 (management zone - Proxmox hosts)
   - 10.20.0.0/16 via 10.0.0.1 (guest zone - optional)
4. This configuration:
   - Works correctly with flannel VXLAN
   - Allows access to all required subnets
   - Avoids need for IP forwarding on Proxmox hosts
   - Prevents MAC address confusion at switch/router level

## Lessons Learned

### What Went Well
- Direct IP access (ssh root@10.10.0.2) bypassed routing issues
- Router and Proxmox hosts maintained connectivity to nl-k8s-01
- NixOS rollback capability available as safety net

### What Went Wrong
- Network changes applied sequentially without coordination
- No ARP cache clearing before/during reconfiguration
- k3s cluster remained running during network changes (etcd split-brain)
- No pre-change connectivity verification matrix

### Action Items

**Immediate:**
- Always clear ARP caches before major network changes
- Stop k3s cluster before network topology changes

**Short-term:**
- Create pre-flight checklist for network maintenance
- Add connectivity verification matrix to runbooks
- Document rollback procedures for network changes

**Long-term:**
- Consider implementing VIP (keepalived/kube-vip) for control plane HA
- Evaluate moving to consistent network architecture per ADR-001
- Implement automated network validation tests
- Consider migrating from flannel to Cilium for better routing control (already noted as FIXME in k3s.nix)
- Alternative: Use flannel host-gw backend instead of VXLAN if /8 prefix is required

## Prevention: Safe Network Reconfiguration Procedure

### Prerequisites
- All networking.nix changes committed to git
- Terminal access to all nodes
- Rollback plan ready (nixos-rebuild --rollback)

### Step 1: Pre-flight Checks
```bash
# Verify current configuration
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  echo "=== $node ==="
  ssh root@${node}.lan 'ip addr show | grep "inet 10\."'
done

# Verify cluster health
ssh root@nl-k8s-01.lan 'kubectl get nodes'
```

### Step 2: Stop Cluster Services
```bash
# Stop k3s on all nodes (prevents etcd split-brain)
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  echo "Stopping k3s on $node..."
  ssh root@${node}.lan 'systemctl stop k3s' &
done
wait

# Verify all stopped
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  ssh root@${node}.lan 'systemctl is-active k3s || echo "$node k3s stopped"'
done
```

### Step 3: Clear ARP Caches
```bash
# On router (prevents stale routing entries)
ssh root@r5c.lan 'ip neigh flush all'

# On Proxmox hosts
ssh root@nl-pve-01.lan 'ip neigh flush all'
ssh root@nl-pve-02.lan 'ip neigh flush all'

# On each k8s node
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  ssh root@${node}.lan 'ip neigh flush all'
done

echo "ARP caches cleared. Waiting 5 seconds..."
sleep 5
```

### Step 4: Apply Network Configuration Changes

**Option A: Parallel (fastest, use for identical changes)**
```bash
# Deploy to all nodes simultaneously
parallel -j4 ssh root@{}.lan 'nixos-rebuild switch' ::: \
  nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04
```

**Option B: Sequential (safer, allows per-node verification)**
```bash
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  echo "=== Updating $node ==="
  ssh root@${node}.lan 'nixos-rebuild switch'

  echo "Waiting 10 seconds for network to settle..."
  sleep 10

  # Verify connectivity before proceeding
  if ping -c 3 -W 2 ${node}.lan; then
    echo "✓ $node reachable"
  else
    echo "✗ WARNING: $node not reachable!"
    echo "Press Enter to continue or Ctrl+C to abort..."
    read
  fi
done
```

### Step 5: Verify Network Configuration
```bash
# Check all nodes have consistent routing
echo "=== Routing Tables ==="
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  echo "--- $node ---"
  ssh root@${node}.lan 'ip route show | grep "^10\."'
  echo
done

# Check prefix lengths are consistent
echo "=== IP Addresses ==="
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  echo "--- $node ---"
  ssh root@${node}.lan 'ip addr show | grep "inet 10\."'
  echo
done
```

### Step 6: Connectivity Matrix Verification
```bash
# Test connectivity between all nodes
echo "=== Connectivity Matrix ==="
for src in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  for dst in 10.10.0.2 10.10.0.3 10.10.0.4 10.10.0.5; do
    if ssh root@${src}.lan "ping -c 1 -W 2 $dst >/dev/null 2>&1"; then
      echo "✓ $src -> $dst"
    else
      echo "✗ $src -> $dst FAILED"
    fi
  done
done
```

### Step 7: Start Cluster Services
```bash
# Start k3s on all nodes
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  echo "Starting k3s on $node..."
  ssh root@${node}.lan 'systemctl start k3s' &
done
wait

echo "Waiting 30 seconds for cluster to initialize..."
sleep 30

# Verify cluster health
ssh root@nl-k8s-01.lan 'kubectl get nodes'
```

### Step 8: Post-Change Verification
```bash
# Check all nodes are Ready
ssh root@nl-k8s-01.lan 'kubectl get nodes'

# Check etcd cluster health
ssh root@nl-k8s-01.lan 'kubectl get cs'

# Check for pod issues
ssh root@nl-k8s-01.lan 'kubectl get pods -A | grep -v Running'

# Monitor k3s logs for errors
ssh root@nl-k8s-01.lan 'journalctl -u k3s -f --since "2 minutes ago"'
```

### Rollback Procedure (If Issues Occur)
```bash
# Stop k3s if it's causing issues
ssh root@nl-k8s-XX.lan 'systemctl stop k3s'

# Rollback network configuration
ssh root@nl-k8s-XX.lan 'nixos-rebuild switch --rollback'

# Clear ARP caches again
ssh root@r5c.lan 'ip neigh flush all'
for node in nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04; do
  ssh root@${node}.lan 'ip neigh flush all'
done

# Wait for routing to stabilize
echo "Waiting 30 seconds for routing to stabilize..."
sleep 30

# Verify connectivity
ping -c 5 nl-k8s-XX.lan

# Restart k3s
ssh root@nl-k8s-XX.lan 'systemctl start k3s'
```

## Related Incidents
- **INC-0003**: Kubernetes cluster down due to DHCP ARP conflict (similar /8 vs /16 prefix issue)
- **INC-0004**: Temporary Cluster Connectivity Loss - Router Connection Tracking Table Full

## References
- ADR-001: Network Segmentation and VLAN Architecture
- nl-pve-01 network configuration: `/etc/network/interfaces`
- Router configuration: `/etc/config/network` on r5c.lan
- Node network configs: `machines/nl-k8s-*/networking.nix`

## Notes

### Why /8 vs /16 Matters

**With /16 prefix (10.10.0.0/16):**
- Node considers 10.10.0.0 - 10.10.255.255 as "local" (directly reachable)
- Traffic to 10.0.0.x goes through default gateway (10.0.0.1)
- Creates network segmentation between infra (10.10.x.x) and trusted (10.0.x.x) zones

**With /8 prefix (10.0.0.0/8):**
- Node considers entire 10.0.0.0 - 10.255.255.255 as "local"
- No gateway needed for any 10.x.x.x address
- Allows direct communication across all subnets (10.0.x.x, 10.10.x.x, etc.)

**Current deployment uses /16 with static routes:**
- Nodes use 10.10.0.x/16 prefix (local infra zone)
- Static routes added for:
  - 10.0.0.0/16 (trusted zone - smart home devices like 10.0.0.21)
  - 10.11.0.0/16 (management zone - Proxmox hosts)
  - 10.20.0.0/16 (guest zone - future use)
- This approach:
  - Compatible with flannel VXLAN (no MAC address confusion)
  - Allows access to all required subnets via gateway
  - No IP forwarding needed on Proxmox hosts
  - Proper network segmentation at L3 routing level

### Flannel Backend Compatibility

**VXLAN (default):**
- ✅ Works with /16 or smaller prefix lengths
- ❌ Incompatible with /8 prefix (causes MAC address confusion)
- Uses UDP port 8472 for overlay network
- Encapsulates packets, creating separate L2 domain

**host-gw:**
- ✅ Works with any prefix length including /8
- Uses kernel routing tables directly
- Requires all nodes on same L2 network (no intermediate routers)
- More efficient (no encapsulation overhead)
- Enable with: `--flannel-backend=host-gw` in k3s extraFlags

**Why VXLAN + /8 Fails:**
1. With /8, nodes think entire 10.0.0.0/8 is local
2. Flannel still needs to route pod traffic (10.42.x.x) between nodes
3. VXLAN frames exit physical interface with node's MAC address
4. Router sees same MAC for multiple IPs → MAC address table corruption
5. Return traffic sent to wrong physical host

### Asymmetric Routing Explained

When prefix lengths are inconsistent:
1. Node A (10.10.0.2/8) thinks 10.10.0.4 is local → sends packet directly
2. Node B (10.10.0.4/16) thinks 10.10.0.2 is NOT local → sends return packet via gateway
3. Gateway sees both as /8 local → tries to redirect
4. Packet loops: Node A → Node B → Gateway → Node B (ICMP redirect) → Node A
5. Eventually TTL expires: "Time to live exceeded"

This is why ARP cache clearing and consistent configuration is critical.
