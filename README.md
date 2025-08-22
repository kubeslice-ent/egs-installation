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
- ✅ For preflight checks, please refer to the [EGS Preflight Check Documentation](docs/EGS-Preflight-Check-README.md) 🔍  
- 📋 For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](https://github.com/kubeslice-ent/egs-installation#token-retrieval) 🔒  
- 🗂️ For precreate required namespace, please refer to the [Namespace Creation Script Documentation](https://github.com/kubeslice-ent/egs-installation#namespace-creation) 🗂️  
- 🚀 For EGS Controller prerequisites, please refer to the [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md) 📋  
- ⚙️ For EGS Worker prerequisites, please refer to the [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md) 🔧  

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

     - **🖥 Global Monitoring Endpoint Settings (Optional):**
       - Configure global monitoring endpoint settings for multi-cluster setups:
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

         The controller installation is configured through the `kubeslice_controller_egs` section in your `egs-installer-config.yaml`:

         ```yaml
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
               imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems   # Docker registry for the images
               namespaceConfig:   # user can configure labels or annotations that EGS Controller namespaces should have
                 labels: {}
                 annotations: {}
               kubeTally:
                 enabled: false                          # Enable KubeTally in the controller
         #### Postgresql Connection Configuration for Kubetally  ####
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
         ```

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
   
   **📝 Note:** Global monitoring endpoint settings are configured in the [Additional Configuration](#2-modify-the-configuration-file-mandatory) section above, including `global_auto_fetch_endpoint` and related Grafana/Prometheus settings.
   
   #### **⚠️ Multi-Cluster Setup Configuration**
   
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
      ```

### 4. **➕ Adding Additional Workers (Optional) **

   To add another worker to your EGS setup, you need to make an entry in the `kubeslice_worker_egs` section of your `egs-installer-config.yaml` file. Follow these steps:

   #### **📝 Step 1: Add Worker Configuration**
   
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
