# Troubleshooting Guide

**Self-Deploy Blueprint Documentation**

Common issues and solutions for self-deployed applications.

---

## Quick Diagnostics

```bash
# Check all services
docker compose ps

# View logs
docker compose logs -f

# Check resource usage
docker stats

# Test health endpoint
curl http://localhost:3000/health

# Test tunnel
curl https://your-domain.com/health
```

---

## Cloudflare Tunnel Issues

### Tunnel Not Connecting

**Symptoms:** Site unreachable, tunnel shows "Inactive"

**Solutions:**

```bash
# Check tunnel status
cloudflared tunnel info $TUNNEL_NAME

# Re-authenticate
cloudflared tunnel login

# Verify credentials file exists
ls ~/.cloudflared/*.json

# Check config syntax
cloudflared tunnel ingress validate

# Run with debug logging
cloudflared tunnel --loglevel debug run $TUNNEL_NAME
```

### DNS Not Resolving

**Symptoms:** `NXDOMAIN` or `DNS_PROBE_FINISHED_NXDOMAIN`

**Solutions:**

```bash
# Verify DNS route exists
cloudflared tunnel route dns $TUNNEL_NAME $DOMAIN

# Check Cloudflare dashboard
# Dashboard > DNS > Verify CNAME record points to tunnel

# Force DNS propagation check
nslookup $DOMAIN 1.1.1.1
dig $DOMAIN @1.1.1.1

# Wait for propagation (up to 24 hours for new domains)
```

### 502 Bad Gateway

**Symptoms:** Tunnel connects but returns 502

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Service not running | `docker compose up -d` |
| Wrong port in config | Check `config.yml` matches service port |
| Service binding to wrong interface | Bind to `0.0.0.0`, not `127.0.0.1` |
| Firewall blocking | Check `ufw status`, allow port |

```bash
# Verify service is listening
netstat -tlnp | grep :3000
ss -tlnp | grep :3000

# Test locally
curl http://localhost:3000/health
```

### WebSocket Connections Dropping

**Symptoms:** WebSocket connects then disconnects

**Solutions:**

```yaml
# In config.yml, add timeout settings:
ingress:
  - hostname: ws.example.com
    service: http://localhost:3001
    originRequest:
      connectTimeout: 60s
      tcpKeepAlive: 30s
      keepAliveTimeout: 86400s
```

---

## Docker Issues

### Container Won't Start

**Symptoms:** Container exits immediately

```bash
# Check exit code
docker compose ps -a

# View logs
docker compose logs api

# Common exit codes:
# 0: Normal exit (check CMD)
# 1: Application error
# 137: Out of memory (OOM killed)
# 139: Segmentation fault
```

### Out of Memory

**Symptoms:** Exit code 137, system slowdown

**Solutions:**

```yaml
# docker-compose.yml - Add memory limits
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

```bash
# Check memory usage
docker stats --no-stream

# Increase Docker memory (Docker Desktop)
# Settings > Resources > Memory

# WSL2: Create/edit %USERPROFILE%\.wslconfig
[wsl2]
memory=4GB
swap=2GB
```

### Port Already in Use

**Symptoms:** `Error: bind: address already in use`

```bash
# Find process using port
# Linux/WSL
sudo lsof -i :3000
sudo netstat -tlnp | grep :3000

# Windows
netstat -ano | findstr :3000

# Kill process
kill <PID>
# or Windows:
taskkill /PID <PID> /F

# Or change port in .env
PORT_FRONTEND=3001
```

### Volume Permission Issues

**Symptoms:** `Permission denied` in container

```bash
# Check volume ownership
docker compose exec api ls -la /app/data

# Fix permissions
docker compose exec api chown -R app:app /app/data

# Or in Dockerfile, before switching to non-root:
RUN chown -R app:app /app
```

### Build Cache Issues

**Symptoms:** Changes not reflecting after build

```bash
# Rebuild without cache
docker compose build --no-cache

# Remove all images and rebuild
docker compose down --rmi all
docker compose up -d --build
```

---

## Database Issues

### Connection Refused

**Symptoms:** `ECONNREFUSED` or `Connection refused`

```bash
# Check database is running
docker compose ps postgres

# Check database logs
docker compose logs postgres

# Verify network connectivity
docker compose exec api ping postgres

# Test connection
docker compose exec postgres psql -U app -d app -c "SELECT 1"
```

### Database Not Ready on Startup

**Symptoms:** App crashes because DB isn't ready

**Solutions:**

```yaml
# docker-compose.yml - Add healthcheck
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U app -d app"]
    interval: 5s
    timeout: 5s
    retries: 5

api:
  depends_on:
    postgres:
      condition: service_healthy
```

Or use wait-for script:

```bash
# wait-for-db.sh
#!/bin/bash
until pg_isready -h postgres -U app; do
  echo "Waiting for database..."
  sleep 2
done
exec "$@"
```

### Migration Failures

**Symptoms:** Migration script fails

```bash
# Check migration status
# Prisma
npx prisma migrate status

# Alembic
alembic current
alembic history

# Rollback last migration
npx prisma migrate resolve --rolled-back <migration>
alembic downgrade -1

# Reset and rerun (DESTRUCTIVE)
npx prisma migrate reset
alembic downgrade base && alembic upgrade head
```

---

## WSL2 Issues (Windows)

### Services Not Accessible from Windows

**Symptoms:** `localhost` doesn't work from Windows

```bash
# Get WSL IP
ip addr show eth0 | grep inet

# Use that IP instead of localhost
# Or enable localhostForwarding in .wslconfig

# %USERPROFILE%\.wslconfig
[wsl2]
localhostForwarding=true
```

### Docker Daemon Not Running

**Symptoms:** `Cannot connect to Docker daemon`

```bash
# Start Docker service
sudo service docker start

# Auto-start Docker (add to ~/.bashrc)
if service docker status 2>&1 | grep -q "is not running"; then
    sudo service docker start
fi
```

### Slow File System

**Symptoms:** Builds/operations very slow

**Solution:** Keep files in WSL filesystem, not Windows mounts

```bash
# Slow (Windows mount)
cd /mnt/c/Users/name/project

# Fast (WSL filesystem)
cd ~/project
```

### Network Issues After Sleep

**Symptoms:** Network stops working after Windows sleep

```bash
# Restart WSL
wsl --shutdown
# Then reopen terminal

# Or restart networking
sudo service networking restart
```

---

## Performance Issues

### High CPU Usage

```bash
# Identify culprit
docker stats
top -c

# Common causes:
# - Infinite loops in code
# - Too many workers
# - Unoptimized queries

# Reduce worker count
# Node
pm2 scale app 2

# Uvicorn
uvicorn app:app --workers 2
```

### High Memory Usage

```bash
# Check memory per container
docker stats --no-stream

# Check for memory leaks
# Node
node --inspect app.js
# Then use Chrome DevTools

# Restart workers periodically
# PM2
pm2 restart app --cron "0 */6 * * *"
```

### Slow Response Times

```bash
# Check where time is spent
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com/api/endpoint

# curl-format.txt:
time_namelookup:  %{time_namelookup}s\n
time_connect:     %{time_connect}s\n
time_appconnect:  %{time_appconnect}s\n
time_pretransfer: %{time_pretransfer}s\n
time_starttransfer: %{time_starttransfer}s\n
time_total:       %{time_total}s\n
```

---

## Logging & Debugging

### Enable Debug Logging

```bash
# Node
DEBUG=* node app.js

# Python
PYTHONUNBUFFERED=1 LOG_LEVEL=DEBUG python app.py

# Docker Compose
docker compose logs -f --tail=100
```

### Access Container Shell

```bash
# Running container
docker compose exec api sh

# Start new container with shell
docker compose run --rm api sh
```

### Inspect Container

```bash
# View container details
docker inspect $(docker compose ps -q api)

# View environment variables
docker compose exec api env

# View mounted volumes
docker compose exec api df -h
```

---

## Recovery Procedures

### Full System Restart

```bash
# Stop everything
docker compose down

# Clear volumes (WARNING: data loss)
docker compose down -v

# Rebuild and start
docker compose up -d --build

# Verify health
curl http://localhost:3000/health
```

### Database Restore

```bash
# Restore from backup
docker compose exec -T postgres psql -U app -d app < backup.sql

# Or for compressed backup
gunzip < backup.sql.gz | docker compose exec -T postgres psql -U app -d app
```

### Rollback Deployment

```bash
# Find previous image
docker images | grep myapp

# Tag and restart
docker tag myapp:previous myapp:latest
docker compose up -d
```

---

## Getting Help

### Collect Diagnostics

```bash
# Create diagnostics bundle
mkdir diagnostics
docker compose ps > diagnostics/services.txt
docker compose logs > diagnostics/logs.txt
docker stats --no-stream > diagnostics/stats.txt
cat .env.example > diagnostics/env.txt  # Never share actual .env
cloudflared tunnel info $TUNNEL_NAME > diagnostics/tunnel.txt 2>&1
```

### Where to Ask

| Resource | URL |
|----------|-----|
| Cloudflare Community | https://community.cloudflare.com |
| Docker Forums | https://forums.docker.com |
| Stack Overflow | https://stackoverflow.com/questions/tagged/docker |
| GitHub Issues | Your project's issue tracker |

---

**Version:** 1.0.0 | **Updated:** December 2025
