#!/bin/bash

# EGS Quick Installer
# One-command installation for EGS (supports both single-cluster and multi-cluster modes)
# Usage: 
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --license-file egs-license.yaml
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --skip-postgresql --skip-gpu-operator
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --controller-kubeconfig /path/to/controller-kubeconfig.yaml --worker-kubeconfig /path/to/worker-kubeconfig.yaml

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
KUBECONFIG_PATH=""
KUBE_CONTEXT=""
PROJECT_NAME="avesha"
CLUSTER_NAME="worker-1"
IMAGE_REGISTRY="harbor.saas1.smart-scaler.io/avesha/aveshasystems"
LICENSE_FILE=""  # Defaults to egs-license.yaml in current directory

# Skip flags for EGS components (works for both single & multi-cluster)
SKIP_CONTROLLER="false"
SKIP_UI="false"
SKIP_WORKER="false"

# Skip flag for PostgreSQL (works for both single & multi-cluster - PostgreSQL is only on controller)
SKIP_POSTGRESQL="false"

# Skip flags for single-cluster mode ONLY (Prometheus & GPU Operator on the single cluster)
SKIP_PROMETHEUS="false"
SKIP_GPU_OPERATOR="false"

# Skip flags for multi-cluster mode (controller cluster prerequisites)
SKIP_CONTROLLER_PROMETHEUS="false"
SKIP_CONTROLLER_GPU_OPERATOR="false"

# Skip flags for multi-cluster mode (worker cluster prerequisites)
SKIP_WORKER_PROMETHEUS="false"
SKIP_WORKER_GPU_OPERATOR="false"

# Worker registration mode
REGISTER_WORKER="false"
CONTROLLER_KUBECONFIG=""
CONTROLLER_CONTEXT=""
# Multiple workers support (arrays)
WORKER_KUBECONFIGS=()
WORKER_CONTEXTS=()
WORKER_NAMES=()
# Legacy single worker support (for backward compatibility)
WORKER_KUBECONFIG=""
WORKER_CONTEXT=""
# Note: Multi-cluster mode is auto-detected when both CONTROLLER_KUBECONFIG and at least one WORKER_KUBECONFIG are provided
# Note: UI always uses the same kubeconfig/context as Controller (they're deployed together)
# Note: You can specify multiple workers using multiple --worker-kubeconfig flags
REGISTER_CLUSTER_NAME=""
REGISTER_PROJECT_NAME=""
TELEMETRY_ENABLED="true"
TELEMETRY_ENDPOINT=""
TELEMETRY_PROVIDER="prometheus"
CLOUD_PROVIDER=""
CLOUD_REGION=""
CONTROLLER_NAMESPACE="kubeslice-controller"

# Project name for full installs (used in cluster_registration). Overridable via --project-name.
PROJECT_NAME="avesha"

# Worker endpoint overrides (array, matches order of --worker-kubeconfig)
WORKER_ENDPOINTS=()

# Behavior flags
GENERATE_CONFIG_ONLY="false"   # --generate-config / --dry-run: build config then exit (no install)
PRESERVE_CONFIG="false"        # --preserve-config: reuse an existing egs-installer-config.yaml as-is
SKIP_DEPENDENCY_CHECK="false"  # --skip-dependency-check: bypass helm-based prerequisite detection
LOCAL_REPO=""                  # --local-repo PATH: use a local installer checkout instead of git clone

# GitHub repository details
EGS_REPO="https://github.com/kubeslice-ent/egs-installation.git"
EGS_BRANCH="main"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# ---------------------------------------------------------------------------
# Cleanup handling
# ---------------------------------------------------------------------------
# Track temporary paths so they are always removed, even on Ctrl-C / error.
CLEANUP_PATHS=()
INSTALL_COMPLETE="false"

register_cleanup_path() {
    [ -n "$1" ] && CLEANUP_PATHS+=("$1")
}

cleanup() {
    local exit_code=$?
    # Restore the user's original kubectl context if we changed it (single-cluster mode)
    if [ -n "${ORIGINAL_KUBE_CONTEXT:-}" ] && [ -n "${SWITCHED_CONTEXT:-}" ]; then
        kubectl config use-context "$ORIGINAL_KUBE_CONTEXT" >/dev/null 2>&1 || true
    fi
    # Remove tracked temporary files/directories
    for _p in "${CLEANUP_PATHS[@]}"; do
        [ -n "$_p" ] && rm -rf "$_p" 2>/dev/null || true
    done
    if [ "$exit_code" -ne 0 ] && [ "$INSTALL_COMPLETE" != "true" ]; then
        echo ""
        print_warning "Installer exited early (code $exit_code). Temporary files were cleaned up."
        print_info "Re-run the installer to retry; your cluster state was not rolled back."
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Back up an existing egs-installer-config.yaml before it gets overwritten/regenerated,
# so a customer's local customizations are never silently destroyed on a re-run.
backup_existing_config() {
    if [ -f "$ORIGINAL_DIR/egs-installer-config.yaml" ]; then
        local ts backup
        ts=$(date +%Y%m%d-%H%M%S)
        backup="$ORIGINAL_DIR/egs-installer-config.yaml.bak.$ts"
        if cp "$ORIGINAL_DIR/egs-installer-config.yaml" "$backup" 2>/dev/null; then
            print_warning "Existing egs-installer-config.yaml backed up to: $(basename "$backup")"
        fi
    fi
}

# Overwrite the working-directory config from the repo template, backing up any existing one first.
install_repo_config() {
    backup_existing_config
    cp "$REPO_SRC/egs-installer-config.yaml" "$ORIGINAL_DIR/egs-installer-config.yaml"
}

# Detect whether a component is already present in the cluster.
# Checks BOTH helm releases AND deployment/statefulset names by case-insensitive keyword,
# so a non-standard helm release name (e.g. "my-postgres") doesn't cause a false negative
# that blocks the install. Returns 0 if found, 1 otherwise.
component_present() {
    local pattern="$1"
    local hargs=() kargs=()
    if [ -n "${KUBECONFIG:-}" ]; then hargs+=(--kubeconfig "$KUBECONFIG"); kargs+=(--kubeconfig "$KUBECONFIG"); fi
    if [ -n "${CURRENT_CONTEXT:-}" ] && [ "${CURRENT_CONTEXT:-}" != "multi-cluster" ]; then
        hargs+=(--kube-context "$CURRENT_CONTEXT"); kargs+=(--context "$CURRENT_CONTEXT")
    fi
    if command -v helm >/dev/null 2>&1 && helm list -A "${hargs[@]}" 2>/dev/null | grep -qiE "$pattern"; then
        return 0
    fi
    if kubectl "${kargs[@]}" get deploy,statefulset -A -o name 2>/dev/null | grep -qiE "$pattern"; then
        return 0
    fi
    return 1
}

# Function to register worker cluster with controller
register_worker_cluster() {
    print_info "Registering worker cluster with controller..."

    # Validate required parameters
    if [ -z "$CONTROLLER_KUBECONFIG" ]; then
        print_error "❌ ERROR: --controller-kubeconfig is required for --register-worker"
        exit 1
    fi

    if [ ! -f "$CONTROLLER_KUBECONFIG" ]; then
        print_error "❌ ERROR: Controller kubeconfig file not found: $CONTROLLER_KUBECONFIG"
        exit 1
    fi

    if [ -z "$REGISTER_CLUSTER_NAME" ]; then
        print_error "❌ ERROR: --register-cluster-name is required for --register-worker"
        exit 1
    fi

    # Set default project name if not provided
    if [ -z "$REGISTER_PROJECT_NAME" ]; then
        REGISTER_PROJECT_NAME="avesha"
        print_info "Using default project name: $REGISTER_PROJECT_NAME"
    fi

    # Validate controller cluster connectivity
    print_info "Validating controller cluster connectivity..."
    CONTROLLER_CMD="kubectl --kubeconfig $CONTROLLER_KUBECONFIG"
    if [ -n "$CONTROLLER_CONTEXT" ]; then
        CONTROLLER_CMD="$CONTROLLER_CMD --context $CONTROLLER_CONTEXT"
    fi

    if ! $CONTROLLER_CMD cluster-info &>/dev/null; then
        print_error "❌ ERROR: Cannot connect to controller cluster"
        print_error "Please verify the controller kubeconfig and context"
        exit 1
    fi

    print_success "Controller cluster connectivity verified"

    # Validate worker cluster if kubeconfig provided and detect cloud provider
    if [ -n "$WORKER_KUBECONFIG" ]; then
        print_info "Validating worker cluster connectivity..."
        WORKER_CMD="kubectl --kubeconfig $WORKER_KUBECONFIG"
        if [ -n "$WORKER_CONTEXT" ]; then
            WORKER_CMD="$WORKER_CMD --context $WORKER_CONTEXT"
        fi

        if ! $WORKER_CMD cluster-info &>/dev/null; then
            print_warning "⚠️  Cannot connect to worker cluster (non-fatal, continuing...)"
        else
            print_success "Worker cluster connectivity verified"

            # Detect cloud provider from worker cluster
            WORKER_CLOUD_PROVIDER=$($WORKER_CMD get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | cut -d: -f1 || echo "")
            if [ "$WORKER_CLOUD_PROVIDER" = "linode" ]; then
                CLOUD_PROVIDER=""  # Keep empty for Linode
                CLOUD_REGION=""    # Keep empty for Linode
                print_info "Detected Linode cluster - cloud provider and region will be left empty"
            elif [ -n "$WORKER_CLOUD_PROVIDER" ] && [ -z "$CLOUD_PROVIDER" ]; then
                print_info "Detected cloud provider: $WORKER_CLOUD_PROVIDER (not setting automatically - use --cloud-provider if needed)"
            fi
        fi
    fi

    # Check if project namespace exists
    PROJECT_NAMESPACE="kubeslice-$REGISTER_PROJECT_NAME"
    print_info "Checking if project namespace exists: $PROJECT_NAMESPACE"

    if ! $CONTROLLER_CMD get namespace "$PROJECT_NAMESPACE" &>/dev/null; then
        print_error "❌ ERROR: Project namespace '$PROJECT_NAMESPACE' does not exist in controller cluster"
        print_error "Please create the project first or use an existing project name"
        exit 1
    fi

    print_success "Project namespace found: $PROJECT_NAMESPACE"

    # Set default telemetry endpoint if not provided
    if [ -z "$TELEMETRY_ENDPOINT" ]; then
        TELEMETRY_ENDPOINT="http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
        print_info "Using default telemetry endpoint: $TELEMETRY_ENDPOINT"
    fi


    # Create temporary directory for cluster YAML
    TEMP_DIR=$(mktemp -d)
    CLUSTER_YAML="$TEMP_DIR/${REGISTER_CLUSTER_NAME}_cluster.yaml"

    # Generate Cluster CRD YAML
    print_info "Generating Cluster CRD for: $REGISTER_CLUSTER_NAME"
    cat <<EOF > "$CLUSTER_YAML"
apiVersion: controller.kubeslice.io/v1alpha1
kind: Cluster
metadata:
  name: $REGISTER_CLUSTER_NAME
  namespace: $PROJECT_NAMESPACE
spec:
  clusterProperty:
    telemetry:
      enabled: $TELEMETRY_ENABLED
      endpoint: $TELEMETRY_ENDPOINT
      telemetryProvider: $TELEMETRY_PROVIDER
    geoLocation:
      cloudProvider: "$CLOUD_PROVIDER"
      cloudRegion: "$CLOUD_REGION"
EOF

    # Apply Cluster CRD to controller
    print_info "Registering cluster '$REGISTER_CLUSTER_NAME' in project '$REGISTER_PROJECT_NAME'..."
    if $CONTROLLER_CMD apply -f "$CLUSTER_YAML" -n "$PROJECT_NAMESPACE"; then
        print_success "Cluster CRD applied successfully"
    else
        print_error "❌ ERROR: Failed to apply Cluster CRD"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Verify cluster registration
    print_info "Verifying cluster registration..."
    sleep 2
    if $CONTROLLER_CMD get cluster.controller.kubeslice.io "$REGISTER_CLUSTER_NAME" -n "$PROJECT_NAMESPACE" &>/dev/null; then
        print_success "✅ Cluster '$REGISTER_CLUSTER_NAME' registered successfully in project '$REGISTER_PROJECT_NAME'"
        echo ""
        print_info "Cluster details:"
        $CONTROLLER_CMD get cluster.controller.kubeslice.io "$REGISTER_CLUSTER_NAME" -n "$PROJECT_NAMESPACE" -o wide
        echo ""
    else
        print_warning "⚠️  Cluster CRD applied but verification failed. Please check manually."
    fi

    # Cleanup
    rm -rf "$TEMP_DIR"

    print_success "✅ Worker cluster registration complete!"
    echo ""
    
    # Automatically set skip flags for all components when in register-worker mode
    # This ensures --register-worker is a standalone functionality
    SKIP_POSTGRESQL="true"
    SKIP_PROMETHEUS="true"
    SKIP_GPU_OPERATOR="true"
    SKIP_CONTROLLER="true"
    SKIP_UI="true"
    
    # If worker kubeconfig is provided, proceed with worker installation
    if [ -n "$WORKER_KUBECONFIG" ]; then
        print_info "Worker kubeconfig provided - proceeding with worker installation..."
        print_info "Setting up for worker installation..."
        
        # Only set SKIP_WORKER="false" if it hasn't been explicitly set to true via --skip-worker flag
        # This respects the user's --skip-worker flag if provided
        if [ "$SKIP_WORKER" != "true" ]; then
            SKIP_WORKER="false"
        else
            print_info "Worker installation will be skipped (--skip-worker flag provided)"
        fi
        
        # Set cluster name to registered cluster name
        CLUSTER_NAME="$REGISTER_CLUSTER_NAME"
        
        # Set multi-cluster mode
        MULTI_CLUSTER="true"
        
        # Add worker to arrays for config generation
        WORKER_KUBECONFIGS=("$WORKER_KUBECONFIG")
        if [ -n "$WORKER_CONTEXT" ]; then
            WORKER_CONTEXTS=("$WORKER_CONTEXT")
        else
            WORKER_CONTEXTS=()
        fi
        WORKER_NAMES=("$REGISTER_CLUSTER_NAME")
        
        print_success "Configuration prepared for worker installation"
        print_info "Worker will be installed on: $REGISTER_CLUSTER_NAME"
        print_info "All other components (Controller, UI, Prerequisites) will be automatically skipped"
        echo ""
        # Continue with normal installation flow (will skip to worker installation)
    else
        # No worker kubeconfig - just registration, exit after this
        SKIP_WORKER="true"
        print_info "✅ Registration complete! Worker cluster '$REGISTER_CLUSTER_NAME' is now registered."
        echo ""
        print_info "Next steps:"
        print_info "1. To install EGS Worker on this cluster, run:"
        cat <<EOF
   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
     --register-worker \\
     --controller-kubeconfig <controller-kubeconfig> \\
     --worker-kubeconfig <worker-kubeconfig> \\
     --register-cluster-name $REGISTER_CLUSTER_NAME \\
     --register-project-name $REGISTER_PROJECT_NAME
EOF
        echo ""
        print_info "   Note: All components (Controller, UI, Prerequisites) are automatically skipped when using --register-worker"
        print_info "2. Verify cluster status in the controller:"
        print_info "   kubectl --kubeconfig $CONTROLLER_KUBECONFIG get cluster.controller.kubeslice.io -n $PROJECT_NAMESPACE"
        echo ""
        # Exit if no worker kubeconfig provided
        INSTALL_COMPLETE="true"
        exit 0
    fi
}

# Function to show help
show_help() {
    cat << EOF
EGS Quick Installer

One-command installation for EGS (Enterprise GPU Scheduler)

Usage:
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash [OPTIONS]

Options:
  --license-file PATH        Path to EGS license file (default: egs-license.yaml in current directory)
  --kubeconfig PATH          Path to kubeconfig file (default: auto-detect, used for single-cluster mode)
  --context NAME             Kubernetes context to use (default: current-context, used for single-cluster mode)
  --cluster-name NAME        Cluster name (default: worker-1)
  --project-name NAME        Project name for cluster registration on full installs (default: avesha)
  --help, -h                 Show this help message

Behavior Flags:
  --generate-config          Generate egs-installer-config.yaml and exit (no install). Alias: --dry-run
  --dry-run                  Same as --generate-config
  --preserve-config          Reuse an existing egs-installer-config.yaml as-is (do not regenerate/overwrite)
  --skip-dependency-check    Bypass helm-based prerequisite detection (PostgreSQL/Controller/UI checks)
  --local-repo PATH          Use a local egs-installation checkout instead of cloning from GitHub

Common Skip Flags (works for both single & multi-cluster):
  --skip-postgresql          Skip PostgreSQL installation (controller only - PostgreSQL is never on workers)
  --skip-controller          Skip EGS Controller installation
  --skip-ui                  Skip EGS UI installation
  --skip-worker              Skip EGS Worker installation

Single-Cluster Mode Skip Flags (use these when installing on ONE cluster):
  --skip-prometheus          Skip Prometheus installation
  --skip-gpu-operator        Skip GPU Operator installation

Multi-Cluster Mode Skip Flags (use these when installing on MULTIPLE clusters):
  Controller Cluster:
    --skip-controller-prometheus    Skip Prometheus on controller cluster
    --skip-controller-gpu-operator  Skip GPU Operator on controller cluster
  
  Worker Cluster(s):
    --skip-worker-prometheus        Skip Prometheus on worker cluster(s)
    --skip-worker-gpu-operator      Skip GPU Operator on worker cluster(s)
  
  Note: In multi-cluster mode, use --skip-controller-* and --skip-worker-* flags
        instead of --skip-prometheus and --skip-gpu-operator

Multi-Cluster Mode (Auto-detected):
  --controller-kubeconfig PATH  Path to controller cluster kubeconfig (auto-detects multi-cluster when used with --worker-kubeconfig)
  --controller-context NAME     Controller cluster context (optional)
  --worker-kubeconfig PATH      Path to worker cluster kubeconfig (can be specified multiple times for multiple workers)
  --worker-context NAME         Worker cluster context (optional, can be specified multiple times, matches order of --worker-kubeconfig)
  --worker-name NAME            Worker cluster name (optional, can be specified multiple times, defaults to worker-1, worker-2, etc.)
  
  Note: Multi-cluster mode is automatically enabled when both --controller-kubeconfig and at least one --worker-kubeconfig are provided
  Note: UI always uses the same kubeconfig/context as Controller (they're deployed together)
  Note: You can add multiple workers by specifying --worker-kubeconfig multiple times

Advanced Override Options:
  --controller-endpoint URL  Override the auto-detected controller cluster API endpoint (useful for Rancher or custom API server URLs)
  --worker-endpoint URL      Override the auto-detected worker cluster API endpoint (can be specified multiple times, matches order of --worker-kubeconfig)
  --ui-service-type TYPE     Set UI proxy service type: LoadBalancer, NodePort, or ClusterIP (default: LoadBalancer)

Worker Registration Mode:
  --register-worker          Register a worker cluster with controller (standalone mode)
  --controller-kubeconfig PATH  Path to controller cluster kubeconfig (required for --register-worker)
  --controller-context NAME     Controller cluster context (optional)
  --worker-kubeconfig PATH      Path to worker cluster kubeconfig (optional, for validation)
  --worker-context NAME         Worker cluster context (optional)
  --register-cluster-name NAME  Cluster name to register (required for --register-worker)
  --register-project-name NAME  Project name (required for --register-worker, default: avesha)
  --telemetry-endpoint URL      Prometheus endpoint URL (optional)
  --telemetry-provider NAME     Telemetry provider (default: prometheus)
  --cloud-provider NAME         Cloud provider name (optional)
  --cloud-region NAME           Cloud region (optional)
  --controller-namespace NAME   Controller namespace (default: kubeslice-controller)

Examples:
  # Simplest - Install EGS with license file in current directory
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash

  # Specify license file path
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --license-file /path/to/egs-license.yaml

  # Skip specific components
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --skip-postgresql --skip-gpu-operator

  # Install only Controller and UI (skip prerequisites and worker)
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-worker

  # Register a worker cluster with controller
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --register-worker \\
    --controller-kubeconfig /path/to/controller-kubeconfig.yaml \\
    --register-cluster-name worker-2 \\
    --register-project-name avesha \\
    --telemetry-endpoint http://prometheus.example.com:9090 \\
    --cloud-provider GCP \\
    --cloud-region us-west1

  # Multi-cluster installation (Controller/UI in one cluster, Worker in another)
  # Multi-cluster mode is auto-detected when both --controller-kubeconfig and --worker-kubeconfig are provided
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --controller-kubeconfig /path/to/controller-kubeconfig.yaml \\
    --controller-context controller-context \\
    --worker-kubeconfig /path/to/worker-kubeconfig.yaml \\
    --worker-context worker-context \\
    --skip-postgresql \\
    --skip-controller-prometheus --skip-controller-gpu-operator \\
    --skip-worker-prometheus --skip-worker-gpu-operator
  
  # Multi-cluster with multiple workers
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --controller-kubeconfig /path/to/controller-kubeconfig.yaml \\
    --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \\
    --worker-context worker1-context \\
    --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \\
    --worker-context worker2-context \\
    --skip-postgresql \\
    --skip-controller-prometheus --skip-controller-gpu-operator \\
    --skip-worker-prometheus --skip-worker-gpu-operator

Notes:
  - License file defaults to 'egs-license.yaml' in current directory if not specified
  - All components are installed by default unless explicitly skipped
  - Installation order: License → Prerequisites → Controller → UI → Worker
  - Takes 10-15 minutes for complete installation
  - Single-cluster mode (default): All components installed in the same cluster with strict dependency checks
  - Multi-cluster mode (auto-detected): Automatically enabled when both --controller-kubeconfig and --worker-kubeconfig are provided. Allows Controller, UI, and Worker in different clusters, relaxes dependency checks
  - Use --register-worker to register a worker cluster with an existing controller (standalone mode)
  - When using --register-worker, controller kubeconfig and cluster name are required

EOF
    exit 0
}

# Function to show license generation steps
show_license_steps() {
    cat << EOF

📋 To generate your EGS license file, follow these steps:

1. Navigate to the EGS Registration page:
   https://avesha.io/egs-registration

2. Complete the registration form with:
   - Your full name
   - Company name
   - Title/Position/Role
   - Work email
   - Cluster fingerprint (see step 3)

3. Generate your cluster fingerprint:
   kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'

4. After registration, you will receive the license file via email

5. Save the license file as 'egs-license.yaml' in your current directory:
   # Copy the license content to egs-license.yaml
   # Or download the file and place it in the current directory

6. Run the installer again:
   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash

For detailed instructions, see: https://docs.avesha.io/documentation/enterprise-egs

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        --context)
            KUBE_CONTEXT="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --license-file)
            LICENSE_FILE="$2"
            shift 2
            ;;
        --image-registry)
            IMAGE_REGISTRY="$2"
            shift 2
            ;;
        --skip-postgresql)
            SKIP_POSTGRESQL="true"
            shift
            ;;
        --skip-prometheus)
            SKIP_PROMETHEUS="true"
            shift
            ;;
        --skip-gpu-operator)
            SKIP_GPU_OPERATOR="true"
            shift
            ;;
        --skip-controller)
            SKIP_CONTROLLER="true"
            shift
            ;;
        --skip-ui)
            SKIP_UI="true"
            shift
            ;;
        --skip-worker)
            SKIP_WORKER="true"
            shift
            ;;
        # Multi-cluster specific skip flags (controller cluster)
        # Note: No --skip-controller-postgresql - use --skip-postgresql (PostgreSQL is only on controller)
        --skip-controller-prometheus)
            SKIP_CONTROLLER_PROMETHEUS="true"
            shift
            ;;
        --skip-controller-gpu-operator)
            SKIP_CONTROLLER_GPU_OPERATOR="true"
            shift
            ;;
        # Multi-cluster specific skip flags (worker clusters)
        --skip-worker-prometheus)
            SKIP_WORKER_PROMETHEUS="true"
            shift
            ;;
        --skip-worker-gpu-operator)
            SKIP_WORKER_GPU_OPERATOR="true"
            shift
            ;;
        --register-worker)
            REGISTER_WORKER="true"
            shift
            ;;
        --controller-kubeconfig)
            CONTROLLER_KUBECONFIG="$2"
            shift 2
            ;;
        --controller-context)
            CONTROLLER_CONTEXT="$2"
            shift 2
            ;;
        --worker-kubeconfig)
            # Support multiple workers - add to array
            WORKER_KUBECONFIGS+=("$2")
            # Also set legacy variable for backward compatibility (last one)
            WORKER_KUBECONFIG="$2"
            shift 2
            ;;
        --worker-context)
            # Support multiple worker contexts - add to array
            WORKER_CONTEXTS+=("$2")
            # Also set legacy variable for backward compatibility (last one)
            WORKER_CONTEXT="$2"
            shift 2
            ;;
        --worker-name)
            # Support multiple worker names - add to array
            WORKER_NAMES+=("$2")
            shift 2
            ;;
        --register-cluster-name)
            REGISTER_CLUSTER_NAME="$2"
            shift 2
            ;;
        --register-project-name)
            REGISTER_PROJECT_NAME="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --generate-config|--dry-run)
            GENERATE_CONFIG_ONLY="true"
            shift
            ;;
        --preserve-config)
            PRESERVE_CONFIG="true"
            shift
            ;;
        --skip-dependency-check)
            SKIP_DEPENDENCY_CHECK="true"
            shift
            ;;
        --local-repo)
            LOCAL_REPO="$2"
            shift 2
            ;;
        --telemetry-endpoint)
            TELEMETRY_ENDPOINT="$2"
            shift 2
            ;;
        --telemetry-provider)
            TELEMETRY_PROVIDER="$2"
            shift 2
            ;;
        --cloud-provider)
            CLOUD_PROVIDER="$2"
            shift 2
            ;;
        --cloud-region)
            CLOUD_REGION="$2"
            shift 2
            ;;
        --controller-namespace)
            CONTROLLER_NAMESPACE="$2"
            shift 2
            ;;
        --controller-endpoint)
            CONTROLLER_ENDPOINT="$2"
            shift 2
            ;;
        --worker-endpoint)
            WORKER_ENDPOINTS+=("$2")
            shift 2
            ;;
        --ui-service-type)
            UI_SERVICE_TYPE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Banner
echo "=============================================="
echo "   🚀 EGS Quick Installer"
echo "   Enterprise GPU Scheduler"
echo "=============================================="
echo ""

# Check all required tools up-front, BEFORE any side effects (clone/copy/config writes).
# This avoids failing 30+ seconds in (after a git clone) just because yq or jq is missing.
MISSING_TOOLS=()
for _tool in git kubectl yq jq; do
    command -v "$_tool" &> /dev/null || MISSING_TOOLS+=("$_tool")
done
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    print_error "Required tool(s) not installed: ${MISSING_TOOLS[*]}"
    print_info "Please install the missing tool(s) and re-run the installer:"
    print_info "  - git      (repository download)"
    print_info "  - kubectl  (cluster access)"
    print_info "  - yq       (v4.44.2+, YAML config edits)"
    print_info "  - jq       (v1.6+, JSON parsing)"
    exit 1
fi

# Save original directory (where user ran curl from) - needed for register_worker_cluster
ORIGINAL_DIR="$(pwd)"

# If --register-worker is set, run registration
# If worker kubeconfig is provided, it will continue with installation
# Otherwise, it will exit after registration
if [ "$REGISTER_WORKER" = "true" ]; then
    register_worker_cluster
    # If register_worker_cluster didn't exit, it means worker installation should proceed
    # The function sets up the necessary variables and continues
fi

# Normalize worker arrays: if legacy WORKER_KUBECONFIG is set but arrays are empty, add it to array
if [ -n "$WORKER_KUBECONFIG" ] && [ ${#WORKER_KUBECONFIGS[@]} -eq 0 ]; then
    WORKER_KUBECONFIGS+=("$WORKER_KUBECONFIG")
    if [ -n "$WORKER_CONTEXT" ]; then
        WORKER_CONTEXTS+=("$WORKER_CONTEXT")
    fi
fi

# Auto-detect multi-cluster mode: if both CONTROLLER_KUBECONFIG and at least one WORKER_KUBECONFIG are provided
MULTI_CLUSTER="false"
if [ -n "$CONTROLLER_KUBECONFIG" ] && [ ${#WORKER_KUBECONFIGS[@]} -gt 0 ]; then
    MULTI_CLUSTER="true"
    print_info "🌐 Multi-cluster mode auto-detected (Controller kubeconfig and ${#WORKER_KUBECONFIGS[@]} worker kubeconfig(s) provided)"
fi

# Validate multi-cluster mode if enabled
if [ "$MULTI_CLUSTER" = "true" ]; then
    # Validate required kubeconfigs for components being installed
    if [ "$SKIP_CONTROLLER" = "false" ] && [ -z "$CONTROLLER_KUBECONFIG" ]; then
        print_error "❌ ERROR: --controller-kubeconfig is required when installing Controller in multi-cluster mode"
        exit 1
    fi
    
    # UI uses the same kubeconfig as Controller (they're deployed together)
    if [ "$SKIP_UI" = "false" ] && [ -z "$CONTROLLER_KUBECONFIG" ]; then
        print_error "❌ ERROR: --controller-kubeconfig is required when installing UI in multi-cluster mode (UI uses Controller's kubeconfig)"
        exit 1
    fi
    
    if [ "$SKIP_WORKER" = "false" ] && [ ${#WORKER_KUBECONFIGS[@]} -eq 0 ]; then
        print_error "❌ ERROR: At least one --worker-kubeconfig is required when installing Worker in multi-cluster mode"
        exit 1
    fi
    
    # Validate kubeconfig files exist
    if [ -n "$CONTROLLER_KUBECONFIG" ] && [ ! -f "$CONTROLLER_KUBECONFIG" ]; then
        print_error "❌ ERROR: Controller kubeconfig file not found: $CONTROLLER_KUBECONFIG"
        exit 1
    fi
    
    # Validate all worker kubeconfig files exist
    for worker_kubeconfig in "${WORKER_KUBECONFIGS[@]}"; do
        if [ ! -f "$worker_kubeconfig" ]; then
            print_error "❌ ERROR: Worker kubeconfig file not found: $worker_kubeconfig"
            exit 1
        fi
    done
    
    print_success "Multi-cluster mode validation passed"
    echo ""
    # For multi-cluster, we'll use component-specific kubeconfigs later
    CURRENT_CONTEXT="multi-cluster"
else
    # Single-cluster mode: Set kubeconfig if provided
    if [ -n "$KUBECONFIG_PATH" ]; then
        export KUBECONFIG="$KUBECONFIG_PATH"
        print_info "Set KUBECONFIG to: $KUBECONFIG_PATH"
    fi
    
    # Set context if provided.
    # We remember the user's current context and restore it on exit (see cleanup trap),
    # so running this installer does not permanently mutate the user's active kubeconfig context.
    if [ -n "$KUBE_CONTEXT" ]; then
        ORIGINAL_KUBE_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
        print_info "Switching to context: $KUBE_CONTEXT (original context will be restored on exit)"
        if ! kubectl config use-context "$KUBE_CONTEXT" 2>/dev/null; then
            print_error "Failed to switch to context: $KUBE_CONTEXT"
            print_info "Verify the context exists: kubectl config get-contexts"
            exit 1
        fi
        SWITCHED_CONTEXT="true"
    fi
    
    # Check cluster connectivity
    print_info "Checking Kubernetes cluster connectivity..."
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        print_info "Please ensure kubectl is configured correctly."
        exit 1
    fi
    
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [ -z "$CURRENT_CONTEXT" ]; then
        print_error "No active Kubernetes context found!"
        exit 1
    fi
    
    print_success "Connected to cluster: $CURRENT_CONTEXT"
fi

# ORIGINAL_DIR was already set unconditionally before register_worker_cluster ran.

# Check if Controller is being installed
# License is only required for Controller, not for UI, Worker, or prerequisites (PostgreSQL, Prometheus, GPU Operator)
NEEDS_LICENSE="false"
if [ "$SKIP_CONTROLLER" = "false" ]; then
    NEEDS_LICENSE="true"
fi

# Only check license if Controller is being installed
if [ "$NEEDS_LICENSE" = "true" ]; then
    # Determine license file path
    if [ -z "$LICENSE_FILE" ]; then
        # Default to egs-license.yaml in current directory
        LICENSE_FILE="$ORIGINAL_DIR/egs-license.yaml"
        print_info "License file not specified, using default: egs-license.yaml"
    else
        # If relative path, convert to absolute path from current directory
        if [[ "$LICENSE_FILE" != /* ]]; then
            LICENSE_FILE="$ORIGINAL_DIR/$LICENSE_FILE"
        fi
    fi

    # Verify license file exists
    if [ ! -f "$LICENSE_FILE" ]; then
        print_error "❌ ERROR: License file not found at: $LICENSE_FILE"
        print_error ""
        show_license_steps
        exit 1
    fi

    print_success "License file found: $LICENSE_FILE"
else
    print_info "License not required (Controller is not being installed)"
fi

# Obtain the EGS installer artifacts.
# REPO_SRC points at a directory containing charts/, egs-installer.sh, egs-installer-config.yaml, etc.
TEMP_DIR=$(mktemp -d)
register_cleanup_path "$TEMP_DIR"

if [ -n "$LOCAL_REPO" ]; then
    # Use a local checkout instead of cloning (avoids network access + latency on every run).
    if [ ! -d "$LOCAL_REPO" ] || [ ! -f "$LOCAL_REPO/egs-installer.sh" ]; then
        print_error "--local-repo path is not a valid EGS installer checkout: $LOCAL_REPO"
        print_info "Expected to find egs-installer.sh and charts/ inside that directory."
        exit 1
    fi
    REPO_SRC="$(cd "$LOCAL_REPO" && pwd)"
    print_success "Using local EGS installer checkout: $REPO_SRC"
else
    print_info "Downloading EGS installer..."
    cd "$TEMP_DIR"
    if ! git clone --depth 1 --branch "$EGS_BRANCH" "$EGS_REPO" egs-installation 2>/dev/null; then
        print_error "Failed to download EGS installer from branch: $EGS_BRANCH"
        print_info "Trying main branch..."
        EGS_BRANCH="main"
        if ! git clone --depth 1 --branch "$EGS_BRANCH" "$EGS_REPO" egs-installation; then
            print_error "Failed to download EGS installer"
            print_info "Tip: if you already have a local checkout, pass --local-repo /path/to/egs-installation"
            exit 1
        fi
    fi
    REPO_SRC="$TEMP_DIR/egs-installation"
    print_success "Downloaded EGS installer"
fi

# Copy necessary files to original directory
print_info "Setting up installation in current directory..."
cp -r "$REPO_SRC/charts" "$ORIGINAL_DIR/" 2>/dev/null || {
    print_error "Failed to copy charts directory"
    exit 1
}
cp "$REPO_SRC/egs-installer.sh" "$ORIGINAL_DIR/"
cp "$REPO_SRC/egs-install-prerequisites.sh" "$ORIGINAL_DIR/"
cp "$REPO_SRC/egs-uninstall.sh" "$ORIGINAL_DIR/" 2>/dev/null || true
cp "$REPO_SRC/fetch_egs_slice_token.sh" "$ORIGINAL_DIR/" 2>/dev/null || true

# Use egs-installer-config.yaml from repo as source of truth
if [ ! -f "$REPO_SRC/egs-installer-config.yaml" ]; then
    print_error "egs-installer-config.yaml not found in repository"
    exit 1
fi

# --preserve-config: keep an existing config exactly as-is and skip all regeneration.
CONFIG_PRESERVED="false"
if [ "$PRESERVE_CONFIG" = "true" ]; then
    if [ -f "$ORIGINAL_DIR/egs-installer-config.yaml" ]; then
        print_info "--preserve-config: using existing egs-installer-config.yaml as-is (skipping regeneration)"
        CONFIG_PRESERVED="true"
    else
        print_warning "--preserve-config set but no existing egs-installer-config.yaml found; a new one will be generated"
    fi
fi

if [ "$CONFIG_PRESERVED" != "true" ]; then

# Save worker template from the repo config OR existing config
# Copy repo config to a temporary location in working directory for yq to access
# (yq may not work reliably with files in /tmp)
TEMP_WORKER_TEMPLATE="$ORIGINAL_DIR/.temp-worker-template.yaml"
TEMP_REPO_CONFIG_COPY="$ORIGINAL_DIR/.temp-repo-config.yaml"

# Priority for template source:
# 1. If register-worker mode and existing config has workers, use existing config (preserves customizations)
# 2. Otherwise, use repo config
TEMPLATE_SOURCE=""
if [ "$REGISTER_WORKER" = "true" ] && [ -f "$ORIGINAL_DIR/egs-installer-config.yaml" ]; then
    EXISTING_WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' "$ORIGINAL_DIR/egs-installer-config.yaml" 2>/dev/null || echo "0")
    if [ "$EXISTING_WORKER_COUNT" -gt 0 ]; then
        # Use existing config for template (preserves any customizations from previous installation)
        TEMPLATE_SOURCE="$ORIGINAL_DIR/egs-installer-config.yaml"
        print_info "Using existing config for worker template (found $EXISTING_WORKER_COUNT existing worker(s))"
    fi
fi

# If no template source yet, use repo config
if [ -z "$TEMPLATE_SOURCE" ] && [ -f "$REPO_SRC/egs-installer-config.yaml" ]; then
    # Copy repo config to working directory so yq can access it
    cp "$REPO_SRC/egs-installer-config.yaml" "$TEMP_REPO_CONFIG_COPY"
    TEMPLATE_SOURCE="$TEMP_REPO_CONFIG_COPY"
    print_info "Using repo config for worker template"
fi

# Save the template
if [ -n "$TEMPLATE_SOURCE" ] && [ -f "$TEMPLATE_SOURCE" ]; then
    WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' "$TEMPLATE_SOURCE" 2>/dev/null || echo "0")
    if [ "$WORKER_COUNT" -gt 0 ]; then
        # Save the template from the first worker entry
        yq eval '.kubeslice_worker_egs[0]' "$TEMPLATE_SOURCE" > "$TEMP_WORKER_TEMPLATE" 2>/dev/null
        # Verify template has valid content
        if [ -s "$TEMP_WORKER_TEMPLATE" ] && ! grep -qE "^(null|{})$" "$TEMP_WORKER_TEMPLATE"; then
            TEMPLATE_NAME=$(yq eval '.name' "$TEMP_WORKER_TEMPLATE" 2>/dev/null || echo "")
            TEMPLATE_NAME_CLEAN=$(echo "$TEMPLATE_NAME" | tr -d '"' | tr -d "'" | xargs)
            if [ -n "$TEMPLATE_NAME_CLEAN" ] && [ "$TEMPLATE_NAME_CLEAN" != "null" ]; then
                print_info "Saved worker template with all fields preserved"
            else
                if [ -s "$TEMP_WORKER_TEMPLATE" ]; then
                    print_info "Saved worker template (name check inconclusive, but file has content)"
                fi
            fi
        fi
    fi
fi
# Clean up temp copy
rm -f "$TEMP_REPO_CONFIG_COPY"

# Now copy base config from repo to working directory
# In register-worker mode, preserve existing config if it has workers configured
EXISTING_WORKERS=0
if [ "$REGISTER_WORKER" = "true" ]; then
    # Check if local config exists
    if [ -f "$ORIGINAL_DIR/egs-installer-config.yaml" ]; then
        EXISTING_WORKERS=$(yq eval '.kubeslice_worker_egs | length' "$ORIGINAL_DIR/egs-installer-config.yaml" 2>/dev/null || echo "0")
        if [ "$EXISTING_WORKERS" -gt 0 ]; then
            print_info "Preserving existing local config with $EXISTING_WORKERS worker(s) (register-worker mode)"
            # Don't overwrite - we'll append to existing config
            # Ensure all existing workers have skip_installation=true (they're already installed)
            for ((i=0; i<EXISTING_WORKERS; i++)); do
                CURRENT_SKIP=$(yq eval ".kubeslice_worker_egs[$i].skip_installation" "$ORIGINAL_DIR/egs-installer-config.yaml" 2>/dev/null)
                if [ "$CURRENT_SKIP" != "true" ]; then
                    yq eval ".kubeslice_worker_egs[$i].skip_installation = true" -i "$ORIGINAL_DIR/egs-installer-config.yaml"
                    WORKER_NAME=$(yq eval ".kubeslice_worker_egs[$i].name" "$ORIGINAL_DIR/egs-installer-config.yaml" 2>/dev/null)
                    print_info "Set skip_installation=true for existing worker: $WORKER_NAME"
                fi
            done
            WORKERS_PRESERVED_FROM_CONTROLLER="true"  # Mark as preserved
        else
            # Local config exists but has no workers - copy from repo
            install_repo_config
            EXISTING_WORKERS=0
            WORKERS_PRESERVED_FROM_CONTROLLER="false"
        fi
    else
        # No local config found. Generate a clean, self-contained config for JUST the
        # worker being registered.
        #
        # We deliberately do NOT import every cluster already registered on the controller
        # as a worker entry. A targeted `--register-worker --register-cluster-name X` should
        # only produce/act on the single cluster X the user named. Auto-importing all
        # controller-registered clusters previously:
        #   (a) listed unrelated clusters (e.g. other workers, even the controller) under
        #       kubeslice_worker_egs in the new worker's config,
        #   (b) generated their YAML under installation-files, and
        #   (c) misaligned kubeslice_worker_egs[] with cluster_registration[], which
        #       fabricated a null-named Cluster and made the 3rd/4th registration fatal.
        # The controller already tracks every registered cluster independently, so nothing
        # is lost by omitting them here. (Multi-worker preservation still works when you
        # keep and re-use a local egs-installer-config.yaml — handled in the branch above.)
        print_info "No local config found - generating a clean config for worker '$REGISTER_CLUSTER_NAME' only (existing controller clusters are left untouched)."
        install_repo_config
        EXISTING_WORKERS=0
        WORKERS_PRESERVED_FROM_CONTROLLER="false"
    fi
else
    # Normal mode: always copy from repo (ONLY if not in register-worker mode with existing workers)
    install_repo_config
    EXISTING_WORKERS=0
    WORKERS_PRESERVED_FROM_CONTROLLER="false"
fi

# Clean up temp copy
rm -f "$TEMP_REPO_CONFIG_COPY"

fi  # end: if [ "$CONFIG_PRESERVED" != "true" ] (config generation block 1)

# Cleanup temp directory (AFTER template is saved). The EXIT trap also covers this.
rm -rf "$TEMP_DIR"
print_success "Setup complete in: $ORIGINAL_DIR"

# Change to original directory
cd "$ORIGINAL_DIR"

# Make scripts executable
chmod +x egs-installer.sh egs-install-prerequisites.sh egs-uninstall.sh fetch_egs_slice_token.sh 2>/dev/null || true

# (yq and jq availability is validated at the top of the script, before any side effects.)

if [ "$CONFIG_PRESERVED" != "true" ]; then

# Handle kubeconfigs based on mode
if [ "$MULTI_CLUSTER" = "true" ]; then
    # Multi-cluster mode: Copy component-specific kubeconfigs
    print_info "Copying component-specific kubeconfigs for multi-cluster mode..."
    
    # Initialize GLOBAL_CONTEXT variable
    GLOBAL_CONTEXT=""
    
    # Copy controller kubeconfig if provided (UI uses the same kubeconfig as Controller)
    if [ -n "$CONTROLLER_KUBECONFIG" ]; then
        CONTROLLER_KUBECONFIG_RELATIVE=$(basename "$CONTROLLER_KUBECONFIG")
        CONTROLLER_KUBECONFIG_FULLPATH=$(realpath "$CONTROLLER_KUBECONFIG" 2>/dev/null || echo "$CONTROLLER_KUBECONFIG")
        ORIGINAL_DIR_FULLPATH=$(realpath "$ORIGINAL_DIR")
        CONTROLLER_KUBECONFIG_DIR=$(dirname "$CONTROLLER_KUBECONFIG_FULLPATH")
        
        # Get controller context (use provided context or get from kubeconfig)
        if [ -z "$CONTROLLER_CONTEXT" ]; then
            CONTROLLER_CONTEXT=$(kubectl config --kubeconfig="$CONTROLLER_KUBECONFIG" current-context 2>/dev/null || echo "")
        fi
        
        # Only copy if kubeconfig is not already in the work directory
        if [ "$CONTROLLER_KUBECONFIG_DIR" != "$ORIGINAL_DIR_FULLPATH" ]; then
            if ! cp "$CONTROLLER_KUBECONFIG" "$ORIGINAL_DIR/$CONTROLLER_KUBECONFIG_RELATIVE"; then
                print_error "Failed to copy controller kubeconfig to work directory"
                exit 1
            fi
            print_success "Copied controller kubeconfig: $CONTROLLER_KUBECONFIG_RELATIVE (UI will use the same)"
        else
            print_success "Controller kubeconfig already in work directory: $CONTROLLER_KUBECONFIG_RELATIVE (UI will use the same)"
        fi
        # Use controller kubeconfig as global (default)
        KUBECONFIG_RELATIVE="$CONTROLLER_KUBECONFIG_RELATIVE"
        # Use controller context as global context
        GLOBAL_CONTEXT="$CONTROLLER_CONTEXT"
    fi
    
    # Copy worker kubeconfigs if provided (support multiple workers)
    WORKER_KUBECONFIG_RELATIVES=()
    WORKER_CONTEXTS_DETECTED=()
    ORIGINAL_DIR_FULLPATH=$(realpath "$ORIGINAL_DIR")
    
    for i in "${!WORKER_KUBECONFIGS[@]}"; do
        WORKER_KUBECONFIG="${WORKER_KUBECONFIGS[$i]}"
        WORKER_KUBECONFIG_RELATIVE=$(basename "$WORKER_KUBECONFIG")
        WORKER_KUBECONFIG_FULLPATH=$(realpath "$WORKER_KUBECONFIG" 2>/dev/null || echo "$WORKER_KUBECONFIG")
        WORKER_KUBECONFIG_DIR=$(dirname "$WORKER_KUBECONFIG_FULLPATH")
        
        # Get worker context (use provided context or get from kubeconfig)
        if [ $i -lt ${#WORKER_CONTEXTS[@]} ]; then
            WORKER_CTX="${WORKER_CONTEXTS[$i]}"
        else
            WORKER_CTX=""
        fi
        
        if [ -z "$WORKER_CTX" ]; then
            WORKER_CTX=$(kubectl config --kubeconfig="$WORKER_KUBECONFIG" current-context 2>/dev/null || echo "")
        fi
        WORKER_CONTEXTS_DETECTED+=("$WORKER_CTX")
        
        # Only copy if kubeconfig is not already in the work directory
        if [ "$WORKER_KUBECONFIG_DIR" != "$ORIGINAL_DIR_FULLPATH" ]; then
            if ! cp "$WORKER_KUBECONFIG" "$ORIGINAL_DIR/$WORKER_KUBECONFIG_RELATIVE"; then
                print_error "Failed to copy worker kubeconfig to work directory: $WORKER_KUBECONFIG_RELATIVE"
                exit 1
            fi
            print_success "Copied worker kubeconfig: $WORKER_KUBECONFIG_RELATIVE"
        else
            print_success "Worker kubeconfig already in work directory: $WORKER_KUBECONFIG_RELATIVE"
        fi
        WORKER_KUBECONFIG_RELATIVES+=("$WORKER_KUBECONFIG_RELATIVE")
        
        # Use first worker kubeconfig as global if controller not provided
        if [ $i -eq 0 ] && [ -z "$CONTROLLER_KUBECONFIG" ]; then
            KUBECONFIG_RELATIVE="$WORKER_KUBECONFIG_RELATIVE"
            GLOBAL_CONTEXT="$WORKER_CTX"
        fi
    done
    
    # Detect cloud provider and GPU nodes from first worker cluster (if available).
    # Use explicit --kubeconfig/--context flags so we DON'T mutate the global KUBECONFIG env
    # or the worker kubeconfig file's current-context as a side effect of detection.
    if [ ${#WORKER_KUBECONFIGS[@]} -gt 0 ]; then
        FIRST_WORKER_KUBECONFIG="${WORKER_KUBECONFIGS[0]}"
        DETECT_CMD="kubectl --kubeconfig $FIRST_WORKER_KUBECONFIG"
        if [ ${#WORKER_CONTEXTS_DETECTED[@]} -gt 0 ] && [ -n "${WORKER_CONTEXTS_DETECTED[0]}" ]; then
            DETECT_CMD="$DETECT_CMD --context ${WORKER_CONTEXTS_DETECTED[0]}"
        fi
        CLOUD_PROVIDER_DETECTED=$($DETECT_CMD get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | cut -d: -f1 || echo "")
        GPU_NODES=$($DETECT_CMD get nodes -o json 2>/dev/null | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' 2>/dev/null | wc -l || echo "0")
    else
        CLOUD_PROVIDER_DETECTED=""
        GPU_NODES="0"
    fi
else
    # Single-cluster mode: Detect GPU nodes and cloud provider
    print_info "Detecting cluster capabilities..."
    GPU_NODES=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' 2>/dev/null | wc -l || echo "0")
    
    # Detect cloud provider
    CLOUD_PROVIDER_DETECTED=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | cut -d: -f1 || echo "")
    
    # Get kubeconfig details
    if [ -f "$KUBECONFIG" ]; then
        KUBECONFIG_FULLPATH=$(realpath "$KUBECONFIG")
        ORIGINAL_DIR_FULLPATH=$(realpath "$ORIGINAL_DIR")
        KUBECONFIG_DIR=$(dirname "$KUBECONFIG_FULLPATH")
        
        if [ "$KUBECONFIG_DIR" = "$ORIGINAL_DIR_FULLPATH" ]; then
            # Kubeconfig is in the same directory, use its basename
            KUBECONFIG_RELATIVE=$(basename "$KUBECONFIG")
        else
            # Kubeconfig is elsewhere, copy it to work directory
            KUBECONFIG_RELATIVE=$(basename "$KUBECONFIG")
            if ! cp "$KUBECONFIG" "$ORIGINAL_DIR/$KUBECONFIG_RELATIVE"; then
                print_error "Failed to copy kubeconfig to work directory"
                exit 1
            fi
            print_success "Copied kubeconfig to work directory: $KUBECONFIG_RELATIVE"
            # Update KUBECONFIG environment variable to point to the copied file
            export KUBECONFIG="$ORIGINAL_DIR/$KUBECONFIG_RELATIVE"
        fi
    else
        # KUBECONFIG env is not set to a readable file. Fall back to the default kubectl
        # location ($HOME/.kube/config) rather than the bogus literal "kubeconfig",
        # which would make the downstream scripts look for a non-existent file.
        DEFAULT_KUBECONFIG="${HOME}/.kube/config"
        if [ -f "$DEFAULT_KUBECONFIG" ]; then
            KUBECONFIG_RELATIVE=$(basename "$DEFAULT_KUBECONFIG")
            if ! cp "$DEFAULT_KUBECONFIG" "$ORIGINAL_DIR/$KUBECONFIG_RELATIVE"; then
                print_error "Failed to copy default kubeconfig ($DEFAULT_KUBECONFIG) to work directory"
                exit 1
            fi
            export KUBECONFIG="$ORIGINAL_DIR/$KUBECONFIG_RELATIVE"
            print_success "Using default kubeconfig: $DEFAULT_KUBECONFIG (copied as $KUBECONFIG_RELATIVE)"
        else
            print_error "Could not determine a kubeconfig file."
            print_info "KUBECONFIG is not set to a readable file and $DEFAULT_KUBECONFIG does not exist."
            print_info "Pass --kubeconfig /path/to/kubeconfig explicitly."
            exit 1
        fi
    fi
fi

# Set GPU detection result.
# ENABLE_CUSTOM_APPS toggles EGS custom GPU apps (GPR/inventory) that require GPU nodes.
# It is independent of the GPU Operator: we never auto-skip the GPU Operator based on
# detection — that remains the user's choice via --skip-gpu-operator (or --skip-worker-gpu-operator).
if [ "$GPU_NODES" -gt 0 ]; then
    print_success "Detected $GPU_NODES GPU node(s)"
    ENABLE_CUSTOM_APPS="true"
else
    print_warning "No GPU nodes detected (GPU-dependent custom apps disabled; GPU Operator still controlled by your flags)."
    ENABLE_CUSTOM_APPS="false"
fi

# Set cloud provider in config (exclude Linode - keep it empty for Linode clusters)
# Only auto-detect if user didn't provide --cloud-provider flag
if [ -z "$CLOUD_PROVIDER" ]; then
    if [ "$CLOUD_PROVIDER_DETECTED" = "linode" ]; then
        CLOUD_PROVIDER=""  # Keep empty for Linode
        print_success "Detected cloud provider: linode (will be left empty in config)"
    elif [ -n "$CLOUD_PROVIDER_DETECTED" ]; then
        CLOUD_PROVIDER="$CLOUD_PROVIDER_DETECTED"
        print_success "Detected cloud provider: $CLOUD_PROVIDER"
    fi
else
    print_success "Using user-provided cloud provider: $CLOUD_PROVIDER"
fi

# Update egs-installer-config.yaml with detected values
print_info "Updating EGS configuration..."

# Update kubeconfig and context
if [ "$MULTI_CLUSTER" = "true" ]; then
    # Multi-cluster mode: Set global kubeconfig (use controller as default, or first available)
    yq eval ".global_kubeconfig = \"$KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
    # Set global context (use controller context if available, otherwise worker context)
    if [ -n "$GLOBAL_CONTEXT" ]; then
        yq eval ".global_kubecontext = \"$GLOBAL_CONTEXT\"" -i egs-installer-config.yaml
    else
        yq eval ".global_kubecontext = \"\"" -i egs-installer-config.yaml
    fi
    
    # Set component-specific kubeconfigs and contexts (even if skipping installation, we need them in config)
    if [ -n "$CONTROLLER_KUBECONFIG" ]; then
        # Set Controller kubeconfig and context
        if [ "$SKIP_CONTROLLER" = "false" ]; then
            yq eval ".kubeslice_controller_egs.use_global_kubeconfig = false" -i egs-installer-config.yaml
            yq eval ".kubeslice_controller_egs.kubeconfig = \"$CONTROLLER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
            if [ -n "$CONTROLLER_CONTEXT" ]; then
                yq eval ".kubeslice_controller_egs.kubecontext = \"$CONTROLLER_CONTEXT\"" -i egs-installer-config.yaml
            else
                yq eval ".kubeslice_controller_egs.kubecontext = \"\"" -i egs-installer-config.yaml
            fi
            print_success "Set Controller kubeconfig: $CONTROLLER_KUBECONFIG_RELATIVE"
        fi
        
        # UI uses the same kubeconfig and context as Controller (they're deployed together)
        if [ "$SKIP_UI" = "false" ]; then
            yq eval ".kubeslice_ui_egs.use_global_kubeconfig = false" -i egs-installer-config.yaml
            yq eval ".kubeslice_ui_egs.kubeconfig = \"$CONTROLLER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
            if [ -n "$CONTROLLER_CONTEXT" ]; then
                yq eval ".kubeslice_ui_egs.kubecontext = \"$CONTROLLER_CONTEXT\"" -i egs-installer-config.yaml
            else
                yq eval ".kubeslice_ui_egs.kubecontext = \"\"" -i egs-installer-config.yaml
            fi
            print_success "Set UI kubeconfig (same as Controller): $CONTROLLER_KUBECONFIG_RELATIVE"
        fi
    fi
    
    # Set worker kubeconfigs and contexts for multiple workers
    if [ ${#WORKER_KUBECONFIG_RELATIVES[@]} -gt 0 ]; then
        # Use the template that was saved from the original repo config (before any modifications)
        TEMP_WORKER_TEMPLATE="$ORIGINAL_DIR/.temp-worker-template.yaml"
        
        # Ensure we're in the right directory
        cd "$ORIGINAL_DIR" 2>/dev/null || true
        
        # Check if template file exists and has valid content
        if [ -f "$TEMP_WORKER_TEMPLATE" ] && [ -s "$TEMP_WORKER_TEMPLATE" ]; then
            # Verify template has a name field (indicates it's a valid worker config)
            # Use proper yq syntax (don't use // empty as it causes errors)
            TEMPLATE_NAME_CHECK=$(yq eval '.name' "$TEMP_WORKER_TEMPLATE" 2>/dev/null || echo "")
            if [ -n "$TEMPLATE_NAME_CHECK" ] && [ "$TEMPLATE_NAME_CHECK" != "null" ]; then
                HAS_TEMPLATE=true
                print_info "Using worker template with all fields preserved"
            else
                # Still use template if file exists and has content (might have fields even if name check fails)
                if [ -s "$TEMP_WORKER_TEMPLATE" ] && ! grep -qE "^(null|{})$" "$TEMP_WORKER_TEMPLATE"; then
                    HAS_TEMPLATE=true
                    print_info "Using worker template (name check inconclusive, but file has content)"
                else
                    HAS_TEMPLATE=false
                    print_warning "Template file exists but is invalid, will use empty structure"
                fi
            fi
        else
            HAS_TEMPLATE=false
            print_warning "Template file not found, will use empty structure (fields may be missing)"
        fi
        
        # Get the count of existing workers before processing
        # Use the EXISTING_WORKERS value set earlier (from controller cluster or local config)
        if [ -n "$EXISTING_WORKERS" ] && [ "$EXISTING_WORKERS" -gt 0 ]; then
            EXISTING_WORKER_COUNT=$EXISTING_WORKERS
        else
            EXISTING_WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' egs-installer-config.yaml 2>/dev/null || echo "0")
        fi
        
        # Check if we're in register-worker mode (adding a new worker to existing ones)
        # In register-worker mode, we should append, not replace
        if [ "$REGISTER_WORKER" = "true" ] && [ "$EXISTING_WORKER_COUNT" -gt 0 ]; then
            print_info "Register-worker mode: Appending new worker to existing ${EXISTING_WORKER_COUNT} worker(s)"
            
            # But first, check if a worker with the same name already exists and remove it
            # This prevents duplicate entries when re-registering the same worker
            if [ ${#WORKER_NAMES[@]} -gt 0 ] && [ -n "${WORKER_NAMES[0]}" ]; then
                NEW_WORKER_NAME="${WORKER_NAMES[0]}"
            elif [ -n "$CLUSTER_NAME" ] && [ "$CLUSTER_NAME" != "worker-1" ]; then
                NEW_WORKER_NAME="$CLUSTER_NAME"
            else
                NEW_WORKER_NAME="worker-1"
            fi
            
            # Check if this worker name already exists and remove ALL instances
            print_info "Checking for existing worker(s) named '$NEW_WORKER_NAME'"
            REMOVED_COUNT=0
            # Loop backwards to avoid index shifting issues when deleting
            for ((idx=EXISTING_WORKER_COUNT-1; idx>=0; idx--)); do
                EXISTING_NAME=$(yq eval ".kubeslice_worker_egs[$idx].name" egs-installer-config.yaml 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
                if [ "$EXISTING_NAME" = "$NEW_WORKER_NAME" ]; then
                    print_warning "Found duplicate worker '$NEW_WORKER_NAME' at index $idx - removing to avoid duplicates"
                    yq eval "del(.kubeslice_worker_egs[$idx])" -i egs-installer-config.yaml
                    REMOVED_COUNT=$((REMOVED_COUNT + 1))
                fi
            done
            
            if [ "$REMOVED_COUNT" -gt 0 ]; then
                # After deletion, recalculate the existing worker count
                EXISTING_WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' egs-installer-config.yaml 2>/dev/null || echo "0")
                print_info "Removed $REMOVED_COUNT duplicate worker(s). Updated existing worker count: $EXISTING_WORKER_COUNT"
            fi
            
            # Don't delete existing workers - we'll append the new one
            START_INDEX=$EXISTING_WORKER_COUNT
        else
            # Normal mode: replace all workers
            # ONLY delete if we didn't preserve workers from controller cluster
            if [ "$WORKERS_PRESERVED_FROM_CONTROLLER" != "true" ]; then
                print_info "Replacing all workers in config"
                # Remove all existing workers from the array first
                yq eval 'del(.kubeslice_worker_egs[])' -i egs-installer-config.yaml
                START_INDEX=0
                # After deletion, EXISTING_WORKER_COUNT should be 0 for the template load logic
                EXISTING_WORKER_COUNT=0
            else
                print_info "Preserving workers from controller cluster, appending new ones"
                START_INDEX=$EXISTING_WORKER_COUNT
            fi
        fi
        
        # Add each worker to the array (starting from START_INDEX for append mode)
        for i in "${!WORKER_KUBECONFIG_RELATIVES[@]}"; do
            # Calculate the actual index in the config array
            CONFIG_INDEX=$((START_INDEX + i))
            WORKER_KUBECONFIG_RELATIVE="${WORKER_KUBECONFIG_RELATIVES[$i]}"
            WORKER_CTX="${WORKER_CONTEXTS_DETECTED[$i]}"
            
            # Check if this worker entry already exists (when updating existing worker, not appending)
            # Skip workers that were preserved from controller cluster (skip_installation=true, use_global_kubeconfig=true)
            EXISTING_WORKER_NAME=""
            EXISTING_WORKER_KUBECONFIG=""
            EXISTING_WORKER_KUBECONTEXT=""
            EXISTING_WORKER_SKIP=""
            EXISTING_WORKER_USE_GLOBAL=""
            SHOULD_SKIP_WORKER=false
            
            if [ "$CONFIG_INDEX" -lt "$EXISTING_WORKER_COUNT" ]; then
                # This is an existing worker - check if it should be skipped (preserved from controller)
                EXISTING_WORKER_SKIP=$(yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].skip_installation" egs-installer-config.yaml 2>/dev/null)
                EXISTING_WORKER_USE_GLOBAL=$(yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].use_global_kubeconfig" egs-installer-config.yaml 2>/dev/null)
                EXISTING_WORKER_NAME=$(yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].name" egs-installer-config.yaml 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
                EXISTING_WORKER_KUBECONFIG=$(yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubeconfig" egs-installer-config.yaml 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
                EXISTING_WORKER_KUBECONTEXT=$(yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubecontext" egs-installer-config.yaml 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
                
                # If this worker is marked as skip_installation=true and use_global_kubeconfig=true,
                # it was preserved from the controller cluster - don't modify it AT ALL
                if [ "$EXISTING_WORKER_SKIP" = "true" ] && [ "$EXISTING_WORKER_USE_GLOBAL" = "true" ]; then
                    print_info "Skipping worker $EXISTING_WORKER_NAME at index $CONFIG_INDEX (preserved from controller, already configured with skip_installation=true)"
                    SHOULD_SKIP_WORKER=true
                fi
            fi
            
            # If this worker should be skipped (preserved), don't process it
            if [ "$SHOULD_SKIP_WORKER" = "true" ]; then
                continue
            fi
            
            # Determine worker name
            # Priority: 1) Provided name via --worker-name, 2) CLUSTER_NAME flag, 3) Existing name (if kubeconfig/kubecontext match), 4) Default
            if [ $i -lt ${#WORKER_NAMES[@]} ] && [ -n "${WORKER_NAMES[$i]}" ]; then
                WORKER_NAME="${WORKER_NAMES[$i]}"
            elif [ -n "$CLUSTER_NAME" ] && [ "$CLUSTER_NAME" != "worker-1" ] && [ $i -eq 0 ]; then
                # Use CLUSTER_NAME for first worker if it's explicitly provided (not default)
                WORKER_NAME="$CLUSTER_NAME"
            elif [ -n "$EXISTING_WORKER_NAME" ] && [ "$EXISTING_WORKER_NAME" != "null" ] && [ "$EXISTING_WORKER_NAME" != "empty" ] && \
                 [ -n "$EXISTING_WORKER_KUBECONFIG" ] && [ "$EXISTING_WORKER_KUBECONFIG" != "null" ] && [ "$EXISTING_WORKER_KUBECONFIG" != "empty" ] && \
                 [ -n "$EXISTING_WORKER_KUBECONTEXT" ] && [ "$EXISTING_WORKER_KUBECONTEXT" != "null" ] && [ "$EXISTING_WORKER_KUBECONTEXT" != "empty" ]; then
                # Preserve existing name if kubeconfig and kubecontext are already set
                WORKER_NAME="$EXISTING_WORKER_NAME"
                print_info "Preserving existing worker name: $WORKER_NAME (kubeconfig and kubecontext already set)"
            else
                WORKER_NAME="worker-$((i+1))"
            fi
            
            # Only load template for NEW workers (CONFIG_INDEX >= EXISTING_WORKER_COUNT)
            # For existing workers, preserve all their fields
            if [ "$CONFIG_INDEX" -ge "$EXISTING_WORKER_COUNT" ]; then
                # This is a new worker - load template
                if [ "$HAS_TEMPLATE" = "true" ] && [ -f "$TEMP_WORKER_TEMPLATE" ]; then
                    # Load the template structure directly into the worker entry
                    # Use absolute path to ensure yq can find the file
                    print_info "Loading template for new worker at index $CONFIG_INDEX from $TEMP_WORKER_TEMPLATE"
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX] = load(\"$TEMP_WORKER_TEMPLATE\")" -i egs-installer-config.yaml
                    # Verify the load was successful
                    LOADED_KEYS=$(yq eval ".kubeslice_worker_egs[$CONFIG_INDEX] | keys" egs-installer-config.yaml 2>/dev/null | wc -l)
                    if [ "$LOADED_KEYS" -gt 5 ]; then
                        print_info "Template loaded successfully with $LOADED_KEYS fields"
                    else
                        print_warning "Template load may have failed, only $LOADED_KEYS fields found"
                    fi
                else
                    # Create a new worker entry with empty structure (will use defaults from egs-installer.sh)
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX] = {}" -i egs-installer-config.yaml
                    if [ "$HAS_TEMPLATE" = "true" ]; then
                        print_warning "Template file not found at $TEMP_WORKER_TEMPLATE, using empty structure"
                    fi
                fi
                
                # Update all fields for new worker
                yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].name = \"$WORKER_NAME\" | .kubeslice_worker_egs[$CONFIG_INDEX].name style=\"double\"" -i egs-installer-config.yaml
                yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
                yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\" | .kubeslice_worker_egs[$CONFIG_INDEX].kubeconfig style=\"double\"" -i egs-installer-config.yaml
                
                if [ -n "$WORKER_CTX" ]; then
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubecontext = \"$WORKER_CTX\" | .kubeslice_worker_egs[$CONFIG_INDEX].kubecontext style=\"double\"" -i egs-installer-config.yaml
                    if [ "$SKIP_WORKER" = "false" ]; then
                        print_success "Set Worker $WORKER_NAME kubeconfig: $WORKER_KUBECONFIG_RELATIVE with context: $WORKER_CTX"
                    fi
                else
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubecontext = \"\" | .kubeslice_worker_egs[$CONFIG_INDEX].kubecontext style=\"double\"" -i egs-installer-config.yaml
                    print_warning "Worker $WORKER_NAME context not found, leaving empty"
                fi
                
                # Set skip_installation based on SKIP_WORKER flag (only for the NEW worker)
                # Existing workers should already have skip_installation: true
                if [ "$SKIP_WORKER" = "true" ]; then
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].skip_installation = true" -i egs-installer-config.yaml
                    print_info "New worker $WORKER_NAME: skip_installation=true (--skip-worker flag provided)"
                else
                    # Don't set skip_installation - let it use template default (false)
                    # This worker will be installed
                    print_info "New worker $WORKER_NAME: skip_installation=false (will be installed)"
                fi
            else
                # This is an existing worker - only update kubeconfig/kubecontext if they are different
                # Preserve ALL other fields
                if [ -n "$WORKER_NAME" ]; then
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].name = \"$WORKER_NAME\" | .kubeslice_worker_egs[$CONFIG_INDEX].name style=\"double\"" -i egs-installer-config.yaml
                fi
                yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
                yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\" | .kubeslice_worker_egs[$CONFIG_INDEX].kubeconfig style=\"double\"" -i egs-installer-config.yaml
                if [ -n "$WORKER_CTX" ]; then
                    yq eval ".kubeslice_worker_egs[$CONFIG_INDEX].kubecontext = \"$WORKER_CTX\" | .kubeslice_worker_egs[$CONFIG_INDEX].kubecontext style=\"double\"" -i egs-installer-config.yaml
                fi
                print_info "Updated existing worker $WORKER_NAME with new kubeconfig/kubecontext"
            fi
        done
        
        # Cleanup temp file (only after all workers are processed)
        rm -f "$TEMP_WORKER_TEMPLATE"
        
        if [ "$SKIP_WORKER" = "false" ]; then
            print_success "Configured ${#WORKER_KUBECONFIG_RELATIVES[@]} worker cluster(s)"
        fi
    fi
else
    # Single-cluster mode: Use global kubeconfig and context
    yq eval ".global_kubeconfig = \"$KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
    yq eval ".global_kubecontext = \"$CURRENT_CONTEXT\"" -i egs-installer-config.yaml
    
    # Normalize the single-cluster worker name to CLUSTER_NAME.
    # The repo config template ships a placeholder worker name (e.g. "dc-cluster3"), and
    # cluster_registration[0].cluster_name is always set to CLUSTER_NAME below. If we only
    # overrode the worker name for non-default CLUSTER_NAME values, a default run (worker-1)
    # would leave the worker entry named "dc-cluster3" while its registration said "worker-1",
    # so the installed worker could never bind to its Cluster CR. Always set it explicitly.
    yq eval ".kubeslice_worker_egs[0].name = \"$CLUSTER_NAME\" | .kubeslice_worker_egs[0].name style=\"double\"" -i egs-installer-config.yaml
    print_info "Worker name set to: $CLUSTER_NAME"
    
    # Ensure use_global_kubeconfig is set for single-cluster mode
    yq eval ".kubeslice_worker_egs[0].use_global_kubeconfig = true" -i egs-installer-config.yaml
fi

# Update cluster_registration for workers
# In register-worker mode with existing workers, we should add a new cluster_registration entry
# Otherwise, update the first entry
if [ "$REGISTER_WORKER" = "true" ] && [ ${#WORKER_KUBECONFIG_RELATIVES[@]} -gt 0 ]; then
    # Register-worker mode: add or update cluster_registration entry
    EXISTING_CLUSTER_REGISTRATIONS=$(yq eval '.cluster_registration | length' egs-installer-config.yaml 2>/dev/null || echo "0")
    
    # For each new worker, add a cluster_registration entry
    for i in "${!WORKER_NAMES[@]}"; do
        WORKER_NAME="${WORKER_NAMES[$i]}"
        CLUSTER_REG_INDEX=$((EXISTING_CLUSTER_REGISTRATIONS + i))
        
        # Check if this cluster_registration entry already exists with this cluster_name
        EXISTING_REG_NAME=$(yq eval ".cluster_registration[] | select(.cluster_name == \"$WORKER_NAME\") | .cluster_name" egs-installer-config.yaml 2>/dev/null | head -1 | tr -d '"' | xargs)
        
        if [ -z "$EXISTING_REG_NAME" ]; then
            # Add new cluster_registration entry for this worker
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].cluster_name = \"$WORKER_NAME\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].project_name = \"$REGISTER_PROJECT_NAME\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].telemetry.enabled = true" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].telemetry.endpoint = \"$TELEMETRY_ENDPOINT\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].telemetry.telemetryProvider = \"$TELEMETRY_PROVIDER\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].geoLocation.cloudProvider = \"$CLOUD_PROVIDER\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$CLUSTER_REG_INDEX].geoLocation.cloudRegion = \"$CLOUD_REGION\"" -i egs-installer-config.yaml
            print_info "Added cluster_registration entry for: $WORKER_NAME"
        else
            print_info "Cluster registration for '$WORKER_NAME' already exists, preserving"
        fi
    done
else
    # Normal mode (single- or multi-cluster): ensure EVERY worker gets a cluster_registration entry.
    # Previously only cluster_registration[0] was updated, so workers 1,2,... in a multi-worker
    # install were never registered with the controller.
    REG_WORKER_NAMES=()
    if [ ${#WORKER_KUBECONFIG_RELATIVES[@]} -gt 0 ]; then
        # Multi-cluster: one registration per worker kubeconfig
        for i in "${!WORKER_KUBECONFIG_RELATIVES[@]}"; do
            if [ $i -lt ${#WORKER_NAMES[@]} ] && [ -n "${WORKER_NAMES[$i]}" ]; then
                REG_WORKER_NAMES+=("${WORKER_NAMES[$i]}")
            elif [ $i -eq 0 ] && [ -n "$CLUSTER_NAME" ] && [ "$CLUSTER_NAME" != "worker-1" ]; then
                REG_WORKER_NAMES+=("$CLUSTER_NAME")
            else
                REG_WORKER_NAMES+=("worker-$((i+1))")
            fi
        done
    else
        # Single-cluster: exactly one worker registration
        if [ ${#WORKER_NAMES[@]} -gt 0 ] && [ -n "${WORKER_NAMES[0]}" ]; then
            REG_WORKER_NAMES+=("${WORKER_NAMES[0]}")
        else
            REG_WORKER_NAMES+=("$CLUSTER_NAME")
        fi
    fi

    for i in "${!REG_WORKER_NAMES[@]}"; do
        REG_NAME="${REG_WORKER_NAMES[$i]}"
        if [ "$i" -eq 0 ]; then
            # Update the first (template) entry, preserving an explicitly-customized cluster_name.
            EXISTING_CLUSTER_NAME=$(yq eval ".cluster_registration[0].cluster_name // empty" egs-installer-config.yaml 2>/dev/null | tr -d '"' | tr -d "'" | xargs)
            if [ -n "$EXISTING_CLUSTER_NAME" ] && [ "$EXISTING_CLUSTER_NAME" != "null" ] && [ "$EXISTING_CLUSTER_NAME" != "empty" ] && [ "$EXISTING_CLUSTER_NAME" != "worker-1" ]; then
                print_info "Preserving existing cluster_registration[0].cluster_name: $EXISTING_CLUSTER_NAME"
            else
                yq eval ".cluster_registration[0].cluster_name = \"$REG_NAME\"" -i egs-installer-config.yaml
            fi
            yq eval ".cluster_registration[0].project_name = \"$PROJECT_NAME\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[0].geoLocation.cloudProvider = \"$CLOUD_PROVIDER\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[0].geoLocation.cloudRegion = \"$CLOUD_REGION\"" -i egs-installer-config.yaml
        else
            # Additional workers: clone the template entry [0], then override identity/geo fields.
            yq eval ".cluster_registration[$i] = .cluster_registration[0]" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$i].cluster_name = \"$REG_NAME\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$i].project_name = \"$PROJECT_NAME\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$i].geoLocation.cloudProvider = \"$CLOUD_PROVIDER\"" -i egs-installer-config.yaml
            yq eval ".cluster_registration[$i].geoLocation.cloudRegion = \"$CLOUD_REGION\"" -i egs-installer-config.yaml
            print_info "Added cluster_registration entry for worker: $REG_NAME"
        fi
    done
fi

# --- Bug fix: remove the shipped template placeholder "worker-1" (register-worker mode) ---
# The repo config ships a sample worker/registration named "worker-1". In register-worker
# mode this placeholder must never leak into a customer's generated config as a phantom
# worker or a spurious Cluster CR. Drop it from BOTH lists unless the user is explicitly
# registering a cluster literally named "worker-1".
if [ "$REGISTER_WORKER" = "true" ] && [ "$REGISTER_CLUSTER_NAME" != "worker-1" ]; then
    PLACEHOLDER_WORKERS=$(yq eval '[.kubeslice_worker_egs[] | select(.name == "worker-1")] | length' egs-installer-config.yaml 2>/dev/null || echo "0")
    if [ "$PLACEHOLDER_WORKERS" -gt 0 ]; then
        yq eval 'del(.kubeslice_worker_egs[] | select(.name == "worker-1"))' -i egs-installer-config.yaml
        print_info "Removed $PLACEHOLDER_WORKERS placeholder worker entry(ies) named 'worker-1'"
    fi
    PLACEHOLDER_REGS=$(yq eval '[.cluster_registration[] | select(.cluster_name == "worker-1")] | length' egs-installer-config.yaml 2>/dev/null || echo "0")
    if [ "$PLACEHOLDER_REGS" -gt 0 ]; then
        yq eval 'del(.cluster_registration[] | select(.cluster_name == "worker-1"))' -i egs-installer-config.yaml
        print_info "Removed $PLACEHOLDER_REGS placeholder cluster_registration entry(ies) named 'worker-1'"
    fi
fi

# --- Bug fix: controller-only install (--skip-worker, single cluster) must not register the
# controller's own cluster name as a worker cluster. Registering it creates a spurious
# Cluster CR that later leaks into other installs as a phantom worker (and clutters
# installation-files). Only applies when no worker kubeconfig was provided and we are not in
# register-worker mode (where registration of the new worker is intentional).
if [ "$SKIP_WORKER" = "true" ] && [ "$REGISTER_WORKER" != "true" ] && [ ${#WORKER_KUBECONFIGS[@]} -eq 0 ]; then
    yq eval '.enable_cluster_registration = false' -i egs-installer-config.yaml
    yq eval 'del(.cluster_registration[])' -i egs-installer-config.yaml
    print_info "Controller-only install (--skip-worker): disabled cluster registration (no worker cluster to register)"
fi

# Update image registry
yq eval ".kubeslice_controller_egs.inline_values.global.imageRegistry = \"$IMAGE_REGISTRY\"" -i egs-installer-config.yaml
yq eval ".kubeslice_ui_egs.inline_values.global.imageRegistry = \"$IMAGE_REGISTRY\"" -i egs-installer-config.yaml
# Update image registry for all workers
# This should merge with existing inline_values, not overwrite them
WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' egs-installer-config.yaml)
for ((i=0; i<WORKER_COUNT; i++)); do
    # Always update imageRegistry, yq should merge this with existing inline_values.global fields
    yq eval ".kubeslice_worker_egs[$i].inline_values.global.imageRegistry = \"$IMAGE_REGISTRY\"" -i egs-installer-config.yaml
done

# Override controller endpoint if provided (useful for Rancher or custom API server URLs)
if [ -n "$CONTROLLER_ENDPOINT" ]; then
    print_info "Overriding controller endpoint with: $CONTROLLER_ENDPOINT"
    yq eval ".kubeslice_controller_egs.inline_values.kubeslice.controller.endpoint = \"$CONTROLLER_ENDPOINT\"" -i egs-installer-config.yaml
    print_success "Controller endpoint set to: $CONTROLLER_ENDPOINT"
fi

# Override worker endpoints if provided (useful for Rancher or custom API server URLs)
if [ ${#WORKER_ENDPOINTS[@]} -gt 0 ]; then
    WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' egs-installer-config.yaml)
    for ((i=0; i<${#WORKER_ENDPOINTS[@]}; i++)); do
        if [ $i -lt $WORKER_COUNT ]; then
            print_info "Overriding worker[$i] endpoint with: ${WORKER_ENDPOINTS[$i]}"
            yq eval ".kubeslice_worker_egs[$i].worker_endpoint_override = \"${WORKER_ENDPOINTS[$i]}\"" -i egs-installer-config.yaml
            print_success "Worker[$i] endpoint set to: ${WORKER_ENDPOINTS[$i]}"
        else
            print_warning "Worker endpoint at index $i has no matching worker in config (only $WORKER_COUNT workers configured). Skipping."
        fi
    done
fi

# Override UI proxy service type if provided
if [ -n "$UI_SERVICE_TYPE" ]; then
    if [[ "$UI_SERVICE_TYPE" != "LoadBalancer" && "$UI_SERVICE_TYPE" != "NodePort" && "$UI_SERVICE_TYPE" != "ClusterIP" ]]; then
        print_error "Invalid --ui-service-type: $UI_SERVICE_TYPE. Must be LoadBalancer, NodePort, or ClusterIP"
        exit 1
    fi
    print_info "Setting UI proxy service type to: $UI_SERVICE_TYPE"
    yq eval ".kubeslice_ui_egs.inline_values.kubeslice.uiproxy.service.type = \"$UI_SERVICE_TYPE\"" -i egs-installer-config.yaml
    print_success "UI proxy service type set to: $UI_SERVICE_TYPE"
fi

# Update enable_custom_apps
yq eval ".enable_custom_apps = $ENABLE_CUSTOM_APPS" -i egs-installer-config.yaml

# ============================================================================
# MULTI-CLUSTER PREREQUISITES CONFIGURATION
# ============================================================================
# In multi-cluster mode, we need to:
# 1. Configure prerequisites for controller cluster (PostgreSQL, Prometheus, GPU Operator)
# 2. Add additional_apps entries for each worker cluster (Prometheus, GPU Operator)
# 3. Add manifests entries for each worker cluster (GPU operator quota, nvidia driver)
# 4. Add commands entries for each worker cluster
# ============================================================================

if [ "$MULTI_CLUSTER" = "true" ] && [ ${#WORKER_KUBECONFIG_RELATIVES[@]} -gt 0 ]; then
    print_info "🌐 Configuring multi-cluster prerequisites..."
    
    # Determine skip flags for controller and worker clusters
    # Logic:
    # - PostgreSQL: Only on controller, use --skip-postgresql
    # - Prometheus/GPU Operator: Use multi-cluster flags (--skip-controller-*, --skip-worker-*)
    # - Single-cluster flags (--skip-prometheus, --skip-gpu-operator) should NOT be used in multi-cluster mode
    #   but if used, they will be applied to controller only (with a warning)
    
    # Controller cluster: PostgreSQL - use global flag (PostgreSQL is only on controller)
    CONTROLLER_SKIP_POSTGRESQL="$SKIP_POSTGRESQL"
    
    # Controller cluster: Prometheus - use controller-specific flag
    # If single-cluster flag is used in multi-cluster mode, warn and apply to controller
    if [ "$SKIP_PROMETHEUS" = "true" ]; then
        print_warning "⚠️  --skip-prometheus used in multi-cluster mode. Use --skip-controller-prometheus and --skip-worker-prometheus instead."
        print_warning "⚠️  Applying --skip-prometheus to controller cluster only."
        CONTROLLER_SKIP_PROMETHEUS="true"
    else
        CONTROLLER_SKIP_PROMETHEUS="$SKIP_CONTROLLER_PROMETHEUS"
    fi
    
    # Controller cluster: GPU Operator - use controller-specific flag
    if [ "$SKIP_GPU_OPERATOR" = "true" ]; then
        print_warning "⚠️  --skip-gpu-operator used in multi-cluster mode. Use --skip-controller-gpu-operator and --skip-worker-gpu-operator instead."
        print_warning "⚠️  Applying --skip-gpu-operator to controller cluster only."
        CONTROLLER_SKIP_GPU_OPERATOR="true"
    else
        CONTROLLER_SKIP_GPU_OPERATOR="$SKIP_CONTROLLER_GPU_OPERATOR"
    fi
    
    # Worker clusters: Use worker-specific flags only
    WORKER_SKIP_PROMETHEUS="$SKIP_WORKER_PROMETHEUS"
    WORKER_SKIP_GPU_OPERATOR="$SKIP_WORKER_GPU_OPERATOR"
    
    # Update controller cluster prerequisites (index 0 in additional_apps for each type)
    # PostgreSQL is ONLY on controller cluster
    if [ "$CONTROLLER_SKIP_POSTGRESQL" = "true" ]; then
        yq eval '(.additional_apps[] | select(.name == "postgresql") | .skip_installation) = true' -i egs-installer-config.yaml
        print_warning "PostgreSQL installation will be skipped on controller cluster"
    fi
    
    # Update first prometheus entry (controller cluster)
    if [ "$CONTROLLER_SKIP_PROMETHEUS" = "true" ]; then
        # Skip the first prometheus entry (controller cluster)
        yq eval '(.additional_apps | to_entries | map(select(.value.name == "prometheus"))[0].key) as $idx | .additional_apps[$idx].skip_installation = true' -i egs-installer-config.yaml 2>/dev/null || \
        yq eval '(.additional_apps[] | select(.name == "prometheus") | .skip_installation) = true' -i egs-installer-config.yaml
        print_warning "Prometheus installation will be skipped on controller cluster"
    fi
    
    # Update first gpu-operator entry (controller cluster)
    if [ "$CONTROLLER_SKIP_GPU_OPERATOR" = "true" ]; then
        yq eval '(.additional_apps | to_entries | map(select(.value.name == "gpu-operator"))[0].key) as $idx | .additional_apps[$idx].skip_installation = true' -i egs-installer-config.yaml 2>/dev/null || \
        yq eval '(.additional_apps[] | select(.name == "gpu-operator") | .skip_installation) = true' -i egs-installer-config.yaml
        print_warning "GPU Operator installation will be skipped on controller cluster"
    fi
    
    # Get current counts for additional_apps, manifests, and commands
    CURRENT_ADDITIONAL_APPS_COUNT=$(yq eval '.additional_apps | length' egs-installer-config.yaml 2>/dev/null || echo "3")
    CURRENT_MANIFESTS_COUNT=$(yq eval '.manifests | length' egs-installer-config.yaml 2>/dev/null || echo "2")
    CURRENT_COMMANDS_COUNT=$(yq eval '.commands | length' egs-installer-config.yaml 2>/dev/null || echo "1")
    
    # Find template indices for gpu-operator and prometheus in additional_apps (from repo config)
    GPU_OP_TEMPLATE_IDX=$(yq eval '.additional_apps | to_entries | map(select(.value.name == "gpu-operator"))[0].key // 0' egs-installer-config.yaml 2>/dev/null || echo "0")
    PROM_TEMPLATE_IDX=$(yq eval '.additional_apps | to_entries | map(select(.value.name == "prometheus"))[0].key // 1' egs-installer-config.yaml 2>/dev/null || echo "1")
    
    # Find template indices for manifests (gpu-operator-quota and nvidia-driver-installer)
    GPU_QUOTA_TEMPLATE_IDX=$(yq eval '.manifests | to_entries | map(select(.value.appname == "gpu-operator-quota"))[0].key // 0' egs-installer-config.yaml 2>/dev/null || echo "0")
    NVIDIA_DRIVER_TEMPLATE_IDX=$(yq eval '.manifests | to_entries | map(select(.value.appname == "nvidia-driver-installer"))[0].key // 1' egs-installer-config.yaml 2>/dev/null || echo "1")
    
    # Find template index for commands (first one)
    CMD_TEMPLATE_IDX="0"
    
    # Add additional_apps, manifests, and commands for each worker cluster
    for i in "${!WORKER_KUBECONFIG_RELATIVES[@]}"; do
        WORKER_KUBECONFIG_RELATIVE="${WORKER_KUBECONFIG_RELATIVES[$i]}"
        WORKER_CTX="${WORKER_CONTEXTS_DETECTED[$i]}"
        
        # Determine worker name
        if [ $i -lt ${#WORKER_NAMES[@]} ] && [ -n "${WORKER_NAMES[$i]}" ]; then
            WORKER_NAME="${WORKER_NAMES[$i]}"
        else
            WORKER_NAME="worker-$((i+1))"
        fi
        
        print_info "Adding prerequisites for worker cluster: $WORKER_NAME"
        
        # ===== ADD GPU-OPERATOR FOR WORKER (copy from template) =====
        GPU_OP_INDEX=$((CURRENT_ADDITIONAL_APPS_COUNT + i * 2))
        
        # Copy the gpu-operator template entry to the new index
        yq eval ".additional_apps[$GPU_OP_INDEX] = .additional_apps[$GPU_OP_TEMPLATE_IDX]" -i egs-installer-config.yaml
        # Update only the kubeconfig-related fields
        yq eval ".additional_apps[$GPU_OP_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
        yq eval ".additional_apps[$GPU_OP_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
        yq eval ".additional_apps[$GPU_OP_INDEX].kubecontext = \"$WORKER_CTX\"" -i egs-installer-config.yaml
        yq eval ".additional_apps[$GPU_OP_INDEX].skip_installation = $WORKER_SKIP_GPU_OPERATOR" -i egs-installer-config.yaml
        
        if [ "$WORKER_SKIP_GPU_OPERATOR" = "true" ]; then
            print_warning "GPU Operator will be skipped on worker: $WORKER_NAME"
        else
            print_success "Added GPU Operator for worker: $WORKER_NAME (copied from template)"
        fi
        
        # ===== ADD PROMETHEUS FOR WORKER (copy from template) =====
        PROM_INDEX=$((CURRENT_ADDITIONAL_APPS_COUNT + i * 2 + 1))
        
        # Copy the prometheus template entry to the new index
        yq eval ".additional_apps[$PROM_INDEX] = .additional_apps[$PROM_TEMPLATE_IDX]" -i egs-installer-config.yaml
        # Update only the kubeconfig-related fields
        yq eval ".additional_apps[$PROM_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
        yq eval ".additional_apps[$PROM_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
        yq eval ".additional_apps[$PROM_INDEX].kubecontext = \"$WORKER_CTX\"" -i egs-installer-config.yaml
        yq eval ".additional_apps[$PROM_INDEX].skip_installation = $WORKER_SKIP_PROMETHEUS" -i egs-installer-config.yaml
        
        if [ "$WORKER_SKIP_PROMETHEUS" = "true" ]; then
            print_warning "Prometheus will be skipped on worker: $WORKER_NAME"
        else
            print_success "Added Prometheus for worker: $WORKER_NAME (copied from template)"
        fi
        
        # ===== ADD MANIFESTS FOR WORKER (GPU Operator Quota - copy from template) =====
        MANIFEST_INDEX=$((CURRENT_MANIFESTS_COUNT + i * 2))
        
        # Copy the gpu-operator-quota template entry to the new index
        yq eval ".manifests[$MANIFEST_INDEX] = .manifests[$GPU_QUOTA_TEMPLATE_IDX]" -i egs-installer-config.yaml
        # Update only the kubeconfig-related fields
        yq eval ".manifests[$MANIFEST_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
        yq eval ".manifests[$MANIFEST_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
        yq eval ".manifests[$MANIFEST_INDEX].kubecontext = \"$WORKER_CTX\"" -i egs-installer-config.yaml
        yq eval ".manifests[$MANIFEST_INDEX].skip_installation = $WORKER_SKIP_GPU_OPERATOR" -i egs-installer-config.yaml
        
        # ===== ADD MANIFESTS FOR WORKER (NVIDIA Driver Installer - copy from template) =====
        NVIDIA_MANIFEST_INDEX=$((CURRENT_MANIFESTS_COUNT + i * 2 + 1))
        
        # Copy the nvidia-driver-installer template entry to the new index
        yq eval ".manifests[$NVIDIA_MANIFEST_INDEX] = .manifests[$NVIDIA_DRIVER_TEMPLATE_IDX]" -i egs-installer-config.yaml
        # Update only the kubeconfig-related fields
        yq eval ".manifests[$NVIDIA_MANIFEST_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
        yq eval ".manifests[$NVIDIA_MANIFEST_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
        yq eval ".manifests[$NVIDIA_MANIFEST_INDEX].kubecontext = \"$WORKER_CTX\"" -i egs-installer-config.yaml
        
        print_success "Added manifests for worker: $WORKER_NAME (copied from template)"
        
        # ===== ADD COMMANDS FOR WORKER (copy from template) =====
        CMD_INDEX=$((CURRENT_COMMANDS_COUNT + i))
        
        # Copy the commands template entry to the new index
        yq eval ".commands[$CMD_INDEX] = .commands[$CMD_TEMPLATE_IDX]" -i egs-installer-config.yaml
        # Update only the kubeconfig-related fields
        yq eval ".commands[$CMD_INDEX].use_global_kubeconfig = false" -i egs-installer-config.yaml
        yq eval ".commands[$CMD_INDEX].kubeconfig = \"$WORKER_KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
        yq eval ".commands[$CMD_INDEX].kubecontext = \"$WORKER_CTX\"" -i egs-installer-config.yaml
        
        print_success "Added commands for worker: $WORKER_NAME (copied from template)"
    done
    
    print_success "Multi-cluster prerequisites configured for ${#WORKER_KUBECONFIG_RELATIVES[@]} worker cluster(s)"
    echo ""
else
    # Single-cluster mode: Use simple skip flags
    # Update skip flags for additional apps (PostgreSQL, Prometheus, GPU Operator)
    # These are installed via egs-install-prerequisites.sh
    if [ "$SKIP_POSTGRESQL" = "true" ]; then
        yq eval '(.additional_apps[] | select(.name == "postgresql") | .skip_installation) = true' -i egs-installer-config.yaml
        print_warning "PostgreSQL installation will be skipped"
    fi

    if [ "$SKIP_PROMETHEUS" = "true" ]; then
        yq eval '(.additional_apps[] | select(.name == "prometheus") | .skip_installation) = true' -i egs-installer-config.yaml
        print_warning "Prometheus installation will be skipped"
    fi

    if [ "$SKIP_GPU_OPERATOR" = "true" ]; then
        yq eval '(.additional_apps[] | select(.name == "gpu-operator") | .skip_installation) = true' -i egs-installer-config.yaml
        print_warning "GPU Operator installation will be skipped"
    fi
fi

# Update skip flags for EGS components (Controller, UI, Worker)
# These are installed via egs-installer.sh
if [ "$SKIP_CONTROLLER" = "true" ]; then
    yq eval ".kubeslice_controller_egs.skip_installation = true" -i egs-installer-config.yaml
    yq eval ".enable_install_controller = false" -i egs-installer-config.yaml
    print_warning "EGS Controller installation will be skipped"
fi

if [ "$SKIP_UI" = "true" ]; then
    yq eval ".kubeslice_ui_egs.skip_installation = true" -i egs-installer-config.yaml
    yq eval ".enable_install_ui = false" -i egs-installer-config.yaml
    print_warning "EGS UI installation will be skipped"
fi

if [ "$SKIP_WORKER" = "true" ]; then
    # Set skip_installation for all workers
    # BUT in register-worker mode, preserved workers already have skip_installation=true
    # So only update workers that don't already have skip_installation=true
    WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' egs-installer-config.yaml)
    for ((i=0; i<WORKER_COUNT; i++)); do
        # Check if this worker already has skip_installation=true (preserved worker)
        CURRENT_SKIP=$(yq eval ".kubeslice_worker_egs[$i].skip_installation" egs-installer-config.yaml 2>/dev/null)
        if [ "$CURRENT_SKIP" != "true" ]; then
            # Only update if not already true
            yq eval ".kubeslice_worker_egs[$i].skip_installation = true" -i egs-installer-config.yaml
        fi
    done
    yq eval ".enable_install_worker = false" -i egs-installer-config.yaml
    print_warning "EGS Worker installation will be skipped for all workers"
fi

# In register-worker mode, ensure all EXISTING workers (not the new one) have skip_installation=true
# This should run regardless of SKIP_WORKER flag to ensure existing workers aren't reinstalled
if [ "$REGISTER_WORKER" = "true" ]; then
    # Get total worker count
    TOTAL_WORKER_COUNT=$(yq eval '.kubeslice_worker_egs | length' egs-installer-config.yaml 2>/dev/null || echo "0")
    
    if [ "$TOTAL_WORKER_COUNT" -gt 0 ]; then
        # The last worker is the newly registered worker
        # All others are existing workers that should be skipped
        NEW_WORKER_INDEX=$((TOTAL_WORKER_COUNT - 1))
        print_info "Register-worker mode: Ensuring existing workers have skip_installation=true, new worker respects --skip-worker flag"
        
        for ((i=0; i<TOTAL_WORKER_COUNT; i++)); do
            WORKER_NAME=$(yq eval ".kubeslice_worker_egs[$i].name" egs-installer-config.yaml 2>/dev/null)
            if [ "$i" -lt "$NEW_WORKER_INDEX" ]; then
                # This is an existing worker - always skip
                CURRENT_SKIP=$(yq eval ".kubeslice_worker_egs[$i].skip_installation" egs-installer-config.yaml 2>/dev/null)
                if [ "$CURRENT_SKIP" != "true" ]; then
                    yq eval ".kubeslice_worker_egs[$i].skip_installation = true" -i egs-installer-config.yaml
                    print_info "✅ Set skip_installation=true for existing worker: $WORKER_NAME"
                else
                    print_info "✅ Worker $WORKER_NAME already has skip_installation=true"
                fi
            elif [ "$i" -eq "$NEW_WORKER_INDEX" ]; then
                # This is the newly registered worker - respect SKIP_WORKER flag
                if [ "$SKIP_WORKER" = "true" ]; then
                    yq eval ".kubeslice_worker_egs[$i].skip_installation = true" -i egs-installer-config.yaml
                    print_info "✅ New worker $WORKER_NAME: skip_installation=true (--skip-worker flag provided)"
                else
                    yq eval ".kubeslice_worker_egs[$i].skip_installation = false" -i egs-installer-config.yaml
                    print_info "✅ New worker $WORKER_NAME: skip_installation=false (will be installed)"
                fi
            fi
        done
    fi
fi

fi  # end: if [ "$CONFIG_PRESERVED" != "true" ] (config generation block 2)

if [ "$CONFIG_PRESERVED" = "true" ]; then
    print_success "Using preserved configuration: $ORIGINAL_DIR/egs-installer-config.yaml"
else
    print_success "Configuration updated successfully!"
fi
echo ""

# Copy license file to current directory if needed (only if license is required)
if [ "$NEEDS_LICENSE" = "true" ]; then
    LICENSE_BASENAME=$(basename "$LICENSE_FILE")
    if [ "$LICENSE_FILE" != "$ORIGINAL_DIR/$LICENSE_BASENAME" ]; then
        if ! cp "$LICENSE_FILE" "$ORIGINAL_DIR/$LICENSE_BASENAME"; then
            print_error "Failed to copy license file to current directory"
            exit 1
        fi
        LICENSE_FILE="$ORIGINAL_DIR/$LICENSE_BASENAME"
        print_success "Copied license file to current directory"
    fi
fi

# Show configuration summary
print_info "📁 Configuration saved to: $ORIGINAL_DIR/egs-installer-config.yaml"
echo ""

# --generate-config / --dry-run: stop here so the user can inspect the generated config
# before any cluster-mutating actions (license apply / prerequisites / components).
if [ "$GENERATE_CONFIG_ONLY" = "true" ]; then
    INSTALL_COMPLETE="true"
    print_success "Config generation complete (--generate-config / --dry-run)."
    print_info "Review the generated config:   cat $ORIGINAL_DIR/egs-installer-config.yaml"
    print_info "When ready, run the same command WITHOUT --generate-config,"
    print_info "or run directly with the existing config:"
    print_info "  ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml"
    print_info "  ./egs-installer.sh --input-yaml egs-installer-config.yaml"
    exit 0
fi

print_info "🚀 Starting automated installation..."
echo ""

# Step 1: Apply EGS license (only if Controller is being installed)
if [ "$NEEDS_LICENSE" = "true" ]; then
    print_info "📜 Step 1/3: Applying EGS license..."
    print_success "Using license file: $LICENSE_FILE"
    print_info "Applying EGS license..."
    echo ""

    # Determine which kubeconfig and context to use for license application
    if [ "$MULTI_CLUSTER" = "true" ] && [ -n "$CONTROLLER_KUBECONFIG" ]; then
        # Multi-cluster mode: Use controller kubeconfig
        LICENSE_KUBECONFIG_ARG="--kubeconfig $CONTROLLER_KUBECONFIG"
        if [ -n "$CONTROLLER_CONTEXT" ]; then
            LICENSE_CONTEXT_ARG="--context $CONTROLLER_CONTEXT"
        else
            LICENSE_CONTEXT_ARG=""
        fi
        print_info "Using controller kubeconfig for license application (multi-cluster mode)"
    else
        # Single-cluster mode: Use current KUBECONFIG
        LICENSE_KUBECONFIG_ARG=""
        LICENSE_CONTEXT_ARG=""
    fi

    # Create namespace if it doesn't exist
    if [ -n "$LICENSE_KUBECONFIG_ARG" ]; then
        kubectl $LICENSE_KUBECONFIG_ARG $LICENSE_CONTEXT_ARG create namespace kubeslice-controller --dry-run=client -o yaml | kubectl $LICENSE_KUBECONFIG_ARG $LICENSE_CONTEXT_ARG apply -f - 2>/dev/null || true
    else
        kubectl create namespace kubeslice-controller --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
    fi

    # Apply license
    if [ -n "$LICENSE_KUBECONFIG_ARG" ]; then
        if kubectl $LICENSE_KUBECONFIG_ARG $LICENSE_CONTEXT_ARG apply -f "$LICENSE_FILE" -n kubeslice-controller; then
            print_success "License applied successfully to controller cluster!"
            echo ""
        else
            print_warning "License application failed or already exists. Continuing..."
            echo ""
        fi
    else
        if kubectl apply -f "$LICENSE_FILE" -n kubeslice-controller; then
            print_success "License applied successfully!"
            echo ""
        else
            print_warning "License application failed or already exists. Continuing..."
            echo ""
        fi
    fi
else
    print_info "📜 Step 1/3: Skipping license application (Controller is not being installed)"
    echo ""
fi

# Step 1: Install prerequisites (PostgreSQL, Prometheus, GPU Operator)
# Only run if at least one is not skipped
# Check both single-cluster flags and multi-cluster flags
SHOULD_INSTALL_PREREQS="false"
if [ "$MULTI_CLUSTER" = "true" ]; then
    # Multi-cluster mode: Check controller and worker specific flags
    if [ "$SKIP_POSTGRESQL" = "false" ] || \
       [ "$SKIP_CONTROLLER_PROMETHEUS" = "false" ] || [ "$SKIP_CONTROLLER_GPU_OPERATOR" = "false" ] || \
       [ "$SKIP_WORKER_PROMETHEUS" = "false" ] || [ "$SKIP_WORKER_GPU_OPERATOR" = "false" ]; then
        SHOULD_INSTALL_PREREQS="true"
    fi
else
    # Single-cluster mode: Check simple flags
    if [ "$SKIP_POSTGRESQL" = "false" ] || [ "$SKIP_PROMETHEUS" = "false" ] || [ "$SKIP_GPU_OPERATOR" = "false" ]; then
        SHOULD_INSTALL_PREREQS="true"
    fi
fi

if [ "$SHOULD_INSTALL_PREREQS" = "true" ]; then
    print_info "📦 Step 2/3: Installing prerequisites (PostgreSQL, Prometheus, GPU Operator)..."
    echo ""
    # Ensure KUBECONFIG is exported for the prerequisites script
    if [ -n "$KUBECONFIG" ]; then
        export KUBECONFIG
        print_info "Using KUBECONFIG: $KUBECONFIG"
    fi
    if ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml; then
        print_success "Prerequisites installed successfully!"
        echo ""
    else
        print_error "Prerequisites installation failed!"
        exit 1
    fi
else
    print_info "📦 Step 2/3: Skipping prerequisites (all skipped)"
    echo ""
fi

# Step 2: Install EGS components (Controller, UI, Worker)
# Dependency checks (relaxed for multi-cluster mode)
# Note: Do dependency checks BEFORE calling egs-installer.sh to show warnings early
if [ "$MULTI_CLUSTER" = "false" ] && [ "$SKIP_DEPENDENCY_CHECK" = "true" ]; then
    print_warning "⚠️  --skip-dependency-check: bypassing PostgreSQL/Controller/UI prerequisite detection."
elif [ "$MULTI_CLUSTER" = "false" ]; then
    # Single-cluster mode: Strict dependency checks
    # Check if Controller is being installed without PostgreSQL (not allowed)
    # But first check if PostgreSQL is already installed in the cluster
    if [ "$SKIP_CONTROLLER" = "false" ] && [ "$SKIP_POSTGRESQL" = "true" ]; then
        if ! component_present "postgres"; then
            print_error "❌ ERROR: Controller installation requires PostgreSQL to be installed."
            print_error "PostgreSQL was not detected (checked helm releases and deployments/statefulsets)."
            print_error "Options: install PostgreSQL first, use --skip-controller, or — if PostgreSQL is"
            print_error "running under a non-standard name — re-run with --skip-dependency-check."
            exit 1
        else
            print_info "ℹ️  PostgreSQL detected in the cluster. Proceeding with Controller installation."
        fi
    fi
    
    # Check if Worker is being installed without Controller (not allowed)
    # But first check if Controller is already installed (for upgrade scenarios)
    if [ "$SKIP_WORKER" = "false" ] && [ "$SKIP_CONTROLLER" = "true" ]; then
        if ! component_present "egs-controller|kubeslice-controller"; then
            print_error "❌ ERROR: Worker installation requires Controller to be installed."
            print_error "Controller was not detected (checked helm releases and deployments/statefulsets)."
            print_error "Options: install Controller first, use --skip-worker, or re-run with --skip-dependency-check."
            exit 1
        else
            print_info "ℹ️  Controller detected in the cluster. Proceeding with Worker installation/upgrade."
        fi
    fi
    
    # Check if Worker is being installed without UI (not allowed)
    # But first check if UI is already installed (for upgrade scenarios)
    if [ "$SKIP_WORKER" = "false" ] && [ "$SKIP_UI" = "true" ]; then
        if ! component_present "egs-ui|kubeslice-ui"; then
            print_error "❌ ERROR: Worker installation requires UI to be installed."
            print_error "UI was not detected (checked helm releases and deployments/statefulsets)."
            print_error "Options: install UI first, use --skip-worker, or re-run with --skip-dependency-check."
            exit 1
        else
            print_info "ℹ️  UI detected in the cluster. Proceeding with Worker installation/upgrade."
        fi
    fi
else
    # Multi-cluster mode: Relaxed dependency checks (components can be in different clusters)
    # In multi-cluster mode, it's expected that components may be in different clusters
    # Only warn about PostgreSQL for Controller (as it's a hard requirement)
    print_info "ℹ️  Multi-cluster mode: Dependency checks relaxed (components may be in different clusters)"
    if [ "$SKIP_CONTROLLER" = "false" ] && [ "$SKIP_POSTGRESQL" = "true" ]; then
        print_warning "⚠️  Controller installation without PostgreSQL in multi-cluster mode."
        print_warning "⚠️  Ensure PostgreSQL is installed in the controller cluster or use --skip-controller"
    fi
    # No warnings for Worker without Controller/UI - this is expected in multi-cluster mode
fi

# Only run if at least one is not skipped
if [ "$SKIP_CONTROLLER" = "false" ] || [ "$SKIP_UI" = "false" ] || [ "$SKIP_WORKER" = "false" ]; then
    print_info "📦 Step 3/3: Installing EGS components (Controller, UI, Worker)..."
    echo ""
    if ./egs-installer.sh --input-yaml egs-installer-config.yaml; then
        INSTALL_COMPLETE="true"
        print_success "✅ EGS installation completed successfully!"
        echo ""
        print_info "📁 Installation files are in: $ORIGINAL_DIR"
        print_info "📋 Configuration file: $ORIGINAL_DIR/egs-installer-config.yaml"
        exit 0
    else
        print_error "EGS installation failed!"
        exit 1
    fi
else
    INSTALL_COMPLETE="true"
    print_info "📦 Step 3/3: Skipping EGS components (all skipped)"
    echo ""
    print_success "✅ Installation completed (all components skipped)"
    exit 0
fi
