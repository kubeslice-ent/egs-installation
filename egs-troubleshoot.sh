#!/bin/bash

#===============================================================================
# EGS Troubleshooting Bundle Generator
# Version: 1.15.5
# Description: Comprehensive diagnostic bundle generator for EGS (Enterprise GPU Slice)
#              deployments. Collects logs, configurations, and cluster state for
#              troubleshooting and support purposes.
#===============================================================================

set -e

# Script metadata
SCRIPT_VERSION="1.15.5"
SCRIPT_NAME="egs-troubleshoot.sh"
BUNDLE_PREFIX="egs-troubleshoot-bundle"

# Default values
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
KUBECONTEXT=""
OUTPUT_DIR=""
S3_BUCKET=""
S3_REGION="us-east-1"
S3_PREFIX=""
AWS_PROFILE=""
VERBOSE=false
INCLUDE_SECRETS=false
LOG_TAIL_LINES=1000
INCLUDE_PREVIOUS_LOGS=true
SKIP_LOGS=false
SKIP_METRICS=false
COLLECT_ALL_NAMESPACES=false
CLUSTER_TYPE=""  # auto-detected: controller, worker, or standalone
MULTI_CLUSTER_MODE=false
ADDITIONAL_KUBECONFIGS=()
CLUSTER_NAME=""

# EGS Core namespaces to collect (always collected)
EGS_CORE_NAMESPACES=(
    "kubeslice-controller"
    "kubeslice-system"
    "egs-monitoring"
    "egs-gpu-operator"
    "kt-postgresql"
    "minio"
    "spire"
    "kubeslice-nsm-webhook-system"
)

# EGS Project namespaces (dynamically discovered)
# These are created by KubeSlice for each project (e.g., kubeslice-avesha, kubeslice-vertex)
EGS_PROJECT_NAMESPACES=()

# Slice application namespaces (dynamically discovered)
# These are namespaces created by slices (e.g., bookinfo-1, iperf-1, vllm-demo-1)
SLICE_APP_NAMESPACES=()

# Additional namespaces that might be relevant for troubleshooting
ADDITIONAL_NAMESPACES=(
    "kube-system"
    "cert-manager"
    "ingress-nginx"
    "default"
)

# EGS CRD API groups - Complete list of all KubeSlice and related CRDs
EGS_API_GROUPS=(
    # KubeSlice Core
    "controller.kubeslice.io"
    "worker.kubeslice.io"
    "networking.kubeslice.io"
    # KubeSlice AI/GPU
    "inventory.kubeslice.io"
    "aiops.kubeslice.io"
    "gpr.kubeslice.io"
    # Monitoring
    "monitoring.coreos.com"
    # NVIDIA GPU Operator
    "nvidia.com"
    "nfd.k8s-sigs.io"
    # KServe (AI/ML Inference)
    "serving.kserve.io"
    # Network Service Mesh
    "networkservicemesh.io"
    # Spire (SPIFFE/SPIRE)
    "spire.spiffe.io"
    # Gateway API
    "gateway.networking.k8s.io"
    "gateway.envoyproxy.io"
    # Calico (Network Policies)
    "crd.projectcalico.org"
)

# Resource types to collect
RESOURCE_TYPES=(
    "pods"
    "deployments"
    "daemonsets"
    "statefulsets"
    "replicasets"
    "jobs"
    "cronjobs"
    "configmaps"
    "services"
    "endpoints"
    "serviceaccounts"
    "roles"
    "rolebindings"
    "clusterroles"
    "clusterrolebindings"
    "ingresses"
    "networkpolicies"
    "persistentvolumeclaims"
    "persistentvolumes"
    "storageclasses"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#===============================================================================
# Helper Functions
#===============================================================================

print_banner() {
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│                     🔧 EGS TROUBLESHOOTING BUNDLE GENERATOR                         │"
    echo "├─────────────────────────────────────────────────────────────────────────────────────┤"
    echo "│  Version: $SCRIPT_VERSION                                                                    │"
    echo "│  Collects diagnostic information for EGS deployments                               │"
    echo "└─────────────────────────────────────────────────────────────────────────────────────┘"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📋 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

EGS Troubleshooting Bundle Generator - Collects diagnostic information for EGS deployments.

OPTIONS:
    -h, --help                  Show this help message
    -v, --version               Show script version
    --verbose                   Enable verbose output
    -k, --kubeconfig PATH       Path to kubeconfig file (default: \$KUBECONFIG or ~/.kube/config)
    -c, --context CONTEXT       Kubernetes context to use (default: current context)
    -o, --output-dir DIR        Output directory for the bundle (default: ./egs-troubleshoot-bundle-TIMESTAMP)
    -n, --namespace NS          Additional namespace to include (can be specified multiple times)
    --all-namespaces            Collect from all namespaces (use with caution)
    --include-secrets           Include secrets in the bundle (values will be base64 encoded)
    --log-lines NUM             Number of log lines to collect per container (default: 1000)
    --skip-logs                 Skip collecting container logs
    --skip-metrics              Skip collecting Prometheus metrics
    --no-previous-logs          Don't collect previous container logs

S3 UPLOAD OPTIONS:
    --s3-bucket BUCKET          S3 bucket name for upload
    --s3-region REGION          S3 bucket region (default: us-east-1)
    --s3-prefix PREFIX          S3 key prefix for the bundle
    --aws-profile PROFILE       AWS profile to use for S3 upload

MULTI-CLUSTER OPTIONS:
    --cluster-name NAME         Identifier for this cluster in the bundle
    --add-kubeconfig PATH       Additional kubeconfig for multi-cluster collection

EXAMPLES:
    # Basic usage - collect bundle with default settings
    $SCRIPT_NAME

    # Specify kubeconfig and context
    $SCRIPT_NAME -k ~/.kube/my-config -c my-cluster

    # Collect from a specific cluster with a name
    $SCRIPT_NAME -k ~/.kube/controller.yaml --cluster-name "egs-controller"

    # Upload bundle to S3
    $SCRIPT_NAME --s3-bucket my-support-bucket --s3-region us-west-2

    # Collect from all namespaces with secrets
    $SCRIPT_NAME --all-namespaces --include-secrets

    # Quick collection without logs
    $SCRIPT_NAME --skip-logs
    
    # Multi-cluster: Collect from controller and workers
    $SCRIPT_NAME -k ~/.kube/controller.yaml --cluster-name "controller" \\
        --s3-bucket support-bucket --s3-region us-west-2
    $SCRIPT_NAME -k ~/.kube/worker1.yaml --cluster-name "worker-1" \\
        --s3-bucket support-bucket --s3-region us-west-2
    $SCRIPT_NAME -k ~/.kube/worker2.yaml --cluster-name "worker-2" \\
        --s3-bucket support-bucket --s3-region us-west-2

CURL ONE-LINER:
    curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- [OPTIONS]

    # Example: Basic collection
    curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \\
        --kubeconfig ~/.kube/config

    # Example: With S3 upload
    curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \\
        --kubeconfig ~/.kube/config \\
        --s3-bucket my-support-bucket \\
        --s3-region us-west-2

    # Example: Controller cluster with S3 upload
    curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \\
        --kubeconfig ~/.kube/controller-kubeconfig.yaml \\
        --cluster-name "egs-controller" \\
        --s3-bucket avesha-support-bundles \\
        --s3-region us-east-1

    # Note: The script is also available at:
    # https://repo.egs.avesha.io/egs-troubleshoot.sh

EOF
}

show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

#===============================================================================
# Prerequisites Check
#===============================================================================

check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local prerequisites_met=true
    
    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl is not installed or not in PATH"
        prerequisites_met=false
    else
        local kubectl_version=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "unknown")
        log_info "✅ kubectl found: $kubectl_version"
    fi
    
    # Check jq (optional but recommended)
    if ! command -v jq &>/dev/null; then
        log_warn "jq is not installed - some features may be limited"
    else
        log_info "✅ jq found: $(jq --version 2>/dev/null || echo 'unknown')"
    fi
    
    # Check tar
    if ! command -v tar &>/dev/null; then
        log_error "tar is not installed or not in PATH"
        prerequisites_met=false
    else
        log_info "✅ tar found"
    fi
    
    # Check gzip
    if ! command -v gzip &>/dev/null; then
        log_warn "gzip is not installed - bundle will not be compressed"
    else
        log_info "✅ gzip found"
    fi
    
    # Check AWS CLI if S3 upload is requested
    if [ -n "$S3_BUCKET" ]; then
        if ! command -v aws &>/dev/null; then
            log_error "AWS CLI is not installed but S3 upload was requested"
            prerequisites_met=false
        else
            log_info "✅ AWS CLI found: $(aws --version 2>/dev/null | head -1)"
        fi
    fi
    
    # Verify kubeconfig exists
    if [ ! -f "$KUBECONFIG" ]; then
        log_error "Kubeconfig file not found: $KUBECONFIG"
        prerequisites_met=false
    else
        log_info "✅ Kubeconfig found: $KUBECONFIG"
    fi
    
    # Verify kubectl can connect to cluster
    local kubectl_cmd="kubectl --kubeconfig=$KUBECONFIG"
    if [ -n "$KUBECONTEXT" ]; then
        kubectl_cmd="$kubectl_cmd --context=$KUBECONTEXT"
    fi
    
    if ! $kubectl_cmd cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        prerequisites_met=false
    else
        log_info "✅ Successfully connected to Kubernetes cluster"
    fi
    
    if [ "$prerequisites_met" = false ]; then
        log_error "Prerequisites check failed. Please fix the issues above and try again."
        exit 1
    fi
    
    log_info "✅ All prerequisites met"
}

#===============================================================================
# Kubectl Wrapper
#===============================================================================

kctl() {
    local cmd="kubectl --kubeconfig=$KUBECONFIG"
    if [ -n "$KUBECONTEXT" ]; then
        cmd="$cmd --context=$KUBECONTEXT"
    fi
    $cmd "$@"
}

#===============================================================================
# Collection Functions
#===============================================================================

detect_cluster_type() {
    log_section "Detecting Cluster Type"
    
    local has_controller_ns=false
    local has_worker_ns=false
    local controller_pods=0
    local worker_pods=0
    
    # Check for kubeslice-controller namespace
    if kctl get namespace kubeslice-controller &>/dev/null; then
        has_controller_ns=true
        controller_pods=$(kctl get pods -n kubeslice-controller 2>/dev/null | grep -c "kubeslice-controller-manager.*Running" || echo "0")
    fi
    
    # Check for kubeslice-system namespace
    if kctl get namespace kubeslice-system &>/dev/null; then
        has_worker_ns=true
        worker_pods=$(kctl get pods -n kubeslice-system 2>/dev/null | grep -c "kubeslice-operator.*Running" || echo "0")
    fi
    
    # Determine cluster type based on what's found
    if [ "$has_controller_ns" = true ] && [ "$has_worker_ns" = true ]; then
        if [ "$controller_pods" -gt 0 ] && [ "$worker_pods" -gt 0 ]; then
            CLUSTER_TYPE="standalone"
            log_info "🔄 Detected: STANDALONE cluster (Controller + Worker on same cluster)"
            log_info "   - Controller pods running: $controller_pods"
            log_info "   - Worker operator pods running: $worker_pods"
            return
        elif [ "$controller_pods" -gt 0 ]; then
            CLUSTER_TYPE="controller"
            log_info "🎮 Detected: CONTROLLER cluster"
            log_info "   - kubeslice-controller namespace found"
            log_info "   - Controller pods running: $controller_pods"
            return
        elif [ "$worker_pods" -gt 0 ]; then
            CLUSTER_TYPE="worker"
            log_info "👷 Detected: WORKER cluster"
            log_info "   - kubeslice-system namespace found"
            log_info "   - Worker operator pods running: $worker_pods"
            return
        fi
    elif [ "$has_controller_ns" = true ] && [ "$controller_pods" -gt 0 ]; then
        CLUSTER_TYPE="controller"
        log_info "🎮 Detected: CONTROLLER cluster"
        log_info "   - kubeslice-controller namespace found"
        log_info "   - Controller pods running: $controller_pods"
        return
    elif [ "$has_worker_ns" = true ] && [ "$worker_pods" -gt 0 ]; then
        CLUSTER_TYPE="worker"
        log_info "👷 Detected: WORKER cluster"
        log_info "   - kubeslice-system namespace found"
        log_info "   - Worker operator pods running: $worker_pods"
        return
    fi
    
    CLUSTER_TYPE="unknown"
    log_warn "⚠️ Could not determine cluster type. Will collect all available resources."
}

get_cluster_name() {
    # Try to get cluster name from various sources
    if [ -n "$CLUSTER_NAME" ]; then
        echo "$CLUSTER_NAME"
        return
    fi
    
    # Try from kubeconfig context
    local context_name=$(kctl config current-context 2>/dev/null || echo "")
    if [ -n "$context_name" ]; then
        echo "$context_name" | sed 's/-ctx$//' | sed 's/^gke_[^_]*_[^_]*_//' | sed 's/^arn:aws:eks:[^:]*:[^:]*:cluster\///'
        return
    fi
    
    echo "cluster"
}

discover_egs_namespaces() {
    log_section "Discovering EGS-Related Namespaces"
    
    # Discover KubeSlice project namespaces (namespaces starting with kubeslice-)
    log_info "Discovering KubeSlice project namespaces..."
    local project_ns=$(kctl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "^kubeslice-" | grep -v -E "^kubeslice-(controller|system|nsm-webhook-system)$" || true)
    for ns in $project_ns; do
        if [[ ! " ${EGS_CORE_NAMESPACES[*]} " =~ " ${ns} " ]]; then
            EGS_PROJECT_NAMESPACES+=("$ns")
            log_debug "  Found project namespace: $ns"
        fi
    done
    log_info "Found ${#EGS_PROJECT_NAMESPACES[@]} project namespace(s)"
    
    # Discover slice application namespaces by looking at slice resources
    log_info "Discovering slice application namespaces..."
    local slice_ns=$(kctl get slices.networking.kubeslice.io --all-namespaces -o jsonpath='{range .items[*]}{.spec.namespaceIsolationProfile.applicationNamespaces[*]}{" "}{end}' 2>/dev/null | tr ' ' '\n' | sort -u || true)
    for ns in $slice_ns; do
        if [ -n "$ns" ] && kctl get namespace "$ns" &>/dev/null; then
            SLICE_APP_NAMESPACES+=("$ns")
            log_debug "  Found slice app namespace: $ns"
        fi
    done
    
    # Also discover namespaces that match common slice patterns
    local pattern_ns=$(kctl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "^(bookinfo|iperf|vllm|ignition|boutique)-[0-9]+$" || true)
    for ns in $pattern_ns; do
        if [[ ! " ${SLICE_APP_NAMESPACES[*]} " =~ " ${ns} " ]]; then
            SLICE_APP_NAMESPACES+=("$ns")
            log_debug "  Found slice app namespace (pattern): $ns"
        fi
    done
    log_info "Found ${#SLICE_APP_NAMESPACES[@]} slice application namespace(s)"
    
    # Print summary
    log_info "📊 Namespace Discovery Summary:"
    log_info "  - Core EGS namespaces: ${#EGS_CORE_NAMESPACES[@]}"
    log_info "  - Project namespaces: ${#EGS_PROJECT_NAMESPACES[@]}"
    log_info "  - Slice app namespaces: ${#SLICE_APP_NAMESPACES[@]}"
    log_info "  - Additional namespaces: ${#ADDITIONAL_NAMESPACES[@]}"
}

collect_cluster_info() {
    log_section "Collecting Cluster Information"
    
    local cluster_dir="$OUTPUT_DIR/cluster-info"
    mkdir -p "$cluster_dir"
    
    log_info "Collecting cluster info..."
    kctl cluster-info dump > "$cluster_dir/cluster-info-dump.txt" 2>&1 || true
    
    log_info "Collecting cluster version..."
    kctl version -o yaml > "$cluster_dir/version.yaml" 2>&1 || true
    
    log_info "Collecting API resources..."
    kctl api-resources -o wide > "$cluster_dir/api-resources.txt" 2>&1 || true
    
    log_info "Collecting API versions..."
    kctl api-versions > "$cluster_dir/api-versions.txt" 2>&1 || true
    
    log_info "Collecting component statuses..."
    kctl get componentstatuses -o yaml > "$cluster_dir/component-statuses.yaml" 2>&1 || true
    
    log_info "Collecting cluster context info..."
    kctl config view --minify -o yaml > "$cluster_dir/current-context.yaml" 2>&1 || true
    
    log_info "✅ Cluster information collected"
}

collect_node_info() {
    log_section "Collecting Node Information"
    
    local nodes_dir="$OUTPUT_DIR/nodes"
    mkdir -p "$nodes_dir"
    
    log_info "Collecting node list..."
    kctl get nodes -o wide > "$nodes_dir/nodes-list.txt" 2>&1 || true
    
    log_info "Collecting detailed node info..."
    kctl get nodes -o yaml > "$nodes_dir/nodes-full.yaml" 2>&1 || true
    
    log_info "Collecting node descriptions..."
    kctl describe nodes > "$nodes_dir/nodes-describe.txt" 2>&1 || true
    
    log_info "Collecting node labels..."
    kctl get nodes --show-labels > "$nodes_dir/nodes-labels.txt" 2>&1 || true
    
    log_info "Collecting node capacity and allocatable resources..."
    kctl get nodes -o custom-columns=\
'NAME:.metadata.name,'\
'STATUS:.status.conditions[?(@.type=="Ready")].status,'\
'CPU_CAPACITY:.status.capacity.cpu,'\
'CPU_ALLOCATABLE:.status.allocatable.cpu,'\
'MEMORY_CAPACITY:.status.capacity.memory,'\
'MEMORY_ALLOCATABLE:.status.allocatable.memory,'\
'GPU_CAPACITY:.status.capacity.nvidia\.com/gpu,'\
'GPU_ALLOCATABLE:.status.allocatable.nvidia\.com/gpu,'\
'PODS_CAPACITY:.status.capacity.pods,'\
'PODS_ALLOCATABLE:.status.allocatable.pods' \
    > "$nodes_dir/nodes-resources.txt" 2>&1 || true
    
    log_info "Collecting node taints..."
    kctl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key' \
    > "$nodes_dir/nodes-taints.txt" 2>&1 || true
    
    # Collect GPU-specific node info
    log_info "Collecting GPU node information..."
    kctl get nodes -o json 2>/dev/null | jq -r '
        .items[] | 
        select(.status.capacity["nvidia.com/gpu"] != null) | 
        {
            name: .metadata.name,
            gpu_capacity: .status.capacity["nvidia.com/gpu"],
            gpu_allocatable: .status.allocatable["nvidia.com/gpu"],
            labels: .metadata.labels
        }
    ' > "$nodes_dir/gpu-nodes.json" 2>&1 || true
    
    log_info "✅ Node information collected"
}

collect_namespace_resources() {
    local namespace="$1"
    local ns_dir="$OUTPUT_DIR/namespaces/$namespace"
    
    log_info "📦 Collecting resources from namespace: $namespace"
    mkdir -p "$ns_dir"
    
    # Check if namespace exists
    if ! kctl get namespace "$namespace" &>/dev/null; then
        log_warn "Namespace $namespace does not exist, skipping..."
        echo "Namespace does not exist" > "$ns_dir/NOT_FOUND.txt"
        return
    fi
    
    # Collect all standard resources
    for resource_type in "${RESOURCE_TYPES[@]}"; do
        log_debug "  Collecting $resource_type..."
        kctl get "$resource_type" -n "$namespace" -o yaml > "$ns_dir/${resource_type}.yaml" 2>&1 || true
        kctl get "$resource_type" -n "$namespace" -o wide > "$ns_dir/${resource_type}-list.txt" 2>&1 || true
    done
    
    # Collect secrets (with option to include values)
    if [ "$INCLUDE_SECRETS" = true ]; then
        kctl get secrets -n "$namespace" -o yaml > "$ns_dir/secrets-full.yaml" 2>&1 || true
    else
        # Collect secret metadata only (no values)
        kctl get secrets -n "$namespace" -o custom-columns=\
'NAME:.metadata.name,TYPE:.type,DATA_KEYS:.data|keys,AGE:.metadata.creationTimestamp' \
        > "$ns_dir/secrets-list.txt" 2>&1 || true
    fi
    
    # Collect events
    log_debug "  Collecting events..."
    kctl get events -n "$namespace" --sort-by='.lastTimestamp' > "$ns_dir/events.txt" 2>&1 || true
    kctl get events -n "$namespace" -o yaml > "$ns_dir/events.yaml" 2>&1 || true
    
    # Collect resource descriptions
    log_debug "  Collecting resource descriptions..."
    kctl describe all -n "$namespace" > "$ns_dir/describe-all.txt" 2>&1 || true
    
    # Collect Helm releases in this namespace
    if command -v helm &>/dev/null; then
        log_debug "  Collecting Helm releases..."
        helm list -n "$namespace" --kubeconfig="$KUBECONFIG" > "$ns_dir/helm-releases.txt" 2>&1 || true
        helm list -n "$namespace" --kubeconfig="$KUBECONFIG" -o yaml > "$ns_dir/helm-releases.yaml" 2>&1 || true
    fi
}

collect_pod_logs() {
    local namespace="$1"
    local logs_dir="$OUTPUT_DIR/namespaces/$namespace/logs"
    
    if [ "$SKIP_LOGS" = true ]; then
        log_debug "  Skipping logs collection (--skip-logs)"
        return
    fi
    
    mkdir -p "$logs_dir"
    
    log_info "📝 Collecting pod logs from namespace: $namespace"
    
    # Get all pods in namespace
    local pods=$(kctl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for pod in $pods; do
        log_debug "  Collecting logs for pod: $pod"
        local pod_dir="$logs_dir/$pod"
        mkdir -p "$pod_dir"
        
        # Get containers in the pod
        local containers=$(kctl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
        local init_containers=$(kctl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null)
        
        # Collect logs for each container
        for container in $containers; do
            log_debug "    Container: $container"
            kctl logs "$pod" -n "$namespace" -c "$container" --tail="$LOG_TAIL_LINES" \
                > "$pod_dir/${container}.log" 2>&1 || true
            
            # Collect previous logs if container has restarted
            if [ "$INCLUDE_PREVIOUS_LOGS" = true ]; then
                kctl logs "$pod" -n "$namespace" -c "$container" --previous --tail="$LOG_TAIL_LINES" \
                    > "$pod_dir/${container}-previous.log" 2>&1 || true
            fi
        done
        
        # Collect init container logs
        for container in $init_containers; do
            log_debug "    Init Container: $container"
            kctl logs "$pod" -n "$namespace" -c "$container" --tail="$LOG_TAIL_LINES" \
                > "$pod_dir/init-${container}.log" 2>&1 || true
        done
        
        # Collect pod description
        kctl describe pod "$pod" -n "$namespace" > "$pod_dir/describe.txt" 2>&1 || true
    done
}

collect_crds_and_crs() {
    log_section "Collecting Custom Resource Definitions and Custom Resources"
    
    local crds_dir="$OUTPUT_DIR/crds"
    mkdir -p "$crds_dir"
    
    # Collect all CRDs
    log_info "Collecting all CRDs..."
    kctl get crds -o yaml > "$crds_dir/all-crds.yaml" 2>&1 || true
    kctl get crds -o wide > "$crds_dir/all-crds-list.txt" 2>&1 || true
    
    # Collect EGS-specific CRDs and their instances
    for api_group in "${EGS_API_GROUPS[@]}"; do
        log_info "Collecting CRDs from API group: $api_group"
        local group_dir="$crds_dir/$api_group"
        mkdir -p "$group_dir"
        
        # Get CRDs for this API group
        local crds=$(kctl get crds -o jsonpath="{.items[?(@.spec.group=='$api_group')].metadata.name}" 2>/dev/null)
        
        for crd in $crds; do
            log_debug "  CRD: $crd"
            local crd_name=$(echo "$crd" | cut -d'.' -f1)
            
            # Get CRD definition
            kctl get crd "$crd" -o yaml > "$group_dir/${crd_name}-crd.yaml" 2>&1 || true
            
            # Get all instances of this CRD across all namespaces
            kctl get "$crd_name" --all-namespaces -o yaml > "$group_dir/${crd_name}-instances.yaml" 2>&1 || true
            kctl get "$crd_name" --all-namespaces -o wide > "$group_dir/${crd_name}-list.txt" 2>&1 || true
        done
    done
    
    # Collect specific KubeSlice resources - COMPREHENSIVE LIST
    log_info "Collecting KubeSlice Controller resources..."
    
    # Controller resources (controller.kubeslice.io)
    local controller_resources=(
        "projects"
        "clusters"
        "sliceconfigs"
        "serviceexportconfigs"
        "sliceqosconfigs"
        "vpnkeyrotations"
        "slicenodeaffinities"
        "sliceresourcequotaconfigs"
        "slicerolebindings"
        "sliceroletemplates"
        "replicationjobconfigs"
        "replicationslice"
    )
    for resource in "${controller_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/controller-${resource}.yaml" 2>&1 || true
        kctl get "$resource" --all-namespaces -o wide > "$crds_dir/controller-${resource}-list.txt" 2>&1 || true
    done
    
    log_info "Collecting KubeSlice Worker resources..."
    
    # Worker resources (worker.kubeslice.io)
    local worker_resources=(
        "gpuworkloads"
        "workerserviceimports"
        "workersliceconfigs"
        "workerslicegateways"
        "workerslicegwrecyclers"
        "workerslicenodeaffinities"
        "workersliceresourcequotas"
        "workerslicerolebindings"
        "workersliceappserviceresourceusages"
        "workerslicegpuprovisioningrequests"
        "workerreplicationjobconfigs"
        "workerreplicationslice"
        "workloadplacements"
        "workerclustergpuallocations"
    )
    for resource in "${worker_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/worker-${resource}.yaml" 2>&1 || true
        kctl get "$resource" --all-namespaces -o wide > "$crds_dir/worker-${resource}-list.txt" 2>&1 || true
    done
    
    log_info "Collecting KubeSlice Networking resources..."
    
    # Networking resources (networking.kubeslice.io)
    local networking_resources=(
        "slices"
        "slicegateways"
        "serviceexports"
        "serviceimports"
        "slicenodeaffinities"
        "sliceresourcequotas"
        "slicerolebindings"
        "vpcserviceimports"
    )
    for resource in "${networking_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/networking-${resource}.yaml" 2>&1 || true
        kctl get "$resource" --all-namespaces -o wide > "$crds_dir/networking-${resource}-list.txt" 2>&1 || true
    done
    
    log_info "Collecting KubeSlice Inventory resources..."
    
    # Inventory resources (inventory.kubeslice.io)
    local inventory_resources=(
        "clustergpuallocations"
        "workerclustergpuallocations"
    )
    for resource in "${inventory_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/inventory-${resource}.yaml" 2>&1 || true
    done
    
    log_info "Collecting KubeSlice AI/Ops resources..."
    
    # AI/Ops resources (aiops.kubeslice.io)
    local aiops_resources=(
        "clustergpuallocations"
        "gpuprovisioningrequests"
        "workloadplacements"
    )
    for resource in "${aiops_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/aiops-${resource}.yaml" 2>&1 || true
    done
    
    log_info "Collecting GPR (GPU Provisioning Request) resources..."
    
    # GPR resources (gpr.kubeslice.io)
    local gpr_resources=(
        "gprautoevictions"
        "gprtemplatebindings"
        "gprtemplates"
        "gpuprovisioningrequests"
        "workloadplacements"
        "workloadtemplates"
        "workspacepolicies"
    )
    for resource in "${gpr_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/gpr-${resource}.yaml" 2>&1 || true
        kctl get "$resource" --all-namespaces -o wide > "$crds_dir/gpr-${resource}-list.txt" 2>&1 || true
    done
    
    # GPU/NVIDIA resources
    log_info "Collecting NVIDIA/GPU Operator resources..."
    local nvidia_resources=(
        "clusterpolicies"
        "nvidiadrivers"
    )
    for resource in "${nvidia_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/nvidia-${resource}.yaml" 2>&1 || true
        kctl get "$resource" --all-namespaces -o wide > "$crds_dir/nvidia-${resource}-list.txt" 2>&1 || true
    done
    
    # Node Feature Discovery resources
    log_info "Collecting Node Feature Discovery resources..."
    local nfd_resources=(
        "nodefeatures"
        "nodefeaturerules"
        "nodefeaturegroups"
    )
    for resource in "${nfd_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/nfd-${resource}.yaml" 2>&1 || true
    done
    
    # KServe resources (AI/ML Inference)
    log_info "Collecting KServe resources..."
    local kserve_resources=(
        "inferenceservices"
        "inferencegraphs"
        "servingruntimes"
        "clusterservingruntimes"
        "clusterlocalmodels"
        "localmodelnodegroups"
        "clusterstoragecontainers"
        "predictors"
        "trainedmodels"
    )
    for resource in "${kserve_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/kserve-${resource}.yaml" 2>&1 || true
        kctl get "$resource" --all-namespaces -o wide > "$crds_dir/kserve-${resource}-list.txt" 2>&1 || true
    done
    
    # Network Service Mesh resources
    log_info "Collecting Network Service Mesh resources..."
    local nsm_resources=(
        "networkservices"
        "networkserviceendpoints"
    )
    for resource in "${nsm_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/nsm-${resource}.yaml" 2>&1 || true
    done
    
    # Spire/SPIFFE resources
    log_info "Collecting Spire/SPIFFE resources..."
    local spire_resources=(
        "clusterspiffeids"
        "clusterfederatedtrustdomains"
    )
    for resource in "${spire_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/spire-${resource}.yaml" 2>&1 || true
    done
    
    # Gateway API resources
    log_info "Collecting Gateway API resources..."
    local gateway_resources=(
        "gateways"
        "gatewayclasses"
        "httproutes"
        "grpcroutes"
        "tcproutes"
        "tlsroutes"
        "udproutes"
        "referencegrants"
        "backendtlspolicies"
    )
    for resource in "${gateway_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/gateway-${resource}.yaml" 2>&1 || true
    done
    
    # Envoy Gateway resources
    log_info "Collecting Envoy Gateway resources..."
    local envoy_resources=(
        "envoyproxies"
        "securitypolicies"
        "clienttrafficpolicies"
        "backendtrafficpolicies"
        "envoypatchpolicies"
    )
    for resource in "${envoy_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/envoy-${resource}.yaml" 2>&1 || true
    done
    
    # Monitoring resources
    log_info "Collecting Prometheus/Monitoring resources..."
    local monitoring_resources=(
        "servicemonitors"
        "podmonitors"
        "prometheusrules"
        "alertmanagerconfigs"
        "alertmanagers"
        "prometheuses"
        "probes"
        "scrapeconfigs"
        "thanosrulers"
        "prometheusagents"
    )
    for resource in "${monitoring_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/monitoring-${resource}.yaml" 2>&1 || true
    done
    
    # Calico Network Policy resources (if using Calico)
    log_info "Collecting Calico Network Policy resources..."
    local calico_resources=(
        "networkpolicies.crd.projectcalico.org"
        "globalnetworkpolicies"
        "globalnetworksets"
        "networksets"
        "hostendpoints"
        "ippools"
        "bgpconfigurations"
        "bgppeers"
        "felixconfigurations"
    )
    for resource in "${calico_resources[@]}"; do
        log_debug "  Collecting $resource..."
        kctl get "$resource" --all-namespaces -o yaml > "$crds_dir/calico-$(echo $resource | cut -d'.' -f1).yaml" 2>&1 || true
    done
    
    log_info "✅ CRDs and Custom Resources collected"
}

collect_helm_info() {
    log_section "Collecting Helm Information"
    
    local helm_dir="$OUTPUT_DIR/helm"
    mkdir -p "$helm_dir"
    
    if ! command -v helm &>/dev/null; then
        log_warn "Helm not found, skipping Helm collection"
        echo "Helm not installed" > "$helm_dir/NOT_AVAILABLE.txt"
        return
    fi
    
    log_info "Collecting Helm releases across all namespaces..."
    helm list --all-namespaces --kubeconfig="$KUBECONFIG" > "$helm_dir/all-releases.txt" 2>&1 || true
    helm list --all-namespaces --kubeconfig="$KUBECONFIG" -o yaml > "$helm_dir/all-releases.yaml" 2>&1 || true
    
    # Collect detailed info for EGS-related releases
    log_info "Collecting detailed Helm release information..."
    
    local egs_releases=$(helm list --all-namespaces --kubeconfig="$KUBECONFIG" -o json 2>/dev/null | \
        jq -r '.[] | select(.name | test("egs|kubeslice|prometheus|grafana|gpu-operator|postgresql"; "i")) | "\(.namespace)/\(.name)"' 2>/dev/null || true)
    
    for release_info in $egs_releases; do
        local ns=$(echo "$release_info" | cut -d'/' -f1)
        local release=$(echo "$release_info" | cut -d'/' -f2)
        local release_dir="$helm_dir/releases/$ns-$release"
        mkdir -p "$release_dir"
        
        log_debug "  Collecting info for release: $release in namespace $ns"
        helm get all "$release" -n "$ns" --kubeconfig="$KUBECONFIG" > "$release_dir/all.txt" 2>&1 || true
        helm get values "$release" -n "$ns" --kubeconfig="$KUBECONFIG" -o yaml > "$release_dir/values.yaml" 2>&1 || true
        helm get manifest "$release" -n "$ns" --kubeconfig="$KUBECONFIG" > "$release_dir/manifest.yaml" 2>&1 || true
        helm history "$release" -n "$ns" --kubeconfig="$KUBECONFIG" > "$release_dir/history.txt" 2>&1 || true
    done
    
    log_info "✅ Helm information collected"
}

collect_metrics() {
    log_section "Collecting Metrics Information"
    
    if [ "$SKIP_METRICS" = true ]; then
        log_info "Skipping metrics collection (--skip-metrics)"
        return
    fi
    
    local metrics_dir="$OUTPUT_DIR/metrics"
    mkdir -p "$metrics_dir"
    
    # Collect node metrics
    log_info "Collecting node metrics..."
    kctl top nodes > "$metrics_dir/node-metrics.txt" 2>&1 || true
    
    # Collect pod metrics for EGS namespaces
    log_info "Collecting pod metrics..."
    for ns in "${EGS_NAMESPACES[@]}"; do
        kctl top pods -n "$ns" > "$metrics_dir/pod-metrics-$ns.txt" 2>&1 || true
    done
    
    # Try to get Prometheus targets if Prometheus is accessible
    log_info "Attempting to collect Prometheus targets..."
    local prom_svc=$(kctl get svc -n egs-monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$prom_svc" ]; then
        kctl exec -n egs-monitoring svc/"$prom_svc" -- wget -q -O- http://localhost:9090/api/v1/targets 2>/dev/null \
            > "$metrics_dir/prometheus-targets.json" 2>&1 || true
    fi
    
    log_info "✅ Metrics information collected"
}

collect_network_info() {
    log_section "Collecting Network Information"
    
    local network_dir="$OUTPUT_DIR/network"
    mkdir -p "$network_dir"
    
    log_info "Collecting services across all namespaces..."
    kctl get svc --all-namespaces -o wide > "$network_dir/all-services.txt" 2>&1 || true
    
    log_info "Collecting endpoints across all namespaces..."
    kctl get endpoints --all-namespaces -o wide > "$network_dir/all-endpoints.txt" 2>&1 || true
    
    log_info "Collecting ingresses..."
    kctl get ingress --all-namespaces -o yaml > "$network_dir/all-ingresses.yaml" 2>&1 || true
    
    log_info "Collecting network policies..."
    kctl get networkpolicies --all-namespaces -o yaml > "$network_dir/network-policies.yaml" 2>&1 || true
    
    # Collect LoadBalancer services details
    log_info "Collecting LoadBalancer service details..."
    kctl get svc --all-namespaces -o json 2>/dev/null | \
        jq '.items[] | select(.spec.type=="LoadBalancer") | {namespace: .metadata.namespace, name: .metadata.name, type: .spec.type, clusterIP: .spec.clusterIP, externalIP: .status.loadBalancer.ingress, ports: .spec.ports}' \
        > "$network_dir/loadbalancer-services.json" 2>&1 || true
    
    # Collect NodePort services details
    log_info "Collecting NodePort service details..."
    kctl get svc --all-namespaces -o json 2>/dev/null | \
        jq '.items[] | select(.spec.type=="NodePort") | {namespace: .metadata.namespace, name: .metadata.name, type: .spec.type, clusterIP: .spec.clusterIP, ports: .spec.ports}' \
        > "$network_dir/nodeport-services.json" 2>&1 || true
    
    log_info "✅ Network information collected"
}

collect_storage_info() {
    log_section "Collecting Storage Information"
    
    local storage_dir="$OUTPUT_DIR/storage"
    mkdir -p "$storage_dir"
    
    log_info "Collecting storage classes..."
    kctl get storageclasses -o yaml > "$storage_dir/storage-classes.yaml" 2>&1 || true
    
    log_info "Collecting persistent volumes..."
    kctl get pv -o yaml > "$storage_dir/persistent-volumes.yaml" 2>&1 || true
    kctl get pv -o wide > "$storage_dir/persistent-volumes-list.txt" 2>&1 || true
    
    log_info "Collecting persistent volume claims..."
    kctl get pvc --all-namespaces -o yaml > "$storage_dir/persistent-volume-claims.yaml" 2>&1 || true
    kctl get pvc --all-namespaces -o wide > "$storage_dir/persistent-volume-claims-list.txt" 2>&1 || true
    
    log_info "✅ Storage information collected"
}

generate_summary() {
    log_section "Generating Summary Report"
    
    local summary_file="$OUTPUT_DIR/SUMMARY.md"
    local cluster_name_val=$(get_cluster_name)
    
    cat > "$summary_file" << EOF
# EGS Troubleshooting Bundle Summary

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Script Version:** $SCRIPT_VERSION
**Cluster Name:** $cluster_name_val
**Cluster Type:** $CLUSTER_TYPE
**Kubeconfig:** $KUBECONFIG
**Context:** ${KUBECONTEXT:-$(kctl config current-context 2>/dev/null || echo 'default')}

## Cluster Information

\`\`\`
$(kctl version --short 2>/dev/null || echo 'Unable to get cluster version')
\`\`\`

## Node Summary

| Nodes | Ready | Not Ready | GPU Nodes |
|-------|-------|-----------|-----------|
| $(kctl get nodes --no-headers 2>/dev/null | wc -l) | $(kctl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo 0) | $(kctl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || echo 0) | $(kctl get nodes -o json 2>/dev/null | jq '[.items[] | select(.status.capacity["nvidia.com/gpu"] != null)] | length' 2>/dev/null || echo 0) |

## EGS Components Status

### Namespaces
$(for ns in "${EGS_NAMESPACES[@]}"; do
    if kctl get namespace "$ns" &>/dev/null; then
        echo "- ✅ $ns"
    else
        echo "- ❌ $ns (not found)"
    fi
done)

### Controller Pods
\`\`\`
$(kctl get pods -n kubeslice-controller -o wide 2>/dev/null || echo 'Namespace not found')
\`\`\`

### Worker Pods
\`\`\`
$(kctl get pods -n kubeslice-system -o wide 2>/dev/null || echo 'Namespace not found')
\`\`\`

### Monitoring Pods
\`\`\`
$(kctl get pods -n egs-monitoring -o wide 2>/dev/null || echo 'Namespace not found')
\`\`\`

### GPU Operator Pods
\`\`\`
$(kctl get pods -n egs-gpu-operator -o wide 2>/dev/null || echo 'Namespace not found')
\`\`\`

## Helm Releases

\`\`\`
$(helm list --all-namespaces --kubeconfig="$KUBECONFIG" 2>/dev/null || echo 'Unable to list Helm releases')
\`\`\`

## Recent Events (Last 10)

\`\`\`
$(kctl get events --all-namespaces --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo 'Unable to get events')
\`\`\`

## Bundle Contents

$(find "$OUTPUT_DIR" -type f | wc -l) files collected

### Directory Structure
\`\`\`
$(find "$OUTPUT_DIR" -type d | head -30)
\`\`\`

---
*This bundle was generated by egs-troubleshoot.sh v$SCRIPT_VERSION*
EOF

    log_info "✅ Summary report generated: $summary_file"
}

create_bundle_archive() {
    # Note: All log messages go to stderr so only the path is captured by $()
    log_section "Creating Bundle Archive" >&2
    
    local bundle_name="${BUNDLE_PREFIX}-$(date +%Y%m%d-%H%M%S)"
    local archive_path="$(dirname "$OUTPUT_DIR")/${bundle_name}.tar.gz"
    
    log_info "Creating archive: $archive_path" >&2
    
    # Create tarball
    tar -czf "$archive_path" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")" 2>&1
    
    if [ -f "$archive_path" ]; then
        local size=$(du -h "$archive_path" | cut -f1)
        log_info "✅ Bundle archive created: $archive_path ($size)" >&2
        echo "$archive_path"
    else
        log_error "Failed to create archive" >&2
        return 1
    fi
}

upload_to_s3() {
    local archive_path="$1"
    
    if [ -z "$S3_BUCKET" ]; then
        return 0
    fi
    
    log_section "Uploading Bundle to S3"
    
    local s3_key="${S3_PREFIX}$(basename "$archive_path")"
    local s3_uri="s3://${S3_BUCKET}/${s3_key}"
    
    log_info "Uploading to: $s3_uri"
    
    local aws_cmd="aws s3 cp"
    if [ -n "$AWS_PROFILE" ]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    aws_cmd="$aws_cmd --region $S3_REGION"
    
    if $aws_cmd "$archive_path" "$s3_uri"; then
        log_info "✅ Bundle uploaded successfully to: $s3_uri"
        
        # Generate presigned URL (valid for 7 days)
        local presign_cmd="aws s3 presign $s3_uri --expires-in 604800"
        if [ -n "$AWS_PROFILE" ]; then
            presign_cmd="$presign_cmd --profile $AWS_PROFILE"
        fi
        presign_cmd="$presign_cmd --region $S3_REGION"
        
        local presigned_url=$($presign_cmd 2>/dev/null || true)
        if [ -n "$presigned_url" ]; then
            log_info "📎 Presigned URL (valid for 7 days):"
            echo "   $presigned_url"
        fi
    else
        log_error "Failed to upload bundle to S3"
        return 1
    fi
}

#===============================================================================
# Main Functions
#===============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -k|--kubeconfig)
                KUBECONFIG="$2"
                shift 2
                ;;
            -c|--context)
                KUBECONTEXT="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--namespace)
                EGS_NAMESPACES+=("$2")
                shift 2
                ;;
            --all-namespaces)
                COLLECT_ALL_NAMESPACES=true
                shift
                ;;
            --include-secrets)
                INCLUDE_SECRETS=true
                shift
                ;;
            --log-lines)
                LOG_TAIL_LINES="$2"
                shift 2
                ;;
            --skip-logs)
                SKIP_LOGS=true
                shift
                ;;
            --skip-metrics)
                SKIP_METRICS=true
                shift
                ;;
            --no-previous-logs)
                INCLUDE_PREVIOUS_LOGS=false
                shift
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --s3-region)
                S3_REGION="$2"
                shift 2
                ;;
            --s3-prefix)
                S3_PREFIX="$2"
                shift 2
                ;;
            --aws-profile)
                AWS_PROFILE="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --add-kubeconfig)
                ADDITIONAL_KUBECONFIGS+=("$2")
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

main() {
    print_banner
    
    # Set default output directory if not specified
    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="./egs-troubleshoot-bundle-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    log_info "Bundle output directory: $OUTPUT_DIR"
    
    # Run prerequisite checks
    check_prerequisites
    
    # Detect cluster type
    detect_cluster_type
    
    # Get cluster name for identification
    local cluster_name=$(get_cluster_name)
    log_info "Cluster name: $cluster_name"
    
    # Collect cluster-wide information
    collect_cluster_info
    collect_node_info
    collect_crds_and_crs
    collect_helm_info
    collect_network_info
    collect_storage_info
    collect_metrics
    
    # Discover EGS-related namespaces
    discover_egs_namespaces
    
    # Collect namespace-specific resources
    log_section "Collecting Namespace Resources"
    
    # If collecting from all namespaces, get the list
    if [ "$COLLECT_ALL_NAMESPACES" = true ]; then
        log_info "Collecting from ALL namespaces..."
        local all_ns=$(kctl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        for ns in $all_ns; do
            collect_namespace_resources "$ns"
            collect_pod_logs "$ns"
        done
    else
        # Combine all discovered namespaces
        local all_namespaces=(
            "${EGS_CORE_NAMESPACES[@]}"
            "${EGS_PROJECT_NAMESPACES[@]}"
            "${SLICE_APP_NAMESPACES[@]}"
            "${ADDITIONAL_NAMESPACES[@]}"
        )
        # Remove duplicates and empty entries
        local unique_namespaces=($(echo "${all_namespaces[@]}" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' '))
        
        log_info "Will collect from ${#unique_namespaces[@]} namespaces"
        
        for ns in "${unique_namespaces[@]}"; do
            collect_namespace_resources "$ns"
            collect_pod_logs "$ns"
        done
    fi
    
    # Generate summary
    generate_summary
    
    # Create archive
    local archive_path=$(create_bundle_archive)
    
    # Upload to S3 if configured
    if [ -n "$S3_BUCKET" ]; then
        upload_to_s3 "$archive_path"
    fi
    
    # Print completion message
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│                     ✅ TROUBLESHOOTING BUNDLE COMPLETE                              │"
    echo "├─────────────────────────────────────────────────────────────────────────────────────┤"
    echo "│  📁 Bundle Directory: $OUTPUT_DIR"
    echo "│  📦 Archive: $archive_path"
    if [ -n "$S3_BUCKET" ]; then
        echo "│  ☁️  Uploaded to: s3://${S3_BUCKET}/${S3_PREFIX}$(basename "$archive_path")"
    fi
    echo "│  📋 Summary: $OUTPUT_DIR/SUMMARY.md"
    echo "└─────────────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    log_info "Please share the generated bundle with support for analysis."
}

# Parse command line arguments
parse_arguments "$@"

# Run main function
main



