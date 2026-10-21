#!/bin/bash
# Provisions (or updates) an isho server on Ubuntu 24.04 and starts/restarts it.
#
# Called by deploy/deploy.ps1 with the extracted release as $1:
#   ISHO_SITE_ADDRESS=https://example.com ISHO_PUBLIC_ORIGIN=https://example.com \
#     bash /opt/isho-release/server/bootstrap.sh /opt/isho-release
#
# Idempotent: packages, users, database, secrets and env files are created once;
# the release files, migrations, seeds, systemd units and Caddyfile are replaced
# on every run.
set -euo pipefail

RELEASE=${1:-/opt/isho-release}
ISHO_HOME=/srv/isho
ENV_DIR=/etc/isho
NODE_DIR=/opt/node22

SITE_ADDRESS=${ISHO_SITE_ADDRESS:-:80}
PUBLIC_ORIGIN=${ISHO_PUBLIC_ORIGIN:-}
SEED_SAMPLE=${ISHO_SEED_SAMPLE:-0}

log() { printf '\n==> %s\n' "$*"; }

if [ ! -d "$RELEASE/api/bin" ] || [ ! -f "$RELEASE/server/bootstrap.sh" ]; then
  echo "Release at $RELEASE looks incomplete" >&2
  exit 1
fi

if [ -z "$PUBLIC_ORIGIN" ]; then
  PUBLIC_ORIGIN="http://$(hostname -I | awk '{print $1}')"
fi
PUBLIC_ORIGIN=${PUBLIC_ORIGIN%/}

if [ -n "${ISHO_COOKIE_SECURE:-}" ]; then
  COOKIE_SECURE=$ISHO_COOKIE_SECURE
else
  COOKIE_SECURE=auto
fi
case "$COOKIE_SECURE" in
  true|false) ;;
  *)
    case "$PUBLIC_ORIGIN" in
      https://*) COOKIE_SECURE=true ;;
      *) COOKIE_SECURE=false ;;
    esac
    ;;
esac

export DEBIAN_FRONTEND=noninteractive

log "Installing system packages"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  postgresql postgresql-contrib imagemagick libpq5 libyaml-0-2 \
  ca-certificates curl xz-utils

log "Ensuring swap"
if ! swapon --show | grep -q '/swapfile'; then
  if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
  fi
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' > /etc/sysctl.d/90-isho.conf
  sysctl -q -w vm.swappiness=10
fi

log "Setting time zone"
# The UI shows local dates; keep SSR in the audience's zone so server and client
# render the same time (the sample data was written for Moscow time).
timedatectl set-timezone Europe/Moscow

log "Ensuring isho user and directories"
id -u isho >/dev/null 2>&1 || useradd --system --home "$ISHO_HOME" --shell /usr/sbin/nologin isho
install -d -o isho -g isho "$ISHO_HOME/api/bin" "$ISHO_HOME/api/tmp" "$ISHO_HOME/api/public/media" "$ISHO_HOME/web"
install -d -m 0750 "$ENV_DIR"
chown root:isho "$ENV_DIR"

log "Ensuring Node.js 22"
if [ ! -x "$NODE_DIR/bin/node" ]; then
  node_file=$(curl -fsSL --retry 5 --retry-all-errors https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt |
    grep -o 'node-v22[0-9.]*-linux-x64\.tar\.xz' | head -1)
  curl -fsSL --retry 10 --retry-all-errors -C - -o /tmp/node.tar.xz \
    "https://nodejs.org/dist/latest-v22.x/$node_file"
  mkdir -p "$NODE_DIR"
  tar -xJf /tmp/node.tar.xz -C "$NODE_DIR" --strip-components=1
fi
ln -sf "$NODE_DIR/bin/node" /usr/local/bin/node
ln -sf "$NODE_DIR/bin/npm" /usr/local/bin/npm

log "Ensuring Caddy"
if ! command -v caddy >/dev/null 2>&1; then
  apt-get install -y -qq --no-install-recommends caddy
fi
# systemd units point at /usr/local/bin/caddy regardless of the package layout.
caddy_bin=/usr/bin/caddy
[ -x "$caddy_bin" ] || caddy_bin=$(command -v caddy)
ln -sfn "$caddy_bin" /usr/local/bin/caddy
id -u caddy >/dev/null 2>&1 || useradd --system --home /var/lib/caddy --shell /usr/sbin/nologin caddy
install -d -o caddy -g caddy /var/lib/caddy /etc/caddy

log "Ensuring environment files"

# set_env FILE KEY VALUE -- replace or append KEY=VALUE.
set_env() {
  local file=$1 key=$2 value=$3 tmp
  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    tmp=$(mktemp)
    awk -v k="$key" -v v="$value" '$0 ~ "^" k "=" { print k "=" v; next } { print }' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

if [ ! -f "$ENV_DIR/api.env" ]; then
  db_password=$(openssl rand -hex 16)
  secret_key=$(openssl rand -base64 64 | tr -d '\n')
  cat > "$ENV_DIR/api.env" <<EOF
LUCKY_ENV=production
PORT=4000
DATABASE_URL=postgres://isho:${db_password}@127.0.0.1:5432/isho_production
SECRET_KEY_BASE=${secret_key}
SEND_GRID_KEY=unused
EOF
fi
set_env "$ENV_DIR/api.env" SEND_GRID_KEY unused
set_env "$ENV_DIR/api.env" HOST 127.0.0.1
set_env "$ENV_DIR/api.env" APP_ORIGIN "$PUBLIC_ORIGIN"
set_env "$ENV_DIR/api.env" APP_DOMAIN "$PUBLIC_ORIGIN"
set_env "$ENV_DIR/api.env" COOKIE_SECURE "$COOKIE_SECURE"
chown root:isho "$ENV_DIR/api.env"
chmod 0640 "$ENV_DIR/api.env"

cat > "$ENV_DIR/web.env" <<EOF
NODE_ENV=production
PORT=3000
HOST=127.0.0.1
NUXT_API_INTERNAL_BASE=http://127.0.0.1:4000
EOF
chown root:isho "$ENV_DIR/web.env"
chmod 0640 "$ENV_DIR/web.env"

cat > "$ENV_DIR/caddy.env" <<EOF
ISHO_SITE_ADDRESS=$SITE_ADDRESS
EOF
chmod 0644 "$ENV_DIR/caddy.env"

log "Ensuring PostgreSQL role and database"
systemctl enable --now postgresql >/dev/null 2>&1 || true
db_password=$(sed -nE 's|^DATABASE_URL=postgres://isho:([^@]*)@.*|\1|p' "$ENV_DIR/api.env")
if [ -z "$db_password" ]; then
  echo "Cannot read the database password from $ENV_DIR/api.env" >&2
  exit 1
fi
runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'isho'" | grep -q 1 ||
  runuser -u postgres -- psql -qc "CREATE ROLE isho LOGIN PASSWORD '$db_password'"
runuser -u postgres -- psql -qc "ALTER ROLE isho WITH LOGIN PASSWORD '$db_password'"
runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'isho_production'" | grep -q 1 ||
  runuser -u postgres -- createdb -O isho isho_production

log "Installing release files"
install -m 0755 "$RELEASE/api/bin/api" "$ISHO_HOME/api/bin/api"
install -m 0755 "$RELEASE/api/bin/tasks" "$ISHO_HOME/api/bin/tasks"
rm -rf "$ISHO_HOME/web/.output"
cp -a "$RELEASE/web/.output" "$ISHO_HOME/web/.output"
install -m 0644 "$RELEASE/server/Caddyfile" /etc/caddy/Caddyfile
install -m 0644 "$RELEASE/server/isho-api.service" /etc/systemd/system/isho-api.service
install -m 0644 "$RELEASE/server/isho-web.service" /etc/systemd/system/isho-web.service
install -m 0644 "$RELEASE/server/caddy.service" /etc/systemd/system/caddy.service
chown -R isho:isho "$ISHO_HOME"
chown -R caddy:caddy /var/lib/caddy

log "Running migrations"
runuser -u isho -- bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && exec ./bin/tasks db.migrate'

log "Seeding required data"
runuser -u isho -- bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && exec ./bin/tasks db.seed.required_data'

if [ "$SEED_SAMPLE" = "1" ]; then
  log "Seeding sample data"
  runuser -u isho -- bash -c 'set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && exec ./bin/tasks db.seed.sample_data'
fi

log "Validating Caddyfile"
set -a; . "$ENV_DIR/caddy.env"; set +a
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

log "Restarting services"
systemctl daemon-reload
systemctl enable isho-api isho-web caddy >/dev/null
systemctl restart isho-api
systemctl restart isho-web
systemctl restart caddy

wait_for() {
  local url=$1 name=$2
  for _ in $(seq 40); do
    if curl -fsS -m 2 -o /dev/null "$url"; then
      log "$name is up"
      return 0
    fi
    sleep 1
  done
  log "$name did not respond at $url"
  systemctl --no-pager --lines=20 status isho-api isho-web caddy || true
  return 1
}

wait_for http://127.0.0.1:4000/api/v1/health "API"
wait_for http://127.0.0.1:3000/ "Nuxt"
wait_for "http://127.0.0.1/" "Caddy"

log "Deployed"
printf 'public origin: %s\ncaddy site:    %s\nsecure cookies: %s\n' "$PUBLIC_ORIGIN" "$SITE_ADDRESS" "$COOKIE_SECURE"
