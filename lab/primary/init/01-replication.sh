#!/usr/bin/env bash
# Runs once, on the primary's first boot only (empty data directory), against
# the image's temporary init server. Sourced by docker-entrypoint.sh.
set -euo pipefail

# Replication role. :'pw' makes psql quote the password safely.
psql -v ON_ERROR_STOP=1 -v pw="$REPLICATION_PASSWORD" \
  --username "$POSTGRES_USER" --dbname postgres <<'SQL'
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD :'pw';
SQL

# Allow replication connections for that role from the lab network only.
# Note: "all" in the database column does NOT match replication connections,
# so this line is required.
echo "host replication replicator ${LAB_SUBNET} scram-sha-256" >> "$PGDATA/pg_hba.conf"
