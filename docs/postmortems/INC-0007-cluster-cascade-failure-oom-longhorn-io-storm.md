# INC-0007: Cluster-Wide Cascade Failure — OOM on nl-k8s-02 Triggering Longhorn I/O Storm and etcd Quorum Loss

**Date**: April 17, 2026
**Severity**: Critical (Entire Kubernetes cluster down, all workloads unavailable)
**Duration**: ~7 hours from first OOM to full recovery (08:41 → ~15:30 CEST)
**Affected Systems**: All k8s nodes (nl-k8s-01 through nl-k8s-04), all workloads (media, auth, home-automation, etc.), ingress, Tailscale-exposed services

## Summary

A memory exhaustion event on nl-k8s-02 at 08:41 CEST triggered a cascading failure that brought down the entire Kubernetes cluster over the following hours. The OOM killer on nl-k8s-02 massacred critical workloads (Radarr, victoria-metrics, vector, longhorn-instance-manager), corrupted multiple Longhorn volumes (remounted read-only), and made the node progressively unresponsive. The unavailability of Longhorn replicas on nl-k8s-02 then caused massive I/O error storms on nl-k8s-01 (which had replicas targeting nl-k8s-02), eventually overloading nl-k8s-01 until it too became unresponsive even though it remained alive at L2. With 2 of 4 etcd members unreachable, quorum was lost, k3s on nl-k8s-03 and nl-k8s-04 entered an `activating` loop, and the entire cluster went dark. Recovery required hard-rebooting all four nodes.

## Timeline

### Detection Phase
- **~07:00 CEST** (approximate): User reports issues with the cluster "this morning"; initial observation is that nl-k8s-02 and nl-k8s-03 cannot reach other nodes over 10.0.1.0/24 — pings route through `169.x.x.x` link-local addresses
- **~07:30 CEST**: User runs `ip route flush all && ip neigh flush all` on nl-k8s-02 and nl-k8s-03; connectivity partially restored for a few seconds, then instability continues
- **~08:00 CEST**: User runs `systemctl restart k3s` on nl-k8s-02 and nl-k8s-03, but cluster remains unstable; Tailscale-exposed workloads and ingress-exposed services (e.g. `media.cianfr.one`) unreachable

### Investigation Phase 1 — Pod Networking Broken on nl-k8s-02/03
- **~08:30 CEST**: Investigation reveals:
  - All 4 nodes `Ready` in kubectl, k3s `active`, flannel routes correct, VXLAN FDB entries correct
  - nl-k8s-01 and nl-k8s-04: local pod IPs reachable from host
  - **nl-k8s-02 and nl-k8s-03**: ARP resolves for pod IPs on `cni0`, but ICMP/TCP does not flow — local pods unreachable from their own host
  - MetalLB controller, ingress-nginx controller, CoreDNS, metrics-server all in CrashLoopBackOff on nl-k8s-02 (liveness probe timeouts)
  - `ingress-nginx-controller` Service had no endpoints, LoadBalancer IP flip-flopping between MetalLB-assigned (10.0.3.1) and k3s servicelb node-IP assignments
- **Hypothesis**: stale conntrack/netfilter state from the earlier route flush, cascading into kube-router iptables churn

### Investigation Phase 2 — Cluster Cascade
- **~10:00 CEST**: Situation deteriorates. nl-k8s-01 and nl-k8s-02 become completely unreachable:
  - nl-k8s-01: ARP resolves (MAC `6c:1f:f7:57:07:49` REACHABLE), TCP/22 accepts connections, but SSH times out during banner exchange — host is alive at L2/L3 but too bogged down to serve any request
  - nl-k8s-02: ARP is `INCOMPLETE` from all other nodes — VM not responding at L2 even though Proxmox reports it running
  - nl-k8s-03 and nl-k8s-04 reachable but k3s in `activating` state
- **k3s journal on nl-k8s-03 and nl-k8s-04**:
  - `Failed to test etcd connection: rpc error: code = Unavailable desc = connection error: desc = "transport: authentication handshake failed: context deadline exceeded"`
  - `dial tcp 10.0.1.2:2380: connect: no route to host`
  - Raft election loop (pre-vote, rejected, new election, repeat) — **etcd quorum lost**: 2/4 members unreachable
- Proxmox UI confirms nl-k8s-02 VM is alive but "barely responsive"

### Resolution Phase
- **~11:00 CEST**: User hard-reboots all four nodes (forced stop/start of nl-k8s-02 VM on Proxmox; power cycle of baremetal nl-k8s-01 and nl-k8s-04; reboot of nl-k8s-03)
- **~11:30 CEST**: Nodes come back online, etcd quorum re-established, k3s transitions to `active`, Kubernetes API restored
- **~15:00 CEST**: Cluster fully operational, workloads rescheduled and healthy

### Post-Incident Investigation
- **15:30 CEST onwards**: Log analysis across all four nodes reveals the true chronological cascade, starting much earlier than initial reports:
  - **08:41:23 CEST on nl-k8s-02**: OOM killer invoked, massacring processes
  - **09:17:01 CEST on nl-k8s-01**: Longhorn volume I/O errors begin
  - **10:28:43 CEST on nl-k8s-03**: NVMe-oF timeout storm begins
  - **~10:07 CEST on nl-k8s-04**: k3s fails to start (`result 'protocol'`)

## Root Cause

The root cause is a **memory exhaustion event on nl-k8s-02** that triggered a multi-stage cascade failure across the entire cluster. The failure chain:

### Stage 1 — Memory exhaustion on nl-k8s-02 (08:41:23)

Kernel logs on nl-k8s-02 show the OOM killer firing repeatedly starting at 08:41:23:

```
Apr 17 08:41:23 nl-k8s-02 kernel: Mem-Info:
  active_anon:1981556 inactive_anon:2237453
  free:36601 free_pcp:0
Apr 17 08:41:23 nl-k8s-02 kernel: Free swap  = 72kB
Apr 17 08:41:23 nl-k8s-02 kernel: Total swap = 8388604kB
Apr 17 08:41:24 nl-k8s-02 kernel: Out of memory: Killed process 39380 (Radarr) ...
Apr 17 08:41:24 nl-k8s-02 kernel: Out of memory: Killed process 5999 (vector) ...
Apr 17 08:41:25 nl-k8s-02 kernel: Out of memory: Killed process 46581 (victoria-metric) ...
Apr 17 08:41:24 nl-k8s-02 kernel: longhorn-instan invoked oom-killer ...
```

The VM had 20GB RAM + 8GB swap, and **both were fully consumed**:
- Total swap: 8 GB — **Free swap: 72 kB** (effectively zero)
- Normal zone: `free: 57328kB` vs `min: 57520kB` — **below the minimum watermark**
- HugePages_Total: 1024 × 2 MB = **2 GB reserved** and fully allocated (`HugePages_Free: 0`) — this 2 GB is permanently unavailable to the normal allocator, effectively shrinking usable RAM from 20 GB to ~18 GB

Victims (in order): Radarr (large .NET process), many `s6-*` supervisors, vector (telemetry log shipper), victoria-metrics (killed with `total-vm:14240256kB` = ~14 GB virtual), and critically **`longhorn-instance-manager`** invoked the OOM killer itself.

### Stage 2 — Longhorn volumes on nl-k8s-02 corrupt and remount read-only

Because the Longhorn instance manager was memory-pressured and its replica processes were being killed, the underlying EXT4 filesystems hosting Longhorn volumes failed:

```
Apr 17 08:41:24 nl-k8s-02 kernel: EXT4-fs error (device dm-17): ext4_journal_check_start:87: comm mosquitto: Detected aborted journal
Apr 17 08:41:24 nl-k8s-02 kernel: EXT4-fs (dm-17): Remounting filesystem read-only
Apr 17 08:41:24 nl-k8s-02 kernel: EXT4-fs error (device dm-21): ext4_journal_check_start:87: comm qbittorrent-nox: Detected aborted journal
Apr 17 08:41:24 nl-k8s-02 kernel: EXT4-fs (dm-21): Remounting filesystem read-only
Apr 17 08:41:24 nl-k8s-02 kernel: EXT4-fs error (device dm-4): __ext4_find_entry:1613: inode #131073: comm postgres: ...
```

Multiple Longhorn-backed EXT4 volumes aborted their journals and remounted read-only. The instance-manager OOM events continued cascading: processes writing to these volumes got stuck in uninterruptible I/O wait (D-state), further compounding memory pressure and delayed response to kubelet.

### Stage 3 — nl-k8s-01 I/O storm from unreachable Longhorn replicas (09:17:01)

~36 minutes later, nl-k8s-01 began experiencing a persistent I/O error storm on its Longhorn-mounted volumes:

```
Apr 17 09:17:01 nl-k8s-01 kernel: Buffer I/O error on dev dm-10, logical block 0, lost sync page write
Apr 17 09:17:01 nl-k8s-01 kernel: EXT4-fs (dm-10): I/O error while writing superblock
Apr 17 09:17:02 nl-k8s-01 kernel: EXT4-fs error (device dm-10): __ext4_find_entry:1613: inode #2: comm curl: reading directory lblock 0
...continuous for ~30 minutes...
Apr 17 09:37:10 nl-k8s-01 kernel: Aborting journal on device dm-13-8.
Apr 17 09:45:38 nl-k8s-01 kernel: EXT4-fs (dm-13): Remounting filesystem read-only
```

- `dm-10`, `dm-11`, `dm-13` were Longhorn volumes (no longer present after reboot — they only exist when attached). The commands affected (`curl`, `check`, `jellyfin`, `mass`) confirm these were application-mounted Longhorn volumes.
- Longhorn replica communication (Longhorn v1 engine replicas over TCP, plus Longhorn v2 over NVMe-oF) could not reach replicas on the OOM-locked nl-k8s-02, causing stuck I/O.
- Processes accessing these volumes piled up in D-state, consuming dispatcher slots and driving load average through the roof.
- `dhcpcd[1016]: route socket overflowed (rcvbuflen 106496) - learning interface state; drained 222 messages` — k3s/flannel kept churning routes as pods failed, overflowing dhcpcd's netlink socket.
- By ~10:13, nl-k8s-01 was so overloaded with stuck I/O that SSH could accept TCP but could not complete the banner handshake: `Apr 17 10:13:17 nl-k8s-01 sshd-session[1733981]: error: send_error: write: Broken pipe`.

### Stage 4 — nl-k8s-03 NVMe-oF timeout storm (10:28:43)

nl-k8s-03 began experiencing NVMe I/O timeouts across many virtual NVMe devices (Longhorn v2 NVMe-oF targets):

```
Apr 17 10:28:43 nl-k8s-03 kernel: nvme nvme13: I/O tag 24 (6018) type 4 opcode 0x1 (I/O Cmd) QID 3 timeout
Apr 17 10:28:43 nl-k8s-03 kernel: nvme nvme5: starting error recovery
...across nvme4, nvme5, nvme6, nvme8, nvme9, nvme13, nvme14...
Apr 17 10:29:15 nl-k8s-03 kernel: block nvme14n1: no usable path - requeuing I/O
```

With 2 of 4 nodes effectively dead for storage purposes (nl-k8s-02 down, nl-k8s-01 overwhelmed by its own I/O storm), Longhorn replicas on nl-k8s-03 had no healthy peers to replicate to — NVMe-oF connections timed out and were requeued repeatedly.

### Stage 5 — etcd quorum loss on nl-k8s-04

With nl-k8s-01 unreachable (hanging in I/O wait, not responding to etcd RPCs) and nl-k8s-02 completely off the network, etcd on nl-k8s-03 and nl-k8s-04 could only see each other — 2 of 4 members = **no quorum**:

```
Apr 17 10:07:19 nl-k8s-04 systemd[1]: k3s.service: Failed with result 'protocol'.
Apr 17 10:13:10 nl-k8s-03 k3s: dial tcp 10.0.1.2:2380: connect: no route to host
Apr 17 10:13:15 nl-k8s-03 k3s: raft: ca5070514f625752 is starting a new election at term 552
Apr 17 10:13:15 nl-k8s-03 k3s: received MsgPreVoteResp rejection from 6ba5dbdc805e0792
```

k3s on nl-k8s-04 repeatedly failed to start, leaving dozens of orphaned `containerd-shim` processes from the unclean terminations (`Found left-over process NNNN (containerd-shim) in control group while starting unit`). k3s on nl-k8s-03 stayed in `activating` forever.

### Why nl-k8s-02 ran out of memory

Proximate causes for the OOM:

1. **2 GB of hugepages reserved and never freed**: `HugePages_Total: 1024` × 2 MB (likely legacy config from Intel GPU plugin / DPDK experiments on a VM that has no DPDK use). This reduces usable memory from 20 GB to ~18 GB.
2. **Multiple memory-heavy workloads co-located**: Radarr (.NET), qBittorrent, postgres (CNPG Immich), victoria-metrics (VMSingle), vector, longhorn-instance-manager, longhorn replicas, ingress-nginx, CoreDNS, MetalLB — all scheduled on the same VM.
3. **No memory limits / resource quotas** on many workloads, letting a single runaway pod consume free memory.
4. **Swap enabled on a k8s node**: k8s has historically disliked swap; it masks OOM until it's too late and actively degrades Longhorn/etcd latency.

No specific trigger was identified (e.g. a Radarr search, an Immich scan, a VictoriaMetrics scrape burst) — this is consistent with the system slowly running out of memory until it tipped over at 08:41:23.

## Resolution

### Immediate Fix (Applied during the incident)

1. Force-stopped and restarted the nl-k8s-02 VM from Proxmox (`qm stop <vmid> && qm start <vmid>`)
2. Hard power-cycled nl-k8s-01 (baremetal, SSH non-functional)
3. Rebooted nl-k8s-03 and nl-k8s-04 to clear stuck state

After all four nodes came back online cleanly, etcd quorum re-established within a few minutes, k3s transitioned to `active`, and the Kubernetes API became responsive. Workloads were automatically rescheduled by the control plane. The cluster self-healed from there.

### Verification

```bash
kubectl --context=nl get nodes -o wide
# All 4 nodes Ready

kubectl --context=nl get pods -A --field-selector status.phase!=Running
# Only transient startup pods

ssh root@10.0.1.2 'free -h'
# Memory: ~5.5Gi used of 19Gi, swap 0B used (post-reboot baseline)
```

## Action Items

### High Priority

- [ ] **Remove hugepages reservation on nl-k8s-02** (and audit on all nodes): `HugePages_Total=1024` × 2 MB = 2 GB is reserved and never used. Reclaim this memory by setting `vm.nr_hugepages=0` (or removing the Nix kernel parameter that sets it). Audit all four nodes for similar unused reservations.
  ```bash
  # On each node, verify current state:
  grep -i huge /proc/meminfo
  # Then remove any nr_hugepages kernel boot parameter or sysctl setting in the NixOS module
  ```

- [ ] **Set memory limits on all high-memory workloads** to prevent single-pod memory runaway. Target workloads in priority order:
  - `media/radarr`, `media/sonarr`, `media/lidarr`, `media/prowlarr` (.NET apps, known memory leakers)
  - `media/qbittorrent` (can consume a lot when many torrents active)
  - `media/immich-*` (ML / CNPG cluster)
  - `telemetry/vmsingle-vm`, `telemetry/vmagent-vm`, `telemetry/victorialogs-*`
  - `default/attic-*`
  - `longhorn-system/instance-manager-*` (review Longhorn's `guaranteedInstanceManagerCPU` / memory request settings)

- [ ] **Disable swap on all k8s nodes**. Swap is actively harmful on k8s nodes hosting latency-sensitive workloads like etcd and Longhorn. When swap fills, the OOM killer takes much longer to act, during which time etcd heartbeats and Longhorn replica I/O become extremely slow, triggering exactly the cascade observed here. In NixOS, set `swapDevices = [];` in the k8s-node module (or set `swappiness = 0` if we absolutely need swap for emergency overflow).

- [ ] **Spread memory-hungry workloads across nodes**: the current scheduling placed Radarr, victoria-metrics, postgres (Immich), ingress-nginx, MetalLB, CoreDNS, metrics-server, and longhorn-instance-manager all on nl-k8s-02 simultaneously. Add `podAntiAffinity` or `topologySpreadConstraints` to prevent memory-heavy apps from clustering on a single node.

- [ ] **Add memory/OOM Prometheus alerts**:
  ```promql
  # Alert if node memory utilization > 85% for 10m
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.85

  # Alert on OOM kill events
  increase(node_vmstat_oom_kill[5m]) > 0

  # Alert on swap in use on k8s nodes (should be 0)
  node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes < 0.99
  ```

### Medium Priority

- [ ] **Review Longhorn replica topology**: for critical volumes, ensure 3 replicas exist so that the loss of a single node does not cause cascading I/O stalls on other nodes. Audit `Volume` resources in the `longhorn-system` namespace:
  ```bash
  kubectl --context=nl get volumes.longhorn.io -n longhorn-system -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.numberOfReplicas,STATE:.status.state
  ```

- [ ] **Tune Longhorn I/O timeouts** to fail-fast when a replica is unreachable, rather than queueing I/O indefinitely and causing D-state process pileup:
  - `engine-replica-timeout` (default 8s) — consider lowering for stateless workloads
  - `replica-replenishment-wait-interval`
  - Review Longhorn v2 (NVMe-oF) TCP timeout settings — this incident showed they hold queued I/O for minutes

- [ ] **Add etcd quorum alerts** so we're aware of impending cluster-wide failure:
  ```promql
  etcd_server_has_leader == 0
  etcd_server_proposals_failed_total > 0
  ```

- [ ] **Document emergency runbook** for this failure mode:
  1. Check `kubectl get nodes` — if all show `Ready` but apps are failing, check individual node pod networking
  2. Check `journalctl -u k3s` for etcd quorum failures
  3. If >1 node is unresponsive at the etcd level, reboot the unresponsive node(s) first before attempting k3s/cni troubleshooting on healthy nodes
  4. Never run `ip route flush all` / `ip neigh flush all` on an active k8s node — this causes CNI/kube-router iptables churn and conntrack storms without addressing the actual issue

### Low Priority

- [ ] **Review VictoriaMetrics memory budget**: the VMSingle instance was OOM-killed with 14 GB virtual / 832 MB anon RSS. Set explicit `-memory.allowedPercent` and pod memory limits.

- [ ] **Investigate why `ip route flush` was attempted during the earlier phase**: the user's recollection of "routing through 169.x.x.x addresses" during the initial investigation corresponds to the stale routes that flannel/kube-router create on veth interfaces (`169.254.0.0/16 dev veth...`). This is normal flannel behavior and not indicative of a routing problem on its own.

- [ ] **Investigate Proxmox VM memory ballooning** on nl-k8s-02 (VM on nl-pve-01): confirm ballooning is disabled and the VM has guaranteed memory allocation (not dynamic). Ballooning can exacerbate OOM situations.

- [ ] **Consider moving nl-k8s-02 off Proxmox** or at minimum increase its RAM allocation from 20 GB → 32 GB, given it hosts ~60+ pods in the `kubectl get pods` snapshot.

## Lessons Learned

### What Went Well

- **etcd quorum protection worked as designed**: k3s correctly refused to continue serving the Kubernetes API when quorum was lost, preventing split-brain writes to the cluster state.
- **Recovery was clean**: once all four nodes were rebooted simultaneously, the cluster self-healed within a few minutes — no etcd corruption, no need for manual `etcd snapshot restore` or `--cluster-reset`.
- **GitOps with ArgoCD meant zero configuration drift**: all workloads respawned in the correct state without manual intervention.

### What Didn't Go Well

- **Single-node OOM brought down the entire cluster**: the blast radius of a memory exhaustion on one worker was catastrophic, primarily due to Longhorn's strong consistency guarantees and the TCP-based replica communication that stalls when peers become unreachable (see also INC-0004).
- **No early warning**: no alerts fired before OOM. Memory utilization was presumably climbing for hours or days, but we had no visibility.
- **Initial investigation was misdirected**: the apparent "network issue" on nl-k8s-02/03 (169.x.x.x routing, unreachable pod IPs) was a symptom, not the cause. The flannel/kube-router layer was actually working correctly — it was the pods themselves that were unresponsive due to I/O stalls and OOM pressure on the node.
- **`ip route flush all` was a red herring**: the user ran this in an attempt to recover connectivity, but it likely made things worse by causing a brief period where flannel had no routes, and it did not address the underlying memory/Longhorn issue.
- **Swap hid the problem**: 8 GB of swap delayed the OOM event and prolonged the degradation phase (slow I/O, high load average, unresponsive workloads) before the OOM killer finally acted at 08:41.
- **SSH-alive-but-dead is a painful failure mode**: nl-k8s-01 accepted TCP but couldn't complete SSH handshakes, making remote recovery impossible. IPMI / out-of-band management on the baremetal nodes would have helped here.

### What We Learned

- **k8s nodes should not have swap enabled**. Full stop. Either upsize the node or let the OOM killer act promptly.
- **Hugepages reservation should be audited and justified**. Reserving memory that's never used is a recipe for premature OOM.
- **Longhorn is a very tight coupling between nodes**: a single degraded node can stall I/O cluster-wide. Consider evaluating whether non-critical workloads (e.g. media scratch volumes) should use `local-path-provisioner` or `hostPath` instead of Longhorn to reduce blast radius.
- **Co-locating memory-heavy pods is dangerous**: without `topologySpreadConstraints`, the scheduler packed nl-k8s-02 tightly with memory consumers.
- **OOM cascades are slow but devastating**: the failure unfolded over 2+ hours from first OOM (08:41) to full cluster death (~10:15). Early detection and alerting could have allowed manual intervention (e.g. cordoning nl-k8s-02, evicting pods) before the cascade became irreversible.

## Related Incidents

- **INC-0004**: Temporary Cluster Connectivity Loss - Router Connection Tracking Table Full (2025-11-19)
  - Similar pattern: Longhorn I/O errors as a secondary symptom of a different underlying issue (conntrack exhaustion vs. OOM).
  - Reinforces the finding that **Longhorn v2 NVMe-oF replica I/O is highly sensitive to any transient network or node issue**, and that apparent "disk errors" in this cluster frequently have a non-storage root cause.
- **INC-0001**: Flannel VXLAN Failure After k3s Upgrade
  - Reference for the initial (incorrect) hypothesis during this incident, which focused on flannel/CNI state.

## References

- Kubernetes swap documentation: https://kubernetes.io/docs/concepts/architecture/nodes/#swap-memory
- Linux OOM killer internals: https://www.kernel.org/doc/gorman/html/understand/understand016.html
- Longhorn best practices: https://longhorn.io/docs/latest/best-practices/
- etcd performance tuning: https://etcd.io/docs/v3.5/tuning/
- NixOS hugepages configuration: `boot.kernelParams = [ "hugepages=N" ]`
