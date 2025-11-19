# Proxmox 10GbE Network Configuration

## Problem

When testing network throughput between Kubernetes nodes, discovered that traffic was routing through the 1Gbps management interface (vmbr0) instead of the 10GbE SFP+ interface (vmbr1), resulting in 1Gbps bottleneck despite having 10G hardware.

## Root Cause

Proxmox bridge interfaces without IP addresses cannot participate in routing decisions. Even though VMs were connected to vmbr1 (10GbE), inter-node traffic was using the default route through vmbr0 (1GbE management interface).

## Solution: Configure Bridge IP Addressing

### Step 1: Add IP to 10GbE Bridge

For the 10GbE bridge to handle traffic directly, it needs an IP in the same subnet as the VMs/nodes connected to it.

**Using Proxmox Web UI (Recommended):**
1. Navigate to: Node → System → Network
2. Select the bridge (e.g., `vmbr1`)
3. Click **Edit**
4. Set **IPv4/CIDR**: `10.10.0.1/16` (or appropriate subnet)
5. Leave **Gateway** empty (unless this is the primary interface)
6. Click **OK**
7. Click **Apply Configuration**

**Result:**
- Bridge now participates in routing for its subnet
- Traffic between nodes in `10.10.0.0/16` uses vmbr1 directly
- More specific routes (/16) take precedence over less specific routes (/8)

### Step 2: Verify Configuration

```bash
# Check bridge has IP
ip addr show vmbr1

# Expected output:
# inet 10.10.0.1/16 scope global vmbr1

# Verify routing table
ip route show | grep 10.10
# Expected: 10.10.0.0/16 dev vmbr1 proto kernel scope link src 10.10.0.1

# Test connectivity from VMs
ping -c 3 10.10.0.1
```

### Step 3: Test Throughput

```bash
# On destination VM (e.g., nl-k8s-02):
iperf3 -s

# On source node (e.g., nl-k8s-01):
iperf3 -c 10.10.0.4 -t 10

# Expected: ~2.5 Gbps (limited by 2.5G USB adapter) or ~10 Gbps (with 10G NICs)
```

## Advanced Configurations

### Multiple VMs on Same 10GbE Bridge

**Scenario:** You have multiple VMs (e.g., nl-k8s-02, truenas) that need 10GbE connectivity.

**Option 1: Single Bridge, Multiple VMs (Simple)**

All VMs share the same bridge. They can communicate with each other at 10G speeds.

```
Configuration:
- vmbr1: 10.10.0.1/16
  - Bridge ports: enp3s0f1np1 (SFP+ port 1)
  - VMs: nl-k8s-02 (10.10.0.4), truenas (10.10.0.10)

Connectivity:
- nl-k8s-02 ↔ truenas: 10 Gbps (direct L2)
- nl-k8s-02 ↔ vmbr1: 10 Gbps
- truenas ↔ vmbr1: 10 Gbps
```

**Steps:**
1. Both VMs configured with `bridge=vmbr1` in their network settings
2. Assign static IPs or DHCP reservations in `10.10.0.0/16` range
3. VMs automatically see each other on Layer 2

**Option 2: Multiple Bridges (Isolated Networks)**

Use separate bridges for different VM groups. Requires multiple physical ports or VLAN tagging.

```
Configuration:
- vmbr1: 10.10.0.1/16 (Kubernetes nodes)
  - Bridge ports: enp3s0f1np1 (SFP+ port 1)
  - VMs: nl-k8s-02

- vmbr2: 10.12.0.1/16 (Storage/VMs)
  - Bridge ports: enp3s0f0np0 (SFP+ port 0)
  - VMs: truenas

Connectivity:
- nl-k8s-02 ↔ truenas: Routes through Proxmox host (10G internal)
- Isolated at Layer 2, connected at Layer 3
```

**Steps:**
1. Create second bridge in Proxmox: System → Network → Create → Linux Bridge
2. Assign second SFP+ port: `enp3s0f0np0`
3. Give it a different subnet: `10.12.0.1/16`
4. Assign VMs to appropriate bridges
5. Enable IP forwarding if inter-bridge communication needed:
   ```bash
   sysctl net.ipv4.ip_forward=1
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
   ```

### Assigning Physical NIC/Port to Specific VM (PCIe Passthrough)

**When to use:** Maximum performance, VM needs direct hardware control, bypassing virtualization overhead.

**Warning:** Once passed through, the host cannot use this device for other VMs.

**Steps:**
1. Enable IOMMU in BIOS (Intel VT-d or AMD-Vi)
2. Enable IOMMU in GRUB:
   ```bash
   # Edit /etc/default/grub
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
   # Or for AMD:
   GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"

   update-grub
   reboot
   ```
3. Find device PCI address:
   ```bash
   lspci | grep -i ethernet
   # Example output: 03:00.0 Ethernet controller: Intel...
   ```
4. In Proxmox UI:
   - VM → Hardware → Add → PCI Device
   - Select the network card
   - Check **All Functions** if it's a multi-port card
   - Check **Primary GPU** only if needed
   - **ROM-Bar** and **PCI-Express**: Usually checked
5. Start VM - the NIC now appears as physical hardware inside the VM

**Pros:**
- Near-native performance
- VM has full control over NIC features (SR-IOV, etc.)

**Cons:**
- NIC unavailable to host and other VMs
- VM migration more complex
- Requires IOMMU-capable hardware

## Adding New NICs to Proxmox Hosts

### Pre-Installation Checklist

Before adding a new NIC (especially 10GbE cards) to a Proxmox host:

1. **Check PCIe Slot Compatibility:**
   - 10GbE cards typically need PCIe 3.0 x8 or x16
   - Verify available slots: `lspci | grep -i pcie`
   - Check motherboard manual for lane allocation

2. **Verify Power Requirements:**
   - High-end NICs can draw 25W+
   - Ensure PSU has capacity
   - Check if card needs PCIe power connector (rare for NICs)

3. **Driver Support:**
   - Check Linux kernel compatibility
   - Intel X520/X710: `ixgbe` / `i40e` (excellent support)
   - Mellanox ConnectX: `mlx4` / `mlx5` (excellent support)
   - Verify: `modinfo <driver_name>`

4. **Cooling Considerations:**
   - 10GbE cards generate significant heat
   - Ensure adequate airflow in case
   - Some cards have passive heatsinks (may need active cooling)

5. **Transceiver/Cable Compatibility:**
   - SFP+ Direct Attach Copper (DAC): 1-10m, cheapest
   - SFP+ Fiber modules: LC, 300m+ (multimode) or 10km+ (single-mode)
   - Verify card supports your transceiver type (some are vendor-locked)

### Post-Installation Configuration

1. **Verify Detection:**
   ```bash
   lspci | grep -i ethernet
   ip link show
   # New interface should appear (e.g., enp3s0f0, enp3s0f1)
   ```

2. **Check Link Status:**
   ```bash
   ethtool enp3s0f1np1
   # Look for:
   # - Link detected: yes
   # - Speed: 10000Mb/s
   # - Duplex: Full
   ```

3. **Test Basic Connectivity:**
   ```bash
   # Bring interface up
   ip link set enp3s0f1np1 up

   # Assign temporary IP for testing
   ip addr add 192.168.100.1/24 dev enp3s0f1np1

   # Ping peer device
   ping 192.168.100.2
   ```

4. **Create Bridge in Proxmox:**
   - System → Network → Create → Linux Bridge
   - **Bridge ports:** Select new interface
   - **IPv4/CIDR:** Assign appropriate subnet
   - **Autostart:** Checked
   - Apply configuration

5. **Assign VMs to New Bridge:**
   - VM → Hardware → Network Device → Edit
   - Change **Bridge:** to new bridge (e.g., vmbr2)
   - Restart VM networking or reboot VM

### Example: Adding Second 10G NIC to nl-pve-02

**Scenario:** nl-pve-02 currently has 1G networking, adding Intel X520 10GbE dual-port SFP+.

**Steps:**

1. **Physical Installation:**
   - Power off host
   - Install card in PCIe 3.0 x8 slot
   - Connect SFP+ DAC cable to switch
   - Power on, boot Proxmox

2. **Verify Detection:**
   ```bash
   ssh root@nl-pve-02.lan
   lspci | grep -i ethernet
   # Should show: Ethernet controller: Intel Corporation 82599ES 10-Gigabit...

   ip link show
   # Should show new interfaces: enp4s0f0, enp4s0f1

   ethtool enp4s0f0 | grep -E "Speed|Link"
   # Speed: 10000Mb/s, Link detected: yes
   ```

3. **Configure Bridge (Proxmox UI):**
   - Navigate to: nl-pve-02 → System → Network
   - Click: Create → Linux Bridge
   - **Name:** vmbr2
   - **Bridge ports:** enp4s0f0
   - **IPv4/CIDR:** 10.10.0.3/16 (if joining K8s network)
   - **Autostart:** Checked
   - **Comment:** "10GbE SFP+ for K8s node nl-k8s-03"
   - Click OK, then Apply Configuration

4. **Update VM Configurations:**
   ```bash
   # Check which VMs should use 10G
   qm list

   # Update VM network (example for VMID 201):
   qm set 201 --net0 virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr2

   # Or via UI: VM 201 → Hardware → net0 → Edit → Bridge: vmbr2
   ```

5. **Test Throughput:**
   ```bash
   # From nl-k8s-03 (VM on nl-pve-02):
   iperf3 -c 10.10.0.4
   # Should see ~10 Gbps
   ```

### Troubleshooting New NIC Issues

**Problem: Interface not detected**
```bash
# Rescan PCI bus
echo 1 > /sys/bus/pci/rescan

# Check dmesg for errors
dmesg | grep -i eth
dmesg | grep -i firmware

# Verify card seated properly (reseat if needed)
```

**Problem: Link shows as DOWN**
```bash
# Check cable/transceiver
ethtool enp3s0f1

# Try bringing up manually
ip link set enp3s0f1 up

# Check for driver issues
modinfo ixgbe
dmesg | grep ixgbe
```

**Problem: Speed negotiates to 1G instead of 10G**
```bash
# Force 10G speed
ethtool -s enp3s0f1 speed 10000 duplex full autoneg off

# Check if SFP+ module is compatible
ethtool -m enp3s0f1

# Verify peer device supports 10G
```

**Problem: High packet loss or errors**
```bash
# Check interface statistics
ip -s link show enp3s0f1

# Look for errors, drops, overruns
ethtool -S enp3s0f1 | grep -i error

# Increase ring buffer size
ethtool -G enp3s0f1 rx 4096 tx 4096

# Check for interrupt issues
cat /proc/interrupts | grep enp3s0f1
```

## Best Practices

1. **Consistent Subnet Allocation:**
   - Use `/16` for flexibility within VLANs
   - Reserve `.0.1` for bridge gateway
   - Reserve `.0.2-.0.99` for static/reserved IPs
   - Use `.1.0+` for DHCP pools

2. **Bridge Naming Convention:**
   - `vmbr0`: Management network (1G, access from WAN)
   - `vmbr1`: High-speed network #1 (10G Kubernetes)
   - `vmbr2`: High-speed network #2 (10G storage/VMs)
   - Document in bridge comments

3. **Always Backup Before Changes:**
   ```bash
   cp /etc/network/interfaces /etc/network/interfaces.backup-$(date +%Y%m%d)
   ```

4. **Test Incrementally:**
   - Add one bridge at a time
   - Test connectivity before moving VMs
   - Keep management network (vmbr0) intact

5. **Use DHCP Reservations:**
   - VMs get predictable IPs without static config
   - Easy to move VMs between hosts
   - Configure on router/DHCP server

6. **Monitor Performance:**
   ```bash
   # Real-time bandwidth monitoring
   iftop -i vmbr1

   # Interface statistics
   watch -n 1 'ip -s link show vmbr1'

   # Check for errors
   ethtool -S enp3s0f1np1 | grep -i error
   ```

## Related Documentation

- [ADR-001: Network Architecture](../adrs/ADR-001-network-architecture.md)
- [Tailscale Subnet Routing](tailscale-subnet-routing-not-working.md)
- [Proxmox Network Configuration](https://pve.proxmox.com/wiki/Network_Configuration)
- [Linux Bridge Documentation](https://wiki.linuxfoundation.org/networking/bridge)
