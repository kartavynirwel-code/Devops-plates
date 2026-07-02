# HashiCorp Vault — Secret Management

Bank locker for secrets — passwords, API keys, DB credentials, certificates.

---

## 1. Problem Vault Solves

| Without Vault | With Vault |
|---|---|
| Passwords in `.env` files | Secrets stored in Vault |
| Secrets in Git repo | Apps fetch secrets at runtime |
| Same secret for everyone | Dynamic secrets per app |
| No audit trail | Full audit log |
| Manual rotation | Automatic secret rotation |
| Secrets never expire | TTL-based secret expiry |

---

## 2. Architecture

- **Storage Backend** — where secrets are stored (File, Consul, DynamoDB, S3)
- **Auth Methods** — how clients authenticate (Token, AppRole, Kubernetes, AWS IAM)
- **Secret Engines** — where secrets live (KV store, Database, AWS, PKI)

```
App starts
 -> Authenticate with Vault (AppRole/K8s auth)
 -> Get Token
 -> Request secret: vault kv get secret/devhub/db
 -> Vault returns: {username, password}
 -> App uses secret (never stored in code!)
```

---

## 3. Install & Run (Dev Mode)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault -y

vault server -dev   # dev/learning only!

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='your-root-token-here'
vault status
```

---

## 4. Basic Commands (KV Secret Engine)

```bash
vault secrets enable -path=secret kv-v2

vault kv put secret/devhub/database \
  username='root' password='SuperSecurePass123!' host='db.devhub.com'

vault kv get secret/devhub/database
vault kv get -field=password secret/devhub/database
vault kv get -format=json secret/devhub/database

vault kv list secret/devhub/
vault kv delete secret/devhub/database
```

---

## 5. Three Maturity Scenarios

1. **Hobby project (unsafe):** Local machine → `.env` → execute → AWS. Risk: Git commit ho gaya to credentials leak.
2. **Source code review (better):** Git → review → audit trail. Still missing: secrets Vault me nahi.
3. **Production (best):** CI/CD → Vault → AWS temporary credentials. No hardcoded credentials anywhere.

---

## 6. Vault + Kubernetes (Agent Injector)

Secrets auto-inject as files into pods — no application code change.

```yaml
annotations:
  vault.hashicorp.com/agent-inject: 'true'
  vault.hashicorp.com/role: 'devhub-role'
  vault.hashicorp.com/agent-inject-secret-db: 'secret/devhub/database'
# injected at: /vault/secrets/db
```

---

## 7. Vault Policies (RBAC for secrets)

```hcl
# devhub-policy.hcl
path "secret/devhub/*" {
  capabilities = ["read", "list"]
}
path "secret/devhub/admin/*" {
  capabilities = ["create", "update", "delete", "read"]
}
```

```bash
vault policy write devhub-policy devhub-policy.hcl
```

---

## 8. Vault + Spring Boot

```xml
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-cloud-starter-vault-config</artifactId>
</dependency>
```

```yaml
spring:
  cloud:
    vault:
      host: localhost
      port: 8200
      scheme: http
      token: ${VAULT_TOKEN}
      kv:
        enabled: true
        default-context: devhub
```

---

## 9. Vault vs K8s Secrets vs .env

| Feature | .env | K8s Secrets | Vault |
|---|---|---|---|
| Security | Very Low | Medium | Very High |
| Audit Log | No | Basic | Full trail |
| Auto Rotation | No | No | Yes |
| Dynamic Secrets | No | No | Yes |
| Access Control | None | RBAC | Fine-grained policies |
| Use for | Local dev | Basic K8s apps | Production |

---

## 10. Production Setup — GitHub Actions OIDC → Vault → AWS

Full flow: GitHub Actions authenticates to Vault via OIDC (no stored secrets), gets **temporary** AWS credentials, runs Terraform.

```
GitHub Actions -> Vault (EC2) -> AWS (temporary credentials)
   Push code      JWT verify     IAM User (TTL)
```

### Vault AWS Secret Engine

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
vault login root

vault secrets enable aws
vault write aws/config/root \
  access_key='AKIA...' secret_key='SECRET...' region='us-east-1'

vault write aws/roles/terraform-role \
  credential_type=iam_user \
  policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [{"Effect": "Allow", "Action": "s3:*", "Resource": "*"}]
}
EOF
```

### GitHub OIDC (JWT) Trust

```bash
vault auth enable jwt

vault write auth/jwt/config \
  oidc_discovery_url='https://token.actions.githubusercontent.com' \
  bound_issuer='https://token.actions.githubusercontent.com'

vault policy write terraform-policy -<<EOF
path "aws/creds/terraform-role" {
  capabilities = ["read"]
}
EOF

vault write auth/jwt/role/gh-actions-role -<<EOF
{
  "role_type": "jwt",
  "bound_audiences": ["https://github.com/kartavynirwel-code"],
  "user_claim": "sub",
  "bound_claims_type": "glob",
  "bound_claims": {"sub": "repo:kartavynirwel-code/DevHub:*"},
  "token_policies": ["terraform-policy"],
  "token_ttl": "1h"
}
EOF
```

### GitHub Actions Workflow

```yaml
name: Terraform Deployment
on: [push]
permissions:
  id-token: write   # required for OIDC
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    steps:
      - uses: actions/checkout@v4
      - name: Fetch Keys from Vault
        uses: hashicorp/vault-action@v3
        with:
          url: http://<vault-ec2-ip>:8200
          role: gh-actions-role
          method: jwt
          secrets: |
            aws/creds/terraform-role access_key | AWS_ACCESS_KEY_ID ;
            aws/creds/terraform-role secret_key | AWS_SECRET_ACCESS_KEY
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan
      - run: terraform apply -auto-approve
```

| Step | What happens |
|---|---|
| 1. Push | GitHub Actions workflow triggers |
| 2. OIDC Token | GitHub generates JWT for the repo |
| 3. Vault Auth | Actions authenticates using JWT |
| 4. Policy Check | Vault verifies repo bound to role |
| 5. AWS Creds | Vault creates temp IAM user w/ S3 access |
| 6. Terraform | Actions uses temp creds to run Terraform |
| 7. Expiry | Credentials expire after 1h automatically |

---

## Interview Questions

**Q: What is HashiCorp Vault?**
Secret management tool — securely stores and controls access to passwords, API keys, certificates. Audit logging, dynamic secrets, auto rotation deta hai.

**Q: Why Vault over Kubernetes Secrets?**
K8s Secrets base64-encoded hain — encrypted nahi by default. Vault encryption at rest, fine-grained policies, full audit trail, aur dynamic secret generation deta hai. Production-grade.

**Q: What are dynamic secrets?**
Vault on-demand credentials generate karta hai with a TTL. Jaise ek temporary DB user create hota hai jo 1 hour baad expire ho jaata hai — no long-lived credentials.

**Q: What is AppRole auth method?**
Machine-to-machine authentication — CI/CD pipeline ko Role ID + Secret ID milta hai Vault se authenticate karne ke liye.

**Q: How would you integrate Vault with Kubernetes?**
Vault Agent Injector — pod annotations add karke, Vault automatically secrets ko file ke roop me inject karta hai pod me. No app code change needed.

**Q: Why Vault over static GitHub Secrets for AWS credentials?**
GitHub Secrets static hote hain — same key forever. Vault TTL-based dynamic credentials deta hai jo automatically expire ho jaate hain — leak hone par bhi useless after expiry.
