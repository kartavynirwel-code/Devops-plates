# kubectl Basics

## 🔍 GET — View Resources

```bash
# Nodes
kubectl get nodes
kubectl get nodes -o wide

# Pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods -n <namespace>
kubectl get pods -A                          # all namespaces
kubectl get pods --show-labels
kubectl get pods -l app=my-app               # filter by label

# Deployments
kubectl get deployments
kubectl get deploy -n <namespace>

# Services
kubectl get services
kubectl get svc

# All resources at once
kubectl get all
kubectl get all -n <namespace>
kubectl get all -A

# ReplicaSets
kubectl get rs

# Namespaces
kubectl get namespaces
kubectl get ns

# ConfigMaps & Secrets
kubectl get configmaps
kubectl get cm
kubectl get secrets

# Ingress
kubectl get ingress
kubectl get ing

# Persistent Volumes
kubectl get pv
kubectl get pvc

# Events (very useful for debugging!)
kubectl get events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## 📋 DESCRIBE — Detailed Info

```bash
kubectl describe pod <pod-name>
kubectl describe pod <pod-name> -n <namespace>
kubectl describe deployment <deploy-name>
kubectl describe service <svc-name>
kubectl describe node <node-name>
kubectl describe ingress <ingress-name>
kubectl describe pvc <pvc-name>
```

---

## 📝 APPLY / CREATE — Deploy Resources

```bash
# Apply from file (create or update)
kubectl apply -f file.yaml
kubectl apply -f ./directory/
kubectl apply -f https://raw.githubusercontent.com/.../file.yaml

# Create (fails if already exists)
kubectl create -f file.yaml

# Create quickly (imperative)
kubectl create deployment my-app --image=nginx
kubectl create namespace my-ns
kubectl create configmap my-config --from-literal=key=value
kubectl create secret generic my-secret --from-literal=password=secret123
```

---

## ❌ DELETE — Remove Resources

```bash
kubectl delete pod <pod-name>
kubectl delete pod <pod-name> -n <namespace>
kubectl delete deployment <deploy-name>
kubectl delete service <svc-name>
kubectl delete -f file.yaml
kubectl delete all --all -n <namespace>      # delete everything in a namespace
kubectl delete namespace <namespace>

# Force delete a stuck pod
kubectl delete pod <pod-name> --grace-period=0 --force
```

---

## 📜 LOGS — View Output

```bash
kubectl logs <pod-name>
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -c <container-name>   # multi-container pod
kubectl logs -f <pod-name>                    # follow / stream logs
kubectl logs --previous <pod-name>            # logs from crashed container
kubectl logs <pod-name> --tail=100            # last 100 lines
kubectl logs -l app=my-app                    # logs from all pods with label
```

---

## 🐚 EXEC — Shell Into Pod

```bash
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -- /bin/sh
kubectl exec -it <pod-name> -c <container> -- /bin/bash
kubectl exec <pod-name> -- env                # run a single command
kubectl exec <pod-name> -- ls /app
```

---

## ✏️ EDIT — Live Edit Resources

```bash
kubectl edit deployment <deploy-name>
kubectl edit service <svc-name>
kubectl edit configmap <cm-name>
```

---

## 📡 PORT-FORWARD — Local Access

```bash
kubectl port-forward pod/<pod-name> 8080:80
kubectl port-forward svc/<svc-name> 8080:80
kubectl port-forward deployment/<deploy-name> 8080:80
```

---

## 📊 SCALE

```bash
kubectl scale deployment <deploy-name> --replicas=3
kubectl scale deployment <deploy-name> --replicas=0   # stop all pods
```

---

## 🔄 ROLLOUT

```bash
kubectl rollout status deployment/<deploy-name>
kubectl rollout history deployment/<deploy-name>
kubectl rollout undo deployment/<deploy-name>            # rollback
kubectl rollout undo deployment/<deploy-name> --to-revision=2
kubectl rollout restart deployment/<deploy-name>         # rolling restart
```

---

## 🏷️ LABELS & ANNOTATIONS

```bash
kubectl label pod <pod-name> env=production
kubectl label pod <pod-name> env-                        # remove label
kubectl annotate pod <pod-name> description="my pod"
```

---

## 🔧 SET — Update Resources

```bash
kubectl set image deployment/<deploy-name> <container>=<new-image>:tag
kubectl set resources deployment/<deploy-name> -c=<container> --limits=cpu=200m,memory=512Mi
kubectl set env deployment/<deploy-name> ENV=production
```
