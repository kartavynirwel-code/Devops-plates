# Git Security

Secrets ko Git me leak hone se rokna aur access control — pehli line of defense in DevSecOps.

---

## 1. .gitignore

Sensitive files ko commit hone se rokta hai.

```
.env
*.pem
application-prod.yml
terraform.tfvars
*.tfstate
```

---

## 2. Native Git Pre-Commit Hooks

Script jo commit se **pehle** chalti hai, locally.

```bash
nano .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

```bash
#!/bin/bash
if git diff --cached | grep -i 'password'; then
  echo "ERROR: Password found in code!"
  exit 1
fi
```

---

## 3. Gitleaks — Secret Scanner

Staged files, full repo, aur history — teeno scan kar sakta hai.

```bash
# install
brew install gitleaks   # mac
# or download binary from github.com/gitleaks/gitleaks

# block commits with secrets
gitleaks protect --staged

# scan entire repo
gitleaks detect --source=. -v

# scan git history
gitleaks detect --source=. --log-opts='HEAD~10..HEAD'
```

### GitHub Actions integration

```yaml
# .github/workflows/gitleaks.yml
name: Gitleaks Secret Scan
on: [push, pull_request]
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
```

Custom rules go in `.gitleaks.toml` at repo root.

---

## 4. Branch Protection Rules

| Rule | Effect |
|---|---|
| Require PR reviews | ≥1 reviewer approval needed |
| Require status checks | CI must pass before merge |
| Block force push | History cannot be overwritten |
| Require signed commits | Verifies author identity |

Set in: GitHub → Settings → Branches → Branch protection rules.

---

## 5. RBAC (Repo-level)

| Role | GitHub | Kubernetes | AWS |
|---|---|---|---|
| Admin | Full access | cluster-admin | AdministratorAccess |
| Developer | Write to repos | namespace edit | Developer policy |
| Viewer | Read only | view role | ReadOnly policy |

---

## 6. CODEOWNERS

Auto-assigns reviewers based on which files changed.

```
# .github/CODEOWNERS
* @kartavynirwel-code
/backend/ @backend-team
/terraform/ @infra-team
```

---

## 7. Dependabot

Auto-scans dependencies, opens PRs for vulnerable versions.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: maven   # Java/Spring Boot
    directory: /
    schedule:
      interval: weekly
```

---

## 8. Threat Modeling — STRIDE

Attacker jaisa sochna, system banane se pehle.

1. Kya bana rahe hain? (system diagram)
2. Kya galat ho sakta hai? (threats)
3. Kya karenge iske baare mein? (mitigations)
4. Kya sahi kiya? (validate)

| Letter | Threat | Example |
|---|---|---|
| S | Spoofing | Login as another user |
| T | Tampering | Change order amount in DB |
| R | Repudiation | "I never deleted that file" |
| I | Info Disclosure | API returns passwords |
| D | Denial of Service | DDoS attack |
| E | Elevation of Privilege | User becomes root |

---

## Interview Questions

**Q: What is Gitleaks and how does it fit into CI/CD?**
Open-source secret scanner for Git repos — hardcoded API keys, passwords, tokens catch karta hai. Pre-commit hook ke roop me local, aur GitHub Actions me CI stage par run hota hai — dono jagah defense-in-depth ke liye.

**Q: Difference between pre-commit hook and CI-stage scan?**
Pre-commit hook developer's local machine par commit se pehle rokta hai (fast feedback). CI scan pushed/PR code par server-side check hai — bypass-proof, kyunki `--no-verify` se local hook skip ho sakta hai.

**Q: What is CODEOWNERS?**
File jo define karti hai kaun kis part of codebase ka owner hai — wo automatically reviewer add ho jaata hai jab uski files change hoti hain.

**Q: What is STRIDE?**
Microsoft ka threat modeling framework — Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege.
