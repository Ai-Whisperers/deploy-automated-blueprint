# Rust Production Dockerfile
# Multi-stage build for minimal image size
#
# Build: docker build -f rust.Dockerfile -t myapp .
# Run: docker run -p 8080:8080 myapp

# Builder stage
FROM rust:1.75-alpine AS builder
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache musl-dev pkgconfig openssl-dev

# Cache dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src

# Build application
COPY . .
RUN touch src/main.rs && cargo build --release

# Runtime stage
FROM alpine:3.19
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates libgcc

# Copy binary
COPY --from=builder /app/target/release/app ./app

# Non-root user
RUN addgroup -g 1001 -S app && adduser -S app -u 1001
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/health || exit 1

EXPOSE ${PORT:-8080}
CMD ["./app"]
