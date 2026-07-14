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

## TLS (HTTPS)

Ingress khud certificate generate nahi karta — cert-manager use karo, jo Let's Encrypt se auto-issue + auto-renew karta hai.

```bash
# Step 1: cert-manager install karo
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

```yaml
# clusterissuer.yaml — Let's Encrypt ke saath account register karta hai
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
```

```yaml
# Ingress me TLS block add karo
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-secret   # cert-manager yahan cert store karega
  rules:
  - host: myapp.example.com
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

```bash
# Verify — Ready: True aane tak wait karo
kubectl get certificate -n default
kubectl describe certificate myapp-tls-secret -n default
```

**Local/staging pe self-signed cert** (real domain nahi hai to):
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=myapp.local"

kubectl create secret tls myapp-tls-secret \
  --cert=tls.crt --key=tls.key -n default
```

## Rate Limiting

Nginx Ingress Controller ke apne built-in annotations hain — koi extra tool install nahi karna.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/limit-rps: "10"          # 10 requests/sec per IP
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"  # burst tak 50 allow
    nginx.ingress.kubernetes.io/limit-connections: "20"  # concurrent connections per IP
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

```bash
# Test karo — 429 aana chahiye limit cross hone pe
for i in {1..30}; do curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local; done
```

| Annotation | Kya karta hai |
|---|---|
| `limit-rps` | Per-IP requests-per-second cap |
| `limit-connections` | Per-IP simultaneous open connections cap |
| `limit-burst-multiplier` | rps ka multiplier — thodi si spike allow karta hai (default 5) |

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
5. **Certificate `Ready: False` phasa reh gaya** → HTTP-01 challenge fail — check karo ki DNS actually us Ingress IP pe point kar raha hai aur port 80 publicly reachable hai
6. **Rate limit annotation lagayi but effect nahi dikha** → Ingress controller reload hone me kuch second lagte hain, aur `limit-rps` per-IP hai — same IP se hi bar-bar test karo

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

**Q: cert-manager kya karta hai?**
> Let's Encrypt (ya kisi bhi ACME issuer) se TLS certificate auto-request,
> validate, aur auto-renew karta hai — manually cert generate/rotate nahi karna padta.

**Q: Rate limiting Ingress level pe kyun, application level pe kyun nahi?**
> Ingress = single entry point, saare services ke liye ek jagah enforce ho jata hai.
> Application level pe har service me alag se implement karna padta — duplicate effort.
