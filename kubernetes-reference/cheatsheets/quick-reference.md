# ⚡ Kubernetes Quick Reference

## 🔑 Most Used Commands

| Task | Command |
|------|---------|
| Get pods | `kubectl get pods -A` |
| Describe pod | `kubectl describe pod <name>` |
| Pod logs | `kubectl logs -f <pod>` |
| Shell into pod | `kubectl exec -it <pod> -- bash` |
| Apply file | `kubectl apply -f file.yaml` |
| Delete resource | `kubectl delete -f file.yaml` |
| Scale deployment | `kubectl scale deploy <name> --replicas=3` |
| Rollback | `kubectl rollout undo deploy/<name>` |
| Rolling restart | `kubectl rollout restart deploy/<name>` |
| Forward port | `kubectl port-forward svc/<name> 8080:80` |
| Top pods | `kubectl top pods` |
| Get events | `kubectl get events --sort-by='.lastTimestamp'` |
| Switch namespace | `kubectl config set-context --current --namespace=<ns>` |

---

## 🗂️ Resource Short Names

| Full Name | Short |
|-----------|-------|
| pods | po |
| deployments | deploy |
| services | svc |
| namespaces | ns |
| configmaps | cm |
| persistentvolumes | pv |
| persistentvolumeclaims | pvc |
| replicasets | rs |
| ingresses | ing |
| daemonsets | ds |
| statefulsets | sts |
| cronjobs | cj |
| horizontalpodautoscalers | hpa |
| serviceaccounts | sa |
| networkpolicies | netpol |

---

## 📊 Resource Types Overview

```
Workloads:    Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob
Networking:   Service, Ingress, NetworkPolicy, EndpointSlice
Config:       ConfigMap, Secret
Storage:      PV, PVC, StorageClass
RBAC:         Role, ClusterRole, RoleBinding, ClusterRoleBinding, ServiceAccount
Scaling:      HorizontalPodAutoscaler, VerticalPodAutoscaler
Quota:        ResourceQuota, LimitRange
Namespace:    Namespace
```

---

## 🔄 Pod Lifecycle

```
Pending → Running → Succeeded
                 ↘ Failed
                 ↘ Unknown
```

Pod Conditions: `Initialized`, `Ready`, `ContainersReady`, `PodScheduled`

---

## 💡 Container Probes

| Probe | Purpose | When failing |
|-------|---------|--------------|
| `livenessProbe` | Is app alive? | Restart container |
| `readinessProbe` | Is app ready for traffic? | Remove from Service endpoints |
| `startupProbe` | Has app finished starting? | Block other probes until done |

Probe types: `httpGet`, `tcpSocket`, `exec`

---

## 📦 Service Types

| Type | Access | Use Case |
|------|--------|----------|
| `ClusterIP` | Inside cluster only | Default, internal comms |
| `NodePort` | Node IP + port (30000-32767) | Dev/testing |
| `LoadBalancer` | External cloud LB | Production external access |
| `ExternalName` | DNS alias | Point to external services |
| Headless (`clusterIP: None`) | Direct pod DNS | StatefulSets |

---

## 🔐 Common Secret Types

| Type | Use |
|------|-----|
| `Opaque` | Generic key-value |
| `kubernetes.io/tls` | TLS certificate |
| `kubernetes.io/dockerconfigjson` | Docker registry auth |
| `kubernetes.io/service-account-token` | SA token |

---

## 📐 Resource Units

```
CPU:     1 = 1 core = 1000m (millicores)
         0.5 = 500m = half a core

Memory:  Ki = kibibytes (1024 bytes)
         Mi = mebibytes
         Gi = gibibytes
         (use Mi/Gi, not M/G)
```

---

## 🏷️ Label Selectors

```bash
kubectl get pods -l app=my-app
kubectl get pods -l 'env in (prod,staging)'
kubectl get pods -l 'env notin (dev)'
kubectl get pods -l app=my-app,env=prod    # AND condition
```

---

## 🔧 Update Strategies

```
RollingUpdate:
  maxSurge: how many extra pods during update (abs or %)
  maxUnavailable: how many pods can be down (abs or %)

Recreate: delete all old, then create all new (causes downtime)
```

---

## 🚦 Common Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | App error |
| 137 | OOMKilled (out of memory) or SIGKILL |
| 139 | Segfault |
| 143 | SIGTERM (graceful shutdown) |

---

## 🌐 DNS Pattern

```
<service-name>.<namespace>.svc.cluster.local
<pod-ip>.<namespace>.pod.cluster.local

# Examples:
my-svc.default.svc.cluster.local
my-db.production.svc.cluster.local
```
