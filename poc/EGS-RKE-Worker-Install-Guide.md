# EGS Worker — Installation Guide for RKE Clusters

> **Based on:** EGS Quick Install v1.0 | Rancher Kubernetes Engine (RKE)
> **Scope:** Register and install the **EGS Worker** against an **existing EGS Controller** — on a **separate worker cluster** or on the **same cluster** as the Controller
> **Prerequisite guide:** [EGS Standalone Controller — Installation Guide for RKE Clusters](EGS-RKE-Controller-Install-Guide.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Worker Installation](#3-worker-installation)
4. [Network Requirements (Separate Worker Cluster)](#4-network-requirements-separate-worker-cluster)
5. [What the Installer Does](#5-what-the-installer-does)
6. [Post-Install Verification](#6-post-install-verification)
7. [Troubleshooting](#7-troubleshooting)
8. [Next Steps](#8-next-steps)

---

## 1. Overview

This guide covers registering and installing the **EGS Worker** against an **EGS Controller that is already running**. It applies to two cases:

| Case | Worker location | When to use |
|------|-----------------|-------------|
| **A — Separate worker cluster** | A different RKE cluster from the Controller | Standard multi-cluster setup: a dedicated control-plane cluster manages one or more remote worker clusters |
| **B — Same cluster as the Controller** | The same RKE cluster that runs the Controller | Single-cluster setup: the Controller and Worker are co-located |

In both cases the EGS Quick Installer (`install-egs.sh`) **registers** the worker with the Controller (creates the `Cluster` custom resource) and **installs** the EGS Worker chart. **No EGS license is required** — the license is validated only when the Controller itself is installed or upgraded.

If the Controller is not yet installed, complete the [Controller installation guide](EGS-RKE-Controller-Install-Guide.md) first, then return here.

### What This Guide Installs (on the worker cluster)

| Component | Namespace | Notes |
|-----------|-----------|-------|
| EGS Worker | `kubeslice-system` | Operator, slice-gateway, and `kubeslice-dns` |
| Prometheus (worker) | `egs-monitoring` | Installed by default; supplies the `PodMonitor` CRDs the Worker needs. Skip with `--skip-worker-prometheus` if already present |
| GPU Operator (worker) | `egs-gpu-operator` | Installed by default on GPU nodes; skip with `--skip-worker-gpu-operator` |
| Cluster registration | `kubeslice-<project>` on the **Controller** (e.g. `kubeslice-avesha`) | `Cluster` CR created on the Controller |

### What This Guide Does NOT Touch

- **EGS Controller, UI, and PostgreSQL** — already installed on the Controller cluster; automatically skipped during a `--register-worker` run
- **EGS License** — not required for worker registration or installation

---

## 2. Prerequisites

### 2.1 Existing Controller

The EGS Controller must already be installed and running. Verify on the **Controller** cluster:

```bash
# Controller and UI pods should be Running
kubectl --kubeconfig <controller-kubeconfig> get pods -n kubeslice-controller

# The project namespace should exist (default project: avesha)
kubectl --kubeconfig <controller-kubeconfig> get ns kubeslice-avesha
```

If these are missing, install the Controller first using the [Controller installation guide](EGS-RKE-Controller-Install-Guide.md).

> 🔑 **Critical for a separate worker cluster (Case A):** the Controller must advertise a **routable** Kubernetes API endpoint so the remote worker can connect back to it. This is set during the **Controller install** with `--controller-endpoint` (see [Section 4](#4-network-requirements-separate-worker-cluster)). It **cannot** be changed by the worker registration command.

### 2.2 Kubeconfigs

| Case | Kubeconfigs needed |
|------|--------------------|
| **A — Separate worker cluster** | Controller kubeconfig **and** the worker cluster kubeconfig |
| **B — Same cluster** | A single kubeconfig (the cluster runs both Controller and Worker) |

RKE generates a kubeconfig at `kube_config_cluster.yml` in the directory where `rke up` was executed. Verify connectivity to each cluster you will use:

```bash
kubectl --kubeconfig /path/to/controller/kube_config_cluster.yml get nodes
kubectl --kubeconfig /path/to/worker/kube_config_cluster.yml get nodes
```

### 2.3 Worker Cluster Requirements

- Admin-level kubeconfig for the worker cluster
- At least one node available to receive the `kubeslice.io/node-type=gateway` label (auto-applied by the installer — see [Section 2.5](#25-gateway-node-labeling))
- **Prometheus `PodMonitor` CRDs**: the Worker requires them. The installer installs the worker's Prometheus by default; if you already run a compatible Prometheus on the worker, you may pass `--skip-worker-prometheus`
- **GPU Operator** (GPU clusters): for nodes with NVIDIA GPUs, the installer installs the NVIDIA GPU Operator on the worker by default so GPU workloads can be scheduled. On CPU-only worker clusters, or where the GPU Operator is already installed, pass `--skip-worker-gpu-operator` to skip it
- **Network reachability to the Controller API** (Case A only) — see [Section 4](#4-network-requirements-separate-worker-cluster)

### 2.4 Required CLI Tools

Verify each tool is installed and at the required version before running the installer:

| Tool | Min Version | Verify Command |
|------|-------------|----------------|
| `kubectl` | v1.23.6+ | `kubectl version --client` |
| `helm` | v3.15.0+ | `helm version` |
| `yq` | v4.44.2+ | `yq --version` |
| `jq` | v1.6+ | `jq --version` |
| `git` | Any recent | `git --version` |
| `curl` | Any recent | `curl --version` |

### 2.5 Gateway Node Labeling

> **Note:** Because the Worker is installed, the installer's worker pre-check labels a node on the **worker cluster** with `kubeslice.io/node-type=gateway` (config key `add_node_label: true`) so the slice-gateway and `kubeslice-dns` pods can schedule. It prefers a node with an `ExternalIP`, falling back to the first available node.

No manual action is required unless your cluster blocks automatic node labeling (OPA/Gatekeeper/PSP) — see [Section 7.5](#75-node-labeling-blocked-by-admission-policy). To pre-label manually:

```bash
kubectl --kubeconfig <worker-kubeconfig> \
  label node <node-name> kubeslice.io/node-type=gateway --overwrite
```

---

## 3. Worker Installation

### 3.1 Case A — Add a Separate Worker Cluster (recommended)

Run from anywhere that can reach **both** the Controller and the worker cluster APIs. The `--register-worker` flow registers the worker with the Controller, then installs the Worker chart on the worker cluster. Controller, UI, and PostgreSQL are automatically skipped.

#### Register AND Install in One Command

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="/path/to/controller/kube_config_cluster.yml"
export WORKER_KUBECONFIG="/path/to/worker/kube_config_cluster.yml"
export CLUSTER_NAME="rke-worker-1"            # Unique name to register this worker as
export PROJECT_NAME="avesha"                  # Project name (default: avesha)

# ============ REGISTER + INSTALL ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

This registers `rke-worker-1` on the Controller and installs the EGS Worker (namespace `kubeslice-system`) on the worker cluster, including the worker's Prometheus and GPU Operator unless skipped.

#### CPU-Only Worker Cluster

Add `--skip-worker-gpu-operator` on worker clusters with no NVIDIA GPUs:

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME \
  --skip-worker-gpu-operator
```

#### Register Only, Install Later

To register the worker now and install it later (for example, when the worker cluster is provisioned separately), omit `--worker-kubeconfig`:

```bash
# Step 1 — Register only (creates the Cluster CR on the Controller)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

```bash
# Step 2 — Later, register + install with the worker kubeconfig
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --register-worker \
  --controller-kubeconfig $CONTROLLER_KUBECONFIG \
  --worker-kubeconfig $WORKER_KUBECONFIG \
  --register-cluster-name $CLUSTER_NAME \
  --register-project-name $PROJECT_NAME
```

> Re-running with the **same** `--register-cluster-name` is safe: the installer preserves the existing entry and does not create a duplicate registration.

### 3.2 Case B — Worker on the Same Cluster as the Controller

When the worker is the **same cluster** as the Controller, you do not need a second kubeconfig or `--register-worker`. Run the installer against that single cluster and skip everything that is already installed; the installer registers the cluster and installs only the Worker.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="/path/to/kube_config_cluster.yml"   # The Controller's own cluster
export CLUSTER_NAME="rke-egs"                               # Name to register this worker as

# ============ INSTALL ONLY THE WORKER (no license needed) ============
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --skip-postgresql \
  --skip-prometheus \
  --skip-gpu-operator \
  --skip-controller \
  --skip-ui
```

This reuses the existing PostgreSQL, Prometheus, and Controller on the cluster. The Worker reaches the Controller API locally, so **no network configuration or `--controller-endpoint` override is needed**. The installer labels the gateway node and registers the Worker.

> **GPU note:** drop `--skip-gpu-operator` if this cluster has NVIDIA GPUs and the GPU Operator is not already installed.

### 3.3 Flag Reference

| Flag | Effect | Applies to |
|------|--------|-----------|
| `--register-worker` | Register a worker with the Controller (auto-skips Controller/UI/PostgreSQL) | Case A |
| `--controller-kubeconfig PATH` | Controller cluster kubeconfig (**required** with `--register-worker`) | Case A |
| `--worker-kubeconfig PATH` | Worker cluster kubeconfig; if provided, the Worker is installed after registration | Case A |
| `--register-cluster-name NAME` | Unique name to register the worker as (**required** with `--register-worker`) | Case A |
| `--register-project-name NAME` | Project name (default: `avesha`) | Case A |
| `--kubeconfig PATH` | Cluster kubeconfig (Controller's own cluster) | Case B |
| `--cluster-name NAME` | Registered worker name and `Cluster` CR name | Case B |
| `--skip-controller`, `--skip-ui`, `--skip-postgresql`, `--skip-prometheus`, `--skip-gpu-operator` | Skip components already installed | Case B |
| `--skip-worker-prometheus` | Skip Prometheus on the worker cluster (use only if a compatible Prometheus already exists) | Case A |
| `--skip-worker-gpu-operator` | Skip GPU Operator on the worker cluster | Case A |
| `--telemetry-endpoint URL` | External Prometheus endpoint on the worker for controller-side metrics | Case A |
| `--cloud-provider NAME` / `--cloud-region NAME` | Record the worker's cloud provider/region in its registration | Case A |

---

## 4. Network Requirements (Separate Worker Cluster)

> Applies to **Case A** only. For Case B (same cluster) the Worker reaches the Controller API locally and this section does not apply.

In a multi-cluster setup the worker connects **back to the Controller** to sync its `Cluster` and `WorkerSlice*` resources and to report to the EGS control plane. Three reachability paths must exist:

| Path | Direction | Why it's needed |
|------|-----------|-----------------|
| **Worker → Controller API** | worker pods → `https://<controller-ip>:6443` | The worker operator reads/writes resources in the Controller's project namespace (`kubeslice-<project>`) |
| **Worker `egs-agent` → Controller UI proxy** | `egs-agent` pod → `https://<controller-ip>:<ui-proxy-nodeport>` (e.g. `:32702`) | The `egs-agent` connects to the Controller's `kubeslice-ui-proxy` (its `API_GW_ENDPOINT`). The installer auto-fetches this URL — see [Section 4.2](#42-egs-agent-endpoint-auto-fetched-from-the-controller) |
| **Controller → Worker telemetry** | Controller → worker Prometheus | Metrics / KubeTally collection (optionally set via `--telemetry-endpoint`) |

### 4.1 Controller Endpoint in the Worker Onboarding Secret

When the worker is registered, the Controller mints a secret whose `controllerEndpoint` is taken from the **Controller's advertised API URL**. On single-node **RKE/K3s/kubeadm**, that URL is often `https://127.0.0.1:6443`, which a **remote** worker cannot reach.

> 🔑 **Set the routable endpoint during the Controller install/upgrade**, not during worker registration. The `--controller-endpoint` flag is only effective when the Controller is installed or upgraded; in `--register-worker` mode it is a **no-op**, and new worker secrets inherit the Controller's existing advertised endpoint. If the Controller currently advertises `127.0.0.1`, re-run the Controller install with:
>
> ```bash
> curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
>   --license-file egs-license.yaml \
>   --kubeconfig <controller-kubeconfig> \
>   --cluster-name <controller-name> \
>   --skip-worker \
>   --controller-endpoint https://<routable-controller-ip>:6443
> ```

### 4.2 `egs-agent` Endpoint (auto-fetched from the Controller)

The worker's `egs-agent` connects to the Controller's `kubeslice-ui-proxy` service (its `API_GW_ENDPOINT`). The installer **automatically discovers** this endpoint from the Controller cluster during a `--register-worker` run and writes it into the Worker values — **no manual override is required**:

- If `kubeslice-ui-proxy` is a **NodePort** (the RKE/K3s default), the installer uses `https://<controller-node-ip>:<nodeport>` (for example `https://<controller-ip>:32702`).
- If it is a **LoadBalancer**, the installer uses the load balancer hostname/IP.
- If it is **ClusterIP only**, the installer records the in-cluster address, which a **remote** worker cannot reach.

> 🔑 **Reachability requirement (Case A):** the discovered `egs-agent` endpoint must be reachable **from the worker cluster**. On a separate worker cluster, expose the Controller's `kubeslice-ui-proxy` as a **NodePort or LoadBalancer** (NodePort is the default) and ensure L3 reachability to that port. If `kubeslice-ui-proxy` is ClusterIP-only, switch it to NodePort/LoadBalancer on the Controller before registering the worker.

Verify the auto-populated endpoint after install (it must **not** be empty):

```bash
kubectl --kubeconfig <worker-kubeconfig> \
  get secret egs-agent-access -n kubeslice-system \
  -o jsonpath='{.data.API_GW_ENDPOINT}' | base64 -d; echo
```

### 4.3 Symptom of an Unreachable Controller Endpoint

The Worker chart deploys and the `kubeslice-operator` pod may even report `Ready` (its readiness probe is a local health check), but its `manager` container logs repeat the following and reconciles never succeed:

```
failed to get server groups: Get "https://<controller-ip>:6443/api":
dial tcp <controller-ip>:6443: connect: no route to host
```

The Worker chart installed correctly — it simply cannot reach the Controller API. Fix L3 reachability (routing / firewall / NAT) and ensure the Controller advertises a routable endpoint ([Section 4.1](#41-controller-endpoint-in-the-worker-onboarding-secret)).

---

## 5. What the Installer Does

For a `--register-worker` run with a worker kubeconfig (Case A), these steps execute automatically in order:

1. Downloads `install-egs.sh` and supporting scripts from `repo.egs.avesha.io`
2. Clones the `egs-installation` repository internally
3. Connects to the Controller with `--controller-kubeconfig` and **registers** the cluster (creates the `Cluster` CR in `kubeslice-<project>`)
4. **Automatically skips** Controller, UI, and PostgreSQL (they belong to the Controller cluster)
5. Validates worker cluster connectivity (non-fatal — see [Section 7.3](#73-worker-registered-but-not-installing))
6. Labels a gateway node on the worker cluster with `kubeslice.io/node-type=gateway`
7. Installs the worker's Prometheus and GPU Operator (unless `--skip-worker-prometheus` / `--skip-worker-gpu-operator`)
8. Installs the EGS Worker in the `kubeslice-system` namespace on the worker cluster
9. Prints completion status to the terminal

> For **Case B** (same cluster), steps 3–8 run against the single cluster, reusing the existing Controller/UI/PostgreSQL and installing only the Worker.

> **Note:** The installer writes these files to your working directory: `egs-installer-config.yaml`, `egs-installer.sh`, `egs-install-prerequisites.sh`, `egs-uninstall.sh`, `fetch_egs_slice_token.sh`, and a `charts/` directory. Keep them for future upgrades or uninstallation.

---

## 6. Post-Install Verification

### 6.1 Worker Pods (on the worker cluster)

```bash
# Worker components: operator, slice-gateway, kubeslice-dns
kubectl --kubeconfig <worker-kubeconfig> get pods -n kubeslice-system
```

All pods should reach `Running` / `Ready`. *(For Case B, use the single cluster kubeconfig.)*

### 6.2 Cluster Registration (on the Controller)

```bash
# Project namespace is kubeslice-<project> (default project: avesha)
kubectl --kubeconfig <controller-kubeconfig> \
  get cluster.controller.kubeslice.io -n kubeslice-avesha
```

The name you registered should be listed and show the worker as registered/connected.

### 6.3 Gateway Node Label (on the worker cluster)

```bash
kubectl --kubeconfig <worker-kubeconfig> get nodes -l kubeslice.io/node-type=gateway
```

At least one node should be returned.

### 6.4 Operator Reconciling (Case A)

Confirm the worker operator can reach the Controller API (no `no route to host`):

```bash
kubectl --kubeconfig <worker-kubeconfig> \
  logs -n kubeslice-system deploy/kubeslice-operator -c manager --tail=50
```

---

## 7. Troubleshooting

### 7.1 PodMonitor CRD not found

**Error:** `no matches for kind "PodMonitor" in version "monitoring.coreos.com/v1"`

The Worker needs Prometheus `PodMonitor` CRDs on the worker cluster. Do **not** pass `--skip-worker-prometheus` unless a compatible Prometheus is already installed. To install Prometheus/CRDs manually on the worker:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace egs-monitoring --create-namespace \
  --kubeconfig <worker-kubeconfig>
```

### 7.2 Worker operator: "no route to host" to the Controller API

The worker cannot reach the Controller's Kubernetes API. See [Section 4](#4-network-requirements-separate-worker-cluster): verify L3 reachability to `https://<controller-ip>:6443` from the worker, and ensure the Controller advertises a routable endpoint (re-run the Controller install with `--controller-endpoint <routable-url>` if it currently advertises `127.0.0.1`).

### 7.3 Worker registered but not installing

If you ran `--register-worker` **without** `--worker-kubeconfig`, only the `Cluster` CR was created. Install the worker by re-running with `--worker-kubeconfig` ([Section 3.1](#31-case-a--add-a-separate-worker-cluster-recommended), Step 2).

> Worker connectivity during registration is **non-fatal**: if the worker is unreachable, the installer prints `⚠️ Cannot connect to worker cluster (non-fatal, continuing...)`, still creates the `Cluster` CR, and the worker install fails later if it remains unreachable.

### 7.4 Cluster not appearing under registration

If `kubectl get cluster.controller.kubeslice.io -n kubeslice-avesha` does not list your worker:

- Confirm the project namespace matches your project (`kubeslice-<project>`; default `kubeslice-avesha`).
- Confirm the Controller pods are `Running` in `kubeslice-controller`.
- Re-run the registration command; it is idempotent and will not create duplicates for the same name.

### 7.5 Node labeling blocked by admission policy

If the worker cluster has OPA/Gatekeeper or PSP policies that block node label mutations, manually apply the gateway label before installing the worker:

```bash
kubectl --kubeconfig <worker-kubeconfig> \
  label node <node-name> kubeslice.io/node-type=gateway --overwrite
```

### 7.6 No active Kubernetes context found

Ensure the relevant kubeconfig is exported and the context is active:

```bash
export KUBECONFIG=/path/to/kube_config_cluster.yml
kubectl config current-context
kubectl get nodes
```

---

## 8. Next Steps

After the Worker is registered and running:

- **Create slices & deploy workloads:** use the EGS UI or APIs to define slices and place GPU/CPU workloads on the registered worker.
- **Add more workers:** repeat [Section 3.1](#31-case-a--add-a-separate-worker-cluster-recommended) with a new `--register-cluster-name` and the new worker's kubeconfig.
- **Retrieve the UI/admin token** (if needed) from the Controller — see the [Controller installation guide](EGS-RKE-Controller-Install-Guide.md).
- **Upgrades:** re-run the installer (optionally with `--local-repo <checkout>` to pin a specific release branch) to upgrade the Worker in place.

### Related Documentation

- [EGS Controller Installation Guide (RKE)](EGS-RKE-Controller-Install-Guide.md)
- [Quick Install Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Quick-Install-README.md)
- [Full Installation Guide](https://github.com/kubeslice-ent/egs-installation/blob/main/README.md)
- [Configuration Reference](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Configuration-README.md)
- [Preflight Check](https://github.com/kubeslice-ent/egs-installation/blob/main/docs/EGS-Preflight-Check-README.md)
- [EGS User Guide](https://docs.avesha.io/documentation/enterprise-egs)

---

*Confidential — Internal Use Only*
