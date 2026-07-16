# Jaeger — Distributed Tracing Setup

## What is Jaeger

Jaeger is an open-source, end-to-end distributed tracing system for monitoring and troubleshooting microservices-based architectures. It traces the path a single request takes across multiple services and measures how long each step takes — helping pinpoint exactly where things slow down or break in a complex system.

## Why Use Jaeger

In a microservices architecture, one user request can touch many services. When something breaks, it's hard to know which service is actually at fault. Jaeger helps by:

- 🐢 **Identifying bottlenecks** — see where your application spends most of its time.
- 🔍 **Finding root causes of errors** — trace errors back to their source service.
- ⚡ **Optimizing performance** — understand and improve per-service latency.

---

## Core Concepts

- 🛤️ **Trace** — the full journey of a request across services; the end-to-end map of every stop it makes.
- 📏 **Span** — a single operation within a trace (e.g., an API call, a DB query), with a start time and duration.
- 🏷️ **Tags** — key-value metadata on a span (e.g., HTTP method, status code).
- 📝 **Logs** — event details captured inside a span (errors, checkpoints).
- 🔗 **Context Propagation** — trace info passed from service to service via headers, so spans across different services can be stitched into one trace.

---

## Architecture — Components

Jaeger is made up of several components:

| Component | Role |
|---|---|
| **Agent** | Collects traces from your application (often a sidecar or daemonset). |
| **Collector** | Receives traces from the agent, processes and validates them. |
| **Query** | Serves the UI for browsing/searching traces. |
| **Storage** | Persists trace data — commonly **Elasticsearch** (or Cassandra). |

> Note: unlike Tempo (object storage only, no separate index), Jaeger's default storage backend (Elasticsearch/Cassandra) needs its own cluster to run and maintain — this is the main operational cost difference between the two.

---

## Prerequisites

- Kubernetes cluster with `kubectl` + Helm 3.
- Elasticsearch already deployed (in a `logging` namespace, TLS-enabled) — Jaeger will use it as the storage backend.
- Application instrumented with OpenTelemetry libraries (e.g. `tracing.js` for Node services, or Micrometer Tracing for Spring Boot).

---

## Step 1: Instrument Your Code

Add tracing capability to each service using OpenTelemetry libraries/middleware for your language/framework. This is what generates and exports spans in the first place — nothing downstream works without this step.

---

## Step 2: Export the Elasticsearch CA Certificate

Retrieves the CA cert from the Elasticsearch master cert secret and decodes it to a local file:

```bash
kubectl get secret elasticsearch-master-certs -n logging -o jsonpath='{.data.ca\.crt}' | base64 --decode > ca-cert.pem
```

---

## Step 3: Create the Tracing Namespace

```bash
kubectl create ns tracing
```

---

## Step 4: Create a ConfigMap for Jaeger's TLS Certificate

```bash
kubectl create configmap jaeger-tls --from-file=ca-cert.pem -n tracing
```

---

## Step 5: Create a Secret for Elasticsearch TLS

```bash
kubectl create secret generic es-tls-secret --from-file=ca-cert.pem -n tracing
```

---

## Step 6: Add the Jaeger Helm Repository

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
```

---

## Step 7: Install Jaeger with Custom Values

Update the `password` field (and any related fields) in `jaeger-values.yaml` with your Elasticsearch password before installing.

> ⚠️ Don't hardcode the password directly in a values file committed to Git — pull it from a Secret/Vault reference instead, or at minimum keep `jaeger-values.yaml` out of version control if it contains the raw password.

```bash
helm install jaeger jaegertracing/jaeger -n tracing --values jaeger-values.yaml
```

---

## Step 8: Port-Forward the Jaeger Query Service

```bash
kubectl port-forward svc/jaeger-query 8080:80 -n tracing
```

Then open `http://localhost:8080` to access the Jaeger UI.

> Port-forward is fine for local access/demo. For production access, expose Jaeger Query via an Ingress (with auth in front of it) rather than leaving it on port-forward.

---

## Viewing Traces

1. Generate traffic against your instrumented services.
2. In the Jaeger UI, select a **service** from the dropdown, optionally filter by **operation**, **tags**, or **duration**.
3. Click a trace to view its **timeline/span view** — shows each span's duration and parent-child relationship across services.

Jaeger's search is form-based (service → operation → tags → duration filters), compared to Tempo's TraceQL where you write the filter as a query string directly.

---

## Common Issues

| Issue | Cause | Fix |
|---|---|---|
| Jaeger pods stuck in `CrashLoopBackOff` | Elasticsearch not reachable, or TLS cert mismatch | Verify ES is up in `logging` namespace and the CA cert Secret/ConfigMap match what's in `jaeger-values.yaml` |
| No traces showing in UI | Services not instrumented, or collector endpoint misconfigured | Confirm OTel exporter in each service points to the Jaeger collector endpoint |
| Traces broken across services | Context propagation headers not forwarded (e.g. through a proxy stripping headers) | Ensure `traceparent`/Jaeger headers pass through every hop, including gateways/proxies |
| High Elasticsearch storage/cost | No ILM (Index Lifecycle Management) policy on trace indices | Configure an ILM policy to roll over/delete old trace indices automatically |

---

## Clean Up

```bash
helm uninstall jaeger -n tracing
helm uninstall elasticsearch -n logging

# Also delete the PVC created for Elasticsearch manually
kubectl get pvc -n logging
kubectl delete pvc <pvc-name> -n logging

helm uninstall monitoring -n monitoring

kubectl delete -k kubernetes-manifest/
kubectl delete -k alerts-alertmanager-servicemonitor-manifest/

# Delete the cluster if it was created just for this exercise
eksctl delete cluster --name observability
```

---

## Why It Matters (Interview Angle)

Jaeger is a CNCF **graduated** project — one of the most mature, battle-tested tracing systems, widely used standalone (i.e., outside a Grafana-centric stack). Knowing its component breakdown (Agent → Collector → Query → Storage) and why it needs Elasticsearch/Cassandra for storage+indexing (vs Tempo's object-storage-only model) is a strong signal of understanding the trade-offs between mature-but-heavier vs lightweight-but-newer tracing backends — a common interview comparison point.
