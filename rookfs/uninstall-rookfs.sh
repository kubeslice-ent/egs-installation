#!/usr/bin/env bash
# Uninstall RookFS / Rook-Ceph completely from the cluster.
# Usage:
#   ./uninstall-rookfs.sh [--kubeconfig PATH] [--namespace rook-ceph] [--dry-run]
#
# Order:
#   1. Delete test PVCs
#   2. Patch CephCluster cleanupPolicy → delete and remove finalizers
#   3. Delete all Ceph CRs (CephCluster, pools, fs, object stores, etc.)
#   4. Delete StorageClasses and SnapshotClasses
#   5. Uninstall Rook Helm chart
#   5b. Delete orphaned rook/ceph/csi RBAC
#   5c. Clear ceph.rook.io/disaster-protection finalizers (prevents stale MON data)
#   6. Delete OSD PVCs (block volumes)
#   7. Delete leftover PVs
#   8. Delete namespace (and CRDs)
#   9. Delete Rook/objectbucket CRDs + VolumeSnapshot CRDs and snapshot-controller
#  10. Remove node labels / taints added by the installer

set -euo pipefail

# ── defaults ─────────────────────────────────────────────────────────────────
NAMESPACE="rook-ceph"
KUBECONFIG="${KUBECONFIG:-}"
DRY_RUN=false

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig) KUBECONFIG="$2"; shift 2 ;;
    --namespace)  NAMESPACE="$2";  shift 2 ;;
    --dry-run)    DRY_RUN=true;    shift   ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ -n "$KUBECONFIG" ]] && export KUBECONFIG

KC() { kubectl ${KUBECONFIG:+--kubeconfig "$KUBECONFIG"} "$@"; }
info()    { echo "[INFO]  $*"; }
warn()    { echo "[WARN]  $*"; }
success() { echo "[OK]    $*"; }

run() {
  if $DRY_RUN; then
    echo "[DRY]   $*"
  else
    "$@"
  fi
}

# ── preflight ─────────────────────────────────────────────────────────────────
info "Verifying cluster connectivity..."
KC cluster-info --request-timeout=10s >/dev/null 2>&1 || {
  echo "ERROR: Cannot reach cluster. Set KUBECONFIG or pass --kubeconfig."
  exit 1
}
success "Cluster reachable."

# ── 1. delete test PVCs ───────────────────────────────────────────────────────
info "Deleting test PVCs (if any)..."
run KC -n "$NAMESPACE" delete pvc rookfs-test-rbd rookfs-test-cephfs --ignore-not-found

# ── 2. patch CephCluster cleanupPolicy ───────────────────────────────────────
if KC -n "$NAMESPACE" get cephcluster rook-ceph >/dev/null 2>&1; then
  info "Patching CephCluster cleanupPolicy to deleteDataDirOnHosts..."
  run KC -n "$NAMESPACE" patch cephcluster rook-ceph --type merge \
    -p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data","sanitizeDisks":{"method":"quick","iteration":1}}}}'

  info "Removing CephCluster finalizers..."
  run KC -n "$NAMESPACE" patch cephcluster rook-ceph --type merge \
    -p '{"metadata":{"finalizers":[]}}'

  info "Deleting CephCluster..."
  run KC -n "$NAMESPACE" delete cephcluster rook-ceph --ignore-not-found --timeout=120s || true
fi

# ── 3. delete other Ceph CRs ─────────────────────────────────────────────────
info "Deleting CephBlockPool, CephFilesystem, CephObjectStore..."
for crd in cephblockpools cephfilesystems cephobjectstores cephrbdmirrors cephfilesystemmirrors; do
  resources=$(KC -n "$NAMESPACE" get "$crd" -o name 2>/dev/null || true)
  if [[ -n "$resources" ]]; then
    echo "$resources" | while read -r r; do
      run KC -n "$NAMESPACE" patch "$r" --type merge -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true
      run KC -n "$NAMESPACE" delete "$r" --ignore-not-found || true
    done
  fi
done

# ── 4. delete StorageClasses and VolumeSnapshotClasses ───────────────────────
info "Deleting StorageClasses..."
for sc in rook-ceph-block rook-cephfs; do
  run KC delete storageclass "$sc" --ignore-not-found
done

info "Deleting VolumeSnapshotClasses..."
for vsc in csi-rbdplugin-snapclass csi-cephfsplugin-snapclass; do
  run KC delete volumesnapshotclass "$vsc" --ignore-not-found 2>/dev/null || true
done

# ── 5. uninstall Helm chart ───────────────────────────────────────────────────
if helm ${KUBECONFIG:+--kubeconfig "$KUBECONFIG"} list -n "$NAMESPACE" 2>/dev/null | grep -q rook-ceph; then
  info "Uninstalling rook-ceph Helm chart..."
  run helm ${KUBECONFIG:+--kubeconfig "$KUBECONFIG"} uninstall rook-ceph \
    --namespace "$NAMESPACE" --timeout=5m || true
else
  warn "Helm release 'rook-ceph' not found, skipping."
fi

# ── 5b. delete orphaned rook/ceph/csi cluster-scoped RBAC ───────────────────
# helm uninstall removes Helm-managed resources, but a prior manifest-based
# install may have left ClusterRoles/Bindings without Helm metadata that a
# subsequent helm install will refuse to import.
info "Cleaning up orphaned rook/ceph/csi ClusterRoles and ClusterRoleBindings..."
for cr in \
    cephfs-csi-nodeplugin cephfs-external-provisioner-runner \
    objectstorage-provisioner-role \
    rbd-csi-nodeplugin rbd-external-provisioner-runner \
    rook-ceph-cluster-mgmt rook-ceph-global rook-ceph-mgr-cluster \
    rook-ceph-mgr-system rook-ceph-object-bucket rook-ceph-osd rook-ceph-system; do
  run KC delete clusterrole "$cr" --ignore-not-found 2>/dev/null || true
done

for crb in \
    cephfs-csi-nodeplugin-role cephfs-csi-provisioner-role \
    objectstorage-provisioner-role-binding \
    rbd-csi-nodeplugin rbd-csi-provisioner-role \
    rook-ceph-global rook-ceph-mgr-cluster rook-ceph-object-bucket \
    rook-ceph-osd rook-ceph-system; do
  run KC delete clusterrolebinding "$crb" --ignore-not-found 2>/dev/null || true
done
success "Orphaned RBAC cleaned up"

# ── 5c. clear rook disaster-protection finalizers before namespace delete ──────
# ConfigMaps and Secrets with ceph.rook.io/disaster-protection finalizers survive
# namespace deletion and poison the next fresh install by providing stale MON data.
info "Clearing ceph.rook.io/disaster-protection finalizers on ConfigMaps/Secrets..."
for kind in configmap secret; do
  KC -n "$NAMESPACE" get "$kind" -o name 2>/dev/null | while read -r res; do
    has_finalizer=$(KC -n "$NAMESPACE" get "$res" \
      -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)
    if echo "$has_finalizer" | grep -q "disaster-protection"; then
      info "  Removing finalizer from $res"
      run KC -n "$NAMESPACE" patch "$res" --type merge \
        -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true
      run KC -n "$NAMESPACE" delete "$res" --ignore-not-found 2>/dev/null || true
    fi
  done
done

# ── 6. delete OSD PVCs ───────────────────────────────────────────────────────
info "Deleting OSD PVCs in namespace $NAMESPACE..."
osd_pvcs=$(KC -n "$NAMESPACE" get pvc -l ceph.rook.io/DeviceSet=set1 -o name 2>/dev/null || true)
if [[ -n "$osd_pvcs" ]]; then
  echo "$osd_pvcs" | while read -r p; do
    run KC -n "$NAMESPACE" delete "$p" --ignore-not-found
  done
else
  # Fallback: delete all PVCs in namespace
  warn "No OSD PVCs found by label; deleting all PVCs in $NAMESPACE..."
  run KC -n "$NAMESPACE" delete pvc --all --ignore-not-found || true
fi

# ── 7. delete released/failed PVs that belonged to rook-ceph ─────────────────
info "Deleting orphaned PVs..."
KC get pv -o json 2>/dev/null | python3 -c "
import sys, json
pvs = json.load(sys.stdin)
for pv in pvs.get('items', []):
    ns = pv.get('spec', {}).get('claimRef', {}).get('namespace', '')
    name = pv['metadata']['name']
    phase = pv.get('status', {}).get('phase', '')
    if ns == '$NAMESPACE' or phase in ('Released', 'Failed'):
        print(name)
" | while read -r pv; do
  run KC delete pv "$pv" --ignore-not-found || true
done

# ── 8. delete namespace (removes remaining pods, configmaps, secrets) ─────────
info "Deleting namespace $NAMESPACE..."
if KC get namespace "$NAMESPACE" >/dev/null 2>&1; then
  run KC delete namespace "$NAMESPACE" --timeout=120s || true

  # If still stuck, force-clear namespace finalizer via the API
  if KC get namespace "$NAMESPACE" >/dev/null 2>&1; then
    info "Namespace stuck Terminating — force-removing finalizer via API..."
    KC get namespace "$NAMESPACE" -o json \
      | python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" \
      | KC replace --raw "/api/v1/namespaces/${NAMESPACE}/finalize" -f - 2>/dev/null || true
  fi
fi

# ── 9. delete Rook CRDs and snapshot-controller resources ────────────────────
info "Deleting Rook CRDs..."
KC get crd -o name 2>/dev/null | grep -E "ceph\.rook\.io|rook\.io|objectbucket\.io" | while read -r crd; do
  run KC delete "$crd" --ignore-not-found || true
done

# VolumeSnapshot CRDs and controller are installed by the installer (Phase 7)
# but are not part of the rook-ceph Helm release, so helm uninstall leaves them.
info "Deleting VolumeSnapshot CRDs and snapshot-controller..."
for crd in volumesnapshots.snapshot.storage.k8s.io \
           volumesnapshotclasses.snapshot.storage.k8s.io \
           volumesnapshotcontents.snapshot.storage.k8s.io; do
  run KC delete crd "$crd" --ignore-not-found 2>/dev/null || true
done
run KC -n kube-system delete deployment snapshot-controller --ignore-not-found 2>/dev/null || true
run KC -n kube-system delete serviceaccount snapshot-controller --ignore-not-found 2>/dev/null || true
run KC delete clusterrole snapshot-controller-runner --ignore-not-found 2>/dev/null || true
run KC delete clusterrolebinding snapshot-controller-role --ignore-not-found 2>/dev/null || true
run KC -n kube-system delete role snapshot-controller-leaderelection --ignore-not-found 2>/dev/null || true
run KC -n kube-system delete rolebinding snapshot-controller-leaderelection --ignore-not-found 2>/dev/null || true

# ── 9b. purge /var/lib/rook host-path from storage nodes ─────────────────────
# Without this, stale MON monmaps on the host survive reinstalls and cause
# mon pods to probe dead addresses, deadlocking quorum formation.
_rook_nodes=$(KC get nodes -l node-role.rookfs/storage=true \
  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [[ -n "$_rook_nodes" ]]; then
  info "Purging /var/lib/rook host-path from storage node(s): $_rook_nodes"
  for _node in $_rook_nodes; do
    _pname="rook-hostclean-${_node}"
    if ! $DRY_RUN; then
      KC -n kube-system apply -f - <<EOF 2>/dev/null || true
apiVersion: v1
kind: Pod
metadata:
  name: ${_pname}
  namespace: kube-system
spec:
  restartPolicy: Never
  nodeName: "${_node}"
  tolerations:
  - operator: Exists
  containers:
  - name: cleanup
    image: busybox:1.36
    command: ["sh", "-c", "rm -rf /host/var/lib/rook && echo 'cleaned /var/lib/rook on ${_node}'"]
    volumeMounts:
    - name: host-root
      mountPath: /host
    securityContext:
      privileged: true
  volumes:
  - name: host-root
    hostPath:
      path: /
EOF
    else
      echo "[DRY]   would create cleanup pod ${_pname} on ${_node}"
    fi
  done
  if ! $DRY_RUN; then
    for _node in $_rook_nodes; do
      _pname="rook-hostclean-${_node}"
      info "  Waiting for host-path cleanup on ${_node}..."
      # Poll until Succeeded or Failed — avoids the Ready-condition race where a
      # fast-completing pod transitions Running→Succeeded before the watch starts.
      _deadline=$(( $(date +%s) + 180 ))
      while [[ $(date +%s) -lt $_deadline ]]; do
        _phase=$(KC -n kube-system get pod "${_pname}" \
          -o jsonpath='{.status.phase}' 2>/dev/null || true)
        [[ "$_phase" == "Succeeded" ]] && break
        [[ "$_phase" == "Failed"    ]] && { warn "cleanup pod ${_pname} failed"; break; }
        sleep 5
      done
      if [[ "${_phase:-}" != "Succeeded" ]]; then
        warn "cleanup pod ${_pname} did not reach Succeeded within 180s (phase=${_phase:-unknown})"
      fi
      KC -n kube-system logs "${_pname}" 2>/dev/null || true
      KC -n kube-system delete pod "${_pname}" --ignore-not-found 2>/dev/null || true
    done
    success "Host-path /var/lib/rook purged from storage nodes"
  fi
else
  info "No nodes labeled node-role.rookfs/storage=true — skipping host-path cleanup"
fi

# ── 10. remove node labels and taints added by installer ─────────────────────
info "Removing rookfs node labels and taints..."
KC get nodes -l node-role.rookfs/storage=true -o name 2>/dev/null | while read -r node; do
  run KC label "$node" node-role.rookfs/storage- 2>/dev/null || true
  run KC taint "$node" ceph=storage:NoSchedule- 2>/dev/null || true
done

success "============================================"
success "RookFS uninstall complete."
success "You can now safely delete the node pool"
success "and recreate it for a fresh install."
success "============================================"
