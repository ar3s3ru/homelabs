# INC-0009: nl-pve-01 Memory-Overcommit Hypervisor Hang → Single-Node Variant of the Longhorn Webhook / Flannel Deadlock

**Date**: April 23, 2026
**Duration**: ~5 hours end-to-end (~18:07 CEST first dark → ~23:15 CEST cluster healthy again)
  - ~4h40m of nl-pve-01 / nl-k8s-02 hard downtime (18:07 → 22:48 CEST, requiring manual power-cycle)
  - ~26 minutes of post-boot pod-networking outage on nl-k8s-02 (22:48 → ~23:14 CEST)
**Impact**: Partial cluster degradation. All workloads scheduled on nl-k8s-02 unavailable for the full window; cluster-wide services with replicas only on nl-k8s-02 affected. Longhorn volumes with replicas on nl-k8s-02 went `faulted`.
**Severity**: High (P1). Not a full cluster outage only because the other 3 k3s nodes stayed healthy.

## tl;dr

A user-triggered Sonarr indexer search generated a burst of Longhorn cross-node replica I/O which pushed **nl-pve-01** — a 31 GiB mini-PC running a 20 GiB VM (`nl-k8s-02`) plus an 8 GiB TrueNAS VM with zero ballooning headroom — into a kernel-level I/O livelock. The hypervisor stopped writing logs at 18:07 CEST without a panic, oops, OOM, MCE, or thermal event; it simply stopped, killing its guest VMs with it. A manual power-cycle at ~22:47 CEST recovered the host, but nl-k8s-02 then walked into the **exact deadlock documented in INC-0008** (this time as a single-node variant rather than cluster-wide): because Longhorn's admission webhooks still had `failurePolicy: Fail` (the INC-0008 action item #1 was never completed), and because nl-k8s-02 could not reach the webhook backend pods on other nodes (its flannel had not started yet), every core `v1.Node` UPDATE that k3s issued during `configureNode()` was rejected with `context deadline exceeded`, which gated `flannel.Run()`, which kept pod networking off, which kept the webhook unreachable — the same circular dependency as INC-0008, just localized to one node. Flipping `failurePolicy` to `Ignore` on both the validating and mutating webhook configurations broke the deadlock in ~30 s. The root crash cause on nl-pve-01 remains the underlying problem; this incident would not have happened had the hypervisor not hung in the first place, and even the host hang would not have turned into a 26-minute cluster-side outage had INC-0008's `failurePolicy: Ignore` fix been persisted in Git.

## Timeline

All times CEST.

### Pre-incident — Quiet state
- **Days leading up**: Cluster nominally healthy. nl-pve-01 holding `truenas` (VM 100, 8 GiB) and `nl-k8s-02` (VM 101, 20 GiB) on a box with 31 GiB total RAM and **no ballooning configured**. Steady-state RAM usage sits at ~30 GiB / 31 GiB after kernel + qemu overhead. The system is riding the edge of OOM every second; any guest working-set spike that causes the host to touch swap creates swap-vs-VM-I/O contention on the same Kingston OM8 consumer NVMe.
- `longhorn-pre-upgrade` Job has been stuck in `deletingDependents: true, beingDeleted: true, field is immutable` since the last Longhorn Helm reconcile — the k3s garbage collector has been retrying every ~10 s for days, generating constant background API-server churn but not causing visible problems.

### The crash — Host dies silently
- **~17:30 CEST Apr 23**: User triggers a search in Sonarr (which runs on nl-k8s-03, not nl-k8s-02). The search kicks off significant I/O on the PVC backing Sonarr's library — a Longhorn volume replicated to nl-k8s-02 (among others). Replica writes begin streaming across the cluster network to the longhorn-instance-manager pod on nl-k8s-02.
- **17:59:40**: Last "normal" log line on nl-pve-01 is the routine `apt-daily.service`.
- **18:07:06**: Last log line on nl-pve-01 is a routine `pmxcfs [dcdb] notice: data verification successful`. After this, **zero further log output** until the post-reboot boot.
- **~18:07–18:16**: The guest nl-k8s-02 continues to log for another ~9 minutes (journal buffer still being written), ending at **18:16:12** with a mundane k3s etcd snapshot message. No hung-task, no softlockup, no OOM, no I/O error — the guest vCPUs simply stopped receiving cycles from the host.
- **18:16:12 → 22:47**: Both machines fully dark. Ping/SSH/web UI all unresponsive. No thermal, no MCE, no kernel panic — the host kernel is in a D-state livelock it cannot recover from and cannot log.
- User notices via failing Tailscale-exposed services that some workloads are unavailable; `kubectl get nodes` shows `nl-k8s-02` as `NotReady`.

### Recovery of the hypervisor
- **~22:47 CEST**: User physically power-cycles nl-pve-01.
- **22:47:52**: nl-pve-01 kernel boots (kernel 6.14.8-2-pve). `last -x` records the prior session as "crash" — no clean shutdown was ever performed.
- **22:48:02**: PVE userland up.
- **22:48:33**: nl-k8s-02 guest (NixOS, kernel 7.0.0) boots.

### Post-boot — The deadlock begins on nl-k8s-02
- **22:48:43**: First k3s start attempt on nl-k8s-02 fails immediately: `listen tcp 10.0.1.2:2380: bind: cannot assign requested address` — the `ens18` virtio-net interface had not yet obtained its address from DHCP when k3s tried to bind etcd's peer listener. k3s crashes, systemd schedules restart.
- **22:48:49**: Second k3s start succeeds at the etcd level. Etcd joins the quorum. Kube-apiserver starts. The node reports `Ready` to the kubelet heartbeat (kubelet speaks over the host network, not via CNI).
- **22:49:02**: k3s logs:
  ```
  Waiting for cloud-controller-manager privileges to become available
  Waiting for untainted node
  ```
  (The INC-0008 signature, immediately recognizable.)
- **22:49:12 onward**: k3s begins its `configureNode()` loop, trying to set annotations, labels, and the control-plane role on its own `v1.Node` object. Every UPDATE is rejected by the kube-apiserver's admission chain:
  ```
  Failed calling webhook, failing closed validator.longhorn.io:
    failed to call webhook "validator.longhorn.io": failed to call webhook:
    Post "https://longhorn-admission-webhook.longhorn-system.svc:9502/v1/webhook/validation?timeout=10s":
    context deadline exceeded
  Failed to set annotations and labels on node nl-k8s-02: Internal error occurred: failed calling webhook "validator.longhorn.io"…
  Unable to set control-plane role label: Internal error occurred: failed calling webhook "validator.longhorn.io"…
  ```
  The webhook Service resolves to three healthy backend pods on nl-k8s-01, nl-k8s-03, nl-k8s-04 (all on `10.42.x.x` — the Flannel overlay). **But nl-k8s-02 has no Flannel, no `cni0`, no `flannel.1`, and therefore no route to 10.42.x.x.** Every outbound webhook call times out after 10 s.
- The embedded flanneld goroutine is gated on `configureNode()` success (k3s 1.35 executor behavior from PR #13262, same as INC-0008), so flannel never starts, so pod networking never comes up, so the webhook call never succeeds. Deadlock.

### Investigation
- **~22:55**: Operator begins investigation. Surface symptoms inspected first: `kubectl describe node`, `kubectl get pods -A --field-selector spec.nodeName=nl-k8s-02`.
- 23 pods on nl-k8s-02 are in `Unknown` or `ContainerCreating`, including `longhorn-manager-mqnfk`, `argocd-application-controller-0`, `argocd-redis-ha-server-0`, multiple svclb daemonsets, `immich-cnpg-cluster-1`, `authelia-cnpg-cluster-1`, `lldap-cnpg-cluster-1`, `ticket-printer-cnpg-cluster-1`, etc. Events show `FailedCreatePodSandBox: … loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory` — the exact text from INC-0008.
- On the node itself:
  - `/run/flannel/` does not exist. `ip -br link` shows no `flannel.1`/`cni0`.
  - `journalctl -u k3s -b | grep flannel` returns zero k3s lines. No `Starting flannel with backend vxlan`.
  - Comparing to nl-k8s-01 confirms the difference: healthy node has `flannel.1`, `flannel-v6.1`, and `cni0` up.
- The RCA of the *host* crash in parallel: PVE journal is silent 18:07 → 22:48; no hung-tasks, no OOM, no MCE, no thermal, no NVMe errors, no AER. `last -x` says `crash`. `free -h` post-reboot shows 30 GiB / 31 GiB used after only 2 VMs started. VM 101 config confirms `memory: 20480` with **no `balloon:` line** → no actual ballooning. This is a memory-overcommit-induced kernel livelock, not a hardware or software fault in the traditional sense.
- Operator recognizes the post-boot symptoms as a replay of INC-0008 and cross-checks: `validator.longhorn.io` still has `failurePolicy: Fail`; action item #1 from INC-0008 ("make the webhook `Ignore` persistent in Nix/ArgoCD") was never completed — ArgoCD re-synced the Longhorn Helm chart at some point after the INC-0008 live patch, reverting `failurePolicy` to the chart default of `Fail`.

### Resolution
- **~23:13 CEST**: Operator runs the exact runbook from INC-0008 §300-333:
  ```bash
  ssh root@nl-k8s-01 "kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml \
    > /root/longhorn-webhook-validator.yaml.bak.INC-0009.$(date +%s)"
  ssh root@nl-k8s-01 "kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator  -o yaml \
    > /root/longhorn-webhook-mutator.yaml.bak.INC-0009.$(date +%s)"

  ssh root@nl-k8s-01 "kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
    --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
  ssh root@nl-k8s-01 "kubectl patch mutatingwebhookconfiguration longhorn-webhook-mutator \
    --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
  ```
- **~23:14 CEST (+30 s)**: Flannel initializes on nl-k8s-02. `/run/flannel/subnet.env` appears. `flannel.1`, `flannel-v6.1`, and `cni0` interfaces come up.
- **~23:15 CEST**: `longhorn-manager-mqnfk` transitions out of `ContainerCreating`. Longhorn node object goes `Ready: True`. Most `Unknown` pods on nl-k8s-02 are re-created by their controllers. Final state: 23 `Running`, 1 `ContainerCreating` (transient), 2 `CrashLoopBackOff` (pre-existing — Kavita startup-probe and Immich backoff, not related to this incident).

## Root Cause

**Two independent root causes stacked.**

### Primary (host hang): Memory overcommit on nl-pve-01

The Proxmox host nl-pve-01 has 31 GiB of physical RAM. Its two guests are configured with:
- `truenas` (VM 100): `memory: 8196`
- `nl-k8s-02` (VM 101): `memory: 20480`, **no `balloon:` directive**

Absent a `balloon:` line, Proxmox's default behavior leaves the VM at its `memory:` maximum with no ballooning pressure from the host. Combined with kernel + qemu process overhead (~2–3 GiB) and pmxcfs/corosync/PVE daemons, steady-state host memory usage sits at ~30 GiB / 31 GiB, leaving essentially zero headroom. Post-reboot evidence: `free -h` shows `30Gi used, 587Mi free` within 3 minutes of boot with only these two VMs running.

When the user's Sonarr search triggered a burst of Longhorn cross-node replica I/O landing on the longhorn-instance-manager pod inside nl-k8s-02, the guest's working set grew. Because the host was already full, the Linux VM subsystem on the host began paging VM memory to swap. The swap device is the **same** Kingston OM8 NVMe that holds the VM's virtual disk (`local-lvm:vm-101-disk-0`). A qemu iothread (`iothread=1` with `scsihw: virtio-scsi-single`) trying to service virtio-scsi requests from the guest — which requires reading pages that have been swapped out — deadlocks against the swap-in path competing for the same NVMe queues. Individual kernel tasks go into uninterruptible D-state on the NVMe; no single subsystem reports a fault (no OOM kill, no I/O error, no softlockup), so no panic is triggered; the system simply stops making progress across all user-visible surfaces (ssh, journald, pmxcfs, console). There is no way to log a message about this because the logging path is also blocked on the NVMe.

**Contributing hardware factor**: the Kingston OM8TAP41024K1 is a consumer QLC NVMe reporting 43% wear after only 803 power-on hours (roughly 33 days equivalent) and 41.3 TB written in that window — approximately 1.2 TB/day of write amplification, consistent with heavy swap + VM I/O on a drive not designed for this workload. The drive has logged 14 "Unsafe Shutdowns" and no media errors, so it is not defective — it's simply not the right tool for the job. Its random I/O performance collapses sharply under sustained mixed load, which compounds the livelock-under-pressure behavior described above.

### Secondary (cluster-side outage after host recovery): INC-0008 deadlock recurrence

Independently, INC-0008's `failurePolicy: Fail` chicken-and-egg between Longhorn admission webhooks and Flannel startup re-occurred as soon as nl-k8s-02 came back up — this time in a new "single-node cold-boot on a cluster that was mostly healthy" variant rather than INC-0008's "all four nodes rolling-rebooted at once" variant. The mechanism is identical: k3s's `configureNode()` → core `v1.Node` UPDATE → dispatched to `validator.longhorn.io` with `failurePolicy: Fail` → the webhook call must be routed to pod-network IPs (10.42.x.x) → the bootstrapping node has no pod network → timeout → UPDATE rejected → k3s's embedded flanneld never starts → loop.

This outage would not have happened if INC-0008's action item #1 had been completed: the patch to `kube/longhorn-system/longhorn/kustomization.yaml` setting `failurePolicy: Ignore` on both webhook configurations. That action item was accepted during the INC-0008 writeup on Apr 19 and was never implemented. ArgoCD's subsequent reconciliation of the Longhorn Helm chart reverted the in-cluster patch applied during the INC-0008 resolution, restoring `failurePolicy: Fail` to both webhooks. Evidence: the `longhorn-pre-upgrade` Job found stuck in `deletingDependents: true, field is immutable` during this investigation is from a Helm reconcile that occurred *after* INC-0008 (the job's owner UID `b7d081e1-…` does not match the one present during INC-0008), confirming that ArgoCD did reconcile the chart — and that reconcile reset the live `failurePolicy`.

## Detection

Primary diagnostic trail (during this incident):

```bash
# 1. Confirm the host actually hung, not just lost network
ssh root@nl-pve-01 'last -x reboot | head -5; journalctl --list-boots | tail -3'
# Shows "crash" between previous and current boot, and a ~4h40m gap with no shutdown record.

# 2. Confirm no software cause on the host
ssh root@nl-pve-01 'journalctl -b -1 -p warning --no-pager | tail -30'
# -- No entries --
ssh root@nl-pve-01 'journalctl -b -1 -k --no-pager | grep -iE "hung_task|oom|mce|nvme|thermal|softlockup"'
# -- No entries matching --

# 3. Confirm memory state post-recovery (smoking gun)
ssh root@nl-pve-01 'free -h; qm config 101 | grep -E "^(memory|balloon)"'
# Mem: 30Gi used / 31Gi total, 587Mi free
# memory: 20480
# (no balloon line)

# 4. Confirm NVMe is worn but not broken
ssh root@nl-pve-01 'smartctl -a /dev/nvme0n1 | grep -E "Percentage Used|Unsafe Shutdowns|Data Units Written"'
# Percentage Used: 43%
# Unsafe Shutdowns: 14
# Data Units Written: 80,827,825 [41.3 TB]

# 5. After reboot, confirm INC-0008 deadlock symptoms on nl-k8s-02
ssh root@nl-k8s-02 'ls /run/flannel/ 2>&1; ip -br link | grep -E "flannel|cni"'
# /run/flannel/: No such file or directory (and no interfaces)
ssh root@nl-k8s-02 'journalctl -u k3s -b --no-pager | grep -iE "Starting flannel|Wrote flannel"'
# Empty — flanneld never started.

# 6. The smoking gun for the secondary cause
ssh root@nl-k8s-02 'journalctl -u k3s -b --no-pager | \
  grep -iE "failing closed validator.longhorn|Unable to set control-plane|Failed to set annotations"' | head
# Spam of webhook timeouts.

# 7. Confirm failurePolicy is still Fail (INC-0008 action item #1 never completed)
ssh root@nl-k8s-01 'kubectl get validatingwebhookconfiguration longhorn-webhook-validator \
  -o jsonpath="{.webhooks[0].failurePolicy}"; echo'
# Fail
ssh root@nl-k8s-01 'kubectl get mutatingwebhookconfiguration longhorn-webhook-mutator \
  -o jsonpath="{.webhooks[0].failurePolicy}"; echo'
# Fail
```

## Resolution

### Immediate fix (applied during incident)

Applied the INC-0008 runbook verbatim. From any node with cluster kubectl access:

```bash
# Back up live state
kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml \
  > /root/longhorn-webhook-validator.yaml.bak.INC-0009.$(date +%s)
kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator   -o yaml \
  > /root/longhorn-webhook-mutator.yaml.bak.INC-0009.$(date +%s)

# Flip failurePolicy: Fail → Ignore on both webhooks
kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
  --type=json --patch='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
kubectl patch mutatingwebhookconfiguration longhorn-webhook-mutator \
  --type=json --patch='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

Flannel came up on nl-k8s-02 within ~30 s. Longhorn manager scheduled, node transitioned back to Longhorn `Ready: True`, faulted replicas began rebuilding.

### Verification

```bash
# nl-k8s-02 has flannel state + interfaces
ssh root@nl-k8s-02 'ls /run/flannel/subnet.env && ip -br link | grep -E "flannel|cni"'

# k3s made progress past configureNode()
ssh root@nl-k8s-02 'journalctl -u k3s -b --no-pager --since "1 minute ago" \
  | grep -iE "Starting flannel|Set control-plane role label"'

# Cluster pod distribution on nl-k8s-02 is healthy
kubectl --context=nl get pods -A --field-selector spec.nodeName=nl-k8s-02 --no-headers \
  | awk '{print $4}' | sort | uniq -c
# 23 Running, 1 ContainerCreating (transient), 2 CrashLoopBackOff (pre-existing, unrelated)

# Longhorn considers all 4 nodes ready
kubectl --context=nl -n longhorn-system get node.longhorn.io
# All 4 nodes: READY=True, SCHEDULABLE=True
```

## Contributing Factors

1. **No ballooning configured on nl-pve-01 VMs.** Despite Proxmox supporting memory ballooning out of the box, neither VM 100 nor VM 101 has a `balloon:` directive. This means memory is reserved for guests at their max, host has no mechanism to reclaim idle guest pages under pressure, and the host sits at ~30 GiB / 31 GiB permanently.

2. **Host RAM is undersized for its workload.** A 31 GiB host carrying 28 GiB worth of statically-assigned VMs is fundamentally over-provisioned even before considering kernel + qemu overhead and cache. Any spike pushes into swap; any swap pushes into the same NVMe that's also serving the VMs. There is no safety margin.

3. **Consumer QLC NVMe on a virtualization host.** The Kingston OM8TAP41024K1 is a budget drive optimized for low-duty-cycle consumer workloads. Under sustained mixed VM I/O + swap traffic, its random-IOPS performance degrades sharply (SLC cache fills, drops to QLC native speed ~50 MB/s for sustained writes). 43% wear after 33 days of use confirms this is the wrong class of drive for the workload. A hung hypervisor on a consumer NVMe under load is a well-known failure mode.

4. **INC-0008 action item #1 was never completed.** The recommendation to make `failurePolicy: Ignore` on the Longhorn webhooks persistent in Git (via Kustomize patch or Helm override) was filed but not implemented. ArgoCD's subsequent reconciliation of the Longhorn chart (evidence: the stuck `longhorn-pre-upgrade` Job from a post-INC-0008 Helm run) reverted the live patch. The cluster was once again vulnerable to the same deadlock.

5. **k3s starts before `ens18` is fully configured on nl-k8s-02.** The first k3s start attempt at 22:48:43 crashed on `bind: cannot assign requested address` for 10.0.1.2, indicating the service started before DHCP completed on the virtio-net interface. k3s's systemd unit has `After=network-online.target`, but `network-online.target` was satisfied while `ens18` was still negotiating. This is a latent boot-race that doesn't usually cause user-visible issues because systemd's restart-on-failure recovers within 5 seconds — but it's unclean, and under a recently-crashed hypervisor (where everything is slower) it might produce longer timing windows that expose other races.

6. **Sonarr, the indexing-heavy pod that triggered the Longhorn I/O storm, has no resource requests or limits.** `QoS Class: BestEffort`. A single user-initiated search can therefore generate unbounded cross-node Longhorn I/O, and by extension unbounded pressure on any nl-pve-01-hosted replica target. The same is true for the rest of the `*arr` stack and several other workloads in the cluster.

7. **`longhorn-pre-upgrade` Job is stuck and adds constant churn.** Every ~10 s the k3s garbage collector tries to sync a Job that cannot be mutated (`field is immutable`). This is ambient noise pre-existing this incident but deserves to be cleaned up, since it adds to the background cost the API server and etcd pay on every node — including the already-stressed nl-k8s-02 during bootstrap.

8. **No kdump, no pstore retention, no panic-on-softlockup.** The host hang on nl-pve-01 left literally zero forensic evidence: empty `/sys/fs/pstore/`, no crash dumps, no ring-buffer remnants. We cannot distinguish between "kernel I/O livelock on NVMe", "kernel bug in 6.14.8-2-pve under swap pressure", or "silent hardware fault with no firmware-reported signal". Next occurrence will be just as blind unless we enable forensic capture ahead of time.

## Impact

**User-facing:**
- All services with sole or primary replicas on nl-k8s-02 unavailable from 18:07 → ~23:15 (~5h).
- Cluster-wide services whose endpoints include nl-k8s-02 pods (MetalLB svclb daemonsets, Longhorn CSI, node-feature-discovery) ran degraded.
- Tailscale-exposed services unreachable when their backing pod happened to be on nl-k8s-02.
- Longhorn volume `pvc-9a7bfd06-2192-4634-aa72-cca075069faa` went `faulted` for the duration; it rebuilt from the healthy replicas on other nodes once nl-k8s-02 came back.

**Operational:**
- No data loss. Etcd quorum held throughout the incident (nl-k8s-01/03/04 remained in majority).
- Cluster state on disk was clean; the broken node needed only `failurePolicy` patched to recover.
- ArgoCD was effectively paused on nl-k8s-02 workloads during the outage, then caught up automatically.
- Manual physical intervention was required to power-cycle nl-pve-01, because the hypervisor was unreachable even via IPMI / console (this particular mini-PC has no out-of-band management). This is why the host-side outage lasted 4h40m rather than the minutes it should have.

## Action Items

### High priority

- [ ] **Persist `failurePolicy: Ignore` on both Longhorn webhooks in Git** (INC-0008 action item #1, finally). Add Kustomize patches to `kube/longhorn-system/longhorn/kustomization.yaml` targeting both `ValidatingWebhookConfiguration/longhorn-webhook-validator` and `MutatingWebhookConfiguration/longhorn-webhook-mutator`. Verify `kustomize build --enable-helm` renders the patched YAML correctly before merging. This closes the INC-0008 regression window permanently.

- [ ] **Enable ballooning on VM 101 (`nl-k8s-02`) and VM 100 (`truenas`).** For nl-k8s-02, setting `balloon: 8192` (or `16384`) with `memory: 20480` gives the host a mechanism to reclaim idle guest RAM when under pressure, without sacrificing the guest's ability to burst up to 20 GiB when it actually needs it. For TrueNAS, ballooning is more delicate (ZFS ARC dislikes memory churn); recommend `balloon: 4096` or leaving it alone but first reducing `memory:` to 6144. Apply with `qm set 101 --balloon 8192 --memory 16384` after draining the node for a brief restart.

- [ ] **Reduce `nl-k8s-02` memory cap to 16 GiB** (`qm set 101 --memory 16384`). k3s + the currently-scheduled pods on that node do not need 20 GiB, and shaving 4 GiB back to the host gives meaningful headroom. Combined with ballooning, this dramatically reduces the chance of hitting the swap-thrash livelock.

- [ ] **Set CPU/memory requests and limits on every `*arr` pod and the other no-QoS workloads.** Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, Sabnzbd — all currently `QoS: BestEffort`. Move them to `Burstable` or `Guaranteed` via the respective Helm `values.yaml` in `kube/media/*/`. Start with `requests: 100m CPU / 256Mi memory`, `limits: 1 CPU / 1Gi memory` and tune from observed usage. ArgoCD also has the same problem (`argocd-server`, `argocd-repo-server` lack memory requests, producing the HPA error flood in the logs) — fix in `kube/argo-system/argocd/values.yaml`.

- [ ] **Replace the consumer Kingston OM8 NVMe on nl-pve-01 with a DC-grade drive** (e.g. Samsung PM9A3, Micron 7450 Pro, Kioxia CD8, Solidigm D7-P5510). 43% wear in 33 days is a runaway failure trajectory — at current rates the drive will exceed endurance within a year, and its sustained-mixed-random performance is part of why the host hung in the first place. Plan a maintenance window to shutdown, swap, and restore-from-backup (or migrate VMs off).

- [ ] **Document the INC-0009 unstick procedure in the runbook.** The INC-0008 runbook already covers the webhook-patch steps; add a short runbook entry describing "if the webhook patch isn't persisted yet and a single node comes back from a hard reboot, apply it again live" and a pointer to the expected state once the action item above is landed.

### Medium priority

- [ ] **Delete the stuck `longhorn-pre-upgrade` Job** to silence the k3s GC error flood:
  ```bash
  kubectl -n longhorn-system delete job longhorn-pre-upgrade --cascade=foreground
  ```
  ArgoCD will recreate it via its `argocd.argoproj.io/hook: PreSync` annotation on the next sync. Monitor the Helm release completing cleanly afterwards; if it still gets stuck, verify the patch added for action item #1 above is correctly rendered.

- [ ] **Enable kernel forensics on nl-pve-01** so the next hang produces evidence:
  - Configure `kernel.softlockup_panic=1` and `kernel.hung_task_panic=1` with a reasonable `hung_task_timeout_secs` (e.g., 300) via `/etc/sysctl.d/99-pve-forensics.conf`.
  - Add `crashkernel=256M` to the kernel cmdline and install/enable `kexec-tools` + `kdump-tools`, so a panic produces a `/var/crash/vmcore`.
  - Ensure `pstore` is mounted and enabled (EFI variable backend) so the kernel ring buffer survives a forced reset.
  - Add `vm.swappiness=10` and `vm.min_free_kbytes=524288` to reduce the probability of swap-thrash livelocks in the first place.

- [ ] **Persist `qemu-server` per-VM logging.** `/var/log/qemu-server/` on nl-pve-01 is currently empty — per-VM qemu stderr is not retained across host reboots. Investigate why (possibly related to the install path or a `tmpfs`?) and ensure future qemu output from each VM is captured and rotated.

- [ ] **Add a Prometheus alert: "Longhorn webhook has zero endpoints".** From INC-0008 action item — still relevant. This is the canary for the deadlock returning in any form.
  ```promql
  kube_endpoint_address_available{namespace="longhorn-system",endpoint="longhorn-admission-webhook"} == 0
  ```
  Warning after 1m, critical after 5m.

- [ ] **Add a Prometheus alert: "hypervisor memory pressure sustained".** Using node_exporter PSI metrics on nl-pve-01:
  ```promql
  avg_over_time(node_pressure_memory_stalled_seconds_total{instance=~"nl-pve-.*"}[5m]) > 0.3
  ```
  Fires before the host hangs, giving us a chance to act.

- [ ] **Add an external uptime monitor for nl-pve-01 and cluster nodes** hosted off-cluster (e.g., UptimeRobot, or a tiny VPS running Prometheus blackbox-exporter). The only reason this outage was caught in ~30 minutes rather than several hours was that the user was actively using a cluster service. Off-cluster monitoring would page on loss-of-ping within a minute.

- [ ] **Consider IPMI / out-of-band management for nl-pve-01.** The mini-PC apparently has no remote power control. Evaluate (a) a cheap network-controllable PDU, (b) a Pi-based soft power controller wired to the front-panel power button, or (c) relocating this workload to hardware with BMC. Any of these would reduce "hypervisor hang" recovery time from hours to minutes.

### Low priority

- [ ] **Fix the k3s-starts-before-ens18-is-up boot race on nl-k8s-02.** Add `After=systemd-networkd-wait-online.service` (or equivalent) to the NixOS k3s module's service definition, and set `Wants=systemd-networkd-wait-online.service`. Alternatively, pass `--node-ip=` lazily or add explicit sleep/health gate. Not urgent because systemd's 5s-retry recovers the failure automatically, but cleaner.

- [ ] **Reduce Longhorn replica count for non-critical PVCs.** Sonarr/Radarr/Prowlarr/Bazarr libraries are re-downloadable; their PVCs don't need 3 replicas. Move them to the existing `nvme-2-replicas` or even `nvme-1-replicas` StorageClass. Reduces cross-node Longhorn write amplification, which directly reduces the I/O pressure that can push nl-pve-01 over the edge.

- [ ] **Add `nodeAffinity` / `topologySpreadConstraints` to spread heavy-I/O pods off nl-k8s-02** until its host has more headroom (post-ballooning and -RAM-addition). An explicit `preferredDuringSchedulingIgnoredDuringExecution` anti-affinity on `kubernetes.io/hostname=nl-k8s-02` for the `*arr` stack would be cheap insurance.

- [ ] **Open an upstream Longhorn issue** (if not already opened from INC-0008) proposing default `failurePolicy: Ignore` or a narrower `objectSelector` on the core `v1.Node` UPDATE rule. Reference INC-0008 and INC-0009 as evidence that this webhook configuration is a recurring cause of cluster-wide outages in small/home-lab deployments.

## Lessons Learned

### What went well

- **Recognition was fast.** The post-reboot symptoms on nl-k8s-02 were instantly recognizable as INC-0008. This incident would have been much harder to diagnose without a well-written postmortem for the prior one. The INC-0008 writeup paid for itself in operator-minutes saved during this incident.
- **Recovery, once diagnosed, was 30 seconds.** The same two `kubectl patch` commands that fixed INC-0008 fixed this one.
- **Cluster data integrity was preserved.** Etcd stayed in quorum throughout. Longhorn replicas were rebuilt automatically once the node came back — no manual restore, no data loss.
- **The other three nodes absorbed the outage gracefully.** Workloads with replicas elsewhere kept running. This is a direct benefit of the multi-replica design; the investment in a 4-node cluster paid off.

### What didn't go well

- **We regressed on an action item.** The single most important action item from INC-0008 — making the webhook `Ignore` persistent — was filed 4 days ago and not done. As a direct result, this incident included a preventable 26-minute cluster-side outage on top of the unavoidable host-side outage. **Unfinished postmortem action items are worse than no postmortem at all**, because they create false confidence that the risk is managed.
- **The hypervisor was sized at its limit and nobody noticed.** `free -h` showing 30 GiB / 31 GiB used post-boot is a screaming warning sign that should have been caught weeks ago if we had any memory-pressure alerting. It wasn't.
- **We had no forensic capture for the host hang.** The ~4h40m silent window contained critical information about *why* the kernel hung, and we have none of it. pstore was empty, there's no kdump, `/var/log/qemu-server/` is empty. Next time this happens we will again be guessing from circumstantial evidence.
- **Physical intervention was required.** The host needed a hard power-cycle by a human in the room. For a "home lab" this is tolerable; if the operator had been away for the weekend it would have been much worse. No remote power management exists.

### What we learned

- **"Partial" cluster outages can become total outages on workloads whose only replica happens to live on the wrong node.** Services with effective replication factor 1 (things like CNPG clusters with instance-ID 1 pinned to a node, single-replica deployments) bit us here. Audit replicas across important services.
- **Memory overcommit on a hypervisor is a latent time bomb.** The host ran fine for weeks until one specific workload spike pushed it over. Overcommit creates fragility that only manifests under load, which is precisely when you least want to discover it.
- **The Longhorn webhook deadlock is not a one-time bug — it's a recurring threat that will resurface on every cold-boot scenario until the `failurePolicy` fix is persisted in Git.** We must close this gap permanently this time. Losing the race twice is a pattern; losing it three times would be a failure of ops discipline.
- **Observability gaps compound each other.** No PSI alerts → we didn't see memory pressure building. No external uptime monitor → we didn't know the host was down for ~30 minutes. No kdump → we can't reconstruct why it died. Each of these individually is a modest investment; together they turn a known incident class into an unknowable one.

## Related Incidents

- **INC-0007** (Apr 17, 2026): Cluster cascade failure, OOM on nl-k8s-02 triggering Longhorn I/O storm. Shared root cause at the hypervisor level (nl-pve-01 memory over-commit) and overlapping manifestation (Longhorn replica pressure on this specific host). That incident's remediation plan identified the same memory-overcommit problem; it remained unfixed and contributed to this incident six days later.
- **INC-0008** (Apr 18–19, 2026): Cluster-wide variant of the Longhorn webhook / Flannel bootstrap deadlock. This incident is the single-node variant, with identical root cause in the secondary failure and identical 30-second fix. The primary remediation (persist `failurePolicy: Ignore` in Git) was filed in INC-0008 and never completed, making this a direct consequence of that unclosed action item.
- **INC-0001** (Nov 13, 2025): Earlier, simpler Flannel-restart incident; the "process X didn't restart on a single node, `systemctl restart k3s` recovered it" cousin of INC-0008/9. Included here for completeness; not directly related to the webhook pathology.

## References

- [INC-0008 postmortem](./INC-0008-flannel-startup-deadlock-longhorn-webhook-after-k3s-1.35-upgrade.md) — the prior occurrence of the secondary failure mode.
- [INC-0007 postmortem](./INC-0007-cluster-cascade-failure-oom-longhorn-io-storm.md) — the prior occurrence of the primary failure mode.
- [Proxmox documentation: Memory ballooning](https://pve.proxmox.com/wiki/Dynamic_Memory_Management) — how to configure `balloon:` correctly for KVM guests.
- [Longhorn docs: Customizing webhooks](https://longhorn.io/docs/latest/advanced-resources/deploy/customizing-webhooks/) — official guidance; the chart does not expose `failurePolicy`, confirming Kustomize patch is the right approach.
- [Kubernetes admission webhook best practices — Avoiding deadlocks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#avoiding-deadlocks-in-self-hosted-webhooks) — general advice; applies directly here.

## Appendix A: Diagnostic commands used

```bash
# Confirm the hypervisor actually hung
ssh root@nl-pve-01 'timedatectl; last -x reboot | head -10; journalctl --list-boots | tail -5'

# Confirm no software cause
ssh root@nl-pve-01 'journalctl -b -1 -p warning --no-pager | tail -30'
ssh root@nl-pve-01 'journalctl -b -1 -k --no-pager | tail -200'
ssh root@nl-pve-01 'journalctl -b -1 --no-pager | grep -iE "oom|hung_task|softlockup|mce|thermal|nvme"'

# Verify hardware health post-recovery
ssh root@nl-pve-01 'sensors; smartctl -a /dev/nvme0n1 | head -80'
ssh root@nl-pve-01 'free -h; qm config 101'

# Forensic evidence preservation
ssh root@nl-pve-01 'ls -la /sys/fs/pstore/ /var/crash/ /var/lib/systemd/pstore/'
# All empty — no crash evidence retained.

# Confirm the secondary (INC-0008) deadlock
ssh root@nl-k8s-02 'ls /run/flannel/ 2>&1; ip -br link | grep -E "flannel|cni|vxlan"'
ssh root@nl-k8s-02 'journalctl -u k3s -b --no-pager | grep -iE "Starting flannel|Wrote flannel"'
ssh root@nl-k8s-02 'journalctl -u k3s -b --no-pager \
  | grep -iE "Waiting for untainted|Waiting for cloud-controller|failing.*validator.longhorn|Unable to set control-plane|Failed to set annotations"'

# Confirm webhook failurePolicy is still Fail (action item #1 never completed)
ssh root@nl-k8s-01 'kubectl get validatingwebhookconfiguration longhorn-webhook-validator \
  -o jsonpath="{.webhooks[0].failurePolicy}"; echo'
ssh root@nl-k8s-01 'kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator \
  -o jsonpath="{.webhooks[0].failurePolicy}"; echo'

# Confirm webhook endpoints are healthy on the 3 nodes that stayed up
ssh root@nl-k8s-01 'kubectl -n longhorn-system get endpointslices \
  | grep webhook'

# Apply the patch (same as INC-0008)
ssh root@nl-k8s-01 "kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml \
  > /root/longhorn-webhook-validator.yaml.bak.INC-0009.$(date +%s)"
ssh root@nl-k8s-01 "kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator  -o yaml \
  > /root/longhorn-webhook-mutator.yaml.bak.INC-0009.$(date +%s)"
ssh root@nl-k8s-01 "kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
  --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
ssh root@nl-k8s-01 "kubectl patch mutatingwebhookconfiguration  longhorn-webhook-mutator \
  --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"

# Verify recovery
ssh root@nl-k8s-02 'ls /run/flannel/subnet.env; ip -br link | grep -E "flannel|cni0"'
kubectl --context=nl -n longhorn-system get node.longhorn.io
kubectl --context=nl get pods -A --field-selector spec.nodeName=nl-k8s-02 \
  --no-headers | awk '{print $4}' | sort | uniq -c
```

## Appendix B: Suggested next-step checklist (short form)

In rough priority order, for the operator to work through after this writeup:

1. **Persist the webhook fix in Git.** Kustomize patch in `kube/longhorn-system/longhorn/kustomization.yaml`. This is the single highest-leverage change; without it INC-0010 is a matter of time.
2. **Set ballooning on nl-pve-01 VMs and shrink nl-k8s-02 to 16 GiB.** `qm set 101 --balloon 8192 --memory 16384` (VM needs a brief stop/start). Targets the primary root cause.
3. **Delete the stuck `longhorn-pre-upgrade` Job** to silence the API-server churn.
4. **Enable forensic capture on nl-pve-01.** pstore + kdump + softlockup_panic + sysctl memory tuning in a new `/etc/sysctl.d/99-pve-forensics.conf`.
5. **Add Prometheus alerts** for Longhorn webhook endpoint availability and hypervisor PSI memory pressure.
6. **Add external off-cluster uptime monitoring.**
7. **Set resource requests/limits on `*arr` stack and ArgoCD pods.**
8. **Plan NVMe replacement on nl-pve-01** with a DC-grade TLC drive.
9. **Consider remote power control** (PDU or Pi-based) so next host hang doesn't require an in-person reset.
10. **Update the INC-0008 action-item section** to mark item #1 as done once step 1 is merged.
