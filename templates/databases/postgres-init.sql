-- PostgreSQL Initialization Script
-- Runs automatically when container starts with empty data directory
--
-- Usage in docker-compose.yml:
--   postgres:
--     image: postgres:15-alpine
--     volumes:
--       - ./databases/postgres-init.sql:/docker-entrypoint-initdb.d/init.sql:ro
--       - postgres-data:/var/lib/postgresql/data
--     environment:
--       POSTGRES_DB: ${DB_NAME:-app}
--       POSTGRES_USER: ${DB_USER:-app}
--       POSTGRES_PASSWORD: ${DB_PASSWORD}

-- ===========================================
-- Extensions
-- ===========================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS "citext";         -- Case-insensitive text
-- CREATE EXTENSION IF NOT EXISTS "postgis";     -- Geospatial (uncomment if needed)

-- ===========================================
-- Schemas (optional, for multi-tenant or organization)
-- ===========================================

-- CREATE SCHEMA IF NOT EXISTS app;
-- SET search_path TO app, public;

-- ===========================================
-- Users Table (example)
-- ===========================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email CITEXT UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    email_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NULL;

-- ===========================================
-- Sessions Table (example)
-- ===========================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);

-- ===========================================
-- API Keys Table (example)
-- ===========================================

CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    last_used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);

-- ===========================================
-- Jobs Table (for background processing)
-- ===========================================

CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    queue VARCHAR(100) NOT NULL DEFAULT 'default',
    payload JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_jobs_queue_status ON jobs(queue, status);
CREATE INDEX idx_jobs_scheduled_at ON jobs(scheduled_at) WHERE status = 'pending';

-- ===========================================
-- Audit Log Table
-- ===========================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- ===========================================
-- Helper Functions
-- ===========================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to users table
CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- ===========================================
-- Row Level Security (optional)
-- ===========================================

-- Enable RLS on tables
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Example policy: users can only see their own data
-- CREATE POLICY users_own_data ON users
--     FOR ALL
--     USING (id = current_setting('app.current_user_id')::UUID);

-- ===========================================
-- Seed Data (development only)
-- ===========================================

-- Uncomment for development environment
-- INSERT INTO users (email, password_hash, name, role, email_verified_at)
-- VALUES
--     ('admin@example.com', '$2b$12$...', 'Admin User', 'admin', NOW()),
--     ('user@example.com', '$2b$12$...', 'Test User', 'user', NOW())
-- ON CONFLICT (email) DO NOTHING;

-- ===========================================
-- Grants (for restricted database users)
-- ===========================================

-- Create read-only user for analytics
-- CREATE USER readonly WITH PASSWORD 'readonly_password';
-- GRANT CONNECT ON DATABASE app TO readonly;
-- GRANT USAGE ON SCHEMA public TO readonly;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- Create application user with limited privileges
-- CREATE USER appuser WITH PASSWORD 'app_password';
-- GRANT CONNECT ON DATABASE app TO appuser;
-- GRANT USAGE ON SCHEMA public TO appuser;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO appuser;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO appuser;
