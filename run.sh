#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY_URL="https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment.git"
DESTINATION=""
ODOO_PORT=""
CHAT_PORT=""

usage() {
    cat <<'EOF'
Usage:
  bash run.sh --destination <directory> --port <odoo-port> --chat <chat-port>

Example:
  bash run.sh --destination odoo-live --port 10020 --chat 20020
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

printf 'Cloning Odoo Docker deployment into %s...\n' "$DESTINATION"
git clone --depth 1 "$REPOSITORY_URL" "$DESTINATION"

PROJECT_DIR="$DESTINATION"
cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
mkdir -p "$PROJECT_DIR/postgresql"
chmod 600 "$PROJECT_DIR/.env"
chmod +x "$PROJECT_DIR/entrypoint.sh"

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
set_env "ODOO_NETWORK" "odoo20_${INSTANCE_SLUG}_internal"
set_env "ODOO_CONTAINER_NAME" "odoo20-${INSTANCE_SLUG}"
set_env "ODOO_DB_CONTAINER_NAME" "odoo20-${INSTANCE_SLUG}-db"

if [[ -n "${SUDO_USER:-}" ]]; then
    chown "$SUDO_USER" "$PROJECT_DIR/.env"
fi

docker compose --project-directory "$PROJECT_DIR" -f "$PROJECT_DIR/docker-compose.yml" up -d

printf '\nOdoo deployment is starting.\n'
printf 'Project: %s\n' "$PROJECT_DIR"
printf 'Odoo:    http://localhost:%s\n' "$ODOO_PORT"
printf 'Live communication port: %s\n' "$CHAT_PORT"
printf 'Check status with: docker compose -f %s/docker-compose.yml ps\n' "$PROJECT_DIR"
