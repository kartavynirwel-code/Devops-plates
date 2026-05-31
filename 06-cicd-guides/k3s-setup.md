# K3s Setup Guide on EC2

## Prerequisites
- Ubuntu EC2 instance
- SSH access
- sudo privileges

---

## Step 1 — Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
```

Verify installation:
```bash
sudo kubectl get nodes
```

Expected output:
```
NAME    STATUS   ROLES                  AGE
ip-xx   Ready    control-plane,master   30s
```

---

## Step 2 — User Access Setup

```bash
# Config directory banao
mkdir -p ~/.kube

# K3s config copy karo
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Permission do
sudo chown $USER:$USER ~/.kube/config

# Test karo
kubectl get nodes
```

Permanent setup (har session mein kaam kare):
```bash
echo "export KUBECONFIG=~/.kube/config" >> ~/.bashrc
source ~/.bashrc
```

---

## Step 3 — Jenkins Access Setup

```bash
# Jenkins ke liye .kube directory banao
sudo mkdir -p /var/lib/jenkins/.kube

# Config copy karo
sudo cp /etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config

# Permission do
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

# Verify - jenkins user se test karo
sudo -u jenkins kubectl get nodes
```

Expected output:
```
NAME    STATUS   ROLES                  AGE
ip-xx   Ready    control-plane,master   5m
```

---

## Step 4 — Docker Setup for Jenkins

```bash
# Jenkins ko docker group mein add karo
sudo usermod -aG docker jenkins

# Restart jenkins
sudo systemctl restart jenkins

# Verify
sudo -u jenkins docker ps
```

---

## Step 5 — Deployment.yaml Update

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
      - name: spring-app
        image: my-boot:latest
        imagePullPolicy: IfNotPresent   # Never nahi, IfNotPresent use karo
        ports:
        - containerPort: 8080
```

---

## Step 6 — Jenkinsfile (Clean - No Hardcoding)

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }
        stage('Docker Build & Deploy') {
            steps {
                sh '''
                    docker build -t my-boot:latest .
                    kubectl apply -f K8s/Deployment.yaml
                    kubectl rollout restart deployment/spring-app
                '''
            }
        }
    }
    post {
        success {
            mail to: 'kartavynirwel77@gmail.com',
                 subject: "✅ Build #${BUILD_NUMBER} Successful!",
                 body: "Website update ho gayi!\n${BUILD_URL}"
        }
        failure {
            mail to: 'kartavynirwel77@gmail.com',
                 subject: "❌ Build #${BUILD_NUMBER} Failed!",
                 body: "Check karo: ${BUILD_URL}"
        }
    }
}
```

---

## Quick Commands Reference

```bash
# Pods check karo
kubectl get pods

# Service check karo
kubectl get svc

# App URL nikalo
kubectl get svc spring-app

# Logs dekho
kubectl logs -f deployment/spring-app

# K3s status
sudo systemctl status k3s

# K3s restart
sudo systemctl restart k3s
```

---

## Local (Minikube) vs EC2 (K3s)

| Cheez            | Minikube (Local)         | K3s (EC2)              |
|------------------|--------------------------|------------------------|
| Use case         | Learning only            | Production ready       |
| Docker env       | eval $(minikube docker-env) | Direct docker build |
| Hardcoding       | Zarurat padti hai        | Kuch nahi              |
| imagePullPolicy  | Never                    | IfNotPresent           |
| kubectl config   | Auto set hota hai        | Manual copy karna padta|
| Cost             | Free (local)             | EC2 cost               |

---

## Troubleshooting

**kubectl: Authentication required**
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

**Jenkins kubectl nahi chal raha**
```bash
sudo cp /etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
```

**Docker permission denied**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**Pod ImagePullBackOff**
```bash
# imagePullPolicy check karo
kubectl describe pod <pod-name>
# Deployment.yaml mein IfNotPresent karo
```
