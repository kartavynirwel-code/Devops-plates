# Custom Kubernetes Controller — Complete Guide

## What We Are Building

A custom Kubernetes controller that watches a custom resource called `DatabaseBackup`.
When you apply a `DatabaseBackup` YAML, the controller automatically takes action.

```
You apply → kubectl apply -f backup.yaml
Controller detects → "New DatabaseBackup found!"
Controller acts → Takes backup, updates status
```

---

## Complete Project Structure

```
my-controller/
├── pom.xml
├── Dockerfile
├── k8s/
│   ├── 1-crd.yaml
│   ├── 2-rbac.yaml
│   ├── 3-controller-deployment.yaml
│   └── 4-sample-resource.yaml
└── src/main/java/com/mycontroller/
    ├── ControllerApplication.java
    ├── model/
    │   ├── DatabaseBackup.java
    │   ├── DatabaseBackupSpec.java
    │   └── DatabaseBackupStatus.java
    └── reconciler/
        └── DatabaseBackupReconciler.java
```

---

## Step 1 — pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>

    <groupId>com.mycontroller</groupId>
    <artifactId>my-controller</artifactId>
    <version>1.0.0</version>
    <name>my-controller</name>

    <properties>
        <java.version>21</java.version>
        <josdk.version>4.4.0</josdk.version>
    </properties>

    <dependencies>

        <!-- Spring Boot -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>

        <!-- Java Operator SDK - Main dependency -->
        <dependency>
            <groupId>io.javaoperatorsdk</groupId>
            <artifactId>operator-framework-spring-boot-starter</artifactId>
            <version>${josdk.version}</version>
        </dependency>

        <!-- Kubernetes Client -->
        <dependency>
            <groupId>io.fabric8</groupId>
            <artifactId>kubernetes-client</artifactId>
            <version>6.8.0</version>
        </dependency>

        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

---

## Step 2 — Model Classes

### DatabaseBackup.java (Resource Definition)

```java
package com.mycontroller.model;

import io.fabric8.kubernetes.api.model.Namespaced;
import io.fabric8.kubernetes.client.CustomResource;
import io.fabric8.kubernetes.model.annotation.Group;
import io.fabric8.kubernetes.model.annotation.ShortNames;
import io.fabric8.kubernetes.model.annotation.Version;

@Group("mycompany.com")           // API group
@Version("v1")                    // API version
@ShortNames("dbb")                // Short name for kubectl
public class DatabaseBackup
        extends CustomResource<DatabaseBackupSpec, DatabaseBackupStatus>
        implements Namespaced {
    // Nothing needed here
    // Parent class handles everything
}
```

---

### DatabaseBackupSpec.java (What User Provides)

```java
package com.mycontroller.model;

import lombok.Data;

@Data
public class DatabaseBackupSpec {

    // Database name to backup
    private String database;

    // Schedule: daily, weekly, manual
    private String schedule;

    // Storage location
    private String storageLocation;

    // Retention days
    private int retentionDays = 7;
}
```

---

### DatabaseBackupStatus.java (What Controller Updates)

```java
package com.mycontroller.model;

import lombok.Data;

@Data
public class DatabaseBackupStatus {

    // PENDING, RUNNING, COMPLETED, FAILED
    private String phase;

    // Last backup time
    private String lastBackupTime;

    // Message for user
    private String message;

    // Number of backups taken
    private int backupCount;
}
```

---

## Step 3 — Main Reconciler (Core Logic)

```java
package com.mycontroller.reconciler;

import com.mycontroller.model.DatabaseBackup;
import com.mycontroller.model.DatabaseBackupStatus;
import io.javaoperatorsdk.operator.api.reconciler.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@ControllerConfiguration(
    // Watch only resources with this label (optional)
    // labelSelector = "managed-by=my-controller"
)
@Component
public class DatabaseBackupReconciler
        implements Reconciler<DatabaseBackup> {

    private static final Logger log =
            LoggerFactory.getLogger(DatabaseBackupReconciler.class);

    @Override
    public UpdateControl<DatabaseBackup> reconcile(
            DatabaseBackup resource,
            Context<DatabaseBackup> context) {

        // This method is called when:
        // 1. New DatabaseBackup is created
        // 2. Existing DatabaseBackup is updated
        // 3. Periodic re-sync happens

        String name = resource.getMetadata().getName();
        String namespace = resource.getMetadata().getNamespace();
        String database = resource.getSpec().getDatabase();
        String schedule = resource.getSpec().getSchedule();

        log.info("=== Reconciling DatabaseBackup ===");
        log.info("Name: {}", name);
        log.info("Namespace: {}", namespace);
        log.info("Database: {}", database);
        log.info("Schedule: {}", schedule);

        try {
            // Set status to RUNNING
            updateStatus(resource, "RUNNING", "Backup in progress...", 0);

            // ==========================================
            // YOUR ACTUAL LOGIC GOES HERE
            // ==========================================
            performBackup(database, resource.getSpec().getStorageLocation());
            // ==========================================

            // Get current backup count
            int currentCount = 0;
            if (resource.getStatus() != null
                    && resource.getStatus().getBackupCount() > 0) {
                currentCount = resource.getStatus().getBackupCount();
            }

            // Update status to COMPLETED
            updateStatus(
                resource,
                "COMPLETED",
                "Backup completed successfully at " + LocalDateTime.now(),
                currentCount + 1
            );

            log.info("Backup completed for database: {}", database);

            // Return updated resource with new status
            return UpdateControl.updateStatus(resource);

        } catch (Exception e) {
            log.error("Backup failed for database: {}", database, e);

            // Update status to FAILED
            updateStatus(resource, "FAILED",
                    "Backup failed: " + e.getMessage(), 0);

            return UpdateControl.updateStatus(resource);
        }
    }

    // Helper method to update status
    private void updateStatus(DatabaseBackup resource,
                               String phase,
                               String message,
                               int backupCount) {
        DatabaseBackupStatus status = new DatabaseBackupStatus();
        status.setPhase(phase);
        status.setMessage(message);
        status.setLastBackupTime(LocalDateTime.now().toString());
        status.setBackupCount(backupCount);
        resource.setStatus(status);
    }

    // Your actual backup logic
    private void performBackup(String database, String location) {
        log.info("Taking backup of database: {} to: {}", database, location);

        // Example: Run a shell command
        // ProcessBuilder pb = new ProcessBuilder(
        //     "pg_dump", "-U", "postgres", database,
        //     "-f", location + "/" + database + ".sql"
        // );
        // pb.start().waitFor();

        // Example: Call an API
        // restTemplate.post("/backup-service/backup", request);

        // For now just simulate
        try {
            Thread.sleep(1000); // Simulate backup taking time
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        log.info("Backup of {} completed!", database);
    }
}
```

---

## Step 4 — Main Application Class

```java
package com.mycontroller;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ControllerApplication {
    public static void main(String[] args) {
        SpringApplication.run(ControllerApplication.class, args);
    }
}
```

---

## Step 5 — application.properties

```properties
# Application name
spring.application.name=my-controller

# Logging
logging.level.com.mycontroller=DEBUG
logging.level.io.javaoperatorsdk=INFO

# Operator config
# Watch all namespaces (empty = all)
# javaoperatorsdk.operators[0].namespaces=default
```

---

## Step 6 — Dockerfile

```dockerfile
# Build stage
FROM maven:3.9.6-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Run stage
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /app/target/*.jar controller.jar
EXPOSE 8080

# Run as non-root user (security best practice)
RUN addgroup --system controller && \
    adduser --system --group controller
USER controller

ENTRYPOINT ["java", "-jar", "controller.jar"]
```

---

## Step 7 — Kubernetes YAML Files

### k8s/1-crd.yaml (Register New Resource Type)

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databasebackups.mycompany.com
spec:
  group: mycompany.com
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                database:
                  type: string
                  description: "Database name to backup"
                schedule:
                  type: string
                  description: "Backup schedule: daily/weekly/manual"
                storageLocation:
                  type: string
                  description: "Where to store backup"
                retentionDays:
                  type: integer
                  description: "How many days to keep backup"
            status:
              type: object
              properties:
                phase:
                  type: string
                lastBackupTime:
                  type: string
                message:
                  type: string
                backupCount:
                  type: integer
      subresources:
        status: {}                # Enable status subresource
      additionalPrinterColumns:  # Show in kubectl get output
        - name: Database
          type: string
          jsonPath: .spec.database
        - name: Phase
          type: string
          jsonPath: .status.phase
        - name: Last-Backup
          type: string
          jsonPath: .status.lastBackupTime
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: databasebackups
    singular: databasebackup
    kind: DatabaseBackup
    shortNames:
      - dbb
```

---

### k8s/2-rbac.yaml (Permissions)

```yaml
# Identity for our controller
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backup-controller-sa
  namespace: default

---
# What our controller is allowed to do
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-controller-role
rules:

  # Permission to watch/manage DatabaseBackup resources
  - apiGroups: ["mycompany.com"]
    resources: ["databasebackups"]
    verbs: ["get", "list", "watch", "update", "patch"]

  # Permission to update status
  - apiGroups: ["mycompany.com"]
    resources: ["databasebackups/status"]
    verbs: ["get", "update", "patch"]

  # Permission to manage Pods (if your controller creates pods)
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "delete"]

  # Permission to manage Jobs (if your controller creates jobs)
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "create", "delete"]

  # Permission to read ConfigMaps and Secrets
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "watch"]

  # Permission to create Events (for logging)
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]

---
# Connect ServiceAccount with ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backup-controller-binding
subjects:
  - kind: ServiceAccount
    name: backup-controller-sa   # Must match ServiceAccount name
    namespace: default
roleRef:
  kind: ClusterRole
  name: backup-controller-role   # Must match ClusterRole name
  apiGroup: rbac.authorization.k8s.io
```

---

### k8s/3-controller-deployment.yaml (Deploy Controller)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backup-controller
  namespace: default
  labels:
    app: backup-controller
spec:
  replicas: 1            # Only 1 replica (leader election needed for multiple)
  selector:
    matchLabels:
      app: backup-controller
  template:
    metadata:
      labels:
        app: backup-controller
    spec:
      # Use the ServiceAccount we created
      serviceAccountName: backup-controller-sa

      containers:
        - name: controller
          image: my-controller:latest
          imagePullPolicy: IfNotPresent

          # Resource limits
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"

          # Environment variables
          env:
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace

          # Health checks
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10

          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 5
```

---

### k8s/4-sample-resource.yaml (Test Your Controller)

```yaml
apiVersion: mycompany.com/v1
kind: DatabaseBackup
metadata:
  name: production-backup
  namespace: default
  labels:
    environment: production
spec:
  database: production-db
  schedule: daily
  storageLocation: /backups/production
  retentionDays: 30

---
apiVersion: mycompany.com/v1
kind: DatabaseBackup
metadata:
  name: staging-backup
  namespace: default
spec:
  database: staging-db
  schedule: weekly
  storageLocation: /backups/staging
  retentionDays: 7
```

---

## Step 8 — Build & Deploy Commands

```bash
# ====================================
# Build the Java Project
# ====================================

# Build jar
mvn clean package -DskipTests

# Build Docker image
docker build -t my-controller:latest .

# (Optional) Push to registry
docker tag my-controller:latest your-registry/my-controller:latest
docker push your-registry/my-controller:latest


# ====================================
# Deploy to Kubernetes
# ====================================

# Step 1: Register the new resource type
kubectl apply -f k8s/1-crd.yaml

# Step 2: Create permissions
kubectl apply -f k8s/2-rbac.yaml

# Step 3: Deploy the controller
kubectl apply -f k8s/3-controller-deployment.yaml

# Step 4: Verify controller is running
kubectl get pods
# backup-controller-xxxx   1/1   Running   0   30s ✅

# Step 5: Check controller logs
kubectl logs -f deployment/backup-controller


# ====================================
# Test Your Controller
# ====================================

# Create a DatabaseBackup resource
kubectl apply -f k8s/4-sample-resource.yaml

# Watch what happens!
kubectl get databasebackup -w
# NAME                 DATABASE       PHASE     LAST-BACKUP
# production-backup    production-db  RUNNING
# production-backup    production-db  COMPLETED 2026-05-31T10:00:00

# See details
kubectl describe databasebackup production-backup

# See all backups
kubectl get dbb   # short name works!

# Delete a backup resource
kubectl delete databasebackup production-backup
```

---

## Step 9 — Verify Everything Works

```bash
# Check CRD is registered
kubectl get crd | grep mycompany
# databasebackups.mycompany.com   2026-05-31T10:00:00Z ✅

# Check RBAC
kubectl get serviceaccount backup-controller-sa
kubectl get clusterrole backup-controller-role
kubectl get clusterrolebinding backup-controller-binding

# Check controller pod
kubectl get pods | grep backup-controller
# backup-controller-7d9b8c-xxxx   1/1   Running   0   2m ✅

# Check controller logs
kubectl logs deployment/backup-controller
# === Reconciling DatabaseBackup ===
# Name: production-backup
# Database: production-db
# Backup completed! ✅

# Check resource status
kubectl get databasebackup
# NAME                DATABASE        PHASE      LAST-BACKUP
# production-backup   production-db   COMPLETED  2026-05-31
```

---

## Complete Flow Summary

```
What happens step by step:

1. kubectl apply -f 1-crd.yaml
   → K8s now knows "DatabaseBackup" resource exists

2. kubectl apply -f 2-rbac.yaml
   → Controller gets identity (ServiceAccount)
   → Controller gets permissions (ClusterRole)
   → Both are connected (ClusterRoleBinding)

3. kubectl apply -f 3-controller-deployment.yaml
   → Your Java program starts running in K8s
   → It uses ServiceAccount for identity
   → It starts watching for DatabaseBackup resources

4. kubectl apply -f 4-sample-resource.yaml
   → New DatabaseBackup resource created in K8s API
   → Controller detects this (it was watching!)
   → reconcile() method is called
   → Controller does its work (backup logic)
   → Controller updates status

5. kubectl get databasebackup
   → You can see status updated by controller ✅
```

---

## Advanced — Add Event Handling

```java
// Handle Delete event
@Override
public DeleteControl cleanup(
        DatabaseBackup resource,
        Context<DatabaseBackup> context) {

    String database = resource.getSpec().getDatabase();
    log.info("DatabaseBackup deleted for: {}", database);

    // Clean up backup files if needed
    cleanupBackupFiles(database);

    return DeleteControl.defaultDelete();
}

private void cleanupBackupFiles(String database) {
    log.info("Cleaning up backup files for: {}", database);
    // Your cleanup logic here
}
```

---

## Advanced — Watch Multiple Resources

```java
@ControllerConfiguration(
    dependents = {
        @Dependent(type = BackupJobDependentResource.class)
    }
)
@Component
public class DatabaseBackupReconciler
        implements Reconciler<DatabaseBackup> {
    // Controller now also watches Jobs it creates
}
```

---

## Troubleshooting

```bash
# Controller not starting?
kubectl describe pod <controller-pod-name>
kubectl logs <controller-pod-name>

# Permission denied error?
# Check RBAC is applied
kubectl auth can-i list databasebackups \
  --as=system:serviceaccount:default:backup-controller-sa

# CRD not found?
kubectl get crd | grep mycompany

# Resource not being reconciled?
kubectl logs deployment/backup-controller | grep "Reconciling"

# Force re-reconcile (add annotation)
kubectl annotate databasebackup production-backup \
  force-sync=$(date +%s) --overwrite
```

---

## Key Concepts Summary

| Term | What It Is | Example |
|------|-----------|---------|
| CRD | Register new resource type | DatabaseBackup type |
| Custom Resource | Instance of CRD | production-backup |
| Controller | Java program watching resources | backup-controller pod |
| Reconciler | Core logic method | reconcile() method |
| ServiceAccount | Controller's identity | backup-controller-sa |
| ClusterRole | What controller can do | list/watch/update |
| ClusterRoleBinding | Connect identity to permissions | SA + Role |
| Operator | CRD + Controller together | Your complete solution |

---

## Interview One-Liners

```
Q: What is a Custom Controller?
A: A program that watches custom K8s resources
   and takes action when they change.
   It implements the reconcile loop pattern.

Q: What is the Reconcile Loop?
A: Controller continuously compares desired state
   (what's in YAML) with actual state (what's running)
   and makes them match.

Q: Why is RBAC needed for controllers?
A: Controller needs to call K8s API to watch
   resources and update status.
   Without RBAC, K8s rejects these calls with 403.

Q: What is an Operator?
A: CRD + Custom Controller together.
   It encodes operational knowledge into code.
   ArgoCD, Prometheus, cert-manager are all operators.
```
