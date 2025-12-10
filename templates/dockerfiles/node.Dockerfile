# Node.js Production Dockerfile
# Multi-stage build for minimal image size

FROM node:20-alpine AS builder
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Build application
COPY . .
RUN npm run build

# Production image
FROM node:20-alpine
WORKDIR /app

# Copy only production dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy built application
COPY --from=builder /app/dist ./dist

# Non-root user
RUN addgroup -g 1001 -S app && adduser -S app -u 1001
USER app

EXPOSE 3000
CMD ["node", "dist/index.js"]
