#!/usr/bin/env bash
# Replica entrypoint: clone the primary with pg_basebackup on first start,
# then hand over to the image's normal entrypoint. Never runs initdb.
set -euo pipefail

: "${PGDATA:?PGDATA must be set}"
: "${PRIMARY_HOST:?PRIMARY_HOST must be set}"
: "${REPLICATION_PASSWORD:?REPLICATION_PASSWORD must be set}"

if [ -s "$PGDATA/PG_VERSION" ]; then
  echo "replica: data directory exists, starting as-is"
else
  echo "replica: empty data directory, cloning from $PRIMARY_HOST"
  parent="$(dirname "$PGDATA")"
  tmp="$PGDATA.tmp"
  mkdir -p "$parent"
  chown postgres:postgres "$parent"
  rm -rf "$tmp" "$PGDATA"   # leftovers from an interrupted clone

  # Clone into a temp dir and rename at the end, so a clone that dies halfway
  # never looks like a valid data directory on the next start.
  # -R writes standby.signal + primary_conninfo; -X stream copies the WAL
  # generated during the backup over a second connection.
  gosu postgres env PGPASSWORD="$REPLICATION_PASSWORD" \
    pg_basebackup -h "$PRIMARY_HOST" -p 5432 -U replicator \
      -D "$tmp" -R -X stream -P --checkpoint=fast

  chmod 700 "$tmp"
  mv "$tmp" "$PGDATA"
  echo "replica: clone complete"
fi

exec docker-entrypoint.sh "$@"
