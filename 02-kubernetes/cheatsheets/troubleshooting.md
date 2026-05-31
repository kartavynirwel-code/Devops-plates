# 🛠️ Kubernetes Troubleshooting Guide

## 🔴 Pod Issues

### Pod stuck in `Pending`
```bash
kubectl describe pod <pod-name>    # look at Events section

# Common causes:
# 1. Insufficient resources on nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 2. PVC not bound
kubectl get pvc

# 3. Node selector / affinity not matching
# Check: nodeSelector, tolerations in pod spec vs node labels
kubectl get nodes --show-labels

# 4. Image pull secret missing
kubectl get pods -o jsonpath='{.spec.imagePullSecrets}'
```

### Pod stuck in `CrashLoopBackOff`
```bash
# Check logs from crashed container
kubectl logs <pod-name> --previous

# Describe for events
kubectl describe pod <pod-name>

# Common causes:
# - App crashes immediately (bad config, missing env vars)
# - Wrong command/entrypoint
# - OOMKilled (increase memory limits)
# - Liveness probe failing too early (increase initialDelaySeconds)
```

### Pod stuck in `ImagePullBackOff`
```bash
kubectl describe pod <pod-name>    # check image name and pull errors

# Common causes:
# 1. Wrong image name or tag
# 2. Private registry — missing imagePullSecrets
# 3. Registry rate limit (Docker Hub)
kubectl get secret regcred -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

### Pod in `OOMKilled` (exit code 137)
```bash
# Increase memory limits in pod spec
# resources.limits.memory: "512Mi"  →  "1Gi"
kubectl top pods                    # check current usage
```

### Pod in `Terminating` (stuck)
```bash
# Force delete
kubectl delete pod <pod-name> --grace-period=0 --force
```

---

## 🔴 Deployment Issues

### Deployment not rolling out
```bash
kubectl rollout status deployment/<name>
kubectl describe deployment <name>
kubectl get rs                      # check ReplicaSets
kubectl get pods -l app=<name>      # check pod state
```

### Deployment stuck at 0 ready replicas
```bash
# Check pod logs and events
kubectl logs deployment/<name>
kubectl describe deployment <name>
# Check readiness probe — may be failing
```

---

## 🔴 Service / Networking Issues

### Service not routing traffic
```bash
# 1. Check endpoints exist (pods must be Ready)
kubectl get endpoints <svc-name>
# Empty endpoints = no matching pods (label selector mismatch)

# 2. Verify label selector matches pod labels
kubectl get svc <svc-name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels

# 3. Test connectivity from inside the cluster
kubectl run test --image=busybox -it --rm -- wget -qO- http://<svc-name>.<namespace>

# 4. Check service port vs container port
kubectl get svc <svc-name> -o yaml   # check targetPort
```

### DNS not resolving
```bash
kubectl run dns-test --image=busybox -it --rm -- nslookup kubernetes.default
kubectl run dns-test --image=busybox -it --rm -- nslookup <svc>.<ns>.svc.cluster.local

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Ingress not working
```bash
kubectl describe ingress <name>
kubectl get ingress <name> -o yaml
# Check ingress controller pods
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <ingress-pod>
```

---

## 🔴 Storage Issues

### PVC stuck in `Pending`
```bash
kubectl describe pvc <pvc-name>

# Common causes:
# 1. No StorageClass matches
kubectl get storageclass
# 2. No available PV (static provisioning)
kubectl get pv
# 3. Access mode mismatch (RWO vs RWX)
```

---

## 🔴 Resource Issues

### Node not scheduling pods
```bash
kubectl describe node <node-name>   # check Taints and Conditions
kubectl get node <node-name> -o yaml | grep -A 5 conditions

# Uncordon a cordoned node
kubectl uncordon <node-name>
```

### Hitting resource quota limits
```bash
kubectl describe resourcequota -n <namespace>
kubectl get events -n <namespace> | grep exceeded
```

---

## 🩺 General Debug Workflow

```
1. kubectl get pods -A              → find failing pods
2. kubectl describe pod <name>      → read Events section carefully
3. kubectl logs <pod> --previous    → see crash logs
4. kubectl get events               → cluster-wide events
5. kubectl top pods / nodes         → resource pressure
6. kubectl exec -it <pod> -- bash   → interactive debug
```

---

## 🔍 Useful One-Liners

```bash
# All non-running pods
kubectl get pods -A --field-selector=status.phase!=Running

# All pods on a specific node
kubectl get pods -A --field-selector spec.nodeName=<node-name>

# Watch pods in real time
kubectl get pods -w

# Check if RBAC is blocking something
kubectl auth can-i <verb> <resource> -n <namespace> --as=<user>

# Get pod's node
kubectl get pod <name> -o jsonpath='{.spec.nodeName}'

# Get all images running in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Find pods by resource usage
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory
```
