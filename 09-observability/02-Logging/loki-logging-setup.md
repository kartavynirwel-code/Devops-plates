# Loki — Centralized Logging Setup

## What is Loki

Loki is a log aggregation system built by Grafana Labs. Unlike Elasticsearch, it does **not** index full log content — it only indexes metadata (labels), and log content itself is stored compressed in object storage / disk. This makes it far cheaper to run than the ELK stack for the same log volume.

**Core components:**
- **Loki** — stores logs and answers LogQL queries.
- **Promtail** (or **Grafana Alloy** in newer setups) — the agent that runs on each node, tails log files/container stdout, attaches labels (pod name, namespace, app), and pushes to Loki.
- **Grafana** — the query/visualization layer (same Grafana already used for Prometheus).

---

## Prerequisites

- A running Kubernetes cluster (K3s / EKS) with `kubectl` access.
- Helm 3 installed.
- Grafana already deployed (via `kube-prometheus-stack` or standalone).

---

## Step 1: Add Helm Repo

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## Step 2: Create Namespace

```bash
kubectl create namespace logging
```

---

## Step 3: Install Loki (Single Binary Mode — good for learning/small clusters)

Create `loki-values.yaml`:

```yaml
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  auth_enabled: false

singleBinary:
  replicas: 1

# Disable components not needed in single-binary/monolithic mode
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
```

Install:

```bash
helm install loki grafana/loki -n logging -f loki-values.yaml
```

Verify:

```bash
kubectl get pods -n logging
```

---

## Step 4: Install Promtail (Log Shipping Agent)

Promtail runs as a **DaemonSet** — one pod per node — so it can read container logs from every node's filesystem (`/var/log/pods`).

Create `promtail-values.yaml`:

```yaml
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push
```

Install:

```bash
helm install promtail grafana/promtail -n logging -f promtail-values.yaml
```

Verify:

```bash
kubectl get pods -n logging -l app.kubernetes.io/name=promtail
```

Each Promtail pod should show `Running` — one per cluster node.

---

## Step 5: Add Loki as a Data Source in Grafana

1. Open Grafana → **Connections → Data Sources → Add data source**.
2. Choose **Loki**.
3. Set URL: `http://loki.logging.svc.cluster.local:3100`
4. Click **Save & Test** — should show "Data source connected".

---

## Step 6: Query Logs with LogQL

Go to **Explore** in Grafana, select the Loki data source, and try:

```logql
{namespace="default", app="devhub-backend"}
```

Filter by log content:

```logql
{namespace="default", app="devhub-backend"} |= "ERROR"
```

Count error rate over time:

```logql
sum(rate({namespace="default", app="devhub-backend"} |= "ERROR" [5m]))
```

---

## Step 7 (Optional): Structured Logging from Spring Boot

For better label extraction, configure Spring Boot to output **JSON logs** (via Logback JSON encoder) instead of plain text. Promtail can then parse fields like `level`, `traceId`, `message` as separate labels using a `pipeline_stages` config with `json` and `labels` stages.

Example Promtail pipeline stage (add to `promtail-values.yaml` under `config.snippets.pipelineStages`):

```yaml
config:
  snippets:
    pipelineStages:
      - json:
          expressions:
            level: level
            message: message
      - labels:
          level:
```

---

## Common Issues

| Issue | Cause | Fix |
|---|---|---|
| Promtail pod CrashLoopBackOff | Wrong Loki push URL | Verify service name/namespace: `loki.logging.svc.cluster.local:3100` |
| No logs showing in Grafana | Labels don't match query | Check actual labels via `{job=~".+"}` broad query first |
| Loki pod pending | No PVC / storage class issue | Check `kubectl describe pvc -n logging` |

---

## Why It Matters (Interview Angle)

Loki's design principle — **"log everything, index only labels"** — is the key differentiator vs Elasticsearch (which indexes full text). This makes Loki significantly cheaper at scale, at the cost of full-text search speed. Being able to explain this trade-off, and the Promtail → Loki → Grafana pipeline (agent → storage → query UI), is a common DevOps/SRE interview checkpoint.
