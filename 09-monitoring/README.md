# 09 - Prometheus + Grafana Monitoring

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
Naya app deploy karo → automatically monitor hoga ✅

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

## Debugging Commands

```bash
# Pods check
kubectl get pods -n monitoring

# Grafana service
kubectl get svc -n monitoring

# Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Browser: http://localhost:9090/targets
```

## ⚠️ Gotchas

1. **Default password** → `prom-operator` nahi hota always — secret se nikalo!
2. **Production me** → Password Kubernetes Secret me store karo, hardcode nahi!

## Interview Questions

**Q: Prometheus kya hai?**
> Open-source monitoring tool — pull-based model use karta hai,
> khud jaake har service se /metrics endpoint se data fetch karta hai.

**Q: Grafana kya hai?**
> Visualization tool — Prometheus ka raw data sundar dashboards me dikhata hai.

**Q: rate() kyun use karte hain counter pe?**
> Counter sirf badhta hai — restart pe reset hota hai.
> rate() actual per-second speed nikalti hai jo meaningful hoti hai.

**Q: kube-prometheus-stack kya hai?**
> Helm chart jo Prometheus + Grafana + Alertmanager + Node Exporter
> sab ek saath install karta hai. Single command me production-ready setup!
