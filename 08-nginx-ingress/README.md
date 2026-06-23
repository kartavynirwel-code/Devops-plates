# 08 - Nginx Ingress Controller

## Kya hai ye?
Nginx Ingress Controller ek "hotel receptionist" ki tarah kaam karta hai.
Bahar se aane wala traffic decide karta hai ki kaunsi service pe bhejein.

```
Ingress YAML     = Receptionist ki instruction book (rules)
Ingress Controller = Actual receptionist (jo rules implement karta hai)
```

## Ingress vs Gateway API
| Cheez | Ingress | Gateway API |
|---|---|---|
| Complexity | Simple | Advanced |
| Routing | Path based | Path + Header + Weight |
| Future | Legacy | Future of K8s networking |

## Install (Helm se)

```bash
# Step 1: Repo add karo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Step 2: Install karo
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Step 3: Verify karo
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

## Basic Ingress YAML

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-frontend-service
            port:
              number: 80
```

## Path Based Routing (Frontend + Backend)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: myapp-backend-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-frontend-service
            port:
              number: 80
```

## Apply karo

```bash
kubectl apply -f ingress.yaml

# Verify
kubectl get ingress
kubectl describe ingress myapp-ingress
```

## Access karo (Minikube)

```bash
# Step 1: Minikube tunnel chalaao (naye terminal me) - ZARURI!
minikube tunnel

# Step 2: Ingress IP nikalo
kubectl get ingress
# ADDRESS column me IP aayegi

# Step 3: /etc/hosts me add karo
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts

# Step 4: Test karo
curl http://myapp.local
```

## Debugging Commands

```bash
# Ingress status
kubectl get ingress
kubectl describe ingress myapp-ingress

# Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20

# Pods check
kubectl get pods -n ingress-nginx
```

## ⚠️ Gotchas

1. **minikube tunnel bhool gaya** → Traffic hang hoga, tunnel mandatory hai!
2. **ingressClassName: nginx missing** → Multiple controllers hain toh specify karna zaruri
3. **Backend service port galat** → frontend=80, backend=8080 — dhyan rakho
4. **rewrite-target annotation** → Path rewriting ke liye zaruri hota hai

## Interview Questions

**Q: Ingress aur Ingress Controller me difference?**
> Ingress YAML sirf rules define karta hai. Ingress Controller actual software hai
> jo un rules ko implement karta hai. Controller ke bina Ingress kaam nahi karta.

**Q: ingressClassName kyun likhte hain?**
> Cluster me multiple Ingress Controllers ho sakte hain — Nginx, Traefik, etc.
> ingressClassName batata hai ki kaunsa controller ye rules handle kare.

**Q: Ingress ke bina traffic kaise route hoti thi?**
> NodePort ya LoadBalancer service se — but wo per-service hota tha.
> Ingress ek hi entry point se multiple services route karta hai.
