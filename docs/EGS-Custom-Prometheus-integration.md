# EGS Prometheus Integration Guide

This guide explains how to integrate EGS (Enterprise GPU Slice) monitoring configurations into your existing Prometheus deployment. The configurations provided are specifically designed to monitor GPU workloads and AI/ML inference services in Kubernetes environments.

## Overview

EGS provides two main scrape configurations:
1. **nvidia-dcgm-exporter metrics** - Monitors AI/ML inference workloads
2. **GPU metrics** - Monitors GPU hardware utilization via NVIDIA GPU Operator

## Prerequisites

- Existing Prometheus deployment in your Kubernetes cluster
- **CRITICAL**: Prometheus Operator installed (required for Method 1)
- NVIDIA GPU Operator installed (for GPU metrics)
- Appropriate RBAC permissions for Prometheus to discover Kubernetes endpoints
- Text Generation Inference or similar AI/ML workloads (for nvidia-dcgm-exporter metrics)

## Important: Prometheus Operator Requirement

**⚠️ CRITICAL NOTICE**: If you want to use **Method 1 (Scrape Configuration)** with `Prometheus` CRD resources, you **MUST** have the Prometheus Operator installed. Without it, your `Prometheus` custom resources will not work.

### Check if you have Prometheus Operator:
```bash
kubectl get deployment prometheus-operator -A
# OR
kubectl get pods -A | grep prometheus-operator
```

If you don't see a prometheus-operator, you'll need to install it (see installation steps below).

## Integration Methods

There are three main ways to integrate EGS monitoring into your existing Prometheus setup:

### Method 1: Scrape Configuration (additionalScrapeConfigs)

**Requirements**: Prometheus Operator must be installed

This method adds scrape configurations directly to Prometheus using `additionalScrapeConfigs`. This is the most flexible approach but requires the Prometheus Operator.

#### Step 1: Install Prometheus Operator (if not present)

If you don't have Prometheus Operator, install it:

```bash
# Add helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install only the Prometheus Operator (without other components)
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --kubeconfig=your-kubeconfig.yaml \
  --namespace your-monitoring-namespace \
  --set prometheus.enabled=false \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheusOperator.enabled=true \
  --set kubeStateMetrics.enabled=false \
  --set nodeExporter.enabled=false
```

#### Step 2: 

#### Using Helm with kube-prometheus-stack

If you're using the `kube-prometheus-stack` Helm chart, update your `values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      # nvidia-dcgm-exporter (Text Generation Inference) Metrics
      - job_name: nvidia-dcgm-exporter
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod_name
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container_name

      # GPU Metrics from NVIDIA GPU Operator
      - job_name: gpu-metrics
        scrape_interval: 1s
        metrics_path: /metrics
        scheme: http
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - your-gpu-operator-namespace  # Change this to your GPU operator namespace
        relabel_configs:
        - source_labels: [__meta_kubernetes_endpoints_name]
          action: drop
          regex: .*-node-feature-discovery-master
        - source_labels: [__meta_kubernetes_pod_node_name]
          action: replace
          target_label: kubernetes_node
```

Then upgrade your Helm release:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack -f values.yaml
```

**Testing Method:**
```bash
# 1. Upgrade Helm release
helm upgrade prometheus prometheus-community/kube-prometheus-stack -f values.yaml

# 2. Check upgrade status
helm status prometheus

# 3. Test targets discovery
kubectl port-forward -n your-monitoring-namespace prometheus-prometheus-kube-prometheus-prometheus-0 9090:9090


curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="nvidia-dcgm-exporter" or .labels.job=="gpu-metrics")'

```


### Method 2: ServiceMonitor (Prometheus Operator)

**Requirements**: Prometheus Operator must be installed

ServiceMonitors are Kubernetes custom resources that define how services should be monitored. This method is cleaner and more Kubernetes-native when using the Prometheus Operator.

#### GPU Metrics ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: egs-gpu-metrics-service-monitor
  namespace: your-monitoring-namespace
  labels:
    app: egs-gpu-monitoring
    release: prometheus-operator # Required label for Prometheus to discover this ServiceMonitor
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter  # Adjust based on your GPU operator setup
  namespaceSelector:
    matchNames:
    - your-gpu-operator-namespace  # Change this to your GPU operator namespace
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

#### nvidia-dcgm-exporter Metrics ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: egs-nvidia-dcgm-exporter-metrics-service-monitor
  namespace: your-monitoring-namespace
  labels:
    app: egs-nvidia-dcgm-exporter-monitoring
    release: prometheus-operator # Required label for Prometheus to discover this ServiceMonitor
spec:
  selector: {}
    # matchLabels:
    #   control-plane: controller-manager  # Adjust based on your nvidia-dcgm-exporter service labels
  namespaceSelector:
    any: true  # Monitor nvidia-dcgm-exporter services across all namespaces
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
    scheme: http
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: pod_name
    - sourceLabels: [__meta_kubernetes_pod_container_name]
      targetLabel: container_name
    - targetLabel: job
      replacement: nvidia-dcgm-exporter
```

Apply the ServiceMonitors:

```bash
kubectl apply -f gpu-servicemonitor.yaml
kubectl apply -f nvidia-dcgm-exporter-servicemonitor.yaml
```

**Testing Method 2:**
```bash
# 1. Apply ServiceMonitors
kubectl apply -f gpu-servicemonitor.yaml
kubectl apply -f nvidia-dcgm-exporter-servicemonitor.yaml

# 2. Verify ServiceMonitors were created
kubectl get servicemonitors -n your-monitoring-namespace
kubectl describe servicemonitor egs-gpu-metrics -n your-monitoring-namespace
kubectl describe servicemonitor egs-nvidia-dcgm-exporter-metrics -n your-monitoring-namespace


# 3. Verify targets in Prometheus service port forward
kubectl port-forward -n your-monitoring-namespace svc/prometheus-operator-kube-p-prometheus 9090:9090 

```

## Method Comparison

| Method | Pros | Cons | Best For | Requires Prometheus Operator |
|--------|------|------|----------|-------------------------------|
| **Scrape Config** | - Works with any Prometheus setup<br>- Most flexible<br>- Can use complex service discovery | - Requires Prometheus restart/reload (for direct config)<br>- Less Kubernetes-native for CRD approach | - Direct Prometheus deployments<br>- Complex discovery requirements | **Yes** (for CRD approach) |
| **ServiceMonitor** | - Kubernetes-native<br>- Dynamic discovery<br>- No Prometheus restart needed<br>- Works through services | - Requires Prometheus Operator<br>- Needs services to exist | - Service-based architectures<br>- Prometheus Operator environments | **Yes** |

## Universal Testing and Verification

### General Health Checks

After implementing any method, perform these universal checks:

```bash
# 1. Check Prometheus is running and healthy
kubectl get pods -n your-monitoring-namespace -l app.kubernetes.io/name=prometheus
kubectl port-forward -n your-monitoring-namespace prometheus-your-prometheus-0 9090:9090 &
curl -s http://localhost:9090/-/healthy
kill %1

# 2. Verify configuration syntax
kubectl port-forward -n your-monitoring-namespace prometheus-your-prometheus-0 9090:9090 &
curl -s http://localhost:9090/api/v1/status/config | jq '.status'
kill %1

# 3. Check all active targets
kubectl port-forward -n your-monitoring-namespace prometheus-your-prometheus-0 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'
kill %1

# 4. Look for your specific jobs
kubectl port-forward -n your-monitoring-namespace prometheus-your-prometheus-0 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="nvidia-dcgm-exporter" or .labels.job=="gpu-metrics" or (.labels.job | contains("servicemonitor")) or (.labels.job | contains("podmonitor")))'
kill %1
```

### Metrics Verification

```bash
# Port forward once for all tests
kubectl port-forward -n your-monitoring-namespace prometheus-your-prometheus-0 9090:9090 &

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

### Troubleshooting Failed Tests

```bash
# If targets are not discovered:
# 1. Check RBAC permissions
kubectl auth can-i list endpoints --as=system:serviceaccount:your-monitoring-namespace:prometheus-your-prometheus
kubectl auth can-i list pods --as=system:serviceaccount:your-monitoring-namespace:prometheus-your-prometheus
kubectl auth can-i list services --as=system:serviceaccount:your-monitoring-namespace:prometheus-your-prometheus

# 2. Check namespace and label selectors
kubectl get endpoints -n your-gpu-operator-namespace --show-labels
kubectl get services -n your-gpu-operator-namespace --show-labels
kubectl get pods -n your-gpu-operator-namespace --show-labels

# If targets are down:
# 1. Test direct access to metrics endpoints
kubectl port-forward -n your-gpu-operator-namespace svc/nvidia-dcgm-exporter 9400:9400 &
curl -s http://localhost:9400/metrics | head -10
kill %1

# 2. Check pod/service status
kubectl get pods -n your-gpu-operator-namespace
kubectl get services -n your-gpu-operator-namespace

# For ServiceMonitor/PodMonitor issues:
# 1. Check Prometheus Operator logs
kubectl logs -n your-monitoring-namespace deployment/prometheus-operator-kube-p-operator | tail -50

# 2. Verify monitor discovery
kubectl get prometheus -n your-monitoring-namespace -o yaml | grep -A 5 -B 5 "serviceMonitorSelector"

# 3. Check monitor status
kubectl get servicemonitors-A
```

## Configuration Customization

### Namespace Adjustments

Update the namespace configurations to match your environment:

- **GPU Operator Namespace**: Change `your-gpu-operator-namespace` to your actual GPU operator namespace
- **nvidia-dcgm-exporter Namespace**: Add specific namespace targeting if your nvidia-dcgm-exporter workloads are in specific namespaces
- **Monitoring Namespace**: Change `your-monitoring-namespace` to where your Prometheus is deployed


### Scrape Interval Adjustments

- **GPU metrics**: Default is 1s for high-resolution monitoring, but you can increase to 5s or 10s if needed
- **nvidia-dcgm-exporter metrics**: Default uses global interval, but you can specify a custom interval

## Common Issues and Solutions

### Issue 1: "Prometheus not reloading after applying CRD"

**Symptoms**: 
- Applied `Prometheus` CRD resource
- Configuration doesn't appear in Prometheus
- No new targets discovered

**Root Cause**: Prometheus Operator not installed

**Solution**:
1. Install Prometheus Operator (see Step 1 in Method 1)
2. Add required selectors to Prometheus resource:
   ```yaml
   spec:
     serviceMonitorSelector: {}
     podMonitorSelector: {}
     ruleSelector: {}
   ```
3. Create proper RBAC permissions
4. Wait for StatefulSet creation

### Issue 2: "No targets discovered"

**Symptoms**:
- Prometheus running
- Configuration loaded
- No targets showing up

**Solutions**:
1. **Check RBAC permissions**: Ensure Prometheus service account can list endpoints/pods/services
2. **Verify namespace names**: Check that namespace names in configs match actual deployments
3. **Check label selectors**: For ServiceMonitor/PodMonitor, verify label selectors match your services/pods

### Issue 3: "Targets down/unhealthy"

**Symptoms**:
- Targets discovered but showing as "DOWN"
- Last scrape errors in Prometheus

**Solutions**:
1. **Test direct access**: Use `kubectl port-forward` to test if metrics endpoints are accessible
2. **Check network policies**: Verify no network policies are blocking access
3. **Verify metrics path**: Ensure the `/metrics` path is correct for your exporters

### Issue 4: "ServiceMonitor not working"

**Symptoms**:
- Resources created successfully
- No targets discovered from monitors

**Solutions**:
1. **Check Prometheus Operator logs**: Look for errors processing monitors
2. **Verify Prometheus configuration**: Ensure Prometheus is configured to discover monitors
3. **Check label selectors**: Verify selectors match your services/pods

## Verification

### Check Prometheus Targets

1. Access your Prometheus UI via port-forward:
   ```bash
   kubectl port-forward -n your-monitoring-namespace prometheus-your-prometheus-0 9090:9090
   ```
2. Go to `http://localhost:9090/targets`
3. Look for the `nvidia-dcgm-exporter` and `gpu-metrics` jobs (or ServiceMonitor/PodMonitor targets)
4. Verify they show as "UP" with discovered endpoints

### Verify Metrics Collection

Query these sample metrics to confirm data collection:

```promql
# GPU utilization
DCGM_FI_DEV_SM_CLOCK

# GPU memory usage
DCGM_FI_DEV_FB_USED

# nvidia-dcgm-exporter request metrics (example)
nvidia-dcgm-exporter_request_duration_seconds

# Node information with GPU context
up{job="gpu-metrics"}
```

## Support

For additional assistance with EGS monitoring integration:

1. Check the EGS documentation for specific metric definitions
2. Verify your GPU operator installation follows EGS requirements
3. Ensure your nvidia-dcgm-exporter workloads are properly instrumented for metrics export
4. Review Prometheus Operator documentation for CRD-specific issues

## Notes

- **Prometheus Operator is REQUIRED** for Methods 1 (CRD approach), 2, and 3
- The GPU metrics scrape interval of 1s provides high-resolution monitoring but may increase storage requirements
- nvidia-dcgm-exporter metrics discovery across all namespaces provides comprehensive coverage but may need filtering in large clusters
- Regular review of discovered targets is recommended to ensure optimal performance
- Always test RBAC permissions before deploying to production
- Consider network policies and security implications when allowing cross-namespace monitoring 
