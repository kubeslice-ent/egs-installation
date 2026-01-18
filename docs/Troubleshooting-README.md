# 🔧 EGS Troubleshooting Bundle Generator

> **Generate comprehensive diagnostic bundles for EGS deployments with a single command!**

This guide covers the EGS Troubleshooting script (`egs-troubleshoot.sh`) that collects logs, configurations, CRDs, and cluster state for troubleshooting and support purposes.

---

## 📑 Table of Contents

| Section | Description |
|---------|-------------|
| [Quick Start](#-quick-start) | Get started with basic bundle generation |
| [Installation](#-installation) | How to run the troubleshooting script |
| [Command Options](#-command-options) | All available options and flags |
| [What's Collected](#-whats-collected) | Detailed list of collected resources |
| [Multi-Cluster Collection](#-multi-cluster-collection) | Collecting from controller and workers |
| [S3 Upload](#-s3-upload) | Upload bundles to AWS S3 |
| [Bundle Structure](#-bundle-structure) | Understanding the output directory |
| [Examples](#-examples) | Common usage examples |
| [Troubleshooting the Script](#-troubleshooting-the-script) | Common issues and solutions |

---

## 🚀 Quick Start

### One-Liner (Recommended)

```bash
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/config
```

### Local Execution

```bash
# Clone the repository (if not already done)
git clone https://github.com/kubeslice-ent/egs-installation
cd egs-installation

# Run the script
./egs-troubleshoot.sh --kubeconfig ~/.kube/config
```

---

## 📦 Installation

### Prerequisites

The script requires the following tools:

| Tool | Purpose | Required |
|------|---------|----------|
| `kubectl` | Kubernetes CLI | ✅ Yes |
| `jq` | JSON processor | ✅ Yes |
| `tar` | Archive creation | ✅ Yes |
| `gzip` | Compression | ✅ Yes |
| `aws` | S3 upload | ⚪ Optional |
| `helm` | Helm release info | ⚪ Optional |

### Methods

#### Method 1: Curl One-Liner (No Installation Required)

```bash
# Basic usage
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/config

# With additional options
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/config \
  --cluster-name "my-cluster" \
  --skip-logs
```

#### Method 2: Download and Run

```bash
# Download the script
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh -o egs-troubleshoot.sh

# Make executable
chmod +x egs-troubleshoot.sh

# Run
./egs-troubleshoot.sh --kubeconfig ~/.kube/config
```

#### Method 3: From Repository

```bash
git clone https://github.com/kubeslice-ent/egs-installation
cd egs-installation
./egs-troubleshoot.sh --kubeconfig ~/.kube/config
```

---

## ⚙️ Command Options

### Basic Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--help` | `-h` | Show help message | - |
| `--version` | `-v` | Show script version | - |
| `--verbose` | - | Enable verbose output | `false` |
| `--kubeconfig PATH` | `-k` | Path to kubeconfig file | `$KUBECONFIG` or `~/.kube/config` |
| `--context CONTEXT` | `-c` | Kubernetes context to use | Current context |
| `--output-dir DIR` | `-o` | Output directory for the bundle | `./egs-troubleshoot-bundle-TIMESTAMP` |
| `--namespace NS` | `-n` | Additional namespace to include | - |

### Collection Options

| Option | Description | Default |
|--------|-------------|---------|
| `--all-namespaces` | Collect from all namespaces (use with caution) | `false` |
| `--include-secrets` | Include secrets in the bundle (base64 encoded) | `false` |
| `--log-lines NUM` | Number of log lines per container | `1000` |
| `--skip-logs` | Skip collecting container logs | `false` |
| `--skip-metrics` | Skip collecting Prometheus metrics | `false` |
| `--no-previous-logs` | Don't collect previous container logs | `false` |

### S3 Upload Options

| Option | Description | Default |
|--------|-------------|---------|
| `--s3-bucket BUCKET` | S3 bucket name for upload | - |
| `--s3-region REGION` | S3 bucket region | `us-east-1` |
| `--s3-prefix PREFIX` | S3 key prefix for the bundle | - |
| `--aws-profile PROFILE` | AWS profile to use | - |

### Multi-Cluster Options

| Option | Description | Default |
|--------|-------------|---------|
| `--cluster-name NAME` | Identifier for this cluster in the bundle | Auto-detected |
| `--add-kubeconfig PATH` | Additional kubeconfig for multi-cluster | - |

---

## 📋 What's Collected

### Cluster Information

| Category | Resources |
|----------|-----------|
| **Cluster Info** | Kubernetes version, API resources, component statuses |
| **Nodes** | Node list, details, labels, annotations, capacity, allocatable resources, conditions, taints |
| **GPU Info** | GPU node details, NVIDIA labels, GPU capacity |

### EGS CRDs (Custom Resource Definitions)

The script collects all CRDs from the following API groups:

| API Group | Description | Resources |
|-----------|-------------|-----------|
| `controller.kubeslice.io` | KubeSlice Controller | clusters, projects, sliceconfigs, slicegateways, slicenodeaffinities, sliceresourcequotas, slicerolebindings, serviceexportconfigs, gpuprovisioningrequests, workspaces, clustergpuallocations |
| `worker.kubeslice.io` | KubeSlice Worker | gpuworkloads, workerserviceimports, workersliceconfigs, workerslicegateways, workerslicegwrecyclers, workerslicenodeaffinities, workersliceresourcequotas, workerslicerolebindings, workerslicegpuprovisioningrequests, workloadplacements, workerclustergpuallocations |
| `networking.kubeslice.io` | KubeSlice Networking | slices, slicegateways, serviceexports, serviceimports, slicenodeaffinities, sliceresourcequotas, slicerolebindings, vpcserviceimports |
| `inventory.kubeslice.io` | KubeSlice Inventory | clustergpuallocations, workerclustergpuallocations |
| `aiops.kubeslice.io` | KubeSlice AI/Ops | clustergpuallocations, gpuprovisioningrequests, workloadplacements |
| `gpr.kubeslice.io` | GPU Provisioning | gprautoevictions, gprtemplatebindings, gprtemplates, gpuprovisioningrequests, workloadplacements, workloadtemplates, workspacepolicies |
| `monitoring.coreos.com` | Prometheus Operator | servicemonitors, podmonitors, prometheusrules, alertmanagerconfigs |
| `nvidia.com` | NVIDIA GPU Operator | clusterpolicies, nvidiadrivers |
| `nfd.k8s-sigs.io` | Node Feature Discovery | nodefeatures, nodefeaturerules |
| `serving.kserve.io` | KServe | inferenceservices, servingruntimes, clusterservingruntimes |
| `networkservicemesh.io` | Network Service Mesh | networkservices, networkserviceendpoints |
| `spire.spiffe.io` | SPIRE/SPIFFE | spireservers, spireagents |
| `gateway.networking.k8s.io` | Gateway API | gateways, gatewayclasses, httproutes |
| `crd.projectcalico.org` | Calico | networkpolicies, globalnetworkpolicies |

### Namespace Resources

For each EGS-related namespace, the script collects:

| Resource Type | Description |
|---------------|-------------|
| `pods` | All pods with status and details |
| `deployments` | Deployment configurations and status |
| `daemonsets` | DaemonSet configurations |
| `statefulsets` | StatefulSet configurations |
| `replicasets` | ReplicaSet details |
| `jobs` | Job configurations and status |
| `cronjobs` | CronJob configurations |
| `configmaps` | ConfigMap data (non-sensitive) |
| `services` | Service configurations |
| `endpoints` | Endpoint details |
| `serviceaccounts` | ServiceAccount configurations |
| `roles` | Role definitions |
| `rolebindings` | RoleBinding configurations |
| `ingresses` | Ingress configurations |
| `networkpolicies` | NetworkPolicy rules |
| `persistentvolumeclaims` | PVC details |
| `events` | Recent events |

### Namespaces Discovered

The script automatically discovers and collects from:

| Namespace Pattern | Description |
|-------------------|-------------|
| `kubeslice-controller` | KubeSlice Controller namespace |
| `kubeslice-system` | KubeSlice Worker namespace |
| `kubeslice-*` | Project namespaces (e.g., kubeslice-avesha, kubeslice-vertex) |
| `egs-monitoring` | Prometheus/Grafana monitoring |
| `egs-gpu-operator` | NVIDIA GPU Operator |
| `kt-postgresql` | KubeTally PostgreSQL |
| `minio` | MinIO for controller replication |
| `spire` | SPIRE for identity |
| Slice namespaces | Application namespaces onboarded to slices |

### Additional Data

| Category | Details |
|----------|---------|
| **Logs** | Container logs (current and previous, configurable lines) |
| **Helm** | Helm releases, values, and history |
| **Storage** | StorageClasses, PersistentVolumes, PersistentVolumeClaims |
| **Network** | Network policies, services, endpoints |
| **Metrics** | Node metrics, pod metrics (if metrics-server available) |

---

## 🌐 Multi-Cluster Collection

For EGS deployments with multiple clusters (controller + workers), run the script separately on each cluster:

### Controller Cluster

```bash
# Collect from controller cluster
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/controller-kubeconfig.yaml \
  --cluster-name "egs-controller"
```

### Worker Clusters

```bash
# Worker 1
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/worker1-kubeconfig.yaml \
  --cluster-name "worker-1"

# Worker 2
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/worker2-kubeconfig.yaml \
  --cluster-name "worker-2"
```

### Multi-Cluster with S3 Upload

Upload all bundles to the same S3 bucket for easy sharing:

```bash
# Controller
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/controller.yaml \
  --cluster-name "controller" \
  --s3-bucket avesha-support-bundles \
  --s3-region us-east-1

# Worker 1
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/worker1.yaml \
  --cluster-name "worker-1" \
  --s3-bucket avesha-support-bundles \
  --s3-region us-east-1

# Worker 2
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/worker2.yaml \
  --cluster-name "worker-2" \
  --s3-bucket avesha-support-bundles \
  --s3-region us-east-1
```

---

## ☁️ S3 Upload

The script can automatically upload the generated bundle to an AWS S3 bucket for easy sharing with the support team.

### Prerequisites for S3 Upload

1. **AWS CLI** installed and configured
2. **IAM permissions** for `s3:PutObject` and optionally `s3:GetObject` (for presigned URLs)
3. **S3 bucket** created and accessible

### Basic S3 Upload

```bash
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/config \
  --s3-bucket my-support-bucket \
  --s3-region us-west-2
```

### S3 Upload with Prefix

Organize bundles by customer or environment:

```bash
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/config \
  --s3-bucket support-bundles \
  --s3-region us-east-1 \
  --s3-prefix "customer-xyz/production/"
```

### S3 Upload with AWS Profile

Use a specific AWS profile:

```bash
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig ~/.kube/config \
  --s3-bucket support-bundles \
  --s3-region us-east-1 \
  --aws-profile support-team
```

### Presigned URL

After successful upload, the script generates a **presigned URL** valid for 7 days. This URL can be shared with the support team without requiring them to have AWS credentials.

```
✅ Bundle uploaded successfully to: s3://support-bundles/egs-troubleshoot-bundle-20260119-120000.tar.gz
📎 Presigned URL (valid for 7 days):
   https://support-bundles.s3.us-east-1.amazonaws.com/egs-troubleshoot-bundle-20260119-120000.tar.gz?X-Amz-...
```

---

## 📁 Bundle Structure

The generated bundle has the following structure:

```
egs-troubleshoot-bundle-YYYYMMDD-HHMMSS/
├── SUMMARY.md                          # Collection summary report
├── cluster-info/
│   ├── version.txt                     # Kubernetes version
│   ├── api-resources.txt               # Available API resources
│   ├── component-statuses.txt          # Component health
│   └── cluster-info.txt                # Cluster information
├── nodes/
│   ├── nodes-list.txt                  # Node list
│   ├── nodes-wide.txt                  # Node details
│   ├── nodes-detailed.yaml             # Full node YAML
│   ├── node-labels.txt                 # Node labels
│   ├── node-taints.txt                 # Node taints
│   ├── node-capacity.txt               # Node capacity
│   └── gpu-nodes.txt                   # GPU node information
├── crds/
│   ├── all-crds.yaml                   # All CRD definitions
│   ├── controller-*.yaml               # Controller CRs
│   ├── worker-*.yaml                   # Worker CRs
│   ├── networking-*.yaml               # Networking CRs
│   ├── inventory-*.yaml                # Inventory CRs
│   ├── aiops-*.yaml                    # AI/Ops CRs
│   ├── gpr-*.yaml                      # GPR CRs
│   ├── nvidia-*.yaml                   # NVIDIA CRs
│   └── monitoring-*.yaml               # Prometheus CRs
├── namespaces/
│   └── <namespace>/
│       ├── pods.yaml
│       ├── pods-wide.txt
│       ├── deployments.yaml
│       ├── services.yaml
│       ├── configmaps.yaml
│       ├── events.txt
│       └── logs/
│           └── <pod>/
│               ├── <container>.log
│               └── <container>-previous.log
├── helm/
│   ├── releases.txt                    # Helm releases
│   └── <release>-values.yaml           # Release values
├── storage/
│   ├── storageclasses.yaml
│   ├── persistentvolumes.yaml
│   └── persistentvolumeclaims.yaml
├── network/
│   ├── services-all.yaml
│   ├── endpoints-all.yaml
│   └── networkpolicies-all.yaml
└── metrics/
    ├── node-metrics.txt
    └── pod-metrics.txt
```

---

## 📝 Examples

### Example 1: Basic Bundle Generation

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config
```

### Example 2: Skip Logs for Faster Collection

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --skip-logs
```

### Example 3: Collect More Log Lines

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --log-lines 5000
```

### Example 4: Include Secrets (Use with Caution)

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --include-secrets
```

### Example 5: Specific Context

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --context production-cluster
```

### Example 6: Custom Output Directory

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --output-dir /tmp/egs-bundle
```

### Example 7: Add Additional Namespaces

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config \
  --namespace my-app-namespace \
  --namespace another-namespace
```

### Example 8: Verbose Output for Debugging

```bash
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --verbose
```

### Example 9: Complete Multi-Cluster Collection with S3

```bash
# Set common variables
export S3_BUCKET="avesha-support-bundles"
export S3_REGION="us-east-1"

# Controller
./egs-troubleshoot.sh \
  --kubeconfig ~/.kube/controller.yaml \
  --cluster-name "controller" \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION

# Worker 1
./egs-troubleshoot.sh \
  --kubeconfig ~/.kube/worker1.yaml \
  --cluster-name "worker-1" \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION

# Worker 2
./egs-troubleshoot.sh \
  --kubeconfig ~/.kube/worker2.yaml \
  --cluster-name "worker-2" \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION
```

---

## 🔍 Troubleshooting the Script

### Common Issues

#### Issue: "kubectl not found"

**Solution:** Install kubectl and ensure it's in your PATH.

```bash
# Check kubectl
which kubectl
kubectl version --client
```

#### Issue: "jq not found"

**Solution:** Install jq.

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# RHEL/CentOS
sudo yum install jq
```

#### Issue: "Permission denied"

**Solution:** Ensure the script is executable.

```bash
chmod +x egs-troubleshoot.sh
```

#### Issue: "Cannot connect to cluster"

**Solution:** Verify kubeconfig and context.

```bash
# Test connectivity
kubectl --kubeconfig ~/.kube/config get nodes

# List available contexts
kubectl config get-contexts
```

#### Issue: "S3 upload failed"

**Solution:** Verify AWS credentials and permissions.

```bash
# Check AWS configuration
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-bucket/
```

#### Issue: "Bundle is too large"

**Solution:** Skip logs or reduce log lines.

```bash
# Skip logs entirely
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --skip-logs

# Or reduce log lines
./egs-troubleshoot.sh --kubeconfig ~/.kube/config --log-lines 100
```

---

## 📞 Support

If you encounter issues with EGS or need assistance:

1. **Generate a troubleshooting bundle** using this script
2. **Upload to S3** or share the bundle with the support team
3. **Contact Avesha Support** with the bundle and issue description

📧 **Support:** support@avesha.io

📚 **Documentation:** [docs.avesha.io/documentation/enterprise-egs](https://docs.avesha.io/documentation/enterprise-egs)

---

## 📄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.15.5 | 2026-01-19 | Initial release with comprehensive EGS support |

---

