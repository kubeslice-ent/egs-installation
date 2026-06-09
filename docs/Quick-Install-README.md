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
   - The installer checks these **up front and aborts before downloading anything** if `git`, `kubectl`, `yq`, or `jq` is missing.
   - Reliable `yq` install (avoids snap's `/tmp` confinement): `curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq`

### 📝 Registration Required

Complete the registration process at [Avesha EGS Registration](https://avesha.io/egs-registration) to receive:
- Access credentials
- Product license file (`egs-license.yaml`)

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

### Preview the Generated Config First (Recommended)

Use `--generate-config` (alias `--dry-run`) to generate `egs-installer-config.yaml` and **stop before touching the cluster**. Review it, then re-run the same command without `--generate-config` to install.

```bash
# Generate and review the config WITHOUT installing anything
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file egs-license.yaml \
  --kubeconfig /path/to/kubeconfig \
  --cluster-name my-cluster \
  --generate-config

cat egs-installer-config.yaml     # review, then re-run WITHOUT --generate-config to install
```

---

## 📐 Topology-Based Installation Examples

This section provides **copy-paste ready commands** for different cluster topologies. Choose the topology that matches your setup.

---

### 🔹 Topology 1: Single Cluster (Everything in One Cluster)

**Use case:** PoC, development, or simple production setups where Controller, UI, and Worker all run on the same Kubernetes cluster.

#### 1️⃣ Full Installation

> 📝 **Note:** Installs all components (PostgreSQL, Prometheus, GPU Operator, Controller, UI, Worker) on a single cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"       # Path to your EGS license file
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export CLUSTER_NAME="my-cluster"             # Name for your cluster

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME
```

#### 2️⃣ Skip Prerequisites

> 📝 **Note:** Use this when PostgreSQL, Prometheus, and GPU Operator are already installed on the cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"       # Path to your EGS license file
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export CLUSTER_NAME="my-cluster"             # Name for your cluster

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-postgresql --skip-prometheus --skip-gpu-operator
```

#### 3️⃣ Install Only Worker

> ⚠️ **Note:** This installs Worker on the **SAME cluster** where Controller/UI are already running. Use this when you want to add Worker capability to an existing Controller cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

---

### 🔹 Topology 2: 1 Controller Cluster + 1 Worker Cluster

**Use case:** Production setup with dedicated controller cluster and one worker cluster.

#### 1️⃣ Full Installation

> 📝 **Note:** Installs Controller/UI on cluster-1 and Worker on cluster-2 with all prerequisites.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig
export WORKER_NAME="production-worker-1"                            # Name for the worker cluster

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --worker-name $WORKER_NAME
```

#### 2️⃣ Skip All Prerequisites

> 📝 **Note:** Use this when PostgreSQL, Prometheus, and GPU Operator are already installed on **both** clusters.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig
export WORKER_NAME="production-worker-1"                            # Name for the worker cluster

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --worker-name $WORKER_NAME \
  --skip-postgresql \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

#### 3️⃣ Skip Prerequisites on Controller Only

> 📝 **Note:** Skips prerequisites on controller cluster but installs them on worker cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig
export WORKER_NAME="production-worker-1"                            # Name for the worker cluster

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --worker-name $WORKER_NAME \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator
```

---

### 🔹 Topology 3: 1 Controller Cluster + 2 Worker Clusters

**Use case:** Multi-region or multi-team setup with one controller managing two separate worker clusters.

#### 1️⃣ Full Installation

> 📝 **Note:** Installs Controller/UI on cluster-1 and Workers on cluster-2 and cluster-3 with all prerequisites.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 cluster kubeconfig
export WORKER1_NAME="production-worker-1"                           # Name for worker 1
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 cluster kubeconfig
export WORKER2_NAME="production-worker-2"                           # Name for worker 2

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME
```

#### 2️⃣ With Custom Contexts

> 📝 **Note:** Use this when your kubeconfig files have multiple contexts and you need to specify which context to use.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export CONTROLLER_CONTEXT="controller-ctx"                          # Controller cluster context
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 cluster kubeconfig
export WORKER1_CONTEXT="worker1-ctx"                                # Worker 1 cluster context
export WORKER1_NAME="production-worker-1"                           # Name for worker 1
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 cluster kubeconfig
export WORKER2_CONTEXT="worker2-ctx"                                # Worker 2 cluster context
export WORKER2_NAME="production-worker-2"                           # Name for worker 2

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --controller-context $CONTROLLER_CONTEXT \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-context $WORKER1_CONTEXT \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-context $WORKER2_CONTEXT \
  --worker-name $WORKER2_NAME
```

#### 3️⃣ Skip All Prerequisites

> 📝 **Note:** Use this when PostgreSQL, Prometheus, and GPU Operator are already installed on **all** clusters.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 cluster kubeconfig
export WORKER1_NAME="production-worker-1"                           # Name for worker 1
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 cluster kubeconfig
export WORKER2_NAME="production-worker-2"                           # Name for worker 2

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME \
  --skip-postgresql \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

---

### 🔹 Topology 4: 1 Controller Cluster + 3 Worker Clusters

**Use case:** Large-scale production with one controller managing multiple worker clusters across different regions or cloud providers.

#### 1️⃣ Full Installation

> 📝 **Note:** Installs Controller/UI on cluster-1 and Workers on cluster-2, cluster-3, and cluster-4 with all prerequisites.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 (US East) kubeconfig
export WORKER1_NAME="us-east-worker"                                # Name for worker 1
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 (US West) kubeconfig
export WORKER2_NAME="us-west-worker"                                # Name for worker 2
export WORKER3_KUBECONFIG="/path/to/worker3-kubeconfig.yaml"        # Worker 3 (EU West) kubeconfig
export WORKER3_NAME="eu-west-worker"                                # Name for worker 3

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME \
  --worker-kubeconfig $WORKER3_KUBECONFIG \
  --worker-name $WORKER3_NAME
```

#### 2️⃣ With Cloud Provider and Region

> 📝 **Note:** `--cloud-provider` and `--cloud-region` are **global** in a single full-install command — they are applied to **every** worker's `cluster_registration` entry. To give each worker a *distinct* provider/region, register the workers separately with `--register-worker` (which takes per-worker `--cloud-provider`/`--cloud-region`), as shown in *Adding a New Worker → With Telemetry Endpoint*.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER1_NAME="us-east-worker"                                # Name for worker 1
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig
export WORKER2_NAME="us-west-worker"                                # Name for worker 2
export WORKER3_KUBECONFIG="/path/to/worker3-kubeconfig.yaml"        # Worker 3 kubeconfig
export WORKER3_NAME="eu-west-worker"                                # Name for worker 3
export CLOUD_PROVIDER="GCP"                                         # Cloud provider, applied to ALL workers
export CLOUD_REGION="us-west1"                                      # Cloud region, applied to ALL workers

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME \
  --worker-kubeconfig $WORKER3_KUBECONFIG \
  --worker-name $WORKER3_NAME \
  --cloud-provider $CLOUD_PROVIDER \
  --cloud-region $CLOUD_REGION
```

#### 3️⃣ Skip Prerequisites on Controller Only

> 📝 **Note:** Skips prerequisites on controller but installs them on all worker clusters.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"                           # Path to your EGS license file
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 (US East) kubeconfig
export WORKER1_NAME="us-east-worker"                                # Name for worker 1
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 (US West) kubeconfig
export WORKER2_NAME="us-west-worker"                                # Name for worker 2
export WORKER3_KUBECONFIG="/path/to/worker3-kubeconfig.yaml"        # Worker 3 (EU West) kubeconfig
export WORKER3_NAME="eu-west-worker"                                # Name for worker 3

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME \
  --worker-kubeconfig $WORKER3_KUBECONFIG \
  --worker-name $WORKER3_NAME \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator
```

> 💡 **Tip:** This pattern scales to any number of workers. Simply add additional `--worker-kubeconfig` and `--worker-name` pairs for each worker cluster.

---

### 🔹 Adding a New Worker to Existing Setup

**Use case:** You already have a Controller + Workers deployed and want to add a new worker cluster.

#### 1️⃣ Register AND Install (Recommended)

> 📝 **Note:** Registers the worker with the controller AND installs EGS Worker in one command.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/new-worker-kubeconfig.yaml"      # New worker cluster kubeconfig
export CLUSTER_NAME="new-worker-1"                                  # Name for the new worker
export PROJECT_NAME="avesha"                                        # Project name (default: avesha)

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

#### 2️⃣ With Telemetry Endpoint

> 📝 **Note:** Use this when the worker has an external Prometheus endpoint that the controller needs to access.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/new-worker-kubeconfig.yaml"      # New worker cluster kubeconfig
export CLUSTER_NAME="new-worker-1"                                  # Name for the new worker
export PROJECT_NAME="avesha"                                        # Project name (default: avesha)
export TELEMETRY_ENDPOINT="http://prometheus.new-worker.example.com:9090"  # External Prometheus endpoint
export CLOUD_PROVIDER="GCP"                                         # Cloud provider (GCP, AWS, Azure, etc.)
export CLOUD_REGION="us-west1"                                      # Cloud region

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME \
  --telemetry-endpoint $TELEMETRY_ENDPOINT \
  --cloud-provider $CLOUD_PROVIDER \
  --cloud-region $CLOUD_REGION
```

#### 3️⃣ Register Only (No Installation)

> 📝 **Note:** Only registers the worker with the controller. Use this when you want to install the worker separately later.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export CLUSTER_NAME="new-worker-1"                                  # Name for the new worker
export PROJECT_NAME="avesha"                                        # Project name (default: avesha)

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

---

### 🔹 Telemetry Endpoint Explained

The `--telemetry-endpoint` parameter specifies the **Prometheus endpoint for the worker cluster**. This is used by the controller to collect metrics and telemetry data from the worker cluster.

| Scenario | Telemetry Endpoint Value |
|----------|-------------------------|
| **Single-cluster** | `http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090` (auto-configured) |
| **Multi-cluster (same network)** | Worker's internal Prometheus endpoint (accessible from controller) |
| **Multi-cluster (different networks)** | Worker's LoadBalancer/NodePort Prometheus endpoint (must be externally accessible) |

**Examples:**

```bash
# Internal endpoint (same network)
--telemetry-endpoint http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090

# LoadBalancer endpoint (different networks)
--telemetry-endpoint http://prometheus-lb.worker-cluster.example.com:9090

# NodePort endpoint
--telemetry-endpoint http://worker-node-ip:30090
```

**⚠️ Important:** For multi-cluster setups where controller and workers are in different networks, the telemetry endpoint **must be externally accessible** from the controller cluster.

---

### 🌐 Multi-Cluster Network Requirements

In a multi-cluster setup the worker's EGS operator connects **back to the controller's Kubernetes API** to sync its `Cluster` and `WorkerSlice*` resources. Two independent reachability paths must therefore exist:

| Path | Direction | Why it's needed |
|------|-----------|-----------------|
| **Worker → Controller API** | worker pods → `https://<controller-ip>:6443` | The worker operator reads/writes its resources in the controller's project namespace (`kubeslice-<project>`). |
| **Controller → Worker telemetry** | controller → worker Prometheus | KubeTally / metrics collection (see *Telemetry Endpoint Explained* above). |

**Controller endpoint embedded in the worker onboarding secret.** When a worker is registered, the controller mints a secret (`kubeslice-rbac-worker-<name>`) whose `controllerEndpoint` is taken from the controller's advertised API URL. On single-node **K3s/kubeadm** the controller kubeconfig server is often `https://127.0.0.1:6443`, which a **remote** worker cannot reach. Override it so the worker receives a routable address:

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --worker-name $WORKER_NAME \
  --controller-endpoint https://<routable-controller-ip>:6443
```

> 🩺 **Symptom of an unreachable controller endpoint:** the worker chart deploys and the `kubeslice-operator` pod can even report `Ready` (its readiness probe is a local health check), but its `manager` container logs repeat the following and **reconciles never succeed**:
>
> ```
> failed to get server groups: Get "https://<controller-ip>:6443/api":
> dial tcp <controller-ip>:6443: connect: no route to host
> ```
>
> The worker chart itself installed correctly — it simply cannot reach the controller API. Fix L3 reachability (routing / firewall / NAT) and/or set `--controller-endpoint` to an address the worker can route to. The same applies in reverse for the telemetry path.

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
| `--project-name NAME` | Project name used for cluster registration on full installs | `avesha` | No |
| `--help, -h` | Show help message | - | No |

### Behavior & Safety Flags

These flags make the installer safer to run repeatedly and easier to review before mutating a cluster.

| Option | Description | Default |
|--------|-------------|---------|
| `--generate-config` (alias `--dry-run`) | Generate `egs-installer-config.yaml` and **exit before any cluster-mutating action** (no license apply, no installs). Use it to review the config first. | Off |
| `--preserve-config` | Reuse an existing `egs-installer-config.yaml` as-is instead of regenerating it, so manual edits survive a re-run. | Off |
| `--skip-dependency-check` | Bypass the helm/deployment-based PostgreSQL/Controller/UI prerequisite detection (for dependencies running under non-standard release names). | Off |
| `--local-repo PATH` | Use a local `egs-installation` checkout instead of cloning from GitHub (air-gapped, pinned-version, or pre-merge `release-*` branch testing). See [Using a Local Checkout](#using-a-local-checkout---local-repo) for examples. | Clone from GitHub |

> ✅ **Safe by default:** The installer performs a single up-front tool check and **aborts before any download** if `git`, `kubectl`, `yq`, or `jq` is missing. On any early exit a cleanup trap removes temporary files and restores your original `kubectl` context, so the cluster is never left half-switched. When a config is regenerated, the previous one is backed up to `egs-installer-config.yaml.bak.<timestamp>`.

### Using a Local Checkout (`--local-repo`)

By default the installer **clones the `main` branch** of `egs-installation` from GitHub at runtime and uses its `charts/`, `egs-installer.sh`, and `egs-installer-config.yaml`. `--local-repo PATH` makes it use an **existing local checkout instead of cloning** — essential for:

- **Testing a specific branch/tag** (e.g. a `release-*` branch) *before* it merges to `main`.
- **Air-gapped / offline installs** where the cluster host cannot reach GitHub.
- **Pinned, reproducible installs** against an audited copy of the repo.

**What to pass:** the **absolute path to the root of an `egs-installation` checkout** (a *directory*, not a file). The installer validates that the path exists and contains `egs-installer.sh`; it also needs `charts/` and `egs-installer-config.yaml` inside it.

```text
/root/egs-rel/                    ← pass THIS path to --local-repo
├── egs-installer.sh              ✅ required (presence is validated)
├── egs-installer-config.yaml     ✅ required (used as the config template)
├── charts/                       ✅ required (these charts are what get deployed)
│   ├── kubeslice-controller-egs/
│   ├── kubeslice-ui-egs/
│   └── kubeslice-worker-egs/
├── egs-install-prerequisites.sh
└── egs-uninstall.sh
```

When `--local-repo` is used, the installer prints `✅ Using local EGS installer checkout: <PATH>` and **skips the GitHub clone entirely** — so the chart version that gets deployed is whatever that checkout contains, not `main`.

> ⚠️ **Pass the repo root, not a sub-path.** `--local-repo /root/egs-rel/charts` (too deep) or `--local-repo /root/egs-rel/install-egs.sh` (a file) will fail with `--local-repo path is not a valid EGS installer checkout`.

#### Example A — Test a release branch before it merges to `main`

> 📝 **Note:** Use this to validate `release-*` charts through the Quick Installer while `main` still ships the previous version. The chart version deployed comes from the checked-out branch.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export RELEASE_BRANCH="release-v1.17.2"          # Branch/tag to test
export LOCAL_REPO="/root/egs-rel"                # Where to clone it
export KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
export LICENSE_FILE="egs-license.yaml"
export CLUSTER_NAME="my-cluster"

# ============ STEP 1: Clone the release branch locally ============
git clone --depth 1 --branch "$RELEASE_BRANCH" \
  https://github.com/kubeslice-ent/egs-installation.git "$LOCAL_REPO"

# ============ STEP 2: Preview the config using the release charts (no install) ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --local-repo "$LOCAL_REPO" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --license-file "$LICENSE_FILE" \
  --cluster-name "$CLUSTER_NAME" \
  --generate-config

# ============ STEP 3: Install for real (re-run WITHOUT --generate-config) ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --local-repo "$LOCAL_REPO" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --license-file "$LICENSE_FILE" \
  --cluster-name "$CLUSTER_NAME"

# ============ VERIFY: charts deployed at the release version ============
helm list -A | grep -E "egs-controller|egs-ui|egs-worker"
```

#### Example B — Air-gapped / offline install (no GitHub at runtime)

> 📝 **Note:** Stage the repo on the host beforehand; `--local-repo` then needs no network for the installer artifacts.

```bash
# ============ ON A MACHINE WITH INTERNET: package the repo ============
git clone --depth 1 --branch release-v1.17.2 \
  https://github.com/kubeslice-ent/egs-installation.git egs-installation
tar -czf egs-installation.tgz egs-installation
# ...transfer egs-installation.tgz AND install-egs.sh to the air-gapped host...

# ============ ON THE AIR-GAPPED HOST: extract and install ============
tar -xzf egs-installation.tgz -C /opt/          # creates /opt/egs-installation
bash install-egs.sh \
  --local-repo /opt/egs-installation \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --license-file egs-license.yaml \
  --cluster-name my-cluster
```

#### Example C — Reuse an existing local checkout

```bash
# You already have the repo checked out (any branch you want to install from)
cd /home/user/egs-installation
git checkout release-v1.17.2

curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --local-repo /home/user/egs-installation \
  --kubeconfig ~/.kube/config \
  --generate-config
```

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
| `--cloud-provider NAME` | Cloud provider name (overrides auto-detection) | Auto-detected | No |
| `--cloud-region NAME` | Cloud region | - | No |
| `--controller-namespace NAME` | Controller namespace | `kubeslice-controller` | No |

### Advanced Override Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--controller-endpoint URL` | Override the controller API endpoint that gets **embedded in each worker onboarding secret** (`controllerEndpoint`). Required when the controller kubeconfig server is `127.0.0.1`/`localhost` (single-node K3s/kubeadm) and workers run in another network; also useful for Rancher or custom API server URLs. See [Multi-Cluster Network Requirements](#-multi-cluster-network-requirements). | Auto-detected from kubeconfig | No |
| `--worker-endpoint URL` | Override the auto-detected worker cluster API endpoint (can be specified multiple times, matches order of `--worker-kubeconfig`) | Auto-detected from kubeconfig | No |
| `--ui-service-type TYPE` | Set UI proxy service type: `LoadBalancer`, `NodePort`, or `ClusterIP`. **The generated config ships `NodePort` by default** (verified on K3s/bare-metal); pass this flag to override (e.g. `LoadBalancer` on clusters with a cloud LB controller). Invalid values are rejected. | `NodePort` (from config template) | No |

---

## 📝 Usage Examples

### Example 1: Basic Installation (License in Current Directory)

```bash
# ============ CUSTOMIZE THESE VALUES ============
export INSTALL_DIR="/home/user/egs-install"  # Directory for installation
export KUBECONFIG_PATH="/home/user/.kube/config"  # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
cd $INSTALL_DIR
# Place egs-license.yaml in this directory
export KUBECONFIG=$KUBECONFIG_PATH
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

### Example 2: Specify License File Path

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="/home/user/.kube/config"  # Path to your kubeconfig
export LICENSE_FILE="/path/to/my-license.yaml"   # Path to your license file

# ============ RUN THE INSTALLER ============
export KUBECONFIG=$KUBECONFIG_PATH
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE
```

### Example 3: Custom Cluster Name

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="/home/user/.kube/config"  # Path to your kubeconfig
export CLUSTER_NAME="production-cluster"          # Custom cluster name

# ============ RUN THE INSTALLER ============
export KUBECONFIG=$KUBECONFIG_PATH
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --cluster-name $CLUSTER_NAME
```

### Example 4: Skip Specific Components

#### Skip PostgreSQL and GPU Operator

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-gpu-operator
```

#### Install only Controller and UI (skip prerequisites and worker)

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-worker
```

### Example 5: Install Only Prerequisites (No License Required)

#### Install only Prometheus and GPU Operator

> 📝 **Note:** No license needed for prerequisites only.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-controller --skip-ui --skip-worker
```

#### Install only PostgreSQL

> 📝 **Note:** No license needed for prerequisites only.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui --skip-worker
```

### Example 6: Install UI or Worker Without License (Controller Already Installed)

#### Install only UI

> 📝 **Note:** No license needed if Controller is already installed.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-worker
```

#### Install only Worker on Controller Cluster

> ⚠️ **Note:** This installs Worker on the **SAME cluster** where Controller/UI are already running. Use this for single-cluster setups.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-prometheus --skip-gpu-operator --skip-controller --skip-ui
```

### Example 7: Multi-Cluster Installation (Controller/UI in One Cluster, Worker in Another)

> ⚠️ **Important:** In multi-cluster mode, each cluster needs its own prerequisites (Prometheus, GPU Operator). The installer automatically configures:
> - **Controller cluster**: PostgreSQL, Prometheus, GPU Operator
> - **Worker cluster(s)**: Prometheus, GPU Operator (no PostgreSQL needed)

#### Full Multi-Cluster Installation

> 📝 **Note:** Installs all prerequisites on all clusters.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG
```

#### Skip PostgreSQL

> 📝 **Note:** PostgreSQL is only on controller. Same flag for single & multi-cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-postgresql
```

#### Skip Prerequisites on Controller Only

> 📝 **Note:** Prerequisites already installed on controller cluster, install on workers.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator
```

#### Skip All Prerequisites on ALL Clusters

> 📝 **Note:** Prerequisites already installed on all clusters.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-postgresql \
  --skip-controller-prometheus --skip-controller-gpu-operator \
  --skip-worker-prometheus --skip-worker-gpu-operator
```

#### Multiple Worker Clusters (Default Names)

> 📝 **Note:** Workers will be named `worker-1`, `worker-2` automatically.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-kubeconfig $WORKER2_KUBECONFIG
```

#### Multiple Worker Clusters with Custom Names

> 📝 **Note:** Use `--worker-name` after each `--worker-kubeconfig` to set custom names.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER1_NAME="production-worker-1"                           # Worker 1 name
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig
export WORKER2_NAME="production-worker-2"                           # Worker 2 name

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME
```

#### Multiple Workers with Custom Contexts

> 📝 **Note:** Use when kubeconfig files have multiple contexts.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export CONTROLLER_CONTEXT="controller-ctx"                          # Controller cluster context
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER1_CONTEXT="worker1-ctx"                                # Worker 1 context
export WORKER1_NAME="worker-1"                                      # Worker 1 name
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig
export WORKER2_CONTEXT="worker2-ctx"                                # Worker 2 context
export WORKER2_NAME="worker-2"                                      # Worker 2 name

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --controller-context $CONTROLLER_CONTEXT \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-context $WORKER1_CONTEXT \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-context $WORKER2_CONTEXT \
  --worker-name $WORKER2_NAME
```

### Example 8: Register Worker Cluster with Controller

#### Basic Worker Registration

> 📝 **Note:** Registers the worker with the controller. Add `--worker-kubeconfig` to also install the worker.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export CLUSTER_NAME="worker-2"                                      # Name for the worker cluster
export PROJECT_NAME="avesha"                                        # Project name (default: avesha)

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

#### Register with Telemetry Endpoint and Cloud Provider

> 📝 **Note:** Use this for external Prometheus endpoints and geo-location tracking.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig
export CLUSTER_NAME="worker-3"                                      # Name for the worker cluster
export PROJECT_NAME="avesha"                                        # Project name (default: avesha)
export TELEMETRY_ENDPOINT="http://prometheus.example.com:9090"      # External Prometheus endpoint
export CLOUD_PROVIDER="GCP"                                         # Cloud provider (GCP, AWS, Azure)
export CLOUD_REGION="us-west1"                                      # Cloud region

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME \
  --telemetry-endpoint $TELEMETRY_ENDPOINT \
  --cloud-provider $CLOUD_PROVIDER \
  --cloud-region $CLOUD_REGION
```

#### Register Linode Worker

> 📝 **Note:** For Linode clusters, cloud provider/region are automatically left empty.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"      # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/linode-worker-kubeconfig.yaml"       # Linode worker kubeconfig
export CLUSTER_NAME="worker-linode-1"                                   # Name for the Linode worker
export PROJECT_NAME="avesha"                                            # Project name (default: avesha)

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
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

### Service Types

The generated `egs-installer-config.yaml` provisions these service types (verified on a K3s single-cluster install):

- **Grafana**: `NodePort`
- **Prometheus**: `NodePort`
- **UI Proxy**: `NodePort` on K3s / bare-metal (no cloud LoadBalancer); reachable at `https://<node-ip>:<nodePort>` — e.g. `kubectl get svc kubeslice-ui-proxy -n kubeslice-controller` shows `443:<nodePort>/TCP`.

> 💡 On clusters that have a cloud LoadBalancer controller, pass `--ui-service-type LoadBalancer` to expose the UI via an external IP instead of a NodePort.

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
- **User Override**: If `--cloud-provider` is provided, it takes precedence over auto-detection
- **Linode**: If auto-detected as Linode, `cloudProvider` field is left empty (Linode-specific requirement)
- **Other providers**: Sets `cloudProvider` to detected value (e.g., `gcp`, `aws`, `azure`)
- **Cloud Region**: Use `--cloud-region` to set the region (e.g., `us-west1`, `us-east-1`)

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
├── fetch_egs_slice_token.sh     # Helper to fetch UI/admin login tokens
├── charts/                      # Helm charts directory
└── egs-license.yaml             # Your license file (if placed here)
```

**Note**: The installer clones the repository internally and uses `egs-installer-config.yaml` from the repository as the source of truth. It then updates this file with your specific configuration.

> ⚠️ **Important:** The Quick Installer always uses the **same `egs-installer-config.yaml` file** in your working directory. When you run the installer multiple times, it updates this existing file with your new configuration - it does **not** create a separate config file. In `--register-worker` mode, existing workers are preserved and the new worker is appended.

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
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker.yaml"          # Worker cluster kubeconfig

# ============ EXAMPLE 1: Skip PostgreSQL ============
# (controller only - same flag for single & multi-cluster)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-postgresql
```

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker.yaml"          # Worker cluster kubeconfig

# ============ EXAMPLE 2: Skip Prometheus on Controller Only ============
# (workers still get Prometheus)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-controller-prometheus
```

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker.yaml"          # Worker cluster kubeconfig

# ============ EXAMPLE 3: Skip Prometheus on Workers Only ============
# (controller still gets Prometheus)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-worker-prometheus
```

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker.yaml"          # Worker cluster kubeconfig

# ============ EXAMPLE 4: Skip All Prerequisites on Controller ============
# (install prerequisites on workers only)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --skip-postgresql --skip-controller-prometheus --skip-controller-gpu-operator
```

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker.yaml"          # Worker cluster kubeconfig

# ============ EXAMPLE 5: Skip Prometheus & GPU Operator Everywhere ============
# (all clusters)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
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

---

## 👥 Multiple Workers Support

The Quick Installer supports installing multiple worker clusters in a single command. This is particularly useful for multi-cluster deployments where you have multiple worker clusters that need to be managed by a single controller.

### How It Works

- **Multiple `--worker-kubeconfig` Flags**: Specify `--worker-kubeconfig` multiple times, once for each worker cluster
- **Worker Names**: Use `--worker-name` to assign custom names to each worker (defaults to `worker-1`, `worker-2`, etc.)
- **Worker Contexts**: Use `--worker-context` to specify contexts for each worker (auto-detected if not provided)
- **Order Matters**: The order of `--worker-kubeconfig`, `--worker-context`, and `--worker-name` flags should match

### Examples

#### Two Workers with Default Names

> 📝 **Note:** Workers will be named `worker-1`, `worker-2` automatically.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-kubeconfig $WORKER2_KUBECONFIG
```

#### Two Workers with Custom Names

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER1_NAME="production-worker-1"                           # Worker 1 name
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig
export WORKER2_NAME="production-worker-2"                           # Worker 2 name

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-name $WORKER2_NAME
```

#### Three Workers (Mix of Named and Default)

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER1_KUBECONFIG="/path/to/worker1-kubeconfig.yaml"        # Worker 1 kubeconfig
export WORKER1_NAME="worker-1"                                      # Worker 1 name
export WORKER2_KUBECONFIG="/path/to/worker2-kubeconfig.yaml"        # Worker 2 kubeconfig (auto-named)
export WORKER3_KUBECONFIG="/path/to/worker3-kubeconfig.yaml"        # Worker 3 kubeconfig
export WORKER3_NAME="worker-3"                                      # Worker 3 name

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER1_KUBECONFIG \
  --worker-name $WORKER1_NAME \
  --worker-kubeconfig $WORKER2_KUBECONFIG \
  --worker-kubeconfig $WORKER3_KUBECONFIG \
  --worker-name $WORKER3_NAME
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
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig

# ============ SINGLE WORKER (STILL SUPPORTED) ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG
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
- `--cloud-provider NAME`: Cloud provider name (overrides auto-detection)
- `--cloud-region NAME`: Cloud region (e.g., `us-west1`, `us-east-1`)
- `--controller-namespace NAME`: Controller namespace (default: `kubeslice-controller`)
- `--controller-endpoint URL`: Override the controller API endpoint embedded in the worker onboarding secret (`controllerEndpoint`) — set this to a routable address when the controller kubeconfig uses `127.0.0.1`/`localhost` and the worker is in another network; also useful for Rancher. **Note:** this flag is only applied when the **Controller is installed/upgraded** (it writes `kubeslice.controller.endpoint` into the controller's Helm values). In **`--register-worker`‑only** mode the controller already exists, so this flag has **no effect** — the `controllerEndpoint` minted into new worker secrets comes from the controller's existing advertised endpoint. To change it, re-run the installer against the controller with `--controller-endpoint`.
- `--worker-endpoint URL`: Override the auto-detected worker API endpoint (can be specified multiple times)
- `--ui-service-type TYPE`: Set UI proxy service type (`LoadBalancer`, `NodePort`, or `ClusterIP`)
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
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig
export CLUSTER_NAME="worker-2"                                      # Worker cluster name
export PROJECT_NAME="avesha"                                        # Project name

# ============ REGISTER AND INSTALL IN ONE COMMAND ============
# The script will:
# 1. Register worker-2 with the controller
# 2. Automatically install the worker on worker-2 cluster
# 3. Preserve existing workers (skip_installation=true)
# 4. Set new worker: skip_installation=false (will install)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

**Option 2: Register Only (Without Installation)**

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export CLUSTER_NAME="worker-2"                                      # Worker cluster name
export PROJECT_NAME="avesha"                                        # Project name

# ============ REGISTER ONLY (NO INSTALLATION) ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

```bash
# ============ LATER: INSTALL THE WORKER SEPARATELY ============
export KUBECONFIG_PATH="~/.kube/config"  # Path to worker kubeconfig

curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-postgresql --skip-prometheus --skip-gpu-operator \
  --skip-controller --skip-ui
```

**Option 3: Register Without Installing (Even With Kubeconfig)**

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"          # Worker cluster kubeconfig
export CLUSTER_NAME="worker-2"                                      # Worker cluster name
export PROJECT_NAME="avesha"                                        # Project name

# ============ REGISTER BUT SKIP INSTALLATION ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME \
  --skip-worker
```

### Verification

After registration, verify the cluster status:

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"  # Controller cluster kubeconfig
export PROJECT_NAMESPACE="kubeslice-avesha"                         # Project namespace

# ============ VERIFY CLUSTER REGISTRATION ============
kubectl --kubeconfig $CONTROLLER_KUBECONFIG \
  get cluster.controller.kubeslice.io -n $PROJECT_NAMESPACE
```

### Error Handling

The registration process validates:
- ✅ Controller kubeconfig file exists and is accessible **(fatal if it fails)**
- ✅ Controller cluster connectivity **(fatal if it fails)**
- ⚠️ Worker cluster connectivity (if kubeconfig provided) — **non-fatal**: if the worker is unreachable the installer prints `⚠️ Cannot connect to worker cluster (non-fatal, continuing...)`, still registers the `Cluster` CR, and proceeds to worker installation. (Worker install itself will then fail later if the worker truly is unreachable.)
- ✅ Project namespace exists in controller cluster **(fatal if missing)**
- ✅ Required parameters are provided — e.g. `--register-cluster-name` is **required**; omitting it exits early with `❌ ERROR: --register-cluster-name is required for --register-worker`

Fatal validations display a clear error message and exit early (with temporary-file cleanup). Worker-connectivity is intentionally non-fatal so registration can complete before the worker is reachable.

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
# ============ CUSTOMIZE THESE VALUES ============
export INSTALL_DIR="/my/install/dir"  # Installation directory

# ============ INSTALL WITH DEFAULT LICENSE LOCATION ============
cd $INSTALL_DIR
# Place egs-license.yaml here
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

### Custom License Path

You can specify a custom path (relative to current directory):

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="/path/to/egs-license.yaml"  # Custom license file path

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE
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

After successful installation, access the EGS UI.

> **📝 Note:** The installer script output will display the UI URL and access token automatically at the end of installation. The steps below are for **manual access** if you need to retrieve these details later.

### Script Output Example

At the end of installation, the script displays access information like this:

<pre>
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         🌐 KUBESLICE UI ACCESS INFORMATION                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Service Type: ⚖️  LoadBalancer                                                      │
│ Access URL  : 🔗 https://&lt;EXTERNAL-IP&gt;                                              │
│ Status      : ✅ Ready for external access via LoadBalancer                         │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        🔐 KUBESLICE PROJECT ACCESS TOKENS                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ 🔑 TOKEN: ✅ Available                                                              │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
eyJhbGciOiJSUzI1NiIsImtpZCI6....&lt;TOKEN&gt;....                                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ 💡 USAGE: 📋 COPY THE ABOVE TOKEN AND PASTE IT ON PLACE OF ENTER SERVICE            │
│              ACCOUNT TOKEN IN BROWSER                                               │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          🏁 INSTALLATION SUMMARY COMPLETE                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ ✅ All configured components have been processed.                                   │
│ 📋 Access information displayed above for quick reference.                          │
│ 🔧 For troubleshooting, check logs in file egs-installer-output.log                 │
│ 📚 Refer to documentation https://docs.avesha.io/documentation/enterprise-egs       │
└─────────────────────────────────────────────────────────────────────────────────────┘
</pre>

Simply copy the **Access URL** and **Token** from the script output to access the UI.

---

### Manual Access (If Needed)

If you need to retrieve the UI access details manually (e.g., after the script has finished), follow these steps:

#### 1. Get the UI URL

```bash
# Get the UI service
kubectl get svc kubeslice-ui-proxy -n kubeslice-controller

# Example output (cloud LoadBalancer):
# NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# kubeslice-ui-proxy   LoadBalancer   10.x.x.x       <EXTERNAL-IP>    443:xxxxx/TCP

# Example output (K3s / bare-metal NodePort, verified):
# NAME                 TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)
# kubeslice-ui-proxy   NodePort   10.43.33.240   <none>        443:32568/TCP
```

Access the UI at:
- **LoadBalancer:** `https://<EXTERNAL-IP>`
- **NodePort:** `https://<node-ip>:<nodePort>` (e.g. `https://192.168.122.180:32568`). A `curl -sk -o /dev/null -w '%{http_code}' https://<node-ip>:<nodePort>` returns `302` (redirect to the login page), confirming the UI is serving.

#### 2. Get the Admin Token (recommended)

The most reliable method — works with only `kubectl` and the controller kubeconfig:

```bash
# Direct token retrieval using kubectl (project namespace is kubeslice-<project>, default: kubeslice-avesha)
kubectl get secret kubeslice-rbac-rw-admin -n kubeslice-avesha -o jsonpath='{.data.token}' | base64 -d
```

Copy the output and paste it into the UI login screen.

#### 3. Helper Script (Alternative)

```bash
# The Quick Installer copies fetch_egs_slice_token.sh into your working directory
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -p avesha -a -u admin
```

> 📝 **Note:** `fetch_egs_slice_token.sh` is copied into your working directory by the Quick Installer (alongside `egs-installer.sh`, `egs-install-prerequisites.sh`, and `egs-uninstall.sh`), so it is ready to run after a Quick Install.

**Parameters:**
- `-k /path/to/kubeconfig`: Absolute path to your kubeconfig file
- `-p avesha`: Project name (default: `avesha`)
- `-a`: Fetch admin token
- `-u admin`: Username for the admin token

📖 **For detailed token retrieval options:** See **[Slice & Admin Token Guide](Slice-Admin-Token-README.md)**

---

## 🐛 Troubleshooting

### License File Not Found

**Error**: `❌ ERROR: License file not found`

**Solution**:
```bash
# Ensure license file exists in current directory
ls -la egs-license.yaml

# Or specify custom path
export LICENSE_FILE="/path/to/egs-license.yaml"
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE
```

### Kubeconfig Not Accessible

**Error**: `No active Kubernetes context found!`

**Solution**:
```bash
# ============ CUSTOMIZE THIS VALUE ============
export KUBECONFIG="/path/to/your/kubeconfig.yaml"

# ============ VERIFY CONNECTION ============
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
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller.yaml"  # Controller kubeconfig
export WORKER_KUBECONFIG="/path/to/worker.yaml"          # Worker kubeconfig

# ============ OPTION 1: INSTALL WITH PROMETHEUS (RECOMMENDED) ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG
```

```bash
# ============ CUSTOMIZE THIS VALUE ============
export WORKER_KUBECONFIG="/path/to/worker.yaml"  # Worker kubeconfig

# ============ OPTION 2: INSTALL PROMETHEUS MANUALLY ============
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace egs-monitoring --create-namespace \
  --kubeconfig $WORKER_KUBECONFIG
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
  # ============ CUSTOMIZE THESE VALUES ============
  export CONTROLLER_KUBECONFIG="/path/to/controller-kubeconfig.yaml"
  export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"
  
  # ============ IN MULTI-CLUSTER MODE ============
  curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
    --controller-kubeconfig $CONTROLLER_KUBECONFIG \
    --worker-kubeconfig $WORKER_KUBECONFIG
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
