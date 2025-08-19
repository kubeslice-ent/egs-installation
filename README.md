---
# 🌐 EGS Installer Script

## 🚀 Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

---

## 📄 EGS Documents

- 📖 For the EGS platform overview, please see the [Platform Overview Documentation](https://docs.avesha.io/) 🌐  
- 🔧 For the Admin guide, please see the [Admin Guide Documentation](https://docs.avesha.io/) 🛠️  
- 👤 For the User guide, please see the [User Guide Documentation](https://docs.avesha.io/) 📚  
- 🛠️ For the Installation guide, please see the documentation on [Installation Guide Documentation](https://github.com/kubeslice-ent/egs-installation) 💻  
- 📝 For Avesha registration, please complete the [Avesha Registration](https://avesha.io/kubeslice-registration) process 🔑  
- ✅ For preflight checks, please refer to the [EGS Preflight Check Documentation](https://github.com/kubeslice-ent/egs-installation?tab=readme-ov-file#egs-preflight-check-script) 🔍  
- 📋 For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](https://github.com/kubeslice-ent/egs-installation#token-retrieval) 🔒  
- 🗂️ For precreate required namespace, please refer to the [Namespace Creation Script Documentation](https://github.com/kubeslice-ent/egs-installation#namespace-creation) 🗂️  

---  

## Getting Started

### Prerequisites

Before you begin, ensure the following steps are completed:

1. **📝 Registration:**
   - Complete the registration process at [Avesha Registration](https://avesha.io/kubeslice-registration) to receive the image pull secrets required for running the script.

2. **🔧 Required Binaries:**
   - Verify that the following binaries are installed and available in your system's `PATH`:
     - **yq** 📄 (minimum version: 4.44.2)
     - **helm** 🛠️ (minimum version: 3.15.0)
     - **kubectl** ⚙️ (minimum version: 1.23.6)
     - **jq** 📦 (minimum version: 1.6.0)

3. **🌐 Kubernetes Access:**
   - Confirm that you have administrative access to the necessary Kubernetes clusters and the appropriate `kubeconfig` files are available.

4. **📂 Clone the Repository:**
   - Start by cloning the EGS installation Git repository:
     ```bash
     git clone https://github.com/kubeslice-ent/egs-installation
     ```

5. **✅ Run EGS Preflight Check Script (Optional):**
   - To ensure your environment meets all installation requirements, you can optionally run the **EGS Preflight Check Script**.
     - Refer to the [EGS Preflight Check Guide](https://github.com/kubeslice-ent/egs-installation?tab=readme-ov-file#egs-preflight-check-script) for detailed instructions.
     - Example command:
       ```bash
       ./egs-preflight-check.sh \
         --kubeconfig ~/.kube/config \
         --kubecontext-list context1,context2
       ```
     - This step validates namespaces, permissions, PVCs, and services, helping to identify and resolve potential issues before installation.

6. **🗂️ Pre-create Required Namespaces (Optional):**
   - If your cluster enforces namespace creation policies, pre-create the namespaces required for installation before running the script.
     - Use the provided namespace creation script with the appropriate configuration to create the necessary namespaces:
       - Refer to the [Namespace Creation Script](https://github.com/kubeslice-ent/egs-installation#namespace-creation) for details.
     - Example command:
       ```bash
       ./create-namespaces.sh \
         --input-yaml namespace-input.yaml \
         --kubeconfig ~/.kube/config \
         --kubecontext-list context1,context2
       ```
     - Ensure that all required annotations and labels for policy enforcement are correctly configured in the YAML file.

7. **🚀 Install Prerequisites for EGS (Optional):**
   - To install prerequisites like GPU Operator, Prometheus for EGS inventory, and PostgreSQL for cost information visibility, you can run the **Prerequisites Installer Script**:
     - Example command:
       ```bash
       ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
       ```
     - **Note:** This step is optional but recommended if an existing instance of these services is not already running and configured. If skipped, some features might be broken or unavailable.

---

## 🛠️ Installation Steps

### 1. **📂 Clone the Repository:**
   - Start by cloning the EGS installation Git repository:
     ```bash
     git clone https://github.com/kubeslice-ent/egs-installation
     ```

### 2. **📝 Modify the Configuration File (Mandatory):**
   - Navigate to the cloned repository and locate the input configuration YAML file `egs-installer-config.yaml`.
   - Update the following mandatory parameters:

     - **🔑 Image Pull Secrets (Mandatory):**
       - Insert the image pull secrets received via email as part of the registration process:
         ```yaml
         global_image_pull_secret:
           repository: "https://index.docker.io/v1/"
           username: ""  # Global Docker registry username (MANDATORY)
           password: ""  # Global Docker registry password (MANDATORY)
         ```

     - **⚙️ Kubernetes Configuration (Mandatory) :**
       - Set the global `kubeconfig` and `kubecontext` parameters:
         ```yaml
         global_kubeconfig: ""  # Relative path to global kubeconfig file from base_path default is script directory (MANDATORY)
         global_kubecontext: ""  # Global kubecontext (MANDATORY)
         use_global_context: true  # If true, use the global kubecontext for all operations by default
         ```

     - **⚙️ Additional Configuration (Optional):**
       - Configure installation stages and additional applications:
         ```yaml
         # Enable or disable specific stages of the installation
         enable_install_controller: true               # Enable the installation of the Kubeslice controller
         enable_install_ui: true                       # Enable the installation of the Kubeslice UI
         enable_install_worker: true                   # Enable the installation of Kubeslice workers

         # Enable or disable the installation of additional applications (prometheus, gpu-operator, postgresql)
         enable_install_additional_apps: false          # Set to true to enable additional apps installation

         # Enable custom applications
         # Set this to true if you want to allow custom applications to be deployed.
         # This is specifically useful for enabling NVIDIA driver installation on your nodes.
         enable_custom_apps: false

         # Command execution settings
         # Set this to true to allow the execution of commands for configuring NVIDIA MIG.
         # This includes modifications to the NVIDIA ClusterPolicy and applying node labels
         # based on the MIG strategy defined in the YAML (e.g., single or mixed strategy).
         run_commands: false
         ```

         ⚙️ **PostgreSQL Connection Configuration (*Mandatory only if `kubetallyEnabled` is set to `true` (Optional otherwise)*)** 

         📌 **Note:** The secret is created in the `kubeslice-controller` namespace during installation. If you prefer to use a pre-created secret, leave all values empty and specify only the secret name.
         - **`postgresSecretName`**: The name of the Kubernetes Secret containing PostgreSQL credentials.
         - The secret must contain the following key-value pairs:
           
           | Key               | Description                                  |
           |-------------------|----------------------------------------------|
           | `postgresAddr`    | The PostgreSQL service endpoint              |
           | `postgresPort`    | The PostgreSQL service port (default: 5432)  |
           | `postgresUser`    | The PostgreSQL username                      |
           | `postgresPassword`| The PostgreSQL password                      |
           | `postgresDB`      | The PostgreSQL database name                 |
           | `postgresSslmode` | The SSL mode for PostgreSQL connection       |
           
    
         **Example Configuration to use pre-created secret**
         
            ```yaml
            postgresSecretName: kubetally-db-credentials   # Secret name in kubeslice-controller namespace for PostgreSQL credentials.
                                                           # Created by install, all the below values must be specified.
                                                           # Alternatively, leave all values empty and provide a pre-created secret.
            postgresAddr: ""  # Change to your PostgreSQL endpoint
            postgresPort: ""   # Change this to match your PostgreSQL service port
            postgresUser: ""  # Set your PostgreSQL username
            postgresPassword: ""  # Set your PostgreSQL password
            postgresDB: ""  # Set your PostgreSQL database name
            postgresSslmode: ""  # Change this based on your SSL configuration
            ```
            
         
           📌 **Alternatively**, if you provide all values with a secret name as specified for `postgresSecretName` in the values file, using the key-value format below, it will automatically create the specified secret in the `kubeslice-controller` namespace with the provided values.
   
            **Example Configuration to auto-create secret with provided values**
            
          ```yaml
              postgresSecretName: kubetally-db-credentials   # Secret name in kubeslice-controller namespace for PostgreSQL credentials created by install, all the below values must be specified 
                                                             # then a secret will be created with specified name. 
                                                             # alternatively you can make all below values empty and provide a pre-created secret name with below connection details format
              postgresAddr: "kt-postgresql.kt-postgresql.svc.cluster.local" # Change this Address to your postgresql endpoint
              postgresPort: 5432                     # Change this Port for the PostgreSQL service to your values 
              postgresUser: "postgres"               # Change this PostgreSQL username to your values
              postgresPassword: "postgres"           # Change this PostgreSQL password to your value
              postgresDB: "postgres"                 # Change this PostgreSQL database name to your value
              postgresSslmode: disable               # Change this SSL mode for PostgreSQL connection to your value
          ```
         
### 3. **🚀 Run the Installation Script:**
   - Execute the installation script using the following command:
     ```bash
     ./egs-installer.sh --input-yaml egs-installer-config.yaml
     ```

### 4. **🔄 Mandatory for Multiple Worker Clusters: Update the Inline Values**

   This section is **mandatory** to ensure proper configuration of monitoring and dashboard URLs. Follow the steps carefully:
   
   #### **⚠️ Set the `global_auto_fetch_endpoint` Flag Appropriately**
   
   1. **🌐 Single-Cluster Setups**  
      - If the **controller** and **worker** are in the same cluster, all the below setting can be ignored, and no change is required
   
   2. **Default Setting**  
      - By default, `global_auto_fetch_endpoint` is set to `false`. If you enable it (`true`), ensure the following configurations:  
        - **💡 Worker Cluster Service Details:** Provide the service details for each worker cluster to fetch the correct monitoring endpoints.  
        - **📊 Multiple Worker Clusters:** Ensure the service endpoints (e.g., Grafana and Prometheus) are accessible from the **controller cluster**.  
   
      #### **🖥 Global Monitoring Endpoint Settings**
   
      These configurations are **mandatory** if `global_auto_fetch_endpoint` is set to `true`. Update the following in your `egs-installer-config.yaml`:
      
      ```yaml
      # Global monitoring endpoint settings
      global_auto_fetch_endpoint: true               # Enable automatic fetching of monitoring endpoints globally
      global_grafana_namespace: egs-monitoring        # Namespace where Grafana is globally deployed
      global_grafana_service_type: ClusterIP          # Service type for Grafana (accessible only within the cluster)
      global_grafana_service_name: prometheus-grafana # Service name for accessing Grafana globally
      global_prometheus_namespace: egs-monitoring     # Namespace where Prometheus is globally deployed
      global_prometheus_service_name: prometheus-kube-prometheus-prometheus # Service name for accessing Prometheus globally
      global_prometheus_service_type: ClusterIP       # Service type for Prometheus (accessible only within the cluster)
      ```
   
   3. **📢 Update `inline-values` for Multi-Cluster Setups**
   
   If `global_auto_fetch_endpoint` is `false` and the **controller** and **worker** are in different clusters, follow these steps:
   
   1. **🗒 Fetch the Grafana & Prometheus External IP**  
      Use the following command to get the **Grafana LoadBalancer External IP**:  
   
      ```bash
      kubectl get svc prometheus-grafana -n monitoring
      kubectl get svc prometheus -n monitoring
      ```
   
   2. **✏ Update the `egs-installer-config.yaml`**  
      Replace `<grafana-lb>` and <prometheus-lb> with the Grafana and prometheus **LoadBalancer External IP or NodePort** in the `inline_values` section:  
   
      ```yaml
      inline_values:  # Inline Helm values for the worker chart
        kubesliceNetworking:
          enabled: false  # Disable Kubeslice networking for this worker
        egs:
          prometheusEndpoint: "http://<prometheus-lb>"  # Prometheus endpoint
          grafanaDashboardBaseUrl: "http://<grafana-lb>/d/Oxed_c6Wz"  # Replace <grafana-lb> with the actual External IP
        metrics:
          insecure: true  # Allow insecure connections for metrics
      ```

### 5. **🔄 Run the Installation Script Again:**
   - Apply the updated configuration by running the installation script again:
     ```bash
     ./egs-installer.sh --input-yaml egs-installer-config.yaml
     ```

### 6. **➕ Adding Additional Workers (Optional) **

   To add another worker to your EGS setup, you need to make an entry in the `kubeslice_worker_egs` section of your `egs-installer-config.yaml` file. Follow these steps:

   #### **📝 Step 1: Add Worker Configuration**
   
   Add a new worker entry to the `kubeslice_worker_egs` array in your configuration file:
   
   ```yaml
   kubeslice_worker_egs:
     - name: "worker-1"                           # Existing worker
       # ... existing configuration ...
     
     - name: "worker-2"                           # New worker
       use_global_kubeconfig: true                # Use global kubeconfig for this worker
       kubeconfig: ""                             # Path to the kubeconfig file specific to the worker, if empty, uses the global kubeconfig
       kubecontext: ""                            # Kubecontext specific to the worker; if empty, uses the global context
       skip_installation: false                   # Do not skip the installation of the worker
       specific_use_local_charts: true            # Override to use local charts for this worker
       namespace: "kubeslice-system"              # Kubernetes namespace for this worker
       release: "egs-worker-2"                    # Helm release name for the worker (must be unique)
       chart: "kubeslice-worker-egs"              # Helm chart name for the worker
       inline_values:                             # Inline Helm values for the worker chart
         global:
           imageRegistry: docker.io/aveshasystems # Docker registry for worker images
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
       helm_flags: "--wait --timeout 5m --debug" # Additional Helm flags for the worker installation
       verify_install: true                      # Verify the installation of the worker
       verify_install_timeout: 60                # Timeout for the worker installation verification (in seconds)
       skip_on_verify_fail: false                # Do not skip if worker verification fails
       enable_troubleshoot: false                # Enable troubleshooting mode for additional logs and checks
   ```

   #### **📝 Step 2: Add Cluster Registration**
   
   Add a corresponding entry in the `cluster_registration` section:
   
   ```yaml
   cluster_registration:
     - cluster_name: "worker-1"                    # Existing cluster
       project_name: "avesha"                      # Name of the project to associate with the cluster
       telemetry:
         enabled: true                             # Enable telemetry for this cluster
         endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090" # Telemetry endpoint
         telemetryProvider: "prometheus"           # Telemetry provider (Prometheus in this case)
       geoLocation:
         cloudProvider: ""                         # Cloud provider for this cluster (e.g., GCP)
         cloudRegion: ""                           # Cloud region for this cluster (e.g., us-central1)
     
     - cluster_name: "worker-2"                    # New cluster
       project_name: "avesha"                      # Name of the project to associate with the cluster
       telemetry:
         enabled: true                             # Enable telemetry for this cluster
         endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090" # Telemetry endpoint
         telemetryProvider: "prometheus"           # Telemetry provider (Prometheus in this case)
       geoLocation:
         cloudProvider: ""                         # Cloud provider for this cluster (e.g., GCP)
         cloudRegion: ""                           # Cloud region for this cluster (e.g., us-central1)
   ```

   #### **⚠️ Important Notes:**
   
   - **🔑 Unique Release Names:** Ensure each worker has a unique `release` name to avoid conflicts during installation.
   - **🌐 Cluster Endpoints:** Update the `prometheusEndpoint` and `grafanaDashboardBaseUrl` with the correct endpoints for the new worker cluster.
   - **🔧 Kubeconfig:** If the new worker is in a different cluster, provide the appropriate `kubeconfig` and `kubecontext` values.
   - **📊 Monitoring:** Ensure the monitoring endpoints (Prometheus/Grafana) are accessible from the controller cluster for proper telemetry.
   - **🔗 Prometheus Accessibility:** **Critical:** Make sure Prometheus endpoints are accessible from the controller cluster. The controller needs to reach the Prometheus service in each worker cluster to collect metrics and telemetry data. If the worker clusters are in different networks, ensure proper network connectivity or use LoadBalancer/NodePort services for Prometheus.

   #### **🚀 Step 3: Run the Installation Script**
   
   After adding the new worker configuration, run the installation script to deploy the additional worker:
   
   ```bash
   ./egs-installer.sh --input-yaml egs-installer-config.yaml
   ```

---

### 🗑️ Uninstallation Steps

**⚠️ Important Note:**  
The uninstallation script will delete **all resources** associated with EGS, including **slices**, **GPRs**, and **all custom resources provisioned by egs**. Use this script with caution, as it performs a complete cleanup of the egs setup.

**Run the Cleanup Script**  
- Execute the uninstallation script using the following command:  
  ```bash
  ./egs-uninstall.sh --input-yaml egs-installer-config.yaml
  ```

--- 
## 🛠️ Configuration details

The script requires a YAML configuration file to define various parameters and settings for the installation process. Below is an example configuration file (`egs-installer-config.yaml`) with descriptions for each section.

## ⚠️ Warning
**Do not copy the YAML configuration directly from this README.** Hash characters (`#`) used for comments may not be interpreted correctly. Always refer to the actual `egs-installer-config.yaml` file available in the repository for accurate configuration.

## YAML Configuration File

```yaml
# Base path to the root directory of your cloned repository
base_path: ""  # If left empty, the script will use the relative path to the script as the base path

# Precheck options
precheck: true  # Run general prechecks before starting the installation
kubeslice_precheck: true  # Run specific prechecks for Kubeslice components

# Global installation verification settings
verify_install: true  # Enable verification of installations globally
verify_install_timeout: 600  # Timeout for global installation verification (in seconds)
skip_on_verify_fail: false  # If set to true, skip steps where verification fails, otherwise exit on failure

# Helm repository settings
use_local_charts: true  # Use local Helm charts instead of fetching them from a repository
local_charts_path: "charts"  # Path to the directory containing local Helm charts
global_helm_repo_url: ""  # URL for the global Helm repository (if not using local charts)
global_helm_username: ""  # Username for accessing the global Helm repository
global_helm_password: ""  # Password for accessing the global Helm repository
readd_helm_repos: true  # Re-add Helm repositories even if they are already present

# List of required binaries for the installation process
required_binaries:
  - yq  # YAML processor
  - helm  # Helm package manager
  - jq  # JSON processor
  - kubectl  # Kubernetes command-line tool

# Global image pull secret settings
global_image_pull_secret:
  repository: "https://index.docker.io/v1/"  # Docker registry URL
  username: ""  # Global Docker registry username
  password: ""  # Global Docker registry password

# Node labeling settings
add_node_label: true  # Enable node labeling during installation

# Kubeconfig settings
global_kubeconfig: ""  # Path to the global kubeconfig file (used if no specific kubeconfig is provided)
global_kubecontext: ""  # Global kubecontext to use; if empty, the default context will be used
use_global_context: true  # If true, use the global kubecontext for all operations by default

# Enable or disable specific stages of the installation
enable_prepare_worker_values_file: true  # Prepare the worker values file for Helm charts
enable_install_controller: true  # Enable the installation of the Kubeslice controller
enable_install_ui: true  # Enable the installation of the Kubeslice UI
enable_install_worker: true  # Enable the installation of Kubeslice workers

# Kubeslice controller installation settings
kubeslice_controller_egs:
  skip_installation: false  # Do not skip the installation of the controller
  use_global_kubeconfig: true  # Use global kubeconfig for the controller installation
  specific_use_local_charts: true  # Override to use local charts for the controller
  kubeconfig: ""  # Path to the kubeconfig file specific to the controller
  kubecontext: ""  # Kubecontext specific to the controller; if empty, uses the global context
  namespace: "kubeslice-controller"  # Kubernetes namespace where the controller will be installed
  release: "kubeslice-controller-release"  # Helm release name for the controller
  chart: "kubeslice-controller-egs"  # Helm chart name for the controller
  inline_values:  # Inline Helm values for the controller chart
    kubeslice:
      controller: 
        endpoint: ""  # Endpoint of the controller API server; auto-fetched if left empty
        migration:
          minio:
            install: "false"  # Do not install MinIO during migration
  helm_flags: "--timeout 10m --atomic"  # Additional Helm flags for the installation
  verify_install: true  # Verify the installation of the controller
  verify_install_timeout: 30  # Timeout for the controller installation verification (in seconds)
  skip_on_verify_fail: false  # If verification fails, do not skip the step

# Kubeslice UI installation settings
kubeslice_ui_egs:
  skip_installation: false  # Do not skip the installation of the UI
  use_global_kubeconfig: true  # Use global kubeconfig for the UI installation
  namespace: "kubeslice-controller"  # Kubernetes namespace where the UI will be installed
  release: "kubeslice-ui"  # Helm release name for the UI
  chart: "kubeslice-ui-egs"  # Helm chart name for the UI
  helm_flags: "--atomic"  # Additional Helm flags for the UI installation
  verify_install: true  # Verify the installation of the UI
  verify_install_timeout: 50  # Timeout for the UI installation verification (in seconds)
  skip_on_verify_fail: false  # If UI verification fails, do not skip the step
  specific_use_local_charts: true  # Override to use local charts for the UI

# Kubeslice worker installation settings
kubeslice_worker_egs:
  - name: "worker-1"
    use_global_kubeconfig: true  # Use global kubeconfig for this worker
    skip_installation: false  # Do not skip the installation of the worker
    specific_use_local_charts: true  # Override to use local charts for this worker
    namespace: "kubeslice-system"  # Kubernetes namespace for this worker
    release: "kubeslice-worker1-release"  # Helm release name for the worker
    chart: "kubeslice-worker-egs"  # Helm chart name for the worker
    inline_values:  # Inline Helm values for the worker chart
      cluster:
        name: worker-1
        endpoint: <worker-cluster-endpoint> # Cluster Endpoint Accessible from Controller Cluster
      kubesliceNetworking:
        enabled: false  # Disable Kubeslice networking for this worker
      egs:
        prometheusEndpoint: "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"  # Prometheus endpoint
        grafanaDashboardBaseUrl: "http://grafana-test"  # Grafana dashboard base URL
      metrics:
        insecure: true  # Allow insecure connections for metrics
    helm_flags: "--atomic"  # Additional Helm flags for the worker installation
    verify_install: true  # Verify the installation of the worker
    verify_install_timeout: 60  # Timeout for the worker installation verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if worker verification fails

# Project and cluster registration settings
enable_project_creation: true  # Enable project creation in Kubeslice
enable_cluster_registration: true  # Enable cluster registration in Kubeslice

# Define projects
projects:
  - name: "avesha"
    username: "admin"  # Username for accessing the Kubeslice project

# Define cluster registration
cluster_registration:
  - cluster_name: "worker-1"
    project_name: "avesha"
    telemetry:
      enabled: true  # Enable telemetry for this cluster
      endpoint: "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"  # Telemetry endpoint
      telemetryProvider: "prometheus"  # Telemetry provider (Prometheus in this case)
    geoLocation:
      cloudProvider: "GCP"  # Cloud provider for this cluster (e.g., GCP)
      cloudRegion: "us-central1"  # Cloud region for this cluster (e.g., us-central1)

# Enable or disable the installation of additional applications
enable_install_additional_apps: true  # Set to true to enable additional apps installation

# Define additional applications to install
additional_apps:
  - name: "gpu-operator"
    skip_installation: false  # Do not skip the installation of the GPU operator
    use_global_kubeconfig: true  # Use global kubeconfig for this application
    namespace: "gpu-operator"  # Namespace where the GPU operator will be installed
    release: "gpu-operator-release"  # Helm release name for the GPU operator
    chart: "gpu-operator"  # Helm chart name for the GPU operator
    repo_url: "https://helm.ngc.nvidia.com/nvidia"  # Helm repository URL for the GPU operator
    version: "v24.6.0"  # Version of the GPU operator to install
    specific_use_local_charts: true  # Use local charts for this application
    inline_values:  # Inline Helm values for the GPU operator chart
      hostPaths:
        driverInstallDir: "/home/kubernetes/bin/nvidia"
      toolkit:
        installDir: "/home/kubernetes/bin/nvidia"
      cdi:
        enabled: true
        default: true
      driver:
        enabled: false
    helm_flags: "--wait"  # Additional Helm flags for this application's installation
    verify_install: true  # Verify the installation of the GPU operator
    verify_install_timeout: 600  # Timeout for verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if verification fails

  - name: "prometheus"
    skip_installation: false  # Do not skip the installation of Prometheus
    use_global_kubeconfig: true  # Use global kubeconfig for Prometheus
    namespace: "monitoring"  # Namespace where Prometheus will be installed
    release: "prometheus"  # Helm release name for Prometheus
    chart: "kube-prometheus-stack"  # Helm chart name for Prometheus
    repo_url: "https://prometheus-community.github.io/helm-charts"  # Helm repository URL for Prometheus
    version: "v45.0.0"  # Version of the Prometheus stack to install
    specific_use_local_charts: true  # Use local charts for this application
    values_file: ""  # Path to an external values file, if any
    inline_values:  # Inline Helm values for Prometheus
      prometheus:
        service:
          type: LoadBalancer
          port: 32270
        prometheusSpec:
          additionalScrapeConfigs:
          - job_name: tgi
            kubernetes_sd_configs:
            - role: endpoints
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod_name
            - source_labels: [__meta_kubernetes_pod_container_name]
              target_label: container_name
            static_configs:
              - targets: ["llm-inference.demo.svc.cluster.local:80"]
          - job_name: gpu-metrics
            scrape_interval: 1s
            metrics_path: /metrics
            scheme: http
            kubernetes_sd_configs:
            - role: endpoints
              namespaces:
                names:
                - gpu-operator
            relabel_configs:
            - source_labels: [__meta_kubernetes_endpoints_name]
              action: drop
              regex: .*-node-feature-discovery-master
            - source_labels: [__meta_kubernetes_pod_node_name]
              action: replace
              target_label: kubernetes_node
      grafana:
        enabled: true
        grafana.ini:
          auth:
            disable_login_form: true
            disable_signout_menu: true
          auth.anonymous:
            enabled: true
            org_role: Viewer
        service:
          type: LoadBalancer
        persistence:
          enabled: true
          size: 1Gi
    helm_flags: "--wait"  # Additional Helm flags for this application's installation
    verify_install: true  # Verify the installation of Prometheus
    verify_install_timeout: 600  # Timeout for verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if verification fails

# Enable custom applications
enable_custom_apps: true  # Set to true to enable custom apps

# Define custom applications and their associated manifests
manifests:
  - appname: gpu-operator-quota
    manifest: ""  # URL or path to the manifest file; if empty, inline YAML is used
    overrides_yaml: ""  # Path to an external YAML file with overrides, if any
    inline_yaml: |  # Inline YAML content for this custom application
      apiVersion: v1
      kind: ResourceQuota
      metadata:
        name: gpu-operator-quota
      spec:
        hard:
          pods: 100
        scopeSelector:
          matchExpressions:
          - operator: In
            scopeName: PriorityClass
            values:
              - system-node-critical
              - system-cluster-critical
    use_global_kubeconfig: true  # Use global kubeconfig for this application
    skip_installation: false  # Do not skip the installation of this application
    verify_install: true  # Verify the installation of this application
    verify_install_timeout: 30  # Timeout for verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if verification fails
    namespace: gpu-operator  # Namespace for this application
    kubeconfig: ""  # Path to the kubeconfig file specific to this application
    kubecontext: ""  # Kubecontext specific to this application; uses global context if empty

  - appname: nvidia-driver-installer
    manifest: https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml
    overrides_yaml: ""  # Path to an external YAML file with overrides, if any
    inline_yaml: null  # Inline YAML content for this application
    use_global_kubeconfig: true  # Use global kubeconfig for this application
    skip_installation: false  # Do not skip the installation of this application
    verify_install: true  # Verify the installation of this application
    verify_install_timeout: 200  # Timeout for verification (in seconds)
    skip_on_verify_fail: true  # Skip if verification fails
    namespace: kube-system  # Namespace for this application
    
# Command execution settings
run_commands: true  # Enable the execution of commands defined in the YAML

# Define commands to execute
commands:
  - use_global_kubeconfig: true  # Use global kubeconfig for these commands
    skip_installation: false  # Do not skip the execution of these commands
    verify_install: true  # Verify the execution of these commands
    verify_install_timeout: 200  # Timeout for verification (in seconds)
    skip_on_verify_fail: true  # Skip if command verification fails
    namespace: kube-system  # Namespace context for these commands
    command_stream: |  # Commands to execute
      kubectl get nodes
      kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name' | xargs -I {} kubectl label nodes {} gke-no-default-nvidia-gpu-device-plugin=true --overwrite


```



### Explanation of YAML Fields

| **Field**                           | **Description**                                                                                                   | **Default/Example**                                                                                 |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| `base_path`                         | Base path to the root directory of the cloned repository. If empty, the script uses the relative path to the script as the base path. | `""` (empty string)                                                                                 |
| `precheck`                          | Run prechecks before installation to validate the environment and required binaries.                              | `true`                                                                                              |
| `kubeslice_precheck`                | Run specific prechecks for Kubeslice components, including cluster access validation and node label checks.       | `true`                                                                                              |
| `verify_install`                    | Enable installation verification globally, ensuring that all installed components are running as expected.        | `true`                                                                                              |
| `verify_install_timeout`            | Global timeout for verification in seconds. Determines how long the script waits for all components to be verified as running. | `600` (10 minutes)                                                                                  |
| `skip_on_verify_fail`               | Decide whether to skip further steps or exit the script if verification fails globally.                            | `false`                                                                                             |
| `global_helm_repo_url`              | URL of the global Helm repository from which charts will be pulled.                                               | <small>[Helm Repository](https://smartscaler.nexus.aveshalabs.io/repository/kubeslice-egs-helm-ent-prod)</small>                     |
| `global_helm_username`              | Username for accessing the global Helm repository, if required.                                                   | `""`                                                                                                |
| `global_helm_password`              | Password for accessing the global Helm repository, if required.                                                   | `""`                                                                                                |
| `readd_helm_repos`                  | Re-add Helm repositories if they already exist to ensure the latest repository configuration is used.             | `true`                                                                                              |
| `required_binaries`                 | List of binaries that are required for the installation process. The script will check for these binaries and exit if any are missing. | `yq`, `helm`, `kubectl`                                                                             |
| `global_image_pull_secret`          | Global image pull secret settings for accessing private Docker registries.                                         | Repository: `https://index.docker.io/v1/`, Username: `""`, Password: `""`                           |
| `add_node_label`                    | Enable node labeling during installation, useful for reserving nodes for specific tasks.                           | `true`                                                                                              |
| `global_kubeconfig`                 | Relative path to the global kubeconfig file used to access Kubernetes clusters.                                    | `""` (empty string)                                                                                 |
| `use_local_charts`                  | Use local Helm charts instead of pulling them from a repository, useful for testing or restricted access scenarios. | `true`                                                                                              |
| `local_charts_path`                 | Relative path to the local Helm charts directory, used only if `use_local_charts` is set to `true`.               | `"charts"`                                                                                          |
| `global_kubecontext`                | Global kubecontext to be used across all Kubernetes interactions. If empty, the default context will be used.     | `""` (empty string)                                                                                 |
| `use_global_context`                | Use the global kubecontext by default for all operations unless a specific context is provided for a component.   | `true`                                                                                              |
| `enable_prepare_worker_values_file` | Enable the preparation of the worker values file before installation, necessary if the worker configuration depends on dynamic values. | `true`                                                                                              |
| `enable_install_controller`         | Enable the installation of the Kubeslice controller.                                                               | `true`                                                                                              |
| `enable_install_ui`                 | Enable the installation of the Kubeslice UI.                                                                       | `true`                                                                                              |
| `enable_install_worker`             | Enable the installation of the Kubeslice worker.                                                                   | `true`                                                                                              |

#### `kubeslice_controller_egs` Subfields

| **Subfield**                  | **Description**                                                                                         | **Default/Example**                                                             |
|-------------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `skip_installation`           | Skip the installation of the Kubeslice controller if it's already installed or not needed.               | `false`                                                                         |
| `use_global_kubeconfig`       | Use the global kubeconfig file for the controller installation.                                          | `true`                                                                          |
| `specific_use_local_charts`   | Use local charts specifically for the controller installation, overriding the global `use_local_charts` setting. | `true`                                                                          |
| `kubeconfig`                  | Relative path to the kubeconfig file for the controller. Overrides the global kubeconfig if specified.    | `""` (empty string)                                                             |
| `kubecontext`                 | Specific kubecontext for the controller installation, uses the global context if empty.                  | `""` (empty string)                                                             |
| `namespace`                   | Kubernetes namespace where the Kubeslice controller will be installed.                                   | `"kubeslice-controller"`                                                        |
| `release`                     | Helm release name for the Kubeslice controller.                                                          | `"kubeslice-controller-release"`                                                |
| `chart`                       | Helm chart name used for installing the Kubeslice controller.                                            | `"kubeslice-controller-egs"`                                                    |
| `inline_values`               | Inline values passed to the Helm chart during installation. For example, setting the controller endpoint. | `kubeslice.controller.endpoint: ""`                                             |
| `helm_flags`                  | Additional Helm flags for the controller installation, such as timeout and atomic deployment.            | `"--timeout 10m --atomic"`                                                      |
| `verify_install`              | Verify the installation of the Kubeslice controller after deployment.                                    | `true`                                                                          |
| `verify_install_timeout`      | Timeout for verifying the installation of the controller, in seconds.                                    | `30` (30 seconds)                                                               |
| `skip_on_verify_fail`         | Skip further steps or exit if the controller verification fails.                                         | `false`                                                                         |

#### `kubeslice_ui_egs` Subfields

| **Subfield**                | **Description**                                                                                           | **Default/Example**                                           |
|-----------------------------|-----------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| `skip_installation`         | Skip the installation of the Kubeslice UI if it's already installed or not needed.                         | `false`                                                       |
| `use_global_kubeconfig`     | Use the global kubeconfig file for the UI installation.                                                   | `true`                                                        |
| `specific_use_local_charts` | Use local charts specifically for the UI installation, overriding the global `use_local_charts` setting.  | `true`                                                        |
| `namespace`                 | Kubernetes namespace where the Kubeslice UI will be installed.                                            | `"kubeslice-controller"`                                      |
| `release`                   | Helm release name for the Kubeslice UI.                                                                   | `"kubeslice-ui"`                                              |
| `chart`                     | Helm chart name used for installing the Kubeslice UI.                                                     | `"kubeslice-ui-egs"`                                          |
| `helm_flags`                | Additional Helm flags for the UI installation, such as atomic deployment.                                 | `"--atomic"`                                                  |
| `verify_install`            | Verify the installation of the Kubeslice UI after deployment.                                             | `true`                                                        |
| `verify_install_timeout`    | Timeout for verifying the installation of the UI, in seconds.                                             | `50` (50 seconds)                                             |
| `skip_on_verify_fail`       | Skip further steps or exit if the UI verification fails.                                                  | `false`                                                       |

#### `kubeslice_worker_egs` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                                                         |
|-----------------------------|---------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `name`                      | Name of the worker node configuration.                                                                  | `"worker-1"`                                                                                                |
| `use_global_kubeconfig`     | Use the global kubeconfig file for the worker installation.                                             | `true`                                                                                                      |
| `skip_installation`         | Skip the installation of the worker if it's already installed or not needed.                            | `false`                                                                                                     |
| `specific_use_local_charts` | Use local charts specifically for the worker installation, overriding the global `use_local_charts` setting. | `true`                                                                                                      |
| `namespace`                 | Kubernetes namespace where the worker will be installed.                                                | `"kubeslice-system"`                                                                                        |
| `release`                   | Helm release name for the worker.                                                                       | `"kubeslice-worker1-release"`                                                                               |
| `chart`                     | Helm chart name used for installing the worker.                                                         | `"kubeslice-worker-egs"`                                                                                    |
| `inline_values`             | Inline values passed to the Helm chart during installation. For example, disabling networking and setting Prometheus endpoints. | `kubesliceNetworking.enabled: false`, `egs.prometheusEndpoint: "http://prometheus-test"`, `egs.grafanaDashboardBaseUrl: "http://grafana-test"`, `metrics.insecure: true` |
| `helm_flags`                | Additional Helm flags for the worker installation, such as atomic deployment.                           | `"--atomic"`                                                                                                |
| `verify_install`            | Verify the installation of the worker after deployment.                                                 | `true`                                                                                                      |
| `verify_install_timeout`    | Timeout for verifying the installation of the worker, in seconds.                                       | `60` (60 seconds)                                                                                           |
| `skip_on_verify_fail`       | Skip further steps or exit if the worker verification fails.                                            | `false`                                                                                                     |
#### `Custom App Manifests` Subfields

| **Field**                       | **Description**                                                                                                         | **Type**          | **Required** | **Example**                                                                                                         |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------|-------------------|--------------|---------------------------------------------------------------------------------------------------------------------|
| `manifests`                     | A list of manifest configurations. Each entry defines how a specific Kubernetes manifest should be applied.            | `list`            | Yes          | See below for individual fields.                                                                                    |
| `manifests[].appname`           | The name of the application or resource. Used for logging and identification purposes.                                   | `string`          | Yes          | `nginx-deployment`                                                                                                  |
| `manifests[].manifest`          | The path to the Kubernetes manifest file. Can be a local file or an HTTPS URL.                                          | `string`          | No           | `nginx/deployment.yaml` or `https://raw.githubusercontent.com/.../nginx-app.yaml`                                   |
| `manifests[].overrides_yaml`    | The path to a YAML file containing overrides for the base manifest. Merges with the base manifest before applying.      | `string`          | No           | `nginx/overrides.yaml`                                                                                              |
| `manifests[].inline_yaml`       | Inline YAML content to be merged with the base manifest. Allows for quick, in-line customization without separate files. | `string` (YAML)   | No           | See inline YAML example below.                                                                                      |
| `manifests[].use_global_kubeconfig` | Determines whether the global kubeconfig and context should be used. If `false`, specific kubeconfig and context must be provided. | `boolean`        | Yes          | `true`                                                                                                              |
| `manifests[].kubeconfig_path`   | Path to a specific Kubernetes configuration file to be used instead of the global kubeconfig.                           | `string`          | No           | `/path/to/specific/kubeconfig`                                                                                      |
| `manifests[].kubecontext`       | The context name in the specific Kubernetes configuration file to be used for this manifest.                            | `string`          | No           | `specific-context`                                                                                                  |
| `manifests[].skip_installation` | Whether to skip the installation of this manifest. Useful for conditional deployments.                                  | `boolean`         | Yes          | `false`                                                                                                             |
| `manifests[].verify_install`    | Whether to verify that the application or resource was successfully deployed.                                           | `boolean`         | Yes          | `true`                                                                                                              |
| `manifests[].verify_install_timeout` | The timeout in seconds for the installation verification.                                                        | `integer`         | Yes          | `60`                                                                                                                |
| `manifests[].skip_on_verify_fail` | Whether to skip the remaining operations if the verification fails.                                                  | `boolean`         | Yes          | `false`                                                                                                             |
| `manifests[].namespace`         | The Kubernetes namespace where the resources should be applied.                                                        | `string`          | Yes          | `nginx-namespace`                                                                                                   |


```
### 🧑‍💻 Script Usage
To run the script, use the following command:
```
```bash
./egs-installer.sh --input-yaml <yaml_file>
```


Replace `<yaml_file>` with the path to your YAML configuration file. For example:

```bash
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

### 💡 Command-Line Options

- `--input-yaml <yaml_file>`: Specifies the YAML configuration file to be used.
- `--help`: Displays usage information.


---

## 🔑 slice & admin Token Retrieval Script - `fetch_egs_slice_token.sh`

`fetch_egs_slice_token.sh` is a Bash script designed to retrieve tokens for Kubernetes slices and admin users within a specified project/namespace. This script can fetch read-only, read-write, and admin tokens based on the provided arguments, making it flexible for various Kubernetes authentication requirements.

## 📋 Usage

```bash
./fetch_egs_slice_token.sh -k <kubeconfig_absolute_path> [-s <slice_name>] -p <project_name> [-a] -u <username1,username2,...>
```

## 🔹 Parameters

- **`-k, --kubeconfig`** (required): Absolute path to the kubeconfig file used to connect to the Kubernetes cluster.
- **`-s, --slice`** (optional if `-a` is provided): Name of the slice for which the tokens are to be retrieved.
- **`-p, --project`** (required): Name of the project (namespace) where the slice is located.
- **`-a, --admin`** (optional): Fetch admin tokens for specified usernames (makes `--slice` optional).
- **`-u, --username`** (required with `-a`): Comma-separated list of usernames for fetching admin tokens.
- **`-h, --help`**: Display help message.

## 🚀 Examples

### 1️⃣ Fetching Slice Tokens Only

Retrieve read-only and read-write tokens for a specified slice:

```bash
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -s pool1 -p avesha
```

- **Explanation**: This command fetches tokens for the slice `pool1` in the namespace `kubeslice-avesha`.
- **Parameters**:
  - `-k /path/to/kubeconfig`: Specifies the path to the kubeconfig file.
  - `-s pool1`: Specifies the slice name (`pool1`).
  - `-p avesha`: Specifies the project/namespace name (`avesha`).

---

### 2️⃣ Fetching Admin Tokens Only 

Fetch admin tokens for specific users. When the `-a` flag is used, `--slice` becomes optional.

```bash
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -p avesha -a -u admin,dev
```

- **Explanation**: This command fetches admin tokens for both `admin` and `dev` users in the namespace `kubeslice-avesha`.
- **Parameters**:
  - `-k /path/to/kubeconfig`: Specifies the path to the kubeconfig file.
  - `-p avesha`: Specifies the project/namespace name (`avesha`).
  - `-a`: Indicates that we are fetching admin tokens.
  - `-u admin,dev`: Specifies a comma-separated list of usernames (`admin` and `dev`).

---

### 3️⃣ Fetching Both Slice and Admin Tokens

Retrieve both slice tokens and admin tokens in a single command:

```bash
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -s pool1 -p avesha -a -u admin,dev
```

- **Explanation**: This command retrieves both read-only and read-write tokens for slice `pool1` and admin tokens for `admin` and `dev` in the namespace `kubeslice-avesha`.
- **Parameters**:
  - `-k /path/to/kubeconfig`: Specifies the path to the kubeconfig file.
  - `-s pool1`: Specifies the slice name (`pool1`).
  - `-p avesha`: Specifies the project/namespace name (`avesha`).
  - `-a`: Indicates that we are fetching admin tokens.
  - `-u admin,dev`: Specifies a comma-separated list of usernames (`admin` and `dev`).

---

### 🛠️ Help

For more details on usage or troubleshooting, you can refer to the help option:

```bash
./fetch_egs_slice_token.sh --help
```
## EGS Preflight Check Script

![Kubernetes](https://img.shields.io/badge/Kubernetes-✔️-blue?logo=kubernetes) ![Bash](https://img.shields.io/badge/Shell_Script-Bash-121011?logo=gnu-bash) ![License](https://img.shields.io/badge/License-@Avesha-orange)

A robust preflight check script designed for EGS setup on Kubernetes. This script verifies Kubernetes resource configurations, permissions, and connectivity to ensure the environment is ready for deployment.

## Features

- 🛠️ **Resource Validation**: Checks namespaces, services, PVCs, and privileges.
- 🔍 **Comprehensive Preflight Checks**: Validates Kubernetes configurations and access.
- 🌐 **Internet Connectivity Checks**: Ensures cluster access to external resources.
- 🧹 **Resource Cleanup**: Optionally deletes created resources after validation.
- ⚡ **Multi-context Support**: Operates on multiple Kubernetes contexts.
- 🐛 **Debugging**: Provides detailed logs for troubleshooting.

## Usage

```bash
./egs-preflight-check.sh [OPTIONS]
```

## Multi Cluster Example
```bash
./egs-preflight-check.sh \
--kubeconfig ~/.kube/config \
--kubecontext-list context1,context2
```

### Key Options:

| Option                     | Description                                                                                  |
|----------------------------|----------------------------------------------------------------------------------------------|
| `--namespace-to-check`     | 🗂️ Comma-separated list of namespaces to check existence.                                    |
| `--test-namespace`         | 🏷️ Namespace for test creation and deletion (default: `egs-test-namespace`).                |
| `--pvc-test-namespace`     | 📂 Namespace for PVC test creation and deletion (default: `egs-test-namespace`).            |
| `--pvc-name`               | 🛠️ Name of the test PVC (default: `egs-test-pvc`).                                          |
| `--storage-class`          | 🗄️ Storage class for the PVC (default: none).                                               |
| `--storage-size`           | 📦 Storage size for the PVC (default: `1Gi`).                                               |
| `--service-name`           | 📌 Name of the test service (default: `test-service`).                                       |
| `--service-type`           | ⚙️ Type of service to create and validate (`ClusterIP`, `NodePort`, `LoadBalancer`, or `all`). Default: `all`. |
| `--kubeconfig`             | 🗂️ Path to the kubeconfig file (mandatory).                                                 |
| `--kubecontext`            | 🌐 Context from the kubeconfig file (mandatory).                                             |
| `--kubecontext-list`       | 🌐 Comma-separated list of context names to operate on.                                      |
| `--cleanup`                | 🧹 Whether to delete test resources (`true` or `false`). Default: `true`.                   |
| `--global-wait`            | ⏳ Time to wait after each command execution (default: `0`).                                 |
| `--watch-resources`        | 👀 Enable or disable watching resources after creation (default: `false`).                  |
| `--watch-duration`         | ⏱️ Duration to watch resources after creation (default: `30` seconds).                     |
| `--invoke-wrappers`        | 🛠️ Comma-separated list of wrapper functions to invoke.                                      |
| `--display-resources`      | 👁️ Whether to display resources created (default: `true`).                                  |
| `--kubectl-path`           | ⚡ Override default kubectl binary path.                                                     |
| `--function-debug-input`   | 🐞 Enable or disable function debugging (default: `false`).                                  |
| `--generate-summary`       | 📊 Enable or disable summary generation (default: `true`).                                  |
| `--resource-action-pairs`  | 🔐 Override default resource-action pairs (e.g., `pod:create,service:get`).                |
| `--fetch-resource-names`   | 🔍 Fetch all resource names from the cluster (default: `false`).                             |
| `--fetch-webhook-names`    | 🔍 Fetch all webhook names from the cluster (default: `false`).                              |
| `--api-resources`          | 🌍 Comma-separated list of API resources to include or operate on.                          |
| `--webhooks`               | 🌍 Comma-separated list of webhooks to include or operate on.                                |
| `--help`                   | ❓ Display this help message.                                                               |

### Default Resource-Action Pairs:

📌 The default resource-action pairs used for privilege checks are:

- `namespace:create,namespace:delete,namespace:get,namespace:list,namespace:watch`
- `pod:create,pod:delete,pod:get,pod:list,pod:watch`
- `service:create,service:delete,service:get,service:list,service:watch`
- `configmap:create,configmap:delete,configmap:get,configmap:list,configmap:watch`
- `secret:create,secret:delete,secret:get,secret:list,secret:watch`
- `serviceaccount:create,serviceaccount:delete,serviceaccount:get,serviceaccount:list,serviceaccount:watch`
- `clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list`
- `clusterrolebinding:create,clusterrolebinding:delete,clusterrolebinding:get,clusterrolebinding:list`

### Wrapper Functions:

| Wrapper Function                  | Description                                                                 |
|-----------------------------------|-----------------------------------------------------------------------------|
| 🗂️ `namespace_preflight_checks`   | Validates namespace creation and existence.                                |
| 🔍 `grep_k8s_resources_with_crds_and_webhooks` | Validates existing resources available in the cluster based on resource names. (e.g., prometheus, gpu-operator, postgresql) |
| 📂 `pvc_preflight_checks`         | Validates PVC creation, deletion, and storage properties.                   |
| ⚙️ `service_preflight_checks`     | Validates the creation and deletion of services (`ClusterIP`, `NodePort`, `LoadBalancer`). |
| 🔐 `k8s_privilege_preflight_checks` | Validates privileges for Kubernetes actions on resources.                  |
| 🌐 `internet_access_preflight_checks` | Validates internet connectivity from within the Kubernetes cluster.         |

### Examples

```bash
./egs-preflight-check.sh --namespace-to-check my-namespace --test-namespace test-ns --invoke-wrappers namespace_preflight_checks
./egs-preflight-check.sh --pvc-test-namespace pvc-ns --pvc-name test-pvc --storage-class standard --storage-size 1Gi --invoke-wrappers pvc_preflight_checks
./egs-preflight-check.sh --test-namespace service-ns --service-name test-service --service-type NodePort --watch-resources true --watch-duration 60 --invoke-wrappers service_preflight_checks
./egs-preflight-check.sh --invoke-wrappers namespace_preflight_checks,pvc_preflight_checks,service_preflight_checks
./egs-preflight-check.sh --resource-action-pairs pod:create,namespace:delete --invoke-wrappers k8s_privilege_preflight_checks
./egs-preflight-check.sh --function-debug-input true --invoke-wrappers namespace_preflight_checks
./egs-preflight-check.sh --generate-summary false --invoke-wrappers namespace_preflight_checks
./egs-preflight-check.sh --fetch-resource-names true --invoke-wrappers service_preflight_checks
./egs-preflight-check.sh --api-resources pod,service --invoke-wrappers namespace_preflight_checks
```

> **Note**: If no wrapper function is specified, all preflight check functions will be executed by default.

## Output

- 📝 **Logs**: Detailed logs are generated for each step, including successes and failures.
- 📊 **Summary**: A final summary is displayed, highlighting the status of all checks.

---
## Namespace Creation Script

This script automates the creation of Kubernetes namespaces with specified annotations and labels based on a YAML configuration file. It dynamically supports multiple Kubernetes contexts and provides detailed success/failure logs with a final summary.

---

## Features

- Dynamically processes namespaces and contexts from an input YAML file.
- Supports multiple Kubernetes contexts in a single execution.
- Logs detailed success/failure information for each namespace creation.
- Provides a summary of operations at the end.
- Handles annotations and labels for each namespace.
- Deletes temporary YAML files after applying the configuration.

---

## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and configured.
- [yq](https://github.com/mikefarah/yq) installed for parsing YAML files.

---

## Script Parameters

| Parameter               | Description                                                |
|-------------------------|------------------------------------------------------------|
| `--input-yaml`          | Path to the input YAML file containing namespace definitions. |
| `--kubeconfig`          | Path to the Kubernetes kubeconfig file.                    |
| `--kubecontext-list`    | Comma-separated list of Kubernetes contexts to process.    |
| `--help` or `-h`        | Display the help message and usage information.            |

---

## Input YAML Format

The input YAML file should follow this format:

```yaml
auto_create_namespace: true
namespaces:
  - name: egs-gpu-operator
    annotations:
      - key: application
        value: egs
    labels:
      - key: avesha-tower-name
        value: development
      - key: application
        value: egs

  - name: egs-monitoring
    annotations:
      - key: application
        value: egs
    labels:
      - key: avesha-tower-name
        value: development
      - key: application
        value: egs
```

---

## Usage

### Running the Script

Save the script as `create-namespaces.sh` and make it executable:

```bash
chmod +x create-namespaces.sh
```

Run the script with the desired parameters:

```bash
./create-namespaces.sh \
  --input-yaml namespace-input.yaml \
  --kubeconfig ~/.kube/config \
  --kubecontext-list context1,context2,context3
```

### Help Option

To see usage information, run:

```bash
./create-namespaces.sh --help
```

---

## Output Example

### Console Logs
```bash
🔄 Processing context: context1
🔧 Creating namespace: egs-gpu-operator in context: context1
✅ Successfully created namespace: egs-gpu-operator in context: context1
🔧 Creating namespace: egs-monitoring in context: context1
❌ Failed to create namespace: egs-monitoring in context: context1
   Reason: Namespace already exists

📋 Summary:
✅ Successful operations: 1
   - egs-gpu-operator (context: context1)
❌ Failed operations: 1
   - egs-monitoring (context: context1): Namespace already exists
```

---

## Summary

This script simplifies the namespace creation process in Kubernetes, making it ideal for environments with multiple clusters and namespaces. Customize the input YAML to suit your needs and track results through the detailed logs and summary provided.

---


### 🔑 Key Features

1. **Prerequisite Checks**: Ensures that required binaries are installed. 🛠️
2. **Kubeslice Pre-Checks**: Validates access to clusters and labels nodes if required. ✅
3. **Helm Chart Management**: Adds, updates, or removes Helm repositories and manages chart installations. 📦
4. **Project and Cluster Management**: Automates the creation of projects and registration of clusters in the Kubeslice controller. 🗂️
5. **Worker Configuration**: Fetches secrets from the controller cluster, prepares worker-specific values files, and manages worker installations. ⚙️

### 📜 Example Workflow

1. **Run Pre-checks**: The script first validates that all prerequisites are met. ✅
2. **Kubeslice Pre-Checks**: Validates that the script can access all necessary clusters. 🔍
3. **Install or Upgrade Helm Charts**:
   - Installs or upgrades the Kubeslice controller. 📦
   - Installs or upgrades the Kubeslice UI. 💻
4. **Project and Cluster Management**:
   - Creates defined projects in the Kubeslice controller. 🗂️
   - Registers defined clusters within these projects. 🌍
5. **Worker Installation**: Installs or upgrades worker nodes, applying the necessary configuration. ⚙️

### 📝 Notes

- Ensure the YAML configuration file is correctly formatted and contains all necessary fields. 📄
- The script will exit with an error if any critical steps fail unless configured to skip on failure. ❌
- Paths specified in the YAML file should be relative to the `base_path` unless absolute paths are used. 📁

### 🛠️ Troubleshooting

- **Missing Binaries**: Ensure all required binaries are installed and accessible in your system's `PATH`. ⚠️
- **Cluster Access Issues**: Verify that kubeconfig files are correctly configured and that the script can access the clusters specified in the YAML configuration. 🔧
- **Timeouts**: If a component fails to install within the specified timeout, increase the `verify_install_timeout` in the YAML file. ⏳

---

## Custom Pricing Upload Script

### 🔑 Key Features

1.Define cloud instance pricing data in YAML

2.Specify Kubernetes connection details (via kubeconfig and kubecontext) in the same YAML

3.Automatically port-forward to a Kubernetes service

4.Convert the YAML pricing info to CSV

5.Upload the CSV to a pricing API running inside the cluster



### 📁 Files

- **custom-pricing-data.yaml**: YAML input file with Kubernetes config and pricing data
- **custom-pricing-upload.sh**: Bash script to read YAML, port-forward, generate CSV, and upload

### 📦 Prerequisites


Make sure the following tools are installed:

- **kubectl**: Communicate with Kubernetes
- **yq**: Parse YAML in shell
- **jq**: Parse JSON in shell
- **curl**: Upload CSV via API

## Input custom-pricing-data YAML Format

The input YAML file should follow this format:

```yaml
kubernetes:
  kubeconfig: ""         #absolute path og kubeconfig
  kubecontext: ""        #kubecontext name
  namespace: "kubeslice-controller"
  service: "kubetally-pricing-service"

#we can add as many cloud providers and instance types as needed
cloud_providers:
  - name: "gcp"
    instances:
      - region: "us-east1"
        component: "Compute Instance"
        instance_type: "a2-highgpu-2g"
        vcpu: 1
        price: 20
        gpu: 1
      - region: "us-east1"
        component: "Compute Instance"
        instance_type: "e2-standard-8"
        vcpu: 1
        price: 5
        gpu: 0
```

### Running the Script


```bash
chmod +x custom-pricing-upload.sh
```

Run the script:

```bash
./custom-pricing-upload.sh 
```

## Summary
1.Reads Kubernetes config from YAML

2.Auto-discovers the service port (e.g., kubetally-pricing-service:80)

3.Picks a random local port

4.Starts a background port-forward to that service

5.Converts pricing data in YAML → CSV

6.Uploads CSV to:
```
http://localhost:<random_port>/api/v1/prices
```
---
