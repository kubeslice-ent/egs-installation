# EGS Standalone Controller — Installation Guide for RKE Clusters

> **Based on:** EGS Quick Install v1.0 | Rancher Kubernetes Engine (RKE)  
> **Scope:** Single-cluster, Controller + UI only — Worker omitted

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [RKE-Specific Considerations](#3-rke-specific-considerations)
4. [Installation](#4-installation)
5. [What the Installer Does](#5-what-the-installer-does)
6. [Post-Install Verification](#6-post-install-verification)
7. [Troubleshooting](#7-troubleshooting)
8. [Next Steps](#8-next-steps)

---

## 1. Overview

This guide covers installing the EGS Controller (and optionally the EGS UI) as a standalone deployment on a Rancher Kubernetes Engine (RKE) cluster. The EGS Worker is intentionally omitted — use these instructions when you want a dedicated control-plane cluster that will later register remote worker clusters.

The EGS Quick Installer (`install-egs.sh`) is the recommended approach. It auto-detects cluster capabilities, generates an `egs-installer-config.yaml`, and handles prerequisites such as PostgreSQL, Prometheus, and the GPU Operator.

### What Will Be Installed

| Component | Namespace | Notes |
|-----------|-----------|-------|
| PostgreSQL | `kt-postgresql` | Backing store for the Controller |
| Prometheus Stack | `egs-monitoring` | Metrics and PodMonitor CRDs |
| GPU Operator | `egs-gpu-operator` | Skip with `--skip-gpu-operator` on CPU-only nodes |
| EGS Controller | `kubeslice-controller` | Required |
| EGS UI | `kubeslice-controller` | Optional; omit with `--skip-ui` |

### What Will NOT Be Installed

- **EGS Worker** — excluded via `--skip-worker`
- Any second or worker cluster components

---

## 2. Prerequisites

### 2.1 RKE Cluster Requirements

- RKE version v1.3+ (Kubernetes v1.23.6 or newer on the underlying nodes)
- Admin-level kubeconfig with access to the target RKE cluster
- Nodes: minimum 3 nodes recommended for production; 1-node acceptable for PoC
- UI access: the UI proxy service defaults to `NodePort` (reachable at `https://<node-ip>:<nodePort>`), which works out-of-the-box on bare-metal RKE. Pass `--ui-service-type LoadBalancer` only if a cloud LB or MetalLB is available

### 2.2 Required CLI Tools

Verify each tool is installed and at the required version before running the installer:

| Tool | Min Version | Verify Command |
|------|-------------|----------------|
| `kubectl` | v1.23.6+ | `kubectl version --client` |
| `helm` | v3.15.0+ | `helm version` |
| `yq` | v4.44.2+ | `yq --version` |
| `jq` | v1.6+ | `jq --version` |
| `git` | Any recent | `git --version` |
| `curl` | Any recent | `curl --version` |

### 2.3 EGS License File

> **Note:** A valid EGS license file (`egs-license.yaml`) is required **only when installing the Controller**. It is not required for prerequisites alone, the UI, or Worker.

To obtain a license:

1. Go to <https://avesha.io/egs-registration> and complete the registration form.
2. Generate your cluster fingerprint from the RKE cluster:
   ```bash
   kubectl get namespace kube-system \
     -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'
   ```
3. Submit the fingerprint during registration and receive `egs-license.yaml` via email.
4. Place the file in the directory from which you will run the installer, or note its full path.

---

## 3. RKE-Specific Considerations

### 3.1 Kubeconfig Location

RKE generates a kubeconfig at `kube_config_cluster.yml` (or `kube_config_<cluster-name>.yml`) in the same directory where `rke up` was executed. Export this path before running the installer:

```bash
# Typical RKE kubeconfig location
export KUBECONFIG=/path/to/kube_config_cluster.yml

# Verify connectivity
kubectl get nodes
```

### 3.2 No Cloud Provider — UI Service Type

> **Note:** The EGS UI proxy defaults to `NodePort`, so it works on bare-metal RKE clusters with no cloud LoadBalancer — no extra flags required. Access it at `https://<node-ip>:<nodePort>`.

If you are running MetalLB or another LB provider and prefer an external IP, pass `--ui-service-type LoadBalancer` explicitly. Use `--ui-service-type ClusterIP` to keep the UI internal-only.

### 3.3 GPU Operator on RKE

If your RKE nodes have no NVIDIA GPUs, skip the GPU Operator entirely with `--skip-gpu-operator`. The installer auto-detects GPU capacity; however, explicitly skipping avoids unnecessary wait time on CPU-only clusters.

### 3.4 Gateway Node Labeling — Not Applicable (Controller-Only)

> **Note:** Gateway node labeling (`kubeslice.io/node-type=gateway`) is driven by the **EGS Worker** installation, not the Controller. The installer applies the label inside its worker pre-check — and only for a worker whose installation is **not** skipped (`egs-installer.sh`, worker loop). The Controller chart does not schedule slice-gateway or `kubeslice-dns` pods, so it needs no gateway node.
>
> Because this guide uses `--skip-worker`, the worker entry is marked `skip_installation=true`, the pre-check takes the "skipping" branch, and **no gateway labeling occurs** — no manual action is needed.
>
> ℹ️ In a *full* single-cluster install where the Worker is co-located with the Controller (i.e., **without** `--skip-worker`), that same shared node **does** get labeled — but it is the Worker install that triggers it. Gateway labeling becomes relevant when you register/install a worker cluster (see [Section 8](#8-next-steps)).

---

## 4. Installation

### 4.1 Scenario A — Fresh Install (All Prerequisites)

Use this when PostgreSQL, Prometheus, and GPU Operator are not yet installed on the RKE cluster. This is the most common path for a new cluster.

#### GPU Cluster (with NVIDIA nodes)

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"          # Path to your license file
export KUBECONFIG_PATH="/path/to/kube_config_cluster.yml"
export CLUSTER_NAME="rke-controller"            # Logical name for this cluster

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-worker
```

#### CPU-Only RKE Cluster (No GPUs)

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"
export KUBECONFIG_PATH="/path/to/kube_config_cluster.yml"
export CLUSTER_NAME="rke-controller"

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-worker \
  --skip-gpu-operator
```

#### CPU-Only RKE + Explicit NodePort UI

> **Note:** `NodePort` is already the default UI service type, so the `--ui-service-type NodePort` flag below is **optional** — include it only if you want to be explicit. Use `--ui-service-type LoadBalancer` instead if you have MetalLB or a cloud LB.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"
export KUBECONFIG_PATH="/path/to/kube_config_cluster.yml"
export CLUSTER_NAME="rke-controller"

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-worker \
  --skip-gpu-operator \
  --ui-service-type NodePort
```

---

### 4.2 Scenario B — Skip Prerequisites (Already Installed)

Use this when PostgreSQL, Prometheus, and GPU Operator are already running on the RKE cluster (e.g., upgrading EGS or re-installing after a failed run).

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"
export KUBECONFIG_PATH="/path/to/kube_config_cluster.yml"
export CLUSTER_NAME="rke-controller"

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-postgresql \
  --skip-prometheus \
  --skip-gpu-operator \
  --skip-worker
```

---

### 4.3 Scenario C — Controller Only (No UI)

Use this for a headless controller-only deployment — useful in automation pipelines where UI access is not needed.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export LICENSE_FILE="egs-license.yaml"
export KUBECONFIG_PATH="/path/to/kube_config_cluster.yml"
export CLUSTER_NAME="rke-controller"

# ============ RUN THE INSTALLER ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-prometheus \
  --skip-gpu-operator \
  --skip-worker \
  --skip-ui
```

> **Note:** Prometheus CRDs (`PodMonitor`) are still needed by the Controller. Only skip Prometheus if you have already installed the `kube-prometheus-stack` separately.

---

### 4.4 Override Flags Quick Reference

| Flag | Effect | Use When |
|------|--------|----------|
| `--skip-postgresql` | Skip PostgreSQL (if already installed) | Upgrading or PostgreSQL exists |
| `--skip-prometheus` | Skip Prometheus stack | When Prometheus already deployed |
| `--skip-gpu-operator` | Skip NVIDIA GPU Operator | CPU-only RKE cluster or GPU already configured |
| `--skip-worker` | Skip EGS Worker installation | Installing standalone Controller only |
| `--skip-ui` | Skip EGS UI installation | Headless / controller-only deployment |
| `--ui-service-type TYPE` | Set UI proxy service type: `NodePort` (default), `LoadBalancer`, or `ClusterIP` | Use `LoadBalancer` only when MetalLB/cloud LB exists |

---

## 5. What the Installer Does

The following steps execute automatically in order during a standard standalone controller install:

1. Downloads `install-egs.sh` and supporting scripts from `repo.egs.avesha.io`
2. Clones the `egs-installation` repository internally
3. Auto-detects GPU nodes via `kubectl get nodes` and sets `enable_custom_apps` accordingly
4. Auto-detects cloud provider from node `providerID` (left empty for bare-metal RKE)
5. Generates `egs-installer-config.yaml` in the working directory
6. Applies the EGS license to the `kubeslice-controller` namespace
7. Installs PostgreSQL in the `kt-postgresql` namespace (unless `--skip-postgresql`)
8. Installs Prometheus Stack in the `egs-monitoring` namespace (unless `--skip-prometheus`)
9. Installs GPU Operator in the `egs-gpu-operator` namespace (unless `--skip-gpu-operator`)
10. Installs EGS Controller in the `kubeslice-controller` namespace
11. Installs EGS UI in the `kubeslice-controller` namespace (unless `--skip-ui`)
12. Prints the UI access URL and admin token to the terminal

> **Note:** The installer writes the following files to your working directory: `egs-installer-config.yaml`, `egs-installer.sh`, `egs-install-prerequisites.sh`, `egs-uninstall.sh`, and a `charts/` directory. Keep these for future upgrades or uninstallation.

---

## 6. Post-Install Verification

### 6.1 Check Component Status

```bash
# Verify Controller pods are running
kubectl get pods -n kubeslice-controller

# Verify PostgreSQL
kubectl get pods -n kt-postgresql

# Verify Prometheus
kubectl get pods -n egs-monitoring

# Verify all Helm releases
helm list -A
```

### 6.2 Retrieve UI Access Details

The installer prints the UI URL and token at the end of the run. To retrieve them manually:

#### Get the UI URL

```bash
kubectl get svc kubeslice-ui-proxy -n kubeslice-controller
# Default (NodePort): the PORT(S) column shows 443:<nodePort>/TCP
#   Access URL: https://<any-node-ip>:<nodePort>
# If you passed --ui-service-type LoadBalancer: the EXTERNAL-IP column shows the LB IP
#   Access URL: https://<EXTERNAL-IP>
```

#### Get the Admin Token

```bash
# Option 1: use the bundled helper script
./fetch_egs_slice_token.sh -k /path/to/kube_config_cluster.yml -p avesha -a -u admin

# Option 2: direct kubectl retrieval
# The project namespace is kubeslice-<project> (default project: avesha → kubeslice-avesha)
kubectl get secret kubeslice-rbac-rw-admin -n kubeslice-avesha \
  -o jsonpath='{.data.token}' | base64 -d
```

---

## 7. Troubleshooting

### 7.1 No active Kubernetes context found

The installer cannot find a valid kubeconfig. Ensure `KUBECONFIG` is exported and the context is active:

```bash
export KUBECONFIG=/path/to/kube_config_cluster.yml
kubectl config current-context
kubectl get nodes
```

### 7.2 License file not found

The installer exits with `❌ ERROR: License file not found`. Confirm the file exists and the path is correct:

```bash
ls -la egs-license.yaml

# Or specify the full path explicitly:
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /full/path/to/egs-license.yaml ...
```

### 7.3 PodMonitor CRD not found

**Error:** `no matches for kind "PodMonitor" in version "monitoring.coreos.com/v1"`

This occurs when `--skip-prometheus` was used but Prometheus CRDs are absent. Either remove `--skip-prometheus` or manually install the CRDs:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace egs-monitoring --create-namespace \
  --kubeconfig $KUBECONFIG_PATH
```

### 7.4 UI service stuck in Pending (only if LoadBalancer was selected)

This does **not** occur with the default `NodePort` service type. It happens only if you explicitly passed `--ui-service-type LoadBalancer` on a bare-metal RKE cluster with no LB provider — the `kubeslice-ui-proxy` service then stays in `<pending>` for its external IP. Re-run with the default (omit the flag) or `--ui-service-type NodePort`, or install MetalLB and re-run:

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file $LICENSE_FILE \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-postgresql --skip-prometheus --skip-gpu-operator \
  --skip-worker \
  --ui-service-type NodePort
```

### 7.5 Controller requires PostgreSQL

**Error:** `❌ ERROR: Controller installation requires PostgreSQL to be installed.`

If you used `--skip-postgresql`, confirm that a Helm release named `postgresql` or `kt-postgresql` exists:

```bash
helm list -A | grep -i postgresql
```

### 7.6 Node labeling blocked by admission policy (worker installs only)

> Applies when you later install/register a **worker** cluster — gateway labeling is not performed during this controller-only install.

If the worker cluster has OPA/Gatekeeper or PSP policies that block node label mutations, manually apply the gateway label before installing the worker:

```bash
kubectl label node <node-name> kubeslice.io/node-type=gateway --overwrite
```

---

## 8. Next Steps

After the standalone Controller is running, you can register remote worker clusters. For the full worker installation guide (separate cluster and same-cluster cases), see [EGS Worker — Installation Guide for RKE Clusters](EGS-RKE-Worker-Install-Guide.md).

Each worker cluster registration requires:

- A separate kubeconfig for the worker cluster
- The Controller kubeconfig (already used above)
- A unique name for the worker cluster

Register and install a worker cluster with a single command:

```bash
export CONTROLLER_KUBECONFIG="/path/to/kube_config_cluster.yml"
export WORKER_KUBECONFIG="/path/to/worker-kubeconfig.yaml"
export CLUSTER_NAME="rke-worker-1"
export PROJECT_NAME="avesha"

curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

### Related Documentation

- [EGS License Setup](../docs/EGS-License-Setup.md)
- [Quick Install Guide](../docs/Quick-Install-README.md)
- [Full Installation Guide](../README.md)
- [Configuration Reference](../docs/Configuration-README.md)
- [Preflight Check](../docs/EGS-Preflight-Check-README.md)
- [EGS User Guide](https://docs.avesha.io/documentation/enterprise-egs)

---

*Confidential — Internal Use Only*
