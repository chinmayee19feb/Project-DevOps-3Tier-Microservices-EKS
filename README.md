# 🗳️ 3-Tier Cloud Wars Voting Application on Amazon EKS

> A production-grade, microservices-based voting application deployed on Amazon EKS with HTTPS, WebSocket support, CI/CD automation, and Prometheus + Grafana monitoring.
> 
---

## 🏗️ Architecture Diagram

<img width="4893" height="2519" alt="3-Tier App on Amazon EKS Cluster drawio" src="https://github.com/user-attachments/assets/e850debb-646e-4581-99f6-fe276c9a2d20" />

---
## 📖 Project Overview
This project deploys a multi-language microservices voting application on Amazon EKS. Users vote between AWS and Azure (Cloud Wars), and results are displayed in real-time via WebSocket.
---

## 🌐 Live Application

The application was deployed on Amazon EKS and tested using custom DNS endpoints.

### Vote Dashboard
---
https://ai-fairy-vote.duckdns.org

<img width="1915" height="901" alt="Screenshot 2026-03-11 210912" src="https://github.com/user-attachments/assets/d548e3a8-1e02-45fd-a834-3c0b7055cea5" />
<img width="1917" height="860" alt="Screenshot 2026-03-11 231100" src="https://github.com/user-attachments/assets/b635a6cc-5d0c-4148-bfcb-0e87bcb4d387" />

### Results Dashboard
---
https://ai-fairy-result.duckdns.org

**Normal Result**
---
<img width="1906" height="969" alt="Screenshot 2026-03-11 231117" src="https://github.com/user-attachments/assets/b02631f7-9321-47ba-bb44-4d59e3b2de42" />

**Tie Scenario** 
---
<img width="1902" height="967" alt="Screenshot 2026-03-11 231240" src="https://github.com/user-attachments/assets/c27ce9b8-f86a-457b-9929-fad4fe9f937b" />

### Technologies Used
---

| Category | Technology |
|----------|-----------|
| Cloud | AWS (EKS, VPC, EBS, ALB, IAM) |
| Orchestration | Kubernetes 1.34 |
| Ingress | Community NGINX Ingress Controller |
| TLS | cert-manager + Let's Encrypt |
| DNS | DuckDNS (free dynamic DNS) |
| CI/CD | GitHub Actions |
| Container Registry | Docker Hub |
| Monitoring | Prometheus + Grafana |
| Languages | Python (Flask), Node.js (Socket.IO), .NET |

---

## 🧩 Application Components
---
The application is composed of multiple microservices that work together to process votes and display results in real time.

### Service Details

| Service | Technology | Image | Replicas | Role |
|--------|------------|-------|----------|------|
| Vote | Python (Flask) | chinmayee606/vote:latest | 2 | Web UI where users cast votes |
| Result | Node.js (Socket.IO) | chinmayee606/result:latest | 2 | Displays real-time voting results |
| Worker | .NET | chinmayee606/worker:latest | 1 | Processes votes from Redis and stores them in PostgreSQL |
| Redis | Redis | redis:6-alpine | 1 | Temporary queue for vote messages |
| PostgreSQL | PostgreSQL | postgres:15-alpine | 1 | Persistent database storing vote results |

---

### 🔄 Data Flow (Vote to Result)


---

### Data Flow (Vote to Result)

```
User clicks Vote
       │
       ▼
Vote Service (Flask/Python)
       │
       │ rpush vote data as JSON
       ▼
Redis (Temporary Queue)
       │
       │ Worker consumes from queue
       ▼
Worker Service (.NET)
       │
       │ INSERT/UPDATE vote in database
       ▼
PostgreSQL (Persistent Store on EBS)
       │
       │ Result reads from database
       ▼
Result Service (Node.js)
       │
       │ Emit via Socket.IO (WebSocket)
       ▼
User sees live results in browser
```

---

## ☁️ AWS Infrastructure

### EKS Cluster

| Property | Value |
|----------|-------|
| Cluster Name | `chinmayee-3tier-cluster` |
| Kubernetes Version | 1.34 |
| Region | us-east-2 (Ohio) |
| Platform | EKS (eks.17) |
| Created With | `eksctl` |
| Authentication Mode | API_AND_CONFIG_MAP |

### EKS Cluster Overview
---
<img width="1901" height="725" alt="Screenshot 2026-03-11 225026" src="https://github.com/user-attachments/assets/24087a42-8fe6-4203-b690-b2d707ad2661" />
<img width="1894" height="879" alt="Screenshot 2026-03-11 225133" src="https://github.com/user-attachments/assets/33ad0904-7f91-4bc1-a693-ede0265f489c" />

### Node Group
---
| Property | Value |
|----------|-------|
| Name | ng-87cea84e |
| Instance Type | m7i-flex.large |
| AMI | Amazon Linux 2023 (AL2023_x86_64_STANDARD) |
| Min/Max/Desired | 1 / 3 / 2 |
| Container Runtime | containerd 2.1.5 |

<img width="1884" height="854" alt="Screenshot 2026-03-11 225437" src="https://github.com/user-attachments/assets/c5420cb6-1e8e-488b-8531-180670d2ca33" />

### Nodes
---
| Node | Internal IP | External IP | Status |
|------|------------|-------------|--------|
| ip-192-168-48-249.us-east-2.compute.internal | 192.168.48.249 | 18.223.156.148 | Ready |
| ip-192-168-7-243.us-east-2.compute.internal | 192.168.7.243 | 18.222.46.190 | Ready |

<img width="1890" height="817" alt="Screenshot 2026-03-11 230530" src="https://github.com/user-attachments/assets/9342b2a4-8c82-4982-a2fe-98311cec3f85" />

### Pods
---
The console view shows the running pods for the Vote, Result, Worker, Redis, and PostgreSQL services.
<img width="1890" height="865" alt="Screenshot 2026-03-11 230809" src="https://github.com/user-attachments/assets/93ae2619-951b-4c0a-a152-839e1945dd39" />


### VPC & Networking

| Resource | ID |
|----------|-----|
| VPC | vpc-000d7891d3195bb57 |
| Subnets | 6 subnets (3 public, 3 private across AZs) |
| Security Group | sg-00ebd081018523ea6 |
| Service CIDR | 10.100.0.0/16 |

### Storage

| Resource | Type | Size | StorageClass |
|----------|------|------|-------------|
| chinmayee-postgres-pvc | EBS (gp2) | 5Gi | gp2 |

---

## ☸️ Kubernetes Design

### Namespace Isolation

All application resources are deployed in a dedicated namespace: **`chinmayee`**

This ensures clean separation within a shared EKS cluster.

### Deployments

| Deployment | Replicas | Resource Requests | Resource Limits |
|-----------|----------|-------------------|-----------------|
| chinmayee-deployment-vote | 2 | 100m CPU, 128Mi | 500m CPU, 256Mi |
| chinmayee-deployment-result | 2 | 250m CPU, 256Mi | 1 CPU, 512Mi |
| chinmayee-deployment-worker | 1 | — | — |
| chinmayee-deployment-postgres | 1 | — | — |
| chinmayee-deployment-redis | 1 | — | — |

### Services (ClusterIP)

All services use **ClusterIP** type — no hard-coded IPs. Inter-service communication via Kubernetes DNS.

| Service | ClusterIP | Port | Target |
|---------|-----------|------|--------|
| chinmayee-svc-vote | 10.100.58.68 | 80 | Vote pods |
| chinmayee-svc-result | 10.100.146.26 | 80 | Result pods |
| chinmayee-svc-redis | 10.100.121.237 | 6379 | Redis pod |
| chinmayee-svc-postgres | 10.100.226.15 | 5432 | PostgreSQL pod |

### Persistent Volume

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: chinmayee-postgres-pvc
  namespace: chinmayee
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
  storageClassName: gp2
```
### Persistent Storage

PostgreSQL uses a **PersistentVolumeClaim backed by Amazon EBS** to ensure vote data persists across pod restarts.

To avoid filesystem conflicts caused by the default `lost+found` directory on EBS volumes, the database uses a subdirectory:

PGDATA=/var/lib/postgresql/data/pgdata

This ensures reliable initialization of the PostgreSQL data directory.

---

### Kubernetes Verification (CLI)

The application components and Kubernetes resources were verified using `kubectl` commands.

These commands confirm that all pods, services, deployments, and ingress resources were successfully created in the `chinmayee` namespace.

**All Kubernetes Resources**
---
<img width="862" height="576" alt="Screenshot 2026-03-11 224650" src="https://github.com/user-attachments/assets/d045696f-d775-42a4-9760-64589fb4ce0a" />

**Running Nodes & Pods**
---
<img width="837" height="318" alt="Screenshot 2026-03-11 224543" src="https://github.com/user-attachments/assets/a30cd77d-8706-4554-908d-cdc5e94e90f9" />


**Cluster Services**
---
<img width="772" height="138" alt="Screenshot 2026-03-11 224209" src="https://github.com/user-attachments/assets/0082eaad-68d5-412c-8cb6-4a8fd3686782" />


**Ingress Resource**
---
<img width="1737" height="363" alt="Screenshot 2026-03-11 231947" src="https://github.com/user-attachments/assets/1f85440f-0d0a-4eb4-ab89-800de1606ab7" />

**Certificate Verification**
---
<img width="1907" height="171" alt="Screenshot 2026-03-11 232128" src="https://github.com/user-attachments/assets/03d6f60a-aaa2-4333-829c-8fc0cc5f9bbb" />

**Monitoring Stack Verification**
---
<img width="958" height="516" alt="Screenshot 2026-03-11 231910" src="https://github.com/user-attachments/assets/9ab3fdd3-9141-4dd6-86a7-19cdcfe99bb0" />


### Key Kubernetes Verification Commands
---
The following commands were used to verify that all application components were successfully deployed inside the cluster.

```bash
kubectl get nodes
kubectl get pods -n chinmayee
kubectl get svc -n chinmayee
kubectl get ingress -n chinmayee
kubectl get all -n chinmayee
kubectl get all -n monitoring
kubectl get all -n ingress-nginx
kubectl get certificate -A


```
## 🌐 Networking & Traffic Flow
External traffic enters the system through DNS and the NGINX Ingress Controller, which routes requests to the appropriate microservices running inside the Kubernetes cluster.
### Complete Traffic Flow

```
1. User types https://ai-fairy-vote.duckdns.org in browser

2. DNS Resolution:
   Browser → DuckDNS → resolves to ALB IP (3.151.54.21)

3. TLS Handshake:
   Browser ←→ ALB ←→ NGINX Ingress Controller
   (TLS terminated at NGINX using Let's Encrypt certificate)

4. HTTP Routing (inside cluster):
   NGINX reads Host header → routes based on ingress rules:
   - ai-fairy-vote.duckdns.org   → chinmayee-svc-vote:80
   - ai-fairy-result.duckdns.org → chinmayee-svc-result:80

5. For Result page WebSocket:
   Browser opens WSS connection → NGINX upgrades to WebSocket
   Path: /result/socket.io → chinmayee-svc-result:80
   Path: /socket.io        → chinmayee-svc-result:80

6. For Vote submission:
   POST / → Vote pod → Redis rpush → Worker consumes → PostgreSQL store
   → Result pod reads from PostgreSQL → emits via Socket.IO → Browser updates
```

### Ingress Configuration

External traffic is routed into the cluster using the **NGINX Ingress Controller**.

The ingress configuration performs:

- Host-based routing for the vote and result services
- WebSocket support for real-time updates via Socket.IO
- Automatic HTTPS provisioning using **cert-manager** and **Let's Encrypt**

Ingress rules route traffic as follows:

| Host | Service |
|------|--------|
| ai-fairy-vote.duckdns.org | Vote Service |
| ai-fairy-result.duckdns.org | Result Service |

The full ingress configuration can be found here:

`k8s/ingress.yaml`

---
### Load Balancer
External traffic enters the cluster through an AWS Load Balancer created by the NGINX Ingress Controller.
<img width="1902" height="856" alt="Screenshot 2026-03-11 225647" src="https://github.com/user-attachments/assets/edf90edb-ef00-4370-973e-d31c258825ed" />


| Property | Value |
|----------|-------|
| Type | AWS NLB (Network Load Balancer) |
| DNS | aecf7ecd40ceb4e4795d6513317bffe9-60b2e41fd1b06e4d.elb.us-east-2.amazonaws.com |
| Ports | 80 (HTTP) → 31771, 443 (HTTPS) → 30876 |
| Created By | NGINX Ingress Controller (LoadBalancer service) |

---
## 7. HTTPS & TLS with cert-manager

### How It Works

```
1. cert-manager watches Ingress for annotation: cert-manager.io/cluster-issuer: "letsencrypt-prod"
2. cert-manager creates a Certificate resource for the hosts in spec.tls
3. cert-manager uses HTTP-01 challenge:
   - Creates a temporary pod + ingress to serve the challenge token
   - Let's Encrypt verifies the domain by hitting /.well-known/acme-challenge/
4. Once verified, Let's Encrypt issues the TLS certificate
5. cert-manager stores the certificate in Kubernetes Secret: ai-fairy-tls
6. NGINX Ingress Controller picks up the secret and serves HTTPS
7. cert-manager auto-renews before expiry (~every 60 days)
```

### Setup Steps

1. **Install cert-manager:**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
   ```

2. **Create ClusterIssuer:**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: nginx-websocket
   ```

3. **Add annotations to Ingress:**
   ```yaml
   annotations:
     cert-manager.io/cluster-issuer: "letsencrypt-prod"
     nginx.ingress.kubernetes.io/ssl-redirect: "true"
   ```

4. **Add TLS block to Ingress spec:**
   ```yaml
   spec:
     tls:
     - hosts:
       - ai-fairy-vote.duckdns.org
       - ai-fairy-result.duckdns.org
       secretName: ai-fairy-tls
   ```
### Verification Commands

```bash
# Check certificate status
kubectl get certificate -n chinmayee

# Check secret
kubectl get secret ai-fairy-tls -n chinmayee

# Describe certificate
kubectl describe certificate ai-fairy-tls -n chinmayee

# Test HTTPS
curl -v https://ai-fairy-vote.duckdns.org 2>&1 | grep "SSL certificate"
```
### 🔒 Security Summary

| Layer | Mechanism |
|-------|-----------|
| TLS Certificates | cert-manager + Let's Encrypt (auto-provisioned, auto-renewed) |
| HTTPS Enforcement | `ssl-redirect: "true"` — all HTTP → HTTPS |
| Certificate Storage | Kubernetes Secret `ai-fairy-tls` |
| WebSocket Security | WSS (WebSocket over TLS) — encrypted via TLS termination |
| HSTS Header | `Strict-Transport-Security: max-age=31536000; includeSubDomains` |

## 🔁 CI/CD Pipeline (GitHub Actions)

This project includes a fully automated **CI/CD pipeline implemented using GitHub Actions**.
### Pipeline Overview
- Triggered on code pushes to the **main branch**
- Builds Docker images for all microservices
- Pushes images to **Docker Hub**
- Authenticates to **AWS using GitHub Secrets**
- Updates **kubeconfig** for the EKS cluster
- Deploys updated Kubernetes manifests using `kubectl apply`

### Pipeline Stages
The CI/CD pipeline is implemented using **GitHub Actions** and triggered on code pushes to the `main` branch.

**Workflow file:** `.github/workflows/deploy.yml`

### Pipeline Stages

```
        Code Push to main
               │
               ▼
┌─────────────────────────────────┐
│  Stage 1: Build & Push(parallel)│
│  ┌─────┐ ┌──────┐ ┌──────┐      │
│  │Vote │ │Result│ │Worker│      │
│  └──┬──┘ └──┬───┘ └──┬───┘      │
│     │       │        │          │
│     ▼       ▼        ▼          │
│  Docker Build & Push to Hub     │
│  Tags: :latest + :SHORT_SHA     │
└─────────────────┬───────────────┘
                  │
                  ▼
┌─────────────────────────────────┐
│  Stage 2: Deploy to EKS         │
│  1. Configure AWS credentials   │
│  2. Update kubeconfig           │
│  3. Deploy databases (Postgres, │
│     Redis) + wait for ready     │
│  4. Deploy microservices        │
│  5. Deploy ingress              │
│  6. Verify deployment           │
└─────────────────────────────────┘
```

### Trigger Conditions

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'vote/**'
      - 'result/**'
      - 'worker/**'
      - 'k8s/**'
  workflow_dispatch:  # Manual trigger
```

## 🔁 CI/CD Pipeline (GitHub Actions)

This project includes a fully automated CI/CD pipeline implemented using GitHub Actions.
Pipeline Overview

- Triggered on code pushes to the main branch

- Builds Docker images for all microservices

- Pushes images to Docker Hub

- Authenticates to AWS using GitHub Secrets

- Updates kubeconfig for the EKS cluster

- Deploys updated Kubernetes manifests using kubectl apply

### CI/CD Workflow Location
    -    .github/workflows/

  ### CI/CD Pipeline Triggers

    - Automatically triggered on code changes to application or Kubernetes manifests
    - Supports manual execution via GitHub Actions (`workflow_dispatch`) for controlled deployments

### Container Images

The CI/CD pipeline builds and pushes container images for each microservice to **Docker Hub**.

| Image | Tag Format |
|------|------------|
| chinmayee606/vote | `:latest`, `:SHORT_SHA` |
| chinmayee606/result | `:latest`, `:SHORT_SHA` |
| chinmayee606/worker | `:latest`, `:SHORT_SHA` |

---

### GitHub Secrets

The GitHub Actions workflow uses repository secrets to authenticate with external services.

| Secret | Purpose |
|------|---------|
| DOCKERHUB_USERNAME | Docker Hub login |
| DOCKERHUB_TOKEN | Docker Hub access token |
| AWS_ACCESS_KEY_ID | AWS authentication |
| AWS_SECRET_ACCESS_KEY | AWS authentication |
  
### Key Characteristics

- Fully automated deployments using **GitHub Actions**
- Uses **declarative Kubernetes manifests**
- Supports **repeatable and consistent deployments**
- Separates **application code from infrastructure configuration**

Pipeline runs and deployment history can be viewed in the **GitHub Actions** tab of this repository.
        

## 📊 Monitoring & Observability

The system includes a monitoring stack based on **Prometheus and Grafana** to track application and infrastructure metrics inside the Kubernetes cluster.

All monitoring components are deployed in a dedicated namespace:

`monitoring`

---

### Monitoring Stack

| Component | Purpose |
|-----------|---------|
| Prometheus | Collects and stores metrics |
| Grafana | Visualizes metrics through dashboards |
| Node Exporter | Provides node-level system metrics |
| kube-state-metrics | Exposes Kubernetes object metrics |

---

### Grafana Dashboards

The Grafana dashboards provide visibility into both **application health** and **cluster performance**.

**Application Dashboard**
- Running pods
- Pod restarts
- CPU usage per container
- Memory usage
- Network traffic

<img width="1904" height="940" alt="Screenshot 2026-03-11 204837" src="https://github.com/user-attachments/assets/d5b9fc2c-f15a-400d-8723-82f74105f02f" />

**CPU usage**
<img width="1903" height="910" alt="Screenshot 2026-03-11 203727" src="https://github.com/user-attachments/assets/43a4b0ff-0453-45fe-b5bb-db591fb1eb28" />

**Memory usage**
<img width="1902" height="917" alt="Screenshot 2026-03-11 203652" src="https://github.com/user-attachments/assets/a28a2b4b-df2a-4b77-bf0c-4ddddb52d757" />

**Network traffic**
<img width="1912" height="920" alt="Screenshot 2026-03-11 203807" src="https://github.com/user-attachments/assets/e9c2ad4a-eb7c-425a-a863-f17c49ade8c1" />



## 🌍 DNS Configuration

The application domains are managed using **DuckDNS**, a dynamic DNS service.

Two subdomains are configured to route traffic to the Kubernetes ingress load balancer:

| Domain | Purpose |
|------|------|
| ai-fairy-vote.duckdns.org | Routes traffic to the Vote service |
| ai-fairy-result.duckdns.org | Routes traffic to the Result dashboard |

Both domains resolve to the AWS Load Balancer created by the NGINX Ingress Controller.

## ⚠️ Key Challenges & Solutions 🛠

| Challenge | Symptoms | Root Cause | Solution | Result |
|-----------|----------|------------|----------|--------|
| **WebSocket failures behind ingress** | Result page loaded blank; browser returned `400` errors when connecting to the Socket.IO endpoint HTTP polling worked but WebSocket upgrade failed | Initial Default ingress configuration did not handle WebSocket upgrade headers correctly  | Deployed a dedicated **Community NGINX Ingress Controller** and configured for WebSocket traffic and updated ingress annotations | WebSocket connections upgraded successfully and the results dashboard began updating in real time |
| **PostgreSQL CrashLoop on EBS volume** | PostgreSQL pod repeatedly entered `CrashLoopBackOff` | EBS volume contained a `lost+found` directory; PostgreSQL requires an empty data directory | Configured `PGDATA` to use a subdirectory (`pgdata`) within the mounted volume | Database initialized correctly and persistent storage worked across pod restarts |
| **Result page displaying Vote page** | Result URL loaded the voting UI instead of results dashboard | Container image was outdated and did not include recent code changes | Rebuilt and pushed updated Docker images and restarted the deployment | Result service deployed correctly and the results page loaded as expected |
| **EKS console access denied** | AWS console showed "You don't have permission to view Kubernetes objects" | IAM user was not mapped in the `aws-auth` ConfigMap | Added IAM user to `aws-auth` with `system:masters` permissions | Kubernetes resources became visible and manageable from the EKS console |
| **Grafana dashboards showing no data** | Monitoring panels returned "No Data" | Prometheus was missing cAdvisor metrics and ingress metrics configuration | Added kubelet `/metrics/cadvisor` scrape job and corrected NGINX metrics endpoint | Metrics began populating in Grafana dashboards |
| **TLS certificate not issuing** | Certificate resource remained in `READY: False` state | DNS record was not pointing to the load balancer, preventing HTTP-01 validation | Created DuckDNS records pointing to the ingress load balancer | TLS certificate issued successfully and HTTPS became available |

---

## 🎯 Lessons Learned

This project provided hands-on experience building and operating a cloud-native application on Kubernetes. Key takeaways include:

- **Kubernetes Networking:** Learned how Ingress controllers, services, and DNS work together to route external traffic into a cluster.
- **Debugging Distributed Systems:** Troubleshooting issues such as WebSocket failures and container misconfigurations required analyzing logs, verifying networking paths, and testing configuration changes incrementally.
- **Stateful Workloads on Kubernetes:** Running PostgreSQL with persistent storage highlighted the importance of correct volume configuration and handling filesystem quirks like the `lost+found` directory on EBS volumes.
- **CI/CD Automation:** Implementing GitHub Actions demonstrated how automated pipelines can build, push, and deploy containerized applications reliably.
- **Observability Matters:** Integrating Prometheus and Grafana provided visibility into application performance and helped validate system health.
- **Security & TLS Management:** Using cert-manager and Let's Encrypt simplified certificate lifecycle management and enabled secure HTTPS and WSS communication.



## 🚀 Future Enhancements

- **Horizontal Pod Autoscaling (HPA):** Automatically scale application pods based on CPU or custom metrics to handle varying workloads.
- **GitOps Deployment:** Introduce tools like **ArgoCD or Flux** to manage Kubernetes deployments using a GitOps workflow.
- **AI-Assisted Monitoring:** Explore using AI tools to analyze logs and metrics for anomaly detection in the monitoring stack.


### 👩‍💻 Author

Chinmayee Pradhan
 Network | DevOps Engineer | AI Enthusiast 
📍 Netherlands

⭐ Feel free to explore the repository or reach out for feedback
