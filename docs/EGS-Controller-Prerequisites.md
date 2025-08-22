# EGS Controller Prerequisites

This document outlines the prerequisites required for installing and operating the EGS (Enterprise GPU Slicing) Controller in your Kubernetes cluster.

## Table of Contents

- [Overview](#overview)
- [🚀 Quick Start Workflow](#-quick-start-workflow)
- [Prerequisites](#prerequisites)
- [EGS Installer Configuration](#egs-installer-configuration) *(Option 1)*
- [Manual Installation Steps](#manual-installation-steps-option-2) *(Option 2)*
  - [1. Prometheus Installation](#1-prometheus-installation)
  - [2. Monitoring Configuration](#2-monitoring-configuration)
  - [3. PostgreSQL Database Setup](#3-postgresql-database-setup)
- [4. Verification Steps](#4-verification-steps)
- [5. Troubleshooting](#5-troubleshooting)

## Overview

The EGS Controller requires several components to be properly configured before installation:
- A monitoring stack (preferably kube-prometheus-stack) for metrics collection
- Proper monitoring configuration to scrape EGS Controller metrics
- PostgreSQL database for KubeTally functionality (chargeback and metrics)

## 🚀 Quick Start Workflow

**Choose ONE approach based on your setup:**

### **🔄 Option 1: Use EGS Prerequisites Script (Recommended for new installations)**
- **What it does:** Automatically installs and configures all required components
- **Best for:** New installations, single clusters, simplified setup
- **Time to complete:** ~10-15 minutes
- **Skip to:** [EGS Installer Configuration](#egs-installer-configuration) → [Verification Steps](#4-verification-steps)

### **🌐 Option 2: Use Existing Infrastructure (Advanced)**
- **What it does:** Integrates with your existing Prometheus, PostgreSQL, and monitoring setup
- **Best for:** Production environments, multi-cluster setups, existing monitoring infrastructure
- **Time to complete:** ~20-30 minutes (depending on existing setup complexity)
- **Skip to:** [Manual Installation Steps](#manual-installation-steps-option-2)

**⚠️ Important:** Choose only ONE approach - do NOT use both simultaneously to avoid conflicts.

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.8.0+
- PV provisioner support in the underlying infrastructure
- Access to container registry with EGS images
- Proper RBAC permissions for monitoring and database operations

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

  - name: "postgresql"
    skip_installation: false
    use_global_kubeconfig: true
    namespace: "kt-postgresql"
    release: "kt-postgresql"
    chart: "postgresql"
    repo_url: "oci://registry-1.docker.io/bitnamicharts/postgresql"
    version: "16.2.1"
    specific_use_local_charts: true
    inline_values:
      auth:
        postgresPassword: "postgres"
        username: "postgres"
        password: "postgres"
        database: "postgres"
      primary:
        persistence:
          enabled: false
          size: 10Gi
    helm_flags: "--wait --debug"
    verify_install: true
    verify_install_timeout: 600
    skip_on_verify_fail: false
```

Then run the prerequisites installer:

```bash
./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
```

This will automatically install:
- **Prometheus Stack** (v45.0.0) in the `egs-monitoring` namespace
- **PostgreSQL** (v16.2.1) in the `kt-postgresql` namespace

---

## Manual Installation Steps (Option 2)

> **📝 Note:** This section is for **Option 2 (Existing Infrastructure)** users only. If you used the EGS Prerequisites Script (Option 1), skip to [Verification Steps](#4-verification-steps).

**📋 Reference:** For configuration examples and templates, see [egs-installer-config.yaml](../egs-installer-config.yaml)

### **📋 Manual Installation Workflow:**
1. **[Prometheus Installation](#1-prometheus-installation)** - Set up monitoring stack
2. **[Monitoring Configuration](#2-monitoring-configuration)** - Configure metrics scraping
3. **[PostgreSQL Database Setup](#3-postgresql-database-setup)** - Set up database and credentials
4. **[Verification Steps](#4-verification-steps)** - Verify all components are working

### 1. Prometheus Installation

### Option A: Kube-Prometheus-Stack (Recommended)

The kube-prometheus-stack is the recommended monitoring solution as it provides a complete monitoring stack with Prometheus, Grafana, and AlertManager.

#### 1.1 Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

#### 1.2 Install Kube-Prometheus-Stack

```bash
# Create monitoring namespace
kubectl create namespace egs-monitoring

# Install the stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace egs-monitoring \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

#### 1.3 Verify Installation

```bash
# Check if all pods are running
kubectl get pods -n egs-monitoring

# Check Prometheus service
kubectl get svc -n egs-monitoring | grep prometheus
```

### Option B: Manual Prometheus Installation

If you prefer to install Prometheus manually, ensure you have:
- Prometheus Operator
- ServiceMonitor CRDs
- Proper RBAC configuration

## 2. Monitoring Configuration

The EGS Controller exposes metrics on port 18080 and requires proper monitoring configuration to be scraped by Prometheus.

### 2.1 Service Monitor Configuration

Create a ServiceMonitor to scrape metrics from the EGS Controller service:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kubeslice-controller-manager-monitor
  namespace: egs-monitoring # NAMESPACE: Change this to your monitoring namespace
  labels:
    app.kubernetes.io/instance: kube-prometheus-stack  # PROMETHEUS_INSTANCE: Change to your Prometheus instance
    release: prometheus  # PROMETHEUS_RELEASE: Change to your Prometheus release name
spec:
  selector:
    matchLabels:
      control-plane: controller-manager  # Matches the service selector
  namespaceSelector:
    matchNames:
      - kubeslice-controller  # KUBESLICE_CONTROLLER_NAMESPACE: Namespace where controller is deployed
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

### 2.2 Apply Monitoring Configuration

```bash
# Apply the ServiceMonitor
kubectl apply -f servicemonitor.yaml

# Verify the monitors are created
kubectl get servicemonitor -n egs-monitoring
```

### 2.3 Verify Metrics Scraping

```bash
# Check if metrics are being scraped in Prometheus
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring

# Open http://localhost:9090 in your browser
# Go to Status -> Targets to see if the EGS Controller targets are UP
```

### 2.4 Universal Metrics Verification Steps

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
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="kubeslice-controller-manager-monitor" or .labels.job=="kubeslice-controller-manager-pod-monitor")'
kill %1
```

### 2.5 EGS Controller Metrics Verification

```bash
# Port forward once for all tests
kubectl port-forward -n egs-monitoring prometheus-operated 9090:9090 &

# 1. Check if EGS Controller metrics are being collected
curl -s "http://localhost:9090/api/v1/query?query=up{job=~\"kubeslice.*controller.*\"}" | jq '.data.result | length'

# 2. Verify namespace labeling for EGS Controller metrics
curl -s "http://localhost:9090/api/v1/query?query=up{job=~\"kubeslice.*controller.*\"}" | jq '.data.result[0].metric.kubernetes_namespace'

# 3. Check pod labeling for EGS Controller metrics
curl -s "http://localhost:9090/api/v1/query?query=up{job=~\"kubeslice.*controller.*\"}" | jq '.data.result[0].metric.pod_name'

# 4. Verify scrape intervals
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("kubeslice")) | .scrapeInterval'

# 5. Check specific EGS Controller metrics
curl -s "http://localhost:9090/api/v1/query?query=process_cpu_seconds_total{job=~\"kubeslice.*controller.*\"}" | jq '.data.result | length'

# Close port forward
kill %1
```

## 3. PostgreSQL Database Setup

> **📝 Note:** This section is for **Option 2 (Existing Infrastructure)** users only. If you used the EGS Prerequisites Script (Option 1), skip to [Verification Steps](#4-verification-steps).

The EGS Controller uses PostgreSQL for KubeTally functionality, which handles chargeback and metrics storage. You have two options for PostgreSQL deployment.

### Option A: Internal PostgreSQL Deployment (Recommended for Development/Testing)

#### 3.1 Install PostgreSQL using Helm

```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create namespace for PostgreSQL
kubectl create namespace kt-postgresql

# Install PostgreSQL using the latest configuration
helm install kt-postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace kt-postgresql \
  --version 16.2.1 \
  --set auth.postgresPassword=postgres \
  --set auth.username=postgres \
  --set auth.database=postgres \
  --set primary.persistence.enabled=false \
  --set primary.persistence.size=10Gi
```

#### 3.2 Configure EGS Controller for Internal PostgreSQL

Update your EGS Controller configuration in `egs-installer-config.yaml`:

```yaml
kubeslice_controller_egs:
  inline_values:
    global:
      kubeTally:
        enabled: true
        postgresSecretName: kubetally-db-credentials
        postgresAddr: "kt-postgresql.kt-postgresql.svc.cluster.local"
        postgresPort: 5432
        postgresUser: "postgres"
        postgresPassword: "postgres"
        postgresDB: "postgres"
        postgresSslmode: disable
        prometheusUrl: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
```

#### 3.3 Create Database Credentials Secret

```bash
# Get PostgreSQL credentials
export POSTGRES_PASSWORD=$(kubectl get secret --namespace kt-postgresql kt-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
export POSTGRES_HOST="kt-postgresql.kt-postgresql.svc.cluster.local"
export POSTGRES_PORT="5432"
export POSTGRES_DB="postgres"

# Create secret for EGS Controller
kubectl create secret generic kubetally-db-credentials \
  --from-literal=postgres-addr=$POSTGRES_HOST \
  --from-literal=postgres-port=$POSTGRES_PORT \
  --from-literal=postgres-user=postgres \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  --from-literal=postgres-db=$POSTGRES_DB \
  --from-literal=postgres-sslmode=disable \
  -n kubeslice-controller
```

### Option B: External PostgreSQL Connection

#### 3.1 External PostgreSQL Requirements

- PostgreSQL 12+ with SSL support
- Database named `kubetally`
- User with appropriate permissions
- Network access from Kubernetes cluster

#### 3.2 Configure EGS Controller for External PostgreSQL

Update your EGS Controller configuration in `egs-installer-config.yaml`:

```yaml
kubeslice_controller_egs:
  inline_values:
    global:
      kubeTally:
        enabled: true
        postgresSecretName: kubetally-db-credentials
        # Leave these empty if using external secret
        postgresAddr: ""
        postgresPort: 5432
        postgresUser: ""
        postgresPassword: ""
        postgresDB: ""
        postgresSslmode: disable
        prometheusUrl: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
```

#### 3.3 Create External Database Secret

```bash
kubectl create secret generic kubetally-db-credentials \
  --from-literal=postgres-addr=your-external-postgres-host \
  --from-literal=postgres-port=5432 \
  --from-literal=postgres-user=your-username \
  --from-literal=postgres-password=your-password \
  --from-literal=postgres-db=your-database-name \
  --from-literal=postgres-sslmode=require \
  -n kubeslice-controller
```

### 3.4 Using EGS Installer for PostgreSQL

The EGS installer can automatically deploy PostgreSQL as part of the prerequisites installation. Configure your `egs-installer-config.yaml`:

```yaml
# Enable additional applications installation
enable_install_additional_apps: true

# PostgreSQL configuration
additional_apps:
  - name: "postgresql"
    skip_installation: false
    use_global_kubeconfig: true
    namespace: "kt-postgresql"
    release: "kt-postgresql"
    chart: "postgresql"
    repo_url: "oci://registry-1.docker.io/bitnamicharts/postgresql"
    version: "16.2.1"
    specific_use_local_charts: true
    inline_values:
      auth:
        postgresPassword: "postgres"
        username: "postgres"
        password: "postgres"
        database: "postgres"
      primary:
        persistence:
          enabled: false
          size: 10Gi
    helm_flags: "--wait --debug"
    verify_install: true
    verify_install_timeout: 600
    skip_on_verify_fail: false
```

Then run the prerequisites installer:

```bash
./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml
```

## 4. Verification Steps

### 4.1 Verify Prometheus Configuration

```bash
# Check if ServiceMonitor are created
kubectl get servicemonitor -n egs-monitoring


# Check Prometheus targets
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring
# Visit http://localhost:9090/targets
```

### 4.2 Verify PostgreSQL Connection

```bash
# Test internal PostgreSQL connection
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --namespace kt-postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql --host kt-postgresql -U postgres -d postgres -p 5432

# Test external PostgreSQL connection (if applicable)
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=your_password" \
  --command -- psql --host your-external-host -U your-username -d your-database-name -p 5432
```

### 4.3 Verify EGS Controller Metrics

```bash
# Check if EGS Controller pods are running
kubectl get pods -n kubeslice-controller

# Test metrics endpoint
kubectl port-forward svc/kubeslice-controller-manager-service 18080:18080 -n kubeslice-controller
# Visit http://localhost:18080/metrics
```

## 5. Troubleshooting

### 5.1 Prometheus Issues

**Problem**: Metrics not being scraped
**Solution**: 
- Verify ServiceMonitor labels match Prometheus configuration
- Check if EGS Controller pods have proper annotations
- Ensure Prometheus has access to the EGS Controller namespace

**Problem**: Prometheus targets showing as DOWN
**Solution**:
- Check network policies
- Verify service endpoints
- Check if metrics port is accessible

### 5.2 PostgreSQL Issues

**Problem**: Connection refused
**Solution**:
- Verify PostgreSQL service is running
- Check network policies and firewall rules
- Verify connection credentials

**Problem**: Authentication failed
**Solution**:
- Check username/password in secret
- Verify database exists
- Check user permissions

### 5.3 EGS Controller Issues

**Problem**: Controller not starting
**Solution**:
- Check logs: `kubectl logs -f deployment/kubeslice-controller-manager -n kubeslice-controller`
- Verify all required secrets exist
- Check resource limits and requests

---

## Additional Resources

- [Kube-Prometheus-Stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PostgreSQL Helm Chart Documentation](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [EGS Controller Values Reference](charts/kubeslice-controller-egs/values.yaml)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)

