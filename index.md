---
layout: page
title: EGS Installation Guide
---

# EGS Installer Script

## Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

---

## EGS Documents

- For the User guide, please see the [User Guide Documentation](https://docs.avesha.io/documentation/enterprise-egs)
- For the Installation guide, please see the [Installation Guide](#getting-started)
- For EGS License setup, please refer to the [EGS License Setup Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md)
- For preflight checks, please refer to the [EGS Preflight Check Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Preflight-Check-README.md)
- For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Slice-Admin-Token-README.md)
- For precreate required namespace, please refer to the [Namespace Creation Script Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Namespace-Creation-README.md)
- For EGS Controller prerequisites, please refer to the [EGS Controller Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Controller-Prerequisites.md)
- For EGS Worker prerequisites, please refer to the [EGS Worker Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Worker-Prerequisites.md)
- For configuration details, please refer to the [Configuration Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md)
- For custom pricing setup, please refer to the [Custom Pricing Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Custom-Pricing-README.md)
- For multi-cluster installation examples, please refer to the [Multi-Cluster Installation Example](https://github.com/kubeslice-ent/egs-installation/blob/main/multi-cluster-example.yaml)

---

## Getting Started

### Prerequisites

Before you begin, ensure the following steps are completed:

1. **Registration:**
   - Complete the registration process at [Avesha EGS Registration](https://avesha.io/egs-registration) to receive the required access credentials and product license for running the script.
   - For detailed license setup instructions, refer to **[EGS License Setup](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md)**.

2. **Required Binaries:**
   - Verify that the following binaries are installed and available in your system's `PATH`:
     - **yq** (minimum version: 4.44.2)
     - **helm** (minimum version: 3.15.0)
     - **kubectl** (minimum version: 1.23.6)
     - **jq** (minimum version: 1.6.0)

3. **Kubernetes Access:**
   - Confirm that you have administrative access to the necessary Kubernetes clusters and the appropriate `kubeconfig` files are available.

4. **Clone the Repository:**
   - Start by cloning the EGS installation Git repository:
     ```bash
     git clone https://github.com/kubeslice-ent/egs-installation
     cd egs-installation
     ```
   - Refer to the [EGS Preflight Check Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Preflight-Check-README.md) for detailed instructions.

5. **License Configuration:**
   - Ensure your EGS license is properly configured. This involves setting up the necessary credentials and API keys.
   - For detailed license setup instructions, refer to **[EGS License Setup](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md)**.

6. **Namespace Creation (Optional):**
   - If your cluster enforces namespace creation policies, pre-create the namespaces required for installation before running the script.
   - Use the provided namespace creation script with the appropriate configuration to create the necessary namespaces:
     ```bash
     ./create-namespaces.sh \
       --input-yaml namespace-input.yaml \
       --kubeconfig ~/.kube/config-controller
     ```
   - Refer to the [Namespace Creation Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Namespace-Creation-README.md) for details.

7. **Modify the Configuration File (Mandatory):**
   - Navigate to the cloned repository and locate the input configuration YAML file `egs-installer-config.yaml`. **For the complete configuration template, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml)**.
   - This file contains all the necessary parameters for installing and configuring EGS components.
   - **Important:** Update the `egs-installer-config.yaml` file with your specific environment details, including cluster names, API keys, and other relevant settings.

8. **Install Prerequisites (After Configuration):**
   - After configuring the YAML file (refer to [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml) for examples), run the prerequisites installer to set up GPU Operator, Prometheus, and PostgreSQL:
   ```bash
   ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
   ```
   **Note:** This step installs the required infrastructure components before the main EGS installation.

---

## Installation Steps

### 1. Kubeslice Controller Installation Settings (Mandatory)

This section is **mandatory** for EGS installation. Configure the controller settings according to your environment. **For the complete controller configuration example, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml#L75-L113)**.

```yaml
kubeslice_controller_egs:
  cluster_name: "controller-cluster" # Unique name for the controller cluster
  kubeconfig: "~/.kube/config-controller" # Path to controller kubeconfig file
  kubecontext: "controller-context" # Kubecontext specific to controller
  namespace: "kubeslice-controller" # Namespace where controller will be installed
  project_name: "avesha" # Project name for unified management
  telemetry:
    enabled: true # Enable telemetry for monitoring
    endpoint: "http://<controller-prometheus-endpoint>:9090" # Prometheus endpoint for telemetry
    telemetryProvider: "prometheus" # Telemetry provider (e.g., prometheus)
  geoLocation:
    cloudProvider: "AWS" # Cloud provider (e.g., AWS, GCP, Azure)
    cloudRegion: "us-east-1" # Cloud region
  kubetally:
    enabled: true # Enable KubeTally for resource metering
    postgresql:
      host: "egs-postgresql.kubeslice-controller.svc.cluster.local" # PostgreSQL host
      port: 5432 # PostgreSQL port
      username: "kubeslice" # PostgreSQL username
      password: "password" # PostgreSQL password
      database: "kubeslice" # PostgreSQL database name
      sslmode: "disable" # SSL mode for PostgreSQL connection
      secretName: "kubeslice-postgresql-credentials" # Kubernetes secret for PostgreSQL credentials
```

**Note:** Since KubeTally is enabled by default, PostgreSQL configuration is now mandatory for EGS installation. The secret is created in the `kubeslice-controller` namespace during installation. If you prefer to use a pre-created secret, leave all values empty and specify only the secret name.

**For detailed PostgreSQL setup, see [EGS Controller Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Controller-Prerequisites.md)**

### 2. Kubeslice UI Installation Settings (Optional)

The Kubeslice UI provides a web interface for managing and monitoring your EGS deployment. By default, it's configured to work out-of-the-box with minimal configuration required. **For the complete UI configuration example, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml#L117-L178)**.

```yaml
kubeslice_ui_egs:
  enabled: true # Enable Kubeslice UI
  cluster_name: "controller-cluster" # Controller cluster name
  kubeconfig: "~/.kube/config-controller" # Path to controller kubeconfig
  kubecontext: "controller-context" # Kubecontext for controller
  namespace: "kubeslice-controller" # Namespace where UI will be installed
  service:
    type: ClusterIP # Service type for UI (ClusterIP, NodePort, LoadBalancer)
    port: 80 # Service port
  ingress:
    enabled: false # Enable Ingress for external access
    host: "ui.example.com" # Ingress host
    className: "nginx" # Ingress class name
  # Chart Source Settings
  specific_use_local_charts: true # Override to use local charts for the UI
```

**IMPORTANT NOTE:** The `DCGM_METRIC_JOB_VALUE` must match the Prometheus scrape job name configured in your Prometheus configuration. Without proper Prometheus scrape configuration, GPU metrics will not be collected and UI visualization will not work. Ensure your Prometheus configuration includes the corresponding scrape job. For detailed Prometheus configuration, see [EGS Worker Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Worker-Prerequisites.md).

### 3. Worker Clusters: Update the Inline Values

This section is **mandatory** to ensure proper configuration of monitoring and dashboard URLs. Follow the steps carefully:

**Note:** This section is OPTIONAL and typically requires NO changes. The default configuration works for most installations.

```yaml
kubeslice_worker_egs:
  - cluster_name: "worker-1-cluster" # Unique name for worker-1 cluster
    kubeconfig: "~/.kube/config-worker-1" # Path to worker-1 kubeconfig
    kubecontext: "worker-1-context" # Kubecontext specific to worker-1
    namespace: "kubeslice-worker-1" # Namespace where worker will be installed
    project_name: "avesha" # Project name for unified management
    telemetry:
      enabled: true # Enable telemetry for monitoring
      endpoint: "http://<worker-1-prometheus-endpoint>:9090" # Prometheus endpoint for telemetry
      telemetryProvider: "prometheus" # Telemetry provider (e.g., prometheus)
    geoLocation:
      cloudProvider: "AWS" # Cloud provider (e.g., AWS, GCP, Azure)
      cloudRegion: "us-west-2" # Cloud region
    kserve:
      enabled: true # Enable KServe integration
      domain: kubeslice.com # KServe domain
      ingressGateway:
        className: "nginx" # Ingress class name for the KServe gateway
  - cluster_name: "worker-2-cluster" # Unique name for worker-2 cluster
    kubeconfig: "~/.kube/config-worker-2" # Path to worker-2 kubeconfig
    kubecontext: "worker-2-context" # Kubecontext specific to worker-2
    namespace: "kubeslice-worker-2" # Namespace where worker will be installed
    project_name: "avesha"
    telemetry:
      enabled: true
      endpoint: "http://<worker-2-prometheus-endpoint>:9090" # Use accessible endpoint
      telemetryProvider: "prometheus"
    geoLocation:
      cloudProvider: "AWS"
      cloudRegion: "us-east-1"
```

**IMPORTANT NOTE:** The `DCGM_EXPORTER_JOB_NAME` value (`gpu-metrics`) must match the Prometheus scrape job name configured in your Prometheus configuration. Without proper Prometheus scrape configuration, GPU metrics will not be collected from the worker cluster and monitoring dashboards will not display GPU data. Ensure your Prometheus configuration includes the corresponding scrape job. For detailed Prometheus configuration, see [EGS Worker Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Worker-Prerequisites.md).

### 4. Run the Installation Script

After completing all configuration changes, run the installation script to deploy EGS:

```bash
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

**IMPORTANT NOTES:**

- **Configuration Changes:** If you make any changes to the configuration file after the initial installation, you must re-run the installation script to apply the changes.
- **Upgrades:** For EGS upgrades or configuration modifications, update your `egs-installer-config.yaml` file and re-run the installation script. The installer will handle upgrades automatically.
- **Verification:** Always verify the installation after making configuration changes to ensure all components are properly deployed.

---

### Uninstallation Steps

**Important Note:**
The uninstallation script will delete **all resources** associated with EGS, including **slices**, **GPRs**, and **all custom resources provisioned by egs**. Use this script with caution, as it performs a complete cleanup of the egs setup.

**Run the Cleanup Script**
- Execute the uninstallation script using the following command:
```bash
./egs-uninstall.sh --input-yaml egs-installer-config.yaml
```