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
- 🔑 For EGS License setup, please refer to the [EGS License Setup Guide](docs/EGS-License-Setup.md) 🗝️  
- ✅ For preflight checks, please refer to the [EGS Preflight Check Documentation](https://github.com/kubeslice-ent/egs-installation?tab=readme-ov-file#egs-preflight-check-script) 🔍  
- 📋 For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](https://github.com/kubeslice-ent/egs-installation#token-retrieval) 🔒  
- 🗂️ For precreate required namespace, please refer to the [Namespace Creation Script Documentation](https://github.com/kubeslice-ent/egs-installation#namespace-creation) 🗂️  
- 🚀 For EGS Controller prerequisites, please refer to the [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md) 📋  
- ⚙️ For EGS Worker prerequisites, please refer to the [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md) 🔧  

---  

## Getting Started

### Prerequisites

Before you begin, ensure the following steps are completed:

1. **📝 Registration:**
   - Complete the registration process at [Avesha Registration](https://avesha.io/kubeslice-registration) to receive the required access credentials for running the script.

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

6. **📋 EGS Prerequisites Setup:**
   - **For Controller**: Review [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md) for Prometheus and PostgreSQL requirements
   - **For Worker**: Review [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md) for GPU Operator and monitoring requirements

7. **🗂️ Pre-create Required Namespaces (Optional):**
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

8. **⚙️ Configure EGS Installer for Prerequisites Installation (Mandatory if using prerequisites):**
   - Before running the prerequisites installer, you must configure the `egs-installer-config.yaml` file to enable additional applications installation:
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
   - **Critical Configuration Steps:**
     1. **Set `enable_install_additional_apps: true`** - This enables the installation of GPU Operator, Prometheus, and PostgreSQL
     2. **Configure `enable_custom_apps`** - Set to `true` if you need NVIDIA driver installation on your nodes
     3. **Set `run_commands`** - Set to `true` if you need NVIDIA MIG configuration and node labeling

9. **🚀 Install Prerequisites (After Configuration):**
   - After configuring the YAML file, run the prerequisites installer to set up GPU Operator, Prometheus, and PostgreSQL:
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
     ```

### 2. **📝 Modify the Configuration File (Mandatory):**
   - Navigate to the cloned repository and locate the input configuration YAML file `egs-installer-config.yaml`.
   - Update the following mandatory parameters:

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

         ⚙️ **Kubeslice Controller Configuration**

         The controller installation is configured through the `kubeslice_controller_egs` section in your `egs-installer-config.yaml`. For detailed configuration options, see **[📋 Configuration Documentation](docs/Configuration-README.md)**.

         ⚙️ **PostgreSQL Connection Configuration (*Mandatory only if `kubetallyEnabled` is set to `true` (Optional otherwise)*)** 

         📌 **Note:** The secret is created in the `kubeslice-controller` namespace during installation. If you prefer to use a pre-created secret, leave all values empty and specify only the secret name.
         
         📋 **For detailed PostgreSQL setup, see [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md)**
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

### 3. **🔄 Worker Clusters: Update the Inline Values**

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

### 4. **➕ Adding Additional Workers (Optional) **

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
         # Leave egsAgent section empty as the script will auto-fetch token and endpoint details
         egsAgent:
           secretName: egs-agent-access
           agentSecret:
             endpoint: ""  # Leave empty - script will auto-fetch
             key: ""       # Leave empty - script will auto-fetch
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

## 🛠️ Configuration

For detailed information about configuring your EGS installation, including the complete YAML configuration file with all parameters and settings, please refer to:

**[📋 Configuration Documentation](docs/Configuration-README.md)**

This documentation covers:
- Complete YAML configuration file structure
- Mandatory and optional parameters
- Kubeslice controller, UI, and worker settings
- Additional applications configuration
- Custom applications and manifests
- Troubleshooting and verification settings



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
| `global_image_pull_secret`          | Global Docker registry credentials for pulling images.                                                             | `repository: "https://index.docker.io/v1/", username: "", password: ""`                              |
| `global_kubeconfig`                 | Relative path to the global kubeconfig file (must be in the script directory) - Mandatory.                         | `""` (empty string)                                                                                 |
| `global_kubecontext`                | Global kubecontext to use - Mandatory.                                                                             | `""` (empty string)                                                                                 |
| `use_global_context`                | Use the global kubecontext for all operations by default.                                                          | `true`                                                                                              |
| `enable_install_controller`         | Enable the installation of the Kubeslice controller.                                                               | `true`                                                                                              |
| `enable_install_ui`                 | Enable the installation of the Kubeslice UI.                                                                       | `true`                                                                                              |
| `enable_install_worker`             | Enable the installation of Kubeslice workers.                                                                      | `true`                                                                                              |
| `enable_install_additional_apps`    | Enable the installation of additional applications (prometheus, gpu-operator, postgresql).                          | `false`                                                                                             |
| `enable_custom_apps`                | Enable custom applications deployment, useful for NVIDIA driver installation.                                       | `true`                                                                                              |
| `run_commands`                      | Enable execution of commands for configuring NVIDIA MIG and node labeling.                                         | `false`                                                                                             |
| `enable_project_creation`           | Enable project creation in Kubeslice.                                                                              | `true`                                                                                              |
| `enable_cluster_registration`       | Enable cluster registration in Kubeslice.                                                                          | `true`                                                                                              |
| `enable_prepare_worker_values_file` | Prepare the worker values file for Helm charts.                                                                    | `true`                                                                                              |
| `enable_autofetch_egsagent_endpoint_and_token` | Auto-fetch egsAgent token and endpoint values.                                                              | `true`                                                                                              |
| `global_auto_fetch_endpoint`        | Enable automatic fetching of monitoring endpoints globally.                                                         | `false`                                                                                             |
| `global_grafana_namespace`          | Namespace where Grafana is globally deployed.                                                                      | `egs-monitoring`                                                                                    |
| `global_grafana_service_type`       | Service type for Grafana (accessible only within the cluster).                                                     | `ClusterIP`                                                                                         |
| `global_grafana_service_name`       | Service name for accessing Grafana globally.                                                                       | `prometheus-grafana`                                                                                |
| `global_prometheus_namespace`       | Namespace where Prometheus is globally deployed.                                                                   | `egs-monitoring`                                                                                    |
| `global_prometheus_service_name`    | Service name for accessing Prometheus globally.                                                                     | `prometheus-kube-prometheus-prometheus`                                                             |
| `global_prometheus_service_type`    | Service type for Prometheus (accessible only within the cluster).                                                  | `ClusterIP`                                                                                         |
| `precheck`                          | Run general prechecks before starting the installation.                                                            | `true`                                                                                              |
| `kubeslice_precheck`                | Run specific prechecks for Kubeslice components.                                                                   | `true`                                                                                              |
| `verify_install`                    | Enable verification of installations globally.                                                                      | `false`                                                                                             |
| `verify_install_timeout`            | Timeout for global installation verification (in seconds).                                                         | `600`                                                                                               |
| `skip_on_verify_fail`               | Skip steps where verification fails, otherwise exit on failure.                                                    | `true`                                                                                              |
| `base_path`                         | Base path to the root directory of the cloned repository.                                                          | `""` (empty string)                                                                                 |
| `use_local_charts`                  | Use local Helm charts instead of fetching them from a repository.                                                  | `true`                                                                                              |
| `local_charts_path`                 | Path to the directory containing local Helm charts.                                                                | `"charts"`                                                                                          |
| `global_helm_repo_url`              | URL for the global Helm repository (if not using local charts).                                                   | `""`                                                                                                |
| `global_helm_username`              | Username for accessing the global Helm repository.                                                                 | `""`                                                                                                |
| `global_helm_password`              | Password for accessing the global Helm repository.                                                                 | `""`                                                                                                |
| `readd_helm_repos`                  | Re-add Helm repositories even if they are already present.                                                         | `true`                                                                                              |
| `required_binaries`                 | List of binaries required for the installation process.                                                            | `yq`, `helm`, `jq`, `kubectl`                                                                      |
| `add_node_label`                    | Enable node labeling during installation.                                                                           | `false`                                                                                             |
| `version`                           | Version of the input configuration file.                                                                           | `"1.14.4"`                                                                                          |

#### `kubeslice_controller_egs` Subfields

| **Subfield**                  | **Description**                                                                                         | **Default/Example**                                                             |
|-------------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `skip_installation`           | Skip the installation of the Kubeslice controller if it's already installed or not needed.               | `false`                                                                         |
| `use_global_kubeconfig`       | Use the global kubeconfig file for the controller installation.                                          | `true`                                                                          |
| `specific_use_local_charts`   | Use local charts specifically for the controller installation, overriding the global `use_local_charts` setting. | `true`                                                                          |
| `kubeconfig`                  | Path to the kubeconfig file specific to the controller, if empty, uses the global kubeconfig.            | `""` (empty string)                                                             |
| `kubecontext`                 | Kubecontext specific to the controller; if empty, uses the global context.                              | `""` (empty string)                                                             |
| `namespace`                   | Kubernetes namespace where the Kubeslice controller will be installed.                                   | `"kubeslice-controller"`                                                        |
| `release`                     | Helm release name for the Kubeslice controller.                                                          | `"egs-controller"`                                                              |
| `chart`                       | Helm chart name used for installing the Kubeslice controller.                                            | `"kubeslice-controller-egs"`                                                    |
| `inline_values`               | Inline values passed to the Helm chart during installation.                                              | See inline values section below                                                 |
| `helm_flags`                  | Additional Helm flags for the controller installation.                                                   | `"--wait --timeout 5m --debug"`                                                 |
| `verify_install`              | Verify the installation of the Kubeslice controller after deployment.                                    | `false`                                                                         |
| `verify_install_timeout`      | Timeout for verifying the installation of the controller, in seconds.                                    | `30` (30 seconds)                                                               |
| `skip_on_verify_fail`         | Skip further steps or exit if the controller verification fails.                                         | `true`                                                                          |
| `enable_troubleshoot`         | Enable troubleshooting mode for additional logs and checks.                                               | `false`                                                                         |

#### `kubeslice_ui_egs` Subfields

| **Subfield**                | **Description**                                                                                           | **Default/Example**                                           |
|-----------------------------|-----------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| `skip_installation`         | Skip the installation of the Kubeslice UI if it's already installed or not needed.                         | `false`                                                       |
| `use_global_kubeconfig`     | Use the global kubeconfig file for the UI installation.                                                   | `true`                                                        |
| `kubeconfig`                | Path to the kubeconfig file specific to the UI, if empty, uses the global kubeconfig.                     | `""` (empty string)                                           |
| `kubecontext`               | Kubecontext specific to the UI; if empty, uses the global context.                                       | `""` (empty string)                                           |
| `namespace`                 | Kubernetes namespace where the Kubeslice UI will be installed.                                            | `"kubeslice-controller"`                                      |
| `release`                   | Helm release name for the Kubeslice UI.                                                                   | `"egs-ui"`                                                    |
| `chart`                     | Helm chart name used for installing the Kubeslice UI.                                                     | `"kubeslice-ui-egs"`                                          |
| `inline_values`             | Inline values passed to the Helm chart during installation.                                               | See inline values section below                                |
| `helm_flags`                | Additional Helm flags for the UI installation.                                                            | `"--wait --timeout 5m --debug"`                                |
| `verify_install`            | Verify the installation of the Kubeslice UI after deployment.                                             | `false`                                                       |
| `verify_install_timeout`    | Timeout for verifying the installation of the UI, in seconds.                                             | `50` (50 seconds)                                             |
| `skip_on_verify_fail`       | Skip further steps or exit if the UI verification fails.                                                  | `true`                                                        |
| `specific_use_local_charts` | Use local charts specifically for the UI installation.                                                   | `true`                                                        |

#### `kubeslice_worker_egs` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                                                         |
|-----------------------------|---------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `name`                      | Name of the worker node configuration.                                                                  | `"worker-1"`                                                                                                |
| `use_global_kubeconfig`     | Use the global kubeconfig file for the worker installation.                                             | `true`                                                                                                      |
| `kubeconfig`                | Path to the kubeconfig file specific to the worker, if empty, uses the global kubeconfig.               | `""` (empty string)                                                                                         |
| `kubecontext`               | Kubecontext specific to the worker; if empty, uses the global context.                                 | `""` (empty string)                                                                                         |
| `skip_installation`         | Skip the installation of the worker if it's already installed or not needed.                            | `false`                                                                                                     |
| `specific_use_local_charts` | Use local charts specifically for the worker installation.                                               | `true`                                                                                                      |
| `namespace`                 | Kubernetes namespace where the worker will be installed.                                                | `"kubeslice-system"`                                                                                        |
| `release`                   | Helm release name for the worker.                                                                       | `"egs-worker"`                                                                                              |
| `chart`                     | Helm chart name used for installing the worker.                                                         | `"kubeslice-worker-egs"`                                                                                    |
| `inline_values`             | Inline values passed to the Helm chart during installation.                                              | See inline values section below                                                                              |
| `helm_flags`                | Additional Helm flags for the worker installation.                                                      | `"--wait --timeout 5m --debug"`                                                                              |
| `verify_install`            | Verify the installation of the worker after deployment.                                                 | `true`                                                                                                      |
| `verify_install_timeout`    | Timeout for verifying the installation of the worker, in seconds.                                       | `60` (60 seconds)                                                                                           |
| `skip_on_verify_fail`       | Skip further steps or exit if the worker verification fails.                                            | `false`                                                                                                     |
| `enable_troubleshoot`       | Enable troubleshooting mode for additional logs and checks.                                              | `false`                                                                                                     |

#### `additional_apps` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `name`                      | Name of the application to install (e.g., gpu-operator, prometheus, postgresql).                        | `"gpu-operator"`                                                               |
| `skip_installation`         | Skip the installation of this application if it's already installed or not needed.                      | `false`                                                                        |
| `use_global_kubeconfig`     | Use the global kubeconfig file for this application installation.                                       | `true`                                                                         |
| `kubeconfig`                | Path to the kubeconfig file specific to this application.                                               | `""` (empty string)                                                            |
| `kubecontext`               | Kubecontext specific to this application; uses global context if empty.                                | `""` (empty string)                                                            |
| `namespace`                 | Kubernetes namespace where the application will be installed.                                           | `"egs-gpu-operator"`                                                           |
| `release`                   | Helm release name for the application.                                                                  | `"gpu-operator"`                                                               |
| `chart`                     | Helm chart name for the application.                                                                    | `"gpu-operator"`                                                               |
| `repo_url`                  | Helm repository URL for the application.                                                                | `"https://helm.ngc.nvidia.com/nvidia"`                                        |
| `version`                   | Version of the application to install.                                                                 | `"v24.9.1"`                                                                   |
| `specific_use_local_charts` | Use local charts for this application.                                                                 | `true`                                                                        |
| `values_file`               | Path to an external values file, if any.                                                               | `""`                                                                           |
| `inline_values`             | Inline values passed to the Helm chart during installation.                                              | See inline values section below                                                |
| `helm_flags`                | Additional Helm flags for the application installation.                                                 | `"--debug"`                                                                   |
| `verify_install`            | Verify the installation of the application after deployment.                                            | `false`                                                                       |
| `verify_install_timeout`    | Timeout for verifying the installation, in seconds.                                                     | `600`                                                                         |
| `skip_on_verify_fail`       | Skip the step if verification fails.                                                                   | `true`                                                                        |
| `enable_troubleshoot`       | Enable troubleshooting mode for additional logs and checks.                                              | `false`                                                                       |

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

#### `commands` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `use_global_kubeconfig`     | Use the global kubeconfig file for these commands.                                                      | `true`                                                                         |
| `kubeconfig`                | Path to the kubeconfig file specific to these commands.                                                 | `""` (empty string)                                                            |
| `kubecontext`               | Kubecontext specific to these commands; uses global context if empty.                                  | `""` (empty string)                                                            |
| `skip_installation`         | Skip the execution of these commands.                                                                   | `false`                                                                        |
| `verify_install`            | Verify the execution of these commands.                                                                 | `false`                                                                        |
| `verify_install_timeout`    | Timeout for verifying the command execution, in seconds.                                                | `200`                                                                          |
| `skip_on_verify_fail`       | Skip if command verification fails.                                                                     | `true`                                                                         |
| `namespace`                 | Namespace context for these commands.                                                                   | `kube-system`                                                                  |
| `command_stream`            | Commands to execute (e.g., node labeling, MIG configuration).                                           | See command examples below                                                     |

#### `enable_troubleshoot` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `enabled`                   | Global enable troubleshooting mode for additional logs and checks.                                       | `false`                                                                        |
| `resource_types`            | List of resource types to troubleshoot (pods, deployments, daemonsets, etc.).                           | `["pods", "deployments", "daemonsets"]`                                        |
| `api_groups`                | List of API groups to troubleshoot (controller.kubeslice.io, worker.kubeslice.io, etc.).                | `["controller.kubeslice.io", "worker.kubeslice.io"]`                           |
| `upload_logs.enabled`       | Enable log upload functionality.                                                                         | `false`                                                                        |
| `upload_logs.command`       | Command to execute for log upload.                                                                      | `""`                                                                           |

#### `projects` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `name`                      | Name of the Kubeslice project.                                                                          | `"avesha"`                                                                     |
| `username`                  | Username for accessing the Kubeslice project.                                                            | `"admin"`                                                                      |

#### `cluster_registration` Subfields

| **Subfield**                | **Description**                                                                                         | **Default/Example**                                                             |
|-----------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `cluster_name`              | Name of the cluster to be registered.                                                                   | `"worker-1"`                                                                   |
| `project_name`              | Name of the project to associate with the cluster.                                                      | `"avesha"`                                                                     |
| `telemetry.enabled`         | Enable telemetry for this cluster.                                                                      | `true`                                                                         |
| `telemetry.endpoint`        | Telemetry endpoint for the cluster.                                                                     | `"http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"` |
| `telemetry.telemetryProvider` | Telemetry provider (Prometheus in this case).                                                        | `"prometheus"`                                                                 |
| `geoLocation.cloudProvider` | Cloud provider for this cluster (e.g., GCP, AWS, Azure).                                               | `""`                                                                           |
| `geoLocation.cloudRegion`   | Cloud region for this cluster (e.g., us-central1, eu-west-1).                                          | `""`                                                                           |


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

## 🔑 Slice & Admin Token Retrieval

For detailed information about retrieving slice and admin tokens for Kubernetes authentication, including comprehensive script usage and examples, please refer to:

**[🔒 Slice & Admin Token Documentation](docs/Slice-Admin-Token-README.md)**

This documentation covers:
- Token retrieval script features and capabilities
- Script parameters and usage options
- Examples for slice tokens, admin tokens, and combined retrieval
- Help and troubleshooting information
## ✅ EGS Preflight Check

For detailed information about running preflight checks to validate your EGS installation environment, including comprehensive script options and usage examples, please refer to:

**[🔍 EGS Preflight Check Documentation](docs/EGS-Preflight-Check-README.md)**

This documentation covers:
- Comprehensive preflight check script features and options
- Resource validation and privilege checking
- Multi-cluster and multi-context support
- Wrapper functions and usage examples
- Troubleshooting and best practices

---
## 🗂️ Namespace Creation

For detailed information about creating Kubernetes namespaces with custom annotations and labels, including the automated namespace creation script, please refer to:

**[📋 Namespace Creation Documentation](docs/Namespace-Creation-README.md)**

This documentation covers:
- Automated namespace creation script features
- Input YAML format specifications
- Script parameters and usage examples
- Multi-context support and logging
- Troubleshooting and best practices

---

## 📊 Custom Pricing Configuration

For detailed information about configuring custom pricing for your EGS installation, including pricing data upload scripts and YAML configuration formats, please refer to:

**[📋 Custom Pricing Documentation](docs/Custom-Pricing-README.md)**

This documentation covers:
- Cloud instance pricing data configuration
- Kubernetes connection setup
- Pricing upload scripts
- YAML format specifications
- Troubleshooting and best practices

---
