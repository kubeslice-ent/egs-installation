# 🚀 EGS Quick Installation Guide

## Overview

The EGS Quick Installer provides a **one-command installation** experience for EGS deployments. This guide is designed for users who want to get EGS up and running quickly without manual configuration. The installer supports both single-cluster and multi-cluster deployments, including the ability to install multiple worker clusters in a single command.

---

## ✨ Features

- **🎯 One-Command Installation**: Install EGS with a single curl command
- **🔍 Auto-Detection**: Automatically detects cluster capabilities (GPU nodes, cloud provider)
- **📝 Smart Defaults**: Uses sensible defaults optimized for single-cluster and multi-cluster setups
- **🤖 Automated Setup**: Handles all prerequisites automatically (PostgreSQL, Prometheus, GPU Operator)
- **⚡ Fast Deployment**: Complete installation in 10-15 minutes
- **🔒 Conditional License**: License only required when installing Controller (not for UI, Worker, or prerequisites)
- **🎛️ Flexible**: Skip individual components as needed
- **🔄 Upgrade Support**: Automatically detects existing installations and performs upgrades
- **🔗 Smart Dependencies**: Validates component dependencies and checks for existing installations before blocking
- **🌐 Worker Registration**: Register worker clusters with controller independently (`--register-worker`)
- **👥 Multiple Workers**: Support for installing multiple worker clusters in a single command

---

## 🚦 Quick Start

### Prerequisites

1. **Kubernetes Cluster**: Admin access to a Kubernetes cluster (v1.23.6+)
2. **kubectl**: Configured and connected to your cluster
3. **EGS License**: Valid license file (`egs-license.yaml` in current directory) - **Only required when installing Controller. Not required for UI, Worker, or prerequisites (PostgreSQL, Prometheus, GPU Operator).**
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
4. ✅ Apply the EGS license (only if installing Controller)
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

### Multi-Cluster Mode Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--controller-kubeconfig PATH` | Path to controller cluster kubeconfig | - | Yes (multi-cluster mode) |
| `--controller-context NAME` | Controller cluster context | Auto-detected | No |
| `--worker-kubeconfig PATH` | Path to worker cluster kubeconfig (can be specified multiple times) | - | Yes (multi-cluster mode) |
| `--worker-context NAME` | Worker cluster context (can be specified multiple times, matches order of --worker-kubeconfig) | Auto-detected | No |
| `--worker-name NAME` | Worker cluster name (can be specified multiple times, defaults to worker-1, worker-2, etc.) | Auto-generated | No |

**Note**: Multi-cluster mode is automatically detected when both `--controller-kubeconfig` and at least one `--worker-kubeconfig` are provided. You can specify multiple `--worker-kubeconfig` flags to install multiple worker clusters.

### Worker Registration Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--register-worker` | Register a worker cluster with controller (standalone mode) | - | No |
| `--controller-kubeconfig PATH` | Path to controller cluster kubeconfig | - | Yes (if `--register-worker`) |
| `--controller-context NAME` | Controller cluster context | Current context | No |
| `--worker-kubeconfig PATH` | Path to worker cluster kubeconfig (for validation) | - | No |
| `--worker-context NAME` | Worker cluster context | Current context | No |
| `--register-cluster-name NAME` | Cluster name to register | - | Yes (if `--register-worker`) |
| `--register-project-name NAME` | Project name | `avesha` | No |
| `--telemetry-endpoint URL` | Prometheus endpoint URL | Auto-detected | No |
| `--telemetry-provider NAME` | Telemetry provider | `prometheus` | No |
| `--cloud-provider NAME` | Cloud provider name | Auto-detected | No |
| `--cloud-region NAME` | Cloud region | - | No |
| `--controller-namespace NAME` | Controller namespace | `kubeslice-controller` | No |

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

### Example 5: Install Only Prerequisites (No License Required)

```bash
# Install only Prometheus and GPU Operator (no license needed)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-controller --skip-ui --skip-worker

# Install only PostgreSQL (no license needed)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui --skip-worker
```

### Example 6: Install UI or Worker Without License (Controller Already Installed)

```bash
# Install only UI (no license needed if Controller is already installed)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-worker

# Install only Worker (no license needed if Controller and UI are already installed)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

### Example 7: Multi-Cluster Installation (Controller/UI in One Cluster, Worker in Another)

```bash
# Single worker cluster in multi-cluster mode
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --skip-postgresql --skip-prometheus --skip-gpu-operator

# Multiple worker clusters in multi-cluster mode (with default names)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --skip-postgresql --skip-prometheus --skip-gpu-operator

# Multiple worker clusters with custom names
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-name production-worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-name production-worker-2 \
  --skip-postgresql --skip-prometheus --skip-gpu-operator

# Multiple workers with contexts
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --controller-context controller-ctx \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-context worker1-ctx \
  --worker-name worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-context worker2-ctx \
  --worker-name worker-2 \
  --skip-postgresql --skip-prometheus --skip-gpu-operator
```

### Example 8: Register Worker Cluster with Controller

```bash
# Basic worker cluster registration
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --register-cluster-name worker-2 \
  --register-project-name avesha

# Register worker with telemetry endpoint and cloud provider
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --register-cluster-name worker-3 \
  --register-project-name avesha \
  --telemetry-endpoint http://prometheus.example.com:9090 \
  --cloud-provider GCP \
  --cloud-region us-west1

# Register Linode worker (cloud provider/region automatically left empty)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/linode-worker-kubeconfig.yaml \
  --register-cluster-name worker-linode-1 \
  --register-project-name avesha
```

---

## 🎯 What Gets Installed

### Installation Order

1. **📜 EGS License** (Applied to `kubeslice-controller` namespace) - *Only applied when installing Controller. Not required for UI, Worker, or prerequisites only.*
2. **🗄️ PostgreSQL** (Namespace: `kt-postgresql`) - *Can be skipped*
3. **📊 Prometheus Stack** (Namespace: `egs-monitoring`) - *Can be skipped*
4. **🎮 GPU Operator** (Namespace: `egs-gpu-operator`) - *Can be manually skipped with `--skip-gpu-operator`*
5. **🎛️ EGS Controller** (Namespace: `kubeslice-controller`) - *Can be skipped*
6. **🌐 EGS UI** (Namespace: `kubeslice-controller`) - *Can be skipped*
7. **⚙️ EGS Worker** (Namespace: `kubeslice-system`) - *Can be skipped, supports multiple workers in multi-cluster mode*

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
- `--skip-worker`: Skip EGS Worker installation (applies to all workers when multiple workers are configured)

### 🔗 Dependency Management & Upgrade Support

The installer automatically validates component dependencies and supports upgrades:

**Controller Dependencies:**
- **Requires PostgreSQL**: If you use `--skip-postgresql`, the installer checks if PostgreSQL is already installed
  - ✅ **If PostgreSQL exists**: Controller installation/upgrade proceeds automatically
  - ❌ **If PostgreSQL missing**: Installation fails with clear error message

**Worker Dependencies:**
- **Single-Cluster Mode**: Requires both Controller and UI in the same cluster
  - ✅ **If both exist**: Worker installation/upgrade proceeds automatically
  - ❌ **If either missing**: Installation fails with clear error message
- **Multi-Cluster Mode**: Dependency checks are relaxed (Controller/UI may be in a different cluster)
  - ⚠️ **Warning issued**: If Controller/UI are not found in the worker cluster, a warning is shown but installation continues
  - ℹ️ **Assumes multi-cluster setup**: The installer assumes Controller/UI are in the controller cluster

**Upgrade Scenarios:**
- If a component is already installed, the installer automatically performs an upgrade instead of a fresh installation
- You can skip dependencies if they're already installed (e.g., `--skip-controller --skip-ui` to upgrade only Worker)
- In multi-cluster mode, you can install workers independently of Controller/UI location

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

**Install only Worker (will fail if Controller/UI not installed in single-cluster mode):**
```bash
# This will fail if Controller and UI are not already installed (single-cluster mode)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

**Install multiple workers in multi-cluster mode:**
```bash
# Install Controller/UI in controller cluster and multiple workers in different clusters
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-name worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-name worker-2 \
  --skip-postgresql --skip-prometheus --skip-gpu-operator
```

---

## 👥 Multiple Workers Support

The Quick Installer supports installing multiple worker clusters in a single command. This is particularly useful for multi-cluster deployments where you have multiple worker clusters that need to be managed by a single controller.

### How It Works

- **Multiple `--worker-kubeconfig` Flags**: Specify `--worker-kubeconfig` multiple times, once for each worker cluster
- **Worker Names**: Use `--worker-name` to assign custom names to each worker (defaults to `worker-1`, `worker-2`, etc.)
- **Worker Contexts**: Use `--worker-context` to specify contexts for each worker (auto-detected if not provided)
- **Order Matters**: The order of `--worker-kubeconfig`, `--worker-context`, and `--worker-name` flags should match

### Examples

```bash
# Two workers with default names (worker-1, worker-2)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml

# Two workers with custom names
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-name production-worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-name production-worker-2

# Three workers (mix of named and default)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-name worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker3-kubeconfig.yaml \
  --worker-name worker-3
```

### Configuration

All workers are automatically added to the `kubeslice_worker_egs` array in the generated `egs-installer-config.yaml` file. Each worker gets:
- A unique name (custom or auto-generated)
- Its own kubeconfig file (copied to the working directory)
- Its own context (auto-detected or specified)
- Shared configuration (image registry, etc.)

### Backward Compatibility

Single worker installations continue to work as before:
```bash
# Single worker (still supported)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml
```

---

## 🔗 Worker Cluster Registration

The `--register-worker` feature allows you to register a worker cluster with an existing controller cluster without running the full installation process. This is useful for multi-cluster setups where you want to register worker clusters separately.

### When to Use

- **Multi-cluster setups**: Register worker clusters in different Kubernetes clusters
- **Separate registration**: Register workers independently of installation
- **Cluster management**: Add new worker clusters to an existing EGS deployment

### How It Works

1. **Connects to Controller**: Uses `--controller-kubeconfig` to connect to the controller cluster
2. **Validates Worker** (optional): If `--worker-kubeconfig` is provided, validates worker cluster connectivity
3. **Detects Cloud Provider**: Automatically detects Linode clusters and leaves cloud provider/region empty
4. **Creates Cluster CRD**: Registers the worker cluster in the controller's project namespace
5. **Verifies Registration**: Confirms the cluster was successfully registered

### Required Parameters

- `--register-worker`: Enables registration mode
- `--controller-kubeconfig PATH`: Path to controller cluster kubeconfig file
- `--register-cluster-name NAME`: Unique name for the worker cluster

### Optional Parameters

- `--controller-context NAME`: Controller cluster context (if not using default)
- `--worker-kubeconfig PATH`: Worker cluster kubeconfig (for validation and cloud provider detection)
- `--worker-context NAME`: Worker cluster context
- `--register-project-name NAME`: Project name (default: `avesha`)
- `--telemetry-endpoint URL`: Prometheus endpoint URL
- `--telemetry-provider NAME`: Telemetry provider (default: `prometheus`)
- `--cloud-provider NAME`: Cloud provider name (auto-detected if worker kubeconfig provided)
- `--cloud-region NAME`: Cloud region
- `--controller-namespace NAME`: Controller namespace (default: `kubeslice-controller`)

### Linode Cluster Handling

When a Linode cluster is detected (via `--worker-kubeconfig`), the installer automatically:
- Sets `cloudProvider` to empty string
- Sets `cloudRegion` to empty string
- Ignores any user-provided cloud provider/region values

This is a Linode-specific requirement and is handled automatically.

### Example Workflow

```bash
# Step 1: Register worker cluster with controller
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --register-cluster-name worker-2 \
  --register-project-name avesha

# Step 2: Install EGS Worker on the worker cluster
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator \
  --skip-controller --skip-ui
```

### Verification

After registration, verify the cluster status:

```bash
kubectl --kubeconfig /path/to/controller-kubeconfig.yaml \
  get cluster.controller.kubeslice.io -n kubeslice-avesha
```

### Error Handling

The registration process validates:
- ✅ Controller kubeconfig file exists and is accessible
- ✅ Controller cluster connectivity
- ✅ Worker cluster connectivity (if kubeconfig provided)
- ✅ Project namespace exists in controller cluster
- ✅ Required parameters are provided

If any validation fails, the installer displays a clear error message and exits.

---

## 🔐 License File

**Important**: The EGS license file is **only required when installing the Controller**. It is **not required** for:
- Installing prerequisites (PostgreSQL, Prometheus, GPU Operator)
- Installing UI (if Controller is already installed)
- Installing Worker (if Controller and UI are already installed)
- Registering worker clusters (`--register-worker`)

### Default Behavior

When installing Controller, the installer expects `egs-license.yaml` in the current directory by default:

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

**Note**: This only applies when installing Controller. If the license file is not found during Controller installation, the installer will:
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
- **Single-Cluster Mode**: Install Controller first, or ensure it's detected:
  ```bash
  # Verify Controller is installed
  helm list -A | grep egs-controller
  
  # If installed, the installer should detect it automatically
  ```
- **Multi-Cluster Mode**: Use `--controller-kubeconfig` to specify the controller cluster:
  ```bash
  # In multi-cluster mode, Controller may be in a different cluster
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
    --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
    --worker-kubeconfig /path/to/worker-kubeconfig.yaml
  ```

**Error**: `❌ ERROR: Worker installation requires UI to be installed.`

**Solution**:
- **Single-Cluster Mode**: Install UI first, or ensure it's detected:
  ```bash
  # Verify UI is installed
  helm list -A | grep egs-ui
  
  # If installed, the installer should detect it automatically
  ```
- **Multi-Cluster Mode**: UI is installed with Controller in the controller cluster. Use `--controller-kubeconfig` to specify the controller cluster (UI uses the same kubeconfig as Controller).

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
