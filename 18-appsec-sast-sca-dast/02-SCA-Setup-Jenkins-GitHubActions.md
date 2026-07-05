# SCA Setup — Jenkins & GitHub Actions

## 1. Analogy First

Think of SCA like a **restaurant checking the ingredients it buys from suppliers**, not the food it cooks itself. Your chef (your own code) might be perfectly clean, but if the flour supplier (an open-source library like Log4j) is contaminated, the whole dish is unsafe — no matter how well you cooked it.

SCA = **Software Composition Analysis**. It doesn't look at code you wrote — it looks at the **third-party/open-source dependencies** you pulled in (Maven, npm, pip packages).

## 2. Why It Exists

- 70-90% of a typical app's codebase is open-source dependencies, not your own code.
- Famous incidents (Log4Shell, Equifax/Struts) happened because a known-vulnerable **dependency** was used, not because of code someone wrote in-house.
- SCA cross-checks your `pom.xml` / `package.json` / `requirements.txt` against CVE databases (NVD) and flags known vulnerable versions.

## 3. Interview-Ready Definition

> SCA identifies open-source and third-party components in an application, maps them against known vulnerability databases (CVE/NVD), and flags outdated or vulnerable versions, along with license compliance risks.

## 4. Tool Choice

| Tool | Best for |
|---|---|
| **OWASP Dependency-Check** | Maven/Java native, deep NVD-based CVE matching |
| **Trivy** | Fast, also scans containers/IaC, single binary, great for GitHub Actions |

You already found 4 CRITICAL Tomcat CVEs in the DevHub image using Trivy — this is the same tool, now applied to the **dependency/filesystem** scan mode instead of image mode.

---

## 5. SCA on Jenkins (using OWASP Dependency-Check)

### Step 1: Install the Jenkins Plugin
Manage Jenkins → Plugins → Install: `OWASP Dependency-Check Plugin`

### Step 2: Configure the Tool
Manage Jenkins → Tools → Dependency-Check installations → Add:
- Name: `dependency-check`
- Install automatically → select latest version

### Step 3: Add Stage to Jenkinsfile
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/kartavynirwel-code/DevHub-2.0.git'
            }
        }
        stage('Build') {
            steps {
                sh 'mvn clean install -DskipTests'
            }
        }
        stage('SCA - Dependency-Check Scan') {
            steps {
                dependencyCheck additionalArguments: '''
                    --scan .
                    --format HTML
                    --format XML
                    --project devhub-2.0
                ''', odcInstallation: 'dependency-check'
            }
        }
        stage('Publish Report') {
            steps {
                dependencyCheckPublisher pattern: 'dependency-check-report.xml'
            }
        }
    }
}
```

### Step 4: Set a Failure Threshold (Fail Build on High CVSS)
```groovy
dependencyCheckPublisher pattern: 'dependency-check-report.xml', failedTotalCritical: 1
```
This fails the Jenkins build if even 1 CRITICAL vulnerability is found — same philosophy as your Trivy CRITICAL findings on the Tomcat image.

### Step 5: View Report
Jenkins job → Build → "Dependency-Check Report" link in sidebar → HTML report with CVE IDs, CVSS scores, affected library + version.

---

## 6. SCA on GitHub Actions (using Trivy)

### Step 1: Create Workflow File
Path: `.github/workflows/sca-trivy.yml`

```yaml
name: SCA - Trivy Dependency Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  trivy-sca:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy filesystem scan (dependencies)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          format: 'table'
          exit-code: '1'
```

### Step 2: Add SARIF Output for GitHub Security Tab (Recommended)
```yaml
      - name: Run Trivy (SARIF for Security tab)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload SARIF to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

### Step 3: Push and Verify
- Commit workflow → open PR → check Actions tab for pass/fail.
- If SARIF step used: Repo → Security tab → Code scanning alerts → shows each vulnerable dependency with CVE + fixed version.

### Step 4: (Optional) Add Maven-Specific Depth
If you want CVE matching tuned specifically for your `pom.xml` (Spring Boot deps), add:
```yaml
      - name: Run Trivy with Maven lockfile awareness
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: 'pom.xml'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
```

---

## 7. What "Good" Looks Like for DevHub 2.0

- Jenkins: Dependency-Check runs post-`mvn install`, fails build on CRITICAL CVEs in `pom.xml` dependencies.
- GitHub Actions: Trivy `fs` scan runs on every PR, results visible in the Security tab, not just console logs.
- Key distinction to keep straight for interviews: **SAST reads code you wrote, SCA reads code you imported.**
