# EGS Controller Prerequisites

This document outlines the prerequisites required for installing and operating the EGS (Enterprise GPU Slicing) Controller in your Kubernetes cluster.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
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

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.8.0+
- PV provisioner support in the underlying infrastructure
- Access to container registry with EGS images
- Proper RBAC permissions for monitoring and database operations

## 1. Prometheus Installation

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
- ServiceMonitor and PodMonitor CRDs
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
  namespace: egs-monitoring  # NAMESPACE: Change this to your monitoring namespace
  labels:
    app.kubernetes.io/instance: kube-prometheus-stack  # PROMETHEUS_INSTANCE: Change to your Prometheus instance
    release: prometheus  # PROMETHEUS_RELEASE: Change to your Prometheus release name
spec:
  endpoints:
    - interval: 30s  # SCRAPE_INTERVAL: How often to collect metrics (30s, 15s, 60s, etc.)
      port: metrics  # Port name where metrics are exposed (port 18080)
      path: /metrics  # METRICS_PATH: Path where metrics are exposed (default: /metrics)
      scrapeTimeout: 10s  # SCRAPE_TIMEOUT: Maximum time to wait for metrics response
      scheme: http  # SCHEME: Use http for port 18080
  namespaceSelector:
    matchNames:
      - kubeslice-controller  # KUBESLICE_CONTROLLER_NAMESPACE: Namespace where controller is deployed
  selector:
    matchLabels:
      control-plane: controller-manager  # Matches the service selector
```

### 2.2 Pod Monitor Configuration

Create a PodMonitor for direct pod metrics collection:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: kubeslice-controller-manager-pod-monitor
  namespace: egs-monitoring  # NAMESPACE: Change this to your monitoring namespace
  labels:
    app.kubernetes.io/instance: kube-prometheus-stack  # PROMETHEUS_INSTANCE: Change to your Prometheus instance
    release: prometheus  # PROMETHEUS_RELEASE: Change to your Prometheus release name
spec:
  selector:
    matchLabels:
      control-plane: controller-manager  # Matches the pod labels
  namespaceSelector:
    matchNames:
      - kubeslice-controller  # KUBESLICE_CONTROLLER_NAMESPACE: Namespace where controller is deployed
  podMetricsEndpoints:
    - interval: 30s  # SCRAPE_INTERVAL: How often to collect metrics (30s, 15s, 60s, etc.)
      port: "18080"  # PORT: Direct port number as string (matches prometheus.io/port annotation)
      path: /metrics  # METRICS_PATH: Path where metrics are exposed (default: /metrics)
      scrapeTimeout: 10s  # SCRAPE_TIMEOUT: Maximum time to wait for metrics response
      scheme: http  # SCHEME: Use http for direct pod access
```

### 2.3 Apply Monitoring Configuration

```bash
# Apply the ServiceMonitor
kubectl apply -f servicemonitor.yaml

# Apply the PodMonitor
kubectl apply -f podmonitor.yaml

# Verify the monitors are created
kubectl get servicemonitor -n egs-monitoring
kubectl get podmonitor -n egs-monitoring
```

### 2.4 Verify Metrics Scraping

```bash
# Check if metrics are being scraped in Prometheus
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring

# Open http://localhost:9090 in your browser
# Go to Status -> Targets to see if the EGS Controller targets are UP
```

## 3. PostgreSQL Database Setup

The EGS Controller uses PostgreSQL for KubeTally functionality, which handles chargeback and metrics storage. You have two options for PostgreSQL deployment.

### Option A: Internal PostgreSQL Deployment (Recommended for Development/Testing)

#### 3.1 Install PostgreSQL using Helm

```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create namespace for PostgreSQL
kubectl create namespace egs-postgresql

# Install PostgreSQL
helm install postgresql bitnami/postgresql \
  --namespace egs-postgresql \
  --set auth.postgresPassword=your_password \
  --set auth.database=kubetally \
  --set primary.persistence.enabled=true \
  --set primary.persistence.size=8Gi
```

#### 3.2 Configure EGS Controller for Internal PostgreSQL

Update your EGS Controller values.yaml:

```yaml
global:
  kubeTally:
    enabled: true
    postgresSecretName: kubetally-db-credentials
    # PostgreSQL connection details will be retrieved from the secret
```

#### 3.3 Create Database Credentials Secret

```bash
# Get PostgreSQL credentials
export POSTGRES_PASSWORD=$(kubectl get secret --namespace egs-postgresql postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
export POSTGRES_HOST="postgresql.egs-postgresql.svc.cluster.local"
export POSTGRES_PORT="5432"
export POSTGRES_DB="kubetally"

# Create secret for EGS Controller
kubectl create secret generic kubetally-db-credentials \
  --from-literal=postgres-addr=$POSTGRES_HOST \
  --from-literal=postgres-port=$POSTGRES_PORT \
  --from-literal=postgres-user=postgres \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  --from-literal=postgres-db=$POSTGRES_DB \
  --from-literal=postgres-sslmode=require \
  -n kubeslice-controller
```

### Option B: External PostgreSQL Connection

#### 3.1 External PostgreSQL Requirements

- PostgreSQL 12+ with SSL support
- Database named `kubetally`
- User with appropriate permissions
- Network access from Kubernetes cluster

#### 3.2 Configure EGS Controller for External PostgreSQL

Update your EGS Controller values.yaml:

```yaml
global:
  kubeTally:
    enabled: true
    postgresSecretName: kubetally-db-credentials
    # Optional: You can specify connection details directly
    # postgresAddr: your-postgres-host
    # postgresPort: 5432
    # postgresUser: your-username
    # postgresPassword: your-password
    # postgresDB: kubetally
    # postgresSslmode: require
```

#### 3.3 Create External Database Secret

```bash
kubectl create secret generic kubetally-db-credentials \
  --from-literal=postgres-addr=your-external-postgres-host \
  --from-literal=postgres-port=5432 \
  --from-literal=postgres-user=your-username \
  --from-literal=postgres-password=your-password \
  --from-literal=postgres-db=kubetally \
  --from-literal=postgres-sslmode=require \
  -n kubeslice-controller
```

### 3.4 Database Schema

The EGS Controller will automatically create the required database schema when it starts. Ensure the database user has the following permissions:

```sql
-- Connect to your PostgreSQL instance
\c kubetally

-- Grant necessary permissions
GRANT CREATE ON DATABASE kubetally TO your_username;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_username;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_username;
```

## 4. Verification Steps

### 4.1 Verify Prometheus Configuration

```bash
# Check if ServiceMonitor and PodMonitor are created
kubectl get servicemonitor -n egs-monitoring
kubectl get podmonitor -n egs-monitoring

# Check Prometheus targets
kubectl port-forward svc/prometheus-operated 9090:9090 -n egs-monitoring
# Visit http://localhost:9090/targets
```

### 4.2 Verify PostgreSQL Connection

```bash
# Test internal PostgreSQL connection
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --namespace egs-postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql --host postgresql -U postgres -d kubetally -p 5432

# Test external PostgreSQL connection (if applicable)
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=your_password" \
  --command -- psql --host your-external-host -U your-username -d kubetally -p 5432
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
- Verify ServiceMonitor/PodMonitor labels match Prometheus configuration
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

## Additional Resources

- [Kube-Prometheus-Stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PostgreSQL Helm Chart Documentation](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [EGS Controller Values Reference](charts/kubeslice-controller-egs/values.yaml)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)

## Support

For additional support or questions regarding EGS Controller prerequisites, please refer to:
- EGS Documentation: [docs.avesha.io](https://docs.avesha.io)
- GitHub Issues: [EGS Repository](https://github.com/kubeslice/egs)
- Community Support: [KubeSlice Community](https://kubeslice.io/community)
