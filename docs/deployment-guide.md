# Deployment Guide

**Self-Deploy Blueprint Documentation**

Step-by-step guide for deploying products to on-premise infrastructure using Cloudflare Tunnel and WSL2 Docker.

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Windows 10/11 | 21H2+ | Or any Linux distribution |
| WSL2 | Latest | Windows only |
| Docker | 20.10+ | In WSL2, not Docker Desktop |
| Node.js | 18+ | Frontend builds |
| Python | 3.10+ | Backend services |
| cloudflared | Latest | Cloudflare Tunnel client |

---

## Step 1: Domain Configuration

### 1.1 Create Subdomain

1. Log in to your domain registrar
2. Create CNAME record:
   - **Name:** `app` (or `api`, `dashboard`, etc.)
   - **Target:** Configured by Cloudflare Tunnel

### 1.2 Configure Cloudflare

Set nameservers for your domain:
```
ns1.cloudflare.com
ns2.cloudflare.com
```

Verify:
```bash
nslookup your-domain.com
```

### 1.3 Add Domain to Cloudflare

1. [Cloudflare Dashboard](https://dash.cloudflare.com) > Add site
2. Enter your domain
3. Select plan (Free tier works)
4. Wait for DNS propagation (up to 24 hours)

---

## Step 2: Cloudflare Tunnel Setup

### 2.1 Install cloudflared

**Windows:**
```powershell
Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "cloudflared.exe"
Move-Item cloudflared.exe C:\Windows\System32\
```

**Linux:**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
```

### 2.2 Authenticate and Create Tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create my-app
cloudflared tunnel route dns my-app app.your-domain.com
```

### 2.3 Configure Tunnel

Create `~/.cloudflared/config.yml`:
```yaml
tunnel: <TUNNEL_ID>
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: app.your-domain.com
    service: http://localhost:3000
  - service: http_status:404
```

---

## Step 3: WSL2 Setup (Windows Only)

### 3.1 Install WSL2

```powershell
wsl --install
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2
```

### 3.2 Configure Memory (Optional)

Create `%USERPROFILE%\.wslconfig`:
```ini
[wsl2]
memory=4GB
swap=2GB
localhostForwarding=true
```

### 3.3 Install Docker

```bash
wsl -d Ubuntu-22.04
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
sudo service docker start
```

### 3.4 Auto-start Docker

Add to `~/.bashrc`:
```bash
if service docker status 2>&1 | grep -q "is not running"; then
    sudo service docker start
fi
```

---

## Step 4: Deploy Services

### 4.1 Clone and Configure

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
cp deploy/env.example .env
nano .env
```

Required variables:
```bash
# API Keys (as needed)
OPENAI_API_KEY=sk-your-key-here

# Cloudflare
CLOUDFLARE_TUNNEL_NAME=my-app

# Environment
APP_ENV=production
NODE_ENV=production
DEBUG=false
```

### 4.2 Start Infrastructure

```bash
# Redis (WSL)
wsl -d Ubuntu-22.04 -e bash -c "sudo service docker start && docker run -d --name redis --restart always -p 6379:6379 -v redis-data:/data redis:7-alpine"

# Redis (Linux native)
docker run -d --name redis --restart always -p 6379:6379 -v redis-data:/data redis:7-alpine
```

### 4.3 Build Applications

```bash
# Frontend
cd web && npm install && npm run build && cd ..

# Backend
cd api && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt && cd ..
```

### 4.4 Start Services

**Option A: Scripts**
```bash
deploy/start-all.bat   # Windows
./deploy/start-all.sh  # Linux
```

**Option B: Manual**
```bash
# Terminal 1: API
cd api && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2

# Terminal 2: Celery (if using)
cd api && source venv/bin/activate
celery -A app.tasks worker --loglevel=info

# Terminal 3: Frontend
cd web && NODE_ENV=production node dist/server.js

# Terminal 4: Tunnel
cloudflared tunnel run my-app
```

### 4.5 Verify

```bash
curl http://localhost:8000/health
curl http://localhost:3000/health
curl https://app.your-domain.com/health
```

---

## Step 5: Service Management

### Status
```bash
wsl -d Ubuntu-22.04 -e docker ps
netstat -ano | findstr :8000
netstat -ano | findstr :3000
```

### Stop
```bash
deploy/stop-all.bat  # or manually:
taskkill /IM python.exe /F
taskkill /IM node.exe /F
taskkill /IM cloudflared.exe /F
wsl -d Ubuntu-22.04 -e docker stop redis
```

### Logs
```bash
wsl -d Ubuntu-22.04 -e docker logs redis
cloudflared tunnel info my-app
```

---

## Architecture

```
Internet → Cloudflare (HTTPS/443) → cloudflared → Frontend (3000) → API (8000) → Redis (6379)
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tunnel not connecting | `cloudflared tunnel list` then `cloudflared tunnel login` |
| WSL Docker issues | `wsl --shutdown` then restart |
| Port conflicts | `netstat -ano \| findstr :PORT` then `taskkill /PID <pid> /F` |
| DNS not resolving | `nslookup app.your-domain.com` to verify propagation |

---

## Performance Optimization

| Level | Tool | Complexity |
|-------|------|------------|
| 1 | Supervisord | Low - process management |
| 2 | Ray + Arrow | Medium - zero-copy parallelism |
| 3 | Bare Metal Linux | Medium - no virtualization |
| 4 | Kubernetes | High - full orchestration |

---

## Security Checklist

- [ ] API keys in `.env` only (never committed)
- [ ] `.env` in `.gitignore`
- [ ] HTTPS via Cloudflare enforced
- [ ] Debug endpoints disabled
- [ ] Rate limiting configured
- [ ] CORS restricted
- [ ] Secrets rotated regularly

---

## Quick Reference

| Service | Port |
|---------|------|
| Frontend | 3000 |
| API | 8000 |
| Redis | 6379 |
| Tunnel Metrics | 20243 |

---

**Version:** 2.0.0 | **Updated:** December 2025
