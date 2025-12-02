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
3. **EGS License**: Valid license file (`egs-license.yaml` in current directory) - **Only required when installing Controller. Not required for UI, Worker, or prerequisites (PostgreSQL, Prometheus, GPU Operator).** In multi-cluster mode, the license is automatically applied to the controller cluster.
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
| `--help, -h` | Show help message | - | No |

### Common Skip Flags (works for both single & multi-cluster)

| Option | Description | Default |
|--------|-------------|---------|
| `--skip-postgresql` | Skip PostgreSQL installation (controller only - PostgreSQL is never on workers) | Install |
| `--skip-controller` | Skip EGS Controller installation | Install |
| `--skip-ui` | Skip EGS UI installation | Install |
| `--skip-worker` | Skip EGS Worker installation | Install |

### Single-Cluster Mode Skip Flags (use ONLY in single-cluster mode)

| Option | Description | Default |
|--------|-------------|---------|
| `--skip-prometheus` | Skip Prometheus installation | Install |
| `--skip-gpu-operator` | Skip GPU Operator installation | Install |

### Multi-Cluster Mode Skip Flags (use in multi-cluster mode)

**Controller Cluster:**

| Option | Description | Default |
|--------|-------------|---------|
| `--skip-controller-prometheus` | Skip Prometheus on controller cluster | Install |
| `--skip-controller-gpu-operator` | Skip GPU Operator on controller cluster | Install |

**Worker Cluster(s):**

| Option | Description | Default |
|--------|-------------|---------|
| `--skip-worker-prometheus` | Skip Prometheus on worker cluster(s) | Install |
| `--skip-worker-gpu-operator` | Skip GPU Operator on worker cluster(s) | Install |

**Important**: 
- `--skip-postgresql` works the same in both modes (PostgreSQL is only on controller)
- In **single-cluster mode**: Use `--skip-prometheus`, `--skip-gpu-operator`
- In **multi-cluster mode**: Use `--skip-controller-prometheus`, `--skip-worker-prometheus`, etc.
- EGS component flags (`--skip-controller`, `--skip-ui`, `--skip-worker`) work the same in both modes

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

**Important**: In multi-cluster mode, each cluster needs its own prerequisites (Prometheus, GPU Operator). The installer automatically configures:
- **Controller cluster**: PostgreSQL, Prometheus, GPU Operator
- **Worker cluster(s)**: Prometheus, GPU Operator (no PostgreSQL needed)

```bash
# Full multi-cluster installation (all prerequisites on all clusters)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml

# Skip PostgreSQL (same flag for single & multi-cluster - PostgreSQL is only on controller)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --skip-postgresql

# Skip all prerequisites on controller, install on workers
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator

# Skip all prerequisites on ALL clusters
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --skip-postgresql \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator

# Multiple worker clusters in multi-cluster mode (with default names)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml

# Multiple worker clusters with custom names
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-name production-worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-name production-worker-2

# Multiple workers with contexts
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --controller-context controller-ctx \
  --worker-kubeconfig /path/to/worker1-kubeconfig.yaml \
  --worker-context worker1-ctx \
  --worker-name worker-1 \
  --worker-kubeconfig /path/to/worker2-kubeconfig.yaml \
  --worker-context worker2-ctx \
  --worker-name worker-2
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

### Single-Cluster Installation Order

1. **📜 EGS License** (Applied to `kubeslice-controller` namespace) - *Only applied when installing Controller. Not required for UI, Worker, or prerequisites only.*
2. **🗄️ PostgreSQL** (Namespace: `kt-postgresql`) - *Can be skipped*
3. **📊 Prometheus Stack** (Namespace: `egs-monitoring`) - *Can be skipped*
4. **🎮 GPU Operator** (Namespace: `egs-gpu-operator`) - *Can be manually skipped with `--skip-gpu-operator`*
5. **🎛️ EGS Controller** (Namespace: `kubeslice-controller`) - *Can be skipped*
6. **🌐 EGS UI** (Namespace: `kubeslice-controller`) - *Can be skipped*
7. **⚙️ EGS Worker** (Namespace: `kubeslice-system`) - *Can be skipped, supports multiple workers in multi-cluster mode*

### Multi-Cluster Installation Order

In multi-cluster mode, prerequisites are installed on EACH cluster:

**Controller Cluster:**
1. **📜 EGS License** (Applied to `kubeslice-controller` namespace)
2. **🗄️ PostgreSQL** (Namespace: `kt-postgresql`) - *Can be skipped with `--skip-postgresql`*
3. **📊 Prometheus Stack** (Namespace: `egs-monitoring`) - *Can be skipped with `--skip-controller-prometheus`*
4. **🎮 GPU Operator** (Namespace: `egs-gpu-operator`) - *Can be skipped with `--skip-controller-gpu-operator`*
5. **🎛️ EGS Controller** (Namespace: `kubeslice-controller`)
6. **🌐 EGS UI** (Namespace: `kubeslice-controller`)

**Worker Cluster(s):**
1. **📊 Prometheus Stack** (Namespace: `egs-monitoring`) - *Can be skipped with `--skip-worker-prometheus`*
2. **🎮 GPU Operator** (Namespace: `egs-gpu-operator`) - *Can be skipped with `--skip-worker-gpu-operator`*
3. **📋 GPU Operator Quota** (Namespace: `egs-gpu-operator`) - *ResourceQuota for GPU pods*
4. **🖥️ NVIDIA Driver Installer** (Namespace: `kube-system`) - *DaemonSet for GPU drivers*
5. **⚙️ EGS Worker** (Namespace: `kubeslice-system`)

**Note**: The worker requires Prometheus CRDs (PodMonitor) to be installed. If you skip Prometheus on the worker cluster, you may encounter errors like `no matches for kind "PodMonitor"`.

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

### Single-Cluster Skip Flags

These flags apply to all components in a single-cluster setup, or to ALL clusters in multi-cluster mode (if no multi-cluster flags are used):

**Skip Prerequisites:**
- `--skip-postgresql`: Skip PostgreSQL installation (useful if using existing PostgreSQL)
- `--skip-prometheus`: Skip Prometheus installation (useful if using existing Prometheus)
- `--skip-gpu-operator`: Skip GPU Operator installation (useful for CPU-only clusters or existing GPU setup)

**Skip EGS Components:**
- `--skip-controller`: Skip EGS Controller installation
- `--skip-ui`: Skip EGS UI installation
- `--skip-worker`: Skip EGS Worker installation (applies to all workers when multiple workers are configured)

### Multi-Cluster Skip Flags

These flags provide fine-grained control over prerequisites in multi-cluster mode:

**Controller Cluster Prerequisites:**
- `--skip-controller-prometheus`: Skip Prometheus on controller cluster only
- `--skip-controller-gpu-operator`: Skip GPU Operator on controller cluster only

**Worker Cluster Prerequisites:**
- `--skip-worker-prometheus`: Skip Prometheus on ALL worker clusters
- `--skip-worker-gpu-operator`: Skip GPU Operator on ALL worker clusters

**Note:** For PostgreSQL, use `--skip-postgresql` (same flag for both modes since PostgreSQL is only on controller)

**How Skip Flags Work in Multi-Cluster Mode:**

| What you use | Controller Cluster | Worker Cluster(s) |
|--------------|-------------------|-------------------|
| `--skip-postgresql` | ❌ PostgreSQL Skipped | N/A (not installed) |
| `--skip-controller-prometheus` | ❌ Prometheus Skipped | ✅ Prometheus Installed |
| `--skip-worker-prometheus` | ✅ Prometheus Installed | ❌ Prometheus Skipped |
| `--skip-controller-prometheus --skip-worker-prometheus` | ❌ Prometheus Skipped | ❌ Prometheus Skipped |
| `--skip-controller-gpu-operator` | ❌ GPU Op Skipped | ✅ GPU Op Installed |
| `--skip-worker-gpu-operator` | ✅ GPU Op Installed | ❌ GPU Op Skipped |

**Rules:**
1. `--skip-postgresql` → Only affects controller (PostgreSQL is never on workers)
2. In multi-cluster mode, use `--skip-controller-*` and `--skip-worker-*` for Prometheus/GPU Operator
3. Using `--skip-prometheus` or `--skip-gpu-operator` in multi-cluster mode will show a warning
4. EGS component flags (`--skip-controller`, `--skip-ui`, `--skip-worker`) always work the same way

**Examples:**
```bash
# Skip PostgreSQL (controller only - same flag for single & multi-cluster)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-postgresql

# Skip Prometheus on controller only (workers still get Prometheus)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-prometheus

# Skip Prometheus on workers only (controller still gets Prometheus)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-worker-prometheus

# Skip all prerequisites on controller, install on workers
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator

# Skip Prometheus & GPU Operator everywhere (all clusters)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

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

### 🔄 Advanced Features

**Template Preservation:**
- When adding new workers, the script preserves all configuration fields from the template
- Ensures fields like `chart`, `namespace`, `release`, `helm_flags`, `inline_values` are not lost
- Automatically saves worker template from repository or existing configuration
- New workers inherit the complete structure with only specific fields updated

**Multi-Cluster License Application:**
- In multi-cluster mode, license is automatically applied to the controller cluster
- Uses `--controller-kubeconfig` and `--controller-context` for license application
- No manual intervention required for multi-cluster license setup

**Intelligent Worker Management:**
- Existing workers are automatically preserved with `skip_installation=true`
- New workers get `skip_installation=false` (will be installed)
- Duplicate workers are automatically detected and removed
- Worker configurations are merged, not replaced

### 📚 Complete Skip Flag Examples

This section provides comprehensive examples for ALL skip flag combinations.

---

#### 🔹 SINGLE-CLUSTER MODE Examples

**1. Full Installation (no skips):**
```bash
# Install everything: PostgreSQL, Prometheus, GPU Operator, Controller, UI, Worker
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

**2. Skip PostgreSQL only:**
```bash
# Use existing PostgreSQL
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql
```

**3. Skip Prometheus only:**
```bash
# Use existing Prometheus
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-prometheus
```

**4. Skip GPU Operator only:**
```bash
# Use existing GPU Operator or CPU-only cluster
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-gpu-operator
```

**5. Skip all prerequisites:**
```bash
# Prerequisites already installed, install only EGS components
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator
```

**6. Install only prerequisites (no EGS components):**
```bash
# Install PostgreSQL, Prometheus, GPU Operator only (no license required)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-controller --skip-ui --skip-worker
```

**7. Install only Controller:**
```bash
# Prerequisites already installed
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-ui --skip-worker
```

**8. Install only UI:**
```bash
# Controller and prerequisites already installed (no license required)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-worker
```

**9. Install only Worker:**
```bash
# Controller, UI, and prerequisites already installed (no license required)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

**10. Install Controller and UI only (no Worker):**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-worker
```

**11. Install prerequisites and Controller only:**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-ui --skip-worker
```

**12. Skip PostgreSQL and Prometheus:**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus
```

**13. Skip PostgreSQL and GPU Operator:**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-gpu-operator
```

**14. Skip Prometheus and GPU Operator:**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-prometheus --skip-gpu-operator
```

---

#### 🔹 MULTI-CLUSTER MODE Examples

**15. Full multi-cluster installation (all prerequisites on all clusters):**
```bash
# Controller cluster: PostgreSQL, Prometheus, GPU Operator, Controller, UI
# Worker cluster: Prometheus, GPU Operator, Worker
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml
```

**16. Skip PostgreSQL (controller only - same as single-cluster):**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-postgresql
```

**17. Skip Prometheus on controller only:**
```bash
# Controller: No Prometheus | Workers: Prometheus installed
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-prometheus
```

**18. Skip Prometheus on workers only:**
```bash
# Controller: Prometheus installed | Workers: No Prometheus
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-worker-prometheus
```

**19. Skip Prometheus on all clusters:**
```bash
# Controller: No Prometheus | Workers: No Prometheus
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-prometheus --skip-worker-prometheus
```

**20. Skip GPU Operator on controller only:**
```bash
# Controller: No GPU Operator | Workers: GPU Operator installed
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-gpu-operator
```

**21. Skip GPU Operator on workers only:**
```bash
# Controller: GPU Operator installed | Workers: No GPU Operator
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-worker-gpu-operator
```

**22. Skip GPU Operator on all clusters:**
```bash
# Controller: No GPU Operator | Workers: No GPU Operator
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-gpu-operator --skip-worker-gpu-operator
```

**23. Skip all prerequisites on controller only:**
```bash
# Controller: No PostgreSQL, No Prometheus, No GPU Operator
# Workers: Prometheus, GPU Operator installed
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator
```

**24. Skip all prerequisites on workers only:**
```bash
# Controller: PostgreSQL, Prometheus, GPU Operator installed
# Workers: No Prometheus, No GPU Operator
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

**25. Skip all prerequisites on all clusters:**
```bash
# Controller: No PostgreSQL, No Prometheus, No GPU Operator
# Workers: No Prometheus, No GPU Operator
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-postgresql \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

**26. Skip Prometheus on controller, GPU Operator on workers:**
```bash
# Controller: No Prometheus, GPU Operator installed
# Workers: Prometheus installed, No GPU Operator
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-prometheus --skip-worker-gpu-operator
```

**27. Skip GPU Operator on controller, Prometheus on workers:**
```bash
# Controller: Prometheus installed, No GPU Operator
# Workers: No Prometheus, GPU Operator installed
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-controller-gpu-operator --skip-worker-prometheus
```

**28. Multi-cluster with multiple workers - skip all prerequisites:**
```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker1.yaml \
  --worker-kubeconfig /path/to/worker2.yaml \
  --skip-postgresql \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

**29. Multi-cluster - install prerequisites on workers only:**
```bash
# Use case: Controller cluster already has prerequisites, workers need them
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator
```

**30. Multi-cluster - skip Worker installation:**
```bash
# Install Controller, UI, and prerequisites only
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml \
  --skip-worker
```

---

#### 🔹 Skip Flag Quick Reference Table

| Scenario | Flags |
|----------|-------|
| **Single-cluster: Skip all prerequisites** | `--skip-postgresql --skip-prometheus --skip-gpu-operator` |
| **Single-cluster: Skip all EGS components** | `--skip-controller --skip-ui --skip-worker` |
| **Multi-cluster: Skip all controller prerequisites** | `--skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator` |
| **Multi-cluster: Skip all worker prerequisites** | `--skip-worker-prometheus --skip-worker-gpu-operator` |
| **Multi-cluster: Skip ALL prerequisites** | `--skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator --skip-worker-prometheus --skip-worker-gpu-operator` |
| **Multi-cluster: Prometheus on workers only** | `--skip-controller-prometheus` |
| **Multi-cluster: GPU Operator on workers only** | `--skip-controller-gpu-operator` |
| **Multi-cluster: Prometheus on controller only** | `--skip-worker-prometheus` |
| **Multi-cluster: GPU Operator on controller only** | `--skip-worker-gpu-operator` |

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

### Duplicate Worker Handling

When using `--register-worker` to add a new worker cluster:
- **Automatic Duplicate Removal**: If a worker with the same name already exists in the configuration, all duplicate entries are automatically removed before adding the new worker
- **Preserved Workers**: Existing workers (not being re-registered) automatically have `skip_installation=true` to prevent reinstallation
- **New Worker**: The newly registered worker has `skip_installation=false` (unless `--skip-worker` flag is provided) so it will be installed
- **No Manual Cleanup Required**: The script handles all duplicate detection and removal automatically

**Example**: If you register `test-worker-2` twice:
1. First registration: Creates `test-worker-2` with `skip_installation=false`
2. Second registration: Removes old `test-worker-2` entry, creates new one with `skip_installation=false`
3. Other workers remain unchanged with `skip_installation=true`

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

The `--register-worker` feature allows you to register a worker cluster with an existing controller cluster. It supports two modes:

1. **Registration Only**: Register the cluster without installing the worker
2. **Registration + Installation**: Register AND install the worker in one command (when `--worker-kubeconfig` is provided)

### When to Use

- **Multi-cluster setups**: Register worker clusters in different Kubernetes clusters
- **Add new workers**: Add new worker clusters to an existing EGS deployment
- **Separate registration**: Register workers independently, then install later
- **One-command registration + installation**: Register and install worker simultaneously

### How It Works

1. **Connects to Controller**: Uses `--controller-kubeconfig` to connect to the controller cluster
2. **Registers Cluster**: Creates cluster CRD in the controller's project namespace
3. **Validates Worker** (optional): If `--worker-kubeconfig` is provided, validates worker cluster connectivity
4. **Detects Cloud Provider**: Automatically detects Linode clusters and leaves cloud provider/region empty
5. **Handles Duplicates**: Automatically removes any existing worker entries with the same name
6. **Preserves Existing Workers**: Sets `skip_installation=true` for all existing workers
7. **Installs Worker** (if `--worker-kubeconfig` provided): Automatically proceeds with worker installation on the new cluster
8. **Verifies Registration**: Confirms the cluster was successfully registered

### Required Parameters

- `--register-worker`: Enables registration mode
- `--controller-kubeconfig PATH`: Path to controller cluster kubeconfig file
- `--register-cluster-name NAME`: Unique name for the worker cluster

### Optional Parameters

- `--controller-context NAME`: Controller cluster context (if not using default)
- `--worker-kubeconfig PATH`: Worker cluster kubeconfig (**Important**: If provided, worker will be installed automatically after registration)
- `--worker-context NAME`: Worker cluster context
- `--register-project-name NAME`: Project name (default: `avesha`)
- `--telemetry-endpoint URL`: Prometheus endpoint URL
- `--telemetry-provider NAME`: Telemetry provider (default: `prometheus`)
- `--cloud-provider NAME`: Cloud provider name (auto-detected if worker kubeconfig provided)
- `--cloud-region NAME`: Cloud region
- `--controller-namespace NAME`: Controller namespace (default: `kubeslice-controller`)
- `--skip-worker`: Skip worker installation (even if `--worker-kubeconfig` is provided)

### Linode Cluster Handling

When a Linode cluster is detected (via `--worker-kubeconfig`), the installer automatically:
- Sets `cloudProvider` to empty string
- Sets `cloudRegion` to empty string
- Ignores any user-provided cloud provider/region values

This is a Linode-specific requirement and is handled automatically.

### Example Workflows

**Option 1: Register AND Install Worker (One Command - Recommended)**
```bash
# Register worker cluster with controller AND install worker in one command
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --register-cluster-name worker-2 \
  --register-project-name avesha

# That's it! The script will:
# 1. Register worker-2 with the controller
# 2. Automatically install the worker on worker-2 cluster
# 3. Preserve existing workers (skip_installation=true)
# 4. Set new worker: skip_installation=false (will install)
```

**Option 2: Register Only (Without Installation)**
```bash
# Register worker cluster WITHOUT installing (no --worker-kubeconfig)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --register-cluster-name worker-2 \
  --register-project-name avesha

# Later, install the worker separately:
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator \
  --skip-controller --skip-ui
```

**Option 3: Register Without Installing (Even With Kubeconfig)**
```bash
# Register but skip installation using --skip-worker flag
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig /path/to/controller-kubeconfig.yaml \
  --worker-kubeconfig /path/to/worker-kubeconfig.yaml \
  --register-cluster-name worker-2 \
  --register-project-name avesha \
  --skip-worker
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

### PodMonitor CRD Not Found (Multi-Cluster)

**Error**: `resource mapping not found for name: "gateway-pods-podmonitor" namespace: "egs-monitoring" from "": no matches for kind "PodMonitor" in version "monitoring.coreos.com/v1"`

**Cause**: The worker cluster doesn't have Prometheus CRDs installed. In multi-cluster mode, each worker cluster needs Prometheus installed to provide the PodMonitor CRD.

**Solution**:
```bash
# Option 1: Install with Prometheus on worker clusters (recommended)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig /path/to/controller.yaml \
  --worker-kubeconfig /path/to/worker.yaml

# Option 2: If you skipped Prometheus on workers, install it manually
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace egs-monitoring --create-namespace \
  --kubeconfig /path/to/worker.yaml
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
