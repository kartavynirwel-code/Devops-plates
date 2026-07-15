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

- **Storage Backend** — where Vault's own data (encrypted) is stored (Raft integrated storage, Consul, S3, File — File/Raft-single-node is dev/learning only, never prod)
- **Auth Methods** — how clients authenticate (Token, Userpass, AppRole, Kubernetes, JWT/OIDC, AWS IAM)
- **Secret Engines** — where secrets live (KV store, Database, AWS, PKI)
- **Seal/Unseal Mechanism** — Vault storage is always encrypted at rest. Vault starts **sealed** — it cannot read its own storage until it has the encryption key. This is the part `vault server -dev` hides from you (dev mode auto-unseals with a throwaway key).

```
App starts
 -> Authenticate with Vault (AppRole/K8s auth)
 -> Get Token
 -> Request secret: vault kv get secret/devhub/db
 -> Vault returns: {username, password}
 -> App uses secret (never stored in code!)
```

---

## 3. Install Vault (Ubuntu)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault -y

vault -version
```

### 3a. Dev Mode (learning / local testing ONLY)

```bash
vault server -dev

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='<root-token-printed-in-terminal>'
vault status
```

⚠️ Dev mode: in-memory storage (data lost on restart), auto-unsealed, root token handed to you directly, TLS disabled. **Never use this for anything real** — it exists only so you can practice commands.

### 3b. Production Mode (real setup — this is what was missing)

Config file `/etc/vault.d/vault.hcl`:

```hcl
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault-cert.pem"
  tls_key_file  = "/etc/vault.d/tls/vault-key.pem"
  # tls_disable = "true"   # only for isolated internal testing, never real prod
}

api_addr     = "https://<vault-node-ip>:8200"
cluster_addr = "https://<vault-node-ip>:8201"
ui           = true
```

Run as a systemd service (Vault's Debian/Ubuntu package already ships a unit file):

```bash
sudo mkdir -p /opt/vault/data
sudo chown vault:vault /opt/vault/data

sudo systemctl enable vault
sudo systemctl start vault
sudo systemctl status vault
```

```bash
export VAULT_ADDR='https://<vault-node-ip>:8200'
vault status
# Output will show: Sealed = true   <-- this is expected right after fresh install
```

### 3c. Initialize Vault (one-time, only once per fresh cluster)

```bash
vault operator init
```

This returns:
- **5 Unseal Keys** (Shamir's Secret Sharing — by default any 3 of these 5 are needed to unseal)
- **1 Initial Root Token**

⚠️ Save these somewhere safe **outside** Vault itself (password manager, printed & locked, or split among team members). If lost, Vault data is permanently unrecoverable.

### 3d. Unseal Vault (needed every time Vault restarts)

```bash
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
# default threshold = 3 out of 5 keys

vault status
# Sealed = false   <-- now Vault is usable
```

```bash
vault login <initial-root-token>
```

**Interview point:** Root token ko day-to-day use nahi karte — login ke baad turant ek admin/CI policy-based token ya AppRole banao, aur root token ko revoke/secure storage me daal do.

---

## 4. Basic Commands — KV Secret Engine (CLI)

```bash
vault secrets enable -path=secret kv-v2

vault kv put secret/devhub/database \
  username='root' password='SuperSecurePass123!' host='db.devhub.com'

vault kv get secret/devhub/database
vault kv get -field=password secret/devhub/database
vault kv get -format=json secret/devhub/database

vault kv list secret/devhub/
vault kv delete secret/devhub/database

# KV v2 keeps version history
vault kv get -version=1 secret/devhub/database
vault kv undelete -versions=1 secret/devhub/database
```

---

## 5. Using the Vault UI

CLI ke saath UI bhi available hai (`ui = true` config me set hai) — GUI se secrets/policies dekhna aur manage karna easier lagta hai especially jab team ke saath kaam ho.

**Steps:**

1. Browser me kholo: `https://<vault-node-ip>:8200/ui`
2. Login screen pe **Method** dropdown se "Token" select karo, root token (ya apna assigned token) paste karo → **Sign In**
3. Left sidebar → **Secrets Engines** — yahan se dekh sakte ho konse engines enabled hain (KV, AWS, Database, etc.) aur naya engine **Enable new engine** button se add kar sakte ho
4. Kisi engine (e.g. `secret/`) pe click karo → **Create secret** button se naya KV path aur key-value pairs UI form se add kar sakte ho (CLI ka `vault kv put` jo karta hai wahi)
5. Left sidebar → **Access → Auth Methods** — yahan Kubernetes/AppRole/JWT auth methods enable + configure kar sakte ho form-based UI se, bina CLI ke
6. Left sidebar → **Policies → ACL Policies** — naya policy **Create ACL policy** se, HCL text box me policy likh ke save kar sakte ho
7. Top-right → **Copy token** icon se apna current session token copy kar sakte ho scripts me use karne ke liye

UI aur CLI dono same backend API (`/v1/...`) ko hit karte hain — koi functional difference nahi, sirf convenience ka farak hai. Production automation (Jenkins/CI) hamesha CLI/API se hi hoga; UI mostly manual inspection/debugging ke liye useful hai.

---

## 6. Vault Policies (RBAC for secrets)

```hcl
# devhub-policy.hcl
path "secret/data/devhub/*" {
  capabilities = ["read", "list"]
}
path "secret/data/devhub/admin/*" {
  capabilities = ["create", "update", "delete", "read"]
}
```

```bash
vault policy write devhub-policy devhub-policy.hcl
vault policy list
vault policy read devhub-policy
```

Note: KV v2 paths internally prefix with `data/` — CLI `vault kv put secret/devhub/database` maps to actual API path `secret/data/devhub/database`, isliye policies me `secret/data/...` likhna padta hai.

---

## 7. Auth Methods

### 7a. Userpass (simple, good for UI demo/testing)

```bash
vault auth enable userpass

vault write auth/userpass/users/kartavya \
  password="ChangeMe123!" \
  policies="devhub-policy"

vault login -method=userpass username=kartavya password="ChangeMe123!"
```

### 7b. AppRole (machine-to-machine, e.g. CI/CD pipelines)

```bash
vault auth enable approle

vault write auth/approle/role/jenkins-role \
  token_policies="devhub-policy" \
  token_ttl=1h \
  token_max_ttl=4h

vault read auth/approle/role/jenkins-role/role-id
vault write -f auth/approle/role/jenkins-role/secret-id

vault write auth/approle/login \
  role_id="<role-id>" \
  secret_id="<secret-id>"
```

### 7c. Kubernetes Auth (for Agent Injector — see section 8)

```bash
vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="https://<K8S_API_SERVER>:443"
```

---

## 8. Vault + Kubernetes (Agent Injector)

Secrets auto-inject as files into pods — no application code change.

**Setup (Helm — official HashiCorp chart):**

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault-agent-injector hashicorp/vault \
  --set "injector.enabled=true" \
  --set "server.enabled=false" \
  -n vault --create-namespace
```
(`server.enabled=false` because Vault itself is already running externally on EC2 in our setup — we only need the injector webhook here.)

**Policy + Role (per service, least privilege):**

```bash
vault policy write auth-service-policy - <<EOF
path "secret/data/ecommerce/auth-service" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/auth-service \
  bound_service_account_names=auth-service-sa \
  bound_service_account_namespaces=ecommerce \
  policies=auth-service-policy \
  ttl=1h
```

**Deployment annotations:**

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: 'true'
    vault.hashicorp.com/role: 'auth-service'
    vault.hashicorp.com/agent-inject-secret-db: 'secret/data/ecommerce/auth-service'
# injected at: /vault/secrets/db
```

---

## 9. Vault + Spring Boot

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
      host: <vault-node-ip>
      port: 8200
      scheme: https
      token: ${VAULT_TOKEN}
      kv:
        enabled: true
        default-context: devhub
```

---

## 10. Vault vs K8s Secrets vs .env

| Feature | .env | K8s Secrets | Vault |
|---|---|---|---|
| Security | Very Low | Medium | Very High |
| Encrypted at rest | No | Only if etcd encryption configured | Yes, always |
| Audit Log | No | Basic | Full trail |
| Auto Rotation | No | No | Yes |
| Dynamic Secrets | No | No | Yes |
| Access Control | None | RBAC | Fine-grained policies |
| Use for | Local dev | Basic K8s apps | Production |

---

## 11. Production Setup — GitHub Actions OIDC → Vault → AWS

Full flow: GitHub Actions authenticates to Vault via OIDC (no stored secrets), gets **temporary** AWS credentials, runs Terraform.

```
GitHub Actions -> Vault (EC2) -> AWS (temporary credentials)
   Push code      JWT verify     IAM User (TTL)
```

### AWS Secret Engine

```bash
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
          url: https://<vault-ec2-ip>:8200
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

## 12. Production Hardening Checklist

- [ ] TLS enabled on listener (never `tls_disable = "true"` in real prod)
- [ ] Raft (integrated storage) or Consul as storage backend — not File
- [ ] Unseal keys distributed among multiple trusted people (Shamir's Secret Sharing) — no single person holds all keys
- [ ] Root token revoked after initial admin setup (`vault token revoke <root-token>`); day-to-day access via policy-scoped tokens/AppRole
- [ ] Audit logging enabled: `vault audit enable file file_path=/var/log/vault_audit.log`
- [ ] Auto-unseal configured for real clusters (AWS KMS / cloud KMS) so a human isn't manually unsealing after every restart
- [ ] Least-privilege policies per service/team — never blanket `path "secret/*" { capabilities = ["read","list","create","update","delete"] }`

---

## Interview Questions

**Q: What is HashiCorp Vault?**
Secret management tool — securely stores and controls access to passwords, API keys, certificates. Audit logging, dynamic secrets, auto rotation deta hai.

**Q: Why Vault over Kubernetes Secrets?**
K8s Secrets base64-encoded hain — encrypted nahi by default. Vault encryption at rest, fine-grained policies, full audit trail, aur dynamic secret generation deta hai. Production-grade.

**Q: What are dynamic secrets?**
Vault on-demand credentials generate karta hai with a TTL. Jaise ek temporary DB user create hota hai jo 1 hour baad expire ho jaata hai — no long-lived credentials.

**Q: What is seal/unseal in Vault, and why does it matter?**
Vault apna storage hamesha encrypted rakhta hai; fresh start ya restart ke baad Vault "sealed" state me hota hai aur data read nahi kar sakta jab tak use decryption key na mile. `vault operator init` root key ko Shamir's Secret Sharing se multiple unseal keys me split kar deta hai (default 5 keys, threshold 3) — koi single person ke paas poora access nahi hota. `vault operator unseal` se threshold number of keys submit karke Vault ko usable banaya jaata hai. Production me ye manual process auto-unseal (cloud KMS) se automate kiya jaata hai.

**Q: What is AppRole auth method?**
Machine-to-machine authentication — CI/CD pipeline ko Role ID + Secret ID milta hai Vault se authenticate karne ke liye.

**Q: How would you integrate Vault with Kubernetes?**
Vault Agent Injector — pod annotations add karke, Vault automatically secrets ko file ke roop me inject karta hai pod me. No app code change needed. Injector Helm chart se install hota hai, aur Kubernetes Auth method (ServiceAccount token based) se Pod Vault ko authenticate karta hai.

**Q: Why Vault over static GitHub Secrets for AWS credentials?**
GitHub Secrets static hote hain — same key forever. Vault TTL-based dynamic credentials deta hai jo automatically expire ho jaate hain — leak hone par bhi useless after expiry.
