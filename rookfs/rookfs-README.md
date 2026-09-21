# Rook/Ceph Storage Installer

This script installs **Rook/Ceph** — a distributed storage system — on any Kubernetes cluster.
It gives your cluster two StorageClasses that pods can use to request persistent storage:

| StorageClass | Type | Use for |
|---|---|---|
| `rook-ceph-block` | Block (RWO) | Databases, single-pod workloads |
| `rook-cephfs` | Filesystem (RWX) | AI/ML models, shared data, multiple pods reading the same volume |

---

## What Gets Installed

When you run the script it goes through these steps automatically:

```
Phase 0  Preflight        — checks kubectl, helm, StorageClass exist before doing anything
Phase 1  Node prep        — labels (and optionally taints) your storage nodes
Phase 2  Operator         — installs the Rook operator (manages Ceph daemons)
Phase 3  CephCluster      — deploys MON, MGR, OSD pods
Phase 4  Wait             — polls until the cluster is healthy
Phase 5  StorageClasses   — creates rook-ceph-block and rook-cephfs; annotates rook-cephfs with
                             storageclass.kubernetes.io/is-default-class=true (⚠ if a default SC already
                             exists, the cluster will have two defaults — remove the annotation from the
                             one you don't want as default)
Phase 6  Pool fix         — sets replication=1 for single-OSD installs (dev only)
Phase 7  VolumeSnapshots  — installs snapshot CRDs and SnapshotClasses (prod only)
Phase 8  Monitoring       — checks Prometheus Operator is present; Rook creates the ServiceMonitor automatically (prod only)
Phase 9  Dashboard        — exposes Ceph UI on NodePort 32200 (only if --dashboard passed)
Phase 10 Validate         — creates a test PVC on each StorageClass and confirms it binds
```

---

## Before You Start

You need these tools installed on your machine:

```bash
kubectl version   # must be able to reach your cluster
helm version      # only needed for prod mode
```

Your `KUBECONFIG` environment variable must point to the cluster, or pass `--kubeconfig <path>` to the script.

---

## Two Modes: Dev vs Prod

### Dev mode (default)
Single OSD, single MON. No replication. Fast to install. Good for UAT, testing, and dev clusters.
- **Data is NOT protected** — if the storage node goes down, data is lost.
- No resource limits, no snapshots, no monitoring.

### Prod mode (`--mode prod`)
3 OSDs across storage nodes, 3 MONs, replication=3. Data survives one node going down.
- Resource limits on all Ceph daemons.
- VolumeSnapshot support (point-in-time backups).
- Prometheus monitoring.
- Helm install (supports `helm upgrade` for future Rook version bumps).

---

## Installation

### Step 1 — Pick your nodes

Decide which nodes in your cluster will carry Ceph storage. You can let the script label them automatically with `--label-nodes`, or label them manually first:

```bash
kubectl label node <node1> node-role.rookfs/storage=true
kubectl label node <node2> node-role.rookfs/storage=true
kubectl label node <node3> node-role.rookfs/storage=true
```

> **Note:** These nodes will be **shared** with other workloads — other pods can still run on them.
> Ceph will pin itself to these nodes via nodeAffinity but will not block other pods.
> If you want dedicated storage nodes (no other pods), add `--taint-nodes` to the install command.

---

### Step 2 — Run the installer

#### Cloud PVC mode (any cloud with a block storage provisioner)

Use this when your cluster has a StorageClass that provisions raw block volumes (e.g. Linode, AWS EBS, GKE, Azure, DigitalOcean).

```bash
./install-rookfs.sh \
  --mode prod \
  --osd-mode pvc \
  --block-sc <your-block-storageclass> \
  --storage-nodes "node1,node2,node3" \
  --label-nodes \
  --osd-size 200Gi \
  --enable-monitoring \
  --enable-snapshots \
  --kubeconfig my-cluster.yaml
```

Add `--portable` if your cloud can reattach block volumes to a different node after a failure (most managed clouds support this):

```bash
  --portable
```

Common block StorageClass names by provider:

| Provider | Block StorageClass |
|---|---|
| Linode | `linode-block-storage-retain` |
| AWS | `gp3` |
| GKE | `standard-rwo` |
| Azure | `managed-premium` |
| DigitalOcean | `do-block-storage` |

#### On-prem / bare-metal (raw disks)

Use this when nodes have raw unformatted disks you want to hand directly to Ceph.

```bash
./install-rookfs.sh \
  --mode prod \
  --osd-mode device \
  --storage-nodes "node1,node2" \
  --devices nvme1n1,nvme2n1 \
  --label-nodes \
  --enable-monitoring \
  --enable-snapshots \
  --kubeconfig my-cluster.yaml
```

> **On-prem note:** Disks must be completely unformatted and unmounted.
> If a disk already has a filesystem, `ceph-volume` will silently skip it and you will get no OSD.
> Check with `lsblk -f` before installing.

#### Nodes with an external taint (e.g. GPU nodes / KubeSlice)

When storage nodes carry a `NoSchedule` taint from another system (e.g. KubeSlice GPU reservation), pass the taint key so the CSI DaemonSet pods can still schedule on those nodes:

```bash
./install-rookfs.sh \
  --mode prod \
  --osd-mode device \
  --storage-nodes "c1w2,c1w3" \
  --devices nvme1n1,nvme2n1 \
  --label-nodes \
  --toleration-key kubeslice.io/egs \
  --toleration-value dedicated-node \
  --kubeconfig amaya-1-kubeconfig.yaml
```

#### Shared nodes with limited CPU

If storage nodes also carry heavy system DaemonSets (Calico, CNI plugins, service mesh agents), use `--resource-profile minimal` to avoid `Insufficient cpu` scheduling failures:

```bash
./install-rookfs.sh \
  --mode prod \
  --osd-mode pvc \
  --block-sc linode-block-storage-retain \
  --storage-nodes "node1,node2,node3" \
  --label-nodes \
  --resource-profile minimal \
  --kubeconfig my-cluster.yaml
```

#### Dev (single node)

```bash
./install-rookfs.sh \
  --osd-mode pvc \
  --block-sc <your-block-storageclass> \
  --storage-node-label node-role.rookfs/storage=true \
  --kubeconfig my-cluster.yaml
```

---

### Step 3 — Verify the installation

```bash
# Check both StorageClasses are present (rook-cephfs is the cluster default)
kubectl get storageclass | grep rook

# Check cluster health
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

# Healthy dev output:
#   health: HEALTH_WARN (expected — no replication on single OSD)
#   osd: 1 osds: 1 up, 1 in

# Healthy prod output:
#   health: HEALTH_OK
#   osd: 3 osds: 3 up, 3 in
```

---

## How OSDs Get Their Storage

Ceph OSDs are the daemons that actually store data. Each OSD needs a raw block device.

### PVC mode (`--osd-mode pvc`)

The script creates a dedicated raw block PVC per OSD from your cluster's block StorageClass:

```
Block StorageClass  →  PVC (raw block, e.g. 200Gi)  →  OSD pod uses it as a disk
```

Requires `--block-sc <storageclass>`. Add `--portable` if the cloud can reattach PVCs to a replacement node after node failure.

### Device mode (`--osd-mode device`)

The script hands raw unformatted disk(s) on the node directly to Ceph:

```
Raw disk (e.g. /dev/nvme1n1)  →  ceph-volume  →  OSD pod
```

Requires `--devices <name[,name...]>`. Disk names must be unformatted — use `lsblk -f` to confirm. If a disk has a filesystem or partition table, `ceph-volume` skips it silently.

---

## Node Count Guide

| Nodes available | What to do |
|---|---|
| 1 | Dev/UAT only — `--mode dev`, 1 OSD, no replication |
| 2 | Supported with `allowMultiplePerNode` (auto-set) — losing either node loses quorum |
| **3+** | **Recommended for production** — 3 OSDs, 3 MONs, replication=3 |

> **2-node quorum warning:** With only 2 storage nodes, Ceph needs both nodes to maintain MON quorum. If either node goes down, quorum is lost and all CephFS mounts block indefinitely. Use 3+ nodes for prod if availability matters.

You do not need all cluster nodes to be storage nodes. Label 3 and the script handles the rest.

---

## Capacity Planning

### Raw storage vs usable space

What you set as `--osd-size` is raw disk **per OSD**. Ceph uses that raw space for replication and metadata, so the space your PVCs can actually use is less.

```
Usable space = (OSD count × OSD size) ÷ replication factor × 0.8
                                                                └── keep 20% free headroom
                                                                    (Ceph degrades past 85%)
```

| OSD size | OSD count | Replication | Usable space |
|---|---|---|---|
| 50Gi | 1 | 1 (dev) | ~40Gi |
| 100Gi | 1 | 1 (dev) | ~80Gi |
| 100Gi | 3 | 3 (prod) | ~80Gi |
| 200Gi | 3 | 3 (prod) | ~160Gi |
| 500Gi | 3 | 3 (prod) | ~400Gi |

**Key point:** With replication=3, three OSDs together give the same usable space as one OSD. You are paying 3× raw for redundancy, not capacity. To get more capacity, increase `--osd-size`.

### CephFS quota trap

With `rook-cephfs`, the PVC request size is reserved as a quota even if the pod writes nothing:

```
PVC: 40Gi requested → CephFS reserves 40Gi quota → actual data written: 0
                       ↑ this counts against your disk
```

**Plan based on total PVC sizes you will create, not actual data.**

### How to size your OSDs

1. List the PVCs you expect to create and add up their sizes
2. Multiply by 1.5 for growth headroom
3. Apply the formula:

```
OSD size (per OSD) = total PVC demand × 1.5 × replication ÷ 0.8 ÷ OSD count
```

**Example — 3 inference model PVCs at 40Gi each + other workloads:**

```
PVC demand:  3 × 40Gi + 50Gi misc = 170Gi
With buffer: 170Gi × 1.5 = 255Gi usable needed
Prod OSD:    255Gi × 3 (replication) ÷ 0.8 ÷ 3 (OSDs) = ~319Gi per OSD → use 350Gi
```

---

## Shared vs Dedicated Storage Nodes

### Shared nodes (most common)
Other pods can still run on storage nodes. Ceph uses nodeAffinity to stay on the labeled nodes but does not block other workloads.

**What to watch:** If a storage node gets heavily loaded by application pods (high CPU/memory), Ceph daemons may experience timeouts. Use `--resource-profile standard` to set CPU and memory limits on Ceph daemons.

**Shared nodes with heavy system DaemonSets:** Clusters running Calico CNI, KubeSlice `nsmgr` + `forwarder-kernel`, Rook CSI plugins, Spire agent, GPU operator NFD worker, etc. consume ~1.4 GHz of CPU requests per node. On a 4-CPU node (~3920m allocatable) this leaves fewer than 900m free — not enough for the `standard` profile's 1000m OSD request. **Use `--resource-profile minimal` on such nodes.**

### Dedicated nodes (`--taint-nodes`)
Adds a `ceph=storage:NoSchedule` taint to storage nodes. No other pods will schedule on them. Ceph daemons run with full access to node resources. Best for production if your cluster has enough nodes to spare.

---

## reclaimPolicy: Delete

Both StorageClasses use `reclaimPolicy: Delete`. This means:

- When a PVC is deleted → the PV is automatically deleted → the Ceph subvolume/image is freed
- No manual cleanup needed
- No orphaned subvolumes consuming quota after PVCs are deleted

> **Why not Retain?** With `Retain`, deleting a PVC leaves the PV and the Ceph subvolume behind. They keep consuming disk quota even though no pod is using them. You have to manually delete Released PVs and Ceph subvolumes, or the disk fills up silently.

---

## Taking Snapshots (prod mode)

After prod install, you can snapshot any PVC:

```bash
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-pvc-snap
spec:
  volumeSnapshotClassName: csi-rbdplugin-snapclass   # for block PVCs
  # volumeSnapshotClassName: csi-cephfsplugin-snapclass  # for CephFS PVCs
  source:
    persistentVolumeClaimName: my-pvc
EOF
```

Restore by creating a new PVC from the snapshot:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc-restored
spec:
  dataSource:
    name: my-pvc-snap
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: rook-ceph-block
EOF
```

---

## Uninstalling

Use `uninstall-rookfs.sh` to cleanly remove everything Rook/Ceph created.

```bash
./uninstall-rookfs.sh --kubeconfig my-cluster.yaml
```

**What it does (in order):**

```
1.   Delete test PVCs
2.   Patch CephCluster cleanupPolicy → strip finalizers → delete CephCluster
3.   Delete CephBlockPool, CephFilesystem, CephObjectStore (strips finalizers first)
4.   Delete StorageClasses and VolumeSnapshotClasses
5.   Uninstall rook-ceph Helm chart
5b.  Delete orphaned rook/ceph/csi ClusterRoles and ClusterRoleBindings by name
     (catches resources left by old manifest-based installs that helm uninstall misses)
5c.  Strip ceph.rook.io/disaster-protection finalizers from all ConfigMaps/Secrets
     (prevents stale MON data poisoning the next install)
6.   Delete OSD PVCs (cloud block volumes, if PVC mode was used)
7.   Delete orphaned PVs
8.   Delete namespace — force-clears via /finalize API if stuck Terminating
9.   Delete Rook CRDs (ceph.rook.io + objectbucket.io) + VolumeSnapshot CRDs
     (volumesnapshots/volumesnapshotclasses/volumesnapshotcontents) + snapshot-controller
     Deployment and its RBAC (installed in Phase 7, not tracked by the Helm release)
9b.  Purge /var/lib/rook from each storage node via a privileged busybox pod
     (eliminates stale MON monmaps that cause probing deadlock on reinstall)
10.  Remove node-role.rookfs/storage label and ceph=storage:NoSchedule taint
```

> **PVC mode note:** The uninstaller deletes PVC objects from Kubernetes, but whether the
> underlying block volume is also deleted depends on your StorageClass `reclaimPolicy`.
> With `reclaimPolicy: Delete` (the Rook default) the volume is deleted automatically.
> With `Retain` (e.g. `linode-block-storage-retain`), go to your cloud console and delete
> the volumes manually after uninstalling.

**Optional flags:**

| Flag | Description |
|---|---|
| `--kubeconfig PATH` | Path to kubeconfig |
| `--namespace NAME` | Namespace to clean (default: `rook-ceph`) |
| `--dry-run` | Print what would be deleted without doing it |

---

## KubeSlice / GPU Node Taint Support

When storage nodes carry a `NoSchedule` taint from an external system (e.g. KubeSlice GPU reservation: `kubeslice.io/egs=dedicated-node:NoSchedule`), pass the taint details to the installer:

```bash
--toleration-key kubeslice.io/egs \
--toleration-value dedicated-node \
--toleration-effect NoSchedule
```

This injects a toleration into the `csi-cephfsplugin` and `csi-rbdplugin` DaemonSets via Helm so they still schedule on tainted nodes. Storage mounts continue to work for workloads running on reserved GPU nodes.

## KubeSlice storageCapabilities

After installation, `print_summary` automatically runs this check and prints the
`storageCapabilities` field from every `clusters.controller.kubeslice.io` object on the cluster.
It shows `(none)` when no cluster objects exist (worker cluster not yet registered with KubeSlice)
or when the EGS agent hasn't synced yet (wait ~1 min and re-run manually):

```bash
kubectl get clusters.controller.kubeslice.io -A \
  -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', []):
    name = item['metadata']['name']
    caps = item.get('status', {}).get('storageCapabilities')
    print(f'  {name}:')
    print(json.dumps(caps, indent=4) if caps else '    (none)')
"
```

---

## Day-2 Operations

### Check cluster health
```bash
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
```

### Expand an OSD (increase disk size)
1. Expand the PVC via `kubectl patch pvc` or your cloud console
2. Restart the OSD pod: `kubectl -n rook-ceph delete pod <osd-pod>`
3. Update the CRUSH weight: `ceph osd crush reweight osd.0 <new-size-in-TiB>`

### Add more OSDs (scale up)
Edit the CephCluster spec and increase `count`:
```bash
kubectl -n rook-ceph edit cephcluster rook-ceph
# Change storageClassDeviceSets[0].count from 3 to 4
```
The operator provisions the new OSD automatically.

### Upgrade Rook version (Helm install)
```bash
helm repo update rook-release
helm upgrade rook-ceph rook-release/rook-ceph \
  --namespace rook-ceph \
  --version v1.15.0 \
  --kubeconfig my-cluster.yaml
```

---

## All Flags Reference

### Core
| Flag | Default | Description |
|---|---|---|
| `--mode` | `dev` | `dev` or `prod` |
| `--kubeconfig` | `$KUBECONFIG` | Path to kubeconfig file |
| `--namespace` | `rook-ceph` | Kubernetes namespace |
| `--ceph-version` | `v19.2.0` | Ceph image tag |
| `--rook-version` | `v1.15.0` | Rook operator version |
| `--install-method` | `manifest` (dev) / `helm` (prod) | `helm` or `manifest` |

### Cluster sizing
| Flag | dev default | prod default | Description |
|---|---|---|---|
| `--osd-mode` | `device` | `device` | `device` (bare-metal raw disks) or `pvc` (cloud block volumes) |
| `--osd-count` | `1` | `3` | Number of OSDs to create (PVC mode only) |
| `--osd-size` | `50Gi` | `50Gi` ⚠ | Disk size per OSD — 50Gi is adequate for dev/UAT but **always pass an explicit value for prod** (200Gi minimum). See **Capacity Planning**. |
| `--block-sc` | — | — | Block StorageClass for OSD PVCs (required with `--osd-mode pvc`) |
| `--portable` | false | false | Mark PVC-backed OSDs as portable (cloud volumes that reattach on node failure) |
| `--devices` | `sdb` | `sdb` | Raw disk names for device mode (comma-separated, e.g. `nvme1n1,nvme2n1`) |
| `--mon-count` | `1` | `3` | Number of MON daemons |
| `--mgr-count` | `1` | `2` | Number of MGR daemons |
| `--replication` | auto | auto | Pool replication factor (auto = min of OSD count and 3) |

### Node management
| Flag | Description |
|---|---|
| `--storage-node-label` | Label key=value to pin Ceph daemons (e.g. `node-role.rookfs/storage=true`) |
| `--storage-nodes` | Comma-separated node names to label/taint |
| `--label-nodes` | Apply `--storage-node-label` to `--storage-nodes` automatically |
| `--taint-nodes` | Taint storage nodes so only Ceph schedules on them (dedicated nodes) |

### Taint toleration (external taints)
| Flag | Default | Description |
|---|---|---|
| `--toleration-key` | — | Taint key to tolerate on storage nodes (e.g. `kubeslice.io/egs`) |
| `--toleration-value` | — | Taint value (e.g. `dedicated-node`) |
| `--toleration-effect` | `NoSchedule` | Taint effect (`NoSchedule` / `NoExecute` / `PreferNoSchedule`) |

### Production features
| Flag | dev default | prod default | Description |
|---|---|---|---|
| `--resource-profile` | `none` | `standard` | `none` `minimal` or `standard` — sets CPU/memory limits |
| `--enable-monitoring` | false | true | Set `monitoring.enabled: true` in CephCluster |
| `--no-monitoring` | — | — | Disable monitoring even in prod mode |
| `--enable-snapshots` | false | true | Install VolumeSnapshot CRDs and SnapshotClasses |
| `--no-snapshots` | — | — | Disable snapshots even in prod mode |
| `--dashboard` | false | false | Expose Ceph dashboard on NodePort 32200 |

### Behaviour
| Flag | Description |
|---|---|
| `--skip-operator` | Skip operator install (if already installed) |
| `--skip-validate` | Skip test PVC creation at the end |
| `--dry-run` | Print all manifests without applying anything |

---

## Resource Profiles

| Profile | Daemon | CPU request | CPU limit | Memory request | Memory limit |
|---|---|---|---|---|---|
| `minimal` | MON | 250m | 500m | 256Mi | 1Gi |
| | MGR | 250m | 1 | 256Mi | 1Gi |
| | OSD | 500m | 1 | 1Gi | 2Gi |
| | MDS | 250m | 1 | 256Mi | 1Gi |
| `standard` | MON | 500m | 1 | 512Mi | 2Gi |
| | MGR | 500m | 2 | 512Mi | 2Gi |
| | OSD | 1 | 2 | 2Gi | 4Gi |
| | MDS | 500m | 2 | 512Mi | 2Gi |

Use `minimal` on nodes with 4–8GB RAM or on any node that already carries heavy system DaemonSets. Use `standard` on nodes with 8GB+ RAM and low baseline CPU usage (dedicated nodes or bare-metal).

---

## Troubleshooting

**OSD pods not starting**
```bash
kubectl -n rook-ceph get pods | grep osd
kubectl -n rook-ceph describe pod <osd-pod>
# PVC mode: check that the block StorageClass exists and PVCs are Bound
kubectl -n rook-ceph get pvc
# Device mode: check that disk names are correct and unformatted (lsblk -f on the node)
```

**CephCluster stuck in Progressing**
```bash
kubectl -n rook-ceph get cephcluster rook-ceph -o jsonpath='{.status}'
kubectl -n rook-ceph logs deploy/rook-ceph-operator | tail -50
# Common cause: MON pods not reaching quorum — check node resources and pod events
```

**PVC stuck in Pending after install**
```bash
kubectl describe pvc <pvc-name>
# Common cause: pool replication > OSD count
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd pool ls detail
```

**Disk full / subvolumes consuming space after PVC deletion**
- This should not happen with `reclaimPolicy: Delete` (current setting)
- If you see Released PVs: `kubectl get pv | grep Released` — delete them manually
- If you see orphaned CephFS subvolumes: `ceph fs subvolume ls myfs csi` — remove with `ceph fs subvolume rm`

**MON stuck in `probing` state — quorum never forms**

Symptom: After reinstall, `mon.a` stays in `probing` for many minutes. Operator logs loop:
```
mons running: [a]
```

Cause: `/var/lib/rook/mon-*/data` on the storage node survived the previous uninstall.
The monmap inside it references old MON addresses — the new MON boots from the stale monmap
and probes dead IPs forever.

Fix: The uninstaller step 9b automatically purges `/var/lib/rook` from all storage nodes
using a privileged busybox pod. If you're recovering manually:

```bash
# On the affected node (via kubectl debug or SSH):
rm -rf /var/lib/rook
```

Then re-run the uninstaller fully before reinstalling.

**MON pods Pending after reinstall — scheduled to dead nodes**

Symptom: MON pods have `Node-Selectors` pointing to nodes that no longer exist.

Cause: The `rook-ceph-mon-endpoints` ConfigMap from the previous install survived with a
`ceph.rook.io/disaster-protection` finalizer. The new operator reads it and re-creates
MON deployments pinned to the old hostnames.

Fix:
```bash
# 1. Delete the CephCluster to stop reconciliation
kubectl -n rook-ceph patch cephcluster rook-ceph --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl -n rook-ceph delete cephcluster rook-ceph

# 2. Force-delete the stale ConfigMap and Secret
kubectl -n rook-ceph patch configmap rook-ceph-mon-endpoints --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl -n rook-ceph delete configmap rook-ceph-mon-endpoints --ignore-not-found
kubectl -n rook-ceph patch secret rook-ceph-mon --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl -n rook-ceph delete secret rook-ceph-mon --ignore-not-found

# 3. Restart operator to clear in-memory MON state
kubectl -n rook-ceph rollout restart deployment/rook-ceph-operator

# 4. Re-apply the CephCluster (re-run the installer with --skip-operator)
```

The `uninstall-rookfs.sh` script handles this automatically in step 5c.

**Helm install fails: "cannot be imported into the current release" (orphaned RBAC)**

Symptom: `helm install` errors with:
```
Error: Unable to continue with install: ClusterRole "rook-ceph-system" in namespace ""
exists and cannot be imported into the current release: invalid ownership metadata;
label validation error: missing key "app.kubernetes.io/managed-by"
```

Cause: A previous install (manifest-based or old Helm version) left ClusterRoles/Bindings
without Helm ownership labels. Helm refuses to adopt resources it did not create.

Fix: Run `uninstall-rookfs.sh` — step 5b explicitly deletes all known rook/ceph/csi
cluster-scoped resources by name before the next Helm install. If you are not doing a
fresh reinstall, delete the blocking resource directly:

```bash
kubectl delete clusterrole <name-from-error>
kubectl delete clusterrolebinding <name-from-error>
# Then retry the install
```

**Phase 4 MON timeout on fresh install**

The script waits 300s for MONs to reach quorum. On slow clusters, each MON takes ~2 min to start.
If the script times out at Phase 4 but MON pods are Running, simply re-run with `--skip-operator`:

```bash
./install-rookfs.sh --mode prod --osd-mode device ... --skip-operator
```

The operator continues in the background; `--skip-operator` skips Phase 2 and re-runs
Phase 3 onward, instantly passing Phase 4 once all MONs are already up.

**Node pool scale-up replaces existing nodes**

On some managed Kubernetes platforms (e.g. Linode LKE), scaling up a node pool can
**replace** existing nodes instead of adding new ones. If storage nodes are replaced,
their hostnames change and MON pods (which are pinned by hostname) become permanently Pending.

Symptoms: MON pods Pending with `FailedScheduling` for a hostname that no longer exists
in `kubectl get nodes`.

Recovery requires MON monmap surgery — run `uninstall-rookfs.sh` fully and reinstall
against the new node names rather than attempting manual recovery.
