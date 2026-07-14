# DAST Setup — Jenkins & GitHub Actions

## 1. Analogy First

Think of DAST like a **health inspector visiting a restaurant while it's actually open and serving customers** — they don't read the recipe book (source code), they walk in, order food, poke at the kitchen doors, try to sneak into the storeroom, and see what actually happens when the restaurant is running live.

DAST = **Dynamic** Application Security Testing. "Dynamic" because the **application must be running** — DAST attacks it from the outside, like a real hacker would, with zero knowledge of the source code.

## 2. Why It Exists

- SAST and SCA both work on code — but some vulnerabilities only appear when the app is actually **running** (misconfigured headers, broken auth flows, session handling bugs, live SQLi via HTTP).
- DAST is black-box: it doesn't care if you wrote it in Java or Python — it just sends real HTTP requests, exactly like Burp Suite or a real attacker would.
- Required for a realistic "attacker's view" pentest-style gate before production deploy.

## 3. Interview-Ready Definition

> DAST is a black-box testing technique that tests a running application from the outside by sending crafted HTTP requests, without access to source code, to discover runtime vulnerabilities like broken authentication, injection, and misconfigurations.

## 4. Tool Choice

**OWASP ZAP (Zed Attack Proxy)** — free, industry-standard, has an official Docker image and both a Jenkins plugin and a GitHub Action. This guide uses ZAP for both pipelines.

Two scan modes:
- **Baseline scan**: passive only, fast (~1-2 min), safe to run on every build.
- **Full scan**: active, sends real attack payloads, slower, use only on staging (never prod).

---

## 5. DAST on Jenkins (using OWASP ZAP)

### Step 1: Pull ZAP Docker Image
```bash
docker pull zaproxy/zap-stable
```

### Step 2: Make Sure Your App Is Deployed to a Reachable URL First
DAST needs a **live, running app**. Add a deploy stage before the ZAP stage, e.g. deploy DevHub 2.0 to a staging URL or a Minikube service, then scan that URL.

### Step 3: Add ZAP Stage to Jenkinsfile
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/kartavynirwel-code/DevHub-2.0.git'
            }
        }
        stage('Deploy to Staging') {
            steps {
                sh 'kubectl apply -f k8s/staging/'
                sh 'sleep 30' // wait for pods to be ready
            }
        }
        stage('DAST - ZAP Baseline Scan') {
            steps {
                sh '''
                    docker run --rm -v $(pwd):/zap/wrk/:rw \
                    zaproxy/zap-stable zap-baseline.py \
                    -t http://staging.devhub.local \
                    -r zap-report.html \
                    -I
                '''
            }
        }
        stage('Publish ZAP Report') {
            steps {
                publishHTML(target: [
                    reportDir: '.',
                    reportFiles: 'zap-report.html',
                    reportName: 'ZAP DAST Report'
                ])
            }
        }
    }
}
```
Note: `-I` means "don't fail the build on findings" (informational mode) — useful while you're still tuning false positives. Remove `-I` once you're ready to enforce a gate.

### Step 4: Enforce a Real Gate (Fail Build on Findings)
```bash
docker run --rm -v $(pwd):/zap/wrk/:rw \
zaproxy/zap-stable zap-baseline.py \
-t http://staging.devhub.local \
-r zap-report.html
```
Without `-I`, ZAP returns a non-zero exit code if it finds WARN/FAIL-level alerts, which naturally fails the Jenkins stage.

### Step 5: Install HTML Publisher Plugin (for report step above)
Manage Jenkins → Plugins → Install: `HTML Publisher Plugin`

### Troubleshooting: `zap_out.json` / Report File Permission Denied (Jenkins User Only)

**Symptom**: The ZAP stage works fine when you run the same `docker run` command manually as the `ubuntu` user, but fails inside Jenkins with a permission error writing `zap_out.json` (or `zap-report.html`) — the container can't write to the mounted workspace.

**Root cause**: ZAP's Docker image runs as its own internal user (`zap`, non-root) inside the container. When you mount `$(pwd):/zap/wrk/:rw`, ZAP writes the report as that internal container user. Running manually as `ubuntu` happens to line up with the file ownership on disk. But Jenkins runs the same `docker run` as the `jenkins` system user (a different UID), and the Jenkins workspace is owned by `jenkins:jenkins` — the container's internal `zap` UID has no write access to it, so the identical command fails only under Jenkins.

**Fix options** (in order of preference):

1. **Pass your UID into the container** so ZAP writes as a UID that already owns the mounted volume:
   ```bash
   docker run --rm -u $(id -u):$(id -g) \
     -v $(pwd):/zap/wrk/:rw \
     zaproxy/zap-stable zap-baseline.py \
     -t http://staging.devhub.local \
     -r zap-report.html -I
   ```
   In the Jenkinsfile, `$(id -u):$(id -g)` resolves to the `jenkins` user's UID/GID at runtime since the `sh` step executes as `jenkins`.

2. **Pre-create the report file with open permissions before the scan**, so the container writes into an existing file instead of creating one under a mismatched owner:
   ```groovy
   stage('DAST - ZAP Baseline Scan') {
       steps {
           sh 'touch zap-report.html && chmod 666 zap-report.html'
           sh '''
               docker run --rm -v $(pwd):/zap/wrk/:rw \
               zaproxy/zap-stable zap-baseline.py \
               -t http://staging.devhub.local \
               -r zap-report.html -I
           '''
       }
   }
   ```

3. **Check the Jenkins workspace ownership itself** — if it's `root`-owned (common after a Docker-based agent misconfiguration), no UID mapping fixes it until that's corrected:
   ```bash
   ls -la $(pwd)   # run as a Jenkins pipeline sh step to confirm ownership
   ```

Option 1 is the cleanest fix and matches how most Jenkins + Docker DAST/SAST integrations handle this — the same pattern applies to similar permission errors with Trivy or any other containerized scan tool mounting the workspace.

---

## 6. DAST on GitHub Actions (using OWASP ZAP)

### Step 1: Create Workflow File
Path: `.github/workflows/dast-zap.yml`

```yaml
name: DAST - ZAP Baseline Scan

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  zap-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy app to staging (example - adjust to your setup)
        run: |
          docker compose -f docker-compose.staging.yml up -d
          sleep 30

      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: 'http://localhost:8080'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
          fail_action: true
```

### Step 2: (Optional) Customize Rules to Reduce Noise
Create `.zap/rules.tsv` in repo root to ignore known false positives:
```
10021	IGNORE	(X-Content-Type-Options header missing on static assets)
10202	IGNORE	(Absence of Anti-CSRF Tokens on public login page)
```

### Step 3: Full Scan Variant (Active Attack, Staging Only)
```yaml
      - name: ZAP Full Scan
        uses: zaproxy/action-full-scan@v0.10.0
        with:
          target: 'http://staging.devhub.local'
          fail_action: true
```
**Warning**: Full scan sends real attack payloads (SQLi attempts, XSS payloads). Never point this at production.

### Step 4: Push and Verify
- Commit workflow → trigger via push or manually via "Run workflow" button (since `workflow_dispatch` is enabled).
- Check Actions tab → ZAP job → download the generated `report_html.html` artifact for full findings.

---

## 7. What "Good" Looks Like for DevHub 2.0

- Jenkins: ZAP baseline scan runs against a Minikube/staging deployment after every merge, HTML report published as a Jenkins artifact.
- GitHub Actions: ZAP action runs against `docker-compose.staging.yml` on push to `main`, fails the workflow on real findings.
- Key distinction to keep straight for interviews: **SAST = read the code, SCA = read the dependency list, DAST = attack the running app.** All three together = your full AppSec pipeline.
