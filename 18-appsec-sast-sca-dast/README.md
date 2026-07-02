# AppSec — SAST · SCA · DAST

Ek building ki security 3 jagah check hoti hai: blueprint (SAST), material (SCA), live inspection (DAST). Teeno complement karte hain, koi ek dusre ka replacement nahi.

---

## 1. SAST — Static Application Security Testing

**Analogy:** Teacher tumhara exam paper check kar raha hai bina tumse question solve karwaye — sirf working padh kar galti bata deta hai. Code run nahi ho raha, sirf padha ja raha hai.

**Why it exists:** Application run hone se pehle hi bugs pakadna sasta hai. Manual review hazaaron lines ke liye scale nahi karta.

**Technical definition:** White-box testing technique jo source code/bytecode/binary ko bina execute kiye analyze karta hai — SQL Injection, hardcoded secrets, buffer overflow jaisi vulnerabilities development phase (commit/PR stage) me hi identify karta hai.

**Tools:** SonarQube, Semgrep, Checkmarx, Fortify, Bandit (Python), SpotBugs (Java), Gitleaks (secrets-specific)

**Catches:** SQLi patterns, hardcoded secrets, weak crypto (MD5), command injection, insecure deserialization

**Limitation:** Runtime behavior nahi dekhta → false positives zyada, aur runtime-only bugs (misconfigured headers) miss karta hai.

---

## 2. SCA — Software Composition Analysis

**Analogy:** Apna recipe (code) sahi hai, lekin bazaar se mangwaye ingredients (dependencies) agar expired/contaminated hain to pura khana kharab. SCA us sauce bottle ka label check karta hai.

**Why it exists:** 70-90% modern application code third-party/open-source hota hai. Ek vulnerable dependency (Log4j jaisi) se attacker andar aa sakta hai, chahe apna code perfect ho. Transitive dependencies manually track karna impossible hai.

**Technical definition:** Third-party/open-source dependencies ko scan karke known CVEs, outdated versions, license compliance issues identify karta hai. SBOM (Software Bill of Materials) generate karta hai.

**Tools:** OWASP Dependency-Check, Snyk, Trivy (dependency scanning bhi), GitHub Dependabot

**Catches:** Known CVEs (e.g. Log4Shell — CVE-2021-44228), outdated/EOL packages, license risks, transitive dependency vulnerabilities

**Limitation:** Sirf known vulnerabilities (public DB me report hui) pakadta hai — zero-days miss. Apna business logic code scan nahi karta.

---

## 3. DAST — Dynamic Application Security Testing

**Analogy:** Security guard — building already ban chuki hai aur chal rahi hai. Blueprint nahi dekhta, asli me darwaze khinchke check karta hai, fire alarm bajakar dekhta hai. Black-box — andar ki wiring nahi pata, bas bahar se attacker jaisa behave karta hai.

**Why it exists:** Bahut si vulnerabilities sirf running application me dikhti hain — server misconfig, auth bypass, session issues, ya multi-component interaction bugs. Attacker ke paas source code nahi hota — usi tarah test karna padta hai.

**Technical definition:** Black-box testing technique jo running application ko bina source code access ke bahar se test karta hai — real HTTP requests bhejkar. Typically staging/pre-prod me, SDLC ke baad ke stage par run hota hai.

**Tools:** OWASP ZAP (free, most popular), Burp Suite (industry standard), Nikto (web server scanner)

**Catches:** Exploitable SQLi/XSS (proof of exploit), auth/session flaws, server misconfig, broken access control

**Limitation:** Line number nahi milta — sirf symptom pata chalta hai. Crawler ko jo pages nahi milte, wo untested reh jaate hain. SAST/SCA se slow hai.

---

## 4. Why All Three Together

| Aspect | SAST | SCA | DAST |
|---|---|---|---|
| Scans | Apna source code | 3rd-party dependencies | Running application |
| Kab run hota hai | Commit/PR stage | Build stage | Staging/pre-prod |
| Box type | White-box | White-box (metadata) | Black-box |
| Access chahiye | Source code | Manifest files | Sirf running URL |
| Pakadta hai | Insecure code patterns | Known CVEs in libs | Exploitable runtime flaws |
| Miss karta hai | Runtime issues | Custom code bugs | Exact code location |

**Real example:** Log4Shell (2021) — dependency ka bug tha, apna code SAST-clean ho sakta tha, lekin SCA isse pakad leta. Ek SQL query me user input direct concatenate karna SAST pakadega. Auth logic me subtle flaw jisse URL manipulate karke admin panel access ho jaaye — wo sirf DAST se real-world testing me pakda jaayega.

> **Interview line:** "SAST, SCA aur DAST ek defense-in-depth strategy banate hain — har layer alag type ki weakness cover karti hai, teeno combine karne se hi coverage complete hoti hai."

---

## 5. How Tools Actually Find Vulnerabilities

**SAST internals:** Code ko parse karke Abstract Syntax Tree (AST) banata hai. Do techniques:
- **Pattern/rule matching** — dangerous patterns dhundta hai (e.g. unparameterized SQL query)
- **Taint analysis** — untrusted data (source, jaise HTTP input) ko track karta hai ki wo kabhi dangerous function (sink, jaise DB query) tak bina sanitize hue pahunchta hai ya nahi

**SCA internals:** Manifest files (package.json, pom.xml, requirements.txt) padh kar dependency tree (direct + transitive) banata hai, fir har package ko vulnerability DB (NVD, OSV) se match karta hai → CVE ID + CVSS score + fix version.

**DAST internals:** Two phases —
- **Crawling** — pages, forms, API endpoints discover karta hai
- **Active scanning** — malicious payloads bhejta hai (`' OR '1'='1` for SQLi, `<script>alert(1)</script>` for XSS) aur response analyze karta hai

---

## 6. Attacker Mindset

### SQL Injection — Step by Step

```
query = "SELECT * FROM users WHERE username = '" + username + "' AND password = '" + password + "'"
```

Attacker payload: `admin' --`

```
SELECT * FROM users WHERE username = 'admin' --' AND password = '...'
```

`--` SQL comment start karta hai → password check ignore ho jaata hai → attacker bina password ke login.

### Broken Access Control / IDOR

```
GET /api/orders/1042
```

Agar backend sirf order ID check karta hai (ye verify nahi karta ki order login user ka hi hai), attacker sirf number badal ke sabka data nikaal sakta hai — `1043, 1044, 1045...`. SAST/SCA easily nahi pakadte (code syntactically clean) — DAST + manual testing zaroori.

### General Attack Pattern

Recon (explore endpoints) → Probe (unexpected input daalo) → Exploit (weakness use karo) → Escalate (chhota access → bada access)

---

## 7. Fixes

**SQL Injection — Parameterized Queries**

```
query = "SELECT * FROM users WHERE username = ? AND password = ?"
execute(query, [username, password])
```

Data query ka part kabhi nahi banta. ORMs (Hibernate, JPA) by-default parameterized queries generate karte hain.

**Broken Access Control — Object-Level Authorization**

```
if order.user_id != current_user.id:
    return 403 Forbidden
```

Frontend pe hide karna kaafi nahi — server-side check hamesha zaroori. (OWASP Top 10 #1 risk.)

**SCA findings** — patched version check karo → direct dependency ho to version bump + regression test → transitive ho to dependency override force karo → zero-day ho to temporary mitigation (feature disable / WAF rule)

**General principles:** Never trust user input · Principle of Least Privilege · Defense in Depth · Shift Left

---

## 8. Hands-On Flow

1. **Build** — vulnerable app (OWASP Juice Shop / DVWA) via Docker
2. **SAST** — Semgrep / SonarQube on source
3. **SCA** — Trivy / OWASP Dependency-Check on dependencies
4. **DAST** — OWASP ZAP against running app + manual SQLi/XSS
5. **Fix** — pick one vuln, fix code, re-scan to confirm

```bash
# vulnerable app
docker run -d -p 3000:3000 bkimminich/juice-shop

# SAST
pip install semgrep --break-system-packages
semgrep --config auto /path/to/source

# SCA
trivy fs /path/to/source

# DAST
docker run -t owasp/zap2docker-stable zap-baseline.py -t http://localhost:3000
```

### DevHub 2.0 integration

Gitleaks (secrets) + Trivy (SCA-ish, image scanning) already in the pipeline. Add a dedicated Semgrep (SAST) stage + ZAP baseline scan (DAST) against staging URL → complete SAST+SCA+DAST loop. Strong resume/interview talking point.

---

## Interview Questions

**Q: SAST vs DAST — key difference?**
SAST white-box hai — source code ko bina run kiye analyze karta hai, commit stage par. DAST black-box hai — running application ko bahar se real attacker jaisa test karta hai, staging stage par.

**Q: Ek hi tool kaafi kyun nahi?**
Teeno alag jagah aur alag stage par kaam karte hain. SAST apna code dekhta hai, SCA dependencies, DAST runtime behavior. Koi bhi ek akela dusre do ki coverage nahi de sakta.

**Q: What is taint analysis?**
SAST technique jo untrusted data (source) ko track karta hai code ke through — kya wo kabhi dangerous function (sink) tak bina sanitize hue pahunchta hai.

**Q: What is IDOR and how do you fix it?**
Insecure Direct Object Reference — ID/reference manipulate karke unauthorized data access. Fix: server-side object-level authorization check — hamesha verify karo ki resource current user ka hi hai.

**Q: SBOM kya hai?**
Software Bill of Materials — application me use ho rahe har dependency ki poori inventory, SCA tool generate karta hai.
