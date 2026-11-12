<div align="center">

# Odoo 20 · Docker Deployment

**Odoo 20 + PostgreSQL 18 · Docker Compose · Optional Traefik**

[![Odoo 20](https://img.shields.io/badge/Odoo-20-714B67?logo=odoo&logoColor=white)](https://www.odoo.com/)
[![PostgreSQL 18](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)

[Quick Start](#4-quick-start) · [Multiple Instances](#7-multiple-instances) · [Operations](#9-container-management) · [Troubleshooting](#12-troubleshooting)

</div>

---

## Contents

1. [Overview](#1-overview)
2. [Requirements](#2-requirements)
3. [Architecture](#3-architecture)
4. [Quick Start](#4-quick-start)
5. [Access and Initial Credentials](#5-access-and-initial-credentials)
6. [Configuration](#6-configuration)
7. [Multiple Instances](#7-multiple-instances)
8. [Traefik / HTTPS](#8-traefik--https)
9. [Container Management](#9-container-management)
10. [Backups](#10-backups)
11. [Linux Host Tuning and Permissions](#11-linux-host-tuning-and-permissions)
12. [Troubleshooting](#12-troubleshooting)
13. [Project Layout and Security](#13-project-layout-and-security)
14. [References](#14-references)

---

## 1. Overview

Run Odoo 20 and PostgreSQL 18 with Docker Compose. Use the standard setup for
one instance, or `run.sh` to install separate instances on different ports.
An optional Compose file connects Odoo to an existing Traefik network.

| Component | Image | Host access | Persistent storage |
|---|---|---|---|
| Odoo | `odoo:20` | `10020` HTTP · `20020` live service | `odoo_data` volume |
| PostgreSQL | `postgres:18` | Not published | `./postgresql` |

## 2. Requirements

- Docker Engine.
- Docker Compose v2 (`docker compose`).
- Ubuntu/Linux server; Windows users can use WSL 2 with Docker integration.

## 3. Architecture

```mermaid
flowchart LR
    U([User]) -->|HTTP :10020| O[Odoo 20]
    U -->|Live service :20020| O
    O -->|Private Docker network| D[(PostgreSQL 18)]
    O --> F[(Odoo data volume)]
    D --> P[(./postgresql)]
```

PostgreSQL is not published to the host. In Traefik mode, requests reach
Odoo through the configured reverse proxy instead of host-published ports.

## 4. Quick Start

### 1 · Get the project

```bash
git clone https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment.git
cd InstallingOdoo20-Docker-Deployment
```

### 2 · Set environment and file permissions

```bash
cp .env.example .env
chmod 600 .env
sudo mkdir -p postgresql
sudo chmod 700 postgresql
chmod +x entrypoint.sh
```

> Create `postgresql/` with `sudo`. The PostgreSQL container runs as `root` and
> rewrites the directory ownership; a directory owned by your login user can
> make the container fail with `Permission denied`.

### 3 · Start

```bash
docker compose pull
docker compose up -d
docker compose ps
```

## 5. Access and Initial Credentials

| Service | Address |
|---|---|
| Odoo web interface | **[http://localhost:10020](http://localhost:10020)** |
| Live communication port | **[http://localhost:20020](http://localhost:20020)** |

> Port `20020` is the live communication/WebSocket service, not a second Odoo
> web interface. Open Odoo itself on port `10020`.

| Credential | Initial value | Used for |
|---|---|---|
| Odoo master password | `Admin@20` | Odoo database-management operations |
| PostgreSQL user | `odoo20` | Odoo-to-PostgreSQL connection |
| PostgreSQL password | `odoo@20` | Odoo-to-PostgreSQL connection |
| Initial PostgreSQL database | `postgre` | PostgreSQL image initialization |

These are example credentials, **not production secrets**. Change them in
`.env` before exposing the service publicly. The Odoo master password is
different from the administrator login you create for an Odoo application
database.

## 6. Configuration

Edit `.env`; do not commit it. The file is already excluded by `.gitignore`.

| Variable | Default | Purpose |
|---|---|---|
| `ODOO_IMAGE` | `odoo:20` | Odoo image |
| `PG_IMAGE` | `postgres:18` | PostgreSQL image |
| `POSTGRES_USER` | `odoo20` | PostgreSQL role |
| `POSTGRES_PASSWORD` | `odoo@20` | PostgreSQL role password |
| `POSTGRES_DB` | `postgre` | Initial database created by the image |
| `ODOO_ADMIN_PASSWORD` | `Admin@20` | Odoo master password |
| `ODOO_HTTP_PORT` | `10020` | Host port → Odoo `8069` |
| `ODOO_CHAT_PORT` | `20020` | Host port → Odoo `8072` |
| `ODOO_NETWORK` | `odoo20_internal` | Private Docker network |
| `ODOO_DOMAIN` | Required for Traefik | Public hostname |
| `DOCKER_PROXY_NETWORK` | `proxy` | Existing Traefik network |
| `CERTSRESOLVER` | `letsencrypt` | Traefik certificate resolver |

Example: use host ports `11020` and `21020`:

```dotenv
ODOO_HTTP_PORT=11020
ODOO_CHAT_PORT=21020
```

Apply changes:

```bash
docker compose up -d
```

> **Existing database:** PostgreSQL initialization variables apply only when
> the data directory is first initialized. Editing credentials in `.env`
> does not change roles, passwords, or databases in existing data.

Custom addons go in [`addons/`](addons/). Odoo settings are in
[`etc/odoo.conf`](etc/odoo.conf); runtime secrets are rendered from the
container environment and should not be added to that tracked file.

## 7. Multiple Instances

`run.sh` clones this repository into a **new directory**, writes that
instance's `.env`, sets its ports and unique container/network names, and
starts Docker Compose. It will not overwrite an existing destination.

```mermaid
flowchart TD
    A([Start]) --> B{Destination exists?}
    B -->|Yes| X[Stop · choose another name]
    B -->|No| C{Git + Docker Compose available?}
    C -->|No| Y[Install requirements]
    C -->|Yes| D[Clone this repository]
    D --> E[Create instance .env + data directory]
    E --> F[Set ports and unique names]
    F --> G[Start Odoo + PostgreSQL]
    G --> H([Open the instance URL])
```

**Requirements:** Git, Docker Engine, Docker Compose v2, and permission to run
Docker. Run from the repository root:

```bash
# Instance 1
sudo bash run.sh --destination odoo-live --port 10020 --chat 20020

# Instance 2
sudo bash run.sh --destination odoo-test --port 11020 --chat 21020
```

| Instance | Destination | Odoo URL | Live service |
|---|---|---|---|
| `odoo-live` | `odoo-live/` | [http://localhost:10020](http://localhost:10020) | `20020` |
| `odoo-test` | `odoo-test/` | [http://localhost:11020](http://localhost:11020) | `21020` |

The same commands can download the installer from this repository's `main`
branch. Review scripts before piping a remote download to a shell:

```bash
curl -fsSL https://raw.githubusercontent.com/abdalazeim/InstallingOdoo20-Docker-Deployment/main/run.sh \
  | bash -s -- --destination odoo-live --port 10020 --chat 20020

curl -fsSL https://raw.githubusercontent.com/abdalazeim/InstallingOdoo20-Docker-Deployment/main/run.sh \
  | bash -s -- --destination odoo-test --port 11020 --chat 21020
```

Each instance has its own PostgreSQL directory and Odoo data volume. Manage
it from its destination directory:

```bash
cd odoo-live
docker compose ps
docker compose logs -f
```

## 8. Traefik / HTTPS

Use [`docker-compose.traefik.yml`](docker-compose.traefik.yml) only when
Traefik is already running and its external Docker network exists.

```dotenv
ODOO_DOMAIN=odoo.example.com
DOCKER_PROXY_NETWORK=proxy
CERTSRESOLVER=letsencrypt
```

```bash
# Only if the shared network has not already been created
docker network create proxy

docker compose -f docker-compose.traefik.yml up -d
```

Configure DNS and Traefik's entrypoint/certificate resolver for your server,
then open `https://odoo.example.com`. Do not run standard and Traefik modes
simultaneously for the same instance.

## 9. Container Management

Run from the deployment directory:

| Action | Command |
|---|---|
| Start | `docker compose up -d` |
| Status | `docker compose ps` |
| Follow all logs | `docker compose logs -f` |
| Odoo logs | `docker compose logs -f odoo20` |
| PostgreSQL logs | `docker compose logs -f db` |
| Restart | `docker compose restart` |
| Stop; keep containers and data | `docker compose stop` |
| Stop; keep data | `docker compose down` |

Both services use `restart: always`: Docker restarts them after a failure or
host restart. `docker compose down` preserves data. Avoid `docker compose down
-v` unless you intend to delete the named Odoo data volume. Never delete
`postgresql/` unless you intend to remove the PostgreSQL data.

## 10. Backups

The PostgreSQL bind mount is `postgresql/`; Odoo attachments and files are
stored in the `odoo_data` named volume. Back up both:

Run these commands from the default single-instance project. For an instance
created by `run.sh`, replace `odoo20-db` and `odoo20` with the container names
shown by `docker compose ps`.

```bash
mkdir -p backups
docker exec odoo20-db pg_dumpall -U odoo20 > backups/postgresql-all.sql
docker exec odoo20 tar -C /var/lib/odoo -czf /tmp/odoo-data.tar.gz .
docker cp odoo20:/tmp/odoo-data.tar.gz backups/odoo-data.tar.gz
docker exec odoo20 rm -f /tmp/odoo-data.tar.gz
```

Protect backup files: SQL dumps may contain credentials and business data.
Keep an additional copy outside the server and test restoration regularly.

## 11. Linux Host Tuning and Permissions

### File permissions

Do **not** use `chmod -R 777`: it grants every local user read/write/execute
access. Use restrictive permissions:

```bash
chmod 600 .env
sudo chmod 700 postgresql
chmod +x entrypoint.sh
```

If a bind mount reports a permission error, inspect the specific path and
container logs before changing ownership:

```bash
docker compose logs --tail=100
ls -ld addons etc postgresql
```

Change permissions only on the affected directory. Do not make database data
or password files world-writable.

### Optional · Increase Linux inotify watches

This host setting may help when running many instances and the system reports
that its file-watch limit is exhausted. It is not normally required:

```bash
if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
  grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf
else
  echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
fi

sudo sysctl -p
```

## 12. Troubleshooting

| Symptom | Check |
|---|---|
| Port already in use | Change `ODOO_HTTP_PORT` / `ODOO_CHAT_PORT` in `.env`; run `docker compose up -d` |
| Odoo cannot connect to PostgreSQL | `docker compose logs db odoo20` |
| PostgreSQL readiness | `docker compose exec db pg_isready -U odoo20 -d postgre` |
| Odoo configuration error | `docker compose logs --tail=100 odoo20` |
| Credentials changed but old ones still work | Existing PostgreSQL data is not re-initialized from `.env` |
| `PostgreSQL data in /var/lib/postgresql/data (unused mount/volume)` or `mkdir: cannot create directory '/var/lib/postgresql': Permission denied` | PostgreSQL 18 images store data in a major-version directory. The mount must be `./postgresql:/var/lib/postgresql` with `PGDATA=/var/lib/postgresql/18/docker`, and the `db` service must run as `root` so the entrypoint can fix ownership |
| Traefik route unavailable | Check DNS, external network, resolver, entrypoint, and `ODOO_DOMAIN` |

```mermaid
flowchart LR
    A([Odoo unavailable]) --> B{Containers running?}
    B -->|No| C[Check docker compose ps]
    B -->|Yes| D{Database ready?}
    D -->|No| E[Check PostgreSQL logs and credentials]
    D -->|Yes| F{Correct host port?}
    F -->|No| G[Check .env port mapping]
    F -->|Yes| H[Check Odoo logs and configuration]
```

## 13. Project Layout and Security

### Project layout

```text
InstallingOdoo20-Docker-Deployment/
├── addons/                       # Custom Odoo addons
├── etc/
│   ├── odoo.conf                 # Odoo configuration template
│   └── requirements.txt          # Optional Python dependencies
├── postgresql/                   # PostgreSQL data (persistent; not committed)
├── .env.example                  # Environment template
├── docker-compose.yml            # Direct host-port deployment
├── docker-compose.traefik.yml    # Optional Traefik deployment
├── entrypoint.sh                 # Runtime config + PostgreSQL wait
├── run.sh                        # Optional multi-instance installer
└── README.md
```

### Security checklist

- [ ] Replace the example Odoo and PostgreSQL passwords.
- [ ] Keep `.env`, database data, and backups out of Git.
- [ ] Do not publish PostgreSQL's port.
- [ ] Use HTTPS through a trusted reverse proxy for public access.
- [ ] Keep Docker Engine and container images updated.

## 14. References

- [Odoo 20 documentation](https://www.odoo.com/documentation/20.0/)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [GitHub repository](https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment)
- [Report an issue](https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment/issues)
