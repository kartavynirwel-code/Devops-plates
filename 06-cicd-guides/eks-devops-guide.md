# EKS DevOps Complete Guide 🚀
### devops-spring-app — Minikube se EKS tak

---

## Poora Flow

```
Code likho
    ↓
Docker image banao
    ↓
Image Docker Hub pe push karo
    ↓
EKS Cluster banao (AWS Console ya eksctl)
    ↓
kubectl se deployment apply karo
    ↓
kubectl se service apply karo
    ↓
AWS automatically Load Balancer bana deta hai
    ↓
External IP mil jaati hai — App live! 🎉
```

---

## deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-spring-app
  labels:
    app: devops-spring-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: devops-spring-app
  template:
    metadata:
      labels:
        app: devops-spring-app
    spec:
      containers:
        - name: devops-spring-app
          image: your-dockerhub-username/devops-spring-app:1.0.0
          ports:
            - containerPort: 8080
```

---

## service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-spring-app-service
spec:
  selector:
    app: devops-spring-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: LoadBalancer
```

> ✅ Minikube pe — NodePort likho
> ✅ EKS pe — LoadBalancer likho (AWS ALB automatically banega)

---

## Commands

### 1. Docker Image banao aur push karo

```bash
# Image build karo
docker build -t your-username/devops-spring-app:1.0.0 .

# Docker Hub pe login karo
docker login

# Image push karo
docker push your-username/devops-spring-app:1.0.0
```

---

### 2. EKS Cluster banao

**Option A — eksctl se (terminal)**

```bash
# eksctl install karo (agar nahi hai)
curl --silent --location \
  "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Cluster banao
eksctl create cluster \
  --name devops-cluster \
  --region ap-south-1 \
  --nodes 2

# 15-20 min lagega
```

**Option B — AWS Console se (browser)**

```
AWS Console → EKS → Create Cluster
→ Name: devops-cluster
→ Region: ap-south-1
→ Node size: t3.medium
→ Nodes: 2
→ Create
```

---

### 3. Laptop ko EKS se connect karo

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name devops-cluster

# Verify karo
kubectl get nodes
# 2 nodes dikhne chahiye — Ready
```

---

### 4. App Deploy karo

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

---

### 5. Load Balancer IP lo

```bash
kubectl get service -w
# EXTERNAL-IP column mein AWS ka URL aayega
# jaise: abc123.ap-south-1.elb.amazonaws.com
```

---

### 6. App Access karo

```bash
curl http://<external-ip>/api/hello
curl http://<external-ip>/api/health
curl http://<external-ip>/api/info
```

---

## Daily Use Commands

```bash
# Pods dekho
kubectl get pods

# Logs dekho
kubectl logs -f <pod-name>

# Service dekho
kubectl get service

# Sab kuch ek saath
kubectl get all

# Agar pod crash ho — reason dekho
kubectl describe pod <pod-name>
```

---

## Cleanup (Paisa bachane ke liye)

```bash
# App delete karo
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml

# Poora cluster delete karo
eksctl delete cluster --name devops-cluster --region ap-south-1
```

> ⚠️ EKS cluster chalta rahe toh paisa lagta rehta hai — kaam khatam hone ke baad delete karo!

---

## Minikube vs EKS — Kya Badlta Hai

| Cheez | Minikube | EKS |
|---|---|---|
| Image | Local build | Docker Hub se |
| Service type | NodePort | LoadBalancer |
| Access | `minikube ip:port` | AWS External IP |
| deployment.yaml | Same ✅ | Same ✅ |
| service.yaml | NodePort | LoadBalancer |

---

## Architecture

```
Internet
    ↓
AWS Load Balancer (auto bana)
    ↓
EKS Cluster
    ↓
┌───────────────────────┐
│  Pod1   Pod2   Pod3   │
│  :8080  :8080  :8080  │
└───────────────────────┘
```

---

*Happy Learning! 🎯*
