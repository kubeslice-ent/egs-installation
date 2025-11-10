# 🚀 EGS Quick Installation Guide

## Overview

The EGS Quick Installer provides a **one-command installation** experience for single-cluster EGS deployments. This guide is designed for users who want to get EGS up and running quickly without manual configuration.

---

## ✨ Features

- **🎯 One-Command Installation**: Install EGS with a single curl command
- **🔍 Auto-Detection**: Automatically detects cluster capabilities (GPU nodes, cloud provider)
- **📝 Smart Defaults**: Uses sensible defaults optimized for single-cluster setups
- **🤖 Automated Setup**: Handles all prerequisites automatically (PostgreSQL, Prometheus, GPU Operator)
- **⚡ Fast Deployment**: Complete installation in 10-15 minutes
- **🔒 License-First**: Validates license before proceeding
- **🎛️ Flexible**: Skip individual components as needed
- **🔄 Upgrade Support**: Automatically detects existing installations and performs upgrades
- **🔗 Smart Dependencies**: Validates component dependencies and checks for existing installations before blocking

---

## 🚦 Quick Start

### Prerequisites

1. **Kubernetes Cluster**: Admin access to a Kubernetes cluster (v1.23.6+)
2. **kubectl**: Configured and connected to your cluster
3. **EGS License**: Valid license file (`egs-license.yaml` in current directory)
4. **Required Tools**: `yq` (v4.44.2+), `helm` (v3.15.0+), `kubectl` (v1.23.6+), `jq` (v1.6+), `git`

### Simplest Installation

```bash
# Navigate to your installation directory
cd /path/to/your/directory

# Place your license file in the current directory
# (or specify path with --license-file)

# Run the installer
export KUBECONFIG=/path/to/your/kubeconfig.yaml
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

**That's it!** The script will:
1. ✅ Download EGS installer files internally
2. ✅ Auto-detect your cluster configuration
3. ✅ Generate `egs-installer-config.yaml` in your current directory
4. ✅ Apply the EGS license
5. ✅ Install PostgreSQL, Prometheus, GPU Operator (unless explicitly skipped)
6. ✅ Install EGS Controller, UI, and Worker
7. ✅ Display access information and tokens

---

## 📋 Command Options

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash [OPTIONS]
```

### Available Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--license-file PATH` | Path to EGS license file (relative to current directory) | `egs-license.yaml` | No |
| `--kubeconfig PATH` | Path to kubeconfig file | Auto-detect | No |
| `--context NAME` | Kubernetes context to use | Current context | No |
| `--cluster-name NAME` | Cluster name for registration | `worker-1` | No |
| `--skip-postgresql` | Skip PostgreSQL installation | Install | No |
| `--skip-prometheus` | Skip Prometheus installation | Install | No |
| `--skip-gpu-operator` | Skip GPU Operator installation | Install | No |
| `--skip-controller` | Skip EGS Controller installation | Install | No |
| `--skip-ui` | Skip EGS UI installation | Install | No |
| `--skip-worker` | Skip EGS Worker installation | Install | No |
| `--help, -h` | Show help message | - | No |

---

## 📝 Usage Examples

### Example 1: Basic Installation (License in Current Directory)

```bash
cd /home/user/egs-install
# Place egs-license.yaml in this directory
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

### Example 2: Specify License File Path

```bash
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /path/to/my-license.yaml
```

### Example 3: Custom Cluster Name

```bash
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --cluster-name production-cluster
```

### Example 4: Skip Specific Components

```bash
# Skip PostgreSQL and GPU Operator
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-gpu-operator

# Install only Controller and UI (skip prerequisites and worker)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-worker
```

### Example 5: Install Only GPU Operator

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-controller --skip-ui --skip-worker
```

---

## 🎯 What Gets Installed

### Installation Order

1. **📜 EGS License** (Applied to `kubeslice-controller` namespace)
2. **🗄️ PostgreSQL** (Namespace: `kt-postgresql`) - *Can be skipped*
3. **📊 Prometheus Stack** (Namespace: `egs-monitoring`) - *Can be skipped*
4. **🎮 GPU Operator** (Namespace: `egs-gpu-operator`) - *Can be manually skipped with `--skip-gpu-operator`*
5. **🎛️ EGS Controller** (Namespace: `kubeslice-controller`) - *Can be skipped*
6. **🌐 EGS UI** (Namespace: `kubeslice-controller`) - *Can be skipped*
7. **⚙️ EGS Worker** (Namespace: `kubeslice-system`) - *Can be skipped*

### Service Types (Single-Cluster Optimized)

- **Grafana**: `ClusterIP` (internal access only)
- **Prometheus**: `ClusterIP` (internal access only)
- **UI Proxy**: `LoadBalancer` (external access)

---

## 🔍 Auto-Detection Features

The script automatically detects and configures:

### GPU Nodes Detection

```bash
# Script checks for GPU nodes
GPU_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name')
```

**Behavior**:
- **GPU nodes found**: Sets `enable_custom_apps: true`, installs GPU Operator (unless `--skip-gpu-operator`)
- **No GPU nodes (CPU-only)**: Sets `enable_custom_apps: false`

### Cloud Provider Detection

```bash
# Auto-detects cloud provider from node providerID
kubectl get nodes -o jsonpath='{.items[0].spec.providerID}'
```

**Special Handling**:
- **Linode**: `cloudProvider` field is left empty (Linode-specific requirement)
- **Other providers**: Sets `cloudProvider` to detected value (e.g., `gcp`, `aws`, `azure`)

### Node Labeling

The script automatically labels nodes with `kubeslice.io/node-type=gateway` if no such nodes exist, ensuring `kubeslice-dns` pod can be scheduled.

---

## 📁 Generated Files

After running the installer, you'll find the following files in your current directory:

```
current-directory/
├── egs-installer-config.yaml    # Generated configuration (from repo template)
├── egs-installer.sh             # Main installer script
├── egs-install-prerequisites.sh # Prerequisites installer
├── egs-uninstall.sh             # Uninstaller script
├── charts/                      # Helm charts directory
└── egs-license.yaml             # Your license file (if placed here)
```

**Note**: The installer clones the repository internally and uses `egs-installer-config.yaml` from the repository as the source of truth. It then updates this file with your specific configuration.

---

## 🎛️ Skip Parameters

You can skip individual components during installation. The installer intelligently handles dependencies and upgrade scenarios.

### Skip Prerequisites

- `--skip-postgresql`: Skip PostgreSQL installation (useful if using existing PostgreSQL)
- `--skip-prometheus`: Skip Prometheus installation (useful if using existing Prometheus)
- `--skip-gpu-operator`: Skip GPU Operator installation (useful for CPU-only clusters or existing GPU setup)

### Skip EGS Components

- `--skip-controller`: Skip EGS Controller installation
- `--skip-ui`: Skip EGS UI installation
- `--skip-worker`: Skip EGS Worker installation

### 🔗 Dependency Management & Upgrade Support

The installer automatically validates component dependencies and supports upgrades:

**Controller Dependencies:**
- **Requires PostgreSQL**: If you use `--skip-postgresql`, the installer checks if PostgreSQL is already installed
  - ✅ **If PostgreSQL exists**: Controller installation/upgrade proceeds automatically
  - ❌ **If PostgreSQL missing**: Installation fails with clear error message

**Worker Dependencies:**
- **Requires both Controller and UI**: If you use `--skip-controller` or `--skip-ui`, the installer checks if these components are already installed
  - ✅ **If both exist**: Worker installation/upgrade proceeds automatically
  - ❌ **If either missing**: Installation fails with clear error message

**Upgrade Scenarios:**
- If a component is already installed, the installer automatically performs an upgrade instead of a fresh installation
- You can skip dependencies if they're already installed (e.g., `--skip-controller --skip-ui` to upgrade only Worker)

### Use Cases

**Install only prerequisites (PostgreSQL, Prometheus, GPU Operator):**
```bash
# Install only prerequisites, skip EGS components (Controller, UI, Worker)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-controller --skip-ui --skip-worker
```

**Install only Controller (PostgreSQL already installed):**
```bash
# If PostgreSQL is already installed, this will work
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-ui --skip-worker
```

**Upgrade only Worker (Controller and UI already installed):**
```bash
# If Controller and UI are already installed, this will upgrade Worker
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

**Install only Worker (will fail if Controller/UI not installed):**
```bash
# This will fail if Controller and UI are not already installed
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

---

## 🔐 License File

### Default Behavior

The installer expects `egs-license.yaml` in the current directory by default:

```bash
# License file in current directory
cd /my/install/dir
# Place egs-license.yaml here
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

### Custom License Path

You can specify a custom path (relative to current directory):

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /path/to/egs-license.yaml
```

### License Not Found

If the license file is not found, the installer will:
1. Display an error message
2. Show steps to generate the license file
3. Exit with instructions

**To generate your license:**
1. Navigate to https://avesha.io/egs-registration
2. Complete the registration form
3. Generate cluster fingerprint: `kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'`
4. Receive license file via email
5. Save as `egs-license.yaml` in your installation directory

---

## 🔍 Accessing Your Installation

### UI Access

After successful installation, you'll see:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   🌐 KUBESLICE UI ACCESS INFORMATION                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ Service Type: ⚖️  LoadBalancer                                              │
│ Access URL  : 🔗 https://xxx-xxx-xxx-xxx.ip.linodeusercontent.com          │
│ Status      : ✅ Ready for external access via LoadBalancer                │
└─────────────────────────────────────────────────────────────────────────────┘
```

**To get UI access details:**
```bash
kubectl get svc -n kubeslice-controller kubeslice-ui-proxy
```

### Access Token

The installer displays your project access token. Copy and paste this token in the UI login screen.

---

## 🐛 Troubleshooting

### License File Not Found

**Error**: `❌ ERROR: License file not found`

**Solution**:
```bash
# Ensure license file exists in current directory
ls -la egs-license.yaml

# Or specify custom path
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /path/to/egs-license.yaml
```

### Kubeconfig Not Accessible

**Error**: `No active Kubernetes context found!`

**Solution**:
```bash
# Set KUBECONFIG environment variable
export KUBECONFIG=/path/to/your/kubeconfig.yaml

# Verify connection
kubectl get nodes
```

### Installation Timeout

If installation times out during Helm operations, check:

```bash
# Check pods status
kubectl get pods -A | grep -E "kubeslice|egs-|kt-postgresql"

# Check helm releases
helm list -A

# Check node resources
kubectl top nodes
```

### Dependency Errors

**Error**: `❌ ERROR: Controller installation requires PostgreSQL to be installed.`

**Solution**:
- Install PostgreSQL first, or
- If PostgreSQL is already installed, ensure it's detected by the installer:
  ```bash
  # Verify PostgreSQL is installed
  helm list -A | grep postgresql
  
  # If installed, the installer should detect it automatically
  # If not detected, check the release name matches (postgresql or kt-postgresql)
  ```

**Error**: `❌ ERROR: Worker installation requires Controller to be installed.`

**Solution**:
- Install Controller first, or
- If Controller is already installed, ensure it's detected:
  ```bash
  # Verify Controller is installed
  helm list -A | grep egs-controller
  
  # If installed, the installer should detect it automatically
  ```

**Error**: `❌ ERROR: Worker installation requires UI to be installed.`

**Solution**:
- Install UI first, or
- If UI is already installed, ensure it's detected:
  ```bash
  # Verify UI is installed
  helm list -A | grep egs-ui
  
  # If installed, the installer should detect it automatically
  ```

---

## 🔄 Reinstallation / Updates

### Complete Reinstall

```bash
# 1. Uninstall existing components (if egs-installer-config.yaml exists)
bash egs-uninstall.sh --input-yaml egs-installer-config.yaml

# 2. Run installer again
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

### Update Components

The Quick Installer automatically handles upgrades. Simply re-run it to upgrade existing components:

```bash
# Re-run the installer - it will automatically upgrade existing components
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

---

## 📚 Related Documentation

- 📋 [EGS License Setup](EGS-License-Setup.md) - How to obtain and configure your license
- 🛠️ [Full Installation Guide](../README.md#getting-started) - For multi-cluster and advanced setups
- 📊 [Configuration Documentation](Configuration-README.md) - Detailed configuration options
- ✅ [Preflight Check](EGS-Preflight-Check-README.md) - Validate your environment before installation
- 🌐 [EGS User Guide](https://docs.avesha.io/documentation/enterprise-egs) - Complete product documentation

---

## 🎉 Success!

If you see this message, your installation is complete:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   🏁 INSTALLATION SUMMARY COMPLETE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ ✅ All configured components have been processed.                           │
│ 📋 Access information displayed above for quick reference.                  │
└─────────────────────────────────────────────────────────────────────────────┘
✅ ✅ EGS installation completed successfully!
```

**Next Steps:**
1. Access the UI using the provided URL
2. Login with the displayed token
3. Start using EGS for GPU scheduling!
