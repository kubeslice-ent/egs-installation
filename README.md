# 🌐 EGS Installer Script

This README provides a comprehensive guide to using the EGS Installer Script, which automates the deployment of EGS components such as Kubeslice controller, UI, and and array of worker within a Kubernetes environment.

## 🚀 Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

## ✅ Prerequisites

Before using the EGS Installer Script, ensure that the following prerequisites are met:

- **Binaries**: The following binaries must be installed and available in your system's `PATH`:
  - `yq` 📄
  - `helm` 🛠️
  - `kubectl` ⚙️
- **Kubernetes**: Ensure that you have access to the necessary Kubernetes clusters with the appropriate kubeconfig files.

## 🛠️ Configuration

The script requires a YAML configuration file to define various parameters and settings for the installation process. Below is an example configuration file (`egs-installer-config.yaml`) with descriptions for each section.

### 📝 YAML Configuration File

```yaml
Here's the YAML configuration file with added comments for each section and key:

```yaml
# The base path to the root directory of your cloned repository.
# This will be used as a reference for all relative paths in the script, if empty it will use relative path to script.
base_path: ""

# Whether to run a pre-check before starting the installation process.
# This check validates the environment and required binaries.
precheck: true

# Whether to perform pre-checks specific to Kubeslice components.
# This includes verifying access to the clusters and checking node labels.
kubeslice_precheck: true

# Global setting to enable or disable installation verification.
# If set to true, the script will verify that all installed components are running.
verify_install: true

# Global timeout for installation verification, in seconds.
# This sets the maximum time the script will wait for all components to be verified as running.
verify_install_timeout: 600  # 10 minutes

# Global flag to decide whether to skip further steps if verification fails.
# If set to false, the script will exit on verification failure.
skip_on_verify_fail: false

# The URL of the global Helm repository from which charts will be pulled.
# This can be overridden at the individual component level if needed.
global_helm_repo_url: "https://smartscaler.nexus.aveshalabs.io/repository/kubeslice-egs-helm-ent-prod"

# Credentials for accessing the global Helm repository.
# These are optional and can be left empty if not required.
global_helm_username: ""  # Global Helm repository username
global_helm_password: ""  # Global Helm repository password

# Whether to remove and re-add Helm repositories if they already exist.
# This ensures that the latest repository configuration is always used.
readd_helm_repos: true

# A list of binaries that are required for the installation process.
# The script will check for these and exit if any are missing.
required_binaries:
  - yq       # YAML processor used for parsing and processing YAML files.
  - helm     # Helm package manager used for deploying Kubernetes applications.
  - kubectl  # Command-line tool for controlling Kubernetes clusters.

# Global image pull secret settings for accessing private Docker registries.
# These settings can be overridden at the component level if different credentials are needed.
global_image_pull_secret:
  repository: "https://index.docker.io/v1/"
  username: ""  # Global Docker registry username
  password: ""  # Global Docker registry password

# Whether to automatically label nodes in worker clusters.
# This is useful for ensuring that certain nodes are reserved for specific tasks.
add_node_label: true

# Path to the global kubeconfig file used to access Kubernetes clusters.
# This path is relative to the base_path and is used for all cluster interactions unless overridden.
global_kubeconfig: "config/global/kubeconfig.yaml"

# Whether to use local Helm charts instead of pulling them from a repository.
# This is useful for testing or when access to the remote repository is restricted.
use_local_charts: true

# Path to the local Helm charts directory, relative to base_path.
# This is used only if use_local_charts is set to true.
local_charts_path: "charts"

# Global kubecontext to be used across all Kubernetes interactions.
# If empty, the default context will be used.
global_kubecontext: ""

# Whether to use the global kubecontext by default.
# If set to true, the global context will be used unless a specific context is provided for a component.
use_global_context: true

# Whether to fetch controller secrets from the worker clusters.
# This is typically used for advanced configurations and is disabled by default.
enable_fetch_controller_secrets: false

# Whether to prepare the worker values file before installation.
# This step is necessary if the worker configuration depends on dynamic values.
enable_prepare_worker_values_file: true

# Whether to install the Kubeslice controller.
# Set this to false if the controller is already installed and does not need to be updated.
enable_install_controller: true

# Whether to install the Kubeslice UI.
# Set this to false if the UI is already installed and does not need to be updated.
enable_install_ui: true

# Whether to install the Kubeslice workers.
# Set this to false if the workers are already installed and do not need to be updated.
enable_install_worker: true

# Configuration settings for installing the Kubeslice controller.
kubeslice_controller_egs:
  # Whether to skip the installation of the Kubeslice controller.
  skip_installation: false
  
  # Whether to use the global kubeconfig for the Kubeslice controller installation.
  use_global_kubeconfig: true
  
  # Path to the kubeconfig file for the Kubeslice controller.
  # This is relative to base_path and can be overridden if a different kubeconfig is needed.
  kubeconfig: "config/global/kubeconfig.yaml"
  
  # Kubernetes namespace where the Kubeslice controller will be installed.
  namespace: "kubeslice-controller"
  
  # Name of the Helm release for the Kubeslice controller.
  release: "kubeslice-controller-release"
  
  # Name of the Helm chart used for installing the Kubeslice controller.
  chart: "kubeslice-controller-egs"
  
  # Inline values to be passed to the Helm chart during installation.
  # These settings can override values in the chart's default values.yaml file.
  inline_values:
    kubeslice:
      controller:
        endpoint: ""  # Endpoint for the Kubeslice controller (should be set during installation).
    imagePullSecrets:
      repository: "https://index.docker.io/v1/"
      username: ""  # Docker registry username for pulling controller images.
      password: ""  # Docker registry password for pulling controller images.
  
  # Additional flags to be passed to the Helm command during installation.
  helm_flags: "--timeout 10m --atomic"
  
  # Whether to verify the installation of the Kubeslice controller.
  verify_install: true
  
  # Timeout for verifying the installation, in seconds.
  verify_install_timeout: 30  # 30 seconds
  
  # Whether to skip further steps if the verification fails.
  skip_on_verify_fail: false

# Configuration settings for installing the Kubeslice UI.
kubeslice_ui_egs:
  # Whether to skip the installation of the Kubeslice UI.
  skip_installation: false
  
  # Whether to use the global kubeconfig for the Kubeslice UI installation.
  use_global_kubeconfig: true
  
  # Kubernetes namespace where the Kubeslice UI will be installed.
  namespace: "kubeslice-controller"
  
  # Name of the Helm release for the Kubeslice UI.
  release: "kubeslice-ui"
  
  # Name of the Helm chart used for installing the Kubeslice UI.
  chart: "kubeslice-ui-egs"
  
  # Additional flags to be passed to the Helm command during installation.
  helm_flags: "--atomic"
  
  # Whether to verify the installation of the Kubeslice UI.
  verify_install: true
  
  # Timeout for verifying the installation, in seconds.
  verify_install_timeout: 50  # 50 seconds
  
  # Whether to skip further steps if the verification fails.
  skip_on_verify_fail: true

# Configuration settings for installing the Kubeslice workers.
kubeslice_worker_egs:
  - name: "worker-1"  # Name of the worker node configuration.
    
    # Whether to use the global kubeconfig for the worker installation.
    use_global_kubeconfig: true
    
    # Whether to skip the installation of this worker.
    skip_installation: false
    
    # Kubernetes namespace where this worker will be installed.
    namespace: "kubeslice-system"
    
    # Name of the Helm release for this worker.
    release: "kubeslice-worker1-release"
    
    # Name of the Helm chart used for installing this worker.
    chart: "kubeslice-worker-egs"
    
    # Inline values to be passed to the Helm chart during installation.
    inline_values:
      kubesliceNetworking:
        enabled: false  # Disable Kubeslice networking for this worker.
      egs:
        prometheusEndpoint: http://prometheus-test  # Prometheus endpoint for this worker.
        grafanaDashboardBaseUrl: http://grafana-test  # Grafana dashboard URL for this worker.
      metrics:
        insecure: true  # Allow insecure connections for metrics.
    
    # Whether to verify the installation of this worker.
    verify_install: true
    
    # Timeout for verifying the installation, in seconds.
    verify_install_timeout: 60  # 60 seconds
    
    # Whether to skip further steps if the verification fails.
    skip_on_verify_fail: false

# Whether to create projects in the Kubeslice controller before deploying workers.
# This step ensures that the necessary projects exist in the controller.
enable_project_creation: true

# Whether to register clusters in the Kubeslice controller after projects have been created.
# This step adds the clusters to the appropriate projects.
enable_cluster_registration: true

# Define projects to be created in the Kubeslice controller.
projects:
  - name: "avesha"  # Name of the project to be created in the controller.
    username: "jupiter"  # Username associated with this project.

# Define clusters to be registered in the Kubeslice controller.
cluster_registration:
  - cluster_name: "worker-1"  # Name of the cluster to be registered.
    project_name: "avesha"  # Name of the project to which this cluster belongs.
    telemetry:
      enabled: true  # Enable telemetry for this cluster.
      telemetryProvider: "prometheus"  #

 Telemetry provider for this cluster.
    geoLocation:
      cloudProvider: "GCP"  # Cloud provider for this cluster (e.g., GCP, AWS).
      cloudRegion: "us-central1"  # Cloud region for this cluster.
```

### Summary of Added Comments:
- **Explanation of each key**: Detailed comments explain the purpose and usage of each key and section within the YAML configuration file.
- **Default values**: For fields where defaults are commonly applied or where a value should be specified during runtime, notes have been added to indicate this.
- **Clarification of settings**: Each block of the YAML file is clarified with comments to make it easier to understand the intended configuration and to help avoid common pitfalls.

This should make the YAML configuration file much easier to understand and customize, especially for users who are new to the script or the specific technologies involved.
```

### 🧑‍💻 Script Usage

To run the script, use the following command:

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

### 📌 Conclusion

The EGS Installer Script is a powerful tool for automating the deployment of Kubeslice components across multiple Kubernetes clusters. With proper configuration and usage, it can significantly simplify the installation and management of complex Kubernetes environments. 🌟

---
