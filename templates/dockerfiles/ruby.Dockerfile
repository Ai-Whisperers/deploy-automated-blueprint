# Ruby/Rails Production Dockerfile
# Multi-stage build with OS considerations
#
# Build: docker build -t myapp .
# Run:   docker run -p 3000:3000 myapp
#
# ===========================================
# OS/Platform Considerations
# ===========================================
#
# Base Image Options:
#   - alpine: Smallest (~50MB), uses musl libc
#   - slim:   Debian-based (~150MB), uses glibc
#   - full:   Debian with build tools (~900MB)
#
# Choose alpine UNLESS:
#   - You use gems with native extensions that require glibc
#   - You need specific system libraries (imagemagick, etc.)
#   - You experience "symbol not found" errors
#
# Known Alpine Issues:
#   - nokogiri: Works but slower compilation
#   - grpc: Requires GRPC_RUBY_BUILD_PROCS=1
#   - mysql2: May need mariadb-dev instead of mysql-dev
#   - sassc: Requires build tools during install
#
# Platform Support:
#   - linux/amd64: Full support
#   - linux/arm64: Full support (M1/M2 Macs, AWS Graviton)
#   - Windows: Requires WSL2 + Docker Desktop

# ===========================================
# Build Arguments
# ===========================================
ARG RUBY_VERSION=3.3
ARG BUNDLER_VERSION=2.5.3
ARG NODE_VERSION=20
# Base options: alpine, slim, bookworm
ARG BASE_VARIANT=alpine

# ===========================================
# Build Stage
# ===========================================
FROM ruby:${RUBY_VERSION}-${BASE_VARIANT} AS builder
WORKDIR /app

# Install build dependencies based on OS variant
RUN if [ -f /etc/alpine-release ]; then \
      # Alpine Linux
      apk add --no-cache \
        build-base \
        git \
        postgresql-dev \
        libxml2-dev \
        libxslt-dev \
        nodejs \
        npm \
        yarn \
        tzdata; \
    else \
      # Debian-based
      apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        nodejs \
        npm \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Install bundler
RUN gem install bundler -v ${BUNDLER_VERSION}

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Install JS dependencies (if applicable)
COPY package.json yarn.lock* package-lock.json* ./
RUN if [ -f yarn.lock ]; then yarn install --frozen-lockfile --production; \
    elif [ -f package-lock.json ]; then npm ci --only=production; \
    fi

# Copy application code
COPY . .

# Precompile assets (Rails)
ARG RAILS_ENV=production
ARG SECRET_KEY_BASE=placeholder_for_build
RUN if [ -f bin/rails ]; then \
      bundle exec rails assets:precompile; \
    fi

# ===========================================
# Runtime Stage
# ===========================================
FROM ruby:${RUBY_VERSION}-${BASE_VARIANT} AS runtime
WORKDIR /app

# Install runtime dependencies only
RUN if [ -f /etc/alpine-release ]; then \
      # Alpine Linux - minimal runtime deps
      apk add --no-cache \
        postgresql-client \
        libxml2 \
        libxslt \
        tzdata \
        curl \
        # For ActionCable/WebSocket (optional)
        # libc6-compat \
        && rm -rf /var/cache/apk/*; \
    else \
      # Debian-based
      apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        libxml2 \
        libxslt1.1 \
        curl \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application
COPY --from=builder /app /app

# Create non-root user
RUN if [ -f /etc/alpine-release ]; then \
      addgroup -g 1001 -S app && adduser -S app -u 1001 -G app; \
    else \
      groupadd -g 1001 app && useradd -u 1001 -g app -s /bin/bash app; \
    fi

# Set ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# ===========================================
# Environment Configuration
# ===========================================
ENV RAILS_ENV=production \
    RACK_ENV=production \
    RUBY_YJIT_ENABLE=1 \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=true

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

# Default command (adjust for your app)
# Puma (Rails default)
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

# Alternative commands:
# Unicorn:  CMD ["bundle", "exec", "unicorn", "-c", "config/unicorn.rb"]
# Thin:     CMD ["bundle", "exec", "thin", "start", "-p", "3000"]
# Falcon:   CMD ["bundle", "exec", "falcon", "serve", "-b", "http://0.0.0.0:3000"]


# ===========================================
# Caveats & Troubleshooting
# ===========================================
#
# 1. Native Extensions Fail on Alpine:
#    Switch to slim variant:
#    docker build --build-arg BASE_VARIANT=slim -t myapp .
#
# 2. "Error loading shared library":
#    Add missing library to runtime stage apk/apt install
#
# 3. Slow Asset Compilation:
#    - Use slim variant for faster native compilation
#    - Or pre-compile assets in CI and copy
#
# 4. Time Zone Issues:
#    Ensure tzdata is installed (included above)
#    Set TZ environment variable: -e TZ=America/New_York
#
# 5. Memory Issues with Puma:
#    Adjust in config/puma.rb:
#    workers ENV.fetch("WEB_CONCURRENCY") { 2 }
#    threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
#
# 6. ARM64 / Apple Silicon:
#    Most gems work, but watch for:
#    - sassc (use cssbundling-rails instead)
#    - therubyracer (deprecated, use mini_racer)
#
# 7. Windows Host Development:
#    - Use WSL2 + Docker Desktop
#    - Mount volumes may be slow; use named volumes
#    - Line endings: ensure LF not CRLF in scripts
