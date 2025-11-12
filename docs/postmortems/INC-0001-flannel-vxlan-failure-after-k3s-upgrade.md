# INC-0001: Flannel VXLAN Failure After K3s 1.34.1 Upgrade

**Date**: November 13, 2025
**Duration**: ~2 hours
**Impact**: Cluster-wide networking failure - pods on different nodes couldn't communicate
**Severity**: Critical (P0)

## tl;dr

After upgrading k3s from 1.32.1+k3s1 to 1.34.1+k3s1, the Flannel VXLAN overlay network failed completely. Pods on different nodes could not communicate, causing DNS failures, webhook timeouts (Kyverno), and general cluster dysfunction. The root cause was that the flannel.1 VXLAN interface failed to initialize on eq14-001 after the upgrade, breaking all cross-node pod communication. Restarting k3s on the affected node restored connectivity.

## Root Cause

The k3s upgrade to v1.34.1+k3s1 caused the Flannel CNI plugin to fail initialization on eq14-001. Specifically:

1. The `flannel.1` VXLAN interface never came up after the upgrade
2. Without this interface, VXLAN tunnels from other nodes (gladius, momonoke) to eq14-001 couldn't be established
3. UDP port 8472 (VXLAN) was not listening on eq14-001
4. Pod-to-pod routing across nodes failed completely

**Technical details:**
- Flannel uses VXLAN (Virtual Extensible LAN) for overlay networking
- Each node has a `flannel.1` interface that encapsulates pod traffic in UDP packets
- The FDB (Forwarding Database) maps remote pod IPs to node IPs via VXLAN tunnel endpoints
- When the flannel interface doesn't initialize, the kernel can't create VXLAN tunnels

## Detection

Initial symptom was Tailscale pods logging DNS timeout errors:
```
Post "https://kubernetes.default.svc/apis/authorization.k8s.io/v1/selfsubjectaccessreviews":
dial tcp: lookup kubernetes.default.svc on 10.43.0.10:53: read udp 10.42.2.231:39898->10.43.0.10:53:
i/o timeout
```

This cascaded into:
- Kyverno admission webhooks timing out (preventing pod creation)
- CoreDNS unable to be queried from pods on other nodes
- General inability to create/schedule new workloads

**Key diagnostic command:**
```bash
ping -c 3 10.42.0.54  # CoreDNS pod IP on eq14-001
# 100% packet loss from gladius
```

## Resolution

1. **Immediate fix**: Restarted k3s on eq14-001
   ```bash
   ssh root@eq14-001 "systemctl restart k3s"
   ```

2. **Verification**: Checked flannel interface came up
   ```bash
   ip link show flannel.1
   # Status: UP
   ```

3. **Tested connectivity**: Verified cross-node pod reachability
   ```bash
   ping 10.42.0.54  # Success from gladius
   ```

4. **Restarted CoreDNS**: Cleared any stale state
   ```bash
   kubectl rollout restart -n kube-system deployment/coredns
   ```

## Contributing Factors

1. **K3s upgrade process** - The upgrade from 1.32.1+k3s1 to 1.34.1+k3s1 may have introduced a timing issue with CNI initialization
2. **Systemd service restart** - k3s service was restarted as part of deployment, but Flannel didn't recover properly
3. **Lack of health checks** - No automated monitoring detected the missing flannel interface

## Impact

**User-facing:**
- All pods attempting DNS resolution failed
- New pods couldn't be created due to webhook timeouts
- Cross-node service communication broken

**Operational:**
- Cluster effectively non-functional for cross-node workloads
- Required manual intervention to restore

## Related Issues

- Kyverno webhook timeouts (symptom, not cause)
- CoreDNS NXDOMAIN responses (secondary effect of no connectivity)
- Previous NFS loopback issues on gladius (unrelated but similar symptom pattern)

## References

- [Flannel VXLAN Backend Documentation](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md#vxlan)
- [K3s 1.34.1+k3s1 Release Notes](https://github.com/k3s-io/k3s/releases/tag/v1.34.1+k3s1%2Bk3s1)
- [Kubernetes CNI Debugging](https://kubernetes.io/docs/tasks/debug/debug-cluster/debug-service/)

## Appendix: Diagnostic Commands Used

```bash
# Check CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# Check DNS service
kubectl get svc -n kube-system kube-dns

# Test pod-to-pod connectivity
ping <pod-ip>

# Check flannel interface
ip link show flannel.1
ip route show | grep 10.42

# Check VXLAN port
ss -ulpn | grep 8472

# Check bridge FDB entries
bridge fdb show dev flannel.1

# Check node IPs
kubectl get nodes -o wide

# Restart k3s
systemctl restart k3s

# Verify flannel came up
journalctl -u k3s -f | grep flannel
```
