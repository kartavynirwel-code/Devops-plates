# SAST Setup — Jenkins & GitHub Actions

## 1. Analogy First

Think of SAST like a **proofreader checking your essay before you submit it** — it never runs the essay out loud, it just reads the raw text (your source code) line by line and flags bad grammar (insecure patterns) before anyone else sees it.

SAST = **Static** Application Security Testing. "Static" because it scans the **source code itself**, without running the application. No server needs to be up, no request needs to be sent.

## 2. Why It Exists

- Catches vulnerabilities (SQL Injection, hardcoded secrets, insecure deserialization, XSS sinks) **before code is even built or deployed**.
- Cheapest place to fix a bug is in the IDE/PR stage — SAST enforces that this happens automatically, not manually.
- Gives you a security gate in CI so vulnerable code physically cannot merge to `main`.

## 3. Interview-Ready Definition

> SAST is a white-box testing technique that analyzes source code, bytecode, or binaries without executing the program, to detect security vulnerabilities early in the SDLC (shift-left security).

## 4. Tool Choice

| Tool | Type | Best for |
|---|---|---|
| **SonarQube** | Self-hosted server + scanner | Deep quality + security dashboard, PR decoration |
| **Semgrep** | CLI, rule-based | Fast, lightweight, great for GitHub Actions, free OSS rules |

Below covers both — SonarQube for Jenkins, Semgrep for GitHub Actions (most common real-world pairing). You can swap either tool into either pipeline.

---

## 5. SAST on Jenkins (using SonarQube)

### Step 1: Run SonarQube Server
```bash
docker run -d --name sonarqube \
  -p 9000:9000 \
  sonarqube:community
```
Login at `http://localhost:9000` (default: admin/admin), change password.

### Step 2: Generate a Token
SonarQube UI → My Account → Security → Generate Token → copy it.

### Step 3: Install Jenkins Plugins
Jenkins → Manage Jenkins → Plugins → Install:
- `SonarQube Scanner`
- `Pipeline: Stage View` (optional, for visualization)

### Step 4: Configure SonarQube Server in Jenkins
Manage Jenkins → System → SonarQube servers → Add:
- Name: `sonar-server`
- URL: `http://<sonarqube-host>:9000`
- Token: add as Jenkins Credential (Secret Text) → select it here

### Step 5: Configure SonarQube Scanner Tool
Manage Jenkins → Tools → SonarQube Scanner installations → Add → auto-install latest version.

### Step 6: Add Stage to Jenkinsfile
```groovy
pipeline {
    agent any
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/kartavynirwel-code/DevHub-2.0.git'
            }
        }
        stage('SAST - SonarQube Scan') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh """
                        ${SCANNER_HOME}/bin/sonar-scanner \
                        -Dsonar.projectKey=devhub-2.0 \
                        -Dsonar.sources=. \
                        -Dsonar.java.binaries=target/classes
                    """
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
}
```

### Step 7: Add Webhook (for Quality Gate to work)
SonarQube → Administration → Configuration → Webhooks → Add:
`http://<jenkins-host>:8080/sonarqube-webhook/`

**Result**: If code has critical vulnerabilities, `waitForQualityGate` fails the build — merge is blocked.

---

## 6. SAST on GitHub Actions (using Semgrep)

### Step 1: Create Workflow File
Path: `.github/workflows/sast-semgrep.yml`

```yaml
name: SAST - Semgrep Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  semgrep:
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    steps:
      - uses: actions/checkout@v4

      - name: Run Semgrep
        run: semgrep ci --config=auto
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

### Step 2: (Optional) Get a Free Semgrep App Token
For dashboard + PR comments: sign up at semgrep.dev → Settings → Tokens → copy token → add as GitHub repo secret `SEMGREP_APP_TOKEN` (Settings → Secrets and variables → Actions → New repository secret).

### Step 3: (No token version — fully offline/free)
```yaml
      - name: Run Semgrep (offline rules only)
        run: semgrep scan --config=p/owasp-top-ten --config=p/java --error
```
- `--error` makes the step exit non-zero (fails the pipeline) if findings exist.
- `p/owasp-top-ten` and `p/java` are free public rulesets matching your Spring Boot stack.

### Step 4: Fail the PR on High Severity Only (tuned version)
```yaml
      - name: Run Semgrep - block only ERROR severity
        run: semgrep scan --config=p/owasp-top-ten --severity=ERROR --error
```

### Step 5: Push and Verify
Commit the workflow → open a PR → check the "Checks" tab on GitHub → Semgrep job output shows findings inline.

---

## 7. What "Good" Looks Like for DevHub 2.0

- Jenkins: SonarQube stage runs on every build → Quality Gate blocks merge if new critical/blocker issues introduced.
- GitHub Actions: Semgrep runs on every PR → comments directly on the diff lines with the vulnerable pattern.
- Both tools scan **source only** — no app needs to be running. That's the line to remember vs SCA (dependencies) and DAST (running app).
