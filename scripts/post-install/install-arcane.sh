#!/usr/bin/env bash
set -Eeuo pipefail

# Install or update Arcane using its official basic Docker Compose layout.
# Secrets are generated on the VM and are never stored in this repository.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# /opt is part of the immutable deployment on bootc; keep mutable service
# configuration under /var.
ARCANE_ROOT="${ARCANE_ROOT:-/var/lib/arcane}"
PROJECTS_DIR="${PROJECTS_DIR:-/var/lib/arcane/projects}"
BUILDS_DIR="${BUILDS_DIR:-/var/lib/arcane/builds}"
ARCANE_VERSION="${ARCANE_VERSION:-latest}"
ARCANE_PORT="${ARCANE_PORT:-3552}"

"$SCRIPT_DIR/prepare-host.sh"

compose_file="$ARCANE_ROOT/compose.yaml"
env_file="$ARCANE_ROOT/.env"

random_secret() {
    # 32 bytes, encoded without punctuation that could confuse dotenv parsing.
    openssl rand -hex 32
}

command -v openssl >/dev/null 2>&1 || {
    echo "Required command not found: openssl" >&2
    exit 1
}

# Preserve existing secrets on upgrades, while creating them on first install.
if [[ ! -f "$env_file" ]]; then
    umask 077
    cat > "$env_file" <<EOF
ARCANE_VERSION=$ARCANE_VERSION
ARCANE_PORT=$ARCANE_PORT
ARCANE_ROOT=$ARCANE_ROOT
PROJECTS_DIRECTORY=$PROJECTS_DIR
BUILDS_DIRECTORY=$BUILDS_DIR
PUID=$(id -u)
PGID=$(id -g)
TZ=${TZ:-UTC}
ENCRYPTION_KEY=$(random_secret)
JWT_SECRET=$(random_secret)
EOF
    chmod 600 "$env_file"
else
    chmod 600 "$env_file"
    echo "Using existing Arcane environment and secrets: $env_file"
fi

cat > "$compose_file" <<'EOF'
services:
  arcane:
    image: ghcr.io/getarcaneapp/manager:${ARCANE_VERSION}
    container_name: arcane
    ports:
      - "${ARCANE_PORT}:3552"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - arcane-data:/app/data
      - ${PROJECTS_DIRECTORY}:${PROJECTS_DIRECTORY}
      - ${BUILDS_DIRECTORY}:${BUILDS_DIRECTORY}
    environment:
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      JWT_SECRET: ${JWT_SECRET}
      PROJECTS_DIRECTORY: ${PROJECTS_DIRECTORY}
      TZ: ${TZ}
      PUID: ${PUID}
      PGID: ${PGID}
    cgroup: host
    healthcheck:
      test: ["CMD", "./arcane", "health", "--timeout", "2s"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 15s
    restart: unless-stopped

volumes:
  arcane-data:
EOF

# Older compose projects may have been created with the conventional mutable
# path /data/compose. That path cannot exist at the root of an immutable bootc
# deployment, so migrate only that known path to the configured mutable path.
if [[ -d "$PROJECTS_DIR" ]]; then
    while IFS= read -r -d '' project_file; do
        sed -i "s#/data/compose#${PROJECTS_DIR}#g" "$project_file"
    done < <(find "$PROJECTS_DIR" -type f \( -name '.env' -o -name '*.env' -o -name '*.yaml' -o -name '*.yml' \) -print0)
fi

cd "$ARCANE_ROOT"
docker compose --env-file "$env_file" config >/dev/null
docker compose --env-file "$env_file" pull
docker compose --env-file "$env_file" up -d

echo "Arcane is starting at http://$(hostname -I | awk '{print $1}'):${ARCANE_PORT}"
echo "Inspect with: cd $ARCANE_ROOT && docker compose logs -f arcane"
