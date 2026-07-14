# 🚀 DevOps Boilerplates & Notes
> Production-ready boilerplates, cheatsheets, and guides for DevOps engineers.

## 📁 Structure

| Folder | Contents |
|--------|----------|
| `01-docker` | Dockerfiles for Spring Boot apps |
| `02-kubernetes` | K8s manifests, commands, cheatsheets, RBAC, storage |
| `03-jenkins` | Declarative & Scripted Jenkinsfiles |
| `04-helm` | Helm charts, templates, values |
| `05-argocd` | ArgoCD manifests, multi-cluster guide |
| `06-cicd-guides` | CI/CD setup guides, EKS & K3s guides |
| `07-terraform-modules` | Reusable Terraform modules (VPC, EC2, EKS, RDS, SG) |
| `08-nginx-ingress` | Nginx Ingress Controller setup & YAML |
| `09-monitoring` | Prometheus + Grafana setup, PromQL reference |
| `10-gateway-api` | Gateway API + Envoy setup, HTTPRoute YAML |
| `11-eks` | EKS via Terraform (VPC, IAM, Cluster, Node Group) |
| `12-service-mesh` | Istio service mesh setup guide |
| `13-git-security` | Gitleaks, pre-commit hooks, branch protection, CODEOWNERS, Dependabot, STRIDE |
| `14-container-security` | Docker hardening (non-root, distroless, multi-stage), Trivy |
| `15-checkov` | IaC security scanning for Terraform, Kubernetes, Dockerfile |
| `16-vault` | HashiCorp Vault — KV secrets, K8s Agent Injector, Spring Boot, GitHub OIDC |
| `17-k8s-security` | Namespaces, RBAC, NetworkPolicy, Kyverno, Secrets, External Secrets Operator |
| `18-appsec-sast-sca-dast` | SAST/SCA/DAST theory, tools, attacker flows, fixes, hands-on |

## 🛠️ Tools Covered

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=flat&logo=jenkins&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat&logo=argo&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat&logo=grafana&logoColor=white)
![Istio](https://img.shields.io/badge/Istio-466BB0?style=flat&logo=istio&logoColor=white)
![Vault](https://img.shields.io/badge/Vault-FFEC6E?style=flat&logo=vault&logoColor=black)
![OWASP](https://img.shields.io/badge/OWASP-000000?style=flat&logo=owasp&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat&logoColor=white)
![Checkov](https://img.shields.io/badge/Checkov-4B32C3?style=flat&logoColor=white)
![Gitleaks](https://img.shields.io/badge/Gitleaks-FF6B6B?style=flat&logoColor=white)
![Kyverno](https://img.shields.io/badge/Kyverno-2C3E50?style=flat&logoColor=white)

## 📚 Quick Links

### Kubernetes
- [kubectl Basics](02-kubernetes/commands/kubectl-basics.md)
- [kubectl Advanced](02-kubernetes/commands/kubectl-advanced.md)
- [kubectl Context](02-kubernetes/commands/kubectl-context.md)
- [Quick Reference](02-kubernetes/cheatsheets/quick-reference.md)
- [Troubleshooting](02-kubernetes/cheatsheets/troubleshooting.md)

### Jenkins
- [Basic Declarative Pipeline](03-jenkins/declarative/Jenkinsfile-basic)
- [Advanced Declarative Pipeline](03-jenkins/declarative/Jenkinsfile-advanced)
- [Basic Scripted Pipeline](03-jenkins/scripted/Jenkinsfile-basic)
- [Advanced Scripted Pipeline](03-jenkins/scripted/Jenkinsfile-advanced)

### Helm
- [Helm Notes](04-helm/notes.md)
- [Sample Chart](04-helm/mychart/)

### ArgoCD
- [ArgoCD Complete Guide](05-argocd/argocd-guide.md)
- [Multi Cluster ArgoCD](05-argocd/MultiClusterArgo.md)

### Guides
- [CI/CD with Jenkins](06-cicd-guides/devops-pipeline-guide-withJenkins.md)
- [K3s Setup Guide](06-cicd-guides/k3s-setup.md)
- [EKS DevOps Guide](06-cicd-guides/eks-devops-guide.md)

### Terraform Modules
- [VPC Module](07-terraform-modules/vpc/)
- [EC2 Module](07-terraform-modules/ec2/)
- [EKS Module](07-terraform-modules/eks/)
- [RDS Module](07-terraform-modules/rds/)
- [Security Group Module](07-terraform-modules/security-group/)

### Monitoring
- [Prometheus + Grafana Setup](09-monitoring/README.md)

### Networking
- [Nginx Ingress Controller](08-nginx-ingress/README.md)
- [Ingress with TLS + Rate Limiting](08-nginx-ingress/ingress-tls-ratelimit.yaml)
- [Gateway API + Envoy](10-gateway-api/README.md)

### EKS via Terraform
- [EKS Complete Setup](11-eks/README.md)
- [Terraform Files](11-eks/eks-terraform/)

### Service Mesh
- [Istio Setup Guide](12-Service-mesh/istio-service-mesh-setup.md)

### DevSecOps
- [Git Security — Gitleaks, Branch Protection, STRIDE](13-git-security/README.md)
- [Container Security — Docker Hardening, Trivy](14-container-security/README.md)
- [Checkov — IaC Security Scanning](15-checkov/README.md)
- [HashiCorp Vault — Secret Management](16-vault/README.md)
- [Kubernetes Security — RBAC, NetworkPolicy, Kyverno, ESO](17-k8s-security/README.md)
- [AppSec — SAST · SCA · DAST](18-appsec-sast-sca-dast/README.md)

## 🎯 Author

**Kartavya Nirwel** — Java Backend Developer & DevOps Engineer

[![GitHub](https://img.shields.io/badge/GitHub-kartavynirwel--code-black?logo=github)](https://github.com/kartavynirwel-code)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Kartavya_Nirwel-blue?logo=linkedin)](https://www.linkedin.com/in/kartavya-nirwel-0b7202326/)
