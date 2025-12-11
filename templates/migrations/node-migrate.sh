#!/bin/bash
# Node.js Database Migration Script
# Supports Prisma, Knex, TypeORM, and Sequelize
#
# Usage:
#   ./node-migrate.sh [migrate|rollback|status|generate]
#
# Docker Compose usage:
#   migrate:
#     build: .
#     command: ./migrations/node-migrate.sh migrate
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

# ===========================================
# Detect ORM
# ===========================================

detect_orm() {
    if [ -f "prisma/schema.prisma" ]; then
        echo "prisma"
    elif [ -f "knexfile.js" ] || [ -f "knexfile.ts" ]; then
        echo "knex"
    elif [ -f "ormconfig.json" ] || [ -f "ormconfig.ts" ]; then
        echo "typeorm"
    elif [ -f ".sequelizerc" ] || grep -q "sequelize" package.json 2>/dev/null; then
        echo "sequelize"
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

    # Extract host and port from DATABASE_URL
    if [ -n "$DATABASE_URL" ]; then
        # Parse postgres://user:pass@host:port/db
        DB_HOST=$(echo $DATABASE_URL | sed -E 's/.*@([^:]+):.*/\1/')
        DB_PORT=$(echo $DATABASE_URL | sed -E 's/.*:([0-9]+)\/.*/\1/')

        for i in {1..30}; do
            if nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
                log "Database is ready"
                return 0
            fi
            sleep 1
        done
        error "Database connection timeout"
    fi
}

# ===========================================
# Prisma Commands
# ===========================================

prisma_migrate() {
    wait_for_db
    log "Running Prisma migrations..."
    npx prisma migrate deploy
}

prisma_rollback() {
    warn "Prisma doesn't support rollback. Use: prisma migrate resolve --rolled-back <migration>"
}

prisma_status() {
    npx prisma migrate status
}

prisma_generate() {
    npx prisma migrate dev --name "${MIGRATION_NAME:-migration}"
}

# ===========================================
# Knex Commands
# ===========================================

knex_migrate() {
    wait_for_db
    log "Running Knex migrations..."
    npx knex migrate:latest
}

knex_rollback() {
    log "Rolling back last Knex migration..."
    npx knex migrate:rollback
}

knex_status() {
    npx knex migrate:status
}

knex_generate() {
    npx knex migrate:make "${MIGRATION_NAME:-migration}"
}

# ===========================================
# TypeORM Commands
# ===========================================

typeorm_migrate() {
    wait_for_db
    log "Running TypeORM migrations..."
    npx typeorm migration:run -d ./dist/data-source.js
}

typeorm_rollback() {
    log "Rolling back last TypeORM migration..."
    npx typeorm migration:revert -d ./dist/data-source.js
}

typeorm_status() {
    npx typeorm migration:show -d ./dist/data-source.js
}

typeorm_generate() {
    npx typeorm migration:generate "./migrations/${MIGRATION_NAME:-Migration}" -d ./dist/data-source.js
}

# ===========================================
# Sequelize Commands
# ===========================================

sequelize_migrate() {
    wait_for_db
    log "Running Sequelize migrations..."
    npx sequelize-cli db:migrate
}

sequelize_rollback() {
    log "Rolling back last Sequelize migration..."
    npx sequelize-cli db:migrate:undo
}

sequelize_status() {
    npx sequelize-cli db:migrate:status
}

sequelize_generate() {
    npx sequelize-cli migration:generate --name "${MIGRATION_NAME:-migration}"
}

# ===========================================
# Execute Command
# ===========================================

case $ORM in
    prisma)
        case $COMMAND in
            migrate)   prisma_migrate ;;
            rollback)  prisma_rollback ;;
            status)    prisma_status ;;
            generate)  prisma_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    knex)
        case $COMMAND in
            migrate)   knex_migrate ;;
            rollback)  knex_rollback ;;
            status)    knex_status ;;
            generate)  knex_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    typeorm)
        case $COMMAND in
            migrate)   typeorm_migrate ;;
            rollback)  typeorm_rollback ;;
            status)    typeorm_status ;;
            generate)  typeorm_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    sequelize)
        case $COMMAND in
            migrate)   sequelize_migrate ;;
            rollback)  sequelize_rollback ;;
            status)    sequelize_status ;;
            generate)  sequelize_generate ;;
            *)         error "Unknown command: $COMMAND" ;;
        esac
        ;;
    *)
        error "No supported ORM detected. Supported: Prisma, Knex, TypeORM, Sequelize"
        ;;
esac

log "Migration command completed successfully"
