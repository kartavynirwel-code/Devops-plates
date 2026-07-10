# Pyroscope — Continuous Profiling Setup

## What is Pyroscope

Pyroscope (now part of Grafana's observability stack, integrated as **Grafana Profiles**) is a **continuous profiling** tool. Where tracing tells you *which service* is slow and metrics tell you *how often*, profiling tells you **exactly which function/line of code** inside a single service is consuming CPU or memory at any point in time — visualized as a **flame graph**.

This is the "fourth pillar" of observability, alongside Logs, Metrics, and Traces.

**Core components:**
- **Pyroscope server** — stores and serves profiling data.
- **Language-specific profiler/agent** — e.g., the `pyroscope` Java agent (uses `async-profiler` under the hood) for JVM apps.
- **Grafana** — visualizes profiles as interactive flame graphs.

---

## Prerequisites

- Kubernetes cluster with `kubectl` + Helm 3.
- Grafana already deployed.
- A JVM-based application (Spring Boot).

---

## Step 1: Add Helm Repo

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## Step 2: Create Namespace

```bash
kubectl create namespace profiling
```

---

## Step 3: Install Pyroscope

Create `pyroscope-values.yaml`:

```yaml
pyroscope:
  persistence:
    enabled: false   # enable + set storageClass for real persistence

  extraArgs:
    log.level: info
```

Install:

```bash
helm install pyroscope grafana/pyroscope -n profiling -f pyroscope-values.yaml
```

Verify:

```bash
kubectl get pods -n profiling
```

Pyroscope server listens on port `4040` by default for both its UI and ingestion API.

---

## Step 4: Instrument the Spring Boot (JVM) App

Two options: **Java agent** (no code change) or **SDK** (fine-grained control). Java agent is faster to set up.

### Option A — Java Agent (recommended to start)

Download the agent and add it as a Java startup flag:

```dockerfile
# In your Dockerfile
ADD https://github.com/grafana/pyroscope-java/releases/latest/download/pyroscope.jar /app/pyroscope.jar

ENTRYPOINT ["java", \
  "-javaagent:/app/pyroscope.jar", \
  "-Dpyroscope.application.name=devhub-backend", \
  "-Dpyroscope.server.address=http://pyroscope.profiling.svc.cluster.local:4040", \
  "-Dpyroscope.format=jfr", \
  "-jar", "/app/app.jar"]
```

Key JVM flags:
- `pyroscope.application.name` — label to identify this service in Pyroscope UI.
- `pyroscope.server.address` — Pyroscope server ingestion endpoint.
- `pyroscope.format=jfr` — uses Java Flight Recorder format (low overhead, recommended for modern JDKs).

### Option B — SDK (fine-grained, code-level control)

Add dependency in `pom.xml`:

```xml
<dependency>
    <groupId>io.pyroscope</groupId>
    <artifactId>agent</artifactId>
    <version>LATEST</version>
</dependency>
```

Initialize in code (e.g., in a `@PostConstruct` or main class):

```java
PyroscopeAgent.start(
    new Config.Builder()
        .setApplicationName("devhub-backend")
        .setServerAddress("http://pyroscope.profiling.svc.cluster.local:4040")
        .setFormat(Format.JFR)
        .build()
);
```

---

## Step 5: Add Pyroscope as a Data Source in Grafana

1. Grafana → **Connections → Data Sources → Add data source**.
2. Choose **Grafana Pyroscope**.
3. Set URL: `http://pyroscope.profiling.svc.cluster.local:4040`
4. Click **Save & Test**.

---

## Step 6: View Flame Graphs

1. Grafana → **Explore** → select the Pyroscope data source.
2. Choose your app (`devhub-backend`) and profile type: `cpu`, `alloc_in_new_tlab_bytes` (memory allocation), etc.
3. The flame graph shows a stack of function calls — **wider bars = more time/resource spent in that function**. Click into frames to drill down.

---

## Step 7 (Optional): Correlate with Traces

Grafana supports **span-to-profile** linking: if a specific trace span in Tempo took unusually long, you can jump to the exact CPU profile captured during that time window — narrowing down from "this service call was slow" to "this specific method call was the bottleneck."

---

## Common Issues

| Issue | Cause | Fix |
|---|---|---|
| No profile data in Grafana | Wrong `pyroscope.server.address` or network policy blocking pod-to-pod traffic | Verify DNS: `pyroscope.profiling.svc.cluster.local:4040` reachable from app pod |
| High CPU overhead from profiling | Sampling rate too aggressive | JFR-based profiling (`format=jfr`) has low overhead by default; avoid old wall-clock profilers for prod |
| Agent fails to attach | JVM version incompatibility with `-javaagent` | Check pyroscope-java release notes for supported JDK versions |

---

## Why It Matters (Interview Angle)

Profiling closes the gap that logs, metrics, and traces leave open: a trace can tell you "the `/checkout` API took 3 seconds," but only a profile tells you it's because a specific `calculateDiscount()` method is doing an unindexed loop. Mentioning continuous profiling (always-on, low-overhead, unlike traditional on-demand profilers) shows awareness of modern observability practices beyond the standard logging/metrics/tracing trio — a differentiator for DevSecOps/SRE-leaning roles.
