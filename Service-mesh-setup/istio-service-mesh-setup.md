# Istio Service Mesh — Complete Setup Guide

> **Goal:** Ek real Kubernetes cluster pe Istio install karo, mTLS enable karo, canary deployment karo, aur observability stack setup karo — step by step.

---

## Prerequisites

- Kubernetes cluster running (local: minikube / kind, ya cloud: GKE/EKS/AKS)
- `kubectl` installed aur cluster se connected
- `curl` available

**Check karo sab theek hai:**

```bash
kubectl cluster-info
kubectl get nodes
```

Output mein nodes `Ready` status mein hone chahiye.

---

## Step 1 — Istioctl Download Karo

```bash
curl -L https://istio.io/downloadIstio | sh
```

Yeh latest version download karega. Folder ka naam kuch aisa hoga: `istio-1.x.x`

```bash
# Folder mein jao (apna version number use karo)
cd istio-1.*

# PATH mein add karo taaki istioctl command kaam kare
export PATH=$PWD/bin:$PATH

# Permanent karna ho toh .bashrc mein daalo
echo 'export PATH=$HOME/istio-1.*/bin:$PATH' >> ~/.bashrc
```

**Verify karo:**

```bash
istioctl version
```

---

## Step 2 — Istio Cluster Mein Install Karo

```bash
istioctl install --set profile=demo -y
```

`demo` profile mein yeh sab included hai:
- Istiod (control plane)
- Ingress Gateway
- Egress Gateway
- Observability addons support

**Install verify karo:**

```bash
kubectl get pods -n istio-system
```

Sabhi pods `Running` hone chahiye. Thoda wait karo agar `Pending` dikh raha hai.

```
NAME                                    READY   STATUS    
istiod-xxxxxxxxx-xxxxx                  1/1     Running   
istio-ingressgateway-xxxxxxxxx-xxxxx    1/1     Running   
```

---

## Step 3 — Sidecar Auto-Injection Enable Karo

Yeh ek label hai jo Istio ko batata hai — "is namespace ke har pod mein Envoy sidecar inject karo automatically."

```bash
kubectl label namespace default istio-injection=enabled
```

**Verify karo:**

```bash
kubectl get namespace default --show-labels
```

`istio-injection=enabled` label dikhna chahiye.

> **Note:** Yeh label lagane ke baad jo bhi naye pods deploy honge unme automatically Envoy sidecar aa jayega. Purane pods restart karne padenge.

---

## Step 4 — Sample App Deploy Karo

Istio ke saath ek demo app aata hai — `bookinfo`. Yeh ek microservices app hai jisme 4 services hain.

```bash
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

**Pods check karo:**

```bash
kubectl get pods
```

Thoda wait karo. Jab sab `Running` ho jaye:

```bash
kubectl get pods
# Har pod mein 2/2 containers hone chahiye (app + envoy sidecar)
```

**App test karo:**

```bash
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
```

Output: `<title>Simple Bookstore App</title>` — matlab app chal raha hai!

---

## Step 5 — Gateway Setup Karo (External Access)

Ab app ko browser mein access karne ke liye Gateway aur VirtualService lagao:

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

**Ingress IP/Port nikalo:**

```bash
# Minikube ke liye:
minikube tunnel  # Alag terminal mein run karo

# IP aur Port:
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo "App URL: http://$GATEWAY_URL/productpage"
```

Browser mein `http://$GATEWAY_URL/productpage` kholo — app dikhna chahiye!

---

## Step 6 — mTLS Enable Karo (Zero Trust Security)

### 6a. PeerAuthentication — mTLS Strict Mode

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF
```

Ab koi bhi plain HTTP traffic allow nahi hogi — sirf mTLS.

### 6b. AuthorizationPolicy — Service-to-Service Access Control

Sirf `productpage` service ko `reviews` service call karne do:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/default/sa/bookinfo-productpage"
EOF
```

**Verify karo — rogue service se access band hai:**

```bash
# Koi aur service reviews ko call nahi kar sakti ab
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -sS http://reviews:9080/reviews/1
# Expected: RBAC: access denied
```

---

## Step 7 — DestinationRule Setup Karo

Reviews service ke 3 versions hain (v1, v2, v3). Subsets define karo:

```bash
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

Ya manually:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF
```

---

## Step 8 — Canary Deployment Karo

### 8a. Pehle 100% traffic v1 pe bhejo

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
EOF
```

### 8b. 10% traffic v2 pe shift karo (Canary)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
EOF
```

### 8c. Sab theek hai? 100% v2 pe le jao

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
      weight: 100
EOF
```

### 8d. Problem aa gayi? Instant rollback

```bash
# Sirf weight wapas badlo — 5 second mein rollback
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
EOF
```

---

## Step 9 — Observability Stack Install Karo

### 9a. Prometheus + Grafana + Jaeger + Kiali

```bash
# Sab addons ek saath install karo
kubectl apply -f samples/addons

# Wait karo sab ready hone tak
kubectl rollout status deployment/kiali -n istio-system
```

### 9b. Dashboards Access Karo

Har dashboard ke liye alag terminal mein run karo:

```bash
# Grafana — Metrics dashboards
istioctl dashboard grafana

# Prometheus — Raw metrics
istioctl dashboard prometheus

# Jaeger — Distributed tracing
istioctl dashboard jaeger

# Kiali — Service mesh visualization (sabse useful!)
istioctl dashboard kiali
```

Browser automatically khulega.

### 9c. Traffic Generate Karo (Dashboards mein data aane ke liye)

```bash
# Alag terminal mein run karo — 100 requests bhejo
for i in $(seq 1 100); do
  curl -sS "http://$GATEWAY_URL/productpage" > /dev/null
  sleep 0.5
done
```

Ab Grafana/Kiali mein traffic patterns dikhenge!

---

## Step 10 — Circuit Breaker Setup Karo (Bonus)

Agar koi service baar baar fail kare toh usse temporarily eject karo:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews-circuit-breaker
spec:
  host: reviews
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 5      # 5 errors ke baad
      interval: 30s             # 30 second window mein
      baseEjectionTime: 30s     # 30 sec ke liye eject karo
      maxEjectionPercent: 50    # Max 50% pods eject ho sakte hain
EOF
```

---

## Quick Reference — Useful Commands

```bash
# Sab Istio resources dekho
kubectl get virtualservices,destinationrules,gateways,peerauthentication -A

# Kisi pod ka sidecar config check karo
istioctl proxy-config cluster <pod-name>

# mTLS status check karo
istioctl authn tls-check <pod-name>.<namespace>

# Config validate karo deploy se pehle
istioctl analyze

# Kisi service ka traffic status
istioctl proxy-status

# Poora Istio uninstall karo
istioctl uninstall --purge
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Pod mein sirf 1/1 containers hain (sidecar nahi aaya) | Namespace label check karo: `kubectl get ns default --show-labels` |
| `RBAC: access denied` error aa raha hai | AuthorizationPolicy check karo, ya temporarily delete karo test ke liye |
| Grafana mein koi data nahi dikh raha | Traffic generate karo pehle (Step 9c), phir 2-3 minute wait karo |
| `istioctl` command not found | `export PATH` wala command dobara run karo |
| Gateway IP nahi mil raha | Minikube pe `minikube tunnel` alag terminal mein run karna zaroori hai |

---

## Summary — Kya Kiya

```
Step 1  → istioctl download
Step 2  → Istio cluster mein install (demo profile)
Step 3  → Sidecar auto-injection enable (namespace label)
Step 4  → Sample app deploy (bookinfo)
Step 5  → Gateway setup (browser access)
Step 6  → mTLS STRICT + AuthorizationPolicy (zero trust)
Step 7  → DestinationRule (subsets/versions define karo)
Step 8  → VirtualService (canary deployment 90/10 → 100)
Step 9  → Grafana + Prometheus + Jaeger + Kiali
Step 10 → Circuit Breaker (outlier detection)
```

> **Core concept yaad rakho:** App ka ek line code nahi badla. Sab kuch Envoy sidecar ne handle kiya — mTLS, routing, metrics, tracing. Yahi Service Mesh ka power hai.
