#!/bin/bash
# Self-Deploy Stop Script (Linux)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

log() { echo "[STOP] $1"; }

# Load environment for TUNNEL_NAME
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

log "Stopping services..."

# Stop Docker Compose if exists
if [ -f docker-compose.yml ]; then
    docker-compose down
    log "Docker Compose stopped"
fi

# Stop Cloudflare Tunnel
pkill -f "cloudflared tunnel" 2>/dev/null || true
log "Cloudflare Tunnel stopped"

# Stop common processes (customize as needed)
pkill -f "uvicorn" 2>/dev/null || true
pkill -f "node dist" 2>/dev/null || true
pkill -f "celery" 2>/dev/null || true

log "All services stopped"
