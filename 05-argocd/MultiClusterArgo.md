# Multi-Cluster Deployment with ArgoCD

## What is Multi-Cluster Deployment?

In production, companies don't run everything on one Kubernetes cluster.
They spread workloads across **multiple clusters** for reliability, performance, and isolation.

```
Single Cluster (Beginner):
One cluster → One region → One failure point ❌

Multi Cluster (Production):
Many clusters → Many regions → High availability ✅
```

---

## Why Multi-Cluster?

```
Reasons companies use multiple clusters:
─────────────────────────────────────────
✅ High Availability    → If one cluster fails, others still run
✅ Geo Distribution    → Clusters closer to users (low latency)
✅ Environment Isolation → dev / staging / prod on separate clusters
✅ Team Isolation      → Team A owns Cluster A, Team B owns Cluster B
✅ Compliance          → Data must stay in specific region (GDPR etc.)
✅ Cost Optimization   → Different workloads on different sized clusters
✅ Blast Radius        → Bad deployment only affects one cluster
```

---

## Multi-Cluster Patterns

There are two main patterns for managing multiple clusters with ArgoCD:

```
Pattern 1: Hub and Spoke  ← Most Popular
Pattern 2: Standalone (Singleton per cluster)
```

---

## Pattern 1 — Hub and Spoke

### Concept:

```
                    ┌─────────────────┐
                    │   HUB CLUSTER   │
                    │   (ArgoCD)      │
                    │                 │
                    │ ┌─────────────┐ │
                    │ │   ArgoCD    │ │
                    │ │  Server     │ │
                    │ └─────────────┘ │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
   │    SPOKE 1   │ │    SPOKE 2   │ │    SPOKE 3   │
   │  (Dev Env)   │ │ (Staging)    │ │  (Prod)      │
   │              │ │              │ │              │
   │  No ArgoCD   │ │  No ArgoCD   │ │  No ArgoCD   │
   └──────────────┘ └──────────────┘ └──────────────┘
```

### How it Works:

```
1. One central cluster runs ArgoCD (Hub)
2. All other clusters are "Spoke" clusters
3. Hub ArgoCD manages deployments on ALL spoke clusters
4. Spoke clusters have NO ArgoCD installed
5. One place to manage everything ✅
```

### Advantages:

```
✅ Single pane of glass — one UI for all clusters
✅ Centralized control
✅ Easier to manage RBAC
✅ Less resource usage (ArgoCD only on one cluster)
✅ One place for all policies
```

### Disadvantages:

```
❌ Hub is a single point of failure
   (If hub goes down, no new deployments anywhere)
❌ Network dependency — hub must reach all spokes
❌ More complex network setup
```

---

## Pattern 2 — Standalone (Singleton)

### Concept:

```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   CLUSTER 1      │  │   CLUSTER 2      │  │   CLUSTER 3      │
│   (Dev)          │  │   (Staging)      │  │   (Prod)         │
│                  │  │                  │  │                  │
│ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
│ │   ArgoCD     │ │  │ │   ArgoCD     │ │  │ │   ArgoCD     │ │
│ └──────────────┘ │  │ └──────────────┘ │  │ └──────────────┘ │
│                  │  │                  │  │                  │
│    App Pods      │  │    App Pods      │  │    App Pods      │
└──────────────────┘  └──────────────────┘  └──────────────────┘
         │                     │                     │
         └─────────────────────┴─────────────────────┘
                               │
                        Git Repository
                      (Single Source of Truth)
```

### How it Works:

```
1. Each cluster has its OWN ArgoCD installed
2. Each ArgoCD manages only its own cluster
3. All ArgoCD instances watch the SAME Git repo
4. Different branches/folders for different clusters
5. Independent — no cluster depends on another
```

### Advantages:

```
✅ No single point of failure
✅ Clusters are fully independent
✅ If one cluster ArgoCD fails, others still work
✅ Better for strict isolation requirements
✅ Each team manages their own ArgoCD
```

### Disadvantages:

```
❌ Multiple ArgoCD instances to manage
❌ No single UI for all clusters
❌ More resource usage
❌ Harder to enforce global policies
❌ Configuration duplication
```

---

## Hub and Spoke vs Standalone — Comparison

| Feature | Hub and Spoke | Standalone |
|---------|--------------|------------|
| ArgoCD instances | 1 (on hub) | One per cluster |
| Single UI | ✅ Yes | ❌ No |
| Single point of failure | ❌ Hub | ✅ No |
| Independence | ❌ Spokes depend on hub | ✅ Fully independent |
| Resource usage | ✅ Low | ❌ Higher |
| Complexity | Medium | Lower per cluster |
| Best for | Centralized teams | Distributed teams |
| Blast radius | Hub failure = no deploys | Isolated failures |

---

## When to Use Which?

```
Use Hub and Spoke when:
→ Small/medium company
→ Central DevOps team manages all clusters
→ You want single dashboard
→ Less than 10 clusters
→ Clusters are in same network/VPC

Use Standalone when:
→ Large company / multiple independent teams
→ Strict security/compliance requirements
→ Teams in different regions
→ More than 10 clusters
→ Cannot afford Hub being a single point of failure
→ Air-gapped environments
```

---

## Hub and Spoke — Setup

### Step 1 — Install ArgoCD on Hub Cluster:

```bash
# Connect to Hub cluster
kubectl config use-context hub-cluster

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl get pods -n argocd -w

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Step 2 — Install ArgoCD CLI:

```bash
# Linux
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login to ArgoCD
argocd login <hub-cluster-ip> --username admin --password <password>
```

### Step 3 — Add Spoke Clusters to Hub ArgoCD:

```bash
# Add spoke cluster 1 (dev)
argocd cluster add dev-cluster-context --name dev

# Add spoke cluster 2 (staging)
argocd cluster add staging-cluster-context --name staging

# Add spoke cluster 3 (prod)
argocd cluster add prod-cluster-context --name prod

# List all registered clusters
argocd cluster list
```

Output:
```
SERVER                          NAME      VERSION  STATUS
https://dev-cluster-ip          dev       1.27     Successful
https://staging-cluster-ip      staging   1.27     Successful
https://prod-cluster-ip         prod      1.27     Successful
https://kubernetes.default.svc  in-cluster 1.27   Successful
```

### Step 4 — Create Applications on Different Clusters:

```yaml
# dev-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kartavynirwel-code/portfolioWEB
    targetRevision: develop          # dev branch
    path: K8s/dev
  destination:
    server: https://dev-cluster-ip   # Spoke cluster
    namespace: dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

```yaml
# prod-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kartavynirwel-code/portfolioWEB
    targetRevision: main             # main branch
    path: K8s/prod
  destination:
    server: https://prod-cluster-ip  # Different spoke cluster
    namespace: prod
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
      # No auto-prune on prod — manual approval needed
```

```bash
kubectl apply -f dev-application.yaml
kubectl apply -f prod-application.yaml
```

---

## Standalone — Setup

### Step 1 — Install ArgoCD on EACH Cluster:

```bash
# Dev Cluster
kubectl config use-context dev-cluster
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Staging Cluster
kubectl config use-context staging-cluster
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Prod Cluster
kubectl config use-context prod-cluster
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Step 2 — Git Repo Structure for Standalone:

```
portfolioWEB/
├── app/                    ← Application code
├── K8s/
│   ├── base/              ← Common configs
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── dev/               ← Dev overrides
│   │   └── kustomization.yaml
│   ├── staging/           ← Staging overrides
│   │   └── kustomization.yaml
│   └── prod/              ← Prod overrides
│       └── kustomization.yaml
└── JenkinsFile
```

### Step 3 — Each ArgoCD Points to Its Folder:

```yaml
# On dev cluster ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/kartavynirwel-code/portfolioWEB
    path: K8s/dev                    # Dev specific path
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc  # Local cluster
    namespace: default
```

```yaml
# On prod cluster ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/kartavynirwel-code/portfolioWEB
    path: K8s/prod                   # Prod specific path
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc  # Local cluster
    namespace: default
```

---

## ApplicationSet — Deploy to Multiple Clusters at Once

ArgoCD has a powerful feature called **ApplicationSet** that can deploy to multiple clusters automatically.

```yaml
# applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-all-clusters
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://dev-cluster-ip
            env: dev
          - cluster: staging
            url: https://staging-cluster-ip
            env: staging
          - cluster: prod
            url: https://prod-cluster-ip
            env: prod
  template:
    metadata:
      name: 'myapp-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/kartavynirwel-code/portfolioWEB
        targetRevision: main
        path: 'K8s/{{env}}'          # Points to env specific folder
      destination:
        server: '{{url}}'
        namespace: '{{env}}'
      syncPolicy:
        automated:
          selfHeal: true
```

```bash
kubectl apply -f applicationset.yaml

# This creates 3 applications automatically:
# myapp-dev    → deploys to dev cluster
# myapp-staging → deploys to staging cluster
# myapp-prod   → deploys to prod cluster
```

---

## Real World Multi-Cluster Flow

```
Developer pushes code
        │
        ▼
   Git Repository
        │
        ├──→ Jenkins (CI)
        │    → Build
        │    → Test
        │    → Docker image push
        │    → Update image tag in Git
        │
        ▼
   Git Updated
        │
        ├──→ ArgoCD Hub (Hub & Spoke)
        │    → Detects change
        │    → Dev cluster   → Auto deploy ✅
        │    → Staging cluster → Auto deploy ✅
        │    → Prod cluster  → Manual approval ⏸️
        │
        └──→ Notification
             → Slack: "Dev deployed ✅"
             → Slack: "Prod waiting for approval ⏸️"
```

---

## Multi-Cluster RBAC — Who Can Deploy Where?

```yaml
# ArgoCD Project with cluster restrictions
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production-project
  namespace: argocd
spec:
  description: Production deployments only
  sourceRepos:
    - 'https://github.com/kartavynirwel-code/*'
  destinations:
    - server: https://prod-cluster-ip    # Only prod cluster
      namespace: '*'
  roles:
    - name: prod-deployer
      description: Can deploy to prod
      policies:
        - p, proj:production-project:prod-deployer, applications, sync, production-project/*, allow
      groups:
        - senior-devops-team             # Only senior team can deploy to prod
```

---

## Useful Commands

```bash
# List all clusters registered in ArgoCD
argocd cluster list

# Add a new cluster
argocd cluster add <context-name> --name <friendly-name>

# Remove a cluster
argocd cluster rm <cluster-url>

# List all apps across all clusters
argocd app list

# Get specific app status
argocd app get myapp-prod

# Sync app on specific cluster
argocd app sync myapp-prod

# Manually approve prod deployment
argocd app sync myapp-prod --revision main

# Rollback specific cluster app
argocd app rollback myapp-prod <revision>

# Get cluster info
argocd cluster get <cluster-url>
```

---

## Multi-Cluster Architecture in AWS

```
AWS Setup:
──────────
Region: ap-south-1 (Mumbai)
│
├── EKS Cluster 1 → Hub + Dev workloads
│   └── ArgoCD installed here
│
├── EKS Cluster 2 → Staging
│   └── No ArgoCD (spoke)
│
└── EKS Cluster 3 → Production
    └── No ArgoCD (spoke)
    └── Private subnet only
    └── Manual sync approval required
```

---

## Summary

```
Multi-Cluster = Running apps on multiple K8s clusters

Two Patterns:
─────────────
Hub and Spoke:
→ One ArgoCD manages all clusters
→ Best for centralized teams
→ Single dashboard ✅

Standalone:
→ Each cluster has own ArgoCD
→ Best for independent teams
→ No single point of failure ✅

ApplicationSet:
→ Deploy to many clusters with one YAML
→ Most powerful ArgoCD feature
→ Used in large companies ✅

Key Takeaway:
→ Git is still single source of truth
→ ArgoCD syncs Git to all clusters
→ Pattern depends on team structure
→ Hub & Spoke most common in industry
```

---

## Interview Questions on Multi-Cluster

```
Q: What is Hub and Spoke in ArgoCD?
A: Hub is one central cluster running ArgoCD
   that manages deployments on multiple spoke
   clusters. Spokes have no ArgoCD installed.

Q: When would you use Standalone over Hub & Spoke?
A: When teams are independent, have strict
   isolation needs, or cannot afford a central
   failure point.

Q: What is ApplicationSet?
A: An ArgoCD feature that creates multiple
   Applications from one template, allowing
   deployment to many clusters automatically.

Q: How do you control who deploys to production?
A: Using ArgoCD Projects with RBAC — restrict
   which teams can sync to production clusters,
   and require manual approval for prod syncs.
```
