---
layout: page
title: EGS Installation Guide
---

EGS AI SRE Agent Platform

<nav class="top-nav">
  <div class="nav-container">
    <div class="nav-links">
      <a href="#home" class="nav-link">Home</a>
      <a href="#documentation" class="nav-link">Documentation</a>
      <a href="#parameters-reference" class="nav-link">Parameters Reference</a>
      <a href="#prerequisites" class="nav-link">Prerequisites</a>
      <a href="#services-configuration" class="nav-link">Services Configuration</a>
      <a href="https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md" target="_blank" class="nav-link">License Setup Guide</a>
      <a href="https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md" target="_blank" class="nav-link">Configuration Guide</a>
    </div>
  </div>
</nav>

<div id="home" class="hero-section">

# EGS Installer Script

A comprehensive AI-powered Site Reliability Engineering platform deployed via automated Bash scripts.

<div class="hero-badges">
  <span class="badge">Bash Script</span>
  <span class="badge">Kubernetes</span>
  <span class="badge">AI/SRE</span>
  <span class="badge">Support</span>
</div>

<div class="hero-buttons">
  <a href="#quick-install" class="btn btn-primary">Get Started Now</a>
  <a href="https://github.com/kubeslice-ent/egs-installation" target="_blank" class="btn btn-secondary">View on GitHub</a>
</div>

</div>

<div id="documentation" class="section">

## 📖 Documentation

* **🚀 Getting Started** - Installation guide
* **⚙️ Services Configuration** - Enable/disable services and integrations  
* **📋 Parameters Reference** - Complete configuration options and examples
* **🔐 License Setup** - EGS license and credentials management
* **📋 Prerequisites** - System requirements and integrations

</div>

<div id="quick-install" class="section">

## ⚡ Quick Install

### Prerequisites

* **Kubernetes cluster** (v1.19+)
* **Helm** (v3.8+)
* **Required Binaries** - yq, helm, kubectl, jq
* **EGS License** - Get your license from [Avesha EGS Registration](https://avesha.io/egs-registration)
* **kubeconfig** file for cluster access

📚 **Important Setup Guides**:

* **[License Setup](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md)** - EGS license configuration and setup
* **[Prerequisites Details](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Preflight-Check-README.md)** - Comprehensive system requirements and integrations

💡 **For local development**: Run `./egs-preflight-check.sh` to ensure all prerequisites are met before installation.

📋 **Note**: The configuration file `egs-installer-config.yaml` expects proper setup. Make sure to:

* Configure your license credentials in the configuration file, OR
* Update the configuration to match your environment setup

### 1. Clone Repository

```bash
# Clone the EGS installation repository
git clone https://github.com/kubeslice-ent/egs-installation
cd egs-installation
```

### 2. License Configuration

```bash
# Configure your EGS license (get from registration)
# Edit the configuration file with your license details
cp egs-installer-config.yaml.example egs-installer-config.yaml
# Update license_info section with your credentials
```

📚 **For advanced license management:** Visit the [License Setup Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-License-Setup.md)

### 3. Installation Options

💡 **Optional: For easier environment variable management, see configuration examples.**

📋 **Note:** If you need to check prerequisites, run the preflight check script first.

#### Minimal (Core EGS Services)

```bash
# Run preflight checks
./egs-preflight-check.sh --input-yaml egs-installer-config.yaml

# Install prerequisites
./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml

# Install EGS components
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

#### Multi-Cluster Setup

📋 **Prerequisites**: Before running multi-cluster setup, ensure you have:

* **Multiple Kubernetes clusters** - Controller and worker clusters configured
* **Network connectivity** - Clusters can communicate with each other
* **Valid kubeconfig files** - For each cluster in your setup

```bash
# Configure multi-cluster setup
# Edit egs-installer-config.yaml for multiple clusters
# See multi-cluster-example.yaml for reference

# Run installation with multi-cluster configuration
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

📋 **For full integration with all services:** See [Configuration Documentation](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md)

⚠️ **Important**: Full integration requires additional setup:

* **[Controller Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Controller-Prerequisites.md)** - Required controller cluster setup
* **[Worker Prerequisites](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Worker-Prerequisites.md)** - Worker cluster configuration and requirements
* **Secret Management** - Advanced credential and secret handling

### 4. Verify Installation

```bash
# Check pod status (all should be Running)
kubectl get pods -n kubeslice-controller
kubectl get pods -n kubeslice-system

# Check services
kubectl get svc -n kubeslice-controller

# Verify installation logs
kubectl logs -n kubeslice-controller deployment/kubeslice-controller
```

### 5. Access the UI

```bash
# Get the service endpoint
kubectl get service -n kubeslice-controller

# Access the EGS UI through the service endpoint
# Default access through port-forward if needed:
kubectl port-forward -n kubeslice-controller service/kubeslice-ui 8080:80
```

🔐 **Access Information:**

* **UI Access**: Through configured service endpoint
* **Configuration**: Via egs-installer-config.yaml
* **Logs**: Available through kubectl logs commands

**Alternative access methods:**

* **Port Forward**: `kubectl port-forward -n kubeslice-controller service/kubeslice-ui 8080:80`
* **Ingress**: Configure ingress controller for external access

</div>

<div id="uninstall" class="section">

## 🗑️ Uninstall

```bash
# Uninstall EGS components
./egs-uninstall.sh --input-yaml egs-installer-config.yaml

# Clean up namespaces (optional)
kubectl delete namespace kubeslice-controller
kubectl delete namespace kubeslice-system
```

📋 **For complete configuration options:** Visit the [Configuration Reference](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md)

</div>

<div id="troubleshooting" class="section">

## 🆘 Troubleshooting

### Common Issues

* **Prerequisites not met**: Run `./egs-preflight-check.sh` to validate requirements
* **Pod failures**: Check logs with `kubectl logs -n kubeslice-controller <pod-name>`
* **License issues**: Verify license configuration in egs-installer-config.yaml

### Basic Debugging

```bash
# Check pod status
kubectl get pods -n kubeslice-controller
kubectl get pods -n kubeslice-system

# View logs
kubectl logs -n kubeslice-controller deployment/kubeslice-controller -f

# Check events
kubectl get events -n kubeslice-controller --sort-by='.lastTimestamp'
```

</div>

<div id="support" class="section">

## 📞 Support

* **Documentation**: [Avesha EGS Documentation](https://docs.avesha.io/documentation/enterprise-egs)
* **GitHub**: [EGS Installation Repository](https://github.com/kubeslice-ent/egs-installation)
* **Issues**: Include pod logs and configuration details

---

📊 **For detailed service configuration:** Visit the [Services Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md)

## EGS Installer Script

* **Avesha Systems** - support@aveshasystems.com

A comprehensive AI-powered Site Reliability Engineering platform deployed via automated installation scripts.

</div>
