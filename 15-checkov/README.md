# Checkov — IaC Security Scanner

Building inspector jo blueprint (Terraform/K8s YAML) ko construction se **pehle** check karta hai.

---

## 1. What is Checkov?

Open-source static analysis tool for Infrastructure as Code — Terraform, CloudFormation, Kubernetes, Dockerfile, ARM templates ko security misconfigurations ke liye scan karta hai, deploy hone se pehle.

---

## 2. Checkov vs Trivy

| | Checkov | Trivy |
|---|---|---|
| Scans | IaC files (Terraform, K8s YAML) | Docker images, code, K8s cluster |
| When | Before deployment (static) | After build (runtime) |
| Finds | Misconfigurations in code | Known CVEs, vulnerabilities |
| Example | S3 bucket public access ON | Log4j vulnerable version |
| Best for | IaC security | Container security |

---

## 3. Install

```bash
pip install checkov
checkov --version
```

---

## 4. Commands

```bash
# scan directory (terraform)
checkov -d .
checkov -f main.tf
checkov -d . --framework terraform

# scan kubernetes
checkov -d . --framework kubernetes
checkov -f deployment.yaml

# scan dockerfile
checkov -f Dockerfile --framework dockerfile

# output formats
checkov -d . -o json > checkov-report.json
checkov -d . -o junitxml > checkov-report.xml
```

---

## 5. Common Checks

| Check ID | What it checks | Severity |
|---|---|---|
| CKV_AWS_18 | S3 bucket logging enabled | Medium |
| CKV_AWS_19 | S3 bucket encryption enabled | High |
| CKV_AWS_20 | S3 bucket not publicly accessible | High |
| CKV_AWS_8 | EC2 detailed monitoring | Low |
| CKV_K8S_14 | Container runs as non-root | Medium |
| CKV_K8S_15 | Image tag is not `:latest` | Medium |
| CKV_K8S_30 | CPU limits defined | Medium |
| CKV_DOCKER_2 | HEALTHCHECK instruction exists | Low |

---

## 6. Skip False Positives

```bash
checkov -d . --skip-check CKV_AWS_8
```

```hcl
resource "aws_s3_bucket" "main" {
  #checkov:skip=CKV_AWS_20:Public access needed for website
  bucket = "my-public-website"
}
```

---

## 7. Jenkins Pipeline

```groovy
stage('IaC Security Scan') {
  steps {
    sh 'pip install checkov'
    sh 'checkov -d . --framework terraform -o junitxml > checkov-report.xml'
  }
  post {
    always { junit 'checkov-report.xml' }
    failure { echo 'IaC Security issues found! Fix before deploy!' }
  }
}
```

---

## Interview Questions

**Q: What is Checkov?**
Open-source static analysis tool for IaC — Terraform, Kubernetes, Dockerfile ko security misconfigurations ke liye scan karta hai, deployment se pehle.

**Q: Checkov vs Trivy — difference?**
Checkov IaC code ko misconfigurations ke liye scan karta hai (before deploy). Trivy running images ko CVEs ke liye scan karta hai (after build). Ek complete DevSecOps pipeline me dono chahiye.

**Q: When does Checkov run in CI/CD?**
`terraform apply` se pehle — plan stage me. Infrastructure create hone se pehle hi security issues catch ho jaate hain.

**Q: What is CKV_AWS_20?**
S3 bucket public access check — ensures bucket publicly accessible na ho. AWS ke most important security checks me se ek.
