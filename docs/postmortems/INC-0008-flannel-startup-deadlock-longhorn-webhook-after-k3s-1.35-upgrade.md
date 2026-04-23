# INC-0008: Flannel Fails To Start Cluster-Wide After k3s 1.35 Upgrade — Longhorn Admission Webhook Deadlock

**Date**: April 19, 2026
**Duration**: ~4 hours (21:10 CEST Apr 18 cordon → ~00:40 CEST Apr 19 full recovery)
**Impact**: Entire Kubernetes cluster effectively down. No pod networking on any of the 4 nodes. All ingress, Longhorn, metrics, and GitOps-managed workloads unavailable.
**Severity**: Critical (P0)

## tl;dr

Following a routine `nix flake update` + NixOS rebuild, k3s was upgraded from v1.34.x+k3s1 to v1.35.2+k3s1 (alongside a jump to kernel 7.0.0) on all four nodes of the `nl` cluster. After the upgrade, the embedded flannel controller never initialized on any node: `/run/flannel/subnet.env` was absent, no `flannel.1`/`cni0` interfaces existed, and the journal contained zero flannel startup messages. All pod networking was broken, which in turn broke every admission webhook served by a pod — including Longhorn's. Because Longhorn's `ValidatingWebhookConfiguration` had a **last rule matching every `UPDATE` on core `v1.Node` cluster-wide with `failurePolicy: Fail`**, every node-object patch from k3s itself (setting labels, removing taints, uncordoning) was rejected. This prevented k3s from completing its agent-side `configureNode()` handshake, which is the gate that triggers flannel setup — creating a **circular deadlock** between the CNI and an admission webhook whose backend depended on the CNI. Rolling k3s back to 1.34.5 did not fix it (same deadlock). Patching the Longhorn validating and mutating webhooks to `failurePolicy: Ignore` broke the deadlock instantly: flannel came up on all four nodes within ~30 s, Longhorn pods rescheduled, and the cluster recovered.

## Timeline

All times CEST.

### Pre-incident — The upgrade
- **~21:00 Apr 18**: User runs `nix flake update` followed by `colmena apply switch` on the four `nl-k8s-*` nodes. nixpkgs bump includes kernel 6.18 → 7.0.0 and `pkgs.k3s` 1.34.x → 1.35.2+k3s1.
- **21:10–21:11 Apr 18**: All four nodes get cordoned (`node.kubernetes.io/unschedulable` taint with `timeAdded: 2026-04-18T21:10…21:11Z`) — standard operator pre-rolling-restart procedure. Nodes get rebooted.

### Detection phase
- **~21:15 Apr 18**: After the reboots, pods remain in `ContainerCreating` / `Pending` state across the cluster. Longhorn webhook logs on the API server are filled with `no endpoints available for service "longhorn-admission-webhook"`. ArgoCD shows all apps failing to reconcile.
- **~00:00 Apr 19**: User escalates and begins investigation, initially suspecting a k3s 1.35 regression.

### Investigation phase 1 — Flannel is simply not running
Quick checks on all four nodes reveal identical state:
- `/run/flannel/` does not exist — no `subnet.env`.
- `ip -br link` shows no `flannel.1`, `flannel-v6.1`, or `cni0` interfaces.
- `/etc/cni/net.d/` is empty (only the baked-in `/var/lib/rancher/k3s/agent/etc/cni/net.d/10-flannel.conflist` is present).
- **The k3s journal on every node contains zero flannel startup lines.** No `"Starting flannel with backend vxlan"`, no `"Wrote flannel subnet file"`, nothing. The embedded flannel controller is never invoked.
- Kernel 7.0.0 emits `modprobe: FATAL: Module iptable_nat not found` at boot, but `iptables-nft` is working correctly and kube-proxy rules are installed — this turns out to be a red herring (iptables CLI translates to nftables transparently).

Every k3s instance shuts up exactly at `"Waiting for untainted node"` / `"Waiting for cloud-controller-manager privileges to become available"` and never progresses past that line.

Initial (incorrect) hypothesis: [k3s PR #13262](https://github.com/k3s-io/k3s/pull/13262) (merged in v1.35.0) refactored CNI startup into the Executor interface; [PR #13920](https://github.com/k3s-io/k3s/pull/13920) (merged 5 days prior, not in any GA release yet) fixes a regression it introduced. Plausible but unconfirmed match.

### Investigation phase 2 — Attempted rollback to k3s 1.34.5
- Pinned `services.k3s.package = pkgs.k3s_1_34` in `modules/k3s/k3s.nix` (1.34.5+k3s1 in the current nixpkgs) and rolled out to all four nodes.
- After the rollback, **flannel is still not starting**. Same symptoms. This rules out the 1.35 refactor as the primary cause.
- User attempts `kubectl uncordon nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04` and is met with:
  ```
  error: unable to uncordon node "nl-k8s-01": Internal error occurred: failed calling webhook
    "validator.longhorn.io": failed to call webhook: Post
    "https://longhorn-admission-webhook.longhorn-system.svc:9502/v1/webhook/validation?timeout=10s":
    no endpoints available for service "longhorn-admission-webhook"
  ```

### Investigation phase 3 — The real root cause
- Relevant k3s log lines (from nl-k8s-01, repeating every second) surface:
  ```
  k3s[…]: Unable to set control-plane role label: Internal error occurred: failed calling webhook
    "validator.longhorn.io": …no endpoints available…
  k3s[…]: node_lifecycle_controller.go:1248] "Failed to remove unreachable taint from node"
    err="…failing webhook validator.longhorn.io…" node="nl-k8s-04"
  ```
- These are **core `v1.Node` UPDATE** operations being blocked by a webhook named `validator.longhorn.io`. That shouldn't happen for a namespaced CRD webhook. Inspection of the full `ValidatingWebhookConfiguration` yaml reveals the smoking gun — the **last** rule (after a long list of `longhorn.io/v1beta2` rules) is:
  ```yaml
  - apiGroups: [""]
    apiVersions: [v1]
    operations: [UPDATE]
    resources: [nodes]
    scope: Cluster
  ```
  with `failurePolicy: Fail`. The Longhorn mutating webhook has the same rule.
- This rule matches every `UPDATE` on every core `v1.Node` — which is exactly what k3s's own agent bootstrap and control-plane controllers do constantly (labels, annotations, taints, conditions). When the webhook endpoints are unavailable, `failurePolicy: Fail` rejects every such update.
- Chain of causation:
  1. Reboot → no flannel yet → no pod networking
  2. No pod networking → Longhorn admission-webhook pod has no endpoint
  3. No endpoint → core `v1.Node` UPDATE patches fail
  4. k3s cannot complete `configureNode()` (which patches the node's labels/annotations)
  5. k3s cannot untaint `node.cloudprovider.kubernetes.io/uninitialized` via its embedded cloud-controller-manager
  6. The agent's `startNetwork()` goroutine is gated on `configureNode()` success → `executor.CNI()` → `flannel.Run()` is never called
  7. Flannel never writes `/run/flannel/subnet.env`, `flannel.1` never comes up → back to step 1.

### Resolution phase
- **~00:34 Apr 19**: From nl-k8s-01, back up both Longhorn webhook configs, then patch both to `failurePolicy: Ignore`:
  ```bash
  kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml > /root/longhorn-webhook-validator.yaml.bak
  kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator    -o yaml > /root/longhorn-webhook-mutator.yaml.bak

  kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
    --type=json --patch='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
  kubectl patch mutatingwebhookconfiguration longhorn-webhook-mutator \
    --type=json --patch='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
  ```
- **~00:34 Apr 19 (+30 s)**: `/run/flannel/subnet.env` appears on nl-k8s-01. `flannel.1`, `flannel-v6.1`, `cni0` interfaces come up.
- **~00:35 Apr 19**: Same on nl-k8s-02, nl-k8s-03, nl-k8s-04. All four nodes transition to `Ready,SchedulingDisabled`.
- **~00:36 Apr 19**: `kubectl uncordon nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04` succeeds.
- **~00:40 Apr 19**: Longhorn manager pods come up, admission-webhook endpoints repopulate, CSI plugins and engine images resume, workloads start reconciling.
- **Note**: the k3s 1.34.5 pin applied during investigation was reverted (back to the nixpkgs default `pkgs.k3s` = 1.35.2+k3s1) **before** the webhook patch was applied, specifically so that the cluster would come up directly on 1.35.2 without needing a second rolling restart afterwards. Final state: all four nodes on `v1.35.2+k3s1` + kernel `7.0.0`.

## Root Cause

**A circular dependency between the CNI (flannel) and an admission webhook (Longhorn's).** Longhorn's `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration` each contain a final rule matching `UPDATE` on core `v1.Node` resources cluster-wide, with `failurePolicy: Fail`. When the cluster is in a cold-start state where flannel has not yet initialized, the Longhorn webhook pods have no endpoints, and every node-object UPDATE — including the ones k3s itself performs during agent bootstrap — is rejected. Because k3s's `startNetwork()` → `executor.CNI()` → `flannel.Run()` chain is gated on `configureNode()` successfully patching the node object, flannel is never started, and pod networking never comes up. The cluster cannot bootstrap itself out of this state without external intervention.

This is fundamentally a **Longhorn misconfiguration**, not a k3s bug. Longhorn ships this core-Node webhook rule to enforce invariants on node-label changes (e.g. preventing users from removing `node.longhorn.io/create-default-disk` in a way that would orphan volumes). However, with `failurePolicy: Fail`, the webhook becomes a single point of failure that can brick the entire cluster if Longhorn itself is unhealthy.

### Why did this manifest only after the upgrade?

In steady-state operation (before the upgrade), all four nodes already had flannel running, Longhorn was healthy, and node patches flowed through the Longhorn webhook without issue. The deadlock was latent. Two factors conspired to expose it during this upgrade:

1. **All four nodes were rebooted nearly simultaneously** as part of the rolling NixOS switch. This meant there was a window where no node had flannel up, so no Longhorn replica could start anywhere, so no webhook endpoint existed anywhere.
2. **k3s 1.35's more aggressive node-patch behavior** (PR #13262's move of annotations/labels to server-side JSON-Patch helpers in the embedded executor) arguably increased the number and timing-sensitivity of node-object UPDATE requests during bootstrap, making the deadlock easier to trigger. However, subsequent testing with the 1.34.5 rollback confirmed that **the deadlock also exists on 1.34.x** — the upgrade merely exposed a pre-existing fragility.

### Why wasn't this caught by the initial investigation?

The "Waiting for untainted node" / "Waiting for cloud-controller-manager privileges" log lines are misleading: they suggest that the k3s CCM is the bottleneck, which pointed investigation toward k3s-internal bootstrapping logic (PRs #13262, #13920, CCM leader election, etc.). The actual webhook failures were hidden in the much noisier Longhorn-webhook spam elsewhere in the log, and appeared to be a *consequence* of the flannel outage rather than the *cause* of it. It took grepping for specific k3s-internal log lines like `"Unable to set control-plane role label"` and `"Failed to remove unreachable taint from node"` to surface the webhook as the actual blocker.

## Detection

Primary diagnostic trail:

```bash
# 1. Confirm flannel isn't running anywhere
ssh root@nl-k8s-01 'ls -la /run/flannel/; ip -br link | grep -E "flannel|cni"'
# /run/flannel/ missing, no interfaces.

# 2. Confirm zero flannel log output — the really important one
ssh root@nl-k8s-01 'journalctl -u k3s -b --no-pager | grep -iE "Starting flannel|Wrote flannel"'
# Empty — flannel.Run() is never called.

# 3. Find the *real* error, not the CNI-cascade errors
ssh root@nl-k8s-01 'journalctl -u k3s -b --no-pager \
  | grep -iE "failing webhook|Unable to set control-plane|Failed to remove unreachable taint"'
# Spam of failed Longhorn webhook calls for core v1.Node UPDATEs.

# 4. Confirm the Longhorn webhook rule set
ssh root@nl-k8s-01 'kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml \
  | grep -B1 -A5 "resources:" | grep -A5 "nodes"'
# Reveals apiGroups: [""], resources: [nodes], scope: Cluster, operations: [UPDATE].

# 5. Confirm failurePolicy is Fail
ssh root@nl-k8s-01 "kubectl get validatingwebhookconfiguration longhorn-webhook-validator \
  -o jsonpath='{.webhooks[0].failurePolicy}'"
# Fail
```

The initial symptoms (pods stuck in `ContainerCreating`, Longhorn webhook spam, `loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory`) were all *consequences* of the deadlock and were strongly suggestive of a flannel bug. Only by asking "why isn't flannel starting?" (as opposed to "why is flannel erroring?") did the real cause surface.

## Resolution

### Immediate fix (applied during the incident)

Patched both Longhorn webhooks to non-blocking:

```bash
# On nl-k8s-01 (or any node with kubectl access to the cluster)

# Back up first
kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml > /root/longhorn-webhook-validator.yaml.bak
kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator    -o yaml > /root/longhorn-webhook-mutator.yaml.bak

# Patch failurePolicy: Fail → Ignore
kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
  --type=json --patch='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
kubectl patch mutatingwebhookconfiguration longhorn-webhook-mutator \
  --type=json --patch='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

Within 30 s, flannel came up on all four nodes; within 2 minutes the cluster was fully functional.

### Verification

```bash
# All nodes Ready and on v1.35.2+k3s1
ssh root@nl-k8s-01 'kubectl get nodes -o wide'

# Flannel subnet file and interfaces on every node
for n in nl-k8s-0{1..4}; do
  ssh root@$n 'ls /run/flannel/subnet.env && ip -br link | grep -E "flannel|cni"'
done

# Longhorn pods scheduled and making progress
ssh root@nl-k8s-01 'kubectl -n longhorn-system get pods -o wide'
```

## Contributing Factors

1. **Longhorn's default webhook posture is unsafe for single-webhook-pod clusters.** With `failurePolicy: Fail` and a cluster-scoped rule on core `v1.Node` UPDATE, any scenario where the webhook pod is unhealthy brings down node-patch operations cluster-wide. This is tolerable in large clusters with multiple replicas of the webhook pod, but dangerous in a 4-node home cluster where the webhook can easily end up with zero healthy endpoints.

2. **All four nodes rebooted nearly simultaneously.** In a staggered rolling restart, at least one node would have flannel up the whole time, which would have allowed the Longhorn webhook pod to remain scheduled and served. The `colmena apply switch` + cordon sequence used for the upgrade drained all nodes at roughly the same time.

3. **k3s 1.35's executor refactor changed node-patch timing.** Though the rollback to 1.34.5 confirmed that the deadlock exists on 1.34 too, the symptoms were far more evident and the deadlock triggered more reliably on 1.35.2 — suggesting some combination of changes in PR #13262 (patches via server-side JSON Patch) made the bootstrap path more sensitive to admission-webhook failures.

4. **Kernel 7.0.0 dropped legacy iptables modules.** `iptable_nat`, `iptable_filter`, `ip6table_nat`, `ip6table_filter` are no longer shipped as modules in this kernel; only the nftables stack is present. `iptables-nft` works transparently, so this is not actually a problem, but it produced many alarming-looking `modprobe: FATAL` log lines that consumed debugging attention.

5. **Nodes were cordoned, which itself produced a new taint (`node.kubernetes.io/unschedulable:NoSchedule`)** and created a chicken-and-egg: `kubectl uncordon` could not succeed because it requires a core `v1.Node` UPDATE, which the webhook blocked. So the "obvious" recovery step was unavailable.

## Impact

**User-facing:**
- All pods in `ContainerCreating` / `Pending` for ~4 hours.
- All ingress traffic via `*.cianfr.one` rejected (no endpoints behind ingress-nginx).
- Tailscale-exposed services unreachable.
- Longhorn volumes not mountable.
- GitOps (ArgoCD) unable to reconcile anything.
- Home Assistant, media stack, photos (Immich), observability (VictoriaMetrics, Grafana), and all other hosted services offline.

**Operational:**
- No data loss. Etcd remained consistent (all four members stayed reachable to each other on 10.0.1.0/24; only the Kubernetes control-plane-initiated node patches were blocked).
- Cluster state on disk was clean; recovery was a single `kubectl patch` away once the root cause was identified.
- Significant time spent chasing red-herring hypotheses (k3s version, kernel 7.0.0, iptables modules, CCM leader election, etcd downgrade) before the webhook was identified as the blocker.

## Action Items

### High priority

- [ ] **Make the Longhorn webhook `failurePolicy: Ignore` persistent in Nix/ArgoCD.** The patch applied during the incident is only in cluster state and will be overwritten the next time ArgoCD syncs the Longhorn Helm chart. Either:
  - **(preferred)** Override `webhook.failurePolicy` (or equivalent) in `kube/longhorn-system/longhorn/values.yaml` if the chart exposes it. **Update (Apr 23):** investigation during [INC-0009](./INC-0009-nl-pve-01-memory-overcommit-hang-and-flannel-webhook-deadlock.md) confirmed the `longhorn` Helm chart v1.11.1 does **not** expose a `webhook.failurePolicy` value (see <https://raw.githubusercontent.com/longhorn/longhorn/v1.11.1/chart/values.yaml>). The fallback path is the correct implementation.
  - **(fallback)** Add a Kustomize strategic-merge patch under `kube/longhorn-system/longhorn/` that rewrites `failurePolicy` on both webhook configurations after the Helm rendering step.
  - **(nuclear option)** Remove the core `v1.Node UPDATE` rule entirely from both webhooks — Longhorn does not critically rely on it; its other rules on `longhorn.io/v1beta2` resources are sufficient for normal operation.

  > ⚠️ **This action item was NOT completed and caused a regression:** On Apr 23, 2026, [INC-0009](./INC-0009-nl-pve-01-memory-overcommit-hang-and-flannel-webhook-deadlock.md) hit the **exact same deadlock** on a single node (nl-k8s-02) after a hypervisor crash forced a cold reboot. The in-cluster patch from this incident had been silently reverted by an ArgoCD Longhorn chart reconcile at some point between Apr 19 and Apr 23 (evidence: a stuck `longhorn-pre-upgrade` Job from a post-INC-0008 Helm run). The same two `kubectl patch` commands from this runbook were applied again to recover. This action item is now retroactively promoted to blocking — no further Longhorn changes should ship until it's closed.

- [ ] **Do not reboot all four nodes simultaneously during upgrades.** Switch the colmena apply to an explicit serial rollout:
  ```
  colmena apply --on nl-k8s-01 switch
  # wait for Ready + flannel up + Longhorn endpoints restored
  colmena apply --on nl-k8s-02 switch
  # …etc
  ```
  Alternatively, gate each step on a health check (`ls /run/flannel/subnet.env && kubectl -n longhorn-system get endpointslices …`).

- [ ] **Document the emergency unstick procedure in the runbook.** If the cluster ever gets wedged in this state again:
  ```bash
  ssh root@nl-k8s-01 "kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
    --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
  ssh root@nl-k8s-01 "kubectl patch mutatingwebhookconfiguration longhorn-webhook-mutator \
    --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
  # Wait ~30s, flannel should come up everywhere.
  ```

### Medium priority

- [ ] **Audit every other webhook in the cluster for similar cluster-breaking potential.** Specifically, enumerate webhooks with `failurePolicy: Fail` that match any core-kubernetes resource (`v1.Node`, `v1.Namespace`, `v1.ServiceAccount`, `v1.Secret`, `v1.ConfigMap`) cluster-wide. Candidates to review based on the current cluster:
  - `kyverno-*` (policy engine, known to have cluster-wide scope)
  - `cert-manager-webhook`
  - `cnpg-validating-webhook-configuration` / `cnpg-mutating-webhook-configuration`
  - `metallb-webhook-configuration`
  - `ingress-nginx-admission`
  - `akri-webhook-configuration`
  - `victoriametrics-*`
  - `inteldeviceplugins-*`

  For each, decide whether `failurePolicy: Ignore` is acceptable (i.e. we can tolerate a brief window of unvalidated requests during a webhook outage) in exchange for avoiding deadlocks like this one.

- [ ] **Add an alert on "Longhorn webhook has zero endpoints".** This is the canary for the deadlock condition. PromQL:
  ```promql
  kube_endpoint_address_available{namespace="longhorn-system",endpoint="longhorn-admission-webhook"} == 0
  ```
  Fire warning after 1 minute, critical after 5 minutes.

- [ ] **Add a smoke test to `colmena apply` post-switch.** After a NixOS switch on a k3s node, wait up to 120 s for `/run/flannel/subnet.env` to exist and `kubectl get node <hostname>` to return `Ready` before considering the deploy successful. Bail out with a clear error if not.

- [ ] **Reconsider the k3s 1.35 pin.** The 1.34.5 rollback was reverted during the incident because the real cause was proven to be independent of the k3s minor version. However, k3s 1.35.x still has known regressions from PR #13262 (PR #13920 is not yet in any GA release — expected in 1.35.4). Consider staying on 1.34.x via `services.k3s.package = pkgs.k3s_1_34;` until 1.35.4 is released, to reduce exposure to other PR #13262 regressions that might yet surface.

### Low priority

- [ ] **Open an upstream Longhorn issue** proposing that the core `v1.Node` UPDATE rule be either removed, narrowed via `objectSelector`, or default to `failurePolicy: Ignore`. Reference this postmortem and k3s issue [#13277](https://github.com/k3s-io/k3s/issues/13277) which is tangentially related.

- [ ] **Investigate kernel 7.0.0 iptables-module warnings** in the k3s boot sequence. These are informational (nftables handles everything transparently), but they're noise that slowed down the investigation. Either filter them from the journal or add a comment to the k3s NixOS module explaining they can be ignored.

- [ ] **Re-evaluate hugepages and kernel boot parameters** carried over from the 6.x kernel series to ensure nothing else surprise-regressed on the 7.0 bump. The iptables module situation suggests there may be other silent changes.

## Lessons Learned

### What went well

- **The cluster's on-disk state was never corrupted.** Etcd remained healthy throughout (the four etcd members could see each other over 10.0.1.0/24 even though k3s was stuck); no snapshot restore or `--cluster-reset` was needed.
- **Recovery was a single, reversible `kubectl patch`.** Once the root cause was identified, remediation took ~30 seconds.
- **GitOps kept configuration drift to zero.** Once flannel came back up, ArgoCD reconciled the cluster to the expected state with no manual intervention.
- **The 1.34.5 rollback, while unnecessary in hindsight, confirmed that the problem was not k3s 1.35-specific.** This was an important diagnostic datapoint that kept investigation honest.

### What didn't go well

- **The initial hypothesis (k3s 1.35 regression) consumed ~2 hours of investigation** before the Longhorn webhook was identified as the actual blocker. The misleading `"Waiting for untainted node"` log line pointed directly at the CCM, away from the real cause.
- **The deadlock was latent for months.** The Longhorn webhook has had this rule for 141 days (the age of the webhook resource), and the cluster has been rebooted many times in that window without triggering it. The specific combination of "all four nodes cordoned at once + reboot + admission webhook has no endpoints anywhere" was required to expose the deadlock. We had no way of knowing this risk existed.
- **`kubectl uncordon` failing was a huge clue that was initially misread.** The error message clearly said `failed calling webhook "validator.longhorn.io"`, but this was easy to dismiss as "of course, no pod networking → no webhook endpoints → any webhook-protected operation fails". We did not immediately connect the dots to "…and one of those webhook-protected operations is the node patch that k3s itself needs to do to start flannel."
- **No early-warning signal.** There is no current alerting on "cluster cannot start flannel" or "admission webhook has no endpoints during node UPDATE". The only signal was user-visible: workloads were unreachable.
- **The upgrade was all-at-once.** Cordoning + rebooting four nodes simultaneously converted a latent bug into a hard outage. A staggered rolling restart would almost certainly have avoided this.

### What we learned

- **Admission webhooks with `failurePolicy: Fail` that match core-Kubernetes resources cluster-wide are single points of failure for the entire control plane.** Especially if the webhook's backend is itself a pod running on the cluster it protects. This is a well-known anti-pattern ([upstream guidance](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#avoiding-deadlocks-in-self-hosted-webhooks)), but it's easy to miss during chart reviews.
- **Rolling upgrades must actually roll, not bounce in parallel.** Even on a small home cluster, the value of keeping at least one node healthy at all times is immense.
- **"The CNI isn't starting" is not always a CNI problem.** In k3s 1.35, CNI startup is gated on successful node patches, which are gated on admission webhooks. A chain of gates means any one link can silently stall the whole thing.
- **When the symptom is "process X silently didn't start", grep the journal for startup lines you *expect* to be there (`"Starting flannel with backend vxlan"`) rather than error lines.** The absence of expected log output is often more diagnostic than the presence of unexpected errors.

## Related Incidents

- **INC-0001** (Nov 13, 2025): Flannel VXLAN failure after a previous k3s upgrade. Surface symptoms were similar (pods on different nodes unable to communicate, flannel interface missing), but the root cause was a stuck flannel process on a single node after a service restart — recoverable with `systemctl restart k3s`. INC-0008 is the "cluster-wide, chicken-and-egg" cousin of INC-0001.
- **INC-0007** (Apr 17, 2026): Cluster cascade failure from OOM on nl-k8s-02. Overlaps with this incident in that Longhorn webhook pods failing / being unschedulable has been implicated in two catastrophic cluster outages in 3 days. Strongly motivates action item #1 (make the Longhorn webhook `failurePolicy: Ignore` persistent).
- **[INC-0009](./INC-0009-nl-pve-01-memory-overcommit-hang-and-flannel-webhook-deadlock.md)** (Apr 23, 2026): Single-node recurrence of the exact deadlock described here, triggered by a cold reboot of nl-k8s-02 after its hypervisor (nl-pve-01) hung under memory pressure. INC-0009 is the "one node walks into the deadlock in isolation while the cluster is otherwise healthy" variant of INC-0008 — same root cause, same 30-second webhook-patch fix. INC-0009 exists because action item #1 above was never completed; ArgoCD reverted the in-cluster patch applied during this incident's resolution, leaving the cluster again vulnerable.

## References

- [k3s PR #13262 — Reorganize Executor interface to make CNI startup part of Executor implementation](https://github.com/k3s-io/k3s/pull/13262) (v1.35.0)
- [k3s PR #13920 — Fix embedded executor VPN config injection](https://github.com/k3s-io/k3s/pull/13920) (regression fix for #13262, not yet in any GA release)
- [k3s issue #13277 — Flannel network error on agent nodes starting from k3s version > v1.31.14+k3s1](https://github.com/k3s-io/k3s/issues/13277) — closed as upstream flannel issue; tangentially related.
- [flannel PR #2251 — Fix deadlock in startup for large clusters](https://github.com/flannel-io/flannel/pull/2251) — different flannel deadlock (large cluster scale), but useful context for how fragile flannel bootstrap can be.
- [Kubernetes admission webhook best practices — Avoiding deadlocks in self-hosted webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#avoiding-deadlocks-in-self-hosted-webhooks)
- [Longhorn webhook documentation](https://longhorn.io/docs/latest/advanced-resources/deploy/customizing-webhooks/)

## Appendix: Diagnostic commands used

```bash
# Node + k3s state
for n in nl-k8s-0{1..4}; do
  ssh root@$n 'echo "=== $(hostname) ==="; k3s --version; uname -r; \
    ls -la /run/flannel/ 2>&1; ip -br link | grep -E "flannel|cni"'
done

# Cluster view
ssh root@nl-k8s-01 'kubectl get nodes -o wide'
ssh root@nl-k8s-01 'kubectl get nodes -o yaml | grep -B2 -A5 taints'
ssh root@nl-k8s-01 'kubectl get pods -A -o wide | grep -vE "Running|Completed"'

# k3s journal — what it's waiting on
ssh root@nl-k8s-01 'journalctl -u k3s -b --no-pager | \
  grep -iE "flannel|Waiting for|untainted|cloud-controller|failing webhook|\
    Unable to set control-plane|Failed to remove unreachable taint"'

# Confirm the webhook rule set
ssh root@nl-k8s-01 'kubectl get validatingwebhookconfiguration longhorn-webhook-validator -o yaml'
ssh root@nl-k8s-01 'kubectl get mutatingwebhookconfiguration  longhorn-webhook-mutator    -o yaml'

# Apply the patch
ssh root@nl-k8s-01 "kubectl patch validatingwebhookconfiguration longhorn-webhook-validator \
  --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
ssh root@nl-k8s-01 "kubectl patch mutatingwebhookconfiguration longhorn-webhook-mutator \
  --type=json --patch='[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"

# Verify
ssh root@nl-k8s-01 "kubectl get validatingwebhookconfiguration longhorn-webhook-validator \
  -o jsonpath='{.webhooks[0].failurePolicy}'; echo"
ssh root@nl-k8s-01 "kubectl get mutatingwebhookconfiguration longhorn-webhook-mutator \
  -o jsonpath='{.webhooks[0].failurePolicy}'; echo"

# After flannel comes up
ssh root@nl-k8s-01 'kubectl uncordon nl-k8s-01 nl-k8s-02 nl-k8s-03 nl-k8s-04'
ssh root@nl-k8s-01 'kubectl -n longhorn-system get pods -o wide'
ssh root@nl-k8s-01 'kubectl -n longhorn-system get endpointslices'
```
