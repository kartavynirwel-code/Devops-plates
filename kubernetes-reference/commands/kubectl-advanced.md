# kubectl Advanced & Debugging

## 🔬 Output Formats

```bash
kubectl get pod <pod-name> -o yaml          # full YAML output
kubectl get pod <pod-name> -o json          # full JSON output
kubectl get pod <pod-name> -o wide          # extra columns
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o custom-columns='NAME:.metadata.name,STATUS:.status.phase'

# Export current resource as YAML (useful to backup or edit)
kubectl get deployment <name> -o yaml > backup.yaml
```

---

## 🩺 Debugging

```bash
# Check why a pod is failing
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Run a temporary debug pod
kubectl run debug --image=busybox -it --rm -- /bin/sh
kubectl run debug --image=nicolaka/netshoot -it --rm -- bash
kubectl run curl-test --image=curlimages/curl -it --rm -- sh

# Copy files to/from pod
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file

# Check resource usage (needs metrics-server)
kubectl top nodes
kubectl top pods
kubectl top pods -n <namespace>
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
```

---

## 🌐 DNS Debugging

```bash
# Run a pod to test DNS
kubectl run dns-test --image=busybox -it --rm -- nslookup kubernetes.default
kubectl run dns-test --image=busybox -it --rm -- nslookup <service-name>.<namespace>.svc.cluster.local
```

---

## 📦 DryRun & Diff

```bash
# Validate without applying
kubectl apply -f file.yaml --dry-run=client
kubectl apply -f file.yaml --dry-run=server

# See what would change
kubectl diff -f file.yaml

# Generate YAML from imperative command
kubectl create deployment my-app --image=nginx --dry-run=client -o yaml
kubectl expose deployment my-app --port=80 --dry-run=client -o yaml
```

---

## 🔑 Secrets Management

```bash
# Decode a secret value
kubectl get secret <secret-name> -o jsonpath='{.data.password}' | base64 --decode

# Create secret from file
kubectl create secret generic my-secret --from-file=./secret.txt

# Create TLS secret
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key

# Create docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password> \
  --docker-email=<email>
```

---

## ⚙️ ConfigMap Quick Create

```bash
kubectl create configmap my-config \
  --from-literal=DB_HOST=localhost \
  --from-literal=DB_PORT=5432

kubectl create configmap my-config --from-file=./config.properties
kubectl create configmap my-config --from-env-file=.env
```

---

## 🔐 RBAC Debugging

```bash
# Can I do this?
kubectl auth can-i create pods
kubectl auth can-i create pods -n <namespace> --as=<user>
kubectl auth can-i '*' '*'                    # am I cluster admin?

# List permissions for a service account
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa-name>
```

---

## 🧹 Cleanup Helpers

```bash
# Delete all evicted pods
kubectl get pods --all-namespaces | grep Evicted | awk '{print $2 " -n " $1}' | xargs kubectl delete pod

# Delete all completed jobs
kubectl delete jobs --field-selector status.successful=1 -A

# Delete pods in CrashLoopBackOff
kubectl get pods -A | grep CrashLoopBackOff | awk '{print "kubectl delete pod "$2" -n "$1}' | bash
```

---

## 📌 Patching Resources

```bash
# Patch a field (strategic merge)
kubectl patch deployment <name> -p '{"spec":{"replicas":3}}'

# Patch with JSON patch
kubectl patch pod <name> --type='json' \
  -p='[{"op":"replace","path":"/spec/containers/0/image","value":"nginx:latest"}]'
```

---

## 🔧 Node Management

```bash
# Cordon (mark unschedulable)
kubectl cordon <node-name>
kubectl uncordon <node-name>

# Drain (safely evict all pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Taint a node
kubectl taint nodes <node-name> key=value:NoSchedule
kubectl taint nodes <node-name> key=value:NoSchedule-    # remove taint
```
