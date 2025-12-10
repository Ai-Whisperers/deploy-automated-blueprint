# Go Production Dockerfile
# Multi-stage build for minimal binary

FROM golang:1.21-alpine AS builder
WORKDIR /app

# Download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main .

# Production image
FROM alpine:latest
WORKDIR /app

# Security updates
RUN apk --no-cache add ca-certificates

# Copy binary
COPY --from=builder /app/main .

# Non-root user
RUN addgroup -g 1001 -S app && adduser -S app -u 1001
USER app

EXPOSE 8080
CMD ["./main"]
