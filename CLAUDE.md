# Self-Deploy Handoff

You are helping a user make their codebase self-deployable using Cloudflare Tunnel and Docker.

---

## Phase 1: Assessment

### 1.1 Gather Information

Ask the user these questions (skip any already answered):

```
1. What is your target domain/subdomain? (e.g., app.example.com)
2. What services does your app have? (e.g., frontend, API, worker, database)
3. What ports do they run on?
4. What runtime/language for each service? (Node, Python, Go, etc.)
5. Do you have existing Docker/docker-compose files?
6. What secrets/env vars are required? (list names only, not values)
7. Windows (WSL2) or native Linux deployment?
```

### 1.2 Detect Stack

Scan the codebase for these markers:

| File | Indicates |
|------|-----------|
| `package.json` | Node.js service |
| `requirements.txt` / `pyproject.toml` | Python service |
| `go.mod` | Go service |
| `Cargo.toml` | Rust service |
| `docker-compose.yml` | Existing containerization |
| `Dockerfile` | Existing container config |
| `nginx.conf` | Reverse proxy setup |
| `redis` in dependencies | Cache/queue layer |
| `celery` / `bull` / `sidekiq` | Background workers |

### 1.3 Select Orchestration Level

```
START
  │
  ├─ Single service? ─────────────────────► Level 0: Direct runtime
  │
  ├─ 2-3 services, same machine? ─────────► Level 1: Shell scripts + systemd/pm2
  │
  ├─ 3-5 services, need restart? ─────────► Level 2: Supervisord
  │
  ├─ 5+ services OR multi-machine? ───────► Level 3: Docker Compose
  │
  ├─ Auto-scaling required? ──────────────► Level 4: Docker Swarm / Nomad
  │
  └─ Enterprise compliance required? ─────► Level 5: Kubernetes
```

Default to the lowest level that satisfies requirements.

---

## Phase 2: Generate Configuration

### 2.1 Create Directory Structure

```
deploy/
├── .env.example          # Environment template
├── config.yml            # Cloudflare tunnel config
├── docker-compose.yml    # Container orchestration (if needed)
├── Dockerfile            # Per-service (if not exists)
├── start.sh              # Linux startup script
├── start.bat             # Windows startup script
└── stop.sh / stop.bat    # Shutdown scripts
```

### 2.2 Environment Template

Generate `deploy/.env.example`:

```bash
# ===========================================
# Self-Deploy Configuration
# Copy to .env and fill in values
# ===========================================

# Cloudflare Tunnel
TUNNEL_NAME=your-tunnel-name
DOMAIN=your-app.example.com

# Service Ports
PORT_FRONTEND=3000
PORT_API=8000
PORT_REDIS=6379

# Secrets (fill in your values)
# [GENERATE BASED ON DETECTED DEPENDENCIES]

# Environment
APP_ENV=production
DEBUG=false
```

### 2.3 Cloudflare Tunnel Config

Generate `deploy/config.yml`:

```yaml
tunnel: ${TUNNEL_ID}
credentials-file: ~/.cloudflared/${TUNNEL_ID}.json

ingress:
  # [GENERATE BASED ON SERVICES DETECTED]
  - hostname: ${DOMAIN}
    service: http://localhost:${PORT_FRONTEND}
  # API subdomain (optional)
  # - hostname: api.${DOMAIN}
  #   service: http://localhost:${PORT_API}
  - service: http_status:404
```

### 2.4 Docker Compose (Level 3+)

Generate `deploy/docker-compose.yml`:

```yaml
version: '3.8'

services:
  # [GENERATE BASED ON DETECTED SERVICES]

  # Example frontend
  frontend:
    build:
      context: ../web
      dockerfile: Dockerfile
    ports:
      - "${PORT_FRONTEND}:${PORT_FRONTEND}"
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # Example API
  api:
    build:
      context: ../api
      dockerfile: Dockerfile
    ports:
      - "${PORT_API}:${PORT_API}"
    env_file:
      - .env
    depends_on:
      - redis
    restart: unless-stopped

  # Redis (if detected)
  redis:
    image: redis:7-alpine
    ports:
      - "${PORT_REDIS}:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped

volumes:
  redis-data:
```

### 2.5 Startup Scripts

Generate `deploy/start.sh`:

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "Starting services..."

# [GENERATE BASED ON ORCHESTRATION LEVEL]

# Level 0-2: Direct processes
# [SERVICE_START_COMMANDS]

# Level 3+: Docker Compose
# docker-compose up -d

# Start Cloudflare Tunnel
cloudflared tunnel run $TUNNEL_NAME &

echo "Services started. Access at https://$DOMAIN"
```

Generate `deploy/start.bat`:

```batch
@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

:: Load environment
for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    if not "%%a"=="" if not "%%a:~0,1%"=="#" set "%%a=%%b"
)

echo Starting services...

:: [GENERATE BASED ON ORCHESTRATION LEVEL]

:: Start Cloudflare Tunnel
start /b cloudflared tunnel run %TUNNEL_NAME%

echo Services started. Access at https://%DOMAIN%
```

### 2.6 Dockerfile Templates

**Node.js:**
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE ${PORT}
CMD ["node", "dist/index.js"]
```

**Python:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE ${PORT}
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "${PORT}"]
```

**Go:**
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o main .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/main .
EXPOSE ${PORT}
CMD ["./main"]
```

---

## Phase 3: Setup Instructions

After generating configs, provide these instructions:

### 3.1 One-Time Setup

```markdown
## Cloudflare Tunnel Setup

1. Install cloudflared:
   - Windows: `winget install cloudflare.cloudflared`
   - Linux: `sudo apt install cloudflared`

2. Authenticate:
   ```bash
   cloudflared tunnel login
   ```

3. Create tunnel:
   ```bash
   cloudflared tunnel create ${TUNNEL_NAME}
   ```

4. Route DNS:
   ```bash
   cloudflared tunnel route dns ${TUNNEL_NAME} ${DOMAIN}
   ```

5. Copy tunnel ID to `deploy/config.yml`
```

### 3.2 Deployment Commands

```markdown
## Deploy

1. Copy environment file:
   ```bash
   cp deploy/.env.example deploy/.env
   # Edit deploy/.env with your values
   ```

2. Start services:
   ```bash
   # Linux
   ./deploy/start.sh

   # Windows
   deploy\start.bat
   ```

3. Verify:
   ```bash
   curl https://${DOMAIN}/health
   ```
```

---

## Phase 4: Validation Checklist

Before completing, verify:

- [ ] `.env.example` lists all required variables
- [ ] `.env` is in `.gitignore`
- [ ] Cloudflare config has correct hostnames
- [ ] All services have health endpoints
- [ ] Startup scripts handle all services
- [ ] Ports don't conflict
- [ ] Dockerfiles exist for containerized services
- [ ] README updated with deploy instructions

---

## Decision Reference

### Port Allocation Convention

| Service Type | Default Port |
|-------------|--------------|
| Frontend | 3000 |
| API | 8000 |
| Admin | 8080 |
| Redis | 6379 |
| PostgreSQL | 5432 |
| MongoDB | 27017 |

### When to Use What

| Scenario | Recommendation |
|----------|----------------|
| Static site + API | Level 1, separate processes |
| Monorepo with 3 services | Level 2, Supervisord |
| Microservices | Level 3, Docker Compose |
| High availability needed | Level 4, Swarm/Nomad |
| Enterprise/compliance | Level 5, Kubernetes |

---

## Error Recovery

| Issue | Resolution |
|-------|------------|
| Port already in use | Check with `netstat`, kill process or change port |
| Tunnel auth failed | Re-run `cloudflared tunnel login` |
| Docker build fails | Check Dockerfile paths, dependencies |
| Service won't start | Check logs, verify env vars set |
| DNS not resolving | Wait for propagation, verify Cloudflare dashboard |

---

## Example Execution

When user says "make this self-deployable":

1. Read this document
2. Scan codebase for stack markers
3. Ask missing questions from 1.1
4. Select orchestration level from 1.3
5. Generate configs from Phase 2
6. Output setup instructions from Phase 3
7. Run validation checklist from Phase 4
