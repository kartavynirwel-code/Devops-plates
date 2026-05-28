# Helm & Operators — Complete Notes

---

## HELM

### What is Helm?

```
Helm = Package Manager for Kubernetes

Just like:
apt     → Ubuntu packages
npm     → Node packages
maven   → Java packages

Helm    → Kubernetes packages
```

---

### Problem Without Helm

```
Simple app deploy karna hai:
→ deployment.yaml
→ service.yaml
→ ingress.yaml
→ configmap.yaml
→ secret.yaml

5 files! Manually manage karo
Alag alag environments ke liye
Sab duplicate karo ❌
```

### Solution With Helm

```bash
# Ek command mein sab!
helm install myapp ./mychart

# Delete
helm uninstall myapp

# Update
helm upgrade myapp ./mychart
```

---

### Helm Chart Structure

```
Chart = Package

mychart/
├── Chart.yaml        → Chart info (name, version)
├── values.yaml       → Default values
└── templates/        → YAML templates
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── configmap.yaml
```

---

### values.yaml — Magic File

```yaml
# values.yaml
replicaCount: 3
image:
  name: myapp
  tag: 1.0.0
service:
  port: 80
  type: NodePort
ingress:
  host: myapp.local
```

```yaml
# deployment.yaml template
spec:
  replicas: {{ .Values.replicaCount }}
  containers:
    - image: {{ .Values.image.name }}:{{ .Values.image.tag }}
```

```
values.yaml mein value change karo
→ Sab YAML files mein auto update!
```

---

### Real Power — Multiple Environments

```bash
# Dev
helm install myapp ./mychart \
  --set replicaCount=1 \
  --set image.tag=dev

# Production
helm install myapp ./mychart \
  --set replicaCount=5 \
  --set image.tag=1.0.0

# Same chart — different values!
```

---

### Helm Hub — Ready Made Charts

```bash
# Repo add karo
helm repo add bitnami https://charts.bitnami.com/bitnami

# Nginx
helm install nginx bitnami/nginx

# Postgres
helm install postgres bitnami/postgresql

# Prometheus
helm install prometheus prometheus-community/prometheus
```

---

### Important Commands

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm repo list

# Search
helm search repo nginx
helm search hub postgres

# Install/Manage
helm install myapp ./mychart
helm install myapp bitnami/nginx
helm upgrade myapp ./mychart
helm rollback myapp 1
helm uninstall myapp

# Info
helm list
helm status myapp
helm history myapp

# Create your own chart
helm create mychart

# Dry run — apply se pehle check karo
helm install myapp ./mychart --dry-run
```

---

### Helm Rollback

```bash
# History dekho
helm history myapp

# Output:
REVISION   STATUS
1          superseded
2          deployed   ← current

# Rollback to revision 1
helm rollback myapp 1
```

---

### One Line Summary

```
Helm    = Kubernetes ka package manager
Chart   = Package (sab YAML ek jagah)
Values  = Config (environments ke liye)
Hub     = Ready made charts available
```

---
---

## OPERATORS

### What is Operator?

```
Operator = CRD + CR + Controller
           (Teen cheez ek saath)

Ek expert jo complex kaam
automatically karta hai

Jaise:
DBA (Database Admin) ka kaam
Operator khud karta hai!
```

---

### Problem Without Operator

```
Postgres deploy karna hai:
→ Pod banao
→ Storage attach karo
→ Password set karo
→ Replication set karo
→ Backup schedule karo
→ Monitoring set karo
→ Failover handle karo

Bahut complex! ❌
```

### With Operator

```yaml
# Bas itna likho
apiVersion: postgres.dev/v1
kind: PostgresCluster
metadata:
  name: mydb
spec:
  instances: 3
  storage: 10Gi
```

```
Operator ne sab kiya:
✅ Pods banaye
✅ Storage attach ki
✅ Password banaya
✅ Replication set ki
✅ Backup schedule kiya
✅ Failover handle karega
```

---

### How Operator Works

```
Tum CR apply karo
        ↓
Controller watch karta hai
        ↓
"Naya CR aaya!"
        ↓
Operator ka logic chala
        ↓
Sab kuch automatically ✅
```

---

### Operator = 3 Things Together

```
CRD        → New resource type define karo
             "PostgresCluster exist karega"

CR         → Us type ka object banao
             "Meri postgres database"

Controller → Watch karo + Kaam karo
             "Database actually chalao"
```

---

### Popular Operators

```
Postgres Operator   → Database manage
Redis Operator      → Cache manage
Prometheus Operator → Monitoring manage
Cert Manager        → SSL manage
ArgoCD              → GitOps manage
Istio               → Service mesh manage
```

---

### Helm vs Operator

```
Helm                    Operator
────                    ────────
Install karo            Install + Manage karo
One time action         Continuously watch karta hai
Simple stateless apps   Complex stateful apps
Nginx, React            Postgres, Kafka, Redis

kubectl apply jaisa     Expert DevOps engineer jaisa
"Set karo aur bhool jao" "24/7 dekh bhaal karta hai"
```

---

### One Line Summary

```
Operator = Smart manager
           Install + Manage + Heal karo
           Expert DevOps engineer
           jo 24/7 kaam karta hai
```

---
---

## Helm vs Operator — When to Use

```
App Type          Use
─────────         ────
Nginx             Helm
React/Angular     Helm
Spring Boot       Helm
Custom App        Helm

Postgres          Operator
MySQL             Operator
Redis             Operator
Kafka             Operator
Prometheus        Operator
```

```
Rule:
Stateless app  → Helm
Stateful app   → Operator
```

---

## Full Summary

```
Helm      = Kubernetes ka npm/maven
            Complex YAML → Simple command
            values.yaml se environments manage

Operator  = CRD + CR + Controller
            Complex apps automatically manage
            Database, Kafka, Monitoring
            24/7 watch + heal karta hai
```

---

*"Helm installs. Operator manages forever."* 🎯
