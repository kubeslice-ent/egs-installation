# 🌐 EGS Installer

> ### **[🚀 EGS Installer Documentation](https://repo.egs.avesha.io/) 🚀**
> *The online documentation provides enhanced navigation, better formatting, and the latest updates.*

---

## 🚀 Overview

The EGS Installer provides two installation methods for deploying EGS components into Kubernetes clusters:

| Method | Best For | Description | Documentation |
|--------|----------|-------------|---------------|
| **⚡ Quick Installer** | New users, PoC, simple setups | Single-command installer with auto-configuration, skip flags, and multi-cluster support | **[📖 Quick Install Guide](docs/Quick-Install-README.md)** |
| **📋 Config-Based Installer** | Production, teams, advanced setups | Version-controlled YAML configuration for repeatable, auditable installs | **[📖 Configuration Guide](docs/Configuration-README.md)** |

All methods leverage **Helm** for package management, **kubectl** for Kubernetes interaction, and **yq** for YAML parsing.

---

## ⚡ Quick Installer

> **New to EGS?** Start here with our single-command installer!

### Basic Installation

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file egs-license.yaml --kubeconfig ~/.kube/config
```

### Common Commands

| Scenario | Command |
|----------|---------|
| **Single-cluster (full)** | `curl -fsSL https://repo.egs.avesha.io/install-egs.sh \| bash -s -- --license-file egs-license.yaml --kubeconfig ~/.kube/config` |
| **Skip prerequisites** | Add `--skip-postgresql --skip-prometheus --skip-gpu-operator` |
| **Multi-cluster** | Add `--controller-kubeconfig <ctrl.yaml> --worker-kubeconfig <wkr.yaml>` |
| **Register worker** | `--register-worker --controller-kubeconfig <ctrl.yaml> --register-cluster-name <name> --register-project-name avesha` |

### Quick Reference

| Option | Description |
|--------|-------------|
| `--license-file` | Path to EGS license file (**required** for controller) |
| `--kubeconfig` | Path to kubeconfig file |
| `--cluster-name` | Custom cluster name (default: worker-1) |
| `--skip-postgresql` | Skip PostgreSQL installation |
| `--skip-prometheus` | Skip Prometheus installation |
| `--skip-gpu-operator` | Skip GPU Operator installation |
| `--skip-controller` | Skip EGS Controller installation |
| `--skip-ui` | Skip EGS UI installation |
| `--skip-worker` | Skip EGS Worker installation |

📖 **For complete Quick Installer documentation including multi-cluster setup, worker registration, and all options:**

### **[→ View Full Quick Install Guide](docs/Quick-Install-README.md)**

---

## 📋 Config-Based Installer

> **For production environments** where you need version-controlled, auditable configurations.

The Config-Based Installer uses `egs-installer.sh` with a managed `egs-installer-config.yaml` file. This approach is recommended when you need:

- **Multiple config files** per environment, customer, or cluster topology
- **Fine-grained control** over all installation parameters
- **Version-controlled, auditable** installation configurations
- **Complex multi-cluster** setups with custom monitoring endpoints

📖 **Detailed configuration documentation:** **[Configuration Guide](docs/Configuration-README.md)**

---

## 📄 Documentation Index

| Category | Document | Description |
|----------|----------|-------------|
| **Installation** | [Quick Install Guide](docs/Quick-Install-README.md) | Single-command installer with all options |
| **Installation** | [Configuration Guide](docs/Configuration-README.md) | Config-based installer reference |
| **Installation** | [Multi-Cluster Example](multi-cluster-example.yaml) | Complete multi-cluster YAML example |
| **Prerequisites** | [EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md) | Controller cluster requirements |
| **Prerequisites** | [EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md) | Worker cluster requirements |
| **Setup** | [EGS License Setup](docs/EGS-License-Setup.md) | License configuration guide |
| **Setup** | [Namespace Creation](docs/Namespace-Creation-README.md) | Pre-create namespaces script |
| **Validation** | [Preflight Check](docs/EGS-Preflight-Check-README.md) | Pre-installation validation |
| **Operations** | [Slice & Admin Token](docs/Slice-Admin-Token-README.md) | Token retrieval guide |
| **Operations** | [Custom Pricing](docs/Custom-Pricing-README.md) | Custom pricing configuration |
| **Security** | [Prometheus TLS Authentication](docs/Prometheus-TLS-Authentication.md) | TLS setup for Prometheus |

📚 **User Guide:** [docs.avesha.io/documentation/enterprise-egs](https://docs.avesha.io/documentation/enterprise-egs)

---

## Getting Started

### Prerequisites

Before installation, ensure the following:

#### 1. 📝 Registration

Complete the registration at [Avesha EGS Registration](https://avesha.io/egs-registration) to receive:
- Access credentials
- Product license file (`egs-license.yaml`)

📖 See **[EGS License Setup](docs/EGS-License-Setup.md)** for detailed instructions.

#### 2. 🔧 Required Binaries

Verify these tools are installed and in your `PATH`:

| Binary | Minimum Version |
|--------|-----------------|
| **yq** | 4.44.2 |
| **helm** | 3.15.0 |
| **kubectl** | 1.23.6 |
| **jq** | 1.6.0 |

#### 3. 🌐 Kubernetes Access

Confirm administrative access to target clusters with appropriate `kubeconfig` files.

#### 4. 📂 Clone Repository

```bash
git clone https://github.com/kubeslice-ent/egs-installation
cd egs-installation
```

#### 5. 🔗 KubeSlice Networking (Optional)

> **Note:** KubeSlice networking is **disabled by default** (`kubesliceNetworking: enabled: false`).

If enabling KubeSlice networking, ensure gateway nodes are labeled:

```bash
kubectl get nodes -l kubeslice.io/node-type=gateway
```

The installer can auto-label nodes when `add_node_label: true` is configured.

#### 6. ✅ Preflight Check (Optional)

Validate your environment before installation:

```bash
./egs-preflight-check.sh --kubeconfig ~/.kube/config --kubecontext-list context1,context2
```

📖 See **[Preflight Check Guide](docs/EGS-Preflight-Check-README.md)** for details.

#### 7. 🗂️ Pre-create Namespaces (Optional)

For clusters with namespace policies:

```bash
./create-namespaces.sh --input-yaml namespace-input.yaml --kubeconfig ~/.kube/config
```

📖 See **[Namespace Creation Guide](docs/Namespace-Creation-README.md)** for details.

---

## 🛠️ Config-Based Installation Steps

> **Using Quick Installer?** See the **[Quick Install Guide](docs/Quick-Install-README.md)** instead.

### Step 1: Configure Prerequisites

**Choose ONE approach:**

#### Option A: EGS-Managed Prerequisites (Recommended)

Let EGS install Prometheus, GPU Operator, and PostgreSQL:

```yaml
# egs-installer-config.yaml
global_kubeconfig: "path/to/kubeconfig"    # Required
global_kubecontext: "your-context"         # Required
use_global_context: true

enable_install_controller: true
enable_install_ui: true
enable_install_worker: true
enable_install_additional_apps: true       # Enables prerequisites
enable_custom_apps: false                  # Set true for NVIDIA drivers
run_commands: false                        # Set true for MIG configuration
add_node_label: true                       # Auto-label gateway nodes
```

Run prerequisites installer:

```bash
./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
```

#### Option B: Pre-existing Infrastructure

If you have Prometheus, GPU Operator, or PostgreSQL already running:

- Set `enable_install_additional_apps: false`
- See **[EGS Controller Prerequisites](docs/EGS-Controller-Prerequisites.md)** for Prometheus/PostgreSQL configuration
- See **[EGS Worker Prerequisites](docs/EGS-Worker-Prerequisites.md)** for GPU Operator/monitoring configuration

---

### Step 2: Configure Controller

```yaml
kubeslice_controller_egs:
  skip_installation: false
  use_global_kubeconfig: true
  namespace: "kubeslice-controller"
  release: "egs-controller"
  chart: "kubeslice-controller-egs"
  inline_values:
    global:
      imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems
      kubeTally:
        enabled: true
      postgresSecretName: kubetally-db-credentials
      postgresAddr: "kt-postgresql.kt-postgresql.svc.cluster.local"
      postgresPort: 5432
      postgresUser: "postgres"
      postgresPassword: "postgres"
      postgresDB: "postgres"
      postgresSslmode: disable
      prometheusUrl: http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090
```

📖 See **[egs-installer-config.yaml](egs-installer-config.yaml#L75-L113)** for complete example.

---

### Step 3: Configure UI (Optional)

The UI typically requires **no changes** from defaults.

```yaml
kubeslice_ui_egs:
  skip_installation: false
  use_global_kubeconfig: true
  namespace: "kubeslice-controller"
  release: "egs-ui"
  chart: "kubeslice-ui-egs"
```

📖 See **[egs-installer-config.yaml](egs-installer-config.yaml#L117-L178)** for complete example.

---

### Step 4: Configure Workers

```yaml
kubeslice_worker_egs:
  - name: "worker-1"
    use_global_kubeconfig: true
    skip_installation: false
    namespace: "kubeslice-system"
    release: "egs-worker"
    chart: "kubeslice-worker-egs"
    inline_values:
      global:
        imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems
      operator:
        env:
          - name: DCGM_EXPORTER_JOB_NAME
            value: gpu-metrics
      egs:
        prometheusEndpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
        grafanaDashboardBaseUrl: "http://<grafana-lb>/d/Oxed_c6Wz"
      kubesliceNetworking:
        enabled: false
```

📖 See **[egs-installer-config.yaml](egs-installer-config.yaml#L181-L240)** for complete example.

---

### Step 5: Configure Cluster Registration

```yaml
cluster_registration:
  - cluster_name: "worker-1"
    project_name: "avesha"
    telemetry:
      enabled: true
      endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
      telemetryProvider: "prometheus"
    geoLocation:
      cloudProvider: ""
      cloudRegion: ""
```

📖 See **[Multi-Cluster Example](multi-cluster-example.yaml)** for multi-cluster registration.

---

### Step 6: Run Installation

```bash
./egs-installer.sh --input-yaml egs-installer-config.yaml
```

---

## 🌐 Multi-Cluster Setup

For multi-cluster deployments with workers in different clusters:

### Key Configuration Differences

| Setting | Single-Cluster | Multi-Cluster |
|---------|----------------|---------------|
| `use_global_kubeconfig` | `true` | `false` (per-worker) |
| Worker `kubeconfig` | Empty (uses global) | Worker-specific path |
| Prometheus endpoint | `*.svc.cluster.local` | LoadBalancer/NodePort IP |
| Grafana endpoint | `*.svc.cluster.local` | LoadBalancer/NodePort IP |

### Multi-Cluster Worker Configuration

```yaml
kubeslice_worker_egs:
  - name: "worker-1"
    use_global_kubeconfig: false
    kubeconfig: "path/to/worker-1-kubeconfig.yaml"
    kubecontext: "worker-1-context"
    # ...

  - name: "worker-2"
    use_global_kubeconfig: false
    kubeconfig: "path/to/worker-2-kubeconfig.yaml"
    kubecontext: "worker-2-context"
    # ...
```

⚠️ **Critical:** For multi-cluster, Prometheus endpoints must be externally accessible (LoadBalancer/NodePort), not `*.svc.cluster.local`.

📖 See **[Multi-Cluster Installation Example](multi-cluster-example.yaml)** for complete configuration.

---

## 🗑️ Uninstallation

⚠️ **Warning:** This removes **all EGS resources** including slices, GPRs, and custom resources.

```bash
./egs-uninstall.sh --input-yaml egs-installer-config.yaml
```

---

## 📋 Quick Reference

### Installation Methods Comparison

| Feature | Quick Installer | Config-Based |
|---------|-----------------|--------------|
| Setup Time | Minutes | Varies |
| Configuration | Flags | YAML file |
| Multi-cluster | ✅ Supported | ✅ Supported |
| Version Control | Generated config | Full control |
| Best For | PoC, new users | Production |

### Common Operations

| Operation | Command |
|-----------|---------|
| Full installation | `./egs-installer.sh --input-yaml egs-installer-config.yaml` |
| Prerequisites only | `./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml` |
| Uninstall | `./egs-uninstall.sh --input-yaml egs-installer-config.yaml` |
| Preflight check | `./egs-preflight-check.sh --kubeconfig ~/.kube/config` |

---
