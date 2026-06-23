# 10 - Kubernetes Gateway API (Envoy Gateway)

## Kya hai ye?
Gateway API, Ingress ka advanced version hai.
Ek "receptionist" ki tarah kaam karta hai — bahar se aane wala traffic
decide karta hai ki kaunsi service pe bhejein.

- **Ingress** = basic routing
- **Gateway API** = advanced routing (path, header, weight based)

## Components
```
GatewayClass  → Konsa controller use karna hai (envoy, nginx, etc.)
Gateway       → Actual entry point (LoadBalancer)
HTTPRoute     → Traffic routing rules
```

## Install (Envoy Gateway)

```bash
# Envoy Gateway install karo
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.0 \
  --namespace envoy-gateway-system \
  --create-namespace

# Verify karo
kubectl get pods -n envoy-gateway-system
```

## GatewayClass YAML

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
```

## Gateway YAML

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: default
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
```

## HTTPRoute YAML (Frontend + Backend)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-frontend-route
  namespace: default
spec:
  parentRefs:
    - name: main-gateway
  hostnames:
    - "test.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-frontend-service
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-backend-route
  namespace: default
spec:
  parentRefs:
    - name: main-gateway
  hostnames:
    - "test.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: myapp-backend-service
          port: 8080
```

## Apply karo

```bash
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

# Verify
kubectl get gateway
kubectl get httproute
```

## Access karo (Minikube)

```bash
# Step 1: Gateway IP nikalo
GATEWAY_IP=$(kubectl get gateway main-gateway -o jsonpath='{.status.addresses[0].value}')
echo $GATEWAY_IP

# Step 2: /etc/hosts me add karo
echo "$GATEWAY_IP test.example.com" | sudo tee -a /etc/hosts

# Step 3: ZARURI - minikube tunnel chalaao (naye terminal me)
minikube tunnel

# Step 4: Test karo
curl http://test.example.com
```

## Debugging Commands

```bash
# Gateway status
kubectl get gateway
kubectl describe gateway main-gateway

# HTTPRoute status
kubectl get httproute
kubectl describe httproute <name>

# Envoy logs
kubectl logs -n envoy-gateway-system -l app.kubernetes.io/component=proxy --tail=20

# Pods check
kubectl get pods -n envoy-gateway-system
```

## ⚠️ Gotchas (Real Debugging Se Seekha!)

1. **minikube tunnel bhool gaya** → LoadBalancer IP hang hoti hai, tunnel mandatory hai!
2. **Frontend NodePort tha** → ClusterIP karna pada, Gateway ClusterIP services ke saath kaam karta hai
3. **Envoy restart** → 18+ restarts ke baad gRPC timeout aa raha tha, pod delete karke fix hua
4. **Backend service port** → frontend=80, backend=8080 — sahi port daalna zaruri hai

## Interview Questions

**Q: Gateway API aur Ingress me difference?**
> Gateway API zyada flexible hai — path, header, weight based routing support karta hai.
> Ingress basic path routing karta hai. Gateway API ka future hai Kubernetes networking ka.

**Q: GatewayClass kya hota hai?**
> Ye batata hai ki kaunsa controller Gateway ko implement karega — Envoy, Nginx, etc.

**Q: HTTPRoute ka parentRef kya hota hai?**
> Ye batata hai ki ye route kaunse Gateway se attached hai.
