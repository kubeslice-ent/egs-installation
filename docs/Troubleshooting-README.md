# 🔧 EGS Troubleshooting Bundle Generator

## Overview

The EGS Troubleshooting script (`egs-troubleshoot.sh`) provides a **one-command diagnostic bundle generation** for EGS deployments. This guide is designed for users who need to collect logs, configurations, CRDs, and cluster state for troubleshooting and support purposes.

---

## ✨ Features

- **🎯 One-Command Generation**: Generate diagnostic bundles with a single curl command
- **🔍 Auto-Detection**: Automatically detects cluster type (Controller/Worker/Standalone)
- **📝 Comprehensive Collection**: Collects all EGS-related resources, CRDs, logs, and configurations
- **🤖 Smart Discovery**: Automatically discovers EGS namespaces (project namespaces, slice namespaces)
- **⚡ Fast Collection**: Skip logs option for faster bundle generation
- **☁️ S3 Upload**: Direct upload to AWS S3 with presigned URL generation
- **📦 Organized Output**: Well-structured bundle with summary report
- **🔄 Multi-Cluster**: Support for collecting from controller and worker clusters separately

---

## 📑 Table of Contents

| Section | Description |
|---------|-------------|
| [Quick Start](#quick-start) | Get started with basic bundle generation |
| [Prerequisites](#prerequisites) | Required tools before running the script |
| [Command Options](#command-options) | All available options and flags |
| [What's Collected](#whats-collected) | Detailed list of collected resources |
| [Multi-Cluster Collection](#multi-cluster-collection) | Collecting from controller and workers |
| [S3 Upload](#s3-upload) | Upload bundles to AWS S3 |
| [Bundle Structure](#bundle-structure) | Understanding the output directory |
| [Examples](#examples) | Common usage examples |
| [Troubleshooting the Script](#troubleshooting-the-script) | Common issues and solutions |

---

## 🚦 Quick Start

### Simplest Bundle Generation

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH
```

**That's it!** The script will:
1. ✅ Auto-detect your cluster type (Controller/Worker/Standalone)
2. ✅ Discover all EGS-related namespaces
3. ✅ Collect cluster information, nodes, CRDs, and resources
4. ✅ Collect container logs (current and previous)
5. ✅ Collect Helm releases and values
6. ✅ Generate a summary report
7. ✅ Create a compressed archive (`.tar.gz`)

---

## 📋 Prerequisites

The script requires the following tools:

| Tool | Purpose | Required |
|------|---------|----------|
| `kubectl` | Kubernetes CLI | ✅ Yes |
| `jq` | JSON processor | ✅ Yes |
| `tar` | Archive creation | ✅ Yes |
| `gzip` | Compression | ✅ Yes |
| `aws` | S3 upload | ⚪ Optional |
| `helm` | Helm release info | ⚪ Optional |

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
| `--cluster-name NAME` | - | Identifier for this cluster in the bundle | Auto-detected |

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

For EGS deployments with multiple clusters (controller + workers), run the script separately on each cluster.

---

### 🔹 Scenario 1: Single Cluster Bundle

**Use case:** Standalone cluster or collecting from one cluster at a time.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export CLUSTER_NAME="my-cluster"             # Name for your cluster (optional)

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME
```

---

### 🔹 Scenario 2: Controller Cluster Bundle

**Use case:** Collect diagnostic data from the EGS controller cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="~/.kube/controller-kubeconfig.yaml"   # Controller kubeconfig path
export CONTROLLER_NAME="egs-controller"                              # Controller cluster name

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $CONTROLLER_KUBECONFIG \
  --cluster-name $CONTROLLER_NAME
```

---

### 🔹 Scenario 3: Worker Cluster Bundles

**Use case:** Collect diagnostic data from worker clusters.

#### Worker 1

```bash
# ============ CUSTOMIZE THESE VALUES ============
export WORKER1_KUBECONFIG="~/.kube/worker1-kubeconfig.yaml"   # Worker 1 kubeconfig path
export WORKER1_NAME="worker-1"                                  # Worker 1 cluster name

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $WORKER1_KUBECONFIG \
  --cluster-name $WORKER1_NAME
```

#### Worker 2

```bash
# ============ CUSTOMIZE THESE VALUES ============
export WORKER2_KUBECONFIG="~/.kube/worker2-kubeconfig.yaml"   # Worker 2 kubeconfig path
export WORKER2_NAME="worker-2"                                  # Worker 2 cluster name

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $WORKER2_KUBECONFIG \
  --cluster-name $WORKER2_NAME
```

---

### 🔹 Scenario 4: Complete Multi-Cluster Collection

**Use case:** Collect bundles from controller and all workers for comprehensive support.

> 📝 **Note:** Run these commands sequentially. Each command generates a separate bundle for that cluster.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export CONTROLLER_KUBECONFIG="~/.kube/controller.yaml"    # Controller kubeconfig
export WORKER1_KUBECONFIG="~/.kube/worker1.yaml"          # Worker 1 kubeconfig
export WORKER2_KUBECONFIG="~/.kube/worker2.yaml"          # Worker 2 kubeconfig

# ============ CONTROLLER BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $CONTROLLER_KUBECONFIG \
  --cluster-name "controller"

# ============ WORKER 1 BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $WORKER1_KUBECONFIG \
  --cluster-name "worker-1"

# ============ WORKER 2 BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $WORKER2_KUBECONFIG \
  --cluster-name "worker-2"
```

---

## ☁️ S3 Upload

The script can automatically upload the generated bundle to an AWS S3 bucket for easy sharing with the support team.

### Prerequisites for S3 Upload

1. **AWS CLI** installed and configured
2. **IAM permissions** for `s3:PutObject` and optionally `s3:GetObject` (for presigned URLs)
3. **S3 bucket** created and accessible

---

### 🔹 Basic S3 Upload

> 📝 **Note:** Generates bundle and uploads directly to S3 bucket.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export S3_BUCKET="my-support-bucket"         # S3 bucket name
export S3_REGION="us-west-2"                 # S3 bucket region

# ============ GENERATE AND UPLOAD ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION
```

---

### 🔹 S3 Upload with Prefix

> 📝 **Note:** Organize bundles by customer or environment using S3 prefixes.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig file
export S3_BUCKET="support-bundles"               # S3 bucket name
export S3_REGION="us-east-1"                     # S3 bucket region
export S3_PREFIX="customer-xyz/production/"      # S3 key prefix for organization

# ============ GENERATE AND UPLOAD ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION \
  --s3-prefix $S3_PREFIX
```

---

### 🔹 S3 Upload with AWS Profile

> 📝 **Note:** Use a specific AWS profile for authentication.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export S3_BUCKET="support-bundles"           # S3 bucket name
export S3_REGION="us-east-1"                 # S3 bucket region
export AWS_PROFILE_NAME="support-team"       # AWS profile name

# ============ GENERATE AND UPLOAD ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION \
  --aws-profile $AWS_PROFILE_NAME
```

---

### 🔹 Multi-Cluster S3 Upload

> 📝 **Note:** Upload all cluster bundles to the same S3 bucket for easy sharing.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export S3_BUCKET="avesha-support-bundles"                          # S3 bucket name
export S3_REGION="us-east-1"                                        # S3 bucket region
export CONTROLLER_KUBECONFIG="~/.kube/controller.yaml"             # Controller kubeconfig
export WORKER1_KUBECONFIG="~/.kube/worker1.yaml"                   # Worker 1 kubeconfig
export WORKER2_KUBECONFIG="~/.kube/worker2.yaml"                   # Worker 2 kubeconfig

# ============ CONTROLLER BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $CONTROLLER_KUBECONFIG \
  --cluster-name "controller" \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION

# ============ WORKER 1 BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $WORKER1_KUBECONFIG \
  --cluster-name "worker-1" \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION

# ============ WORKER 2 BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $WORKER2_KUBECONFIG \
  --cluster-name "worker-2" \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION
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

> 📝 **Note:** Simplest way to generate a bundle.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH
```

---

### Example 2: Skip Logs for Faster Collection

> 📝 **Note:** Use this when logs are not needed or for faster bundle generation.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-logs
```

---

### Example 3: Collect More Log Lines

> 📝 **Note:** Increase log lines when detailed log analysis is needed.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export LOG_LINES="5000"                       # Number of log lines to collect

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --log-lines $LOG_LINES
```

---

### Example 4: Include Secrets (Use with Caution)

> ⚠️ **Warning:** Only use this when specifically requested by support. Secrets will be base64 encoded in the bundle.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --include-secrets
```

---

### Example 5: Specific Kubernetes Context

> 📝 **Note:** Use this when your kubeconfig has multiple contexts.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig file
export KUBE_CONTEXT="production-cluster"         # Kubernetes context to use

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --context $KUBE_CONTEXT
```

---

### Example 6: Custom Output Directory

> 📝 **Note:** Specify where to save the bundle.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export OUTPUT_DIR="/tmp/egs-bundle"          # Custom output directory

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --output-dir $OUTPUT_DIR
```

---

### Example 7: Add Additional Namespaces

> 📝 **Note:** Include custom namespaces that aren't auto-discovered.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"          # Path to your kubeconfig file
export EXTRA_NS_1="my-app-namespace"             # Additional namespace 1
export EXTRA_NS_2="another-namespace"            # Additional namespace 2

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --namespace $EXTRA_NS_1 \
  --namespace $EXTRA_NS_2
```

---

### Example 8: Verbose Output for Debugging

> 📝 **Note:** Enable verbose output to see detailed progress.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ GENERATE THE BUNDLE ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --verbose
```

---

### Example 9: Complete Bundle with S3 Upload

> 📝 **Note:** Generate bundle and upload to S3 for easy sharing.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export CLUSTER_NAME="production-cluster"     # Cluster name
export S3_BUCKET="avesha-support"            # S3 bucket name
export S3_REGION="us-east-1"                 # S3 bucket region

# ============ GENERATE AND UPLOAD ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --cluster-name $CLUSTER_NAME \
  --s3-bucket $S3_BUCKET \
  --s3-region $S3_REGION
```

---

## 🐛 Troubleshooting the Script

### Common Issues

#### Issue: "kubectl not found"

**Solution:** Install kubectl and ensure it's in your PATH.

```bash
# Check kubectl
which kubectl
kubectl version --client
```

---

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

---

#### Issue: "Cannot connect to cluster"

**Solution:** Verify kubeconfig and context.

```bash
# Test connectivity
kubectl --kubeconfig ~/.kube/config get nodes

# List available contexts
kubectl config get-contexts
```

---

#### Issue: "S3 upload failed"

**Solution:** Verify AWS credentials and permissions.

```bash
# Check AWS configuration
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-bucket/
```

---

#### Issue: "Bundle is too large"

**Solution:** Skip logs or reduce log lines.

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file

# ============ SKIP LOGS ENTIRELY ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --skip-logs
```

Or reduce log lines:

```bash
# ============ CUSTOMIZE THESE VALUES ============
export KUBECONFIG_PATH="~/.kube/config"      # Path to your kubeconfig file
export LOG_LINES="100"                        # Reduced log lines

# ============ GENERATE WITH FEWER LOGS ============
curl -fsSL https://repo.egs.avesha.io/egs-troubleshoot.sh | bash -s -- \
  --kubeconfig $KUBECONFIG_PATH \
  --log-lines $LOG_LINES
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

## 📚 Related Documentation

| Document | Description |
|----------|-------------|
| [Quick Install Guide](Quick-Install-README.md) | Single-command EGS installer |
| [Configuration Reference](Configuration-README.md) | Config-based installer reference |
| [EGS License Setup](EGS-License-Setup.md) | License configuration guide |
| [Controller Prerequisites](EGS-Controller-Prerequisites.md) | Controller cluster requirements |
| [Worker Prerequisites](EGS-Worker-Prerequisites.md) | Worker cluster requirements |

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.15.5 | 2026-01-19 | Initial release with comprehensive EGS support |

---

