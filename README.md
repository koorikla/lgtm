# Grafana Stack Umbrella Chart (POC)

This umbrella chart deploys a full Grafana observability stack tailored for a Proof of Concept (POC) environment.

## Components

- **Mimir**: Scalable Prometheus-compatible metrics storage.
- **Loki**: Log aggregation system (Monolithic mode).
- **Tempo**: Distributed tracing backend (Monolithic mode).
- **Grafana**: Observability dashboard.
- **Alloy**: OpenTelemetry Collector and Prometheus Agent.
- **MinIO**: S3-compatible object storage (via Bitnami chart).

## Prerequisites for local development

- **Container Runtime**: Docker or Podman.
- **Kind**: For creating local clusters.
- **Kubernetes Cluster**: (e.g., Kind, k3d, or a managed cluster).
- **Helm**: v3+.
- **Kubectl**: 
- **Make**: For automation commands.

## Getting Started

### 1. Create a Cluster (Optional)
If you don't have a cluster, create a local Kind cluster:
```bash
make cluster
```

### 2. Install the Stack
Deploy the stack to the `monitoring` namespace:
```bash
make install
```

### 3. Verify Deployment
Run the automated verification script:
```bash
make test
```
This script will:
- Wait for pods to be ready.
- Port-forward Grafana (localhost:3000).
- Check datasource connectivity.
- Ingest and query sample metrics and logs.

## Accessing Grafana

- **URL**: http://localhost:3000
- **User**: `admin`
- **Password**: `admin`

## Telemetry Pipelines (Alloy)

Alloy is pre-configured to collect:

- **Metrics**:
  - **Annotation-based**: Set `prometheus.io/scrape: "true"` on your pods.
  - **Operator-based**: Uses `ServiceMonitor` and `PodMonitor` CRDs.
- **Logs**:
  - Automatically collects logs from all pods in the cluster, enriched with Kubernetes metadata (`namespace`, `pod`, `container`, `app`).
- **Traces**:
  - Accepts OTLP traces via gRPC on `grafana-stack-alloy:4317`.

## Troubleshooting

### "Volume not found" or MinIO errors
The stack is configured with **ephemeral usage (non-persistent)** for the POC. MinIO runs in standalone mode without persistent volumes.
- **Data Loss**: All data (logs, metrics, traces) is lost when the cluster is deleted or the MinIO pod restarts.
- **Buckets**: Buckets (`mimir-blocks`, `loki-data`, etc.) are created automatically on startup by the `buckets` configuration in `values.yaml`.

### "No Data" in Grafana
- **Availability**: Verify Alloy is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy`.
- **Pipeline Status**: Check Alloy logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`.
- **Labels**: Ensure your pods have the correct annotations or labels for discovery.
