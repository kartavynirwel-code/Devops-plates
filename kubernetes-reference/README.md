# ☸️ Kubernetes Reference Guide

A complete personal reference for Kubernetes — commands, boilerplates, and cheatsheets.

## 📁 Folder Structure

```
kubernetes-reference/
├── README.md                    ← You are here
├── commands/
│   ├── kubectl-basics.md        ← Core kubectl commands
│   ├── kubectl-advanced.md      ← Advanced/debug commands
│   └── kubectl-context.md       ← Cluster & context management
├── boilerplates/
│   ├── pods/                    ← Pod YAMLs
│   ├── deployments/             ← Deployment YAMLs
│   ├── services/                ← Service YAMLs
│   ├── configmaps/              ← ConfigMap & Secret YAMLs
│   ├── ingress/                 ← Ingress YAMLs
│   ├── storage/                 ← PV, PVC YAMLs
│   ├── rbac/                    ← Role, ClusterRole YAMLs
│   └── namespaces/              ← Namespace YAMLs
└── cheatsheets/
    ├── quick-reference.md       ← One-page quick ref
    └── troubleshooting.md       ← Debug & fix common issues
```

## 🚀 Quick Start

```bash
# Check cluster is running
kubectl cluster-info

# See all resources
kubectl get all -A

# Apply any boilerplate
kubectl apply -f boilerplates/deployments/basic-deployment.yaml
```
