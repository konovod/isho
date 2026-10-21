#!/bin/bash
# Builds Linux artifacts for the isho API and web frontend inside WSL.
#
# Run as root from Windows:
#   wsl -u root -e bash /mnt/d/projects/crystal/isho/deploy/build-wsl.sh
#
# The result is deploy/artifacts/isho-deploy.tar.gz with this layout:
#   api/bin/api, api/bin/tasks   Vue/Nuxt server build in web/.output
#   server/*                     config files consumed by server/bootstrap.sh
set -euo pipefail

REPO=${ISHO_REPO:-/mnt/d/projects/crystal/isho}
WORK=${ISHO_BUILD_DIR:-/root/isho-build}
ARTIFACTS="$REPO/deploy/artifacts"

CRYSTAL_VERSION=1.19.1
CRYSTAL_DIR="/opt/crystal-$CRYSTAL_VERSION"
NODE_DIR=/opt/node22

log() { printf '\n==> %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive

if [ ! -f /opt/.isho-build-deps ]; then
  log "Installing build dependencies"
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    libpq-dev libyaml-dev libssl-dev libevent-dev libgmp-dev libxml2-dev \
    pkg-config git curl xz-utils ca-certificates
  touch /opt/.isho-build-deps
fi

if [ ! -x "$CRYSTAL_DIR/bin/crystal" ]; then
  log "Installing Crystal $CRYSTAL_VERSION"
  crystal_url="https://github.com/crystal-lang/crystal/releases/download/$CRYSTAL_VERSION/crystal-$CRYSTAL_VERSION-1-linux-x86_64.tar.gz"
  # The GitHub release CDN occasionally stalls; resume instead of starting over.
  for attempt in $(seq 1 40); do
    if curl -fsSL -C - --max-time 240 --speed-limit 20000 --speed-time 30 \
      -o /tmp/crystal.tar.gz "$crystal_url"; then
      break
    fi
    echo "  crystal download stalled, resuming (attempt $attempt)"
    sleep 2
  done
  rm -rf "$CRYSTAL_DIR"
  mkdir -p "$CRYSTAL_DIR"
  tar -xzf /tmp/crystal.tar.gz -C "$CRYSTAL_DIR" --strip-components=1
fi

if [ ! -x "$NODE_DIR/bin/node" ]; then
  log "Installing Node.js 22"
  node_file=$(curl -fsSL --retry 5 --retry-all-errors https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt |
    grep -o 'node-v22[0-9.]*-linux-x64\.tar\.xz' | head -1)
  curl -fsSL --retry 10 --retry-all-errors -C - -o /tmp/node.tar.xz \
    "https://nodejs.org/dist/latest-v22.x/$node_file"
  mkdir -p "$NODE_DIR"
  tar -xJf /tmp/node.tar.xz -C "$NODE_DIR" --strip-components=1
fi

export PATH="$CRYSTAL_DIR/bin:$NODE_DIR/bin:$PATH"
log "Toolchain: $(crystal --version | head -1), node $(node -v)"

log "Copying sources to $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"
tar -C "$REPO" -cf - \
  --exclude=./.git \
  --exclude=./.openchamber \
  --exclude=./web/node_modules \
  --exclude=./web/.output \
  --exclude=./web/.nuxt \
  --exclude=./api/bin \
  --exclude=./api/tmp \
  --exclude=./api/public/media \
  --exclude=./deploy/artifacts \
  . | tar -C "$WORK" -xf -

log "Building API (release)"
cd "$WORK/api"
mkdir -p bin
shards install
crystal build --release --no-debug src/api.cr -o bin/api
crystal build --release --no-debug tasks.cr -o bin/tasks

log "Building web (Nuxt)"
cd "$WORK/web"
npm ci --no-audit --no-fund
npm run build

log "Packaging artifacts"
rm -rf "$WORK/package"
mkdir -p "$WORK/package/api/bin" "$WORK/package/web"
cp "$WORK/api/bin/api" "$WORK/api/bin/tasks" "$WORK/package/api/bin/"
cp -a "$WORK/web/.output" "$WORK/package/web/.output"
cp -a "$REPO/deploy/server" "$WORK/package/server"

# Files authored on Windows may have CRLF; systemd, bash and Caddy dislike it.
find "$WORK/package/server" -type f -exec sed -i 's/\r$//' {} +

{
  echo "commit=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "crystal=$(crystal --version | head -1)"
  echo "node=$(node -v)"
} > "$WORK/package/VERSION"

mkdir -p "$ARTIFACTS"
tar -czf "$ARTIFACTS/isho-deploy.tar.gz" -C "$WORK/package" .

log "Done: $ARTIFACTS/isho-deploy.tar.gz ($(du -h "$ARTIFACTS/isho-deploy.tar.gz" | cut -f1))"
cat "$WORK/package/VERSION"
