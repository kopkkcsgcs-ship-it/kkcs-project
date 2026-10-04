#!/bin/sh
# Dipasang di VPS sebagai /usr/local/bin/kkcs-apply-sql (owner root, mode 755).
# Dipanggil CI lewat sudo dengan satu argumen: /tmp/kkcs-migrations.sql
set -e
if [ "$1" != "/tmp/kkcs-migrations.sql" ]; then
  echo "Berkas tidak diizinkan: $1" >&2
  exit 1
fi
docker cp "$1" kkcs-sql:/tmp/m.sql
docker exec kkcs-sql sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d db-kkcs -b -i /tmp/m.sql'
docker exec kkcs-sql rm -f /tmp/m.sql || true
rm -f "$1"
echo "Migrasi selesai."
