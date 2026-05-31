# Jenkins Boilerplates — Java Spring Boot

---

## Folder Structure

```
jenkins/
├── declarative/
│   ├── Jenkinsfile-basic       → Simple CI/CD
│   └── Jenkinsfile-advanced    → Multi-env + Approval
├── scripted/
│   ├── Jenkinsfile-basic       → Simple Groovy pipeline
│   └── Jenkinsfile-advanced    → Parallel + Auto rollback
└── README.md
```

---

## Declarative vs Scripted

```
Declarative                  Scripted
───────────                  ────────
pipeline { }                 node { }
Easy to read                 More flexible
Less code                    More code
Structured                   Full Groovy
Beginners ke liye            Advanced use cases
```

---

## Which File to Use?

| File | Use When |
|---|---|
| `declarative/Jenkinsfile-basic` | Simple project, start karo yahan se |
| `declarative/Jenkinsfile-advanced` | Dev/Staging/Prod environments |
| `scripted/Jenkinsfile-basic` | Groovy sikna hai |
| `scripted/Jenkinsfile-advanced` | Parallel tests + Auto rollback |

---

## Pipeline Stages

```
Checkout → Build → Test → Docker Build
       → Docker Push → Deploy → Done!
```

---

## Jenkins Mein Setup Karna

### 1. Credentials Add Karo
```
Jenkins → Manage Jenkins → Credentials → Add

ID: docker-hub-creds
Username: your-dockerhub-username
Password: your-dockerhub-password
```

### 2. Tools Configure Karo
```
Jenkins → Manage Jenkins → Global Tool Configuration

Maven: Maven-3.9
JDK:   JDK-17
```

### 3. Pipeline Job Banao
```
New Item → Pipeline → OK
Pipeline → Pipeline script from SCM
SCM → Git
Repository URL → your github repo
Script Path → jenkins/declarative/Jenkinsfile-basic
```

---

## Important Variables

```groovy
APP_NAME     = 'devops-spring-app'
DOCKER_IMAGE = 'your-username/devops-spring-app'
DOCKER_TAG   = "${BUILD_NUMBER}"    // Auto increment
```

---

## Key Concepts Used

| Concept | Where |
|---|---|
| `withCredentials` | Docker Hub login |
| `parallel` | Tests ek saath chalao |
| `input` | Manual approval |
| `archiveArtifacts` | JAR save karo |
| `junit` | Test reports |
| `cleanWs` | Workspace clean |
| `helm upgrade --install` | K8s deploy |
| `kubectl rollout status` | Deploy verify |
| `try/catch` | Error handle + rollback |

---

## Start Karo

```bash
# Sabse pehle yeh use karo
jenkins/declarative/Jenkinsfile-basic

# Samajh aaya → Advanced try karo
jenkins/declarative/Jenkinsfile-advanced
```

---

*"Push karo — Pipeline sab kuch karega!"* 🚀
