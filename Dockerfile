# NanoClaw — main process
# Runs the orchestrator with Docker socket mounted for spawning agent containers

FROM node:22-slim

# Build tools needed for better-sqlite3 native addon
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first (cache layer)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source and build
COPY tsconfig.json ./
COPY src/ src/
RUN npm run build

# Prune devDeps from the image
RUN npm prune --omit=dev

# State directories (mounted as volumes at runtime)
RUN mkdir -p store groups data logs

# Build the agent container image at startup if not present
COPY container/ container/
COPY scripts/ scripts/

# Entrypoint: ensure agent image exists, then start
COPY <<'EOF' /app/docker-entrypoint.sh
#!/bin/bash
set -e

# Build agent container if image doesn't exist
if ! docker image inspect nanoclaw-agent:latest >/dev/null 2>&1; then
  echo "Building agent container image..."
  bash /app/container/build.sh
fi

exec node dist/index.js
EOF
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
