---
layout: default
title: Home
nav_order: 1
description: "Streamline installation, upgrade, and configuration of EGS components in Kubernetes clusters"
permalink: /
---

# 🌐 EGS Installer Script

Streamline installation, upgrade, and configuration of EGS components in Kubernetes clusters.

[![Helm Chart](https://img.shields.io/badge/Helm-Chart-blue?style=flat-square&logo=helm)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.23+-blue?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![EGS](https://img.shields.io/badge/EGS-Enterprise-green?style=flat-square)](https://avesha.io)
[![Support](https://img.shields.io/badge/Support-Avesha-orange?style=flat-square)](mailto:support@aveshasystems.com)

[⚡ Quick Install](#-quick-install){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[📖 Full Documentation](#-egs-documents){: .btn .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/kubeslice-ent/egs-installation){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## ⚡ Quick Install

Get started with EGS in seconds using our single-command installer:

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig ~/.kube/config \
  --kubecontext my-cluster \
  --license-path ./license.yaml
```

**📖 Full Guide:** [Quick Install README](./docs/Quick-Install-README.md) - Complete options, multi-cluster support, and skip flags.

---

## 📖 EGS Documents

| Document | Description |
|----------|-------------|
| ⚡ **[Quick Install Guide](./docs/Quick-Install-README.md)** | Single-command installer with auto-configuration |
| 👤 **[User Guide](https://docs.avesha.io/documentation/enterprise-egs)** | Complete user documentation |
| 🔑 **[License Setup](./docs/EGS-License-Setup.md)** | EGS license configuration |
| ✅ **[Preflight Check](./docs/EGS-Preflight-Check-README.md)** | Pre-installation validation |
| 📋 **[Token Retrieval](./docs/Slice-Admin-Token-README.md)** | Slice & Admin token guide |
| 🗂️ **[Namespace Creation](./docs/Namespace-Creation-README.md)** | Pre-create namespaces |
| 🚀 **[Controller Prerequisites](./docs/EGS-Controller-Prerequisites.md)** | Controller cluster setup |
| ⚙️ **[Worker Prerequisites](./docs/EGS-Worker-Prerequisites.md)** | Worker cluster setup |
| 🛠️ **[Configuration Guide](./docs/Configuration-README.md)** | Complete configuration reference |
| 💰 **[Custom Pricing](./docs/Custom-Pricing-README.md)** | Pricing configuration |
| 🌐 **[Multi-Cluster Example](./multi-cluster-example.yaml)** | Multi-cluster setup example |

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure the following:

1. **📝 Registration:** Complete registration at [Avesha EGS Registration](https://avesha.io/egs-registration)

2. **🔧 Required Binaries:**
   - **yq** (minimum: 4.44.2)
   - **helm** (minimum: 3.15.0)
   - **kubectl** (minimum: 1.23.6)
   - **jq** (minimum: 1.6.0)

3. **🌐 Kubernetes Access:** Administrative access with appropriate `kubeconfig` files

4. **📂 Clone Repository:**
   ```bash
   git clone https://github.com/kubeslice-ent/egs-installation
   cd egs-installation
   ```

---

## 🛠️ Installation Methods

### Method 1: Quick Installer (Recommended)

Single command with auto-configuration:

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig ~/.kube/config \
  --kubecontext my-cluster \
  --license-path ./license.yaml
```

**Features:**
- ✅ Auto-detection of cloud provider & GPU nodes
- ✅ Skip flags for prerequisites
- ✅ Multi-cluster support with `--register-worker`
- ✅ Single-cluster and multi-cluster modes

📖 **[Full Quick Install Guide](./docs/Quick-Install-README.md)**

### Method 2: Config-Based Installer

For production deployments with full control:

```bash
# Configure egs-installer-config.yaml
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

📖 **[Configuration Documentation](./docs/Configuration-README.md)**

---

## 📋 Quick Navigation

### 🔧 Prerequisites
- [📝 Registration](#prerequisites)
- [🛠️ Required Binaries](#prerequisites)
- [🌐 Kubernetes Access](#prerequisites)
- [📂 Clone Repository](#prerequisites)

### 🛠️ Installation
- [⚡ Quick Install](#-quick-install)
- [🎛️ Controller Setup](#3-kubeslice-controller-installation-settings-mandatory)
- [🖥️ UI Setup](#4-kubeslice-ui-installation-settings-optional)
- [⚙️ Worker Configuration](#5-worker-clusters-update-the-inline-values)
- [➕ Additional Workers](#6-adding-additional-workers-optional)

---

## 🗑️ Uninstallation

**⚠️ Warning:** This will delete all EGS resources including slices, GPRs, and custom resources.

```bash
./egs-uninstall.sh --input-yaml egs-installer-config.yaml
```

---

## 📞 Support

- **Email:** [support@aveshasystems.com](mailto:support@aveshasystems.com)
- **Documentation:** [docs.avesha.io](https://docs.avesha.io/documentation/enterprise-egs)
- **GitHub Issues:** [Report an Issue](https://github.com/kubeslice-ent/egs-installation/issues)

---

<script>
// Copy functionality for code blocks
function copyCode(button) {
    const codeBlock = button.previousElementSibling;
    const code = codeBlock.querySelector('code') || codeBlock;
    const text = code.textContent;
    
    navigator.clipboard.writeText(text).then(() => {
        button.textContent = '✓ Copied!';
        button.style.background = '#28a745';
        setTimeout(() => {
            button.textContent = '📋 Copy';
            button.style.background = '#007bff';
        }, 2000);
    });
}

document.addEventListener('DOMContentLoaded', function() {
    const codeBlocks = document.querySelectorAll('pre');
    codeBlocks.forEach(function(pre) {
        const button = document.createElement('button');
        button.textContent = '📋 Copy';
        button.style.cssText = 'position:absolute;top:5px;right:5px;padding:5px 10px;background:#007bff;color:white;border:none;border-radius:4px;cursor:pointer;font-size:12px;';
        pre.style.position = 'relative';
        pre.appendChild(button);
        button.onclick = function() { copyCode(this); };
    });
});
</script>
