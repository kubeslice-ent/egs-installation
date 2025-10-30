#!/bin/bash

# EGS Simple Installer - One Command Installation
# Version: 1.0.0
# Description: Simplified installation script for single-cluster EGS deployments

set -e

SCRIPT_VERSION="1.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo "=============================================="
echo "   🚀 EGS Simple Installer v${SCRIPT_VERSION}"
echo "   Single Cluster Quick Setup"
echo "=============================================="
echo ""

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    for tool in kubectl helm yq jq; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        else
            print_success "$tool is installed"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are met!"
}

# Function to auto-detect kubeconfig and context
auto_detect_kube_context() {
    print_info "Auto-detecting Kubernetes configuration..."
    
    # Get current context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_CONTEXT" ]; then
        print_error "No active Kubernetes context found!"
        print_info "Please set your kubeconfig context using: kubectl config use-context <context-name>"
        exit 1
    fi
    
    # Get kubeconfig path
    KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
    
    print_success "Detected Kubernetes context: $CURRENT_CONTEXT"
    print_success "Using kubeconfig: $KUBECONFIG_PATH"
    
    # Test cluster connectivity
    if kubectl cluster-info &>/dev/null; then
        print_success "Successfully connected to Kubernetes cluster"
    else
        print_error "Cannot connect to Kubernetes cluster with current context"
        exit 1
    fi
}

# Function to detect cluster capabilities
detect_cluster_capabilities() {
    print_info "Detecting cluster capabilities..."
    
    # Check for GPU nodes
    GPU_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' 2>/dev/null | wc -l)
    
    if [ "$GPU_NODES" -gt 0 ]; then
        print_success "Detected $GPU_NODES GPU node(s) in the cluster"
        HAS_GPU="true"
    else
        print_warning "No GPU nodes detected. GPU Operator will still be installed but may not be active."
        HAS_GPU="false"
    fi
    
    # Check for LoadBalancer support
    print_info "Checking for LoadBalancer support..."
    LB_SUPPORT="true"
    
    # Detect cloud provider
    CLOUD_PROVIDER=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | cut -d: -f1 || echo "unknown")
    
    if [ "$CLOUD_PROVIDER" != "unknown" ]; then
        print_success "Detected cloud provider: $CLOUD_PROVIDER"
    else
        print_warning "Could not detect cloud provider. Using default configuration."
    fi
}

# Function to generate full configuration
generate_full_config() {
    local OUTPUT_CONFIG="${1:-egs-installer-config.yaml}"
    
    print_info "Generating full EGS configuration with auto-detected settings..."
    
    # Use sensible defaults - all values auto-detected or defaulted
    IMAGE_REGISTRY="harbor.saas1.smart-scaler.io/avesha/aveshasystems"
    PROJECT_NAME="avesha"
    CLUSTER_NAME="egs-cluster"
    INSTALL_PROMETHEUS="true"
    INSTALL_GPU_OPERATOR="true"
    INSTALL_POSTGRESQL="true"
    UI_SERVICE_TYPE="LoadBalancer"
    # CLOUD_PROVIDER and CLOUD_REGION already set by detect_cluster_capabilities()
    
    # Get the base directory
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy kubeconfig to local directory for relative path usage
    KUBECONFIG_BASENAME=$(basename "$KUBECONFIG_PATH")
    if [ "$KUBECONFIG_PATH" != "$BASE_DIR/$KUBECONFIG_BASENAME" ]; then
        cp "$KUBECONFIG_PATH" "$BASE_DIR/kubeconfig-temp"
        KUBECONFIG_RELATIVE="kubeconfig-temp"
    else
        KUBECONFIG_RELATIVE="$KUBECONFIG_BASENAME"
    fi
    
    # Generate the full configuration file
    cat > "$OUTPUT_CONFIG" << EOF
########################### MANDATORY PARAMETERS ####################################################################

# Kubeconfig settings
global_kubeconfig: "$KUBECONFIG_RELATIVE"                         # Relative path to the global kubeconfig file (must be in the script directory) - Mandatory
global_kubecontext: "$CURRENT_CONTEXT"                        # Global kubecontext to use - Mandatory
use_global_context: true                      # If true, use the global kubecontext for all operations by default

# Enable or disable specific stages of the installation
enable_install_controller: true               # Enable the installation of the Kubeslice controller
enable_install_ui: true                       # Enable the installation of the Kubeslice UI
enable_install_worker: true                   # Enable the installation of Kubeslice workers

# Enable or disable the installation of additional applications(prometheus, gpu-operator, postgresql)
enable_install_additional_apps: true         # Set to true to enable additional apps installation

# Enable custom applications
enable_custom_apps: false

# Command execution settings
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
global_grafana_service_type: LoadBalancer       # Service type for Grafana (accessible from outside)
global_grafana_service_name: prometheus-grafana # Service name for accessing Grafana globally
global_prometheus_namespace: egs-monitoring     # Namespace where Prometheus is globally deployed
global_prometheus_service_name: prometheus-kube-prometheus-prometheus # Service name for accessing Prometheus globally
global_prometheus_service_type: LoadBalancer    # Service type for Prometheus (accessible from outside)

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
      imageRegistry: $IMAGE_REGISTRY   # Docker registry for the images
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
      imageRegistry: $IMAGE_REGISTRY   # Docker registry for the UI images
    kubeslice:
      prometheus:
        url: http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090  # Prometheus URL for monitoring
      uiproxy:
        service:
          type: $UI_SERVICE_TYPE                  # Service type for the UI proxy
        labels:
          app: kubeslice-ui-proxy
        annotations: {}

        ingress:
          enabled: false
          servicePort: 443
          className: ""
          hosts:
            - host: ui.kubeslice.com
              paths:
                - path: /
                  pathType: Prefix
          tls: []
          annotations: {}
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
  - name: "$CLUSTER_NAME"                           # Worker name
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
        imageRegistry: $IMAGE_REGISTRY # Docker registry for worker images
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



#### Define Projects ####
projects:
  - name: "$PROJECT_NAME"                              # Name of the Kubeslice project
    username: "admin"                           # Username for accessing the Kubeslice project

#### Define Cluster Registration ####
cluster_registration:
  - cluster_name: "$CLUSTER_NAME"                    # Name of the cluster to be registered
    project_name: "$PROJECT_NAME"                      # Name of the project to associate with the cluster
    #### Telemetry Settings ####
    telemetry:
      enabled: true                             # Enable telemetry for this cluster
      endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090" # Telemetry endpoint
      telemetryProvider: "prometheus"           # Telemetry provider (Prometheus in this case)
    #### Geo-Location Settings ####
    geoLocation:
      cloudProvider: "$CLOUD_PROVIDER"              # Cloud provider for this cluster (e.g., GCP)
      cloudRegion: "$CLOUD_REGION"                # Cloud region for this cluster (e.g., us-central1)

#### Define Additional Applications to Install ####
additional_apps:
  - name: "gpu-operator"                       # Name of the application
    skip_installation: false                   # Do not skip the installation of the GPU operator
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
      driver:
        enabled: false
    helm_flags: "--debug"                              # Additional Helm flags for this application's installation
    verify_install: false                       # Verify the installation of the GPU operator
    verify_install_timeout: 600                 # Timeout for verification (in seconds)
    skip_on_verify_fail: true                   # Skip the step if verification fails
    enable_troubleshoot: false                  # Enable troubleshooting mode for additional logs and checks

  - name: "prometheus"                         # Name of the application
    skip_installation: false                   # Do not skip the installation of Prometheus
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
          type: LoadBalancer                     # Service type for Prometheus
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
          type: LoadBalancer                  # Service type for Grafana
        persistence:
          enabled: false                      # Disable persistence
          size: 1Gi                           # Default persistence size
    helm_flags: "--debug"                             # Additional Helm flags for this application's installation
    verify_install: false                      # Verify the installation of Prometheus
    verify_install_timeout: 600                # Timeout for verification (in seconds)
    skip_on_verify_fail: true                  # Skip the step if verification fails
    enable_troubleshoot: false                 # Enable troubleshooting mode for additional logs and checks

  - name: "postgresql"                         # Name of the application
    skip_installation: false                   # Do not skip the installation of PostgreSQL
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
EOF
    
    print_success "Generated full configuration: $OUTPUT_CONFIG"
}

# Function to display next steps
show_next_steps() {
    echo ""
    echo "=============================================="
    echo "   📋 Next Steps"
    echo "=============================================="
    echo ""
    print_info "1. Review the generated configuration file: egs-installer-config.yaml"
    print_info "2. Run the installation:"
    echo ""
    echo "   ./egs-installer.sh --input-yaml egs-installer-config.yaml"
    echo ""
    print_info "3. After installation, access the UI:"
    echo ""
    echo "   kubectl get svc -n kubeslice-controller kubeslice-ui-proxy"
    echo ""
    print_warning "Note: Installation may take 10-15 minutes depending on your cluster."
    echo ""
}

# Main execution flow
main() {
    local AUTO_INSTALL=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-install)
                AUTO_INSTALL=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --auto-install       Automatically run the installer after generating config"
                echo "  --help, -h           Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                   # Generate config with auto-detection (review before install)"
                echo "  $0 --auto-install    # Generate config and install immediately"
                echo ""
                echo "Zero-Config Installation:"
                echo "  This script auto-detects your Kubernetes context and cluster settings."
                echo "  No configuration file is needed!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_info "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Step 1: Check prerequisites
    check_prerequisites
    echo ""
    
    # Step 2: Auto-detect Kubernetes context
    auto_detect_kube_context
    echo ""
    
    # Step 3: Detect cluster capabilities
    detect_cluster_capabilities
    echo ""
    
    # Step 4: Generate full configuration
    generate_full_config "egs-installer-config.yaml"
    echo ""
    
    # Step 5: Show next steps or auto-install
    if [ "$AUTO_INSTALL" = true ]; then
        print_info "Auto-install mode enabled. Running EGS installer..."
        echo ""
        
        if [ -f "./egs-installer.sh" ]; then
            ./egs-installer.sh --input-yaml egs-installer-config.yaml
        else
            print_error "egs-installer.sh not found in current directory!"
            print_info "Please download the full EGS installation package."
            exit 1
        fi
    else
        show_next_steps
    fi
    
    print_success "EGS Simple Installer completed successfully!"
}

# Run main function
main "$@"

