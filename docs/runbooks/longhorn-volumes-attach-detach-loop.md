# Longhorn volumes in attach-detach loop

## Overview

Describe the issue where Longhorn volumes are stuck in an attach-detach loop.

## Symptoms

- Volumes repeatedly looping "Attaching" and "Detaching" states,
- Volumes reporting "Faulted" state eventually through Longhorn UI,
- Pods using affected volumes fail to start or become unstable,
- Error messages in Longhorn UI or logs.

## Impact

- Application downtime,
- Data unavailability.

## Root causes

- Restarting Kubernetes nodes without clean shutdown of Longhorn manager and other resources, causing data loss.

## Resolution

1. Identify all affected Deployments/StatefulSets (through `k9s`),
2. For each affected Deployment/StatefulSet, identify all the PersistentVolumeClaims affected,
3. Scale down all affected Deployments/StatefulSets to 0,
4. For each affected Delopyment/StatefulSet,
   1. Observe that there are no currently running/scheduled Pods,
   2. Manually mount the faulty PersistentVolumeClaim to the last node they were attached to, through Longhorn UI,
   3. Copy the Longhorn path for the mounted volume through the UI, e.g. `/dev/longhorn/pvc-xxx`,
   4. SSH into the node where the Volume has been mounted,
   5. Mount the Volume to a physical directory, e.g. `mount /dev/longhorn/pvc-xxxxxx /root/tmp`,
   6. `cd /root/tmp` and ensure the data is correct (e.g. through `ls`),
   7. Unmount the volume through `umount /root/tmp`,
   8. Unmount the Volume from the node using Longhorn UI,
   9. Observe that the Volume is now in "Detached" state,
   10. Scale up the Deployment/StatefulSet from `k9s`
   11. Observe that the Volume is now attached and in "Healthy" state,
   12. Observe that the Pod(s) for the Deployment/StatefulSet is now in "Running" state,
5. Observe that all Volumes are in "Healthy" state through Longhorn UI.


## Prevention

- Ensure Longhorn resources are gracefully shutdown when restarting a Kubernetes node.

## References

`TODO`
