# EGS Worker Prerequisites

This document outlines the prerequisites required for installing and operating the EGS (Enterprise GPU Slicing) Worker in your Kubernetes cluster.

## Table of Contents

- [Overview](#overview)
- [🚀 Quick Start Workflow](#-quick-start-workflow)
- [Prerequisites](#prerequisites)
- [EGS Installer Configuration](#egs-installer-configuration) *(Option 1)*
- [Manual Installation Steps](#manual-installation-steps-option-2) *(Option 2)*
  - [1. GPU Operator Installation](#1-gpu-operator-installation)
  - [2. Kube-Prometheus-Stack Installation](#2-kube-prometheus-stack-installation)
  - [3. GPU Metrics Monitoring Configuration](#3-gpu-metrics-monitoring-configuration)
- [4. Verification Steps](#4-verification-steps)
- [5. Troubleshooting](#5-troubleshooting)

## Overview

The EGS Worker requires several components to be properly configured before installation:
- NVIDIA GPU Operator for GPU management and monitoring
- Kube-Prometheus-Stack for metrics collection and visualization
- Proper monitoring configuration to scrape GPU metrics from GPU Operator components
- GPU-enabled nodes with NVIDIA drivers

## 🚀 Quick Start Workflow

**Choose ONE approach based on your setup:**

### **🔄 Option 1: Use EGS Prerequisites Script (Recommended for new installations)**
- **What it does:** Automatically installs and configures all required components
- **Best for:** New installations, single clusters, simplified setup
- **Time to complete:** ~15-20 minutes
- **Skip to:** [EGS Installer Configuration](#egs-installer-configuration) → [Verification Steps](#4-verification-steps)

### **🌐 Option 2: Use Existing Infrastructure (Advanced)**
- **What it does:** Integrates with your existing GPU Operator, Prometheus, and monitoring setup
- **Best for:** Production environments, multi-cluster setups, existing monitoring infrastructure
- **Time to complete:** ~25-35 minutes (depending on existing setup complexity)
- **Skip to:** [Manual Installation Steps](#manual-installation-steps-option-2)

**⚠️ Important:** Choose only ONE approach - do NOT use both simultaneously to avoid conflicts.

## Prerequisites

- Kubernetes cluster (1.19+) with GPU-enabled nodes
- Helm 3.8.0+
- NVIDIA GPUs with compatible drivers
- PV provisioner support in the underlying infrastructure
- Access to container registry with EGS and NVIDIA images
- Proper RBAC permissions for monitoring and GPU operations

## EGS Installer Configuration

The EGS installer can automatically handle most of the prerequisites installation. To use this approach, configure your `egs-installer-config.yaml`. **For the complete configuration template, see [egs-installer-config.yaml](../egs-installer-config.yaml)**:

```yaml
# Enable additional applications installation
enable_install_additional_apps: true

# Enable custom applications
enable_custom_apps: true

# Command execution settings
run_commands: false

# Additional applications configuration
additional_apps:
  - name: "gpu-operator"
    skip_installation: false
    use_global_kubeconfig: true
    namespace: "egs-gpu-operator"
    release: "gpu-operator"
    chart: "gpu-operator"
    repo_url: "https://helm.ngc.nvidia.com/nvidia"
    version: "v24.9.1"
    specific_use_local_charts: true
    inline_values:
      hostPaths:
        driverInstallDir: "/home/kubernetes/bin/nvidia"
      toolkit:
        installDir: "/home/kubernetes/bin/nvidia"
      cdi:
        enabled: true
        default: true
      driver:
        enabled: false
    helm_flags: "--debug"
    verify_install: false
    verify_install_timeout: 600
    skip_on_verify_fail: true
    enable_troubleshoot: false

  - name: "prometheus"
    skip_installation: false
    use_global_kubeconfig: true
    namespace: "egs-monitoring"
    release: "prometheus"
    chart: "kube-prometheus-stack"
    repo_url: "https://prometheus-community.github.io/helm-charts"
    version: "v45.0.0"
    specific_use_local_charts: true
    inline_values:
      prometheus:
        service:
          type: ClusterIP
        prometheusSpec:
          storageSpec: {}
          additionalScrapeConfigs:
          - job_name: nvidia-dcgm-exporter
            kubernetes_sd_configs:
            - role: endpoints
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod_name
            - source_labels: [__meta_kubernetes_pod_container_name]
              target_label: container_name
          - job_name: gpu-metrics
            scrape_interval: 1s
            metrics_path: /metrics
            scheme: http
            kubernetes_sd_configs:
            - role: endpoints
              namespaces:
                names:
                - egs-gpu-operator
            relabel_configs:
            - source_labels: [__meta_kubernetes_endpoints_name]
              action: drop
              regex: .*-node-feature-discovery-master
            - source_labels: [__meta_kubernetes_pod_node_name]
              action: replace
              target_label: kubernetes_node
      grafana:
        enabled: true
        grafana.ini:
          auth:
            disable_login_form: true
            disable_signout_menu: true
          auth.anonymous:
            enabled: true
            org_role: Viewer
        service:
          type: ClusterIP
        persistence:
          enabled: false
          size: 1Gi
    helm_flags: "--debug"
    verify_install: false
    verify_install_timeout: 600
    skip_on_verify_fail: true
    enable_troubleshoot: false
```

Then run the prerequisites installer:

```bash
./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
```

This will automatically install:
- **GPU Operator** (v24.9.1) in the `egs-gpu-operator` namespace
- **Prometheus Stack** (v45.0.0) in the `egs-monitoring` namespace with GPU metrics configuration

---

## Manual Installation Steps (Option 2)

> **📝 Note:** This section is for **Option 2 (Existing Infrastructure)** users only. If you used the EGS Prerequisites Script (Option 1), skip to [Verification Steps](#4-verification-steps).

**📋 Reference:** For configuration examples and templates, see [egs-installer-config.yaml](../egs-installer-config.yaml)

### **📋 Manual Installation Workflow:**
1. **[GPU Operator Installation](#1-gpu-operator-installation)** - Set up GPU management and monitoring
2. **[Kube-Prometheus-Stack Installation](#2-kube-prometheus-stack-installation)** - Set up monitoring stack
3. **[GPU Metrics Monitoring Configuration](#3-gpu-metrics-monitoring-configuration)** - Configure GPU metrics collection
4. **[Verification Steps](#4-verification-steps)** - Verify all components are working

### 1. GPU Operator Installation

> **📝 Note:** This section is for **Option 2 (Existing Infrastructure)** users only. If you used the EGS Prerequisites Script (Option 1), skip to [Verification Steps](#4-verification-steps).

The NVIDIA GPU Operator is essential for managing GPU resources and exposing GPU metrics that EGS Worker needs for GPU slicing operations.

### 1.1 Add NVIDIA Helm Repository

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
```

### 1.2 Install GPU Operator

```bash
# Create namespace for GPU Operator
kubectl create namespace egs-gpu-operator

# Install GPU Operator with EGS-specific configuration
helm install gpu-operator nvidia/gpu-operator \
  --namespace egs-gpu-operator \
  --set nfd.enabled=true \
  --set nfd.nodefeaturerules=false \
  --set driver.enabled=true \
  --set driver.version="550.144.03" \
  --set driver.useOpenKernelModules=false \
  --set driver.upgradePolicy.autoUpgrade=true \
  --set driver.upgradePolicy.maxParallelUpgrades=1 \
  --set driver.upgradePolicy.maxUnavailable="25%" \
  --set mig.strategy=single \
  --set node-feature-discovery.enableNodeFeatureApi=true \
  --set node-feature-discovery.master.config.extraLabelNs=["nvidia.com"] \
  --set daemonsets.tolerations[0].key="nvidia.com/gpu" \
  --set daemonsets.tolerations[0].operator="Exists" \
  --set daemonsets.tolerations[0].effect="NoSchedule" \
  --set daemonsets.tolerations[1].key="kubeslice.io/egs" \
  --set daemonsets.tolerations[1].operator="Exists" \
  --set daemonsets.tolerations[1].effect="NoSchedule"
```

### 1.3 Verify GPU Operator Installation

```bash
# Check if all GPU Operator pods are running
kubectl get pods -n egs-gpu-operator

# Check GPU Operator components
kubectl get daemonset -n egs-gpu-operator
kubectl get deployment -n egs-gpu-operator

# Verify GPU nodes are labeled
kubectl get nodes --show-labels | grep nvidia.com/gpu

# Check if NVIDIA drivers are installed
kubectl get pods -n egs-gpu-operator -l app=nvidia-driver-daemonset
```

### 1.4 GPU Operator Components

The GPU Operator installs several components that expose metrics:

- **NVIDIA Driver DaemonSet**: Manages GPU drivers on nodes
- **NVIDIA Device Plugin**: Exposes GPU resources to Kubernetes
- **Node Feature Discovery**: Labels nodes with GPU capabilities
- **DCGM Exporter**: Exposes GPU metrics (if enabled)
- **GPU Feature Discovery**: Discovers GPU features and capabilities

## 2. Kube-Prometheus-Stack Installation

> **📝 Note:** This section is for **Option 2 (Existing Infrastructure)** users only. If you used the EGS Prerequisites Script (Option 1), skip to [Verification Steps](#4-verification-steps).

The kube-prometheus-stack provides comprehensive monitoring capabilities for the EGS Worker cluster.

### 2.1 Add Prometheus Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2.2 Install Kube-Prometheus-Stack with GPU Metrics Configuration

Create a custom values file for GPU metrics monitoring:

```yaml
# gpu-monitoring-values.yaml
inline_values:
  prometheus:
    service:
      type: ClusterIP                     # Service type for Prometheus
    prometheusSpec:
      storageSpec: {}                     # Placeholder for storage configuration
      additionalScrapeConfigs:
      - job_name: nvidia-dcgm-exporter
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod_name
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container_name
      - job_name: gpu-metrics
        scrape_interval: 1s
        metrics_path: /metrics
        scheme: http
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - egs-gpu-operator
        relabel_configs:
        - source_labels: [__meta_kubernetes_endpoints_name]
          action: drop
          regex: .*-node-feature-discovery-master
        - source_labels: [__meta_kubernetes_pod_node_name]
          action: replace
          target_label: kubernetes_node
  grafana:
    enabled: true                         # Enable Grafana
    grafana.ini:
      auth:
        disable_login_form: true
        disable_signout_menu: true
      auth.anonymous:
        enabled: true
        org_role: Viewer
    service:
      type: ClusterIP                  # Service type for Grafana
    persistence:
      enabled: false                      # Disable persistence
      size: 1Gi                           # Default persistence size
```

### 2.3 Install with Custom Configuration

```bash
# Create monitoring namespace
kubectl create namespace egs-monitoring

# Install kube-prometheus-stack with GPU metrics configuration
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace egs-monitoring \
  --values gpu-monitoring-values.yaml \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### 2.4 Verify Prometheus Installation

```bash
# Check if all monitoring pods are running
kubectl get pods -n egs-monitoring

# Check Prometheus service
kubectl get svc -n egs-monitoring | grep prometheus

# Verify additional scrape configs are loaded
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring
# Visit http://localhost:9090/config to verify gpu-metrics job is configured
```

### 2.5 Universal Metrics Verification Steps

After implementing any monitoring method, perform these universal checks:

```bash
# 1. Check Prometheus is running and healthy
kubectl get pods -n egs-monitoring -l app.kubernetes.io/name=prometheus
kubectl port-forward -n egs-monitoring prometheus-operated 9090:9090 &
curl -s http://localhost:9090/-/healthy
kill %1

# 2. Verify configuration syntax
kubectl port-forward -n egs-monitoring prometheus-operated 9090:9090 &
curl -s http://localhost:9090/api/v1/status/config | jq '.status'
kill %1

# 3. Check all active targets
kubectl port-forward -n egs-monitoring prometheus-operated 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'
kill %1

# 4. Look for your specific jobs
kubectl port-forward -n egs-monitoring prometheus-operated 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="nvidia-dcgm-exporter" or .labels.job=="gpu-metrics" or (.labels.job | contains("servicemonitor")) or (.labels.job | contains("podmonitor")))'
kill %1
```

### 2.6 GPU Metrics Verification

```bash
# Port forward once for all tests
kubectl port-forward -n egs-monitoring prometheus-operated 9090:9090 &

# 1. Check if GPU metrics are being collected
curl -s "http://localhost:9090/api/v1/query?query=DCGM_FI_DEV_SM_CLOCK" | jq '.data.result | length'

# 2. Check if nvidia-dcgm-exporter metrics are being collected (adjust metric name as needed)
curl -s "http://localhost:9090/api/v1/query?query=up{job=~\".*nvidia-dcgm-exporter.*\"}" | jq '.data.result | length'

# 3. Verify node labeling for GPU metrics
curl -s "http://localhost:9090/api/v1/query?query=DCGM_FI_DEV_SM_CLOCK" | jq '.data.result[0].metric.kubernetes_node'

# 4. Check pod labeling for nvidia-dcgm-exporter metrics
curl -s "http://localhost:9090/api/v1/query?query=up{job=~\".*nvidia-dcgm-exporter.*\"}" | jq '.data.result[0].metric.pod_name'

# 5. Verify scrape intervals
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("gpu")) | .scrapeInterval'

# Close port forward
kill %1
```

## 3. GPU Metrics Monitoring Configuration

> **📝 Note:** This section is for **Option 2 (Existing Infrastructure)** users only. If you used the EGS Prerequisites Script (Option 1), skip to [Verification Steps](#4-verification-steps).

### 3.1 GPU Metrics Endpoints

The GPU Operator exposes metrics on several endpoints that need to be monitored:

- **DCGM Exporter**: GPU performance and health metrics
- **NVIDIA Device Plugin**: GPU resource allocation metrics
- **Node Feature Discovery**: GPU capability labels
- **GPU Feature Discovery**: GPU feature metrics

### 3.2 Service Monitor for GPU Metrics

Create a ServiceMonitor to scrape GPU metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gpu-metrics-monitor
  namespace: egs-monitoring
  labels:
    app.kubernetes.io/instance: kube-prometheus-stack
    release: prometheus  # Required label for Prometheus to discover this ServiceMonitor
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter  # Adjust based on your GPU operator setup
  namespaceSelector:
    matchNames:
    - egs-gpu-operator  # Change this to your GPU operator namespace
  endpoints:
  - port: gpu-metrics
    interval: 1s
    path: /metrics
    scheme: http
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_node_name]
      targetLabel: kubernetes_node
    - sourceLabels: [__meta_kubernetes_endpoints_name]
      action: drop
      regex: .*-node-feature-discovery-master
    - targetLabel: job
      replacement: gpu-metrics
```

### 3.3 Apply Monitoring Configuration

```bash
# Apply the ServiceMonitor
kubectl apply -f gpu-servicemonitor.yaml

# Verify the monitors are created
kubectl get servicemonitor -n egs-monitoring
```

### 3.4 GPU Metrics Dashboard

Import a GPU monitoring dashboard into Grafana:

```bash
# Port forward to Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n egs-monitoring

# Access Grafana at http://localhost:3000
# Import dashboard ID: 14574 (NVIDIA GPU Exporter Dashboard)
```

## 4. Verification Steps

### 4.1 Verify GPU Operator

```bash
# Check GPU Operator status
kubectl get pods -n egs-gpu-operator

# Verify GPU resources are available
kubectl get nodes -o json | jq '.items[] | select(.status.allocatable."nvidia.com/gpu" != null) | .metadata.name'

# Check GPU device plugin
kubectl get pods -n egs-gpu-operator -l app=nvidia-device-plugin-daemonset

# Test GPU allocation
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvcr.io/nvidia/cuda:12.6.3-base-ubuntu22.04 \
  --overrides='{"spec":{"containers":[{"name":"gpu-test","image":"nvcr.io/nvidia/cuda:12.6.3-base-ubuntu22.04","resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}' \
  -- nvidia-smi
```

### 4.2 Verify Prometheus Configuration

```bash
# Check if GPU metrics job is configured
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring
# Visit http://localhost:9090/targets and look for gpu-metrics job

# Check if GPU metrics are being scraped
# Visit http://localhost:9090/graph and query: up{job="gpu-metrics"}

# For comprehensive verification, use the Universal Metrics Verification Steps (section 2.5)
# and GPU Metrics Verification (section 2.6) above
```

### 4.3 Verify GPU Metrics Collection

```bash
# Check if GPU metrics are available
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring

# Query GPU metrics in Prometheus:
# - DCGM_FI_DEV_GPU_UTIL: up{job="gpu-metrics",__name__=~"DCGM_FI_DEV_GPU_UTIL"}
# - GPU Memory Usage: up{job="gpu-metrics",__name__=~"DCGM_FI_DEV_FB_USED"}
# - GPU Temperature: up{job="gpu-metrics",__name__=~"DCGM_FI_DEV_GPU_TEMP"}
```

### 4.4 Verify EGS Worker Readiness

```bash
# Check if EGS Worker can access GPU resources
kubectl get nodes --show-labels | grep nvidia.com/gpu

# Verify GPU operator tolerations are working
kubectl get pods -n egs-gpu-operator -o wide
```

## 5. Troubleshooting

### 5.1 GPU Operator Issues

**Problem**: GPU Operator pods not starting
**Solution**: 
- Check node labels: `kubectl get nodes --show-labels`
- Verify NVIDIA drivers are installed on nodes
- Check GPU operator logs: `kubectl logs -f deployment/gpu-operator-controller-manager -n egs-gpu-operator`

**Problem**: GPU resources not visible to Kubernetes
**Solution**:
- Verify device plugin is running: `kubectl get pods -n egs-gpu-operator -l app=nvidia-device-plugin-daemonset`
- Check device plugin logs for errors
- Verify GPU nodes have proper labels

**Problem**: GPU metrics not exposed
**Solution**:
- Check if DCGM exporter is enabled and running
- Verify metrics endpoint is accessible: `kubectl port-forward svc/nvidia-dcgm-exporter 9400:9400 -n egs-gpu-operator`
- Check DCGM exporter logs for errors

### 5.2 Prometheus Issues

**Problem**: GPU metrics job not showing in targets
**Solution**:
- Verify additionalScrapeConfigs are properly configured
- Check Prometheus configuration: `kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring`
- Visit http://localhost:9090/config to verify gpu-metrics job

**Problem**: GPU metrics showing as DOWN
**Solution**:
- Check if GPU metrics endpoints are accessible
- Verify network policies allow Prometheus to access GPU operator namespace
- Check GPU operator service endpoints

### 5.3 EGS Worker Issues

**Problem**: Worker cannot access GPU resources
**Solution**:
- Verify GPU operator is properly installed and running
- Check if GPU nodes are properly labeled
- Verify GPU device plugin is working
- Check EGS Worker logs for GPU-related errors

**Problem**: GPU slicing not working
**Solution**:
- Verify GPU metrics are being collected by Prometheus
- Check if GPU operator components are exposing required metrics
- Verify EGS Worker has proper RBAC permissions for GPU operations

## Additional Configuration

### 5.4 GPU Operator Advanced Configuration

For production environments, consider these additional GPU Operator settings:

```yaml
# Advanced GPU Operator values
helm install gpu-operator nvidia/gpu-operator \
  --namespace egs-gpu-operator \
  --set driver.enabled=true \
  --set driver.version="550.144.03" \
  --set driver.upgradePolicy.autoUpgrade=false \
  --set mig.strategy=single \
  --set nfd.enabled=true \
  --set nfd.nodefeaturerules=false \
  --set node-feature-discovery.enableNodeFeatureApi=true \
  --set node-feature-discovery.master.config.extraLabelNs=["nvidia.com"] \
  --set daemonsets.updateStrategy="OnDelete" \
  --set daemonsets.rollingUpdate.maxUnavailable="1"
```

### 5.5 Monitoring Stack Optimization

For high-performance GPU monitoring:

```yaml
# Optimized monitoring values
prometheus:
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    resources:
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 1000m

---

## Additional Resources

- [NVIDIA GPU Operator Documentation](https://docs.ngc.nvidia.com/kubernetes/gpu-operator/)
- [Kube-Prometheus-Stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [DCGM Exporter Metrics Reference](https://github.com/NVIDIA/dcgm-exporter)
- [EGS Worker Values Reference](charts/kubeslice-worker-egs/values.yaml)
- [GPU Operator Values Reference](charts/gpu-operator/values.yaml)
- [EGS Installer Configuration Template](../egs-installer-config.yaml)

## Support

For additional support or questions regarding EGS Worker prerequisites, please refer to:
- EGS Documentation: [docs.avesha.io](https://docs.avesha.io)
- NVIDIA GPU Operator Support: [NVIDIA NGC](https://ngc.nvidia.com/)
- GitHub Issues: [EGS Repository](https://github.com/kubeslice/egs)
- Community Support: [KubeSlice Community](https://kubeslice.io/community)
