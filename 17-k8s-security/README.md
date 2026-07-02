# Kubernetes Security

Namespaces · RBAC · NetworkPolicy · Kyverno · Secrets · External Secrets Operator

Prerequisites: Docker, kubectl, kind, Helm

```bash
kind create cluster --name k8s-security
kubectl get nodes
```

---

## 1. Namespaces

Logical isolation boundary — foundation that RBAC, NetworkPolicy, and quotas scope to.

| Benefit | Example |
|---|---|
| Team/project separation | `payments`, `search` teams each get own ns |
| RBAC scope | Dev team sees only their namespace |
| NetworkPolicy scope | Deny cross-ns traffic by default |
| Resource quotas | Cap CPU/memory per team |

```bash
kubectl create namespace payments
kubectl create namespace search

kubectl create deployment nginx-payments --image=nginx -n payments
kubectl create deployment nginx-search --image=nginx -n search
```

> Namespaces alone are NOT security — they're the foundation RBAC/NetworkPolicy build on.

---

## 2. RBAC

Who? (User/ServiceAccount) · What? (verbs) · On what? (resources) · Where? (namespace/cluster)

| Object | Scope | Purpose |
|---|---|---|
| Role | Namespace | Permissions within one namespace |
| ClusterRole | Cluster | Permissions cluster-wide |
| RoleBinding | Namespace | Binds Role to User/SA |
| ClusterRoleBinding | Cluster | Binds ClusterRole cluster-wide |

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: payments
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

```bash
kubectl create serviceaccount payments-user -n payments
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: payments
subjects:
- kind: ServiceAccount
  name: payments-user
  namespace: payments
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
# should return yes
kubectl auth can-i list pods --as=system:serviceaccount:payments:payments-user -n payments

# should return no
kubectl auth can-i delete pods --as=system:serviceaccount:payments:payments-user -n payments
```

---

## 3. NetworkPolicy — Zero Trust Networking

Default: all pods can talk to all pods. NetworkPolicy flips to deny-all + explicit allow.

> `kind` needs a CNI plugin to enforce NetworkPolicy — install Calico first.

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

```bash
kubectl run backend --image=nginx --labels="app=my-app" -n payments
kubectl run frontend --image=busybox --labels="role=frontend" -n payments -- sleep 3600
kubectl run attacker --image=busybox -n payments -- sleep 3600
kubectl expose pod backend --port=80 --name=backend-svc -n payments
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-specific-traffic
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
```

Result: `frontend → backend-svc` succeeds, `attacker → backend-svc` times out.

---

## 4. Kyverno — Policy as Code

Kubernetes-native admission controller. YAML-native (no Rego). Intercepts resources before creation.

| Capability | What it does |
|---|---|
| Validate | Reject non-compliant resources |
| Mutate | Auto-fix resources before creation |
| Generate | Auto-create resources (e.g. NetworkPolicy per ns) |

```bash
kubectl apply --server-side -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
```

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce   # Audit = log only, doesn't block
  rules:
  - name: require-image-tag
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Image tag :latest is not allowed. Use a specific version."
      pattern:
        spec:
          containers:
          - image: "!*:latest"
```

```bash
kubectl run bad-pod --image=nginx:latest -n payments   # blocked
kubectl run good-pod --image=nginx:1.25 -n payments    # succeeds
```

> Start with `Audit` on existing clusters before switching to `Enforce`.

---

## 5. Secret Management

```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=StrongPassword123 \
  -n dev
```

```yaml
env:
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: username
```

> base64 is encoding, NOT encryption. K8s Secrets aren't encrypted at rest by default — enable etcd encryption or use an external secret manager.

| Practice | Why |
|---|---|
| Combine Secrets + RBAC | Only specific ServiceAccounts can read |
| Restrict per namespace | Dev can't read prod secrets |
| Never log secrets | `kubectl logs` should never print passwords |
| Never commit to Git | base64 easily decoded |
| Enable etcd encryption | Prevents theft via etcd backup |

---

## 6. External Secrets Operator (Git-Safe Secrets)

Secrets live in Vault; Git only holds a *reference*.

| Step | What happens | Where |
|---|---|---|
| 1 | Secret stored securely | Vault / AWS SM |
| 2 | ExternalSecret YAML committed | Git (safe) |
| 3 | ESO reads Vault, creates K8s Secret | Cluster |
| 4 | Pod consumes it normally | App env vars |

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

Vault dev-mode deployment, SecretStore, and ExternalSecret YAMLs follow the same pattern as `16-vault/`, pointed at the K8s cluster instead of a standalone EC2 Vault.

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: payments
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
```

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: payments
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: db-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: payments/db
      property: username
  - secretKey: password
    remoteRef:
      key: payments/db
      property: password
```

Pod consumes `db-secret` exactly like any other K8s Secret — zero app code change.

---

## Summary

| # | Topic | Tool | Protects |
|---|---|---|---|
| 1 | Namespaces | `kubectl create namespace` | Team/project isolation |
| 2 | RBAC | Role + RoleBinding | Who accesses what |
| 3 | NetworkPolicy | Calico + NetworkPolicy | Which pods talk to which |
| 4 | Policy as Code | Kyverno ClusterPolicy | Image/config standards |
| 5 | Secrets | `kubectl create secret` | Credentials out of code |
| 6 | External Secrets | ESO + Vault | Secrets safe in Git workflows |

```bash
kind delete cluster --name k8s-security
```

---

## Interview Questions

**Q: Do namespaces provide security by themselves?**
Nahi — sirf logical isolation deti hain. Real security RBAC + NetworkPolicy + quotas namespace ke upar layer karne se aati hai.

**Q: Role vs ClusterRole?**
Role ek namespace tak scoped hota hai. ClusterRole cluster-wide permissions define karta hai — cross-namespace resources ya cluster-scoped resources (nodes, PVs) ke liye zaroori.

**Q: Why is Kubernetes NetworkPolicy zero-trust by design once applied?**
Default me sab pods ek dusre se baat kar sakte hain. Ek NetworkPolicy apply hone ke baad, sirf explicitly allowed traffic hi allowed hota hai — baaki sab implicitly denied.

**Q: Kyverno Enforce vs Audit?**
Enforce non-compliant resource ko block karta hai admission time par. Audit sirf violation log karta hai bina block kiye — existing clusters par rollout ke liye safer starting point.

**Q: Are Kubernetes Secrets encrypted?**
Base64 encoded hain, encrypted nahi by default. Encryption at rest ke liye etcd encryption enable karna padta hai, ya better — external secret manager (Vault) use karo.
