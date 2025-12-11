# Java/Spring Boot Production Dockerfile
# Multi-stage build with JVM optimization
#
# Build: docker build -t myapp .
# Run:   docker run -p 8080:8080 myapp
#
# ===========================================
# OS/Platform Considerations
# ===========================================
#
# JDK Distributions:
#   - eclipse-temurin: Recommended, widely tested (formerly AdoptOpenJDK)
#   - amazoncorretto:  AWS optimized, good for ECS/EKS
#   - azul/zulu:       Enterprise support available
#   - bellsoft/liberica: Smaller footprint option
#   - graalvm:         For native compilation (see GraalVM section)
#
# Base OS Options:
#   - alpine:     Smallest (~100MB), uses musl libc
#   - debian:     Standard glibc (~200MB)
#   - ubi-minimal: Red Hat Universal Base Image
#
# Choose Alpine UNLESS:
#   - You use JNI libraries compiled against glibc
#   - You need specific native libraries
#   - You experience "UnsatisfiedLinkError"
#
# Known Alpine Issues:
#   - Some JDBC drivers need glibc (use gcompat)
#   - Async profiler may not work
#   - Some APM agents require glibc
#
# Platform Support:
#   - linux/amd64: Full support
#   - linux/arm64: Full support (Graviton, M1/M2)
#   - Windows: Requires WSL2 + Docker Desktop

# ===========================================
# Build Arguments
# ===========================================
ARG JAVA_VERSION=21
ARG BUILD_TYPE=maven
# Options: maven, gradle
ARG JVM_IMPL=eclipse-temurin
# Options: eclipse-temurin, amazoncorretto, azul/zulu
ARG BASE_OS=alpine
# Options: alpine, jammy (Ubuntu 22.04)

# ===========================================
# Build Stage
# ===========================================
FROM ${JVM_IMPL}:${JAVA_VERSION}-jdk-${BASE_OS} AS builder
WORKDIR /app

# Install build tools based on build type
ARG BUILD_TYPE
RUN if [ "${BUILD_TYPE}" = "gradle" ]; then \
      if [ -f /etc/alpine-release ]; then \
        apk add --no-cache gradle; \
      else \
        apt-get update && apt-get install -y gradle && rm -rf /var/lib/apt/lists/*; \
      fi; \
    fi

# Copy build files first (for layer caching)
COPY pom.xml mvnw* ./
COPY .mvn .mvn 2>/dev/null || true
COPY build.gradle* settings.gradle* gradlew* ./
COPY gradle gradle 2>/dev/null || true

# Download dependencies (cached layer)
RUN if [ -f pom.xml ]; then \
      ./mvnw dependency:go-offline -B || mvn dependency:go-offline -B; \
    elif [ -f build.gradle ]; then \
      ./gradlew dependencies --no-daemon || gradle dependencies; \
    fi

# Copy source code
COPY src src

# Build application
RUN if [ -f pom.xml ]; then \
      ./mvnw package -DskipTests -B || mvn package -DskipTests -B; \
    elif [ -f build.gradle ]; then \
      ./gradlew build -x test --no-daemon || gradle build -x test; \
    fi

# Extract layers for Spring Boot (if applicable)
RUN if [ -f target/*.jar ]; then \
      java -Djarmode=layertools -jar target/*.jar extract --destination extracted || \
      mkdir -p extracted && cp target/*.jar extracted/app.jar; \
    elif [ -f build/libs/*.jar ]; then \
      java -Djarmode=layertools -jar build/libs/*.jar extract --destination extracted || \
      mkdir -p extracted && cp build/libs/*.jar extracted/app.jar; \
    fi

# ===========================================
# Runtime Stage
# ===========================================
FROM ${JVM_IMPL}:${JAVA_VERSION}-jre-${BASE_OS} AS runtime
WORKDIR /app

# Install runtime dependencies
RUN if [ -f /etc/alpine-release ]; then \
      apk add --no-cache \
        curl \
        tzdata \
        # For glibc compatibility (uncomment if needed):
        # gcompat \
        # libc6-compat \
        && rm -rf /var/cache/apk/*; \
    else \
      apt-get update && apt-get install -y --no-install-recommends \
        curl \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Create non-root user
RUN if [ -f /etc/alpine-release ]; then \
      addgroup -g 1001 -S app && adduser -S app -u 1001 -G app; \
    else \
      groupadd -g 1001 app && useradd -u 1001 -g app -s /bin/bash app; \
    fi

# Copy application (Spring Boot layered or standard JAR)
COPY --from=builder --chown=app:app /app/extracted/dependencies/ ./
COPY --from=builder --chown=app:app /app/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=app:app /app/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=app:app /app/extracted/application/ ./
# Fallback for non-layered JAR
COPY --from=builder --chown=app:app /app/extracted/app.jar ./app.jar 2>/dev/null || true

# Switch to non-root user
USER app

# ===========================================
# JVM Configuration
# ===========================================
ENV JAVA_OPTS="\
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=50.0 \
    -XX:+UseG1GC \
    -XX:+UseStringDeduplication \
    -Djava.security.egd=file:/dev/./urandom \
    -Dspring.profiles.active=production"

# For virtual threads (Java 21+):
# -Djdk.virtualThreadScheduler.parallelism=4

# For ZGC (low latency):
# -XX:+UseZGC -XX:+ZGenerational

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

# Entry point
# Spring Boot layered:
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
# Standard JAR (uncomment if not using layers):
# ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]


# ===========================================
# GraalVM Native Image (Optional)
# ===========================================
# For native compilation, use this instead:
#
# FROM ghcr.io/graalvm/native-image:ol8-java21 AS native-builder
# WORKDIR /app
# COPY --from=builder /app/target/*.jar app.jar
# RUN native-image -jar app.jar -o app \
#     --no-fallback \
#     --enable-url-protocols=http,https \
#     -H:+ReportExceptionStackTraces
#
# FROM alpine:3.19 AS native-runtime
# WORKDIR /app
# RUN apk add --no-cache curl
# COPY --from=native-builder /app/app ./app
# RUN addgroup -g 1001 -S app && adduser -S app -u 1001
# USER app
# EXPOSE 8080
# CMD ["./app"]


# ===========================================
# Caveats & Troubleshooting
# ===========================================
#
# 1. "UnsatisfiedLinkError" on Alpine:
#    Some native libraries need glibc. Options:
#    a) Switch to debian base: --build-arg BASE_OS=jammy
#    b) Install gcompat: add "gcompat" to apk install
#    c) Use distroless: gcr.io/distroless/java21-debian12
#
# 2. Memory Issues (OOMKilled):
#    - Container doesn't respect memory limits by default
#    - MUST use -XX:+UseContainerSupport (included above)
#    - Adjust MaxRAMPercentage (default 75% is conservative)
#
# 3. Slow Startup:
#    Options to improve:
#    a) Use CDS (Class Data Sharing): -Xshare:on
#    b) Use GraalVM native image (see above)
#    c) Spring Boot 3.2+: -Dspring.aot.enabled=true
#    d) Use tiered compilation: -XX:TieredStopAtLevel=1
#
# 4. CPU Throttling:
#    JVM may over-parallelize. Set:
#    -XX:ActiveProcessorCount=2
#
# 5. ARM64 / Apple Silicon:
#    - All major JDKs support ARM64
#    - Some older libraries may not (check native deps)
#    - GraalVM native image: use --platform linux/amd64 if issues
#
# 6. Windows Host Development:
#    - Use WSL2 + Docker Desktop
#    - Maven wrapper (mvnw) needs LF line endings
#    - Convert with: sed -i 's/\r$//' mvnw
#
# 7. Large Image Size:
#    - Use jlink to create custom JRE:
#      jlink --add-modules java.base,java.logging --output custom-jre
#    - Or use distroless images
#    - Consider GraalVM native for smallest size
#
# 8. Profiling in Container:
#    Add JVM flags: -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints
#    For async-profiler on Alpine: may need glibc
