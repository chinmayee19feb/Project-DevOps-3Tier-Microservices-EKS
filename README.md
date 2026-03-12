# 🗳️ 3-Tier Voting Application on Amazon EKS

> A production-style deployment of a microservices-based application on Amazon EKS, using Kubernetes, Ingress, DNS, and persistent storage.

---

## 📖 Project Overview

This project demonstrates how to deploy a production-like, cloud-native microservices application on Amazon EKS, with a fully automated CI/CD pipeline using GitHub Actions.

The application is a multi-language microservices **Voting App**, composed of multiple services that communicate internally via Kubernetes networking and are exposed externally using an **NGINX Ingress Controller** with custom DNS.

The focus of this project is not just deployment, but understanding how Kubernetes components interact, how to debug real issues, and how to design a clean, scalable architecture on EKS.

---

## 🏗️ Architecture Diagram

<img width="4893" height="2519" alt="3-Tier App on Amazon EKS Cluster drawio" src="https://github.com/user-attachments/assets/e850debb-646e-4581-99f6-fe276c9a2d20" />


### Application Components

| Service | Technology | Purpose |
|------|-----------|---------|
| Vote | Python (Flask) | Frontend UI where users cast votes |
| Worker | .NET | Background processor that consumes votes |
| Redis | Redis | Temporary queue for incoming votes |
| Postgres | PostgreSQL | Persistent storage for vote counts |
| Result | Node.js | Displays live voting results |

---

### Request Flow

User → NGINX Ingress (DNS + Routing) → Vote Service → Redis → Worker → PostgreSQL → Result Service


---

## ☁️ Platform & Tools

- Amazon EKS  
- Kubernetes (Deployments, Services, PVCs, Ingress)  
- NGINX Ingress Controller  
- AWS Route 53  
- Amazon EBS  
- Docker & Docker Hub  

---

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


  #### Key Characteristics

  - No manual deployments required

  - Uses declarative Kubernetes manifests

  - Supports safe, repeatable deployments

  - Separates application code from infrastructure configuration

📌 The pipeline has been executed successfully to deploy and update the application on the EKS cluster.
        
        - Successful pipeline runs can be seen in the GitHub Actions tab of this repository.

## 🔧 Kubernetes Design Choices

### Namespace Isolation

All resources are deployed in a dedicated namespace:
chinmayee

This ensures clean separation within a shared EKS cluster.

---

### Service-to-Service Communication

- Internal communication uses **ClusterIP Services**
- No hard-coded IP addresses
- Services communicate via **Kubernetes DNS**

Examples:
chinmayee-svc-postgres
chinmayee-svc-redis

---

### Ingress & DNS

- Shared **NGINX Ingress Controller** for the cluster
- Separate **Ingress resource** for this project
- Host-based routing configured using **AWS Route 53**

| URL | Description |
|----|------------|
| http://vote.app.chin.diogohack.shop | Voting frontend |
| http://result.app.chin.diogohack.shop | Results dashboard |

---

### Stateful Workload (Postgres)

- PostgreSQL uses an **EBS-backed PersistentVolumeClaim**
- `PGDATA` subdirectory used to avoid filesystem conflicts
- Data persists across pod restarts

---

## 🧪 Validation & Testing

### Kubernetes Checks

- kubectl get pods -n chinmayee
- kubectl get svc -n chinmayee
- kubectl get endpoints -n chinmayee
- kubectl get ingress -n chinmayee

### Application Testing

curl http://vote.app.chin.diogohack.shop
curl http://result.app.chin.diogohack.shop

### Useful Debugging Commands

- kubectl describe pod <pod-name> -n chinmayee
- kubectl logs <pod-name> -n chinmayee
- kubectl get endpoints -n chinmayee
- kubectl get ingress -n chinmayee

#### Votes successfully flow through:

Vote → Redis → Worker → Postgres → Result

### Voting 
#### http://vote.app.chin.diogohack.shop
<img width="1610" height="943" alt="Vote-with-domain" src="https://github.com/user-attachments/assets/aa4488ae-abc9-48ca-b409-d25da96792ca" />

### Result
#### http://result.app.chin.diogohack.shop
<img width="1718" height="1004" alt="result-domain" src="https://github.com/user-attachments/assets/1e35a0b9-ea4a-4aba-ad9d-8cd4d947a2c0" />



### 🛠 Key Challenges & Solutions
| Challenge                              | Problem / Symptoms                                                                          | Root Cause                                                                                          | Solution Implemented                                                                                    | Result                                                                 |
| -------------------------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| **WebSocket Failures Behind Ingress**  | Result page loaded blank; WebSocket connections to Socket.IO endpoint returned `400` errors | Default ingress controller did not handle WebSocket upgrade headers correctly                       | Deployed **Community NGINX Ingress Controller** and configured it to properly support WebSocket traffic | WebSocket connections succeeded and real-time results loaded correctly |
| **PostgreSQL CrashLoop on EBS Volume** | PostgreSQL pod failed to start and entered `CrashLoopBackOff`                               | EBS volumes contained a default `lost+found` directory; PostgreSQL requires an empty data directory | Mounted PostgreSQL data using a `subPath` instead of the volume root                                    | Database initialized successfully with persistent storage              |

### 🚀 Future Enhancements

- Implement Horizontal Pod Autoscaler (HPA)
- Enable HTTPS on Ingress to serve applications securely over HTTPS.
- Add monitoring with Prometheus and Grafana

### 🎯 Key Learnings

- Hands-on experience deploying applications to Amazon EKS
- Understanding Kubernetes networking, Services, and Ingress
- Managing stateful applications with persistent storage
- Automating deployments using GitHub Actions
- Systematic debugging of Kubernetes and application issues


### 👩‍💻 Author

Chinmayee Pradhan
Aspiring Cloud / DevOps Engineer
📍 Netherlands

⭐ Feel free to explore the repository or reach out for feedback
