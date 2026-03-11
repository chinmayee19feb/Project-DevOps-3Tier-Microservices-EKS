# 3-Tier Cloud Wars Voting Application on Amazon EKS — Complete Documentation

> A production-grade, microservices-based voting application deployed on Amazon EKS with HTTPS, WebSocket support, CI/CD automation, and Prometheus + Grafana monitoring.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [AWS Infrastructure](#3-aws-infrastructure)
4. [Application Components](#4-application-components)
5. [Kubernetes Design](#5-kubernetes-design)
6. [Networking & Traffic Flow](#6-networking--traffic-flow)
7. [HTTPS & TLS with cert-manager](#7-https--tls-with-cert-manager)
8. [WebSocket Challenge & Solution](#8-websocket-challenge--solution)
9. [CI/CD Pipeline](#9-cicd-pipeline)
10. [Monitoring with Prometheus & Grafana](#10-monitoring-with-prometheus--grafana)
11. [DNS Configuration](#11-dns-configuration)
12. [EKS Console Access](#12-eks-console-access)
13. [Key Challenges & Solutions](#13-key-challenges--solutions)
14. [Step-by-Step Setup Guide](#14-step-by-step-setup-guide)
15. [Cleanup & Teardown](#15-cleanup--teardown)
16. [File Structure](#16-file-structure)

---

## 1. Project Overview

This project deploys a **multi-language microservices voting application** on Amazon EKS. Users vote between AWS and Azure (Cloud Wars), and results are displayed in real-time via WebSocket.

### Live URLs

| App | URL | Protocol |
|-----|-----|----------|
| Vote | https://ai-fairy-vote.duckdns.org | HTTPS (TLS 1.2+) |
| Result | https://ai-fairy-result.duckdns.org | HTTPS + WSS (WebSocket Secure) |
| Grafana | http://localhost:3000 (port-forward) | Internal only |

### Technologies Used

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

## 2. Architecture

### High-Level Architecture

```
                    ┌──────────────────────────────────────────────────────────────┐
                    │                        AWS Cloud                             │
                    │  ┌───────────────────────────────────────────────────────┐   │
                    │  │                        VPC                            │   │
                    │  │  ┌─────────────────────────────────────────────────┐  │   │
                    │  │  │              Amazon EKS Cluster                  │  │   │
                    │  │  │                                                  │  │   │
 ┌─────────┐       │  │  │  ┌──────────┐    ┌──────────┐    ┌──────────┐  │  │   │
 │  Users   │──HTTPS──│──│──▶│   ALB    │───▶│  NGINX   │───▶│  Vote    │  │  │   │
 │(Browser) │       │  │  │  │          │    │ Ingress  │    │ (Flask)  │  │  │   │
 └─────────┘       │  │  │  └──────────┘    │nginx-ws  │    └────┬─────┘  │  │   │
      │            │  │  │                   │TLS Term. │         │        │  │   │
      │            │  │  │                   └────┬─────┘    push votes    │  │   │
 ┌─────────┐       │  │  │                        │              │        │  │   │
 │Route 53 │       │  │  │                   ai-fairy-result     ▼        │  │   │
 │  (DNS)  │       │  │  │                        │         ┌──────────┐  │  │   │
 └─────────┘       │  │  │                        │         │  Redis   │  │  │   │
                    │  │  │                        ▼         │ (Queue)  │  │  │   │
 ┌─────────┐       │  │  │                   ┌──────────┐   └────┬─────┘  │  │   │
 │  Let's  │──TLS cert──│──────────────────▶│  Result  │        │        │  │   │
 │ Encrypt │       │  │  │                   │(Node.js) │   consume       │  │   │
 │cert-mgr │       │  │  │                   │Socket.IO │        │        │  │   │
 └─────────┘       │  │  │                   └────▲─────┘        ▼        │  │   │
                    │  │  │                        │         ┌──────────┐  │  │   │
                    │  │  │                   read results   │  Worker  │  │  │   │
                    │  │  │                        │         │  (.NET)  │  │  │   │
                    │  │  │                   ┌────┴─────┐   └────┬─────┘  │  │   │
                    │  │  │                   │PostgreSQL│◀──store─┘       │  │   │
                    │  │  │                   │  (Store) │                  │  │   │
                    │  │  │                   └────┬─────┘                  │  │   │
                    │  │  │                        │                        │  │   │
                    │  │  │                   ┌────┴─────┐                  │  │   │
                    │  │  │                   │   EBS    │                  │  │   │
                    │  │  │                   │ Volume   │                  │  │   │
                    │  │  │                   └──────────┘                  │  │   │
                    │  │  │                                                  │  │   │
                    │  │  │  ┌─────────────────────────────────────────┐    │  │   │
                    │  │  │  │  Monitoring (Internal)                  │    │  │   │
                    │  │  │  │  Prometheus ──▶ Grafana (localhost:3000)│    │  │   │
                    │  │  │  └─────────────────────────────────────────┘    │  │   │
                    │  │  └─────────────────────────────────────────────────┘  │   │
                    │  └───────────────────────────────────────────────────────┘   │
                    └──────────────────────────────────────────────────────────────┘

 ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
 │Developer │───▶│   Git    │───▶│  GitHub  │───▶│  GitHub  │───▶│  Docker  │──deploy──▶ EKS
 │          │    │          │    │   Repo   │    │ Actions  │    │   Hub    │
 └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

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

## 3. AWS Infrastructure

### EKS Cluster

| Property | Value |
|----------|-------|
| Cluster Name | `chinmayee-3tier-cluster` |
| Kubernetes Version | 1.34 |
| Region | us-east-2 (Ohio) |
| Platform | EKS (eks.17) |
| Created With | `eksctl` |
| Authentication Mode | API_AND_CONFIG_MAP |

### Node Group

| Property | Value |
|----------|-------|
| Name | ng-87cea84e |
| Instance Type | m7i-flex.large |
| AMI | Amazon Linux 2023 (AL2023_x86_64_STANDARD) |
| Min/Max/Desired | 1 / 3 / 2 |
| Container Runtime | containerd 2.1.5 |

### Nodes

| Node | Internal IP | External IP | Status |
|------|------------|-------------|--------|
| ip-192-168-48-249.us-east-2.compute.internal | 192.168.48.249 | 18.223.156.148 | Ready |
| ip-192-168-7-243.us-east-2.compute.internal | 192.168.7.243 | 18.222.46.190 | Ready |

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

## 4. Application Components

### Service Details

| Service | Language/Framework | Image | Replicas | Port | Role |
|---------|-------------------|-------|----------|------|------|
| Vote | Python 3.11 / Flask | chinmayee606/vote:latest | 2 | 80 | Frontend — users cast votes |
| Result | Node.js 18 / Express + Socket.IO | chinmayee606/result:latest | 2 | 80 | Frontend — displays live results via WebSocket |
| Worker | .NET | chinmayee606/worker:latest | 1 | — | Background processor — moves votes from Redis to PostgreSQL |
| Redis | Redis 6 Alpine | redis:6-alpine | 1 | 6379 | Temporary vote queue |
| PostgreSQL | PostgreSQL 15 Alpine | postgres:15-alpine | 1 | 5432 | Persistent vote storage |

### Vote Service (Flask/Python)

- Serves the voting UI at `/`
- On POST, pushes vote data as JSON (`{voter_id, vote}`) to Redis queue via `rpush`
- Redis connection configurable via `REDIS_HOST` and `REDIS_PORT` environment variables
- Sets a `voter_id` cookie to track voters
- Connects to Redis at `chinmayee-svc-redis:6379`

### Result Service (Node.js/Socket.IO)

- Serves the results UI at `/`
- Connects to PostgreSQL to read vote counts
- Uses **Socket.IO** for real-time updates via WebSocket (WSS)
- Socket.IO client connects with path `/result/socket.io`
- Supports both `websocket` and `polling` transports
- Health checks: readinessProbe and livenessProbe on `/` port 80
- Connects to PostgreSQL at `chinmayee-svc-postgres:5432`

### Worker Service (.NET)

- Background processor with no external port
- Consumes votes from Redis queue
- Writes/updates vote counts in PostgreSQL
- Connects to both `chinmayee-svc-redis` and `chinmayee-svc-postgres`

### PostgreSQL

- Uses `PGDATA=/var/lib/postgresql/data/pgdata` subdirectory to avoid EBS `lost+found` conflict
- Data persisted on EBS volume via PersistentVolumeClaim (5Gi, gp2)
- Credentials: postgres/postgres (dev environment)

---

## 5. Kubernetes Design

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

PostgreSQL mounts this at `/var/lib/postgresql/data` with `PGDATA` set to a subdirectory (`pgdata`) to avoid the EBS `lost+found` directory issue.

---

## 6. Networking & Traffic Flow

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

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  # Old name commented out (debugging history):
  #name: chinmayee-ingress
  name: chinmayee-ingress-websocket
  namespace: chinmayee
  annotations:
    # Old ingress classes tried during debugging:
    #kubernetes.io/ingress.class: chinmayee-nginx
    # kubernetes.io/ingress.class: nginx
    kubernetes.io/ingress.class: "nginx-websocket"
    # Old timeout annotations tried:
    # nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    # nginx.ingress.kubernetes.io/proxy-send-timeout: "2600"
    # nginx.ingress.kubernetes.io/websocket-services: "chinmayee-svc-result"
    nginx.ingress.kubernetes.io/websocket-services: "chinmayee-svc-result"
    nginx.ingress.kubernetes.io/proxy-set-header: "Upgrade $http_upgrade"
    nginx.ingress.kubernetes.io/proxy-set-header: "Connection $connection_upgrade"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - ai-fairy-vote.duckdns.org
    - ai-fairy-result.duckdns.org
    secretName: ai-fairy-tls
  ingressClassName: nginx-websocket
  rules:
  - host: ai-fairy-vote.duckdns.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: chinmayee-svc-vote
            port:
              number: 80
  - host: ai-fairy-result.duckdns.org
    http:
      paths:
      - path: /result/socket.io    # Socket.IO endpoint
        pathType: Prefix
        backend:
          service:
            name: chinmayee-svc-result
            port:
              number: 80
      - path: /socket.io            # Fallback Socket.IO path
        pathType: Prefix
        backend:
          service:
            name: chinmayee-svc-result
            port:
              number: 80
      - path: /                      # Main result page
        pathType: Prefix
        backend:
          service:
            name: chinmayee-svc-result
            port:
              number: 80
```

### Load Balancer

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
# NAME           READY   SECRET         AGE
# ai-fairy-tls   True    ai-fairy-tls   6h

# Check secret
kubectl get secret ai-fairy-tls -n chinmayee

# Describe certificate
kubectl describe certificate ai-fairy-tls -n chinmayee

# Test HTTPS
curl -v https://ai-fairy-vote.duckdns.org 2>&1 | grep "SSL certificate"
```

### Security Summary

| Layer | Mechanism |
|-------|-----------|
| TLS Certificates | cert-manager + Let's Encrypt (auto-provisioned, auto-renewed) |
| HTTPS Enforcement | `ssl-redirect: "true"` — all HTTP → HTTPS |
| Certificate Storage | Kubernetes Secret `ai-fairy-tls` |
| WebSocket Security | WSS (WebSocket over TLS) — encrypted via TLS termination |
| HSTS Header | `strict-transport-security: max-age=31536000; includeSubDomains` |

---

## 8. WebSocket Challenge & Solution

This was the **longest and most difficult challenge** in the project.

### The Problem

- The Result page uses **Socket.IO** for real-time vote updates
- Browser was throwing **400 errors** on the Socket.IO endpoint
- HTTP polling worked, but WebSocket upgrade failed
- Result page stayed **completely blank**
- Backend pods were healthy — the issue was at the ingress layer

### Debugging Process

1. **Checked NGINX Ingress logs** — confirmed WebSocket upgrade headers were being dropped

2. **Reviewed existing ingress setup** — the original shared ingress controller (`chinmayee-nginx` / `nginx` class) was not configured for WebSocket

3. **Studied Kubernetes documentation** — learned that WebSocket requires explicit support for `Upgrade` and `Connection` headers

4. **Tried various approaches** (visible in commented-out lines in ingress.yaml):
   ```yaml
   # Attempt 1: Original shared ingress
   #name: chinmayee-ingress
   #kubernetes.io/ingress.class: chinmayee-nginx
   #ingressClassName: "chinmayee-nginx"

   # Attempt 2: Default nginx class
   # kubernetes.io/ingress.class: nginx
   # ingressClassName: nginx

   # Attempt 3: Timeout tuning
   # nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
   # nginx.ingress.kubernetes.io/proxy-send-timeout: "2600"
   ```

### The Solution

Deployed a **separate Community NGINX Ingress Controller** with its own class (`nginx-websocket`):

```bash
# Install Community NGINX Ingress Controller with custom class
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.ingressClassResource.name=nginx-websocket \
  --set controller.ingressClass=nginx-websocket
```

Key annotations that fixed WebSocket:
```yaml
kubernetes.io/ingress.class: "nginx-websocket"
nginx.ingress.kubernetes.io/websocket-services: "chinmayee-svc-result"
nginx.ingress.kubernetes.io/proxy-set-header: "Upgrade $http_upgrade"
nginx.ingress.kubernetes.io/proxy-set-header: "Connection $connection_upgrade"
```

Dedicated Socket.IO paths in ingress rules:
```yaml
- path: /result/socket.io
- path: /socket.io
```

Socket.IO client configuration (`result/views/app.js`):
```javascript
var socket = io(namespace, {
  path: '/result/socket.io',
  transports: ['websocket', 'polling']
});
```

### Result

WebSocket connections working as expected. Real-time vote updates display properly via WSS.

---

## 9. CI/CD Pipeline

### Pipeline Overview

The CI/CD pipeline is implemented using **GitHub Actions** and triggered on code pushes to the `main` branch.

**Workflow file:** `.github/workflows/deploy.yml`

### Pipeline Stages

```
Code Push to main
       │
       ▼
┌─────────────────────────────────┐
│  Stage 1: Build & Push (parallel)│
│  ┌─────┐ ┌──────┐ ┌──────┐    │
│  │Vote │ │Result│ │Worker│    │
│  └──┬──┘ └──┬───┘ └──┬───┘    │
│     │       │        │         │
│     ▼       ▼        ▼         │
│  Docker Build & Push to Hub    │
│  Tags: :latest + :SHORT_SHA    │
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

### Docker Images

All images are pushed to **Docker Hub** under `chinmayee606/`:

| Image | Tag Format |
|-------|-----------|
| chinmayee606/vote | :latest, :SHORT_SHA |
| chinmayee606/result | :latest, :SHORT_SHA |
| chinmayee606/worker | :latest, :SHORT_SHA |

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| DOCKERHUB_USERNAME | Docker Hub login |
| DOCKERHUB_TOKEN | Docker Hub access token |
| AWS_ACCESS_KEY_ID | AWS authentication |
| AWS_SECRET_ACCESS_KEY | AWS authentication |

---

## 10. Monitoring with Prometheus & Grafana

### Stack Components

| Component | Purpose | Image |
|-----------|---------|-------|
| Prometheus | Metrics collection & storage | prom/prometheus:v2.51.0 |
| Grafana | Visualization & dashboards | grafana/grafana:10.4.1 |
| Node Exporter | Node-level metrics (DaemonSet) | prom/node-exporter:v1.7.0 |
| kube-state-metrics | Kubernetes object metrics | registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.12.0 |

All deployed in the **`monitoring`** namespace.

### What Prometheus Scrapes

| Job | Target | Metrics |
|-----|--------|---------|
| prometheus | Self (localhost:9090) | Prometheus health |
| kubernetes-nodes | Kubelet (HTTPS) | Node status |
| kubernetes-cadvisor | Kubelet /metrics/cadvisor | Container CPU, memory, network |
| kubernetes-pods | Pods with `prometheus.io/scrape: true` | Custom app metrics |
| kubernetes-services | Services with `prometheus.io/scrape: true` | Service metrics |
| nginx-ingress | NGINX controller pod:10254 | Ingress controller metrics |
| kube-state-metrics | kube-state-metrics:8080 | Pod status, restarts, deployments |
| node-exporter | Node Exporter:9100 | CPU, memory, disk, network per node |

### Grafana Dashboards

**Dashboard 1: Cloud Wars — Voting App Overview**
- Running pod count (chinmayee namespace)
- Total pod restarts
- CPU usage by pod (timeseries)
- Memory usage by pod (timeseries)
- Network I/O per pod (RX/TX)
- Container restarts over time
- Pod ready status
- CPU throttling

**Dashboard 2: EKS Node Metrics**
- Node CPU usage (%)
- Node memory usage (%)
- Disk usage (%)
- Network traffic (RX/TX bytes per second)

### Access Grafana

```bash
# Port-forward (internal only — not exposed publicly)
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open http://localhost:3000
# User: admin
# Password: CloudWars2026!
```

### Prometheus Data Source

Automatically configured via ConfigMap:
```yaml
url: http://prometheus.monitoring.svc.cluster.local:9090
```

### Deploy Monitoring

```bash
./k8s/monitoring/deploy-monitoring.sh
```

---

## 11. DNS Configuration

### DuckDNS Setup

DuckDNS is a free dynamic DNS service. Each subdomain points to the NGINX Ingress Load Balancer IP.

| Subdomain | IP | Points To |
|-----------|-----|-----------|
| ai-fairy-vote.duckdns.org | 3.151.54.21 | ALB → NGINX → Vote Service |
| ai-fairy-result.duckdns.org | 3.151.54.21 | ALB → NGINX → Result Service |

### How to Set Up

1. Go to https://www.duckdns.org
2. Log in with GitHub/Google
3. Create subdomain: `ai-fairy-vote`
4. Set IP to the Load Balancer IP:
   ```bash
   # Get the ALB hostname
   kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

   # Resolve to IP
   nslookup <ALB_HOSTNAME>
   ```
5. Repeat for `ai-fairy-result`

### Update IP via API

```bash
curl "https://www.duckdns.org/update?domains=ai-fairy-vote&token=YOUR_TOKEN&ip=NEW_IP"
curl "https://www.duckdns.org/update?domains=ai-fairy-result&token=YOUR_TOKEN&ip=NEW_IP"
```

---

## 12. EKS Console Access

To view Nodes, Pods, and other Kubernetes resources in the AWS EKS Console, the IAM user needs proper access.

### The Problem

By default, the EKS console shows "You don't have permission to view Kubernetes objects" even for IAM users with AWS admin access.

### The Fix

The cluster uses `API_AND_CONFIG_MAP` authentication mode. Two things are needed:

1. **EKS Access Entry** with `AmazonEKSClusterAdminPolicy`:
   ```bash
   aws eks create-access-entry \
     --cluster-name chinmayee-3tier-cluster \
     --region us-east-2 \
     --principal-arn "arn:aws:iam::097659826330:user/Admin" \
     --type STANDARD

   aws eks associate-access-policy \
     --cluster-name chinmayee-3tier-cluster \
     --region us-east-2 \
     --principal-arn "arn:aws:iam::097659826330:user/Admin" \
     --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
     --access-scope type=cluster

   aws eks associate-access-policy \
     --cluster-name chinmayee-3tier-cluster \
     --region us-east-2 \
     --principal-arn "arn:aws:iam::097659826330:user/Admin" \
     --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy" \
     --access-scope type=cluster
   ```

2. **aws-auth ConfigMap** with `system:masters` group:
   ```yaml
   data:
     mapUsers: |
       - userarn: arn:aws:iam::097659826330:user/Admin
         username: Admin
         groups:
         - system:masters
   ```

### Important

- You must log into the console as the **IAM user** (Admin), NOT the **root account**
- Root accounts cannot be added to EKS access entries
- Console URL: `https://097659826330.signin.aws.amazon.com/console`

---

## 13. Key Challenges & Solutions

| # | Challenge | Symptoms | Root Cause | Solution |
|---|-----------|----------|------------|----------|
| 1 | **WebSocket Failures** (longest challenge) | Result page blank, browser 400 errors on Socket.IO, HTTP polling worked but WebSocket upgrade failed | Shared ingress controller dropped WebSocket upgrade headers | Deployed separate Community NGINX Ingress Controller with `nginx-websocket` class and WebSocket annotations |
| 2 | **PostgreSQL CrashLoop** | Pod in CrashLoopBackOff | EBS volume has `lost+found` directory; PostgreSQL needs empty data dir | Used `PGDATA` with subdirectory (`pgdata`) via environment variable |
| 3 | **Result page showing Vote page** | Clicking Result showed voting UI instead of results dashboard | Docker image had old code; container wasn't rebuilt after code changes | Rebuilt and pushed Docker images, then `kubectl rollout restart` |
| 4 | **EKS Console no permissions** | "You don't have permission to view Kubernetes objects" | IAM user not in aws-auth ConfigMap; logged in as root instead of IAM user | Added IAM user to aws-auth with system:masters; logged in as IAM user |
| 5 | **Grafana No Data** | Dashboard panels showing "No Data" | Prometheus missing cAdvisor scrape config; NGINX metrics port not exposed | Added `kubernetes-cadvisor` job scraping `/metrics/cadvisor` from kubelet; fixed NGINX target to use pod IP:10254 |
| 6 | **TLS cert not issuing** | Certificate stuck at READY: False | DNS record for domain not created; Let's Encrypt HTTP-01 challenge couldn't reach the domain | Created DuckDNS record pointing to ALB IP |

---

## 14. Step-by-Step Setup Guide

### Prerequisites

- AWS CLI configured with IAM user
- kubectl installed
- eksctl installed
- Docker installed and logged into Docker Hub
- Helm installed

### Step 1: Create EKS Cluster

```bash
eksctl create cluster \
  --name chinmayee-3tier-cluster \
  --region us-east-2 \
  --nodegroup-name ng-workers \
  --node-type m7i-flex.large \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3
```

### Step 2: Create Namespace

```bash
kubectl create namespace chinmayee
```

### Step 3: Deploy Community NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.ingressClassResource.name=nginx-websocket \
  --set controller.ingressClass=nginx-websocket
```

Wait for LoadBalancer IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### Step 4: Set Up DNS (DuckDNS)

1. Get the ALB IP: `nslookup <ALB_HOSTNAME>`
2. Create DuckDNS subdomains pointing to ALB IP

### Step 5: Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
```

Create ClusterIssuer for Let's Encrypt (see Section 7).

### Step 6: Deploy Application

```bash
# Database layer
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/redis-service.yaml

# Wait for databases
kubectl wait --for=condition=ready pod -l app=chinmayee-postgres -n chinmayee --timeout=180s
kubectl wait --for=condition=ready pod -l app=chinmayee-redis -n chinmayee --timeout=180s

# Application layer
kubectl apply -f k8s/vote-deployment.yaml
kubectl apply -f k8s/vote-service.yaml
kubectl apply -f k8s/result-deployment.yaml
kubectl apply -f k8s/result-service.yaml
kubectl apply -f k8s/worker-deployment.yaml

# Ingress (triggers cert-manager TLS)
kubectl apply -f k8s/ingress.yaml
```

### Step 7: Verify

```bash
kubectl get pods -n chinmayee
kubectl get svc -n chinmayee
kubectl get ingress -n chinmayee
kubectl get certificate -n chinmayee

# Test HTTPS
curl -sI https://ai-fairy-vote.duckdns.org
curl -sI https://ai-fairy-result.duckdns.org
```

### Step 8: Deploy Monitoring

```bash
./k8s/monitoring/deploy-monitoring.sh

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000 (admin / CloudWars2026!)
```

### Step 9: Configure EKS Console Access

```bash
# Add IAM user to aws-auth
kubectl edit configmap aws-auth -n kube-system
# Add mapUsers section (see Section 12)

# Create access entry
aws eks create-access-entry --cluster-name chinmayee-3tier-cluster --region us-east-2 \
  --principal-arn "arn:aws:iam::ACCOUNT_ID:user/USERNAME" --type STANDARD

aws eks associate-access-policy --cluster-name chinmayee-3tier-cluster --region us-east-2 \
  --principal-arn "arn:aws:iam::ACCOUNT_ID:user/USERNAME" \
  --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
  --access-scope type=cluster
```

---

## 15. Cleanup & Teardown

### Step 1: Delete Monitoring

```bash
kubectl delete namespace monitoring
kubectl delete clusterrole prometheus kube-state-metrics
kubectl delete clusterrolebinding prometheus kube-state-metrics
```

### Step 2: Delete Application

```bash
kubectl delete namespace chinmayee
```

### Step 3: Delete NGINX Ingress Controller

```bash
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

### Step 4: Delete cert-manager

```bash
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
```

### Step 5: Delete EKS Cluster

```bash
eksctl delete cluster --name chinmayee-3tier-cluster --region us-east-2
```

This will also delete:
- Node group and EC2 instances
- VPC and subnets (if created by eksctl)
- Load Balancer
- EBS volumes (PVCs)

### Step 6: Clean Up DNS

- Remove `ai-fairy-vote` and `ai-fairy-result` subdomains from DuckDNS

---

## 16. File Structure

```
Project-DevOps-3Tier-Microservices-EKS/
├── .github/
│   └── workflows/
│       └── deploy.yml                    # CI/CD pipeline (GitHub Actions)
├── k8s/
│   ├── ingress.yaml                      # NGINX Ingress with TLS + WebSocket
│   ├── postgres-deployment.yaml          # PostgreSQL deployment
│   ├── postgres-pvc.yaml                 # EBS persistent volume claim
│   ├── postgres-service.yaml             # PostgreSQL ClusterIP service
│   ├── redis-deployment.yaml             # Redis deployment
│   ├── redis-service.yaml                # Redis ClusterIP service
│   ├── result-deployment.yaml            # Result app deployment (2 replicas)
│   ├── result-service.yaml               # Result ClusterIP service
│   ├── vote-deployment.yaml              # Vote app deployment (2 replicas)
│   ├── vote-service.yaml                 # Vote ClusterIP service
│   ├── worker-deployment.yaml            # Worker deployment
│   └── monitoring/
│       ├── 00-namespace.yaml             # monitoring namespace
│       ├── 01-prometheus-rbac.yaml       # Prometheus ServiceAccount + RBAC
│       ├── 02-prometheus-config.yaml     # Prometheus scrape configuration
│       ├── 03-prometheus-deployment.yaml # Prometheus server
│       ├── 04-node-exporter.yaml         # Node Exporter DaemonSet
│       ├── 05-kube-state-metrics.yaml    # kube-state-metrics
│       ├── 06-grafana-datasource.yaml    # Grafana ← Prometheus datasource
│       ├── 07-grafana-dashboards-config.yaml  # Pre-built dashboards JSON
│       ├── 08-grafana-deployment.yaml    # Grafana server
│       ├── 09-grafana-secret.yaml        # Grafana admin password
│       └── deploy-monitoring.sh          # One-command deploy script
├── vote/
│   ├── app.py                            # Flask vote application
│   ├── Dockerfile                        # Vote Docker image
│   ├── templates/index.html              # Vote UI (Cloud Wars theme)
│   └── static/stylesheets/style.css      # Vote styles
├── result/
│   ├── server.js                         # Node.js result server
│   ├── Dockerfile                        # Result Docker image
│   └── views/
│       ├── index.html                    # Result UI (Cloud Wars theme)
│       ├── app.js                        # Socket.IO client
│       └── stylesheets/style.css         # Result styles
├── worker/
│   └── ...                               # .NET worker service
├── README.md                             # Original README
├── README-SECURE.md                      # HTTPS & WebSocket documentation
└── README-DETAILED.md                    # This file — complete documentation
```

---

## Author

**Chinmayee Pradhan**
Aspiring Cloud / DevOps Engineer
