# .NET Production Dockerfile
# Future-proof multi-stage build supporting .NET 8+ LTS
#
# Build modes:
#   Standard:      docker build -t myapp .
#   Self-contained: docker build --build-arg PUBLISH_MODE=self-contained -t myapp .
#   AOT (Native):  docker build --build-arg PUBLISH_MODE=aot -t myapp .
#   Trimmed:       docker build --build-arg PUBLISH_MODE=trimmed -t myapp .
#
# Supported project types: Web API, Blazor Server, Worker Service, Console

# ===========================================
# Build Arguments
# ===========================================
ARG DOTNET_VERSION=8.0
ARG PUBLISH_MODE=standard
# Options: standard, self-contained, aot, trimmed

# ===========================================
# Build Stage
# ===========================================
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-alpine AS build
WORKDIR /src

# Install native dependencies for AOT compilation (if needed)
RUN apk add --no-cache clang build-base zlib-dev

# Copy solution and project files for better layer caching
COPY *.sln ./
COPY */*.csproj ./

# Restore project structure and dependencies
RUN for file in $(ls *.csproj 2>/dev/null); do \
      mkdir -p ${file%.*}/ && mv $file ${file%.*}/; \
    done || true
RUN dotnet restore

# Copy source code
COPY . .

# Build and publish based on mode
ARG PUBLISH_MODE
RUN case "${PUBLISH_MODE}" in \
      "self-contained") \
        dotnet publish -c Release -o /app/publish \
          --self-contained true \
          -r linux-musl-x64 \
          /p:PublishSingleFile=true ;; \
      "aot") \
        dotnet publish -c Release -o /app/publish \
          -r linux-musl-x64 \
          /p:PublishAot=true ;; \
      "trimmed") \
        dotnet publish -c Release -o /app/publish \
          --self-contained true \
          -r linux-musl-x64 \
          /p:PublishTrimmed=true \
          /p:PublishSingleFile=true ;; \
      *) \
        dotnet publish -c Release -o /app/publish ;; \
    esac

# ===========================================
# Runtime Stage - Standard Mode
# ===========================================
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION}-alpine AS runtime-standard
WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy published app
COPY --from=build /app/publish .

# ===========================================
# Runtime Stage - Self-Contained / AOT / Trimmed
# ===========================================
FROM alpine:3.19 AS runtime-self-contained
WORKDIR /app

# Install minimal runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    icu-libs \
    curl

# Copy published app
COPY --from=build /app/publish .

# Make executable
RUN chmod +x /app/*

# ===========================================
# Final Stage - Select Runtime
# ===========================================
ARG PUBLISH_MODE
FROM runtime-${PUBLISH_MODE:-standard} AS final
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S app && adduser -S app -u 1001 -G app

# Set ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Environment configuration
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    COMPlus_EnableDiagnostics=0

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port (8080 is .NET 8+ default)
EXPOSE 8080

# Entry point - auto-detect executable
# For specific app: CMD ["./MyApp"]
CMD ["sh", "-c", "exec ./*"]


# ===========================================
# Alternative: Multi-Project Solution
# ===========================================
# If you have a multi-project solution, use this pattern instead:
#
# FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
# WORKDIR /src
#
# # Copy solution
# COPY MyApp.sln .
# COPY src/MyApp.Api/MyApp.Api.csproj src/MyApp.Api/
# COPY src/MyApp.Core/MyApp.Core.csproj src/MyApp.Core/
# COPY src/MyApp.Infrastructure/MyApp.Infrastructure.csproj src/MyApp.Infrastructure/
#
# # Restore
# RUN dotnet restore
#
# # Copy source and build
# COPY . .
# RUN dotnet publish src/MyApp.Api/MyApp.Api.csproj -c Release -o /app/publish
#
# FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
# WORKDIR /app
# COPY --from=build /app/publish .
# USER app
# EXPOSE 8080
# ENTRYPOINT ["dotnet", "MyApp.Api.dll"]


# ===========================================
# Usage Notes
# ===========================================
#
# Standard (Framework-dependent):
#   - Smallest build, requires .NET runtime
#   - Best for: Most web applications
#   docker build -t myapp .
#
# Self-contained:
#   - Includes .NET runtime, larger but portable
#   - Best for: Environments without .NET installed
#   docker build --build-arg PUBLISH_MODE=self-contained -t myapp .
#
# AOT (Ahead-of-Time):
#   - Native compilation, fastest startup
#   - Best for: Serverless, microservices
#   - Note: Some reflection features limited
#   docker build --build-arg PUBLISH_MODE=aot -t myapp .
#
# Trimmed:
#   - Removes unused code, smaller binary
#   - Best for: Size-constrained deployments
#   - Note: May break reflection-heavy code
#   docker build --build-arg PUBLISH_MODE=trimmed -t myapp .
#
# Version upgrade:
#   docker build --build-arg DOTNET_VERSION=9.0 -t myapp .
