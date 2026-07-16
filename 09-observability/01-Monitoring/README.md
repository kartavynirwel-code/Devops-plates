# 01 - Monitoring (Prometheus + Grafana)

## Kya hai ye?
Prometheus + Grafana = Kubernetes ka monitoring stack.

```
Prometheus = Data collector (metrics fetch karta hai)
Grafana    = Data visualizer (graphs + dashboards)
```

**Real life analogy:**
Hospital monitoring room — har patient (pod) ka
heartbeat (CPU, memory) ek screen pe dikhta hai!

## One-Time Setup
Ek baar install karo — poore cluster ki monitoring hoti hai!
Naya app deploy karo → automatically monitor hoga ✅ (agar sahi labels/annotations hon — Service Discovery section dekho)

## Install (Helm se)

```bash
# Step 1: Namespace banao
kubectl create namespace monitoring

# Step 2: Repo add karo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Step 3: Install karo (Prometheus + Grafana + AlertManager sab ek saath!)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# Step 4: Verify karo
kubectl get pods -n monitoring
```

`kube-prometheus-stack` install hote hi **Prometheus Operator** bhi aata hai — ye operator hi Service Discovery ka core hai (neeche detail mein).

## Grafana Access

```bash
# Port forward karo
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Browser me jaao
http://localhost:3000

# Default credentials
Username: admin
Password: kubectl get secret prometheus-grafana -n monitoring \
          -o jsonpath="{.data.admin-password}" | base64 --decode
```

## Custom Password Set Karna

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=MySecurePassword123
```

## Grafana Dashboard Import Karna

```
1. grafana.com/dashboards pe jao
2. Koi bhi dashboard ID copy karo
   (15661 = Kubernetes cluster monitoring)
3. Grafana → Dashboards → Import → ID paste karo
4. Done! ✅
```

---

## Service Discovery — Prometheus apne aap targets kaise dhundta hai

Traditional Prometheus mein `prometheus.yml` ke andar manually har target ka IP/port likhna padta tha. Kubernetes mein pods create/destroy hote rehte hain, IP change hote rehte hain — static config kaam nahi karega. Isiliye **Prometheus Operator** do custom CRDs deta hai jo automatic discovery karte hain:

### 1) ServiceMonitor — Service ke through discovery
Ye batata hai Prometheus ko: "is label wali Services ko scrape karo."

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  namespace: monitoring
  labels:
    release: prometheus   # kube-prometheus-stack release name se match hona chahiye
spec:
  selector:
    matchLabels:
      app: myapp           # tumhari Service pe ye label hona chahiye
  namespaceSelector:
    matchNames:
      - default
  endpoints:
    - port: metrics         # Service ke andar named port
      path: /actuator/prometheus
      interval: 30s
```

**Flow:** ServiceMonitor → Service (label match) → Service ke peeche wale Pods → un pods ke `/metrics` endpoint se scrape.

### 2) PodMonitor — Pod ko directly discover karna
Jab koi Service hi na ho (headless workloads, jobs), seedha Pod ko target karo:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: myapp-podmonitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: myapp
  podMetricsEndpoints:
    - port: metrics
      path: /metrics
```

### Verify — kya Prometheus ne target pick kiya?
```bash
kubectl get servicemonitor -n monitoring
kubectl get podmonitor -n monitoring

# Prometheus UI mein targets check karo
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Browser: http://localhost:9090/targets
```

### Common gotcha
`release: prometheus` label **ServiceMonitor/PodMonitor dono** pe lagna zaroori hai — Prometheus Operator sirf `serviceMonitorSelector` mein configured label wale resources ko hi watch karta hai. Ye label na ho toh target list mein kabhi nahi aayega, koi error bhi nahi dikhega — silently ignore ho jayega.

---

## PromQL Basics

```promql
# Kaunse targets up hain?
up

# Specific namespace filter
container_memory_usage_bytes{namespace="monitoring"}

# Request rate (last 5 min)
rate(http_requests_total[5m])

# Sum by pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Down pods
up == 0
```

## rate() vs irate()

Dono counters pe use hote hain, difference calculation window me hai:

```promql
# rate() — poore [5m] window ka average per-second rate
# Smooth graph, dashboards ke liye best (spikes chup jate hain)
rate(http_requests_total[5m])

# irate() — sirf last 2 data points ka instant rate
# Sudden spikes dikhata hai, alerting/fast-moving metrics ke liye best
irate(http_requests_total[5m])
```

| | `rate()` | `irate()` |
|---|---|---|
| Calculation | Poore window ka average | Sirf last 2 points |
| Graph | Smooth | Spiky |
| Best for | Dashboards, trends | Fast-changing metrics, alerts |
| Gotcha | Short spike miss ho sakta hai | Noisy graph, misleading agar scrape interval bada hai |

---

## Alertmanager — Alert Rules Setup

Prometheus metrics collect karta hai, **Alertmanager** decide karta hai kisko aur kaise notify karna hai (Slack, email, PagerDuty).

```yaml
# alert-rules.yaml — PrometheusRule CRD (kube-prometheus-stack isko auto-pick karta hai)
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: monitoring
  labels:
    release: prometheus   # kube-prometheus-stack release name se match hona chahiye
spec:
  groups:
  - name: myapp.rules
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High 5xx error rate on {{ $labels.pod }}"
        description: "Error rate is {{ $value | humanizePercentage }} for 5 minutes"

    - alert: PodDown
      expr: up == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "{{ $labels.pod }} is down"
```

```bash
kubectl apply -f alert-rules.yaml
kubectl get prometheusrule -n monitoring
```

**Alertmanager ko notify karna sikhao (Slack example):**
```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-prometheus-kube-prometheus-alertmanager
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    route:
      receiver: 'slack-notifications'
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 3h
    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        send_resolved: true
type: Opaque
```

```bash
kubectl apply -f alertmanager-config.yaml -n monitoring

# Verify — Alertmanager UI
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring
# Browser: http://localhost:9093
```

---

## Debugging Commands

```bash
# Pods check
kubectl get pods -n monitoring

# Grafana service
kubectl get svc -n monitoring

# ServiceMonitor / PodMonitor check
kubectl get servicemonitor,podmonitor -n monitoring

# Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Browser: http://localhost:9090/targets
```

## ⚠️ Gotchas

1. **Default password** → `prom-operator` nahi hota always — secret se nikalo!
2. **Production me** → Password Kubernetes Secret me store karo, hardcode nahi!
3. **PrometheusRule apply kiya but alert fire nahi hua** → `release: prometheus` label check karo, ye Helm release name se exactly match hona chahiye warna Prometheus rule ko pick hi nahi karega
4. **irate() ka spiky graph confuse kar raha** → yehi expected hai, dashboards ke liye `rate()` use karo, irate() sirf alerting/debugging ke liye
5. **ServiceMonitor bana diya but target Prometheus UI mein nahi dikh raha** → same reason, `release: prometheus` label missing hai (ya jo bhi label `serviceMonitorSelector` mein configured hai)

## Interview Questions

**Q: Prometheus kya hai?**
> Open-source monitoring tool — pull-based model use karta hai,
> khud jaake har service se /metrics endpoint se data fetch karta hai.

**Q: Grafana kya hai?**
> Visualization tool — Prometheus ka raw data sundar dashboards me dikhata hai.

**Q: Prometheus Kubernetes mein targets kaise discover karta hai?**
> Prometheus Operator ke through ServiceMonitor/PodMonitor CRDs use hote hain.
> ServiceMonitor label-matched Services ko target karta hai, PodMonitor seedha Pods ko —
> dono cases mein Operator automatically Prometheus ka scrape config generate/update karta hai,
> manual `prometheus.yml` editing ki zaroorat nahi padti.

**Q: ServiceMonitor aur PodMonitor mein kab kaunsa use karoge?**
> Agar workload ke aage Service hai (normal Deployment case) → ServiceMonitor.
> Agar Service nahi hai (headless workload, batch Jobs) → PodMonitor seedha Pod ko target karta hai.

**Q: rate() kyun use karte hain counter pe?**
> Counter sirf badhta hai — restart pe reset hota hai.
> rate() actual per-second speed nikalti hai jo meaningful hoti hai.

**Q: kube-prometheus-stack kya hai?**
> Helm chart jo Prometheus + Grafana + Alertmanager + Prometheus Operator + Node Exporter
> sab ek saath install karta hai. Single command me production-ready setup!

**Q: rate() aur irate() me kab kaunsa use karoge?**
> Dashboard/trend dikhane ke liye `rate()` — smooth aur stable.
> Alerting ya fast-spike detect karne ke liye `irate()` — instant, but noisy.

**Q: Alertmanager Prometheus se alag kyun hai?**
> Separation of concerns — Prometheus sirf metrics evaluate karke alert *fire* karta hai.
> Alertmanager routing, grouping, deduplication, aur actual notification (Slack/email/PagerDuty) handle karta hai.
