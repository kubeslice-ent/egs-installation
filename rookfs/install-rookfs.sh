#!/usr/bin/env bash
# install-rookfs.sh — Production-grade Rook/Ceph installer for any Kubernetes cluster
# Works on any cloud or on-prem cluster — no cloud preset required.
#
# Usage:
#   ./install-rookfs.sh --mode <dev|prod> [options]
#
# Modes:
#   dev   Single OSD/MON, no resource limits, manifest install  (default)
#   prod  3 OSDs, 3 MONs, 2 MGRs, Helm install, resource limits,
#         monitoring, snapshots, node tainting
#
# OSD modes:
#   pvc     Cloud block volumes via a StorageClass (requires --block-sc)
#   device  Raw block devices on the node (requires --storage-nodes and --devices)
#
# Quick examples:
#   Prod (cloud PVC, any provider):
#     ./install-rookfs.sh --mode prod --osd-mode pvc \
#       --block-sc <your-storageclass> --portable \
#       --storage-nodes "node1,node2,node3" --label-nodes
#
#   Prod (on-prem / bare-metal, raw disks):
#     ./install-rookfs.sh --mode prod --osd-mode device \
#       --storage-nodes "node1,node2,node3" --devices nvme1n1,nvme2n1 \
#       --label-nodes
#
#   Prod (GPU nodes with external taint):
#     ./install-rookfs.sh --mode prod --osd-mode device \
#       --storage-nodes "node1,node2" --devices nvme1n1 --label-nodes \
#       --toleration-key kubeslice.io/egs --toleration-value dedicated-node
#
set -euo pipefail

# ─── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; }
die()     { error "$*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}$*${NC}"; }

# ─── Defaults ────────────────────────────────────────────────────────────────
MODE="dev"
INSTALL_METHOD=""           # set by --install-method or mode default (manifest|helm)
KUBECONFIG="${KUBECONFIG:-}"
NAMESPACE="rook-ceph"
CEPH_VERSION="v19.2.0"
ROOK_VERSION="v1.15.0"
SNAPSHOTTER_VERSION="v7.0.1"

# Cluster sizing (empty = set by mode default or fallback)
OSD_MODE="device"           # device (bare-metal) | pvc (cloud block volumes)
OSD_COUNT=""
OSD_SIZE="50Gi"
BLOCK_SC=""                 # required when --osd-mode pvc
PORTABLE=false              # true = cloud PVC volumes that can reattach on node failure
MON_COUNT=""
MGR_COUNT=""
ALLOW_MULTIPLE_MON=true
REPLICATION=0               # 0 = auto: min(osd-count, 3)

# Node management
STORAGE_NODE_LABEL=""       # e.g. role=storage-node
STORAGE_NODES=""            # comma-separated node names
DEVICES="sdb"               # comma-separated device names (device mode only)
LABEL_NODES=false
TAINT_NODES=false
CEPH_TAINT_KEY="ceph"
CEPH_TAINT_VALUE="storage"
CEPH_TAINT_EFFECT="NoSchedule"
TOLERATION_KEY=""           # external taint to tolerate (e.g. GPU node taint)
TOLERATION_VALUE=""
TOLERATION_EFFECT="NoSchedule"

# Production features (empty = set by mode default or fallback)
RESOURCE_PROFILE=""         # none | minimal | standard
ENABLE_MONITORING=""
ENABLE_SNAPSHOTS=""
DASHBOARD=false

# Behaviour
SKIP_OPERATOR=false
SKIP_VALIDATE=false
DRY_RUN=false

# ─── Arg parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)               MODE="$2"; shift 2 ;;
    --install-method)     INSTALL_METHOD="$2"; shift 2 ;;
    --kubeconfig)         KUBECONFIG="$2"; shift 2 ;;
    --namespace)          NAMESPACE="$2"; shift 2 ;;
    --ceph-version)       CEPH_VERSION="$2"; shift 2 ;;
    --rook-version)       ROOK_VERSION="$2"; shift 2 ;;
    --osd-mode)           OSD_MODE="$2"; shift 2 ;;
    --osd-count)          OSD_COUNT="$2"; shift 2 ;;
    --osd-size)           OSD_SIZE="$2"; shift 2 ;;
    --block-sc)           BLOCK_SC="$2"; shift 2 ;;
    --portable)           PORTABLE=true; shift ;;
    --mon-count)          MON_COUNT="$2"; shift 2 ;;
    --mgr-count)          MGR_COUNT="$2"; shift 2 ;;
    --replication)        REPLICATION="$2"; shift 2 ;;
    --storage-node-label) STORAGE_NODE_LABEL="$2"; shift 2 ;;
    --storage-nodes)      STORAGE_NODES="$2"; shift 2 ;;
    --devices)            DEVICES="$2"; shift 2 ;;
    --label-nodes)        LABEL_NODES=true; shift ;;
    --taint-nodes)        TAINT_NODES=true; shift ;;
    --ceph-taint-key)     CEPH_TAINT_KEY="$2"; shift 2 ;;
    --ceph-taint-value)   CEPH_TAINT_VALUE="$2"; shift 2 ;;
    --toleration-key)     TOLERATION_KEY="$2"; shift 2 ;;
    --toleration-value)   TOLERATION_VALUE="$2"; shift 2 ;;
    --toleration-effect)  TOLERATION_EFFECT="$2"; shift 2 ;;
    --resource-profile)   RESOURCE_PROFILE="$2"; shift 2 ;;
    --enable-monitoring)  ENABLE_MONITORING=true; shift ;;
    --no-monitoring)      ENABLE_MONITORING=false; shift ;;
    --enable-snapshots)   ENABLE_SNAPSHOTS=true; shift ;;
    --no-snapshots)       ENABLE_SNAPSHOTS=false; shift ;;
    --dashboard)          DASHBOARD=true; shift ;;
    --skip-operator)      SKIP_OPERATOR=true; shift ;;
    --skip-validate)      SKIP_VALIDATE=true; shift ;;
    --dry-run)            DRY_RUN=true; shift ;;
    -h|--help) awk '/^set -/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) die "Unknown option: $1  (use --help)" ;;
  esac
done

# Export so helm (and any subprocess) inherits the same cluster context as kubectl
[[ -n "$KUBECONFIG" ]] && export KUBECONFIG

# ─── Mode defaults ────────────────────────────────────────────────────────────
apply_mode_defaults() {
  if [[ "$MODE" == "prod" ]]; then
    # Only override sizing if user didn't explicitly set them
    MON_COUNT="${MON_COUNT:-3}"
    MGR_COUNT="${MGR_COUNT:-2}"
    OSD_COUNT="${OSD_COUNT:-3}"
    INSTALL_METHOD="${INSTALL_METHOD:-helm}"
    RESOURCE_PROFILE="${RESOURCE_PROFILE:-standard}"
    ENABLE_MONITORING="${ENABLE_MONITORING:-true}"
    ENABLE_SNAPSHOTS="${ENABLE_SNAPSHOTS:-true}"
    [[ -n "$STORAGE_NODES" ]] && LABEL_NODES=true
  elif [[ "$MODE" != "dev" ]]; then
    die "Invalid --mode '$MODE'. Use dev or prod."
  fi
  # Final fallbacks for dev mode / unset values
  MON_COUNT="${MON_COUNT:-1}"
  MGR_COUNT="${MGR_COUNT:-1}"
  OSD_COUNT="${OSD_COUNT:-1}"
  INSTALL_METHOD="${INSTALL_METHOD:-manifest}"
  RESOURCE_PROFILE="${RESOURCE_PROFILE:-none}"
  ENABLE_MONITORING="${ENABLE_MONITORING:-false}"
  ENABLE_SNAPSHOTS="${ENABLE_SNAPSHOTS:-false}"
  # When --label-nodes is used without an explicit --storage-node-label, apply the
  # default label so that nodeAffinity placement is generated for MONs and OSDs.
  if $LABEL_NODES && [[ -z "$STORAGE_NODE_LABEL" ]]; then
    STORAGE_NODE_LABEL="node-role.rookfs/storage=true"
  fi
}

# ─── PVC mode validation ──────────────────────────────────────────────────────
validate_pvc_mode() {
  [[ "$OSD_MODE" != "pvc" ]] && return
  [[ -z "$BLOCK_SC" ]] && die "--osd-mode pvc requires --block-sc <storageclass>"
}

# ─── Compute replication ──────────────────────────────────────────────────────
compute_replication() {
  # Device mode: actual OSD count = nodes × devices per node
  if [[ "$OSD_MODE" == "device" && -n "$STORAGE_NODES" ]]; then
    local _nc _dc
    IFS=',' read -ra _nl <<< "$STORAGE_NODES"; _nc="${#_nl[@]}"
    IFS=',' read -ra _dl <<< "$DEVICES";       _dc="${#_dl[@]}"
    OSD_COUNT=$(( _nc * _dc ))
  fi
  [[ "$REPLICATION" -eq 0 ]] && REPLICATION=$(( OSD_COUNT < 3 ? OSD_COUNT : 3 ))
  # Allow multiple MONs per node when MON count exceeds available storage nodes
  local _snode_count=0
  [[ -n "$STORAGE_NODES" ]] && { IFS=',' read -ra _snl <<< "$STORAGE_NODES"; _snode_count="${#_snl[@]}"; }
  if [[ "$MON_COUNT" -eq 1 ]] || { [[ "$_snode_count" -gt 0 ]] && [[ "$_snode_count" -lt "$MON_COUNT" ]]; }; then
    ALLOW_MULTIPLE_MON=true
  else
    ALLOW_MULTIPLE_MON=false
  fi
}

# ─── Helpers ─────────────────────────────────────────────────────────────────
KC() { kubectl ${KUBECONFIG:+--kubeconfig "$KUBECONFIG"} "$@"; }

kubectl_apply() {
  if $DRY_RUN; then echo "[dry-run] kubectl apply:"; cat
  else KC apply -f -; fi
}

wait_for_pods() {
  local label="$1" expected="$2" timeout="${3:-300}" elapsed=0
  info "Waiting for $expected pod(s) with label $label ..."
  while true; do
    local ready
    ready=$(KC -n "$NAMESPACE" get pods -l "$label" --no-headers 2>/dev/null | grep -c "Running" || true)
    [[ "$ready" -ge "$expected" ]] && { success "$label: $ready/$expected Running"; return 0; }
    [[ "$elapsed" -ge "$timeout" ]] && { error "Timeout: $label $ready/$expected Running after ${timeout}s"; return 1; }
    sleep 10; elapsed=$((elapsed+10))
    info "  $label: $ready/$expected Running (${elapsed}s/${timeout}s)"
  done
}

wait_for_cephcluster() {
  local timeout="${1:-900}" elapsed=0
  info "Waiting for CephCluster Ready (timeout ${timeout}s) ..."
  while true; do
    local phase health
    phase=$(KC -n "$NAMESPACE" get cephcluster rook-ceph -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    health=$(KC -n "$NAMESPACE" get cephcluster rook-ceph -o jsonpath='{.status.ceph.health}' 2>/dev/null || echo "")
    [[ "$phase" == "Ready" ]] && { success "CephCluster Ready (health: $health)"; return 0; }
    [[ "$elapsed" -ge "$timeout" ]] && { error "Timeout: CephCluster phase=$phase health=$health"; return 1; }
    sleep 15; elapsed=$((elapsed+15))
    info "  CephCluster phase=$phase health=$health (${elapsed}s/${timeout}s)"
  done
}

wait_for_osd() {
  local timeout="${1:-600}" elapsed=0
  info "Waiting for $OSD_COUNT OSD pod(s) Running ..."
  while true; do
    local running
    running=$(KC -n "$NAMESPACE" get pods --no-headers 2>/dev/null \
      | grep "rook-ceph-osd-[0-9]" | grep -c "Running" || true)
    [[ "$running" -ge "$OSD_COUNT" ]] && { success "$running OSD(s) Running"; return 0; }
    [[ "$elapsed" -ge "$timeout" ]] && { warn "Only $running/$OSD_COUNT OSDs Running after ${timeout}s"; return 1; }
    sleep 15; elapsed=$((elapsed+15))
    info "  OSDs Running: $running/$OSD_COUNT (${elapsed}s/${timeout}s)"
  done
}

exec_ceph() { KC -n "$NAMESPACE" exec deploy/rook-ceph-tools -- ceph "$@" 2>&1; }

# ─── Phase 0: Preflight ───────────────────────────────────────────────────────
preflight() {
  header "=== Phase 0: Preflight ==="
  command -v kubectl >/dev/null || die "kubectl not found in PATH"
  KC cluster-info --request-timeout=10s >/dev/null 2>&1 || die "Cannot reach cluster (check KUBECONFIG)"

  if [[ "$INSTALL_METHOD" == "helm" ]]; then
    command -v helm >/dev/null || die "helm not found — install from https://helm.sh or use --install-method manifest"
  fi

  if [[ "$OSD_MODE" == "pvc" ]]; then
    [[ -z "$BLOCK_SC" ]] && die "--osd-mode pvc requires --block-sc <storageclass>"
    KC get storageclass "$BLOCK_SC" >/dev/null 2>&1 \
      || warn "StorageClass '$BLOCK_SC' not found — will fail at OSD provisioning"
  fi

  if [[ "$OSD_MODE" == "device" && -z "$STORAGE_NODES" ]]; then
    die "--osd-mode device requires --storage-nodes <node1,node2,...> — no nodes specified"
  fi

  if [[ "$MODE" == "prod" && "$OSD_COUNT" -lt 3 ]]; then
    warn "Production mode with fewer than 3 OSDs — no fault tolerance"
  fi
  if [[ "$MODE" == "prod" && -z "$STORAGE_NODES" && -z "$STORAGE_NODE_LABEL" ]]; then
    warn "Production mode: no --storage-nodes or --storage-node-label — Ceph may run on shared nodes"
  fi

  success "Preflight passed  [mode=$MODE  method=$INSTALL_METHOD  osd-mode=$OSD_MODE]"
  info "  OSDs=$OSD_COUNT  MONs=$MON_COUNT  MGRs=$MGR_COUNT  replication=$REPLICATION"
  info "  Resources=$RESOURCE_PROFILE  Monitoring=$ENABLE_MONITORING  Snapshots=$ENABLE_SNAPSHOTS"
}

# ─── Phase 1: Label and taint storage nodes ───────────────────────────────────
label_and_taint_nodes() {
  [[ -z "$STORAGE_NODES" ]] && return
  [[ "$LABEL_NODES" == false && "$TAINT_NODES" == false ]] && return
  $DRY_RUN && { info "[dry-run] Would label/taint nodes: $STORAGE_NODES"; return; }

  header "=== Phase 1: Node preparation ==="
  IFS=',' read -ra node_list <<< "$STORAGE_NODES"
  for node in "${node_list[@]}"; do
    if $LABEL_NODES && [[ -n "$STORAGE_NODE_LABEL" ]]; then
      KC label node "$node" "$STORAGE_NODE_LABEL" --overwrite
      success "Labeled $node: $STORAGE_NODE_LABEL"
    fi
    if $TAINT_NODES; then
      KC taint node "$node" "${CEPH_TAINT_KEY}=${CEPH_TAINT_VALUE}:${CEPH_TAINT_EFFECT}" \
        --overwrite 2>/dev/null || true
      success "Tainted $node: ${CEPH_TAINT_KEY}=${CEPH_TAINT_VALUE}:${CEPH_TAINT_EFFECT}"
    fi
  done
}

# ─── Phase 2: Operator ────────────────────────────────────────────────────────
install_operator() {
  header "=== Phase 2: Rook operator ==="
  if $SKIP_OPERATOR; then info "Skipping (--skip-operator)"; return; fi

  local op_exists
  op_exists=$(KC -n "$NAMESPACE" get deployment rook-ceph-operator --no-headers 2>/dev/null | grep -c . || true)
  if [[ "$op_exists" -gt 0 ]]; then
    info "Rook operator already present — skipping install"
    return
  fi

  if [[ "$INSTALL_METHOD" == "helm" ]]; then
    install_operator_helm
  else
    install_operator_manifest
  fi
}

install_operator_helm() {
  info "Installing Rook ${ROOK_VERSION} via Helm ..."
  $DRY_RUN && { info "[dry-run] helm upgrade --install rook-ceph rook-release/rook-ceph --version $ROOK_VERSION"; return; }

  helm repo add rook-release https://charts.rook.io/release 2>/dev/null || true
  helm repo update rook-release

  local monitoring_flag=""
  $ENABLE_MONITORING && monitoring_flag="--set monitoring.enabled=true"

  # Build optional CSI plugin toleration for external node taints (e.g. GPU nodes).
  # CSI DaemonSet pods run on every node, so they must tolerate any taint present
  # on nodes where workloads will mount Ceph volumes.
  local helm_extra_args=()
  if [[ -n "$TOLERATION_KEY" ]]; then
    helm_extra_args+=(--set-json \
      "csi.pluginTolerations=[{\"key\":\"${TOLERATION_KEY}\",\"operator\":\"Exists\",\"effect\":\"${TOLERATION_EFFECT}\"}]")
  fi

  helm upgrade --install rook-ceph rook-release/rook-ceph \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$ROOK_VERSION" \
    --set image.tag="$ROOK_VERSION" \
    $monitoring_flag \
    "${helm_extra_args[@]+"${helm_extra_args[@]}"}" \
    ${KUBECONFIG:+--kubeconfig "$KUBECONFIG"} \
    --wait --timeout=5m

  success "Helm install complete"
  wait_for_pods "app=rook-ceph-operator" 1 300
}

install_operator_manifest() {
  local base="https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples"
  info "Installing Rook ${ROOK_VERSION} via manifests ..."
  $DRY_RUN && { info "[dry-run] Would apply crds.yaml, common.yaml, operator.yaml from $base"; return; }

  KC apply -f "${base}/crds.yaml"
  KC apply -f "${base}/common.yaml"
  KC apply -f "${base}/operator.yaml"
  wait_for_pods "app=rook-ceph-operator" 1 300
}

# ─── Phase 3: CephCluster ─────────────────────────────────────────────────────
build_placement_yaml() {
  local yaml=""
  if [[ -n "$STORAGE_NODE_LABEL" ]]; then
    local lk="${STORAGE_NODE_LABEL%%=*}" lv="${STORAGE_NODE_LABEL#*=}"
    yaml="${yaml}      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: ${lk}
                  operator: In
                  values:
                    - '${lv}'
"
  fi
  # Emit tolerations block if Ceph taint is active OR an external taint must be tolerated
  if $TAINT_NODES || [[ -n "$TOLERATION_KEY" ]]; then
    yaml="${yaml}      tolerations:
"
    if $TAINT_NODES; then
      yaml="${yaml}        - key: \"${CEPH_TAINT_KEY}\"
          operator: \"Equal\"
          value: \"${CEPH_TAINT_VALUE}\"
          effect: \"${CEPH_TAINT_EFFECT}\"
"
    fi
    if [[ -n "$TOLERATION_KEY" ]]; then
      yaml="${yaml}        - key: \"${TOLERATION_KEY}\"
          operator: \"Equal\"
          value: \"${TOLERATION_VALUE}\"
          effect: \"${TOLERATION_EFFECT}\"
"
    fi
  fi
  echo "$yaml"
}

build_storage_yaml() {
  # Cloud block volumes can detach and reattach on node failure (portable=true).
  # Raw on-prem disks are tied to the node — always portable=false.
  local portable="false"
  [[ "$OSD_MODE" == "pvc" ]] && $PORTABLE && portable="true"

  local node_placement=""
  if [[ -n "$STORAGE_NODE_LABEL" ]]; then
    local lk="${STORAGE_NODE_LABEL%%=*}" lv="${STORAGE_NODE_LABEL#*=}"
    node_placement="        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - key: ${lk}
                      operator: In
                      values:
                        - '${lv}'
"
  fi

  # Spread OSDs across nodes so all 3 don't land on one node (which would
  # leave replication=3 pools undersized and stuck in HEALTH_WARN).
  # preparePlacement governs the prepare/init pod that pins the node at provisioning
  # time — critical for portable: false (on-prem) where that decision is permanent.
  local prepare_placement=""
  if [[ "$OSD_COUNT" -gt 1 ]]; then
    local topo="          topologySpreadConstraints:
            - maxSkew: 1
              topologyKey: kubernetes.io/hostname
              whenUnsatisfiable: DoNotSchedule
              labelSelector:
                matchLabels:
                  app: rook-ceph-osd
"
    if [[ -n "$node_placement" ]]; then
      node_placement="${node_placement}${topo}"
    else
      node_placement="        placement:
${topo}"
    fi
    prepare_placement="        preparePlacement:
          topologySpreadConstraints:
            - maxSkew: 1
              topologyKey: kubernetes.io/hostname
              whenUnsatisfiable: DoNotSchedule
              labelSelector:
                matchLabels:
                  app: rook-ceph-osd-prepare
"
  fi

  if [[ "$OSD_MODE" == "pvc" ]]; then
    cat <<EOF
    useAllNodes: false
    useAllDevices: false
    storageClassDeviceSets:
      - name: set1
        count: ${OSD_COUNT}
        portable: ${portable}
${node_placement}${prepare_placement}        volumeClaimTemplates:
          - metadata:
              name: data
            spec:
              resources:
                requests:
                  storage: ${OSD_SIZE}
              storageClassName: ${BLOCK_SC}
              volumeMode: Block
              accessModes:
                - ReadWriteOnce
EOF
  else
    local nodes_yaml=""
    if [[ -n "$STORAGE_NODES" ]]; then
      IFS=',' read -ra node_list <<< "$STORAGE_NODES"
      IFS=',' read -ra dev_list <<< "$DEVICES"
      for node in "${node_list[@]}"; do
        nodes_yaml="${nodes_yaml}      - name: \"${node}\"
        devices:
"
        for dev in "${dev_list[@]}"; do
          nodes_yaml="${nodes_yaml}          - name: \"${dev}\"
"
        done
      done
    fi
    cat <<EOF
    useAllNodes: false
    useAllDevices: false
    nodes:
${nodes_yaml}    config:
      osdsPerDevice: "1"
EOF
  fi
}

build_resources_yaml() {
  [[ "$RESOURCE_PROFILE" == "none" ]] && return

  local mon_req_cpu mon_req_mem mon_lim_cpu mon_lim_mem
  local mgr_req_cpu mgr_req_mem mgr_lim_cpu mgr_lim_mem
  local osd_req_cpu osd_req_mem osd_lim_cpu osd_lim_mem
  local mds_req_cpu mds_req_mem mds_lim_cpu mds_lim_mem

  if [[ "$RESOURCE_PROFILE" == "minimal" ]]; then
    mon_req_cpu="250m";  mon_req_mem="256Mi"; mon_lim_cpu="500m";  mon_lim_mem="1Gi"
    mgr_req_cpu="250m";  mgr_req_mem="256Mi"; mgr_lim_cpu="1";     mgr_lim_mem="1Gi"
    osd_req_cpu="500m";  osd_req_mem="1Gi";   osd_lim_cpu="1";     osd_lim_mem="2Gi"
    mds_req_cpu="250m";  mds_req_mem="256Mi"; mds_lim_cpu="1";     mds_lim_mem="1Gi"
  else  # standard
    mon_req_cpu="500m";  mon_req_mem="512Mi"; mon_lim_cpu="1";     mon_lim_mem="2Gi"
    mgr_req_cpu="500m";  mgr_req_mem="512Mi"; mgr_lim_cpu="2";     mgr_lim_mem="2Gi"
    osd_req_cpu="1";     osd_req_mem="2Gi";   osd_lim_cpu="2";     osd_lim_mem="4Gi"
    mds_req_cpu="500m";  mds_req_mem="512Mi"; mds_lim_cpu="2";     mds_lim_mem="2Gi"
  fi

  cat <<EOF
  resources:
    mon:
      requests:
        cpu: "${mon_req_cpu}"
        memory: "${mon_req_mem}"
      limits:
        cpu: "${mon_lim_cpu}"
        memory: "${mon_lim_mem}"
    mgr:
      requests:
        cpu: "${mgr_req_cpu}"
        memory: "${mgr_req_mem}"
      limits:
        cpu: "${mgr_lim_cpu}"
        memory: "${mgr_lim_mem}"
    osd:
      requests:
        cpu: "${osd_req_cpu}"
        memory: "${osd_req_mem}"
      limits:
        cpu: "${osd_lim_cpu}"
        memory: "${osd_lim_mem}"
    mds:
      requests:
        cpu: "${mds_req_cpu}"
        memory: "${mds_req_mem}"
      limits:
        cpu: "${mds_lim_cpu}"
        memory: "${mds_lim_mem}"
EOF
}

install_cephcluster() {
  header "=== Phase 3: CephCluster ==="
  local placement storage resources placement_block=""

  placement=$(build_placement_yaml)
  storage=$(build_storage_yaml)
  resources=$(build_resources_yaml)

  [[ -n "$placement" ]] && placement_block="  placement:
    all:
${placement}"

  cat <<EOF | kubectl_apply
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: ${NAMESPACE}
spec:
  cephVersion:
    image: quay.io/ceph/ceph:${CEPH_VERSION}
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  skipUpgradeChecks: false
  continueUpgradeAfterChecksEvenIfNotHealthy: false
  mon:
    count: ${MON_COUNT}
    allowMultiplePerNode: ${ALLOW_MULTIPLE_MON}
  mgr:
    count: ${MGR_COUNT}
    allowMultiplePerNode: false
    modules:
      - name: pg_autoscaler
        enabled: true
  dashboard:
    enabled: true
    ssl: false
  monitoring:
    enabled: ${ENABLE_MONITORING}
  crashCollector:
    disable: false
  cleanupPolicy:
    confirmation: ""
  removeOSDsIfOutAndSafeToRemove: false
${resources}
${placement_block}
  storage:
${storage}
EOF
  success "CephCluster applied"
}

# ─── Phase 4: Wait ────────────────────────────────────────────────────────────
wait_cluster() {
  header "=== Phase 4: Waiting for cluster ==="
  $DRY_RUN && { info "[dry-run] Skipping wait"; return; }

  wait_for_pods "app=rook-ceph-mon" "$MON_COUNT" 300
  wait_for_pods "app=rook-ceph-mgr" 1 300
  wait_for_osd 600
  wait_for_cephcluster 900
}

# ─── Phase 5: StorageClasses ──────────────────────────────────────────────────
install_storageclasses() {
  header "=== Phase 5: StorageClasses ==="

  local require_safe="false"
  [[ "$REPLICATION" -ge 2 ]] && require_safe="true"

  cat <<EOF | kubectl_apply
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: ${NAMESPACE}
spec:
  failureDomain: host
  replicated:
    size: ${REPLICATION}
    requireSafeReplicaSize: ${require_safe}
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-block
provisioner: ${NAMESPACE}.rbd.csi.ceph.com
parameters:
  clusterID: ${NAMESPACE}
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: ${NAMESPACE}
reclaimPolicy: Delete
allowVolumeExpansion: true
---
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: myfs
  namespace: ${NAMESPACE}
spec:
  metadataPool:
    replicated:
      size: ${REPLICATION}
      requireSafeReplicaSize: ${require_safe}
  dataPools:
    - name: replicated
      replicated:
        size: ${REPLICATION}
        requireSafeReplicaSize: ${require_safe}
  preserveFilesystemOnDelete: false
  metadataServer:
    activeCount: 1
    activeStandby: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-cephfs
provisioner: ${NAMESPACE}.cephfs.csi.ceph.com
parameters:
  clusterID: ${NAMESPACE}
  fsName: myfs
  pool: myfs-replicated
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: ${NAMESPACE}
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
  success "StorageClasses: rook-ceph-block (RWO)  rook-cephfs (RWX)"

  # Mark rook-cephfs as the cluster default so PVCs without an explicit
  # storageClassName are provisioned by CephFS (RWX).
  if ! $DRY_RUN; then
    KC annotate storageclass rook-cephfs \
      storageclass.kubernetes.io/is-default-class=true --overwrite
    success "rook-cephfs set as default StorageClass"
  fi
}

# ─── Phase 6: Fix pool replication (single-OSD only) ─────────────────────────
fix_pool_replication() {
  [[ "$REPLICATION" -ge 2 ]] && return
  $DRY_RUN && { info "[dry-run] Skipping pool replication fix"; return; }

  header "=== Phase 6: Pool replication fix ==="
  deploy_toolbox; sleep 10

  local pools
  pools=$(exec_ceph osd pool ls 2>/dev/null || true)
  for pool in $pools; do
    exec_ceph osd pool set "$pool" size "$REPLICATION" --yes-i-really-mean-it >/dev/null 2>&1 || true
    exec_ceph osd pool set "$pool" min_size "$REPLICATION" >/dev/null 2>&1 || true
  done
  exec_ceph config set global osd_pool_default_size "$REPLICATION" >/dev/null 2>&1 || true
  exec_ceph config set global osd_pool_default_min_size "$REPLICATION" >/dev/null 2>&1 || true
  success "Pool size set to $REPLICATION (single-OSD mode)"
}

# ─── Phase 7: VolumeSnapshot support ─────────────────────────────────────────
install_snapshots() {
  $ENABLE_SNAPSHOTS || return 0
  header "=== Phase 7: VolumeSnapshot support ==="

  local base="https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/${SNAPSHOTTER_VERSION}"

  if $DRY_RUN; then
    info "[dry-run] Would install VolumeSnapshot CRDs + controller (${SNAPSHOTTER_VERSION})"
    return
  fi

  info "Installing VolumeSnapshot CRDs ${SNAPSHOTTER_VERSION} ..."
  KC apply -f "${base}/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml"
  KC apply -f "${base}/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml"
  KC apply -f "${base}/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml"

  info "Installing snapshot controller ..."
  KC apply -f "${base}/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml"
  KC apply -f "${base}/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml"

  info "Creating VolumeSnapshotClasses ..."
  cat <<EOF | KC apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-rbdplugin-snapclass
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: ${NAMESPACE}.rbd.csi.ceph.com
parameters:
  clusterID: ${NAMESPACE}
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: ${NAMESPACE}
deletionPolicy: Delete
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-cephfsplugin-snapclass
driver: ${NAMESPACE}.cephfs.csi.ceph.com
parameters:
  clusterID: ${NAMESPACE}
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: ${NAMESPACE}
deletionPolicy: Delete
EOF
  success "VolumeSnapshot CRDs, controller, and SnapshotClasses installed"
}

# ─── Phase 8: Monitoring ──────────────────────────────────────────────────────
install_monitoring() {
  $ENABLE_MONITORING || return 0
  header "=== Phase 8: Prometheus monitoring ==="

  # monitoring.enabled: true in the CephCluster spec tells Rook to create and
  # own the rook-ceph-mgr ServiceMonitor automatically. Creating a second one
  # here would clobber Rook's ownerReference, causing reconcile churn.
  # Phase 8 only verifies that Prometheus Operator is present so scraping works.
  if KC get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    success "Prometheus Operator detected — Rook will create the ServiceMonitor automatically"
    info "  Scrape target: MGR pod port 9283 (/metrics)"
  else
    warn "Prometheus Operator CRDs not found — ServiceMonitor will not be functional"
    info "  Install Prometheus Operator (kube-prometheus-stack) to enable scraping"
    info "  Metrics endpoint is still exposed at MGR pod port 9283 (/metrics)"
  fi
}

# ─── Phase 9: Dashboard ───────────────────────────────────────────────────────
install_dashboard() {
  $DASHBOARD || return 0
  header "=== Phase 9: Ceph Dashboard ==="
  $DRY_RUN && { info "[dry-run] Would expose dashboard via NodePort 32200"; return; }

  cat <<EOF | KC apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rook-ceph-mgr-dashboard-nodeport
  namespace: ${NAMESPACE}
spec:
  type: NodePort
  selector:
    app: rook-ceph-mgr
    rook_cluster: ${NAMESPACE}
    mgr_role: active
  ports:
    - name: dashboard
      port: 7000
      targetPort: 7000
      nodePort: 32200
EOF

  local node_ip
  node_ip=$(KC get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null \
    || KC get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  success "Dashboard exposed: http://${node_ip}:32200"
  info "  Default credentials: admin / $(KC -n "$NAMESPACE" get secret rook-ceph-dashboard-password \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo '<fetch from secret rook-ceph-dashboard-password>')"
}

# ─── Toolbox ──────────────────────────────────────────────────────────────────
deploy_toolbox() {
  local existing
  existing=$(KC -n "$NAMESPACE" get deployment rook-ceph-tools --no-headers 2>/dev/null | grep -c . || true)
  [[ "$existing" -gt 0 ]] && return

  info "Deploying Ceph toolbox ..."
  KC apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rook-ceph-tools
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rook-ceph-tools
  template:
    metadata:
      labels:
        app: rook-ceph-tools
    spec:
      tolerations:
      - operator: Exists
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: rook-ceph-tools
        image: quay.io/ceph/ceph:${CEPH_VERSION}
        command:
        - /bin/bash
        - -c
        - |
          MON=\$(cat /etc/rook/mon-endpoints | sed 's/[a-z]=//g')
          cat > /etc/ceph/ceph.conf <<CONF
          [global]
          mon host = \${MON}
          CONF
          cat > /etc/ceph/keyring <<KR
          [client.admin]
          key = \${ROOK_CEPH_SECRET}
          KR
          sleep infinity
        env:
        - name: ROOK_CEPH_USERNAME
          valueFrom:
            secretKeyRef:
              name: rook-ceph-mon
              key: ceph-username
        - name: ROOK_CEPH_SECRET
          valueFrom:
            secretKeyRef:
              name: rook-ceph-mon
              key: ceph-secret
        volumeMounts:
        - mountPath: /etc/ceph
          name: ceph-config
        - mountPath: /etc/rook
          name: mon-endpoint-volume
      volumes:
      - name: ceph-config
        emptyDir: {}
      - name: mon-endpoint-volume
        configMap:
          name: rook-ceph-mon-endpoints
          items:
          - key: data
            path: mon-endpoints
EOF
  wait_for_pods "app=rook-ceph-tools" 1 120
}

# ─── Phase 10: Validate ───────────────────────────────────────────────────────
validate() {
  header "=== Phase 10: Validation ==="
  $SKIP_VALIDATE && { info "Skipping (--skip-validate)"; return; }
  $DRY_RUN && { info "[dry-run] Skipping"; return; }

  KC apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rookfs-test-rbd
  namespace: ${NAMESPACE}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-ceph-block
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rookfs-test-cephfs
  namespace: ${NAMESPACE}
spec:
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-cephfs
EOF

  local elapsed=0
  while true; do
    local rbd cephfs
    rbd=$(KC -n "$NAMESPACE" get pvc rookfs-test-rbd -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    cephfs=$(KC -n "$NAMESPACE" get pvc rookfs-test-cephfs -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    [[ "$rbd" == "Bound" && "$cephfs" == "Bound" ]] && { success "RBD PVC: Bound"; success "CephFS PVC: Bound"; break; }
    [[ "$elapsed" -ge 120 ]] && { error "PVC validation timed out (RBD=$rbd CephFS=$cephfs)"; break; }
    sleep 10; elapsed=$((elapsed+10))
    info "  RBD=$rbd CephFS=$cephfs (${elapsed}s)"
  done

  KC -n "$NAMESPACE" delete pvc rookfs-test-rbd rookfs-test-cephfs --ignore-not-found >/dev/null 2>&1 || true
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}  Rook/Ceph installation complete${NC}"
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
  echo ""
  KC -n "$NAMESPACE" get cephcluster rook-ceph \
    -o custom-columns="CLUSTER:.metadata.name,PHASE:.status.phase,HEALTH:.status.ceph.health,OSDS:.status.storage.osd.storeType" 2>/dev/null || true
  echo ""
  KC get storageclass 2>/dev/null | grep rook || true
  echo ""
  info "KubeSlice cluster storageCapabilities:"
  KC get clusters.controller.kubeslice.io -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', []):
    name = item['metadata']['name']
    caps = item.get('status', {}).get('storageCapabilities')
    print(f'  {name}:')
    print(json.dumps(caps, indent=4) if caps else '    (none)')
" 2>/dev/null || true
  echo ""
  echo "  Toolbox:     kubectl -n ${NAMESPACE} exec deploy/rook-ceph-tools -- ceph status"
  echo "  Block (RWO): rook-ceph-block"
  echo "  FS    (RWX): rook-cephfs"
  $ENABLE_SNAPSHOTS && echo "  Snapshots:   csi-rbdplugin-snapclass (RBD)  csi-cephfsplugin-snapclass (CephFS)"
  $ENABLE_MONITORING && echo "  Metrics:     MGR pod port 9283/metrics"
  $DASHBOARD && echo "  Dashboard:   NodePort 32200"
  echo ""
  if [[ "$REPLICATION" -eq 1 ]]; then
    warn "Single-OSD: no replication — suitable for dev/UAT only"
    warn "  Expected: HEALTH_WARN (no replicas configured)"
  fi
  if [[ "$MODE" == "prod" ]]; then
    echo -e "  ${GREEN}Production install — verify:${NC}"
    echo "    ceph status         → HEALTH_OK"
    echo "    ceph osd tree       → all OSDs up/in"
    echo "    ceph df             → available capacity"
  fi
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}Rook/Ceph Installer${NC}  mode=${MODE}  rook=${ROOK_VERSION}  ceph=${CEPH_VERSION}"
  echo ""

  apply_mode_defaults
  validate_pvc_mode
  compute_replication

  preflight
  label_and_taint_nodes
  install_operator
  install_cephcluster
  wait_cluster
  install_storageclasses
  fix_pool_replication
  deploy_toolbox
  install_snapshots
  install_monitoring
  install_dashboard
  validate
  print_summary
}

main
