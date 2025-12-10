#!/bin/bash
# Self-Deploy Startup Script (Linux)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[START]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    log "Environment loaded"
else
    error ".env file not found. Copy from .env.example"
fi

# Validate required vars
[ -z "$TUNNEL_NAME" ] && error "TUNNEL_NAME not set"
[ -z "$DOMAIN" ] && error "DOMAIN not set"

# Start services based on orchestration level
if [ -f docker-compose.yml ]; then
    log "Starting Docker Compose services..."
    docker-compose up -d
else
    log "Starting services directly..."

    # Redis (if not using Docker)
    if command -v redis-server &> /dev/null; then
        redis-server --daemonize yes
        log "Redis started"
    fi

    # Add your service start commands here
    # Example:
    # cd ../api && source venv/bin/activate && uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    # cd ../web && npm start &
fi

# Start Cloudflare Tunnel
log "Starting Cloudflare Tunnel..."
cloudflared tunnel run "$TUNNEL_NAME" &

log "All services started"
log "Access your app at: https://$DOMAIN"

# Health check
sleep 5
if curl -s "http://localhost:${PORT_FRONTEND:-3000}/health" > /dev/null 2>&1; then
    log "Health check passed"
else
    warn "Health check failed - services may still be starting"
fi
