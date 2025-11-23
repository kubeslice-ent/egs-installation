# Slurm Cluster Helm Chart - Setup Guide

This guide provides step-by-step instructions for installing and configuring a Slurm cluster using the Helm chart.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 0: Install Soperator](#step-0-install-soperator)
3. [Step 1: Install CRDs](#step-1-install-crds)
4. [Step 2: Configure Values](#step-2-configure-values)
5. [Step 3: Install Slurm Cluster](#step-3-install-slurm-cluster)
6. [Step 4: Verify Installation](#step-4-verify-installation)
7. [Step 5: Access the Cluster](#step-5-access-the-cluster)
8. [Troubleshooting](#troubleshooting)
9. [Uninstallation](#uninstallation)

## Prerequisites

Before installing the Slurm cluster, ensure you have:

- **Kubernetes cluster** (version >= 1.29.0)
- **kubectl** configured to access your cluster
- **Helm 3** installed
- **Storage Class** available for PersistentVolumes (e.g., `csi-mounted-fs-path-sc`)
- **Kubernetes nodes** with appropriate labels for scheduling (e.g., GPU nodes)
- **NVIDIA GPU Operator** (if using GPU clusters)
- **NVIDIA Network Operator** (if using InfiniBand networking)

### Check Prerequisites

```bash
# Verify kubectl access
kubectl cluster-info

# Verify Helm is installed
helm version

# List available storage classes
kubectl get storageclass

# Check node labels (for GPU clusters)
kubectl get nodes --show-labels | grep gpu
```

## Step 0: Install Soperator

**Soperator** is the Kubernetes operator that manages Slurm clusters. It must be installed before deploying any Slurm clusters.

### About OpenKruise

Soperator relies on [**OpenKruise operator**](https://github.com/openkruise/kruise) to manage Advanced StatefulSets. By default, OpenKruise is automatically installed as a dependency when installing soperator. However, you can disable its installation if you already have OpenKruise operator installed in your cluster.

> [!IMPORTANT]
> If you're installing OpenKruise separately, make sure you have the required feature gates enabled:
> - `ImagePullJobGate=true`
> - `RecreatePodWhenChangeVCTInCloneSetGate=true`
> - `StatefulSetAutoResizePVCGate=true`
> - `StatefulSetAutoDeletePVC=true`
> - `PreDownloadImageForInPlaceUpdate=true`

### Method 1: Install from OCI Registry (Recommended)

This method installs soperator from the official OCI registry.

#### Enable OCI Support

```bash
export HELM_EXPERIMENTAL_OCI=1
```

#### Add Helm Repository

For the stable version:
```bash
helm repo add soperator oci://cr.eu-north1.nebius.cloud/soperator
```

For the dev/unstable version:
```bash
helm repo add soperator-dev oci://cr.eu-north1.nebius.cloud/soperator-unstable
```

#### Update Helm Repositories

```bash
helm repo update
```

#### Install Soperator

For stable version:
```bash
helm install soperator soperator/helm-soperator \
  --namespace soperator-system \
  --create-namespace \
  --version 1.22.3
```

For dev version:
```bash
helm install soperator soperator-dev/helm-soperator \
  --namespace soperator-system \
  --create-namespace \
  --version 1.22.3
```

### Method 2: Install from Local Chart Directory

If you have the soperator chart in your local repository:

```bash
# Navigate to the repository root
cd /path/to/soperator-1.22.3

# Install from local chart directory
helm install soperator helm/soperator/ \
  --namespace soperator-system \
  --create-namespace
```

### Verify Soperator Installation

Wait for soperator to be ready:

```bash
# Check soperator pods
kubectl get pods -n soperator-system

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# soperator-manager-xxx                  2/2     Running   0          2m
# kruise-manager-xxx                    2/2     Running   0          2m
```

Verify the manager is running:

```bash
# Check soperator manager logs
kubectl logs -n soperator-system deployment/soperator-manager -c manager --tail=20

# Check if CRDs are installed
kubectl get crd | grep slurm.nebius.ai
```

Expected CRDs:
- `slurmclusters.slurm.nebius.ai`
- `activechecks.slurm.nebius.ai`
- `jailedconfigs.slurm.nebius.ai`
- (and other related CRDs)

### Troubleshooting Soperator Installation

If soperator pods are not starting:

1. **Check pod status**:
   ```bash
   kubectl describe pod -n soperator-system -l control-plane=controller-manager
   ```

2. **Check events**:
   ```bash
   kubectl get events -n soperator-system --sort-by='.lastTimestamp'
   ```

3. **Verify image pull secrets** (if using private registry):
   ```bash
   kubectl get secrets -n soperator-system
   ```

4. **Check OpenKruise installation**:
   ```bash
   kubectl get pods -n kruise-system
   ```

Once soperator is installed and running, proceed to the next step.

## Step 1: Install CRDs

The SlurmCluster Custom Resource Definition (CRD) must be installed before deploying the cluster.

> [!NOTE]
> If you installed soperator from the OCI registry or local chart, the CRDs may already be installed. You can verify this by running:
> ```bash
> kubectl get crd | grep slurm.nebius.ai
> ```
> 
> If the CRDs are already present, you can skip this step. However, if you need to install or update CRDs separately, follow the instructions below.

```bash
# Navigate to the chart directory
cd helm/slurm-cluster

# Install CRD chart
helm install soperator-crds ../soperator-crds/ --namespace <your-namespace> --create-namespace

# Or upgrade if already installed
helm upgrade --install soperator-crds ../soperator-crds/ --namespace <your-namespace> --create-namespace

# Wait for CRDs to be ready
kubectl wait --for condition=established --timeout=60s crd/slurmclusters.slurm.nebius.ai
```

## Step 2: Configure Values

Review and customize the `values.yaml` file according to your requirements.

### Key Configuration Options

1. **Cluster Name**: Set your cluster name
   ```yaml
   clusterName: "slurm1"
   ```

2. **Accounting** (Optional): Disable if not using MariaDB operator
   ```yaml
   slurmNodes:
     accounting:
       enabled: false
       externalDB:
         enabled: false
       mariadbOperator:
         enabled: false
   ```

3. **Storage Configuration**: Configure volume sources
   ```yaml
   volumeSources:
     - name: controller-spool
       createPVC: true
       storageClassName: "csi-mounted-fs-path-sc"
       size: "30Gi"
       accessModes: ["ReadWriteOnce"]  # Default if not specified
       persistentVolumeClaim:
         claimName: "controller-spool-pvc"
         readOnly: false
     - name: jail
       createPVC: true
       storageClassName: "csi-mounted-fs-path-sc"
       size: "200Gi"
       accessModes: ["ReadWriteOnce"]  # Default if not specified
       persistentVolumeClaim:
         claimName: "jail-pvc"
         readOnly: false
   ```

4. **Node Filters**: Configure which Kubernetes nodes to use
   ```yaml
   k8sNodeFilters:
     - name: gpu
       affinity:
         nodeAffinity:
           requiredDuringSchedulingIgnoredDuringExecution:
             nodeSelectorTerms:
               - matchExpressions:
                   - key: accelerator
                     operator: In
                     values:
                       - nvidia-tesla-v100
   ```

5. **Cluster Type**: Set to `gpu` or `cpu`
   ```yaml
   clusterType: gpu
   ```

### Important Notes

- **PVC Access Modes**: The chart defaults to `ReadWriteOnce` for PVCs. Most storage classes (especially block storage) only support `ReadWriteOnce`. Only use `ReadWriteMany` if your storage class supports it (e.g., NFS-based storage).

- **Accounting**: If you don't have MariaDB operator installed, make sure to disable accounting:
  ```yaml
  slurmNodes:
    accounting:
      enabled: false
      externalDB:
        enabled: false
      mariadbOperator:
        enabled: false
  ```

## Step 3: Install Slurm Cluster

### Create Namespace (if not exists)

```bash
kubectl create namespace slurm1
```

### Install the Chart

```bash
# Basic installation
helm install slurm1 helm/slurm-cluster/ -n slurm1

# Or with custom values file
helm install slurm1 helm/slurm-cluster/ -n slurm1 -f my-values.yaml

# Or with inline values
helm install slurm1 helm/slurm-cluster/ -n slurm1 \
  --set clusterName=slurm1 \
  --set slurmNodes.accounting.enabled=false
```

### Installation Process

The installation will:

1. Create PriorityClasses for different components
2. Create PersistentVolumeClaims (if `createPVC: true`)
3. Create ConfigMaps for Slurm scripts
4. Create the SlurmCluster Custom Resource
5. The soperator controller will then:
   - Create populate-jail job to initialize the jail filesystem
   - Create controller StatefulSet
   - Create worker StatefulSet
   - Create login StatefulSet
   - Create sconfigcontroller Deployment

### Monitor Installation

```bash
# Watch pods being created
kubectl get pods -n slurm1 -w

# Check SlurmCluster status
kubectl get slurmcluster -n slurm1

# Check PVC status
kubectl get pvc -n slurm1

# Check populate-jail job
kubectl get jobs -n slurm1 | grep populate-jail
```

## Step 4: Verify Installation

### Check Pod Status

All pods should be in `Running` state:

```bash
kubectl get pods -n slurm1
```

Expected output:
```
NAME                               READY   STATUS      RESTARTS   AGE
controller-0                       2/2     Running     0          5m
login-0                            2/2     Running     0          5m
worker-0                           2/2     Running     0          5m
sconfigcontroller-xxx               1/1     Running     0          5m
slurm1-populate-jail-xxx           0/1     Completed   0          5m
```

### Check SlurmCluster Status

```bash
kubectl get slurmcluster slurm1 -n slurm1
```

Expected output:
```
NAME     STATUS      CONTROLLERS   WORKERS   LOGIN   SCONFIGCTRL   ACCOUNTING
slurm1   Available   True          1         1       True          False
```

### Verify Controller

```bash
# Test controller connectivity
kubectl exec controller-0 -n slurm1 -c slurmctld -- scontrol ping
```

Expected output:
```
Slurmctld(primary) at controller-0 is UP
```

### Check PVCs

```bash
kubectl get pvc -n slurm1
```

All PVCs should be `Bound`:
```
NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES
controller-spool-controller-0   Bound    pvc-xxx                                   499Gi      RWO
jail-pvc                        Bound    pvc-xxx                                   499Gi      RWO
worker-spool-worker-0           Bound    pvc-xxx                                   499Gi      RWO
```

## Step 5: Access the Cluster

### Get Login Service Information

```bash
kubectl get svc -n slurm1 | grep login
```

### Option 1: Using LoadBalancer (Recommended)

If the service is exposed via LoadBalancer:

```bash
# Get external IP
EXTERNAL_IP=$(kubectl get svc slurm1-login-svc -n slurm1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# SSH to login node
ssh root@${EXTERNAL_IP} -p 22
```

### Option 2: Using NodePort

```bash
# Get NodePort
NODEPORT=$(kubectl get svc slurm1-login-svc -n slurm1 -o jsonpath='{.spec.ports[0].nodePort}')

# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# SSH to login node
ssh root@${NODE_IP} -p ${NODEPORT}
```

### Option 3: Using Port Forward (For Testing)

```bash
# Forward port
kubectl port-forward -n slurm1 svc/slurm1-login-svc 2222:22

# In another terminal
ssh root@localhost -p 2222
```

### Verify Cluster from Login Node

Once logged in:

```bash
# Check Slurm status
scontrol ping

# View cluster nodes
sinfo

# View partitions
sinfo -l

# Check job queue
squeue

# Submit a test job
srun hostname
```

## Troubleshooting

### Issue: PVCs Stuck in Pending

**Problem**: PVCs remain in `Pending` state.

**Solution**:
- Check if storage class exists: `kubectl get storageclass`
- Verify storage class supports the access mode (usually `ReadWriteOnce`)
- For `WaitForFirstConsumer` binding mode, PVCs bind when a pod using them is scheduled

### Issue: Pods Not Starting

**Problem**: Pods remain in `Init` or `CrashLoopBackOff` state.

**Solutions**:

1. **Check pod logs**:
   ```bash
   kubectl logs <pod-name> -n slurm1 --all-containers=true
   ```

2. **Check populate-jail job**:
   ```bash
   kubectl logs -n slurm1 -l app.kubernetes.io/component=populate-jail --tail=50
   ```

3. **Check controller logs**:
   ```bash
   kubectl logs -n soperator-system deployment/soperator-manager --tail=50
   ```

4. **Verify secrets exist** (if using accounting):
   ```bash
   kubectl get secrets -n slurm1 | grep mariadb
   ```

### Issue: Controller Shows as DOWN

**Problem**: `scontrol ping` shows controller as DOWN.

**Solutions**:

1. **Check controller pod logs**:
   ```bash
   kubectl logs controller-0 -n slurm1 -c slurmctld --tail=50
   ```

2. **Restart controller**:
   ```bash
   kubectl delete pod controller-0 -n slurm1
   ```

3. **Check accounting connection** (if enabled):
   ```bash
   kubectl get pods -n slurm1 | grep accounting
   ```

### Issue: Worker Pod Stuck in Init

**Problem**: Worker pod remains in `Init:1/2` or `Init:0/2` state.

**Solutions**:

1. **Check init container logs**:
   ```bash
   kubectl logs worker-0 -n slurm1 -c wait-for-controller
   kubectl logs worker-0 -n slurm1 -c munge
   ```

2. **Verify controller is ready**:
   ```bash
   kubectl exec controller-0 -n slurm1 -c slurmctld -- scontrol ping
   ```

3. **Check if jail is populated**:
   ```bash
   kubectl exec controller-0 -n slurm1 -c slurmctld -- ls -la /mnt/jail
   ```

### Issue: Login Pod Crashing

**Problem**: Login pod in `CrashLoopBackOff`.

**Solutions**:

1. **Check logs**:
   ```bash
   kubectl logs login-0 -n slurm1 -c sshd --tail=50
   ```

2. **Verify jail is mounted**:
   ```bash
   kubectl exec login-0 -n slurm1 -c sshd -- ls -la /mnt/jail
   ```

3. **Restart login pod**:
   ```bash
   kubectl delete pod login-0 -n slurm1
   ```

### Issue: Populate-Jail Job Failing

**Problem**: populate-jail job shows `Error` status.

**Solutions**:

1. **Check job logs**:
   ```bash
   kubectl logs -n slurm1 -l app.kubernetes.io/component=populate-jail --tail=50
   ```

2. **Delete failed jobs** (controller will recreate):
   ```bash
   kubectl delete job -n slurm1 -l app.kubernetes.io/component=populate-jail
   ```

3. **Clean jail volume** (if corrupted):
   ```bash
   # Delete PVC and let it recreate
   kubectl delete pvc jail-pvc -n slurm1
   # Then restart populate-jail job
   ```

### Issue: CRD Field Warnings

**Problem**: Helm shows warnings about unknown fields in CRD.

**Solutions**:

1. **Update CRD chart**:
   ```bash
   helm upgrade soperator-crds ../soperator-crds/ -n <namespace>
   ```

2. **Verify CRD version matches chart version**

### Complete Reinstall

If you encounter multiple issues, a clean reinstall may be necessary:

```bash
# Uninstall Helm release
helm uninstall slurm1 -n slurm1

# Delete SlurmCluster CR (if still exists)
kubectl delete slurmcluster slurm1 -n slurm1

# Delete PVCs (optional - removes data)
kubectl delete pvc -n slurm1 --all

# Wait for cleanup
sleep 10

# Reinstall
helm install slurm1 helm/slurm-cluster/ -n slurm1
```

## Uninstallation

### Remove Slurm Cluster

#### Remove Helm Release

```bash
helm uninstall slurm1 -n slurm1
```

#### Clean Up Resources

```bash
# Delete SlurmCluster CR
kubectl delete slurmcluster slurm1 -n slurm1

# Delete PVCs (WARNING: This deletes all data)
kubectl delete pvc -n slurm1 --all

# Delete namespace (optional)
kubectl delete namespace slurm1
```

### Remove CRDs (Optional)

```bash
helm uninstall soperator-crds -n <namespace>
```

### Remove Soperator (Optional)

> [!WARNING]
> Only uninstall soperator if you're removing all Slurm clusters. Uninstalling soperator will prevent management of any existing SlurmCluster resources.

#### Uninstall from OCI Registry

```bash
helm uninstall soperator -n soperator-system
```

#### Uninstall from Local Chart

```bash
helm uninstall soperator -n soperator-system
```

#### Clean Up Soperator Resources

```bash
# Delete soperator namespace (this will also remove OpenKruise if installed by soperator)
kubectl delete namespace soperator-system

# If OpenKruise was installed separately, remove it manually
kubectl delete namespace kruise-system
```

#### Remove CRDs (Complete Cleanup)

If you want to completely remove all CRDs:

```bash
# List all Slurm-related CRDs
kubectl get crd | grep slurm.nebius.ai

# Delete all Slurm CRDs
kubectl delete crd $(kubectl get crd | grep slurm.nebius.ai | awk '{print $1}')
```

## Additional Resources

- **Slurm Documentation**: https://slurm.schedmd.com/documentation.html
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Helm Documentation**: https://helm.sh/docs/

## Support

For issues and questions:
- Check the troubleshooting section above
- Review pod logs and events
- Check soperator controller logs in `soperator-system` namespace
- Verify all prerequisites are met

---

**Note**: This guide is based on soperator version 1.22.3. Adjust commands and configurations according to your specific version and requirements.


