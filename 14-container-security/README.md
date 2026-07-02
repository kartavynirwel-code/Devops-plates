# Container Security — Docker Hardening + Trivy

Insecure default se lekar fully hardened container tak — progressive steps.

---

## 1. Insecure Container (Baseline — what NOT to do)

```dockerfile
FROM node:25
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000
CMD ["npm", "start"]
```

| Issue | Problem |
|---|---|
| Runs as root | App compromise = full container control (UID 0) |
| Single-stage build | Build tools remain in runtime image |
| Copies everything | Secrets/junk files can leak into image |
| Writable filesystem | Attacker can persist malicious files |
| No resource limits | Container can DoS the host |

---

## 2. Non-Root User

```dockerfile
FROM node:25
WORKDIR /app
RUN groupadd -r appuser && useradd -r -g appuser appuser
COPY . .
RUN npm install
USER appuser
EXPOSE 3000
CMD ["npm", "start"]
```

Root exploited → attacker owns container. Non-root exploited → attacker gets scoped, limited permissions only.

---

## 3. .dockerignore

Without it: `.git` history, `.env` secrets, `node_modules` bloat, and unnecessary files all get baked into the image.

```
.git
.gitignore
node_modules
.env
Dockerfile*
README.md
```

---

## 4. Multi-Stage Builds

Build tools/compilers never touch the runtime image.

```dockerfile
# -------- Build Stage --------
FROM node:25 AS builder
WORKDIR /build
COPY package.json ./
RUN npm install
COPY . .

# -------- Runtime Stage --------
FROM node:25-slim
WORKDIR /app
COPY --from=builder /build/app.js ./app.js
COPY --from=builder /build/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "app.js"]
```

---

## 5. Distroless Images

No shell, no package manager, no OS utilities — non-root by default (UID 65532).

```dockerfile
FROM node:25 AS builder
WORKDIR /build
COPY package.json ./
RUN npm install
COPY . .

FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=builder /build/app.js ./app.js
COPY --from=builder /build/node_modules ./node_modules
EXPOSE 3000
CMD ["app.js"]
```

---

## 6. Runtime Hardening (Defence in Depth)

```bash
docker run \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 100 \
  --memory 256m \
  --cpus 0.5 \
  -p 3000:3000 \
  secure-app
```

| Flag | Purpose |
|---|---|
| `--read-only` | Filesystem immutable at runtime |
| `--tmpfs /tmp` | In-memory writable area only |
| `--cap-drop ALL` | Removes all Linux capabilities |
| `--security-opt no-new-privileges` | Blocks setuid/setgid escalation |
| `--pids-limit 100` | Fork-bomb protection |
| `--memory` / `--cpus` | Resource ceiling, protects host |

---

## 7. Trivy — Vulnerability Scanner

Docker images, filesystem/code, K8s clusters, Terraform/IaC — sab scan karta hai.

```bash
# install (Ubuntu/Debian)
sudo apt install trivy

# scan image
trivy image nginx:latest
trivy image kartavyanirwel/devhub-app:latest

# only HIGH/CRITICAL
trivy image --severity HIGH,CRITICAL nginx:latest

# scan filesystem/code
trivy fs .

# scan k8s cluster
trivy k8s --report summary cluster
```

### Jenkins integration

```groovy
stage('Security Scan') {
  steps {
    sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest'
    // exit-code 1 = fail pipeline if vulnerabilities found
  }
}
```

| Severity | Action |
|---|---|
| CRITICAL | Block deployment |
| HIGH | Block if possible |
| MEDIUM | Plan to fix |
| LOW | Track it |

---

## Final Takeaway

| Step | Fix | Gain |
|---|---|---|
| 1 | Baseline | Runs as root — starting point only |
| 2 | `USER appuser` | Limited blast radius |
| 3 | `.dockerignore` | No accidental secret leaks |
| 4 | Multi-stage build | Build tools absent from runtime |
| 5 | Distroless | No shell, no OS tools, non-root default |
| 6 | Runtime flags | Kernel-level isolation + resource limits |

**Secure Container = Secure Image + Hardened Runtime**

---

## Interview Questions

**Q: Why is running a container as root dangerous?**
Agar app compromise ho jaaye, attacker ko UID 0 (root) mil jaata hai — full container control, aur agar container escape ho jaaye to host tak risk.

**Q: Multi-stage build vs distroless — difference?**
Multi-stage sirf runtime artifacts ko final image me copy karta hai (build tools nahi), lekin base OS still slim/full ho sakta hai. Distroless ek step aage — OS shell aur package manager hi remove kar deta hai, so attacker ke paas exec karne ko kuch nahi.

**Q: What does Trivy scan besides Docker images?**
Filesystem/source code, Git repos (secrets + misconfig), Kubernetes clusters, aur Terraform/IaC files.
