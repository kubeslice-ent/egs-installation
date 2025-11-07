# EGS Quick Installation Guide

This guide covers the curl-friendly installation of EGS for single-cluster setups.

## 🚦 Quick Start

### Prerequisites

1. **Kubernetes Cluster**: Admin access to a Kubernetes cluster (v1.23.6+)
2. **kubectl**: Configured and connected to your cluster
3. **EGS License**: Valid license file (`egs-license.yaml`)
4. **Required Tools**: `yq`, `helm`, `kubectl`, `jq` (auto-checked by the script)

### Simplest Installation

```bash
# Navigate to your installation directory
cd /path/to/your/directory

# Run the installer (license file defaults to egs-license.yaml in current directory)
export KUBECONFIG=/path/to/your/kubeconfig.yaml
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

**That's it!** The script will:
1. ✅ Auto-detect your cluster configuration
2. ✅ Generate optimized `egs-installer-config.yaml` in your current directory
3. ✅ Apply the EGS license
4. ✅ Install PostgreSQL, Prometheus, GPU Operator (if GPU nodes detected)
5. ✅ Install EGS Controller, UI, and Worker
6. ✅ Display access information and tokens

---

## 📋 Command Options

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- [OPTIONS]
```

### Available Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--license-file PATH` | Path to EGS license file | egs-license.yaml | No |
| `--kubeconfig PATH` | Path to kubeconfig file | Auto-detect | No |
| `--context NAME` | Kubernetes context to use | Current context | No |
| `--cluster-name NAME` | Cluster name for registration | `worker-1` | No |
| `--skip-postgresql` | Skip PostgreSQL installation | false | No |
| `--skip-prometheus` | Skip Prometheus installation | false | No |
| `--skip-gpu-operator` | Skip GPU Operator installation | false | No |
| `--skip-controller` | Skip EGS Controller installation | false | No |
| `--skip-ui` | Skip EGS UI installation | false | No |
| `--skip-worker` | Skip EGS Worker installation | false | No |
| `--help, -h` | Show help message | - | No |

---

## 📝 Usage Examples

### Example 1: Basic Installation (Simplest)

```bash
# Place egs-license.yaml in current directory
cd /home/user/egs-install
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash
```

### Example 2: Custom License File Location

```bash
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /path/to/my-license.yaml
```

### Example 3: Skip Specific Components

```bash
# Skip PostgreSQL and Prometheus (use existing ones)
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus
```

### Example 4: Install Only GPU Operator

```bash
# Install only GPU Operator on existing cluster
export KUBECONFIG=/home/user/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus \
  --skip-controller --skip-ui --skip-worker
```

### Example 5: Custom Cluster Configuration

```bash
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /path/to/license.yaml \
  --kubeconfig ~/.kube/config \
  --context my-cluster \
  --cluster-name production-cluster
```

---

## 🎯 What Gets Installed

The installation order and components depend on the skip parameters used. By default, all components are installed.

### Default Installation Order

1. **📜 EGS License** (Applied to `kubeslice-controller` namespace) - *Only if Controller/UI/Worker are enabled*
2. **🗄️ PostgreSQL** (Namespace: `kt-postgresql`) - *Skipped with `--skip-postgresql`*
3. **📊 Prometheus Stack** (Namespace: `egs-monitoring`) - *Skipped with `--skip-prometheus`*
4. **🎮 GPU Operator** (Namespace: `egs-gpu-operator`) - *Skipped with `--skip-gpu-operator` or auto-skipped on CPU-only clusters*
5. **🎛️ EGS Controller** (Namespace: `kubeslice-controller`) - *Skipped with `--skip-controller`*
6. **🌐 EGS UI** (Namespace: `kubeslice-controller`) - *Skipped with `--skip-ui`*
7. **⚙️ EGS Worker** (Namespace: `kubeslice-system`) - *Skipped with `--skip-worker`*

### Service Types (Single-Cluster Optimized)

- **Grafana**: `ClusterIP` (internal access only) - *Only created if Prometheus is installed*
- **Prometheus**: `ClusterIP` (internal access only) - *Only created if Prometheus is installed*
- **UI Proxy**: `LoadBalancer` (external access) - *Only created if UI is installed*

---

## 🔍 Auto-Detection Features

The script automatically detects and configures:

### GPU Nodes Detection

```bash
# Script checks for GPU nodes
GPU_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | .metadata.name')
```

**Behavior**:
- **GPU nodes found**: Sets `enable_custom_apps: true`, installs GPU Operator
- **No GPU nodes (CPU-only)**: Sets `enable_custom_apps: false`, skips GPU Operator

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

After running the curl installer, you'll find the following files in your current directory:

```
current-directory/
├── egs-installer-config.yaml    # Generated configuration
├── egs-installer.sh             # Main installer script
├── egs-install-prerequisites.sh # Prerequisites installer
├── egs-uninstall.sh             # Uninstaller script
├── charts/                      # Helm charts directory
└── installation-files/          # Runtime installation files
```

---

## 🔧 Generated Configuration

The script generates `egs-installer-config.yaml` with these defaults:

```yaml
# Project and Cluster
project: avesha
cluster_name: worker-1  # Override with --cluster-name

# Service Types (Single-Cluster Optimized)
global_grafana_service_type: ClusterIP
global_prometheus_service_type: ClusterIP
kubeslice_ui_egs.inline_values.kubeslice.uiproxy.service.type: LoadBalancer

# GPU Support (Auto-Detected)
enable_custom_apps: false  # true if GPU nodes detected

# Cloud Provider (Auto-Detected)
cloudProvider: ""  # Empty for Linode, auto-filled for others

# Components (Modified by skip parameters)
enable_install_controller: true      # false if --skip-controller used
enable_install_ui: true             # false if --skip-ui used
enable_install_worker: true         # false if --skip-worker used
enable_install_additional_apps: true
```

---

## 🎭 Installation Modes

### Curl Mode (Remote Installation)

When run via curl, the script:
1. Downloads installer to a temporary location
2. Copies necessary files to your **current directory**
3. Generates config in your **current directory**
4. Runs installation from your **current directory**
5. All files remain in your current directory for future management

```bash
# Work directory: wherever you run the command
cd /my/install/location
curl -fsSL ... | bash -s -- --license-file egs-license.yaml
# Files are created in /my/install/location/
```

### Local Mode (Git Cloned)

When run from a cloned repository:
```bash
git clone https://github.com/kubeslice-ent/egs-installation
cd egs-installation
bash install-egs.sh --license-file egs-license.yaml
```

---

## ⏱️ Installation Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| **Config Generation** | ~10 seconds | Auto-detect cluster, generate config |
| **License Application** | ~5 seconds | Apply EGS license |
| **PostgreSQL** | ~2-3 minutes | Database installation |
| **Prometheus** | ~2-3 minutes | Monitoring stack installation |
| **GPU Operator** | ~2-3 minutes | GPU support (if applicable) |
| **EGS Controller** | ~2-3 minutes | Core controller installation |
| **EGS UI** | ~1-2 minutes | User interface deployment |
| **EGS Worker** | ~2-3 minutes | Worker components installation |
| **Total** | **~10-15 minutes** | Complete end-to-end installation |

---

## 🔍 Accessing Your Installation

### UI Access (Only if UI is installed)

If you installed the EGS UI (not skipped with `--skip-ui`), you'll see:

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

**Error**: `❌ ERROR: License file not found at: egs-license.yaml`

**Solution**:
```bash
# 1. Obtain EGS license from https://avesha.io/egs-registration
# 2. Save it as 'egs-license.yaml' in your current directory
ls -la egs-license.yaml

# Or specify custom path
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file /path/to/your/license.yaml
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

### GPU Operator on CPU-Only Cluster

**Issue**: GPU Operator installed but no GPU nodes

The script automatically detects this and sets `enable_custom_apps: false` to skip GPU Operator installation on CPU-only clusters.

### Installation Timeout

If installation times out during Helm operations, this is usually due to network issues or resource constraints. Check:

```bash
# Check pods status
kubectl get pods -A | grep -E "kubeslice|egs-|kt-postgresql"

# Check helm releases
helm list -A

# Check node resources
kubectl top nodes
```

### Failed Prerequisites Installation

**Check the logs:**
```bash
# In your installation directory
cat egs-install-prerequisites-output.log

# Check for specific errors
grep -i "error\|failed" egs-install-prerequisites-output.log
```

---

## 🔄 Reinstallation / Updates

### Complete Reinstall

```bash
# 1. Uninstall existing components
bash egs-uninstall.sh --input-yaml egs-installer-config.yaml

# 2. Restore original config (optional)
rm egs-installer-config.yaml

# 3. Run installer again
export KUBECONFIG=/path/to/kubeconfig.yaml
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --license-file egs-license.yaml
```

### Update Single Component

If you need to update just one component, use the standard installer:

```bash
# Modify egs-installer-config.yaml as needed
bash egs-installer.sh --input-yaml egs-installer-config.yaml
```

---

## 🎛️ Advanced Configuration

While the quick installer uses smart defaults, you can customize the generated `egs-installer-config.yaml` before installation:

### Manual Config Adjustment

```bash
# 1. Generate config without installing (for now, use the script directly)
bash install-egs.sh --license-file egs-license.yaml
# Press Ctrl+C after config generation if needed

# 2. Edit the generated config
vi egs-installer-config.yaml

# 3. Run installation with custom config
bash egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
bash egs-installer.sh --input-yaml egs-installer-config.yaml
```

### Common Customizations

**Change Service Types:**
```yaml
global_grafana_service_type: LoadBalancer  # Make Grafana externally accessible
global_prometheus_service_type: NodePort   # Use NodePort instead
```

**Custom Image Registry:**
```yaml
global_image_pull_secret:
  repository: "your-registry.example.com"
  username: "your-username"
  password: "your-password"
```

**Enable MIG (Multi-Instance GPU):**
```yaml
enable_custom_apps: true
run_commands: true  # Enable GPU configuration commands
```

---

## 📊 Default Values

### Single-Cluster Defaults

```yaml
# Fixed Values
project_name: avesha
cluster_name: worker-1

# Service Types
global_grafana_service_type: ClusterIP
global_prometheus_service_type: ClusterIP
ui_service_type: LoadBalancer

# Components
enable_install_controller: true
enable_install_ui: true
enable_install_worker: true
enable_install_additional_apps: true
enable_custom_apps: auto-detected  # Based on GPU nodes

# Features
kubeTally.enabled: true
add_node_label: true
```

---

## 🔐 Security Considerations

### License File

- **Storage**: Keep your license file secure
- **Location**: Can be anywhere accessible to the user running the curl command
- **Format**: Must be valid YAML as provided by Avesha

### Kubeconfig

- **Permissions**: The script warns if kubeconfig is world-readable
- **Location**: Can be auto-detected or specified via `--kubeconfig`
- **Context**: Auto-uses current context or specify with `--context`

### Generated Files

After installation, your current directory will contain:
- `egs-installer-config.yaml` - Contains cluster details (review before sharing)
- `charts/` - Helm charts (safe to share)
- `*.sh` scripts - Installation scripts (safe to share)

---

## 📚 Comparison: Quick Install vs. Manual Install

| Feature | Quick Install (Curl) | Manual Install (Git Clone) |
|---------|---------------------|---------------------------|
| **Setup Time** | ~1 minute | ~5-10 minutes |
| **Commands** | 1 curl command | Multiple commands |
| **Configuration** | Auto-generated | Manual editing required |
| **Prerequisites** | Auto-installed | Manual installation |
| **Best For** | Single-cluster, quick setup | Multi-cluster, advanced config |
| **Customization** | Limited (smart defaults) | Full control |
| **Learning Curve** | Minimal | Moderate |

---

## 🎯 Use Cases

### When to Use Quick Install

✅ **Perfect for:**
- First-time EGS installation
- Development/testing environments
- Single-cluster deployments
- Quick demos and POCs
- Standard configurations

❌ **Not recommended for:**
- Multi-cluster deployments
- Highly customized configurations
- Air-gapped environments
- When you need full control over each step

### When to Use Manual Install

For advanced scenarios, refer to the [Full Installation Guide](../README.md#getting-started).

---

## 🛠️ Post-Installation

### Verify Installation

```bash
# Check all components are running
kubectl get pods -A | grep -E "kubeslice|egs-|kt-postgresql"

# Verify helm releases
helm list -A

# Check UI service
kubectl get svc -n kubeslice-controller kubeslice-ui-proxy
```

### Access the UI

1. **Get External IP:**
   ```bash
   kubectl get svc -n kubeslice-controller kubeslice-ui-proxy
   ```

2. **Open in Browser:**
   ```
   https://<EXTERNAL-IP>
   ```

3. **Login:**
   - Copy the access token displayed at the end of installation
   - Paste it in the "Service Account Token" field

### Verify License

```bash
# Check license was applied
kubectl get secrets -n kubeslice-controller | grep egs-license
```

---

## 🗑️ Uninstallation

The quick installer downloads the uninstall script for you:

```bash
# From your installation directory
bash egs-uninstall.sh --input-yaml egs-installer-config.yaml
```

This removes:
- All EGS components (Controller, UI, Worker)
- PostgreSQL
- Prometheus
- GPU Operator
- Associated namespaces

---

## 💡 Tips and Best Practices

### 1. License File Preparation

Before running the installer:
```bash
# Verify license file exists
ls -la egs-license.yaml

# Verify license content
cat egs-license.yaml | head -5
```

### 2. Kubeconfig Setup

```bash
# Option 1: Use default kubeconfig
export KUBECONFIG=~/.kube/config

# Option 2: Use custom kubeconfig
export KUBECONFIG=/path/to/custom-config.yaml

# Verify connection before installation
kubectl get nodes
```

### 3. Installation Directory

```bash
# Create a dedicated directory for EGS installation
mkdir ~/egs-installation
cd ~/egs-installation

# Place your license file here
cp /path/to/egs-license.yaml .

# Run the installer
export KUBECONFIG=~/.kube/config
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- --license-file egs-license.yaml
```

### 4. Network Requirements

Ensure your cluster has:
- **Internet access** (to pull images)
- **LoadBalancer support** (for UI access)
- **Sufficient resources** (4+ nodes recommended)

### 5. Monitoring Installation

```bash
# In another terminal, watch the installation progress
watch -n 5 'kubectl get pods -A | grep -E "kubeslice|egs-|kt-postgresql"'
```

---

## 🔗 Related Documentation

- 📋 [EGS License Setup](EGS-License-Setup.md) - How to obtain and configure your license
- 🛠️ [Full Installation Guide](../README.md#getting-started) - For multi-cluster and advanced setups
- 📊 [Configuration Documentation](Configuration-README.md) - Detailed configuration options
- ✅ [Preflight Check](EGS-Preflight-Check-README.md) - Validate your environment before installation
- 🌐 [EGS User Guide](https://docs.avesha.io/documentation/enterprise-egs) - Complete product documentation

---

## ❓ FAQ

### Q: Can I use this for multi-cluster setups?

**A:** The quick installer is optimized for single-cluster deployments. For multi-cluster setups, use the [manual installation process](../README.md).

### Q: What if I already have Prometheus/PostgreSQL?

**A:** The quick installer will install its own instances. To use existing instances, you'll need to use manual installation and custom configuration.

### Q: Can I change the default cluster name?

**A:** Yes, use `--cluster-name` parameter:
```bash
curl ... | bash -s -- --license-file egs-license.yaml --cluster-name my-cluster
```

### Q: Where is the kubeconfig file?

**A:** The script will copy your kubeconfig to the installation directory if it's not already there. The relative path is used in the generated config.

### Q: What if the installation fails midway?

**A:** The script is designed to be idempotent. You can re-run it, and it will skip already-installed components. For a clean reinstall, use the uninstaller first.

### Q: How do I update EGS after installation?

**A:** For updates:
1. Edit `egs-installer-config.yaml` with new settings
2. Run: `bash egs-installer.sh --input-yaml egs-installer-config.yaml`

### Q: Can I install only specific components?

**A:** Yes! Use skip parameters to install only what you need:
```bash
# Install only Controller
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator \
  --skip-ui --skip-worker

# Install only Worker (skip everything else)
curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --skip-postgresql --skip-prometheus --skip-gpu-operator \
  --skip-controller --skip-ui
```

---

## 📞 Support

For issues or questions:
- 📧 Email: support@avesha.io
- 📚 Documentation: https://docs.avesha.io/documentation/enterprise-egs
- 🐛 Issues: https://github.com/kubeslice-ent/egs-installation/issues

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

---

*Last Updated: November 2025*


