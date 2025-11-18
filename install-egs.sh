#!/bin/bash

# EGS Quick Installer
# One-command installation for single-cluster EGS
# Usage: 
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --license-file egs-license.yaml
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --skip-postgresql --skip-gpu-operator

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
SKIP_POSTGRESQL="false"
SKIP_PROMETHEUS="false"
SKIP_GPU_OPERATOR="false"
SKIP_CONTROLLER="false"
SKIP_UI="false"
SKIP_WORKER="false"

# Worker registration mode
REGISTER_WORKER="false"
CONTROLLER_KUBECONFIG=""
CONTROLLER_CONTEXT=""
WORKER_KUBECONFIG=""
WORKER_CONTEXT=""
REGISTER_CLUSTER_NAME=""
REGISTER_PROJECT_NAME=""
TELEMETRY_ENABLED="true"
TELEMETRY_ENDPOINT=""
TELEMETRY_PROVIDER="prometheus"
CLOUD_PROVIDER=""
CLOUD_REGION=""
CONTROLLER_NAMESPACE="kubeslice-controller"

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
    print_info "Next steps:"
    print_info "1. Install EGS Worker on the worker cluster:"
    print_info "   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\"
    print_info "     --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui"
    print_info "2. Ensure the worker cluster can reach the controller cluster"
    print_info "3. Verify cluster status in the controller:"
    print_info "   kubectl --kubeconfig $CONTROLLER_KUBECONFIG get cluster.controller.kubeslice.io -n $PROJECT_NAMESPACE"
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
  --kubeconfig PATH          Path to kubeconfig file (default: auto-detect)
  --context NAME             Kubernetes context to use (default: current-context)
  --cluster-name NAME        Cluster name (default: worker-1)
  --skip-postgresql          Skip PostgreSQL installation
  --skip-prometheus          Skip Prometheus installation
  --skip-gpu-operator        Skip GPU Operator installation
  --skip-controller          Skip EGS Controller installation
  --skip-ui                  Skip EGS UI installation
  --skip-worker              Skip EGS Worker installation
  --help, -h                 Show this help message

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

Notes:
  - License file defaults to 'egs-license.yaml' in current directory if not specified
  - All components are installed by default unless explicitly skipped
  - Installation order: License → Prerequisites → Controller → UI → Worker
  - Takes 10-15 minutes for complete installation
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
            WORKER_KUBECONFIG="$2"
            shift 2
            ;;
        --worker-context)
            WORKER_CONTEXT="$2"
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

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "git is not installed. Please install git first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# If --register-worker is set, run registration and exit (skip normal installation flow)
if [ "$REGISTER_WORKER" = "true" ]; then
    register_worker_cluster
    exit 0
fi

# Set kubeconfig if provided
if [ -n "$KUBECONFIG_PATH" ]; then
    export KUBECONFIG="$KUBECONFIG_PATH"
    print_info "Set KUBECONFIG to: $KUBECONFIG_PATH"
fi

# Set context if provided
if [ -n "$KUBE_CONTEXT" ]; then
    print_info "Switching to context: $KUBE_CONTEXT"
    kubectl config use-context "$KUBE_CONTEXT" &>/dev/null || {
        print_error "Failed to switch to context: $KUBE_CONTEXT"
        exit 1
    }
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

# Save original directory (where user ran curl from)
ORIGINAL_DIR="$(pwd)"

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

# Clone repository internally
print_info "Downloading EGS installer..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if ! git clone --depth 1 --branch "$EGS_BRANCH" "$EGS_REPO" egs-installation 2>/dev/null; then
    print_error "Failed to download EGS installer from branch: $EGS_BRANCH"
    print_info "Trying main branch..."
    EGS_BRANCH="main"
    if ! git clone --depth 1 --branch "$EGS_BRANCH" "$EGS_REPO" egs-installation; then
        print_error "Failed to download EGS installer"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

print_success "Downloaded EGS installer"

# Copy necessary files to original directory
print_info "Setting up installation in current directory..."
cp -r "$TEMP_DIR/egs-installation/charts" "$ORIGINAL_DIR/" 2>/dev/null || {
    print_error "Failed to copy charts directory"
    rm -rf "$TEMP_DIR"
    exit 1
}
cp "$TEMP_DIR/egs-installation/egs-installer.sh" "$ORIGINAL_DIR/"
cp "$TEMP_DIR/egs-installation/egs-install-prerequisites.sh" "$ORIGINAL_DIR/"
cp "$TEMP_DIR/egs-installation/egs-uninstall.sh" "$ORIGINAL_DIR/" 2>/dev/null || true

# Use egs-installer-config.yaml from repo as source of truth
if [ ! -f "$TEMP_DIR/egs-installation/egs-installer-config.yaml" ]; then
    print_error "egs-installer-config.yaml not found in repository"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Copy base config from repo
cp "$TEMP_DIR/egs-installation/egs-installer-config.yaml" "$ORIGINAL_DIR/egs-installer-config.yaml"

# Cleanup temp directory
rm -rf "$TEMP_DIR"
print_success "Setup complete in: $ORIGINAL_DIR"

# Change to original directory
cd "$ORIGINAL_DIR"

# Make scripts executable
chmod +x egs-installer.sh egs-install-prerequisites.sh 2>/dev/null || true

# Check if yq is installed (required for config updates)
if ! command -v yq &> /dev/null; then
    print_error "yq is not installed. Please install yq (v4.44.2+) first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install jq (v1.6+) first."
    exit 1
fi

# Detect GPU nodes and cloud provider
print_info "Detecting cluster capabilities..."
GPU_NODES=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' 2>/dev/null | wc -l || echo "0")
if [ "$GPU_NODES" -gt 0 ]; then
    print_success "Detected $GPU_NODES GPU node(s)"
    ENABLE_CUSTOM_APPS="true"
else
    print_warning "No GPU nodes detected."
    ENABLE_CUSTOM_APPS="false"
    # Don't automatically skip GPU Operator - let user decide via --skip-gpu-operator flag
fi

# Detect cloud provider
CLOUD_PROVIDER_DETECTED=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | cut -d: -f1 || echo "")

# Set cloud provider in config (exclude Linode - keep it empty for Linode clusters)
if [ "$CLOUD_PROVIDER_DETECTED" = "linode" ]; then
    CLOUD_PROVIDER=""  # Keep empty for Linode
    print_success "Detected cloud provider: linode (will be left empty in config)"
elif [ -n "$CLOUD_PROVIDER_DETECTED" ]; then
    CLOUD_PROVIDER="$CLOUD_PROVIDER_DETECTED"
    print_success "Detected cloud provider: $CLOUD_PROVIDER"
else
    CLOUD_PROVIDER=""
fi

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
    # Fallback
    KUBECONFIG_RELATIVE="kubeconfig"
fi

# Update egs-installer-config.yaml with detected values
print_info "Updating EGS configuration..."

# Update kubeconfig and context
yq eval ".global_kubeconfig = \"$KUBECONFIG_RELATIVE\"" -i egs-installer-config.yaml
yq eval ".global_kubecontext = \"$CURRENT_CONTEXT\"" -i egs-installer-config.yaml

# Update cluster name
yq eval ".kubeslice_worker_egs[0].name = \"$CLUSTER_NAME\"" -i egs-installer-config.yaml
yq eval ".cluster_registration[0].cluster_name = \"$CLUSTER_NAME\"" -i egs-installer-config.yaml

# Update cloud provider
yq eval ".cluster_registration[0].geoLocation.cloudProvider = \"$CLOUD_PROVIDER\"" -i egs-installer-config.yaml

# Update image registry
yq eval ".kubeslice_controller_egs.inline_values.global.imageRegistry = \"$IMAGE_REGISTRY\"" -i egs-installer-config.yaml
yq eval ".kubeslice_ui_egs.inline_values.global.imageRegistry = \"$IMAGE_REGISTRY\"" -i egs-installer-config.yaml
yq eval ".kubeslice_worker_egs[0].inline_values.global.imageRegistry = \"$IMAGE_REGISTRY\"" -i egs-installer-config.yaml

# Update enable_custom_apps
yq eval ".enable_custom_apps = $ENABLE_CUSTOM_APPS" -i egs-installer-config.yaml

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
    yq eval ".kubeslice_worker_egs[0].skip_installation = true" -i egs-installer-config.yaml
    yq eval ".enable_install_worker = false" -i egs-installer-config.yaml
    print_warning "EGS Worker installation will be skipped"
fi

print_success "Configuration updated successfully!"
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
print_info "🚀 Starting automated installation..."
echo ""

# Step 0: Apply EGS license (only if Controller is being installed)
if [ "$NEEDS_LICENSE" = "true" ]; then
    print_info "📜 Step 0/3: Applying EGS license..."
    print_success "Using license file: $LICENSE_FILE"
    print_info "Applying EGS license..."
    echo ""

    # Create namespace if it doesn't exist
    kubectl create namespace kubeslice-controller --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

    if kubectl apply -f "$LICENSE_FILE" -n kubeslice-controller; then
        print_success "License applied successfully!"
        echo ""
    else
        print_warning "License application failed or already exists. Continuing..."
        echo ""
    fi
else
    print_info "📜 Step 0/3: Skipping license application (Controller is not being installed)"
    echo ""
fi

# Step 1: Install prerequisites (PostgreSQL, Prometheus, GPU Operator)
# Only run if at least one is not skipped
if [ "$SKIP_POSTGRESQL" = "false" ] || [ "$SKIP_PROMETHEUS" = "false" ] || [ "$SKIP_GPU_OPERATOR" = "false" ]; then
    print_info "📦 Step 1/3: Installing prerequisites (PostgreSQL, Prometheus, GPU Operator)..."
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
    print_info "📦 Step 1/3: Skipping prerequisites (all skipped)"
    echo ""
fi

# Step 2: Install EGS components (Controller, UI, Worker)
# Check if Controller is being installed without PostgreSQL (not allowed)
# But first check if PostgreSQL is already installed in the cluster
if [ "$SKIP_CONTROLLER" = "false" ] && [ "$SKIP_POSTGRESQL" = "true" ]; then
    # Check if PostgreSQL is already installed
    POSTGRESQL_INSTALLED=$(helm list -A --kubeconfig "$KUBECONFIG" --kube-context "$CURRENT_CONTEXT" 2>/dev/null | grep -E "postgresql|kt-postgresql" | wc -l || echo "0")
    if [ "$POSTGRESQL_INSTALLED" -eq 0 ]; then
        print_error "❌ ERROR: Controller installation requires PostgreSQL to be installed."
        print_error "Please install PostgreSQL first, or use --skip-controller to skip Controller installation."
        print_error "Controller needs PostgreSQL for its database."
        exit 1
    else
        print_info "ℹ️  PostgreSQL is already installed in the cluster. Proceeding with Controller installation."
    fi
fi

# Check if Worker is being installed without Controller (not allowed)
# But first check if Controller is already installed (for upgrade scenarios)
if [ "$SKIP_WORKER" = "false" ] && [ "$SKIP_CONTROLLER" = "true" ]; then
    # Check if Controller is already installed
    CONTROLLER_INSTALLED=$(helm list -A --kubeconfig "$KUBECONFIG" --kube-context "$CURRENT_CONTEXT" 2>/dev/null | grep -E "egs-controller|kubeslice-controller" | wc -l || echo "0")
    if [ "$CONTROLLER_INSTALLED" -eq 0 ]; then
        print_error "❌ ERROR: Worker installation requires Controller to be installed."
        print_error "Please install Controller first, or use --skip-worker to skip Worker installation."
        print_error "Worker needs Controller CRDs and project registration to function."
        exit 1
    else
        print_info "ℹ️  Controller is already installed in the cluster. Proceeding with Worker installation/upgrade."
    fi
fi

# Check if Worker is being installed without UI (not allowed)
# But first check if UI is already installed (for upgrade scenarios)
if [ "$SKIP_WORKER" = "false" ] && [ "$SKIP_UI" = "true" ]; then
    # Check if UI is already installed
    UI_INSTALLED=$(helm list -A --kubeconfig "$KUBECONFIG" --kube-context "$CURRENT_CONTEXT" 2>/dev/null | grep -E "egs-ui|kubeslice-ui" | wc -l || echo "0")
    if [ "$UI_INSTALLED" -eq 0 ]; then
        print_error "❌ ERROR: Worker installation requires UI to be installed."
        print_error "Please install UI first, or use --skip-worker to skip Worker installation."
        print_error "Worker needs UI API gateway endpoint for egs-agent to function."
        exit 1
    else
        print_info "ℹ️  UI is already installed in the cluster. Proceeding with Worker installation/upgrade."
    fi
fi

# Only run if at least one is not skipped
if [ "$SKIP_CONTROLLER" = "false" ] || [ "$SKIP_UI" = "false" ] || [ "$SKIP_WORKER" = "false" ]; then
    print_info "📦 Step 2/3: Installing EGS components (Controller, UI, Worker)..."
    echo ""
    if ./egs-installer.sh --input-yaml egs-installer-config.yaml; then
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
    print_info "📦 Step 2/3: Skipping EGS components (all skipped)"
    echo ""
    print_success "✅ Installation completed (all components skipped)"
    exit 0
fi
