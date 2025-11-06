#!/bin/bash

# EGS Quick Installer (Curl-Friendly)
# One-command installation for single-cluster EGS
# Auto-installs: PostgreSQL, Prometheus, GPU Operator, Controller, UI, Worker
# Usage: 
#   curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- --license-file egs-license.yaml
#   curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- --license-file egs-license.yaml --kubeconfig ~/.kube/config --context my-context
#   curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- --license-file egs-license.yaml --cluster-name prod-cluster

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
LICENSE_FILE=""  # Path to license file (defaults to egs-license.yaml in work directory)
INSTALL_PROMETHEUS="true"
INSTALL_GPU_OPERATOR="true"
INSTALL_POSTGRESQL="true"

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
  curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- --license-file <PATH> [OPTIONS]

Options:
  --license-file PATH        Path to EGS license file (REQUIRED)
  --kubeconfig PATH          Path to kubeconfig file (default: auto-detect)
  --context NAME             Kubernetes context to use (default: current-context)
  --cluster-name NAME        Cluster name (default: worker-1)
  --help, -h                 Show this help message

Examples:
  # Simplest - Install EGS with one command (REQUIRED: license file must be passed)
  curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- \\
    --license-file egs-license.yaml

  # Specify kubeconfig and context
  curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- \\
    --license-file egs-license.yaml \\
    --kubeconfig ~/.kube/config \\
    --context my-cluster

  # Custom cluster name
  curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- \\
    --license-file egs-license.yaml \\
    --cluster-name prod-cluster

  # Specify custom license file location
  curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- \\
    --license-file /path/to/my-license.yaml

Notes:
  - LICENSE FILE IS MANDATORY - Must be passed via --license-file parameter
  - Automatically installs ALL components (prerequisites + EGS)
  - Default cluster: 'worker-1', Project: 'avesha'
  - Installation order: License → PostgreSQL → Prometheus → GPU Operator → Controller → UI → Worker
  - Takes 10-15 minutes for complete installation
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

# Resolve license file to absolute path BEFORE changing directories
if [ -n "$LICENSE_FILE" ]; then
    # If relative path, convert to absolute path from current directory
    if [[ "$LICENSE_FILE" != /* ]]; then
        LICENSE_FILE="$(cd "$(dirname "$LICENSE_FILE")" 2>/dev/null && pwd)/$(basename "$LICENSE_FILE")"
    fi
    # Verify license file exists NOW (before changing directories)
    if [ ! -f "$LICENSE_FILE" ]; then
        print_error "❌ ERROR: License file not found at: $LICENSE_FILE"
        print_error "Please ensure the EGS license file exists at the specified path."
        print_error "Example: curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- --license-file egs-license.yaml"
        exit 1
    fi
    print_info "License file found: $LICENSE_FILE"
fi

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
    
    # Use the feature branch for now (change to main after merge)
    BRANCH="${EGS_BRANCH:-feature/single-command-installer}"
    REPO="${EGS_REPO:-https://github.com/kubeslice-ent/egs-installation.git}"
    
    if ! git clone --depth 1 --branch "$BRANCH" "$REPO" egs-installation 2>/dev/null; then
        print_error "Failed to download EGS installer from branch: $BRANCH"
        print_info "Trying main branch..."
        BRANCH="main"
        if ! git clone --depth 1 --branch "$BRANCH" "$REPO" egs-installation; then
            print_error "Failed to download EGS installer"
            exit 1
        fi
    fi
    
    print_success "Downloaded EGS installer"
    
    # Copy necessary files to original directory
    print_info "Setting up installation in current directory..."
    cp -r "$TEMP_DIR/egs-installation/charts" "$ORIGINAL_DIR/" 2>/dev/null || true
    cp "$TEMP_DIR/egs-installation/egs-installer.sh" "$ORIGINAL_DIR/"
    cp "$TEMP_DIR/egs-installation/egs-install-prerequisites.sh" "$ORIGINAL_DIR/"
    cp "$TEMP_DIR/egs-installation/egs-uninstall.sh" "$ORIGINAL_DIR/" 2>/dev/null || true
    
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
if [ "$CLUSTER_NAME" != "worker-1" ] || [ "$INSTALL_PROMETHEUS" = "false" ] || [ "$INSTALL_GPU_OPERATOR" = "false" ] || [ "$INSTALL_POSTGRESQL" = "false" ]; then
    print_info "Using custom configuration:"
    [ "$CLUSTER_NAME" != "worker-1" ] && print_info "  Cluster: $CLUSTER_NAME"
    [ "$INSTALL_PROMETHEUS" = "false" ] && print_warning "  Skipping Prometheus"
    [ "$INSTALL_GPU_OPERATOR" = "false" ] && print_warning "  Skipping GPU Operator"
    [ "$INSTALL_POSTGRESQL" = "false" ] && print_warning "  Skipping PostgreSQL"
fi

# Generate config file (using the existing template structure from egs-installer-config.yaml)
cat > egs-installer-config.yaml << 'EOFCONFIG'
########################### MANDATORY PARAMETERS ####################################################################

# Kubeconfig settings
global_kubeconfig: "KUBECONFIG_PLACEHOLDER"                         # Relative path to the global kubeconfig file (must be in the script directory) - Mandatory
global_kubecontext: "CONTEXT_PLACEHOLDER"                        # Global kubecontext to use - Mandatory
use_global_context: true                      # If true, use the global kubecontext for all operations by default

# Enable or disable specific stages of the installation
enable_install_controller: true               # Enable the installation of the Kubeslice controller
enable_install_ui: true                       # Enable the installation of the Kubeslice UI
enable_install_worker: true                   # Enable the installation of Kubeslice workers

# Enable or disable the installation of additional applications(prometheus, gpu-operator, postgresql)

enable_install_additional_apps: true         # Set to true to enable additional apps installation

# Enable custom applications
# Set this to true if you want to allow custom applications to be deployed.
# This is specifically useful for enabling NVIDIA driver installation on your nodes.
enable_custom_apps: ENABLE_CUSTOM_APPS_PLACEHOLDER

# Command execution settings
# Set this to true to allow the execution of commands for configuring NVIDIA MIG.
# This includes modifications to the NVIDIA ClusterPolicy and applying node labels
# based on the MIG strategy defined in the YAML (e.g., single or mixed strategy).
run_commands: false

#########################################################################################################################
########################### OPTIONAL CONFIGURATION PARAMETERS FOR MULTICLUSTER SETUP###########################################################

# Global image pull secret settings for AirGap Installations
global_image_pull_secret:
  repository: "https://index.docker.io/v1/"   # Docker registry URL
  username: ""                                # Global Docker registry username
  password: ""                                # Global Docker registry password

# Project and cluster registration settings
enable_project_creation: true                   # Enable project creation in Kubeslice
enable_cluster_registration: true               # Enable cluster registration in Kubeslice
enable_prepare_worker_values_file: true         # Prepare the worker values file for Helm charts
enable_autofetch_egsagent_endpoint_and_token: true # if False then, skip update values of egsAgent token and endpoint in values file. 

# Global monitoring endpoint settings
global_auto_fetch_endpoint: true               # Enable automatic fetching of monitoring endpoints globally
global_grafana_namespace: egs-monitoring        # Namespace where Grafana is globally deployed
global_grafana_service_type: ClusterIP          # Service type for Grafana (accessible only within the cluster)
global_grafana_service_name: prometheus-grafana # Service name for accessing Grafana globally
global_prometheus_namespace: egs-monitoring     # Namespace where Prometheus is globally deployed
global_prometheus_service_name: prometheus-kube-prometheus-prometheus # Service name for accessing Prometheus globally
global_prometheus_service_type: ClusterIP       # Service type for Prometheus (accessible only within the cluster)

# Precheck options
precheck: true                                  # Run general prechecks before starting the installation
kubeslice_precheck: true                        # Run specific prechecks for Kubeslice components

# Global installation verification settings
verify_install: false                           # Enable verification of installations globally
verify_install_timeout: 600                     # Timeout for global installation verification (in seconds)
skip_on_verify_fail: true                       # If set to true, skip steps where verification fails, otherwise exit on failure

# Base path settings
base_path: ""                                   # If left empty, the script will use the relative path to the script as the base path

# Helm repository settings
use_local_charts: true                          # Use local Helm charts instead of fetching them from a repository
local_charts_path: "charts"                     # Path to the directory containing local Helm charts
global_helm_repo_url: ""                        # URL for the global Helm repository (if not using local charts)
global_helm_username: ""                        # Username for accessing the global Helm repository
global_helm_password: ""                        # Password for accessing the global Helm repository
readd_helm_repos: true                          # Re-add Helm repositories even if they are already present

#### Kubeslice Controller Installation Settings ####
kubeslice_controller_egs:
  skip_installation: false                     # Do not skip the installation of the controller
  use_global_kubeconfig: true                  # Use global kubeconfig for the controller installation
  specific_use_local_charts: true              # Override to use local charts for the controller
  kubeconfig: ""                               # Path to the kubeconfig file specific to the controller, if empty, uses the global kubeconfig
  kubecontext: ""                              # Kubecontext specific to the controller; if empty, uses the global context
  namespace: "kubeslice-controller"            # Kubernetes namespace where the controller will be installed
  release: "egs-controller"                    # Helm release name for the controller
  chart: "kubeslice-controller-egs"            # Helm chart name for the controller
#### Inline Helm Values for the Controller Chart ####
  inline_values:
    global:
      imageRegistry: IMAGE_REGISTRY_PLACEHOLDER   # Docker registry for the images
      namespaceConfig:   # user can configure labels or annotations that EGS Controller namespaces should have
        labels: {}
        annotations: {}
      kubeTally:
        enabled: true                          # Enable KubeTally in the controller
#### Postgresql Connection Configuration for Kubetally  ####
        existingSecret: false # Set to true if secret is pre-created externally
        postgresSecretName: kubetally-db-credentials   # Secret name in kubeslice-controller namespace for PostgreSQL credentials created by install, all the below values must be specified 
                                                       # then a secret will be created with specified name. 
                                                       # alternatively you can make all below values empty and provide a pre-created secret name with below connection details format
        postgresAddr: "kt-postgresql.kt-postgresql.svc.cluster.local" # Change this Address to your postgresql endpoint
        postgresPort: 5432                     # Change this Port for the PostgreSQL service to your values 
        postgresUser: "postgres"               # Change this PostgreSQL username to your values
        postgresPassword: "postgres"           # Change this PostgreSQL password to your value
        postgresDB: "postgres"                 # Change this PostgreSQL database name to your value
        postgresSslmode: disable               # Change this SSL mode for PostgreSQL connection to your value
        prometheusUrl: http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090  # Prometheus URL for monitoring
    kubeslice:
      controller:
        endpoint: ""                           # Endpoint of the controller API server; auto-fetched if left empty
#### Helm Flags and Verification Settings ####
  helm_flags: "--wait --timeout 5m --debug"            # Additional Helm flags for the installation
  verify_install: false                        # Verify the installation of the controller
  verify_install_timeout: 30                   # Timeout for the controller installation verification (in seconds)
  skip_on_verify_fail: true                    # If verification fails, do not skip the step
#### Troubleshooting Settings ####
  enable_troubleshoot: false                   # Enable troubleshooting mode for additional logs and checks
#### Kubeslice Controller Installation Settings ####

#### Kubeslice UI Installation Settings ####
kubeslice_ui_egs:
  skip_installation: false                     # Do not skip the installation of the UI
  use_global_kubeconfig: true                  # Use global kubeconfig for the UI installation
  kubeconfig: ""                               # Path to the kubeconfig file specific to the UI, if empty, uses the global kubeconfig
  kubecontext: ""                              # Kubecontext specific to the UI; if empty, uses the global context
  namespace: "kubeslice-controller"            # Kubernetes namespace where the UI will be installed
  release: "egs-ui"                            # Helm release name for the UI
  chart: "kubeslice-ui-egs"                    # Helm chart name for the UI
#### Inline Helm Values for the UI Chart ####
  inline_values:
    global:
      imageRegistry: IMAGE_REGISTRY_PLACEHOLDER   # Docker registry for the UI images
    kubeslice:
      prometheus:
        url: http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090  # Prometheus URL for monitoring
      uiproxy:
        service:
          type: LoadBalancer                  # Service type for the UI proxy
          ## if type selected to NodePort then set nodePort value if required
          # nodePort:
          # port: 443
          # targetPort: 8443
        labels:
          app: kubeslice-ui-proxy
        annotations: {}

        ingress:
          ## If true, ui‑proxy Ingress will be created
          enabled: false
          ## Port on the Service to route to
          servicePort: 443
          ## Ingress class name (e.g. "nginx"), if you're using a custom ingress controller
          className: ""
          hosts:
            - host: ui.kubeslice.com     # replace with your FQDN
              paths:
                - path: /             # base path
                  pathType: Prefix    # Prefix | Exact
          ## TLS configuration (you must create these Secrets ahead of time)
          tls: []
            # - hosts:
            #     - ui.kubeslice.com
            #   secretName: uitlssecret
          annotations: {}
          ## Extra labels to add onto the Ingress object
          extraLabels: {}
      apigw:
        env:
          - name: DCGM_METRIC_JOB_VALUE
            value: nvidia-dcgm-exporter
          
      egsCoreApis:
        enabled: true                         # Enable EGS core APIs for the UI
        service:
          type: ClusterIP                  # Service type for the EGS core APIs
#### Helm Flags and Verification Settings ####
  helm_flags: "--wait --timeout 5m --debug"            # Additional Helm flags for the UI installation
  verify_install: false                        # Verify the installation of the UI
  verify_install_timeout: 50                   # Timeout for the UI installation verification (in seconds)
  skip_on_verify_fail: true                    # If UI verification fails, do not skip the step
#### Chart Source Settings ####
  specific_use_local_charts: true              # Override to use local charts for the UI

#### Kubeslice Worker Installation Settings ####
kubeslice_worker_egs:
  - name: "CLUSTER_NAME_PLACEHOLDER"                           # Worker name
    use_global_kubeconfig: true                # Use global kubeconfig for this worker
    kubeconfig: ""                             # Path to the kubeconfig file specific to the worker, if empty, uses the global kubeconfig
    kubecontext: ""                            # Kubecontext specific to the worker; if empty, uses the global context
    skip_installation: false                   # Do not skip the installation of the worker
    specific_use_local_charts: true            # Override to use local charts for this worker
    namespace: "kubeslice-system"              # Kubernetes namespace for this worker
    release: "egs-worker"                      # Helm release name for the worker
    chart: "kubeslice-worker-egs"              # Helm chart name for the worker
#### Inline Helm Values for the Worker Chart ####
    inline_values:
      global:
        imageRegistry: IMAGE_REGISTRY_PLACEHOLDER # Docker registry for worker images
      kubesliceNetworking:
        enabled: true        # enable/disable network component installation
      operator:
        env:
          - name: DCGM_EXPORTER_JOB_NAME
            value: gpu-metrics
      egs:
        prometheusEndpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"  # Prometheus endpoint
        grafanaDashboardBaseUrl: "http://<grafana-lb>/d/Oxed_c6Wz" # Grafana dashboard base URL
      egsAgent:
        secretName: egs-agent-access
        agentSecret:
          endpoint: ""
          key: ""
      metrics:
        insecure: true                        # Allow insecure connections for metrics
      kserve:
        enabled: true                         # Enable KServe for the worker
        kserve:                               # KServe chart options
          controller:
            gateway:
              domain: kubeslice.com
              ingressGateway:
                className: "nginx"            # Ingress class name for the KServe gateway
      egsGpuAgent:
        env:
          - name: REMOTE_HE_INFO
            value: "nvidia-dcgm.egs-gpu-operator.svc.cluster.local:5555"
          - name: HEALTH_CHECK_INTERVAL
            value: "15m"
#### Helm Flags and Verification Settings ####
    helm_flags: "--wait --timeout 5m --debug"          # Additional Helm flags for the worker installation
    verify_install: true                       # Verify the installation of the worker
    verify_install_timeout: 60                 # Timeout for the worker installation verification (in seconds)
    skip_on_verify_fail: false                 # Do not skip if worker verification fails
#### Troubleshooting Settings ####
    enable_troubleshoot: false                 # Enable troubleshooting mode for additional logs and checks
#### Local Monitoring Endpoint Settings (Optional) ####
    # local_auto_fetch_endpoint: true          # Enable automatic fetching of monitoring endpoints
    # local_grafana_namespace: egs-monitoring  # Namespace where Grafana is deployed
    # local_grafana_service_name: prometheus-grafana  # Service name for accessing Grafana
    # local_grafana_service_type: ClusterIP    # Service type for Grafana (accessible only within the cluster)
    # local_prometheus_namespace: egs-monitoring  # Namespace where Prometheus is deployed
    # local_prometheus_service_name: prometheus-kube-prometheus-prometheus  # Service name for accessing Prometheus
    # local_prometheus_service_type: ClusterIP # Service type for Prometheus (accessible only within the cluster)



#### Define Projects ####
projects:
  - name: "avesha"                              # Name of the Kubeslice project
    username: "admin"                           # Username for accessing the Kubeslice project

#### Define Cluster Registration ####
cluster_registration:
  - cluster_name: "CLUSTER_NAME_PLACEHOLDER"                    # Name of the cluster to be registered
    project_name: "avesha"                      # Name of the project to associate with the cluster
    #### Telemetry Settings ####
    telemetry:
      enabled: true                             # Enable telemetry for this cluster
      endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090" # Telemetry endpoint
      telemetryProvider: "prometheus"           # Telemetry provider (Prometheus in this case)
    #### Geo-Location Settings ####
    geoLocation:
      cloudProvider: "CLOUD_PROVIDER_PLACEHOLDER"              # Cloud provider for this cluster (e.g., GCP)
      cloudRegion: ""                # Cloud region for this cluster (e.g., us-central1)

#### Define Additional Applications to Install ####
additional_apps:
  - name: "gpu-operator"                       # Name of the application
    skip_installation: GPU_OPERATOR_SKIP_PLACEHOLDER                   # Do not skip the installation of the GPU operator
    use_global_kubeconfig: true                # Use global kubeconfig for this application
    kubeconfig: ""                             # Path to the kubeconfig file specific to this application
    kubecontext: ""                            # Kubecontext specific to this application; uses global context if empty
    namespace: "egs-gpu-operator"              # Namespace where the GPU operator will be installed
    release: "gpu-operator"                    # Helm release name for the GPU operator
    chart: "gpu-operator"                      # Helm chart name for the GPU operator
    repo_url: "https://helm.ngc.nvidia.com/nvidia" # Helm repository URL for the GPU operator
    version: "v24.9.1"                         # Version of the GPU operator to install
    specific_use_local_charts: true            # Use local charts for this application
    #### Inline Helm Values for GPU Operator ####
    inline_values:
      hostPaths:
        driverInstallDir: "/home/kubernetes/bin/nvidia"
      toolkit:
        installDir: "/home/kubernetes/bin/nvidia"
      cdi:
        enabled: true
        default: true
      # mig:
      #   strategy: "mixed"
      # migManager:                             # Enable to ensure that the node reboots and can apply the MIG configuration.
      #   env:
      #     - name: WITH_REBOOT
      #       value: "true"
      driver:
        enabled: false
    helm_flags: "--debug"                              # Additional Helm flags for this application's installation
    verify_install: false                       # Verify the installation of the GPU operator
    verify_install_timeout: 600                 # Timeout for verification (in seconds)
    skip_on_verify_fail: true                   # Skip the step if verification fails
    enable_troubleshoot: false                  # Enable troubleshooting mode for additional logs and checks

  - name: "prometheus"                         # Name of the application
    skip_installation: PROMETHEUS_SKIP_PLACEHOLDER                   # Do not skip the installation of Prometheus
    use_global_kubeconfig: true                # Use global kubeconfig for Prometheus
    kubeconfig: ""                             # Path to the kubeconfig file specific to this application
    kubecontext: ""                            # Kubecontext specific to this application; uses global context if empty
    namespace: "egs-monitoring"                # Namespace where Prometheus will be installed
    release: "prometheus"                      # Helm release name for Prometheus
    chart: "kube-prometheus-stack"             # Helm chart name for Prometheus
    repo_url: "https://prometheus-community.github.io/helm-charts" # Helm repository URL for Prometheus
    version: "v45.0.0"                         # Version of the Prometheus stack to install
    specific_use_local_charts: true            # Use local charts for this application
    values_file: ""                             # Path to an external values file, if any
    #### Inline Helm Values for Prometheus ####
    inline_values:
      prometheus:
        service:
          type: ClusterIP                     # Service type for Prometheus
        prometheusSpec:
          storageSpec: {}                     # Placeholder for storage configuration
          additionalScrapeConfigs:
          - job_name: nvidia-dcgm-exporter
            kubernetes_sd_configs:
            - role: endpoints
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod_name
            - source_labels: [__meta_kubernetes_pod_container_name]
              target_label: container_name
          - job_name: gpu-metrics
            scrape_interval: 1s
            metrics_path: /metrics
            scheme: http
            kubernetes_sd_configs:
            - role: endpoints
              namespaces:
                names:
                - egs-gpu-operator
            relabel_configs:
            - source_labels: [__meta_kubernetes_endpoints_name]
              action: drop
              regex: .*-node-feature-discovery-master
            - source_labels: [__meta_kubernetes_pod_node_name]
              action: replace
              target_label: kubernetes_node
      grafana:
        enabled: true                         # Enable Grafana
        grafana.ini:
          auth:
            disable_login_form: true
            disable_signout_menu: true
          auth.anonymous:
            enabled: true
            org_role: Viewer
        service:
          type: ClusterIP                  # Service type for Grafana
        persistence:
          enabled: false                      # Disable persistence
          size: 1Gi                           # Default persistence size
    helm_flags: "--debug"                             # Additional Helm flags for this application's installation
    verify_install: false                      # Verify the installation of Prometheus
    verify_install_timeout: 600                # Timeout for verification (in seconds)
    skip_on_verify_fail: true                  # Skip the step if verification fails
    enable_troubleshoot: false                 # Enable troubleshooting mode for additional logs and checks

  - name: "postgresql"                         # Name of the application
    skip_installation: POSTGRESQL_SKIP_PLACEHOLDER                   # Do not skip the installation of PostgreSQL
    use_global_kubeconfig: true                # Use global kubeconfig for PostgreSQL
    kubeconfig: ""                             # Path to the kubeconfig file specific to this application
    kubecontext: ""                            # Kubecontext specific to this application; uses global context if empty
    namespace: "kt-postgresql"                # Namespace where PostgreSQL will be installed
    release: "kt-postgresql"                  # Helm release name for PostgreSQL
    chart: "postgresql"                       # Helm chart name for PostgreSQL
    repo_url: "oci://registry-1.docker.io/bitnamicharts/postgresql" # Helm repository URL for PostgreSQL
    version: "16.2.1"                         # Version of the PostgreSQL chart to install
    specific_use_local_charts: true           # Use local charts for this application
    values_file: ""                            # Path to an external values file, if any
    #### Inline Helm Values for PostgreSQL ####
    inline_values:
      auth:
        postgresPassword: "postgres"          # Explicit password (use if not relying on \`existingSecret\`)
        username: "postgres"                  # Explicit username (fallback if \`existingSecret\` is not used)
        password: "postgres"                  # Password for PostgreSQL (optional)
        database: "postgres"                  # Default database to create
      primary:
        persistence:
          enabled: false                      # Disable persistent storage for PostgreSQL
          size: 10Gi                          # Size of the Persistent Volume Claim
    helm_flags: "--wait --debug"                       # Additional Helm flags for this application's installation
    verify_install: true                       # Verify the installation of PostgreSQL
    verify_install_timeout: 600                # Timeout for verification (in seconds)
    skip_on_verify_fail: false                 # Do not skip if verification fails

#### Define Custom Applications and Associated Manifests ####
manifests:
  - appname: gpu-operator-quota               # Name of the custom application
    manifest: ""                              # URL or path to the manifest file; if empty, inline YAML is used
    overrides_yaml: ""                        # Path to an external YAML file with overrides, if any
    inline_yaml: |                            # Inline YAML content for this custom application
      apiVersion: v1
      kind: ResourceQuota
      metadata:
        name: gpu-operator-quota
      spec:
        hard:
          pods: 100                           # Maximum number of pods
        scopeSelector:
          matchExpressions:
          - operator: In
            scopeName: PriorityClass          # Define scope for PriorityClass
            values:
              - system-node-critical
              - system-cluster-critical
    use_global_kubeconfig: true               # Use global kubeconfig for this application
    skip_installation: false                  # Do not skip the installation of this application
    verify_install: false                     # Verify the installation of this application
    verify_install_timeout: 30                # Timeout for verification (in seconds)
    skip_on_verify_fail: true                 # Skip if verification fails
    namespace: egs-gpu-operator               # Namespace for this application
    kubeconfig: ""                            # Path to the kubeconfig file specific to this application
    kubecontext: ""                           # Kubecontext specific to this application; uses global context if empty

  - appname: nvidia-driver-installer          # Name of the custom application
    manifest: "https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml"
                                               # URL to the manifest file
    overrides_yaml: ""                        # Path to an external YAML file with overrides, if any
    inline_yaml: null                         # Inline YAML content for this application
    use_global_kubeconfig: true               # Use global kubeconfig for this application
    kubeconfig: ""                            # Path to the kubeconfig file specific to this application
    kubecontext: ""                           # Kubecontext specific to this application; uses global context if empty
    skip_installation: false                  # Do not skip the installation of this application
    verify_install: false                     # Verify the installation of this application
    verify_install_timeout: 200               # Timeout for verification (in seconds)
    skip_on_verify_fail: true                 # Skip if verification fails
    namespace: kube-system                    # Namespace for this application

    

#### Define Commands to Execute ####
commands:
  - use_global_kubeconfig: true               # Use global kubeconfig for these commands
    kubeconfig: ""                            # Path to the kubeconfig file specific to these commands
    kubecontext: ""                           # Kubecontext specific to these commands; uses global context if empty
    skip_installation: false                   # Do not skip the execution of these commands
    verify_install: false                     # Verify the execution of these commands
    verify_install_timeout: 200               # Timeout for verification (in seconds)
    skip_on_verify_fail: true                 # Skip if command verification fails
    namespace: kube-system                    # Namespace context for these commands
    command_stream: |                         # Commands to execute
      kubectl create namespace egs-gpu-operator --dry-run=client -o yaml | kubectl apply -f - || true
      kubectl get nodes || true
      kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' | xargs -I {} kubectl label nodes {} gke-no-default-nvidia-gpu-device-plugin=true cloud.google.com/gke-accelerator=true --overwrite || true
      kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' | xargs -I {} sh -c "echo {}; kubectl get node {} -o=jsonpath='{.metadata.labels}' | jq ." || true
      kubectl get clusterpolicies.nvidia.com/cluster-policy --no-headers || true

#### Troubleshooting Mode Settings ####
enable_troubleshoot:
  enabled: false                              # Global enable troubleshooting mode for additional logs and checks

  #### Resource Types to Troubleshoot ####
  resource_types:
    - pods
    - deployments
    - daemonsets
    - statefulsets
    - replicasets
    - jobs
    - configmaps
    - secrets
    - services
    - serviceaccounts
    - roles
    - rolebindings
    - crds

  #### API Groups to Troubleshoot ####
  api_groups:
    - controller.kubeslice.io
    - worker.kubeslice.io
    - inventory.kubeslice.io
    - aiops.kubeslice.io
    - networking.kubeslice.io
    - monitoring.coreos.com

  #### Upload Log Settings ####
  upload_logs:
    enabled: false                           # Enable log upload functionality
    command: |                               # Command to execute for log upload

#### List of Required Binaries ####
required_binaries:
  - yq                                       # YAML processor
  - helm                                     # Helm package manager
  - jq                                       # JSON processor
  - kubectl                                  # Kubernetes command-line tool

#### Node Labeling Settings ####
add_node_label: true                        # Enable node labeling during installation
# Version of the input configuration file
version: "1.15.3"
EOFCONFIG

# Replace placeholders with actual values
sed -i "s/KUBECONFIG_PLACEHOLDER/$KUBECONFIG_RELATIVE/g" egs-installer-config.yaml
sed -i "s/CONTEXT_PLACEHOLDER/$CURRENT_CONTEXT/g" egs-installer-config.yaml
sed -i "s|IMAGE_REGISTRY_PLACEHOLDER|$IMAGE_REGISTRY|g" egs-installer-config.yaml
sed -i "s/CLUSTER_NAME_PLACEHOLDER/$CLUSTER_NAME/g" egs-installer-config.yaml
sed -i "s/CLOUD_PROVIDER_PLACEHOLDER/$CLOUD_PROVIDER/g" egs-installer-config.yaml
sed -i "s/GPU_OPERATOR_SKIP_PLACEHOLDER/$([ "$INSTALL_GPU_OPERATOR" = "false" ] && echo "true" || echo "false")/g" egs-installer-config.yaml
sed -i "s/PROMETHEUS_SKIP_PLACEHOLDER/$([ "$INSTALL_PROMETHEUS" = "false" ] && echo "true" || echo "false")/g" egs-installer-config.yaml
sed -i "s/POSTGRESQL_SKIP_PLACEHOLDER/$([ "$INSTALL_POSTGRESQL" = "false" ] && echo "true" || echo "false")/g" egs-installer-config.yaml
sed -i "s/ENABLE_CUSTOM_APPS_PLACEHOLDER/$ENABLE_CUSTOM_APPS/g" egs-installer-config.yaml

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

# Step 0: Check for and apply EGS license
print_info "📜 Step 0/3: Applying EGS license..."

# Check if license file parameter was provided
if [ -z "$LICENSE_FILE" ]; then
    print_error "❌ ERROR: License file parameter is required!"
    print_error "Please provide the license file path using: --license-file <path>"
    print_error "Example: curl -fsSL https://raw.githubusercontent.com/kubeslice-ent/egs-installation/main/install-egs.sh | bash -s -- --license-file egs-license.yaml"
    print_error "For license setup instructions, see: docs/EGS-License-Setup.md"
    exit 1
fi

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

# Step 1: Install prerequisites
print_info "📦 Step 1/2: Installing prerequisites (PostgreSQL, Prometheus, GPU Operator)..."
echo ""
if ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml; then
    print_success "Prerequisites installed successfully!"
    echo ""
else
    print_error "Prerequisites installation failed!"
    exit 1
fi

# Step 2: Install EGS components
print_info "📦 Step 2/2: Installing EGS components (Controller, UI, Worker)..."
echo ""
if ./egs-installer.sh --input-yaml egs-installer-config.yaml; then
    print_success "✅ EGS installation completed successfully!"
    exit 0
else
    print_error "EGS installation failed!"
    exit 1
fi

