#!/usr/bin/env bash
# ==============================================================================
# Odoo 20 deployment installer (single or multiple instances).
#
# Clones this repository into a NEW directory, writes that instance's .env,
# assigns unique ports and container/network names, starts the stack and waits
# until Odoo answers on /odoo. The Odoo database is created by the container
# entrypoint on first start, so no manual initialisation step is needed.
#
# Requirements: Git, Docker Engine, Docker Compose v2, permission to run Docker.
# ==============================================================================
set -Eeuo pipefail

REPOSITORY_URL="https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment.git"
DESTINATION=""
ODOO_PORT=""
CHAT_PORT=""
DB_NAME=""
SKIP_INIT=""

usage() {
    cat <<'EOF'
Usage:
  bash run.sh --destination <directory> --port <odoo-port> --chat <chat-port> [options]

Options:
  --db <name>     Odoo database to create (default: odoo<odoo-port>)
  --skip-init     Do not create the Odoo database on first start
  -h, --help      Show this help

Examples:
  sudo bash run.sh --destination odoo-live --port 10020 --chat 20020
  sudo bash run.sh --destination odoo-test --port 11020 --chat 21020 --db odoo_test
EOF
}

while (($#)); do
    case "$1" in
        --destination)
            (($# >= 2)) || { usage >&2; exit 2; }
            DESTINATION="$2"
            shift 2
            ;;
        --port)
            (($# >= 2)) || { usage >&2; exit 2; }
            ODOO_PORT="$2"
            shift 2
            ;;
        --chat)
            (($# >= 2)) || { usage >&2; exit 2; }
            CHAT_PORT="$2"
            shift 2
            ;;
        --db)
            (($# >= 2)) || { usage >&2; exit 2; }
            DB_NAME="$2"
            shift 2
            ;;
        --skip-init)
            SKIP_INIT="1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$DESTINATION" || -z "$ODOO_PORT" || -z "$CHAT_PORT" ]]; then
    usage >&2
    exit 2
fi

validate_port() {
    local name="$1"
    local value="$2"
    if [[ ! "$value" =~ ^[0-9]+$ ]] || ((10#$value < 1 || 10#$value > 65535)); then
        printf 'Error: %s must be a port number between 1 and 65535.\n' "$name" >&2
        exit 2
    fi
}

validate_port "--port" "$ODOO_PORT"
validate_port "--chat" "$CHAT_PORT"

if [[ "$DESTINATION" == "/" || "$DESTINATION" == "." || "$DESTINATION" == ".." ]]; then
    printf 'Error: destination must be a new project directory, not %s.\n' "$DESTINATION" >&2
    exit 2
fi

if ! command -v git >/dev/null 2>&1; then
    printf 'Error: Git is required. Install Git and try again.\n' >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: Docker is required. Install Docker Engine and try again.\n' >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    printf 'Error: Docker Compose v2 is required (docker compose).\n' >&2
    exit 1
fi

if [[ -e "$DESTINATION" ]]; then
    printf 'Error: destination already exists: %s\n' "$DESTINATION" >&2
    exit 1
fi

INSTANCE_NAME="${DESTINATION##*/}"
INSTANCE_SLUG="$(printf '%s' "$INSTANCE_NAME" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//')"

if [[ -z "$INSTANCE_SLUG" ]]; then
    printf 'Error: destination must include letters or numbers.\n' >&2
    exit 2
fi

if [[ -z "$DB_NAME" ]]; then
    DB_NAME="odoo${ODOO_PORT}"
fi

printf 'Cloning Odoo Docker deployment into %s...\n' "$DESTINATION"
git clone --depth 1 "$REPOSITORY_URL" "$DESTINATION"

PROJECT_DIR="$DESTINATION"
cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
chmod 600 "$PROJECT_DIR/.env"

set_env() {
    local key="$1"
    local value="$2"
    local env_file="$PROJECT_DIR/.env"
    if grep -q "^${key}=" "$env_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$env_file"
    fi
}

set_env "ODOO_HTTP_PORT" "$ODOO_PORT"
set_env "ODOO_CHAT_PORT" "$CHAT_PORT"
set_env "ODOO_DB_NAME" "$DB_NAME"
set_env "ODOO_AUTO_INIT" "1"
if [[ -n "$SKIP_INIT" ]]; then
    set_env "ODOO_AUTO_INIT" "0"
fi
set_env "ODOO_NETWORK" "odoo20_${INSTANCE_SLUG}_internal"
set_env "ODOO_CONTAINER_NAME" "odoo20-${INSTANCE_SLUG}"
set_env "ODOO_DB_CONTAINER_NAME" "odoo20-${INSTANCE_SLUG}-db"

# Leave the whole project writable by the invoking user, otherwise .env, etc/
# and compose files stay root-owned and later edits need sudo.
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    chown -R "$SUDO_USER" "$PROJECT_DIR"
fi

compose() {
    docker compose --project-directory "$PROJECT_DIR" \
        -f "$PROJECT_DIR/docker-compose.yml" "$@"
}

printf 'Starting containers...\n'
compose up -d

ODOO_CONTAINER="$(grep -E '^ODOO_CONTAINER_NAME=' "$PROJECT_DIR/.env" | cut -d= -f2-)"
ODOO_CONTAINER="${ODOO_CONTAINER:-odoo20}"

printf 'Waiting for PostgreSQL to become healthy...\n'
db_status="missing"
for _ in $(seq 1 60); do
    db_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        "${ODOO_CONTAINER}-db" 2>/dev/null || echo missing)"
    if [[ "$db_status" == "healthy" ]]; then
        break
    fi
    sleep 2
done

if [[ "$db_status" != "healthy" ]]; then
    printf 'Error: PostgreSQL did not become healthy. Check: compose -f %s/docker-compose.yml logs db\n' "$PROJECT_DIR" >&2
    exit 1
fi

printf 'Waiting for Odoo to answer on /odoo (the first start creates the database)...\n'
odoo_ready=""
for _ in $(seq 1 150); do
    if curl -fsS -o /dev/null "http://localhost:${ODOO_PORT}/odoo" 2>/dev/null; then
        odoo_ready="1"
        break
    fi
    sleep 2
done

printf '\n'
if [[ -z "$odoo_ready" ]]; then
    printf 'Error: Odoo did not become ready.\n' >&2
    printf 'Logs:      docker compose -f %s/docker-compose.yml logs --tail=80 odoo20\n' "$PROJECT_DIR" >&2
    exit 1
fi

printf 'Odoo deployment is ready.\n'
printf 'Project:   %s\n' "$PROJECT_DIR"
printf 'Odoo:      http://localhost:%s/odoo\n' "$ODOO_PORT"
printf 'Database:  %s\n' "$DB_NAME"
printf 'Live port: %s (WebSocket only, not a web UI)\n' "$CHAT_PORT"
printf 'Status:    docker compose -f %s/docker-compose.yml ps\n' "$PROJECT_DIR"
printf 'Logs:      docker compose -f %s/docker-compose.yml logs -f\n' "$PROJECT_DIR"