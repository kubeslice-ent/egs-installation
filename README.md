---
# 🌐 EGS Installer Script

## 🚀 Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

---

## 📄 EGS Documents

- 📖 For the EGS platform overview, please see the [Platform Overview Documentation](https://docs.avesha.io/documentation/enterprise-egs) 🌐  
- 🔧 For the Admin guide, please see the [EGS Admin Guide](docs/EGS-Admin-guide.pdf) 🛠️  
- 👤 For the User guide, please see the [User Guide Documentation](https://docs.avesha.io/documentation/enterprise-egs) 📚  
- 🛠️ For the Installation guide, please see the documentation on [Installation Guide Documentation](https://github.com/kubeslice-ent/egs-installation) 💻  
- 🔑 For EGS License setup, please refer to the [EGS License Setup Guide](docs/EGS-License-Setup.md) 🗝️  
- ✅ For preflight checks, please refer to the [EGS Preflight Check Documentation](docs/EGS-Preflight-Check-README.md) 🔍  
- 📋 For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](docs/Slice-Admin-Token-README.md) 🔒  
- 🗂️ For precreate required namespace, please refer to the [Namespace Creation Script Documentation](docs/Namespace-Creation-README.md) 🗂️  
- 🚀 For EGS Controller prerequisites, please refer to the [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md) 📋  
- ⚙️ For EGS Worker prerequisites, please refer to the [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md) 🔧  
- 🛠️ For configuration details, please refer to the [Configuration Documentation](docs/Configuration-README.md) 📋  
- 📊 For custom pricing setup, please refer to the [Custom Pricing Documentation](docs/Custom-Pricing-README.md) 💰

---

## Getting Started

### Prerequisites

Before you begin, ensure the following steps are completed:

1. **📝 Registration:**
   - Complete the registration process at [Avesha EGS Registration](https://avesha.io/egs-registration) to receive the required access credentials and product license for running the script.
   - For detailed license setup instructions, refer to **[📋 EGS License Setup](docs/EGS-License-Setup.md)**.

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
     cd egs-installation
     ```

5. **✅ Run EGS Preflight Check Script (Optional):**
   - To ensure your environment meets all installation requirements, you can optionally run the **EGS Preflight Check Script**.
     - Refer to the [EGS Preflight Check Guide](docs/EGS-Preflight-Check-README.md) for detailed instructions.
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
       - Refer to the [Namespace Creation Guide](docs/Namespace-Creation-README.md) for details.
     - Example command:
       ```bash
       ./create-namespaces.sh \
         --input-yaml namespace-input.yaml \
         --kubeconfig ~/.kube/config \
         --kubecontext-list context1,context2
       ```
     - Ensure that all required annotations and labels for policy enforcement are correctly configured in the YAML file.

7. **⚙️ Configure EGS Installer for Prerequisites Installation:**

   **⚠️ IMPORTANT: Choose ONE approach - do NOT use both simultaneously**

   **Option A: Using EGS Prerequisites Script (Recommended for new installations)**
   
   If you want EGS to automatically install and configure Prometheus, GPU Operator, and PostgreSQL:
   
   **Global Kubeconfig Configuration:**
   - Ensure your global kubeconfig is properly configured for multi-cluster access:
     ```yaml
     global_kubeconfig: ""  # Relative path to global kubeconfig file from base_path (MANDATORY)
     global_kubecontext: ""  # Global kubecontext (MANDATORY)
     use_global_context: true  # If true, use the global kubecontext for all operations by default
     ```

   **Configuration File Setup:**
   - Configure the `egs-installer-config.yaml` file to enable additional applications installation. **For complete configuration examples, see [egs-installer-config.yaml](egs-installer-config.yaml)**:
     ```yaml
     # Enable or disable specific stages of the installation
     enable_install_controller: true               # Enable the installation of the Kubeslice controller
     enable_install_ui: true                       # Enable the installation of the Kubeslice UI
     enable_install_worker: true                   # Enable the installation of Kubeslice workers

     # Enable or disable the installation of additional applications (prometheus, gpu-operator, postgresql)
     enable_install_additional_apps: true          # Set to true to enable additional apps installation

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
   
   **Critical Configuration Steps:**
     1. **Set `enable_install_additional_apps: true`** - This enables the installation of GPU Operator, Prometheus, and PostgreSQL
     2. **Configure `enable_custom_apps`** - Set to `true` if you need NVIDIA driver installation on your nodes
     3. **Set `run_commands`** - Set to `true` if you need NVIDIA MIG configuration and node labeling

   **Additional Apps Configuration for Each Worker:**
   - **📌 IMPORTANT:** For different worker clusters, you need to add additional apps array for each component in the `kubeslice_worker_egs` section
   - Each worker cluster requires its own instances of GPU Operator and Prometheus if `enable_install_additional_apps: true`
   - **For complete additional apps configuration examples, see [egs-installer-config.yaml](egs-installer-config.yaml#L255-L320)**
   - Example structure for multiple workers with additional apps:
     ```yaml
     additional_apps:
       - name: "gpu-operator-worker-1"              # Name of the application
         skip_installation: false                   # Do not skip the installation of the GPU operator
         use_global_kubeconfig: false               # Use specific kubeconfig for this worker
         kubeconfig: "~/.kube/config-worker-1"      # Path to worker-1 kubeconfig file
         kubecontext: "worker-1-context"            # Kubecontext specific to worker-1
         namespace: "egs-gpu-operator"              # Namespace where the GPU operator will be installed
         release: "gpu-operator-worker-1"           # Helm release name for the GPU operator
         chart: "gpu-operator"                      # Helm chart name for the GPU operator
         repo_url: "https://helm.ngc.nvidia.com/nvidia" # Helm repository URL for the GPU operator
         version: "v24.9.1"                         # Version of the GPU operator to install
         specific_use_local_charts: true            # Use local charts for this application
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
         helm_flags: "--debug"                      # Additional Helm flags for this application's installation
         verify_install: false                      # Verify the installation of the GPU operator
         verify_install_timeout: 600                # Timeout for verification (in seconds)
         skip_on_verify_fail: true                  # Skip the step if verification fails
         enable_troubleshoot: false                 # Enable troubleshooting mode for additional logs and checks
       
       - name: "prometheus-worker-1"                # Name of the application
         skip_installation: false                   # Do not skip the installation of Prometheus
         use_global_kubeconfig: false               # Use specific kubeconfig for this worker
         kubeconfig: "~/.kube/config-worker-1"      # Path to worker-1 kubeconfig file
         kubecontext: "worker-1-context"            # Kubecontext specific to worker-1
         namespace: "egs-monitoring"                # Namespace where Prometheus will be installed
         release: "prometheus-worker-1"             # Helm release name for Prometheus
         chart: "kube-prometheus-stack"             # Helm chart name for Prometheus
         repo_url: "https://prometheus-community.github.io/helm-charts" # Helm repository URL for Prometheus
         version: "v45.0.0"                         # Version of the Prometheus stack to install
         specific_use_local_charts: true            # Use local charts for this application
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
         helm_flags: "--debug"                     # Additional Helm flags for this application's installation
         verify_install: false                      # Verify the installation of Prometheus
         verify_install_timeout: 600                # Timeout for verification (in seconds)
         skip_on_verify_fail: true                  # Skip the step if verification fails
         enable_troubleshoot: false                 # Enable troubleshooting mode for additional logs and checks
     
     # For worker-2, repeat the same structure with different kubeconfig, kubecontext, and release names:
     # - name: "gpu-operator-worker-2"
     #   kubeconfig: "~/.kube/config-worker-2"
     #   kubecontext: "worker-2-context"
     #   release: "gpu-operator-worker-2"
     # - name: "prometheus-worker-2"
     #   kubeconfig: "~/.kube/config-worker-2"
     #   kubecontext: "worker-2-context"
     #   release: "prometheus-worker-2"
     ```

   **Option B: Using Pre-existing Infrastructure**
   
   If you already have Prometheus, GPU Operator, or PostgreSQL running in your cluster:
   
   - **Set `enable_install_additional_apps: false`** in your `egs-installer-config.yaml`
   - **Refer to the prerequisite documentation** to ensure proper configuration for metrics scraping:
     - **[EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md)** - For Prometheus and PostgreSQL configuration
     - **[EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md)** - For GPU Operator and monitoring configuration
   - **Verify that your existing components** are properly configured to scrape EGS metrics
   - **Ensure proper RBAC permissions** and network policies are in place

8. **🚀 Install Prerequisites (After Configuration):**
   - After configuring the YAML file (refer to [egs-installer-config.yaml](egs-installer-config.yaml) for examples), run the prerequisites installer to set up GPU Operator, Prometheus, and PostgreSQL:
   ```bash
   ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
   ```
   - **Note:** This step installs the required infrastructure components before the main EGS installation.
---

## 🛠️ Installation Steps

### 1. **📂 Clone the Repository:**
   - Start by cloning the EGS installation Git repository:
     ```bash
     git clone https://github.com/kubeslice-ent/egs-installation
     cd egs-installation
     ```

### 2. **📝 Modify the Configuration File (Mandatory):**
   - Navigate to the cloned repository and locate the input configuration YAML file `egs-installer-config.yaml`. **For the complete configuration template, see [egs-installer-config.yaml](egs-installer-config.yaml)**.
   - Choose your installation approach:

   **🔄 Option A: Single Cluster Installation (Simplified)**
   
   For single cluster setups where controller and workers are in the same cluster, you only need to update basic configuration:
   
   ```yaml
   # Kubernetes Configuration (Mandatory)
   global_kubeconfig: ""  # Relative path to global kubeconfig file from base_path default is script directory (MANDATORY)
   global_kubecontext: ""  # Global kubecontext (MANDATORY)
   use_global_context: true  # If true, use the global kubecontext for all operations by default

   # Installation Flags (Mandatory)
   enable_install_controller: true               # Enable the installation of the Kubeslice controller
   enable_install_ui: true                       # Enable the installation of the Kubeslice UI
   enable_install_worker: true                   # Enable the installation of Kubeslice workers
   enable_install_additional_apps: true          # Set to true to enable additional apps installation
   enable_custom_apps: true                      # Set to true if you want to allow custom applications to be deployed
   run_commands: false                           # Set to true to allow the execution of commands for configuring NVIDIA MIG
   ```
   
   **After updating these values, you can proceed directly to Step 7 (Run Installation Script).**
   
   **🌐 Option B: Multi-Worker Installation (Advanced)**
   
   For multi-cluster setups or when you need detailed worker configuration, continue with the following sections:
   
   **⚙️ Global Monitoring Endpoint Settings (Optional):**
   - Configure global monitoring endpoint settings for multi-cluster setups:
     
     **⚠️ IMPORTANT NOTE:** It is recommended to set `global_auto_fetch_endpoint: true` for automatic endpoint discovery. If set to `false`, you must manually provide the Prometheus endpoints in the respective worker values section or cluster definition section. Ensure that worker Prometheus endpoints are accessible from the controller cluster for proper monitoring.
     
     **📌 CLUSTER SETUP CONSIDERATION:** If using ClusterIP service type, this is only valid for single cluster setups. For multi-worker setups where worker and controller clusters are different, ClusterIP will NOT work as the controller cluster cannot access worker cluster services. Use NodePort, LoadBalancer, or ensure proper network connectivity between clusters.
      
      ```yaml
      # Global monitoring endpoint settings
      global_auto_fetch_endpoint: false               # Enable automatic fetching of monitoring endpoints globally
      global_grafana_namespace: egs-monitoring        # Namespace where Grafana is globally deployed
      global_grafana_service_type: ClusterIP          # Service type for Grafana (accessible only within the cluster)
      global_grafana_service_name: prometheus-grafana # Service name for accessing Grafana globally
      global_prometheus_namespace: egs-monitoring     # Namespace where Prometheus is globally deployed
      global_prometheus_service_name: prometheus-kube-prometheus-prometheus # Service name for accessing Prometheus globally
      global_prometheus_service_type: ClusterIP       # Service type for Prometheus (accessible only within the cluster)
      ```
   
   **📋 When to Use Each Approach:**
   
   - **🔄 Option A (Single Cluster):** Use when controller and all workers are in the same Kubernetes cluster. This is the simplest setup and requires minimal configuration.
   
   - **🌐 Option B (Multi-Worker):** Use when you have workers in different clusters, need custom worker configurations, or want detailed control over monitoring endpoints and worker settings.
   
   **Continue with the following sections for detailed configuration (Option B users only):**

### 3. **Kubeslice Controller Installation Settings (Mandatory)**

   **Note: This section is MANDATORY for EGS installation. Configure the controller settings according to your environment.** **For the complete controller configuration example, see [egs-installer-config.yaml](egs-installer-config.yaml#L75-L120)**.
   
   ```yaml
   # Kubeslice Controller Installation Settings
   kubeslice_controller_egs:
     skip_installation: false                     # Do not skip the installation of the controller
     use_global_kubeconfig: true                  # Use global kubeconfig for the controller installation
     specific_use_local_charts: true              # Override to use local charts for the controller
     kubeconfig: ""                               # Path to the kubeconfig file specific to the controller, if empty, uses the global kubeconfig
     kubecontext: ""                              # Kubecontext specific to the controller; if empty, uses the global context
     namespace: "kubeslice-controller"            # Kubernetes namespace where the controller will be installed
     release: "egs-controller"                    # Helm release name for the controller
     chart: "kubeslice-controller-egs"            # Helm chart name for the controller
   
     # Inline Helm Values for the Controller Chart
     inline_values:
       global:
         imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems   # Docker registry for the images
         namespaceConfig:   # user can configure labels or annotations that EGS Controller namespaces should have
           labels: {}
           annotations: {}
         kubeTally:
           enabled: true                           # Enable KubeTally in the controller
   
         # PostgreSQL Connection Configuration for Kubetally
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
   
     # Helm Flags and Verification Settings
     helm_flags: "--wait --timeout 5m --debug"            # Additional Helm flags for the installation
     verify_install: false                        # Verify the installation of the controller
     verify_install_timeout: 30                   # Timeout for the controller installation verification (in seconds)
     skip_on_verify_fail: true                    # If verification fails, do not skip the step
   
     # Troubleshooting Settings
     enable_troubleshoot: false                   # Enable troubleshooting mode for additional logs and checks
   ```

   **⚙️ PostgreSQL Connection Configuration (Mandatory - KubeTally is enabled by default)**

   **📌 Note:** Since KubeTally is enabled by default, PostgreSQL configuration is now mandatory for EGS installation. The secret is created in the `kubeslice-controller` namespace during installation. If you prefer to use a pre-created secret, leave all values empty and specify only the secret name.

   **`postgresSecretName`**: The name of the Kubernetes Secret containing PostgreSQL credentials.

   The secret must contain the following key-value pairs:

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
   
   **📌 Alternatively**, if you provide all values with a secret name as specified for `postgresSecretName` in the values file, using the key-value format below, it will automatically create the specified secret in the `kubeslice-controller` namespace with the provided values.
   
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

   **For detailed PostgreSQL setup, see [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md)**

### 4. **Kubeslice UI Installation Settings (Optional)**

   **Note: This section is OPTIONAL and typically requires NO changes. The default configuration works for most installations.**

   The Kubeslice UI provides a web interface for managing and monitoring your EGS deployment. By default, it's configured to work out-of-the-box with minimal configuration required. **For the complete UI configuration example, see [egs-installer-config.yaml](egs-installer-config.yaml#L117-L200)**.

   ```yaml
   # Kubeslice UI Installation Settings
   kubeslice_ui_egs:
     skip_installation: false                     # Do not skip the installation of the UI
     use_global_kubeconfig: true                  # Use global kubeconfig for the UI installation
     kubeconfig: ""                               # Path to the kubeconfig file specific to the UI, if empty, uses the global kubeconfig
     kubecontext: ""                              # Kubecontext specific to the UI; if empty, uses the global context
     namespace: "kubeslice-controller"            # Kubernetes namespace where the UI will be installed
     release: "egs-ui"                            # Helm release name for the UI
     chart: "kubeslice-ui-egs"                    # Helm chart name for the UI
   
     # Inline Helm Values for the UI Chart
     inline_values:
       global:
         imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems   # Docker registry for the UI images
       kubeslice:
         prometheus:
           url: http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090  # Prometheus URL for monitoring
         uiproxy:
           service:
             type: ClusterIP                  # Service type for the UI proxy
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
             annotations: []
             ## Extra labels to add onto the Ingress object
             extraLabels: {}
           apigw:
             env:
               - name: DCGM_METRIC_JOB_VALUE
                 value: nvidia-dcgm-exporter  # This value must match the Prometheus scrape job name for GPU metrics collection
         
         egsCoreApis:
           enabled: true                         # Enable EGS core APIs for the UI
           service:
             type: ClusterIP                  # Service type for the EGS core APIs
   
     # Helm Flags and Verification Settings
     helm_flags: "--wait --timeout 5m --debug"            # Additional Helm flags for the UI installation
     verify_install: false                        # Verify the installation of the UI
     verify_install_timeout: 50                   # Timeout for the UI installation verification (in seconds)
     skip_on_verify_fail: true                    # If UI verification fails, do not skip the step
   
     # Chart Source Settings
     specific_use_local_charts: true              # Override to use local charts for the UI
   ```

   **📌 IMPORTANT NOTE:** The `DCGM_METRIC_JOB_VALUE` must match the Prometheus scrape job name configured in your Prometheus configuration. Without proper Prometheus scrape configuration, GPU metrics will not be collected and UI visualization will not work. Ensure your Prometheus configuration includes the corresponding scrape job. For detailed Prometheus configuration, see [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md).

### 5. **Worker Clusters: Update the Inline Values**

   This section is **mandatory** to ensure proper configuration of monitoring and dashboard URLs. Follow the steps carefully:
   
   **📝 Note:** Global monitoring endpoint settings are configured in the [Modify the Configuration File](https://github.com/kubeslice-ent/egs-installation/tree/main?tab=readme-ov-file#2--modify-the-configuration-file-mandatory) section above, including `global_auto_fetch_endpoint` and related Grafana/Prometheus settings.
   
   **⚠️ Multi-Cluster Setup Configuration**
   
   If the **controller** and **worker** are in different clusters, you need to configure monitoring endpoints manually:
   
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
        global:
          imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems # Docker registry for worker images
        operator:
          env:
            - name: DCGM_EXPORTER_JOB_NAME
              value: gpu-metrics  # This value must match the Prometheus scrape job name for GPU metrics collection
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
      ```

   **📌 IMPORTANT NOTE:** The `DCGM_EXPORTER_JOB_NAME` value (`gpu-metrics`) must match the Prometheus scrape job name configured in your Prometheus configuration. Without proper Prometheus scrape configuration, GPU metrics will not be collected from the worker cluster and monitoring dashboards will not display GPU data. Ensure your Prometheus configuration includes the corresponding scrape job. For detailed Prometheus configuration, see [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md).

### 6. **Adding Additional Workers (Optional)**

   To add another worker to your EGS setup, you need to make an entry in the `kubeslice_worker_egs` section of your `egs-installer-config.yaml` file. **For complete worker configuration examples, see [egs-installer-config.yaml](egs-installer-config.yaml#L181-L240)**. Follow these steps:

   **Step 1: Add Worker Configuration**
   
   Add a new worker entry to the `kubeslice_worker_egs` array in your configuration file:
   
   ```yaml
   kubeslice_worker_egs:
     - name: "worker-1"                           # Worker name
       use_global_kubeconfig: true                # Use global kubeconfig for this worker
       kubeconfig: ""                             # Path to the kubeconfig file specific to the worker, if empty, uses the global kubeconfig
       kubecontext: ""                            # Kubecontext specific to the worker; if empty, uses the global context
       skip_installation: false                   # Do not skip the installation of the worker
       specific_use_local_charts: true            # Override to use local charts for this worker
       namespace: "kubeslice-system"              # Kubernetes namespace for this worker
       release: "egs-worker"                      # Helm release name for the worker
       chart: "kubeslice-worker-egs"              # Helm chart name for the worker
       inline_values:                             # Inline Helm values for the worker chart
         global:
           imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems # Docker registry for worker images
         operator:
           env:
             - name: DCGM_EXPORTER_JOB_NAME
               value: gpu-metrics  # This value must match the Prometheus scrape job name for GPU metrics collection
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

   **Step 2: Add Cluster Registration**
   
   Add corresponding entries in the `cluster_registration` section for each new worker. **For cluster registration examples, see [egs-installer-config.yaml](egs-installer-config.yaml#L240-L270)**:

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
   ```

   **⚠️ Important Notes:**
   
   - **🔑 Unique Release Names:** Ensure each worker has a unique `release` name to avoid conflicts during installation.
   - **🌐 Cluster Endpoints:** Update the `prometheusEndpoint` and `grafanaDashboardBaseUrl` with the correct endpoints for the new worker cluster.
   - **🔧 Kubeconfig:** If the new worker is in a different cluster, provide the appropriate `kubeconfig` and `kubecontext` values.
   - **📊 Monitoring:** Ensure the monitoring endpoints (Prometheus/Grafana) are accessible from the controller cluster for proper telemetry.
   - **🔗 Prometheus Accessibility:** **Critical:** Make sure Prometheus endpoints are accessible from the controller cluster. The controller needs to reach the Prometheus service in each worker cluster to collect metrics and telemetry data. If the worker clusters are in different networks, ensure proper network connectivity or use LoadBalancer/NodePort services for Prometheus.

   **📌 Note - Multiple Worker Configuration:**
   
   When configuring multiple workers, you can use an array structure in your `egs-installer-config.yaml`. Here's a sample snippet showing how to efficiently handle multiple workers:
   
   ```yaml
   kubeslice_worker_egs:
     # Worker 1 - Complete configuration
     - name: "worker-1"
       use_global_kubeconfig: true
       kubeconfig: ""
       kubecontext: ""
       skip_installation: false
       specific_use_local_charts: true
       namespace: "kubeslice-system"
       release: "egs-worker-1"
       chart: "kubeslice-worker-egs"
       inline_values:
         global:
           imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems
         operator:
           env:
             - name: DCGM_EXPORTER_JOB_NAME
               value: gpu-metrics
         egs:
           prometheusEndpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
           grafanaDashboardBaseUrl: "http://<grafana-lb>/d/Oxed_c6Wz"
         # ... other worker-1 specific values
       
     # Worker 2 - Pattern for additional workers
     - name: "worker-2"
       use_global_kubeconfig: true
       kubeconfig: ""
       kubecontext: ""
       skip_installation: false
       specific_use_local_charts: true
       namespace: "kubeslice-system"
       release: "egs-worker-2"                    # Unique release name
       chart: "kubeslice-worker-egs"
       inline_values:
         global:
           imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems
         operator:
           env:
             - name: DCGM_EXPORTER_JOB_NAME
               value: gpu-metrics
         egs:
           prometheusEndpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
           grafanaDashboardBaseUrl: "http://<grafana-lb>/d/Oxed_c6Wz"
         # ... other worker-2 specific values
       
     # Worker 3 - Follow same pattern
     - name: "worker-3"
       # ... similar configuration with unique name, release, and endpoints
   ```
   
   **💡 Key Points for Multiple Workers:**
   - **Unique Identifiers:** Each worker must have unique `name` and `release` values
   - **Endpoint Configuration:** Configure worker-specific monitoring endpoints if they're in different clusters
   - **Array Structure:** Use YAML array syntax with `-` for each worker entry
   - **Consistent Pattern:** Follow the same configuration structure for all workers
   - **🔧 Cluster Access:** **Critical:** For workers in different clusters, ensure worker-specific `kubeconfig` and `kubecontext` values are properly specified. If using global kubeconfig, verify it has access to all worker clusters.

   **📋 Cluster Registration YAML Examples:**

   **⚠️ CRITICAL NOTE - Prometheus Endpoint Accessibility:**
   
   The examples below show **example Prometheus endpoints** for demonstration purposes. **IMPORTANT:** If your controller and worker clusters are in different Kubernetes clusters, the Kubernetes cluster service URLs (like `*.svc.cluster.local`) will **NOT work** because the controller cluster cannot reach the internal service endpoints of worker clusters.
   
   **For Multi-Cluster Setups, you must use:**
   - **LoadBalancer External IPs** for Prometheus services
   - **NodePort** services with accessible node IPs
   - **Ingress/LoadBalancer** endpoints that are reachable from the controller cluster
   - **External Prometheus instances** with public endpoints
   
   **Single Cluster Setup (All workers in same cluster):**
   
   ```yaml
   cluster_registration:
     - cluster_name: "egs-cluster"
       project_name: "avesha"
       telemetry:
         enabled: true
         endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
         telemetryProvider: "prometheus"
       geoLocation:
         cloudProvider: "GCP"
         cloudRegion: "us-central1"
   ```

   **Multi-Cluster Setup (Workers in different clusters):**
   
   ```yaml
   cluster_registration:
     
     # Worker clusters - follow same pattern with unique names and endpoints
     - cluster_name: "worker-1-cluster"
       project_name: "avesha"
       telemetry:
         enabled: true
         endpoint: "http://<worker-1-prometheus-endpoint>:9090"  # Use accessible endpoint
         telemetryProvider: "prometheus"
       geoLocation:
         cloudProvider: "GCP"
         cloudRegion: "us-west1"
     
     - cluster_name: "worker-2-cluster"
       project_name: "avesha"
       telemetry:
         enabled: true
         endpoint: "http://<worker-2-prometheus-endpoint>:9090"  # Use accessible endpoint
         telemetryProvider: "prometheus"
       geoLocation:
         cloudProvider: "AWS"
         cloudRegion: "us-east-1"
   ```

   **🔑 Cluster Registration Key Points:**
   - **Unique Cluster Names:** Each cluster must have a unique `cluster_name` value
   - **Telemetry Endpoints:** Configure cluster-specific Prometheus endpoints for each worker cluster
   - **Geographic Distribution:** Use `geoLocation` to specify cloud provider and region for each cluster
   - **Project Association:** All clusters should be associated with the same `project_name` for unified management

---

### 7. **🚀 Run the Installation Script**

After completing all configuration changes, run the installation script to deploy EGS:

```bash
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

**📌 IMPORTANT NOTES:**

- **🔄 Configuration Changes:** If you make any changes to the configuration file after the initial installation, you must re-run the installation script to apply the changes.
- **⬆️ Upgrades:** For EGS upgrades or configuration modifications, update your `egs-installer-config.yaml` file and re-run the installation script. The installer will handle upgrades automatically.
- **✅ Verification:** Always verify the installation after making configuration changes to ensure all components are properly deployed.

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
