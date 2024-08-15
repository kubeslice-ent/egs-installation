# EGS Installer Script

This README provides a comprehensive guide to using the EGS Installer Script, which automates the deployment of EGS components such as Kubeslice controllers, UIs, and workers within a Kubernetes environment.

## Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

## Prerequisites

Before using the EGS Installer Script, ensure that the following prerequisites are met:

- **Binaries**: The following binaries must be installed and available in your system's `PATH`:
  - `yq`
  - `helm`
  - `kubectl`
  - `kubectx`
- **Kubernetes**: Ensure that you have access to the necessary Kubernetes clusters with the appropriate kubeconfig files.

## Configuration

The script requires a YAML configuration file to define various parameters and settings for the installation process. Below is an example configuration file (`egs-installation-config.yaml`) with descriptions for each section.

### YAML Configuration File

```yaml
base_path: "/home/richie/egs-installation"  # Set to the root directory of your cloned repository

precheck: true  # Run prechecks before installation
kubeslice_precheck: true  # Perform pre-checks specific to Kubeslice components

verify_install: true  # Enable installation verification globally
verify_install_timeout: 600  # Timeout for installation verification in seconds
skip_on_verify_fail: false  # Exit script if verification fails

global_helm_repo_url: "https://smartscaler.nexus.aveshalabs.io/repository/kubeslice-egs-helm-ent-prod"  # Global Helm repository URL
global_helm_username: ""  # Global Helm repository username
global_helm_password: ""  # Global Helm repository password
readd_helm_repos: true  # Remove and re-add Helm repositories if they already exist

required_binaries:  # List of required binaries
  - yq
  - helm
  - kubectl
  - kubectx

global_image_pull_secret:  # Global image pull secret settings
  repository: "https://index.docker.io/v1/"
  username: ""
  password: ""

add_node_label: true  # Automatically label nodes in worker clusters
global_kubeconfig: "config/global/kubeconfig.yaml"  # Path to the global kubeconfig file
use_local_charts: true  # Use local Helm charts instead of pulling from a repository
local_charts_path: "charts"  # Path to the local Helm charts directory
global_kubecontext: ""  # Global kubecontext (optional)
use_global_context: true  # Use the global kubecontext by default

enable_fetch_controller_secrets: false  # Fetch controller secrets (disabled by default)
enable_prepare_worker_values_file: true  # Prepare worker values files
enable_install_controller: true  # Enable installation of the Kubeslice controller
enable_install_ui: true  # Enable installation of the Kubeslice UI
enable_install_worker: true  # Enable installation of Kubeslice workers

kubeslice_controller_egs:  # Configuration for Kubeslice controller installation
  skip_installation: false
  use_global_kubeconfig: true
  kubeconfig: "config/global/kubeconfig.yaml"
  namespace: "kubeslice-controller"
  release: "kubeslice-controller-release"
  chart: "kubeslice-controller-egs"
  inline_values:
    kubeslice:
      controller:
        endpoint: ""
    imagePullSecrets:
      repository: "https://index.docker.io/v1/"
      username: ""
      password: ""
  helm_flags: "--timeout 10m --atomic"
  verify_install: true
  verify_install_timeout: 30
  skip_on_verify_fail: false

kubeslice_ui_egs:  # Configuration for Kubeslice UI installation
  skip_installation: false
  use_global_kubeconfig: true
  namespace: "kubeslice-controller"
  release: "kubeslice-ui"
  chart: "kubeslice-ui-egs"
  helm_flags: "--atomic"
  verify_install: true
  verify_install_timeout: 50
  skip_on_verify_fail: true

kubeslice_worker_egs:  # Configuration for Kubeslice worker installations
  - name: "worker-1"
    use_global_kubeconfig: true
    skip_installation: false
    namespace: "kubeslice-system"
    release: "kubeslice-worker1-release"
    chart: "kubeslice-worker-egs"
    inline_values:
      kubesliceNetworking:
        enabled: false
      egs:
        prometheusEndpoint: http://prometheus-test
        grafanaDashboardBaseUrl: http://grafana-test
      metrics:
        insecure: true
    verify_install: true
    verify_install_timeout: 60
    skip_on_verify_fail: false

enable_project_creation: true  # Enable project creation in the Kubeslice controller
enable_cluster_registration: true  # Enable cluster registration

projects:  # Define projects to be created in the Kubeslice controller
  - name: "avesha"
    username: "jupiter"

cluster_registration:  # Define clusters to be registered in the Kubeslice controller
  - cluster_name: "worker-1"
    project_name: "avesha"
    telemetry:
      enabled: true
      telemetryProvider: "prometheus"
    geoLocation:
      cloudProvider: "GCP"
      cloudRegion: "us-central1"
```

### Script Usage

To run the script, use the following command:

```bash
./egs-installer.sh --input-yaml <yaml_file>
```

Replace `<yaml_file>` with the path to your YAML configuration file. For example:

```bash
./egs-installer.sh --input-yaml egs-installation-config.yaml
```

### Command-Line Options

- `--input-yaml <yaml_file>`: Specifies the YAML configuration file to be used.
- `--help`: Displays usage information.

### Key Features

1. **Prerequisite Checks**: Ensures that required binaries are installed.
2. **Kubeslice Pre-Checks**: Validates access to clusters and labels nodes if required.
3. **Helm Chart Management**: Adds, updates, or removes Helm repositories and manages chart installations.
4. **Project and Cluster Management**: Automates the creation of projects and registration of clusters in the Kubeslice controller.
5. **Worker Configuration**: Fetches secrets from the controller cluster, prepares worker-specific values files, and manages worker installations.

### Example Workflow

1. **Run Pre-checks**: The script first validates that all prerequisites are met.
2. **Kubeslice Pre-Checks**: Validates that the script can access all necessary clusters.
3. **Install or Upgrade Helm Charts**:
   - Installs or upgrades the Kubeslice controller.
   - Installs or upgrades the Kubeslice UI.
4. **Project and Cluster Management**:
   - Creates defined projects in the Kubeslice controller.
   - Registers defined clusters within these projects.
5. **Worker Installation**: Installs or upgrades worker nodes, applying the necessary configuration.

### Notes

- Ensure the YAML configuration file is correctly formatted and contains all necessary fields.
- The script will exit with an error if any critical steps fail unless configured to skip on failure.
- Paths specified in the YAML file should be relative to the `base_path` unless absolute paths are used.

### Troubleshooting

- **Missing Binaries**: Ensure all required binaries are installed and accessible in your system's `PATH`.
- **Cluster Access Issues**: Verify that kubeconfig files are correctly configured and that the script can access the clusters specified in the YAML configuration.
- **Timeouts**: If a component fails to install within the specified timeout, increase the `verify_install_timeout` in the YAML file.

### Conclusion

The EGS Installer Script is a powerful tool for automating the deployment of Kubeslice components across multiple Kubernetes clusters. With proper configuration and usage, it can significantly simplify the installation and management of complex Kubernetes environments.
