# Tempo — Distributed Tracing Setup

## What is Tempo

Tempo is Grafana Labs' distributed tracing backend. It stores **traces** — records of a single request's journey across multiple services, broken into **spans** (individual units of work, e.g., "HTTP call to payment-service", "DB query"). Like Loki, Tempo is cost-efficient because it only requires object storage/disk and doesn't need a separate indexing database — traces are found via **trace ID** lookup, and exemplars link metrics/logs to the exact trace.

**Core components:**
- **Tempo** — stores and serves trace data.
- **OpenTelemetry (OTel) Collector** or app-side OTel SDK — captures spans and exports them to Tempo.
- **Grafana** — visualizes traces (flame graphs / span timelines) and correlates with Loki logs and Prometheus metrics.

---

## Prerequisites

- Kubernetes cluster with `kubectl` + Helm 3.
- Grafana already deployed.
- Application built with Spring Boot (or any OpenTelemetry-supported stack).

---

## Step 1: Add Helm Repo

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## Step 2: Create Namespace

```bash
kubectl create namespace tracing
```

---

## Step 3: Install Tempo

Create `tempo-values.yaml`:

```yaml
tempo:
  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces

  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
```

Install:

```bash
helm install tempo grafana/tempo -n tracing -f tempo-values.yaml
```

Verify:

```bash
kubectl get pods -n tracing
```

---

## Step 4: Instrument the Spring Boot App

Add dependencies to `pom.xml` for Micrometer Tracing with OTLP export:

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>
```

In `application.yml`:

```yaml
management:
  tracing:
    sampling:
      probability: 1.0   # 100% sampling for dev/demo; lower in production
  otlp:
    tracing:
      endpoint: http://tempo.tracing.svc.cluster.local:4318/v1/traces
```

This auto-instruments incoming/outgoing HTTP calls and DB queries with trace context, and pushes spans to Tempo over OTLP.

---

## Step 5: Add Tempo as a Data Source in Grafana

1. Grafana → **Connections → Data Sources → Add data source**.
2. Choose **Tempo**.
3. Set URL: `http://tempo.tracing.svc.cluster.local:3200`
4. Under the Tempo data source settings, enable **"Trace to logs"** and link it to the Loki data source (so you can jump from a trace span directly to its logs).
5. Click **Save & Test**.

---

## Step 6: View Traces

1. Generate some traffic to the app (hit a few API endpoints).
2. In Grafana → **Explore** → select Tempo.
3. Search by **Trace ID** (get one from response headers `traceparent`, or from correlated logs if `traceId` is in your JSON log fields).
4. View the **flame graph** — shows total request time broken down span-by-span across services.

---

## Step 7 (Optional): Correlate Logs, Metrics, Traces

Standard observability practice — the "three pillars":

- **Logs (Loki)** tell you *what happened*.
- **Metrics (Prometheus)** tell you *how much / how often*.
- **Traces (Tempo)** tell you *where time was spent across services*.

If your Spring Boot JSON logs include `traceId` and `spanId` (Micrometer Tracing adds these automatically to the MDC), Grafana can jump between all three using that shared ID — this is the "exemplar" linking pattern.

---

## Common Issues

| Issue | Cause | Fix |
|---|---|---|
| No traces appearing | Wrong OTLP endpoint or port (4317 grpc vs 4318 http) | Match exporter protocol to the port used |
| Traces appear but broken across services | Missing trace context propagation between services | Ensure all services use the same tracing library/version and propagate `traceparent` header |
| High storage usage | 100% sampling in production | Lower `management.tracing.sampling.probability` (e.g., 0.1 = 10%) |

---

## Why It Matters (Interview Angle)

Tracing answers a question logs and metrics can't: **"which service in this microservices chain caused the 2-second delay?"** Explaining spans, trace context propagation, and sampling trade-offs (100% sampling gives full visibility but costs more storage/overhead) demonstrates real microservices observability understanding — a common gap area even among candidates who know Prometheus well.
