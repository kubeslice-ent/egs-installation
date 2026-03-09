# EGS metrics pipeline (bundled in this repo)

The EGS charts in this repository (`charts/kubeslice-controller-egs`, `charts/kubeslice-worker-egs`, `charts/kubeslice-ui-egs`) include the **full metrics pipeline**. They are synced from **dev-charts-ent-egs** and provide:

- **Controller:** EGS metrics-ingestion (DCGM/Jetson → EGS_* transformation), with a ServiceMonitor for Prometheus.
- **Worker:** Metrics-agent (scrapes worker Prometheus, pushes to controller), Jetson ServiceMonitor, and jetson-egs-stats-exporter (DaemonSet + Service + ServiceMonitor).

Use the standard installer and scripts in this repo; enable the pipeline by adding the inline values below to your `egs-installer-config.yaml`.

---

## Enabling the metrics pipeline

### 1. Controller cluster

**Prerequisites:** Prometheus (e.g. kube-prometheus-stack) in the controller cluster in a namespace that discovers ServiceMonitors (e.g. `egs-monitoring`).

In `egs-installer-config.yaml`, under `kubeslice_controller_egs.inline_values`, ensure:

```yaml
kubeslice_controller_egs:
  inline_values:
    global:
      imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems
      # ... kubeTally, postgres, prometheusUrl, etc. ...
    serviceMonitor:
      enabled: true
      namespace: egs-monitoring
    # Enable EGS metrics ingestion (DCGM/Jetson -> EGS_* transformation)
    egs:
      metricsIngestion:
        enabled: true
```

When both `egs.metricsIngestion.enabled` and `serviceMonitor.enabled` are true, the controller chart will:

- Deploy **egs-metrics-ingestion** (Deployment + Service) in the controller namespace.
- Create a **ServiceMonitor** for egs-metrics-ingestion in `egs-monitoring` so Prometheus scrapes job `egs-metrics-ingestion`.

Transformation config (DCGM + Jetson → EGS_*) is bundled in the chart; no extra manifests are required.

---

### 2. Worker cluster

**Prerequisites:** Prometheus in the worker cluster (e.g. `egs-monitoring`) that discovers ServiceMonitors. For DCGM: GPU Operator. For Jetson: enable jetson-egs-stats-exporter and/or jetson ServiceMonitor as below.

In `egs-installer-config.yaml`, under each entry in `kubeslice_worker_egs`, add to `inline_values`:

```yaml
kubeslice_worker_egs:
  - name: "worker-1"
    inline_values:
      global:
        imageRegistry: harbor.saas1.smart-scaler.io/avesha/aveshasystems
      monitoring:
        podMonitor:
          enabled: true
          namespace: egs-monitoring
        jetsonServiceMonitor:
          enabled: true
          namespace: egs-monitoring
          releaseLabel: prometheus
      # Metrics agent: scrapes worker Prometheus, pushes to controller egs-metrics-ingestion
      metricsAgent:
        enabled: true
        prometheus:
          endpoint: "http://prometheus-kube-prometheus-prometheus.egs-monitoring.svc.cluster.local:9090"
        ingestion:
          endpoint: "http://egs-metrics-ingestion.kubeslice-controller.svc.cluster.local:8080"
      # Jetson EGS stats exporter (DaemonSet on Jetson/arm64 nodes)
      jetsonEgsStatsExporter:
        enabled: true
```

- **metricsAgent:** When enabled, runs in the worker cluster, scrapes the worker Prometheus, and pushes to egs-metrics-ingestion in the controller cluster.
- **jetsonServiceMonitor:** When enabled, creates a ServiceMonitor for services with `app: jetson-gpu-exporter` (if you run that exporter separately).
- **jetsonEgsStatsExporter:** When enabled, deploys the jetson-egs-stats-exporter DaemonSet (image `jetson-python-exporter:1.7`) on arm64 nodes and its ServiceMonitor so Prometheus scrapes it.

Adjust Prometheus/ingestion endpoints if your namespaces or cluster topology differ (e.g. multi-cluster).

---

## End-to-end flow

1. **Worker cluster:** Prometheus scrapes DCGM (GPU Operator) and/or Jetson exporters (jetson-gpu-exporter, jetson-egs-stats-exporter) via ServiceMonitors/PodMonitors.
2. **Metrics-agent (worker):** Scrapes the worker Prometheus and pushes metrics to **egs-metrics-ingestion** in the controller cluster.
3. **Controller cluster:** **egs-metrics-ingestion** receives metrics, applies the bundled transformation (DCGM/Jetson → EGS_*), and exposes them at `/default/metrics`.
4. **Controller cluster:** Prometheus scrapes egs-metrics-ingestion via the ServiceMonitor (job `egs-metrics-ingestion`).
5. **UI / api-gw:** Query the same Prometheus (controller) for EGS_* metrics with job `egs-metrics-ingestion`.

---

## Prerequisites summary

| Location    | Component                          | Purpose |
|------------|-------------------------------------|--------|
| Controller | Prometheus                          | In a namespace that discovers ServiceMonitors (e.g. egs-monitoring). |
| Controller | ServiceMonitor (egs-metrics-ingestion) | Rendered by controller chart when enabled; no extra manifest. |
| Worker     | Prometheus                          | Discovers ServiceMonitors in egs-monitoring (or your configured namespace). |
| Worker     | ServiceMonitor (Jetson / jetson-egs-stats-exporter) | Rendered by worker chart when the corresponding options are enabled. |

---

## Re-syncing charts from dev-charts-ent-egs

To refresh the bundled EGS charts from **dev-charts-ent-egs**:

```bash
# From repo root (egs-installation)
rm -rf charts/kubeslice-controller-egs charts/kubeslice-worker-egs charts/kubeslice-ui-egs
cp -r /path/to/dev-charts-ent-egs/charts/kubeslice-controller-egs \
      /path/to/dev-charts-ent-egs/charts/kubeslice-worker-egs \
      /path/to/dev-charts-ent-egs/charts/kubeslice-ui-egs \
      charts/
```

Replace `/path/to/dev-charts-ent-egs` with the actual path to the dev-charts-ent-egs repository.
