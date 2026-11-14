#!/bin/sh
# ==============================================================================
# Odoo 20 Private Repository - Generic Entrypoint Wrapper
#
# يستمد الأفكار من Odoo-MultiVersion-Deployment مع تحسينات للأمان والتوافق.
# ==============================================================================
set -eu
umask 077

: "${HOST:=db}"
: "${PORT:=5432}"
: "${USER:=odoo}"
: "${PASSWORD:=}"
: "${ODOO_ADMIN_PASSWORD:=odoo20}"
: "${ODOO_DB_NAME:=}"
export ODOO_DB_NAME

# تثبيت متطلبات بايثون الإضافية إذا أضافها المشغل.
if [ -f /etc/odoo/requirements.txt ]; then
    pip3 install --no-cache-dir -r /etc/odoo/requirements.txt
fi

# Render the environment-backed settings without modifying the mounted config.
python3 - <<'PY'
import os
from pathlib import Path

source = Path("/etc/odoo/odoo.conf").read_text(encoding="utf-8")
values = {
    "${ODOO_ADMIN_PASSWORD}": os.environ["ODOO_ADMIN_PASSWORD"],
    "${ODOO_DB_USER}": os.environ["USER"],
    "${ODOO_DB_PASSWORD}": os.environ["PASSWORD"],
    "${ODOO_DB_NAME}": os.environ["ODOO_DB_NAME"].strip(),
}
for placeholder, value in values.items():
    if "\n" in value or "\r" in value:
        raise SystemExit(f"Invalid newline in value for {placeholder}")
    source = source.replace(placeholder, value)

if any(placeholder in source for placeholder in values):
    raise SystemExit("Unresolved environment variable in /etc/odoo/odoo.conf")

# An empty ODOO_DB_NAME means "use the database selector", so drop the option
# instead of writing an empty value.
if not values["${ODOO_DB_NAME}"]:
    source = "".join(
        line for line in source.splitlines(keepends=True)
        if not line.lstrip().startswith("db_name")
    )

config = Path("/tmp/odoo.conf")
config.write_text(source, encoding="utf-8")
config.chmod(0o600)
PY

# الانتظار حتى تقبل PostgreSQL الاتصالات قبل تشغيل أودو.
if [ -n "${PASSWORD}" ]; then
    python3 - <<'PY'
import os
import socket
import time

host = os.environ.get("HOST", "db")
port = int(os.environ.get("PORT", "5432"))
for _ in range(60):
    try:
        with socket.create_connection((host, port), timeout=2):
            break
    except OSError:
        time.sleep(1)
else:
    raise SystemExit(f"Timed out waiting for PostgreSQL at {host}:{port}")
PY
fi

exec odoo "$@"
