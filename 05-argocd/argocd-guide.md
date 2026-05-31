# ArgoCD — Complete Guide

## What is ArgoCD?

ArgoCD is a **declarative, GitOps continuous delivery tool** for Kubernetes.

It watches your Git repository and automatically syncs changes to your Kubernetes cluster.

```
Git Repository = Single Source of Truth
ArgoCD = Bridge between Git and Kubernetes
```

---

## Core Concept — GitOps

```
Traditional CD:
Developer → CI Tool → kubectl apply → Kubernetes
(CI tool needs K8s access — security risk!)

GitOps with ArgoCD:
Developer → Git Push → CI Tool → Git Update
                                     ↓
                                  ArgoCD watches Git
                                     ↓
                                  Auto deploys to K8s ✅
(Only ArgoCD needs K8s access — more secure!)
```

---

## How ArgoCD Works

```
1. You push code to Git
2. Jenkins builds Docker image
3. Jenkins updates image tag in Deployment.yaml
4. Jenkins pushes Deployment.yaml to Git
5. ArgoCD detects the Git change
6. ArgoCD applies changes to Kubernetes
7. Website is updated ✅
   (You didn't run a single kubectl command!)
```

---

## ArgoCD Key Features

| Feature | Description |
|---------|-------------|
| Auto Sync | Automatically syncs Git → Kubernetes |
| Self Healing | If someone manually changes K8s, ArgoCD reverts it back to Git state |
| Rollback | Just point to a previous Git commit |
| Multi Cluster | One ArgoCD manages multiple K8s clusters |
| Visual Dashboard | See deployment status, health, history |
| RBAC | Role-based access control |
| Audit Trail | Git history = Deployment history |

---

## Architecture

```
┌─────────────────────────────────────────┐
│              Git Repository              │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │ Application │  │  K8s Manifests   │  │
│  │    Code     │  │  Deployment.yaml │  │
│  └─────────────┘  │  Service.yaml    │  │
│                   └──────────────────┘  │
└─────────────────────────────────────────┘
         │                    │
         ▼                    ▼
   ┌──────────┐        ┌──────────────┐
   │ Jenkins  │        │   ArgoCD     │
   │  CI      │        │   CD         │
   │ • Build  │        │ • Watch Git  │
   │ • Test   │        │ • Sync K8s   │
   │ • Docker │        │ • Dashboard  │
   └──────────┘        └──────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   Kubernetes     │
                    │  ┌────────────┐  │
                    │  │   Pods     │  │
                    │  │  Running   │  │
                    │  └────────────┘  │
                    └──────────────────┘
```

---

## Installation on Kubernetes

```bash
# Step 1 - Create namespace
kubectl create namespace argocd

# Step 2 - Install ArgoCD
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 3 - Wait for pods to be ready
kubectl get pods -n argocd -w

# Step 4 - Expose ArgoCD UI
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort"}}'

# Step 5 - Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Step 6 - Access UI
# http://<your-ip>:<nodeport>
# Username: admin
# Password: (from step 5)
```

---

## Creating an Application in ArgoCD

### Via UI:
```
1. Open ArgoCD dashboard
2. Click "New App"
3. Fill in:
   - App Name: portfolio-app
   - Project: default
   - Sync Policy: Automatic
   - Repository URL: https://github.com/your-repo
   - Path: K8s (folder with yaml files)
   - Cluster: https://kubernetes.default.svc
   - Namespace: default
4. Click "Create"
5. Done! ArgoCD starts watching your repo ✅
```

### Via YAML:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kartavynirwel-code/portfolioWEB
    targetRevision: main
    path: K8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      selfHeal: true      # Reverts manual K8s changes
      prune: true         # Removes deleted resources
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f application.yaml
```

---

## Jenkins + ArgoCD Together

### Jenkins Pipeline (CI Only — No kubectl!):
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }
        stage('Docker Build & Push') {
            steps {
                sh '''
                    docker build -t your-registry/my-boot:${BUILD_NUMBER} .
                    docker push your-registry/my-boot:${BUILD_NUMBER}
                '''
            }
        }
        stage('Update K8s Manifest') {
            steps {
                // Update image tag in Deployment.yaml
                sh '''
                    sed -i "s|image: .*|image: your-registry/my-boot:${BUILD_NUMBER}|" K8s/Deployment.yaml
                    git add K8s/Deployment.yaml
                    git commit -m "Update image to build ${BUILD_NUMBER}"
                    git push
                '''
                // ArgoCD will detect this change and auto deploy!
            }
        }
    }
    post {
        success {
            mail to: 'kartavynirwel77@gmail.com',
                 subject: "Build ${BUILD_NUMBER} Successful - ArgoCD Deploying",
                 body: "Image pushed! ArgoCD will deploy automatically. ${BUILD_URL}"
        }
        failure {
            mail to: 'kartavynirwel77@gmail.com',
                 subject: "Build ${BUILD_NUMBER} Failed",
                 body: "Check: ${BUILD_URL}"
        }
    }
}
```

---

## ArgoCD Sync Policies

```yaml
syncPolicy:
  automated:
    selfHeal: true    # Auto fix manual K8s changes
    prune: true       # Delete resources removed from Git
```

| Policy | Description |
|--------|-------------|
| Manual | You click "Sync" in UI manually |
| Automated | ArgoCD syncs automatically on Git change |
| Self Heal | Reverts unauthorized manual K8s changes |
| Prune | Removes K8s resources deleted from Git |

---

## Application Health Status

```
Healthy   ✅ → All pods running, all good
Degraded  ⚠️ → Something wrong with pods
Progressing 🔄 → Deployment in progress
Suspended ⏸️ → Manually paused
Unknown   ❓ → Cannot determine status
```

---

## Sync Status

```
Synced     ✅ → Git and K8s are in sync
OutOfSync  ❌ → Git changed, K8s not updated yet
```

---

## Rollback with ArgoCD

```
UI Method:
1. ArgoCD Dashboard → Your App
2. Click "History and Rollback"
3. Select previous deployment
4. Click "Rollback"
5. Done! ✅

CLI Method:
argocd app rollback portfolio-app <revision-number>
```

---

## ArgoCD CLI Commands

```bash
# Login
argocd login <argocd-server-ip>

# List applications
argocd app list

# Get app status
argocd app get portfolio-app

# Sync manually
argocd app sync portfolio-app

# Rollback
argocd app rollback portfolio-app 3

# Delete app
argocd app delete portfolio-app
```

---

## ArgoCD vs Jenkins for CD

| Feature | Jenkins CD | ArgoCD |
|---------|-----------|--------|
| kubectl in pipeline | Yes (security risk) | No ✅ |
| Visual dashboard | No | Yes ✅ |
| Rollback | Manual | Easy ✅ |
| Self healing | No | Yes ✅ |
| GitOps | Partial | Full ✅ |
| K8s native | No | Yes ✅ |
| Learning curve | Low | Medium |

---

## Real World Flow

```
Day in the life of a DevOps Engineer:

Morning:
→ Check ArgoCD dashboard
→ All apps Healthy ✅ Synced ✅
→ Nothing to do!

Developer pushes code:
→ Jenkins builds automatically
→ Image pushed to registry
→ Deployment.yaml updated in Git
→ ArgoCD detects change (within 3 mins)
→ Auto deploys to Kubernetes
→ Slack notification: "Deployment successful ✅"

Problem occurs:
→ ArgoCD shows Degraded ⚠️
→ Team gets alert
→ One click rollback in ArgoCD
→ Problem solved in minutes
```

---

## Why ArgoCD in Interviews

```
Interviewers ask:
Q: How do you handle CD in your project?
A: We use ArgoCD for GitOps-based CD.
   Jenkins handles CI — build, test, Docker image.
   ArgoCD watches Git and auto syncs to Kubernetes.
   This separates CI and CD concerns, improves security
   since only ArgoCD needs K8s access, and gives us
   easy rollback through Git history.

This answer = Strong candidate ✅
```

---

## Quick Reference

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Expose UI
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Check pods
kubectl get pods -n argocd

# Apply ArgoCD app
kubectl apply -f argocd-app.yaml

# Check sync status
argocd app get <app-name>
```

---

## Summary

```
ArgoCD = GitOps CD tool for Kubernetes

Key Points:
✅ Git is the source of truth
✅ Auto syncs Git changes to Kubernetes
✅ Self heals unauthorized changes
✅ Easy rollback via Git history
✅ Visual dashboard
✅ Works with Jenkins (Jenkins = CI, ArgoCD = CD)
✅ Industry standard in 2025
✅ CNCF Graduated Project
```
