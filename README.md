---
# 🌐 EGS Installer Script

This README provides a comprehensive guide to using the EGS Installer Script, which automates the deployment of EGS components such as Kubeslice controller, UI, and an array of workers within a Kubernetes environment.

## 🚀 Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

## ✅ Prerequisites

Before using the EGS Installer Script, ensure that the following prerequisites are met:

- **Binaries**: The following binaries must be installed and available in your system's `PATH`:
  - `yq` 📄 (minimum version: 4.0.0)
  - `helm` 🛠️ (minimum version: 3.5.0)
  - `kubectl` ⚙️ (minimum version: 1.20.0)
- **Kubernetes Access**: Ensure you have administrative access to the necessary Kubernetes clusters with the appropriate kubeconfig files.

## 🛠️ Configuration

The script requires a YAML configuration file to define various parameters and settings for the installation process. Below is an example configuration file (`egs-installer-config.yaml`) with descriptions for each section.

## ⚠️ Warning
**Do not copy the YAML configuration directly from this README.** Hash characters (`#`) used for comments may not be interpreted correctly. Always refer to the actual `egs-installer-config.yaml` file available in the repository for accurate configuration.

### 📝 YAML Configuration File

# Base path to the root directory of your cloned repository
base_path: ""  # if empty it will take relative path to script as base path

# Precheck options
precheck: true  # Run prechecks before installation
kubeslice_precheck: true  # Specific precheck for Kubeslice components

# Global installation verification settings
verify_install: true  # Enable installation verification globally
verify_install_timeout: 600  # Global timeout for verification (in seconds)
skip_on_verify_fail: false  # Decide whether to skip or error out if verification fails globally

# Helm repository settings
global_helm_repo_url: "https://smartscaler.nexus.aveshalabs.io/repository/kubeslice-egs-helm-ent-prod"
global_helm_username: ""  # Global Helm repository username
global_helm_password: ""  # Global Helm repository password
readd_helm_repos: true  # Re-add Helm repositories if they already exist

# List of required binaries for the installation process
required_binaries:
  - yq
  - helm
  - kubectl

# Global image pull secret settings
global_image_pull_secret:
  repository: "https://index.docker.io/v1/"
  username: ""  # Global Docker registry username
  password: ""  # Global Docker registry password

# Node labeling settings
add_node_label: true  # Enable node labeling during installation

# Kubeconfig settings
global_kubeconfig: ""  # Relative path to global kubeconfig file
use_local_charts: true  # Use local charts instead of pulling from a repository
local_charts_path: "charts"  # Relative path to local charts directory
global_kubecontext: ""  # Global kubecontext, if empty, the default context will be used
use_global_context: true  # Use global kubecontext by default for all operations

# Enable or disable specific stages of the installation
enable_prepare_worker_values_file: true  # Enable preparing worker values file
enable_install_controller: true  # Enable installation of the controller
enable_install_ui: true  # Enable installation of the UI
enable_install_worker: true  # Enable installation of the worker

# Kubeslice controller installation settings
kubeslice_controller_egs:
  skip_installation: false  # Do not skip the installation of the controller
  use_global_kubeconfig: true  # Use global kubeconfig for the controller
  specific_use_local_charts: true  # Use local charts specifically for controller installation
  kubeconfig: ""  # Relative path to controller kubeconfig file
  kubecontext: ""  # Controller-specific kubecontext, uses global if empty
  namespace: "kubeslice-controller"  # Kubernetes namespace for the controller
  release: "kubeslice-controller-release"  # Helm release name for the controller
  chart: "kubeslice-controller-egs"  # Helm chart name for the controller
  inline_values:  # Inline values for the Helm chart
    kubeslice:
      controller:
        endpoint: ""  # Controller endpoint, should be set during installation
  helm_flags: "--timeout 10m --atomic"  # Additional Helm flags for installation
  verify_install: true  # Verify controller installation
  verify_install_timeout: 30  # Timeout for controller installation verification (in seconds)
  skip_on_verify_fail: false  # Do not skip if verification fails

# Kubeslice UI installation settings
kubeslice_ui_egs:
  skip_installation: false  # Do not skip the installation of the UI
  use_global_kubeconfig: true  # Use global kubeconfig for the UI
  specific_use_local_charts: true  # Use local charts specifically for UI installation
  namespace: "kubeslice-controller"  # Kubernetes namespace for the UI
  release: "kubeslice-ui"  # Helm release name for the UI
  chart: "kubeslice-ui-egs"  # Helm chart name for the UI
  helm_flags: "--atomic"  # Additional Helm flags for installation
  verify_install: true  # Verify UI installation
  verify_install_timeout: 50  # Timeout for UI installation verification (in seconds)
  skip_on_verify_fail: false  # Do not skip if verification fails

# Kubeslice worker installation settings
kubeslice_worker_egs:
  - name: "worker-1"
    use_global_kubeconfig: true  # Use global kubeconfig for this worker
    skip_installation: false  # Do not skip the installation of the worker
    specific_use_local_charts: true  # Use local charts specifically for worker installation
    namespace: "kubeslice-system"  # Kubernetes namespace for the worker
    release: "kubeslice-worker1-release"  # Helm release name for the worker
    chart: "kubeslice-worker-egs"  # Helm chart name for the worker
    inline_values:  # Inline values for the worker Helm chart
      kubesliceNetworking:
        enabled: false  # Disable Kubeslice networking for this worker
      egs:
        prometheusEndpoint: "http://prometheus-test"  # Prometheus endpoint
        grafanaDashboardBaseUrl: "http://grafana-test"  # Grafana dashboard base URL
      metrics:
        insecure: true  # Allow insecure connections for metrics
    helm_flags: "--atomic"  # Additional Helm flags for worker installation
    verify_install: true  # Verify worker installation
    verify_install_timeout: 60  # Timeout for worker installation verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if worker verification fails

# Project and cluster registration settings
enable_project_creation: true  # Enable project creation
enable_cluster_registration: true  # Enable cluster registration

# Define projects
projects:
  - name: "avesha"
    username: "admin"  # Username associated with the project

# Define cluster registration
cluster_registration:
  - cluster_name: "worker-1"
    project_name: "avesha"
    telemetry:
      enabled: true  # Enable telemetry for this cluster
      endpoint: ""  # Telemetry endpoint, should be set during registration
      telemetryProvider: "prometheus"  # Telemetry provider
    geoLocation:
      cloudProvider: "GCP"  # Cloud provider for this cluster
      cloudRegion: "us-central1"  # Cloud region for this cluster

# Additional application installation settings
enable_install_additional_apps: true  # Enable installation of additional apps

additional_apps:
  - name: "gpu-operator"
    skip_installation: false
    use_global_kubeconfig: true  # Use global kubeconfig for this additional app
    namespace: "gpu-operator"  # Kubernetes namespace for the additional app
    release: "gpu-operator-release"  # Helm release name for the additional app
    chart: "gpu-operator"  # Helm chart name for the additional app
    repo_url: "https://helm.ngc.nvidia.com/nvidia"  # Repository URL for the Helm chart
    version: "v24.6.0"  # Specific version of the Helm chart to be installed
    specific_use_local_charts: false  # Override to use the remote chart instead of local
    inline_values:  # Inline values for the Helm chart
      hostPaths:
        driverInstallDir: "/home/kubernetes/bin/nvidia"
      toolkit:
        installDir: "/home/kubernetes/bin/nvidia"
      cdi:
        enabled: true
        default: true
      driver:
        enabled: false
    helm_flags: "--wait"  # Additional Helm flags for installation
    verify_install: true  # Verify installation of the additional app
    verify_install_timeout: 600  # Timeout for additional app installation verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if additional app verification fails

  - name: "prometheus"
    skip_installation: false
    use_global_kubeconfig: true  # Use global kubeconfig for this additional app
    namespace: "monitoring"  # Kubernetes namespace for the additional app
    release: "prometheus"  # Helm release name for the additional app
    chart: "kube-prometheus-stack"  # Helm chart name for the additional app
    repo_url: "https://prometheus-community.github.io/helm-charts"  # Repository URL for the Helm chart
    version: "v45.0.0"  # Specific version of the Helm chart to be installed
    specific_use_local_charts: false  # Override to use the remote chart instead of local
    values_file: ""  # Path to the values file for the additional app (if any)
    inline_values:  # Inline values for the Helm chart
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
        persistence:
          enabled: true
          size: 1Gi
    helm_flags: "--wait"  # Additional Helm flags for installation
    verify_install: true  # Verify installation of the additional app
    verify_install_timeout: 600  # Timeout for additional app installation verification (in seconds)
    skip_on_verify_fail: false  # Do not skip if additional app verification fails
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
