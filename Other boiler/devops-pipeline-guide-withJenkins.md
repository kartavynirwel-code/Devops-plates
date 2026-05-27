# Complete DevOps Pipeline Guide 🚀
### Git → Jenkins → Docker → Ansible → Kubernetes

---

## Poora Flow

```
Developer Code Likhta Hai
          ↓
       Git Push
          ↓
      Jenkins (CI/CD)
      ┌────────────────────────────┐
      │  1. Code Checkout          │
      │  2. Maven Build (JAR)      │
      │  3. Unit Tests             │
      │  4. Docker Image Build     │
      │  5. Image Push (Docker Hub)│
      │  6. Ansible Trigger        │
      │  7. Kubernetes Deploy      │
      └────────────────────────────┘
          ↓
      Ansible (Config)
      (Servers configure karta hai)
          ↓
      Kubernetes (Orchestration)
      ┌──────────────────────────┐
      │  Pod1   Pod2   Pod3      │
      │  :8080  :8080  :8080     │
      └──────────────────────────┘
          ↓
      Load Balancer
          ↓
      App Live! 🎉
```

---

## Har Tool Ka Kaam

| Tool | Kaam | Real Life Example |
|---|---|---|
| **Git** | Code store aur track karo | Office mein file save karna |
| **Jenkins** | Automatically build + deploy karo | Factory machine jo khud kaam kare |
| **Maven** | Java project build karo | JAR file banana |
| **Docker** | App ko container mein pack karo | Tiffin box — har jagah same khana |
| **Docker Hub** | Images store karo | Cloud mein tiffin box rakhna |
| **Ansible** | Servers configure karo | Ek setting — sab servers pe apply |
| **Kubernetes** | Containers manage karo | Manager jo workers ko kaam deta hai |
| **AWS EKS** | Managed Kubernetes | AWS sab handle karta hai |

---

## Project Structure

```
devops-spring-app/
├── src/                      # Java Spring Boot code
├── Dockerfile                # Image kaise bane
├── Jenkinsfile               # Pipeline steps
├── ansible/
│   ├── inventory.ini         # Server list
│   └── deploy.yml            # Ansible playbook
├── k8s/
│   ├── deployment.yaml       # App deploy karo
│   └── service.yaml          # App expose karo
└── pom.xml                   # Maven config
```

---

## Step 1 — Git Setup

```bash
# Repo banao
git init
git remote add origin https://github.com/your-username/devops-spring-app.git

# Code push karo
git add .
git commit -m "initial commit"
git push origin main
```

**Yahi push Jenkins ko trigger karega!**

---

## Step 2 — Dockerfile

```dockerfile
# Stage 1 — Build
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn clean package -DskipTests -q

# Stage 2 — Run
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/devops-spring-app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## Step 3 — Jenkinsfile

```groovy
pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "your-username/devops-spring-app"
        DOCKER_TAG   = "1.0.0"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/your-username/devops-spring-app.git'
            }
        }

        stage('Build JAR') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh "docker login -u $DOCKER_USER -p $DOCKER_PASS"
                    sh "docker push ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }

        stage('Ansible Configure') {
            steps {
                sh 'ansible-playbook ansible/deploy.yml -i ansible/inventory.ini'
            }
        }

        stage('Kubernetes Deploy') {
            steps {
                sh 'kubectl apply -f k8s/deployment.yaml'
                sh 'kubectl apply -f k8s/service.yaml'
                sh 'kubectl rollout status deployment/devops-spring-app'
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline successful — App deployed!'
        }
        failure {
            echo '❌ Pipeline failed — Check logs!'
        }
    }
}
```

---

## Step 4 — Ansible Files

**inventory.ini — Server list**
```ini
[servers]
server1 ansible_host=192.168.1.10 ansible_user=ubuntu
server2 ansible_host=192.168.1.11 ansible_user=ubuntu

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

**deploy.yml — Playbook**
```yaml
---
- hosts: servers
  become: yes
  tasks:

    - name: Docker install karo
      apt:
        name: docker.io
        state: present
        update_cache: yes

    - name: Docker service start karo
      service:
        name: docker
        state: started
        enabled: yes

    - name: kubectl install karo
      snap:
        name: kubectl
        classic: yes

    - name: Old container stop karo
      shell: docker stop devops-spring-app || true

    - name: New image pull karo
      shell: docker pull your-username/devops-spring-app:1.0.0

    - name: Container run karo
      shell: >
        docker run -d
        --name devops-spring-app
        -p 8080:8080
        your-username/devops-spring-app:1.0.0
```

---

## Step 5 — Kubernetes Files

**k8s/deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-spring-app
  labels:
    app: devops-spring-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: devops-spring-app
  template:
    metadata:
      labels:
        app: devops-spring-app
    spec:
      containers:
        - name: devops-spring-app
          image: your-username/devops-spring-app:1.0.0
          ports:
            - containerPort: 8080
          livenessProbe:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 20
            periodSeconds: 5
```

**k8s/service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-spring-app-service
spec:
  selector:
    app: devops-spring-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: LoadBalancer    # EKS pe AWS ALB automatically banega
                        # Minikube pe NodePort likho
```

---

## Jenkins Install karo (Local)

```bash
# Docker se Jenkins chalao — sabse aasaan
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Password lo
docker logs jenkins
# Ya
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Browser mein kholo
# http://localhost:8080
```

---

## Ansible Install karo

```bash
# Ubuntu/Linux
sudo apt update
sudo apt install ansible -y

# Verify
ansible --version

# Test connection
ansible all -i inventory.ini -m ping
```

---

## Full Pipeline Ek Nazar Mein

```
┌─────────────────────────────────────────────────────────┐
│                    DEVELOPER                             │
│              git push origin main                        │
└──────────────────────┬──────────────────────────────────┘
                       ↓ webhook trigger
┌──────────────────────────────────────────────────────────┐
│                    JENKINS                                │
│  Checkout → Build → Test → Docker Build → Docker Push    │
└──────────────────────┬───────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────────┐
│                    ANSIBLE                                │
│         Servers configure karo → Dependencies install    │
└──────────────────────┬───────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────────┐
│                  KUBERNETES (EKS)                         │
│         Pod1 ── Pod2 ── Pod3                             │
│              Load Balancer                                │
└──────────────────────┬───────────────────────────────────┘
                       ↓
                   USER 🎉
              http://aws-lb-url/api/hello
```

---

## Learning Order

```
Week 1  Docker + Kubernetes    ✅ Ho gaya!
Week 2  Jenkins install
        Jenkinsfile likhna
        Pipeline banana
Week 3  Ansible basics
        Playbook likhna
        Servers configure karna
Week 4  Sab ek saath connect karo
        Git push → Auto deploy 🎉
```

---

## Important Commands

```bash
# Jenkins
docker start jenkins
docker stop jenkins
docker logs jenkins

# Ansible
ansible-playbook deploy.yml -i inventory.ini
ansible all -m ping -i inventory.ini

# Kubernetes
kubectl apply -f k8s/
kubectl get pods
kubectl get service
kubectl rollout status deployment/devops-spring-app
kubectl logs -f <pod-name>

# Docker
docker build -t your-username/devops-spring-app:1.0.0 .
docker push your-username/devops-spring-app:1.0.0
docker images
```

---

## Next Steps — Advanced

| Topic | Kya Seekhna Hai |
|---|---|
| **GitHub Actions** | Jenkins ka alternative — cloud based CI/CD |
| **Helm** | Kubernetes ke liye package manager |
| **Prometheus + Grafana** | App monitoring |
| **ArgoCD** | GitOps — Git se auto deploy |
| **Terraform** | Infrastructure as Code |
| **AWS ECR** | Docker Hub ka AWS alternative |


---
---
deployment.yaml     service.yaml       ingress.yaml
───────────────     ────────────       ────────────
kind: Deployment    kind: Service      kind: Ingress

spec:               spec:              spec:
  replicas: 3         selector:          rules:
  template:             app: xyz           - host:
    containers:       ports:                 paths:
      - image: xyz      - port: 80             - path: /
        port: 8080        target: 8080           backend:
                      type: NodePort               service:

"App chalao"        "App expose karo"  "Traffic route karo"
---
*"Ek baar pipeline set karo — phir sirf git push karo, baaki sab automatic!"* 🚀
