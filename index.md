---
layout: page
title: EGS Installation Guide
---

# 🌐 EGS Installer Script

## 🚀 Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

---

## 📄 EGS Documents

- 👤 For the User guide, please see the [User Guide Documentation](https://docs.avesha.io/documentation/enterprise-egs) 📚  
- 🛠️ For the Installation guide, please see the [Installation Guide](#getting-started) 💻  
- 🔑 For EGS License setup, please refer to the [EGS License Setup Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md) 🗝️  
- ✅ For preflight checks, please refer to the [EGS Preflight Check Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Preflight-Check-README.md) 🔍  
- 📋 For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Slice-Admin-Token-README.md) 🔒  
- 🗂️ For precreate required namespace, please refer to the [Namespace Creation Script Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Namespace-Creation-README.md) 🗂️  
- 🚀 For EGS Controller prerequisites, please refer to the [EGS Controller Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Controller-Prerequisites.md) 📋  
- ⚙️ For EGS Worker prerequisites, please refer to the [EGS Worker Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Worker-Prerequisites.md) 🔧  
- 🛠️ For configuration details, please refer to the [Configuration Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md) 📋  
- 📊 For custom pricing setup, please refer to the [Custom Pricing Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Custom-Pricing-README.md) 💰  
- 🌐 For multi-cluster installation examples, please refer to the [Multi-Cluster Installation Example](https://github.com/kubeslice-ent/egs-installation/blob/main/multi-cluster-example.yaml) 🔗

---

## Getting Started

### Prerequisites

Before you begin, ensure the following steps are completed:

1. **📝 Registration:**
   - Complete the registration process at [Avesha EGS Registration](https://avesha.io/egs-registration) to receive the required access credentials and product license for running the script.
   - For detailed license setup instructions, refer to **[📋 EGS License Setup](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md)**.

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

5. **🔍 Run Preflight Checks (Recommended):**
   - Before proceeding with the installation, run the preflight check script to validate your environment:
     ```bash
     ./egs-preflight-check.sh \
       --input-yaml egs-installer-config.yaml \
       --validate-all
     ```
   - Refer to the [EGS Preflight Check Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Preflight-Check-README.md) for detailed instructions.

6. **🗂️ Namespace Pre-creation (If Required):**
   - If your cluster enforces namespace creation policies, pre-create the namespaces required for installation before running the script.
     - Use the provided namespace creation script with the appropriate configuration to create the necessary namespaces:
       ```bash
       ./create-namespaces.sh \
         --input-yaml namespace-input.yaml \
         --validate-manifests
       ```
       - Refer to the [Namespace Creation Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Namespace-Creation-README.md) for details.

7. **⚙️ Enable Additional Applications (Optional):**
   - Configure the `egs-installer-config.yaml` file to enable additional applications installation. **For complete configuration examples, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml)**:

8. **🚀 Install Prerequisites (After Configuration):**
   - After configuring the YAML file (refer to [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml) for examples), run the prerequisites installer to set up GPU Operator, Prometheus, and PostgreSQL:
   ```bash
   ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
   ```
   **📌 Note:** This step installs the required infrastructure components before the main EGS installation.

---

## 🛠️ Installation Steps

### 1. **📂 Clone the Repository:**
   - Start by cloning the EGS installation Git repository:
     ```bash
     git clone https://github.com/kubeslice-ent/egs-installation
     cd egs-installation
     ```

### 2. **📝 Modify the Configuration File (Mandatory):**
   - Navigate to the cloned repository and locate the input configuration YAML file `egs-installer-config.yaml`. **For the complete configuration template, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml)**.

   **📋 Multi-Cluster Configuration Reference:** For a complete multi-cluster installation example with detailed YAML configuration, see [Multi-Cluster Installation Example](https://github.com/kubeslice-ent/egs-installation/blob/main/multi-cluster-example.yaml).

### 3. **Kubeslice Controller Installation Settings (Mandatory)**

   **Note: This section is MANDATORY for EGS installation. Configure the controller settings according to your environment.** **For the complete controller configuration example, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml#L75-L113)**.

### 4. **Kubeslice UI Installation Settings (Optional)**

   **Note: This section is OPTIONAL and typically requires NO changes. The default configuration works for most installations.**

   The Kubeslice UI provides a web interface for managing and monitoring your EGS deployment. By default, it's configured to work out-of-the-box with minimal configuration required. **For the complete UI configuration example, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml#L117-L178)**.

### 5. **Worker Clusters: Update the Inline Values**

   This section is **mandatory** to ensure proper configuration of monitoring and dashboard URLs. Follow the steps carefully:

### 6. **Adding Additional Workers (Optional)**

   To add another worker to your EGS setup, you need to make an entry in the `kubeslice_worker_egs` section of your `egs-installer-config.yaml` file. **For complete worker configuration examples, see [egs-installer-config.yaml](https://github.com/kubeslice-ent/egs-installation/blob/main/egs-installer-config.yaml#L181-L240)**. **For a comprehensive multi-cluster example with multiple workers, see [Multi-Cluster Installation Example](https://github.com/kubeslice-ent/egs-installation/blob/main/multi-cluster-example.yaml)**.

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
