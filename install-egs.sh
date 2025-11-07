#!/bin/bash

# EGS Quick Installer (Curl-Friendly)
# One-command installation for single-cluster EGS
# Auto-installs: PostgreSQL, Prometheus, GPU Operator, Controller, UI, Worker
# Usage:
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --license-file /path/to/license.yaml
#   curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --skip-postgresql --skip-prometheus

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
EGS_VERSION=""
PROJECT_NAME="avesha"  # Fixed project name
CLUSTER_NAME="worker-1"  # Default cluster name matching egs-installer-config.yaml
IMAGE_REGISTRY="harbor.saas1.smart-scaler.io/avesha/aveshasystems"
LICENSE_FILE=""  # Path to license file (optional, defaults to egs-license.yaml in current directory)
INSTALL_PROMETHEUS="true"
INSTALL_GPU_OPERATOR="true"
INSTALL_POSTGRESQL="true"
INSTALL_CONTROLLER="true"
INSTALL_UI="true"
INSTALL_WORKER="true"

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

# Function to show help
show_help() {
    cat << EOF
EGS Quick Installer

Auto-generates config and installs EGS with one command

Usage:
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- [OPTIONS]

Options:
  --license-file PATH        Path to EGS license file (optional, default: egs-license.yaml in current directory)
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

Examples:
  # Simplest - Install EGS with license file in current directory
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash

  # Specify custom license file location
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --license-file /path/to/my-license.yaml

  # Skip specific components
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --skip-postgresql --skip-prometheus

  # Install only GPU Operator
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --skip-postgresql --skip-prometheus --skip-controller --skip-ui --skip-worker

  # Custom cluster configuration
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \\
    --cluster-name prod-cluster --kubeconfig ~/.kube/config --context prod-context

Notes:
  - License file defaults to 'egs-license.yaml' in current directory
  - Automatically installs all components unless explicitly skipped
  - Installation order: License → PostgreSQL → Prometheus → GPU Operator → Controller → UI → Worker
  - Takes 5-15 minutes depending on components selected
  - For license setup, see: docs/EGS-License-Setup.md

EOF
    exit 0
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
        --version)
            EGS_VERSION="$2"
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
        --skip-prometheus)
            INSTALL_PROMETHEUS="false"
            shift
            ;;
        --skip-gpu-operator)
            INSTALL_GPU_OPERATOR="false"
            shift
            ;;
        --skip-postgresql)
            INSTALL_POSTGRESQL="false"
            shift
            ;;
        --skip-controller)
            INSTALL_CONTROLLER="false"
            shift
            ;;
        --skip-ui)
            INSTALL_UI="false"
            shift
            ;;
        --skip-worker)
            INSTALL_WORKER="false"
            shift
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

# Show configuration
if [ -n "$KUBECONFIG_PATH" ]; then
    print_info "Using kubeconfig: $KUBECONFIG_PATH"
fi
if [ -n "$KUBE_CONTEXT" ]; then
    print_info "Using context: $KUBE_CONTEXT"
fi
if [ -n "$EGS_VERSION" ]; then
    print_info "Installing version: $EGS_VERSION"
fi

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

# Handle license file - default to egs-license.yaml in current directory if not specified
if [ -z "$LICENSE_FILE" ]; then
    LICENSE_FILE="egs-license.yaml"
    print_info "Using default license file: $LICENSE_FILE"
fi

# Resolve license file to absolute path BEFORE changing directories
if [[ "$LICENSE_FILE" != /* ]]; then
    LICENSE_FILE="$(cd "$(dirname "$LICENSE_FILE")" 2>/dev/null && pwd)/$(basename "$LICENSE_FILE")"
fi

# Verify license file exists NOW (before changing directories)
if [ ! -f "$LICENSE_FILE" ]; then
        print_error "❌ ERROR: License file not found at: $LICENSE_FILE"
        print_error ""
        print_error "To generate an EGS license file:"
        print_error "1. Visit: https://avesha.io/egs-registration"
        print_error "2. Complete the registration process"
        print_error "3. Download the license file and save it as 'egs-license.yaml' in the current directory"
        print_error "4. Or specify the path using: --license-file /path/to/your/license.yaml"
        print_error ""
        print_error "Example usage:"
        print_error "  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash"
        print_error ""
        print_error "For detailed license setup instructions, see: docs/EGS-License-Setup.md"
    exit 1
fi

print_info "License file found: $LICENSE_FILE"

# Detect if running locally or via curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Save original directory (where user ran curl from)
ORIGINAL_DIR="$(pwd)"

# Check if we're already in the egs-installation directory (local mode)
if [ -f "$SCRIPT_DIR/egs-installer.sh" ] && [ "$SCRIPT_NAME" = "install-egs.sh" ]; then
    # Local mode - use current directory
    print_info "Running in local mode (using current directory)"
    WORK_DIR="$SCRIPT_DIR"
    LOCAL_MODE=true
    TEMP_DIR=""
else
    # Curl mode - work in original directory, download scripts to temp
    TEMP_DIR=$(mktemp -d)
    print_info "Downloading EGS installer to temporary location..."
    
    # Clone the repository to temp
    cd "$TEMP_DIR"
    
    # Clone the main branch
    BRANCH="${EGS_BRANCH:-main}"
    REPO="${EGS_REPO:-https://github.com/kubeslice-ent/egs-installation.git}"

    if ! git clone --depth 1 --branch "$BRANCH" "$REPO" egs-installation 2>/dev/null; then
        print_error "Failed to download EGS installer from branch: $BRANCH"
        exit 1
    fi

    print_success "Downloaded EGS installer"

    # Copy necessary files to original directory
    print_info "Setting up installation in current directory..."
    cp -r "$TEMP_DIR/egs-installation/charts" "$ORIGINAL_DIR/" 2>/dev/null || true
    cp "$TEMP_DIR/egs-installation/egs-installer.sh" "$ORIGINAL_DIR/"
    cp "$TEMP_DIR/egs-installation/egs-install-prerequisites.sh" "$ORIGINAL_DIR/"
    cp "$TEMP_DIR/egs-installation/egs-uninstall.sh" "$ORIGINAL_DIR/" 2>/dev/null || true
    cp "$TEMP_DIR/egs-installation/egs-installer-config.yaml" "$ORIGINAL_DIR/" 2>/dev/null || true
    
    # Set work directory to original directory
    WORK_DIR="$ORIGINAL_DIR"
    LOCAL_MODE=false
    
    # Cleanup temp directory
    rm -rf "$TEMP_DIR"
    print_success "Setup complete in: $WORK_DIR"
fi

# Change to work directory
cd "$WORK_DIR"

# Make scripts executable
chmod +x egs-installer.sh 2>/dev/null || true

# Detect GPU nodes and cloud provider
print_info "Detecting cluster capabilities..."
GPU_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' 2>/dev/null | wc -l || echo "0")
if [ "$GPU_NODES" -gt 0 ]; then
    print_success "Detected $GPU_NODES GPU node(s)"
    ENABLE_CUSTOM_APPS="true"
else
    print_warning "No GPU nodes detected. Skipping GPU Operator installation (CPU-only cluster)."
    ENABLE_CUSTOM_APPS="false"
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

# Generate egs-installer-config.yaml
print_info "Generating EGS configuration..."

# Get kubeconfig details
# Use the actual kubeconfig filename if in same directory, otherwise copy to work directory
if [ -f "$KUBECONFIG" ]; then
    KUBECONFIG_FULLPATH=$(realpath "$KUBECONFIG")
    WORK_DIR_FULLPATH=$(realpath "$WORK_DIR")
    KUBECONFIG_DIR=$(dirname "$KUBECONFIG_FULLPATH")
    
    if [ "$KUBECONFIG_DIR" = "$WORK_DIR_FULLPATH" ]; then
        # Kubeconfig is in the same directory, use its basename
        KUBECONFIG_RELATIVE=$(basename "$KUBECONFIG")
    else
        # Kubeconfig is elsewhere, copy it to work directory
        KUBECONFIG_RELATIVE=$(basename "$KUBECONFIG")
        if ! cp "$KUBECONFIG" "$WORK_DIR/$KUBECONFIG_RELATIVE"; then
            print_error "Failed to copy kubeconfig to work directory"
            exit 1
        fi
        print_success "Copied kubeconfig to work directory: $KUBECONFIG_RELATIVE"
        # Update KUBECONFIG environment variable to point to the copied file
        export KUBECONFIG="$WORK_DIR/$KUBECONFIG_RELATIVE"
    fi
else
    # Fallback
    KUBECONFIG_RELATIVE="kubeconfig"
fi

# Show configuration being used
if [ "$CLUSTER_NAME" != "worker-1" ] || [ "$INSTALL_PROMETHEUS" = "false" ] || [ "$INSTALL_GPU_OPERATOR" = "false" ] || [ "$INSTALL_POSTGRESQL" = "false" ] || [ "$INSTALL_CONTROLLER" = "false" ] || [ "$INSTALL_UI" = "false" ] || [ "$INSTALL_WORKER" = "false" ]; then
    print_info "Using custom configuration:"
    [ "$CLUSTER_NAME" != "worker-1" ] && print_info "  Cluster: $CLUSTER_NAME"
    [ "$INSTALL_PROMETHEUS" = "false" ] && print_warning "  Skipping Prometheus"
    [ "$INSTALL_GPU_OPERATOR" = "false" ] && print_warning "  Skipping GPU Operator"
    [ "$INSTALL_POSTGRESQL" = "false" ] && print_warning "  Skipping PostgreSQL"
    [ "$INSTALL_CONTROLLER" = "false" ] && print_warning "  Skipping Controller"
    [ "$INSTALL_UI" = "false" ] && print_warning "  Skipping UI"
    [ "$INSTALL_WORKER" = "false" ] && print_warning "  Skipping Worker"
fi

# Modify the existing config file with custom values

# Use yq to update the config values directly
yq -i ".global_kubeconfig = \"$KUBECONFIG_RELATIVE\"" egs-installer-config.yaml
yq -i ".global_kubecontext = \"$CURRENT_CONTEXT\"" egs-installer-config.yaml
yq -i ".global_image_pull_secret.repository = \"$IMAGE_REGISTRY\"" egs-installer-config.yaml
yq -i ".cluster_registration[0].cluster_name = \"$CLUSTER_NAME\"" egs-installer-config.yaml
yq -i ".projects[0].name = \"$PROJECT_NAME\"" egs-installer-config.yaml
yq -i ".cluster_registration[0].geoLocation.cloudProvider = \"$CLOUD_PROVIDER\"" egs-installer-config.yaml

# Update skip/installation flags
if [ "$INSTALL_GPU_OPERATOR" = "false" ]; then
    yq -i ".additional_apps[0].skip_installation = true" egs-installer-config.yaml
else
    yq -i ".additional_apps[0].skip_installation = false" egs-installer-config.yaml
fi

if [ "$INSTALL_PROMETHEUS" = "false" ]; then
    yq -i ".additional_apps[1].skip_installation = true" egs-installer-config.yaml
else
    yq -i ".additional_apps[1].skip_installation = false" egs-installer-config.yaml
fi

if [ "$INSTALL_POSTGRESQL" = "false" ]; then
    yq -i ".additional_apps[2].skip_installation = true" egs-installer-config.yaml
else
    yq -i ".additional_apps[2].skip_installation = false" egs-installer-config.yaml
fi

# Update enable flags
yq -i ".enable_install_controller = $([ "$INSTALL_CONTROLLER" = "true" ] && echo "true" || echo "false")" egs-installer-config.yaml
yq -i ".enable_install_ui = $([ "$INSTALL_UI" = "true" ] && echo "true" || echo "false")" egs-installer-config.yaml
yq -i ".enable_install_worker = $([ "$INSTALL_WORKER" = "true" ] && echo "true" || echo "false")" egs-installer-config.yaml

# Update custom apps based on GPU detection
yq -i ".enable_custom_apps = $ENABLE_CUSTOM_APPS" egs-installer-config.yaml

print_success "Generated egs-installer-config.yaml"

# Always just generate config
print_success "Configuration generated successfully!"
echo ""

# Check if we should auto-install (both curl and local mode)
print_info "📁 Configuration saved to: $WORK_DIR/egs-installer-config.yaml"
echo ""
print_info "🚀 Starting automated installation..."
echo ""

# Disable cleanup trap during installation
trap - EXIT

# Step 0: Check for and apply EGS license (only if controller, UI, or worker are being installed)
if [ "$INSTALL_CONTROLLER" = "true" ] || [ "$INSTALL_UI" = "true" ] || [ "$INSTALL_WORKER" = "true" ]; then
    print_info "📜 Step 0/3: Applying EGS license..."

    # License file handling is done earlier in the script

    print_info "Applying EGS license..."
    echo ""
else
    print_info "📜 Skipping license application (no EGS components selected for installation)..."
    echo ""
fi

# Create namespace and apply license only if controller, UI, or worker are being installed
if [ "$INSTALL_CONTROLLER" = "true" ] || [ "$INSTALL_UI" = "true" ] || [ "$INSTALL_WORKER" = "true" ]; then
    # Create namespace if it doesn't exist
    kubectl create namespace kubeslice-controller --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

    if kubectl apply -f "$LICENSE_FILE" -n kubeslice-controller; then
        print_success "License applied successfully!"
        echo ""
    else
        print_warning "License application failed or already exists. Continuing..."
        echo ""
    fi
fi

# Step 1: Install prerequisites (only if any are enabled)
if [ "$INSTALL_POSTGRESQL" = "true" ] || [ "$INSTALL_PROMETHEUS" = "true" ] || [ "$INSTALL_GPU_OPERATOR" = "true" ]; then
    print_info "📦 Step 1/2: Installing prerequisites (PostgreSQL, Prometheus, GPU Operator)..."
    echo ""
    if ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml; then
        print_success "Prerequisites installed successfully!"
        echo ""
    else
        print_error "Prerequisites installation failed!"
        exit 1
    fi
else
    print_info "📦 Skipping prerequisites installation (none selected)..."
    echo ""
fi

# Step 2: Install EGS components (only if any are enabled)
if [ "$INSTALL_CONTROLLER" = "true" ] || [ "$INSTALL_UI" = "true" ] || [ "$INSTALL_WORKER" = "true" ]; then
    print_info "🚀 Step 2/2: Installing EGS components (Controller, UI, Worker)..."
    echo ""
    if ./egs-installer.sh --input-yaml egs-installer-config.yaml; then
        print_success "✅ EGS installation completed successfully!"
        exit 0
    else
        print_error "EGS installation failed!"
        exit 1
    fi
else
    print_info "🚀 Skipping EGS components installation (none selected)..."
    echo ""
fi

