#!/bin/bash
# Python Database Migration Script
# Supports Alembic, Django, SQLAlchemy-Migrate, and Tortoise ORM
#
# Usage:
#   ./python-migrate.sh [migrate|rollback|status|generate]
#
# Docker Compose usage:
#   migrate:
#     build: .
#     command: ./migrations/python-migrate.sh migrate
#     depends_on:
#       - postgres
#     environment:
#       - DATABASE_URL=${DATABASE_URL}

set -e

COMMAND=${1:-migrate}
MIGRATION_NAME=${2:-}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[MIGRATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Activate virtualenv if exists
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# ===========================================
# Detect ORM
# ===========================================

detect_orm() {
    if [ -f "alembic.ini" ] || [ -d "alembic" ]; then
        echo "alembic"
    elif [ -f "manage.py" ] && grep -q "django" requirements.txt 2>/dev/null; then
        echo "django"
    elif [ -d "migrations" ] && grep -q "tortoise" requirements.txt 2>/dev/null; then
        echo "tortoise"
    elif grep -q "sqlalchemy-migrate" requirements.txt 2>/dev/null; then
        echo "sqlalchemy-migrate"
    else
        echo "unknown"
    fi
}

ORM=$(detect_orm)
log "Detected ORM: $ORM"

# ===========================================
# Wait for Database
# ===========================================

wait_for_db() {
    log "Waiting for database..."

    python << 'EOF'
import os
import time
import socket
from urllib.parse import urlparse

url = os.environ.get('DATABASE_URL', '')
if url:
    parsed = urlparse(url)
    host = parsed.hostname or 'localhost'
    port = parsed.port or 5432

    for i in range(30):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            sock.connect((host, port))
            sock.close()
            print(f"Database at {host}:{port} is ready")
            exit(0)
        except:
            time.sleep(1)

    print("Database connection timeout")
    exit(1)
EOF
}

# ===========================================
# Alembic Commands (SQLAlchemy)
# ===========================================

alembic_migrate() {
    wait_for_db
    log "Running Alembic migrations..."
    alembic upgrade head
}

alembic_rollback() {
    log "Rolling back last Alembic migration..."
    alembic downgrade -1
}

alembic_status() {
    alembic current
    alembic history
}

alembic_generate() {
    alembic revision --autogenerate -m "${MIGRATION_NAME:-migration}"
}

# ===========================================
# Django Commands
# ===========================================

django_migrate() {
    wait_for_db
    log "Running Django migrations..."
    python manage.py migrate --noinput
}

django_rollback() {
    if [ -z "$MIGRATION_NAME" ]; then
        error "Django rollback requires app name and migration: ./migrate.sh rollback app_name 0001"
    fi
    APP_NAME=$MIGRATION_NAME
    TARGET=${3:-zero}
    log "Rolling back Django migration: $APP_NAME to $TARGET..."
    python manage.py migrate "$APP_NAME" "$TARGET"
}

django_status() {
    python manage.py showmigrations
}

django_generate() {
    if [ -z "$MIGRATION_NAME" ]; then
        python manage.py makemigrations
    else
        python manage.py makemigrations --name "$MIGRATION_NAME"
    fi
}

# ===========================================
# Tortoise ORM Commands
# ===========================================

tortoise_migrate() {
    wait_for_db
    log "Running Tortoise ORM migrations..."
    aerich upgrade
}

tortoise_rollback() {
    log "Rolling back last Tortoise ORM migration..."
    aerich downgrade
}

tortoise_status() {
    aerich history
}

tortoise_generate() {
    aerich migrate --name "${MIGRATION_NAME:-migration}"
}

# ===========================================
# SQLAlchemy-Migrate Commands (Legacy)
# ===========================================

sqla_migrate_migrate() {
    wait_for_db
    log "Running SQLAlchemy-Migrate migrations..."
    python manage.py db upgrade
}

sqla_migrate_rollback() {
    log "Rolling back last SQLAlchemy-Migrate migration..."
    python manage.py db downgrade
}

sqla_migrate_status() {
    python manage.py db current
}

sqla_migrate_generate() {
    python manage.py db revision -m "${MIGRATION_NAME:-migration}"
}

# ===========================================
# Execute Command
# ===========================================

case $ORM in
    alembic)
        case $COMMAND in
            migrate)   alembic_migrate ;;
            rollback)  alembic_rollback ;;
            status)    alembic_status ;;
            generate)  alembic_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    django)
        case $COMMAND in
            migrate)   django_migrate ;;
            rollback)  django_rollback ;;
            status)    django_status ;;
            generate)  django_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    tortoise)
        case $COMMAND in
            migrate)   tortoise_migrate ;;
            rollback)  tortoise_rollback ;;
            status)    tortoise_status ;;
            generate)  tortoise_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    sqlalchemy-migrate)
        case $COMMAND in
            migrate)   sqla_migrate_migrate ;;
            rollback)  sqla_migrate_rollback ;;
            status)    sqla_migrate_status ;;
            generate)  sqla_migrate_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    *)
        error "No supported ORM detected. Supported: Alembic, Django, Tortoise ORM"
        ;;
esac

log "Migration command completed successfully"
