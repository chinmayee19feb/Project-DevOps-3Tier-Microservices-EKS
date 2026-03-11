# Cloud Wars — Secure 3-Tier Voting App on Amazon EKS

> Production-grade deployment with HTTPS, WebSocket support, cert-manager, and a cyberpunk-themed UI.

---

## Live URLs

| App | URL |
|-----|-----|
| Vote | https://ai-fairy-vote.duckdns.org |
| Result | https://ai-fairy-result.duckdns.org |

Both endpoints are served over **HTTPS** with automatic certificate management.

---

## What Changed (feature/ai-insights)

### 1. HTTPS with cert-manager & Let's Encrypt

All traffic is encrypted end-to-end using TLS certificates issued by Let's Encrypt, managed automatically by cert-manager.

#### How It Works

```
User (HTTPS) → NGINX Ingress (TLS termination) → ClusterIP Services → Pods
```

#### cert-manager Setup

1. **Install cert-manager** on the EKS cluster:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
   ```

2. **Create a ClusterIssuer** for Let's Encrypt production:
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

3. **Ingress annotations** request the certificate automatically:
   ```yaml
   annotations:
     cert-manager.io/cluster-issuer: "letsencrypt-prod"
     nginx.ingress.kubernetes.io/ssl-redirect: "true"
   ```

4. **TLS block** in the Ingress spec defines which hosts to secure:
   ```yaml
   spec:
     tls:
     - hosts:
       - ai-fairy-vote.duckdns.org
       - ai-fairy-result.duckdns.org
       secretName: ai-fairy-tls
   ```

#### What cert-manager Does Automatically

- Requests a TLS certificate from Let's Encrypt for both domains
- Stores the certificate in the Kubernetes secret `ai-fairy-tls`
- Renews the certificate before it expires (every ~60 days)
- The NGINX Ingress Controller picks up the secret and terminates TLS

#### Verifying the Certificate

```bash
# Check certificate status
kubectl get certificate -n chinmayee

# Check the secret
kubectl get secret ai-fairy-tls -n chinmayee

# Describe the certificate for details
kubectl describe certificate ai-fairy-tls -n chinmayee

# Test HTTPS externally
curl -v https://ai-fairy-vote.duckdns.org 2>&1 | grep "SSL certificate"
```

---

### 2. DNS with DuckDNS

Switched from Route 53 (`chin.diogohack.shop`) to **DuckDNS** (`duckdns.org`) — a free dynamic DNS service.

| Domain | Points To |
|--------|-----------|
| `ai-fairy-vote.duckdns.org` | NGINX Ingress Load Balancer IP |
| `ai-fairy-result.duckdns.org` | NGINX Ingress Load Balancer IP |

---

### 3. WebSocket Support for Live Results — The Biggest Challenge

This was the **longest and most difficult challenge** faced during the project.

#### The Problem

The browser was throwing **400 errors** when trying to connect to the Socket.IO endpoint. While the app could still communicate using HTTP polling, all attempts to upgrade to WebSocket were failing. The Result page stayed **completely blank** — even though the backend pods were healthy.

#### Debugging Process

1. **Checked NGINX Ingress logs** — confirmed the ingress controller wasn't handling WebSocket traffic properly. The upgrade headers were being dropped.

2. **Reviewed the existing ingress setup** — the original ingress (`chinmayee-ingress`) used the shared cluster ingress class (`chinmayee-nginx` / `nginx`). This controller wasn't configured to handle WebSocket upgrade requests.

3. **Studied Kubernetes documentation** — went through the official NGINX Ingress Controller docs to understand how WebSocket proxying works and what annotations are required.

4. **Deployed a separate Community NGINX Ingress Controller** — for trial purposes, created a new ingress controller with the class `nginx-websocket`, specifically configured to handle WebSocket connections properly.

#### The Evolution (visible in the commented-out lines in `ingress.yaml`)

The ingress file tells the full story through its commented-out lines:

```yaml
# Original ingress name and class (didn't support WebSocket)
#name: chinmayee-ingress
#kubernetes.io/ingress.class: chinmayee-nginx
# kubernetes.io/ingress.class: nginx
#ingressClassName: "chinmayee-nginx"
# ingressClassName: nginx

# Timeout annotations tried during debugging
# nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
# nginx.ingress.kubernetes.io/proxy-send-timeout: "2600"
# nginx.ingress.kubernetes.io/websocket-services: "chinmayee-svc-result"
```

Each commented-out line represents a different approach that was tried. The old ingress name, the old ingress classes, and the timeout annotations were all part of the debugging journey.

#### The Solution

Deployed the **Community NGINX Ingress Controller** with a dedicated class (`nginx-websocket`) and configured the ingress with proper WebSocket support:

```yaml
# New ingress name and class
name: chinmayee-ingress-websocket
kubernetes.io/ingress.class: "nginx-websocket"
ingressClassName: nginx-websocket

# WebSocket annotations
nginx.ingress.kubernetes.io/websocket-services: "chinmayee-svc-result"
nginx.ingress.kubernetes.io/proxy-set-header: "Upgrade $http_upgrade"
nginx.ingress.kubernetes.io/proxy-set-header: "Connection $connection_upgrade"
```

**Dedicated ingress paths for Socket.IO:**
```yaml
- path: /result/socket.io
  pathType: Prefix
  backend:
    service:
      name: chinmayee-svc-result
      port:
        number: 80
- path: /socket.io
  pathType: Prefix
  backend:
    service:
      name: chinmayee-svc-result
      port:
        number: 80
```

#### Result

WebSocket connections started working as expected. The Result page loads properly in the browser with **real-time vote updates** via Socket.IO over WSS (WebSocket Secure), since TLS is terminated at the ingress.

---

### 4. Cyberpunk "Cloud Wars" UI

Both the Vote and Result frontends were redesigned with a cyberpunk/sci-fi theme:

- Animated cyber grid background and scanline overlay
- Floating particle effects
- Glitch text animation for titles
- Neon glow buttons (AWS vs Azure)
- Real-time progress bars on the Result page
- Winner/tied indicator badges
- Orbitron + Rajdhani fonts from Google Fonts
- Fully responsive design

---

### 5. Application Code Changes

#### Vote App (`vote/app.py`)
- Redis host and port are now configurable via environment variables (`REDIS_HOST`, `REDIS_PORT`)
- Defaults remain backward-compatible (`redis:6379`)

#### Result App (`result/views/app.js`)
- Socket.IO connects with path `/result/socket.io` for proper routing behind ingress
- Supports both `websocket` and `polling` transports

#### Cross-app Navigation
- Vote page links to `https://ai-fairy-result.duckdns.org`
- Result page links to `https://ai-fairy-vote.duckdns.org`
- Auto-detects `localhost` for local port-forward development

---

## Security Summary

| Layer | Mechanism | Details |
|-------|-----------|---------|
| TLS Certificates | cert-manager + Let's Encrypt | Auto-provisioned & auto-renewed |
| HTTPS Enforcement | NGINX Ingress | `ssl-redirect: "true"` — HTTP → HTTPS redirect |
| Certificate Storage | Kubernetes Secret | `ai-fairy-tls` in namespace `chinmayee` |
| WebSocket Security | WSS | Encrypted via TLS termination at ingress |
| DNS | DuckDNS | Free dynamic DNS pointing to ingress LB |

---

## Architecture

```
                        ┌─────────────────────────────┐
                        │        Internet (HTTPS)      │
                        └──────────────┬──────────────┘
                                       │
                        ┌──────────────▼──────────────┐
                        │   NGINX Ingress Controller   │
                        │   (TLS termination via       │
                        │    cert-manager/Let's Encrypt)│
                        └──────┬───────────────┬──────┘
                               │               │
              ai-fairy-vote    │               │  ai-fairy-result
                               │               │
                     ┌─────────▼───┐   ┌───────▼─────────┐
                     │  Vote (Flask)│   │ Result (Node.js) │
                     └──────┬──────┘   └───────▲─────────┘
                            │                  │
                     ┌──────▼──────┐   ┌───────┴─────────┐
                     │    Redis     │   │   PostgreSQL     │
                     └──────┬──────┘   └───────▲─────────┘
                            │                  │
                     ┌──────▼──────────────────┴─────────┐
                     │          Worker (.NET)              │
                     └────────────────────────────────────┘
```

---

## Key Challenges & Solutions

| Challenge | Symptoms | Root Cause | Solution | Result |
|-----------|----------|------------|----------|--------|
| **WebSocket Failures Behind Ingress** (Longest challenge) | Result page blank; browser throwing `400` errors on Socket.IO endpoint; HTTP polling worked but WebSocket upgrade failed | The shared cluster ingress controller (`chinmayee-nginx` / `nginx`) did not handle WebSocket upgrade headers — it dropped the `Upgrade` and `Connection` headers | Deployed a separate **Community NGINX Ingress Controller** with class `nginx-websocket`, added WebSocket annotations, and created dedicated `/socket.io` and `/result/socket.io` ingress paths | WebSocket connections working as expected; real-time results load properly |
| **PostgreSQL CrashLoop on EBS Volume** | PostgreSQL pod in `CrashLoopBackOff` | EBS volumes contain a default `lost+found` directory; PostgreSQL requires an empty data directory | Mounted PostgreSQL data using a `subPath` instead of the volume root | Database initialized successfully with persistent storage |

---

## Files Modified

| File | Change |
|------|--------|
| `k8s/ingress.yaml` | TLS, cert-manager, WebSocket support, DuckDNS hosts |
| `vote/app.py` | Configurable Redis connection |
| `vote/templates/index.html` | Cyberpunk UI redesign |
| `vote/static/stylesheets/style.css` | Cyberpunk styles |
| `result/views/index.html` | Cyberpunk UI redesign |
| `result/views/stylesheets/style.css` | Cyberpunk styles |
| `result/views/app.js` | Socket.IO path fix for ingress routing |

---

## Author

Chinmayee Pradhan
Aspiring Cloud / DevOps Engineer
