---
layout: home
title: EGS Installer Script
description: A comprehensive guide for installing, upgrading, and configuring EGS components in Kubernetes clusters
---

# 🌐 EGS Installer Script

## 🚀 Overview

The EGS Installer Script is a Bash script designed to streamline the installation, upgrade, and configuration of EGS components in Kubernetes clusters. It leverages Helm for package management, kubectl for interacting with Kubernetes clusters, and yq for parsing YAML files. The script allows for automated validation of cluster access, installation of required binaries, and the creation of Kubernetes namespaces and resources.

---

## 📄 EGS Documents

- 👤 For the User guide, please see the [User Guide Documentation](https://docs.avesha.io/documentation/enterprise-egs) 📚  
- 🛠️ For the Installation guide, please see the [Installation Guide](#getting-started) 💻  
- 🔑 For EGS License setup, please refer to the [EGS License Setup Guide](docs/EGS-License-Setup) 🗝️  
- ✅ For preflight checks, please refer to the [EGS Preflight Check Documentation](docs/EGS-Preflight-Check-README) 🔍  
- 📋 For token retrieval, please refer to the [Slice & Admin Token Retrieval Script Documentation](docs/Slice-Admin-Token-README) 🔒  
- 🗂️ For precreate required namespace, please refer to the [Namespace Creation Script Documentation](docs/Namespace-Creation-README) 🗂️  
- 🚀 For EGS Controller prerequisites, please refer to the [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites) 📋  
- ⚙️ For EGS Worker prerequisites, please refer to the [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites) 🔧  
- 🛠️ For configuration details, please refer to the [Configuration Documentation](docs/Configuration-README) 📋  
- 📊 For custom pricing setup, please refer to the [Custom Pricing Documentation](docs/Custom-Pricing-README) 💰  
- 🌐 For multi-cluster installation examples, please refer to the [Multi-Cluster Installation Example](multi-cluster-example.yaml) 🔗

---

## Getting Started

### Prerequisites

Before you begin, ensure the following steps are completed:

1. **📝 Registration:**
   - Complete the registration process at [Avesha EGS Registration](https://avesha.io/egs-registration) to receive the required access credentials and product license for running the script.
   - For detailed license setup instructions, refer to **[📋 EGS License Setup](docs/EGS-License-Setup)**.

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
     - Refer to the [EGS Preflight Check Guide](docs/EGS-Preflight-Check-README) for detailed instructions.

For complete installation instructions, please refer to the [full README documentation](README).

---

## Quick Links

<div class="grid-container">
  <div class="grid-item">
    <h3>🚀 Getting Started</h3>
    <p>New to EGS? Start here for a complete installation guide.</p>
    <a href="#getting-started" class="btn">Get Started</a>
  </div>
  
  <div class="grid-item">
    <h3>📋 Prerequisites</h3>
    <p>Check system requirements and prepare your environment.</p>
    <a href="docs/EGS-Controller-Prerequisites" class="btn">View Prerequisites</a>
  </div>
  
  <div class="grid-item">
    <h3>🔧 Configuration</h3>
    <p>Configure EGS components for your specific needs.</p>
    <a href="docs/Configuration-README" class="btn">Configure EGS</a>
  </div>
  
  <div class="grid-item">
    <h3>✅ Preflight Check</h3>
    <p>Validate your environment before installation.</p>
    <a href="docs/EGS-Preflight-Check-README" class="btn">Run Checks</a>
  </div>
</div>

---

## Support

For additional support and documentation, visit:
- 📚 [Official Documentation](https://docs.avesha.io/documentation/enterprise-egs)
- 💬 [Community Support](https://github.com/kubeslice-ent/egs-installation/issues)
- 🔗 [Avesha Website](https://avesha.io)
