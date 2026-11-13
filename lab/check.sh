#!/usr/bin/env bash
# Lab health check: write a unique row on the primary, then require it to show
# up on every replica within a deadline. Exits non-zero on any failure.
#
# Usage: lab/check.sh            (run on the lab host)
#        TIMEOUT=10 lab/check.sh
set -euo pipefail

PRIMARY=pg-primary
REPLICAS=(pg-replica1 pg-replica2)
TIMEOUT="${TIMEOUT:-5}"   # seconds per replica

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok:   $*"; }

# Run one SQL statement in a container; unaligned, tuples only.
# ON_ERROR_STOP makes psql exit non-zero on SQL errors.
sql() {
  local container="$1" query="$2"
  # client_min_messages=warning hides NOTICEs such as "already exists, skipping".
  docker exec -e PGOPTIONS="-c client_min_messages=warning" "$container" psql -U postgres -d postgres -X -v ON_ERROR_STOP=1 -tAc "$query"
}

# 1. Roles: the primary must be a primary, the replicas must be in recovery.
#    Without this, a promoted "replica" would make the read check meaningless.
[ "$(sql "$PRIMARY" 'SELECT pg_is_in_recovery()')" = "f" ] \
  || fail "$PRIMARY is in recovery (not a primary)"
ok "$PRIMARY is primary"

for r in "${REPLICAS[@]}"; do
  [ "$(sql "$r" 'SELECT pg_is_in_recovery()')" = "t" ] \
    || fail "$r is not in recovery (promoted or misconfigured?)"
  ok "$r is in recovery"
done

# 2. The primary sees every replica streaming.
streaming="$(sql "$PRIMARY" "SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming'")"
[ "$streaming" -eq "${#REPLICAS[@]}" ] \
  || fail "expected ${#REPLICAS[@]} streaming replicas on $PRIMARY, found $streaming"
ok "$PRIMARY reports $streaming streaming replicas"

# 3. Write a token that cannot collide with an earlier run.
token="check-$(date +%s%N)-$RANDOM"
sql "$PRIMARY" "CREATE TABLE IF NOT EXISTS lab_check (
                  id         bigserial PRIMARY KEY,
                  token      text NOT NULL UNIQUE,
                  created_at timestamptz NOT NULL DEFAULT now())" >/dev/null
sql "$PRIMARY" "INSERT INTO lab_check (token) VALUES ('$token')" >/dev/null
ok "wrote $token on $PRIMARY"

# 4. Poll each replica until the row arrives or the deadline passes.
#    Async replication: the row is not guaranteed to be there immediately.
#    The table itself may not have replicated yet either, so a query error
#    counts as "not yet", not as a failure, until the deadline.
for r in "${REPLICAS[@]}"; do
  deadline=$(( $(date +%s) + TIMEOUT ))
  start_ns=$(date +%s%N)
  until [ "$(sql "$r" "SELECT count(*) FROM lab_check WHERE token = '$token'" 2>/dev/null || true)" = "1" ]; do
    [ "$(date +%s)" -lt "$deadline" ] \
      || fail "$r did not show $token within ${TIMEOUT}s"
    sleep 0.1
  done
  # Upper bound only: includes docker exec + psql startup on every poll,
  # which dominates. This is NOT replication lag (see pg_stat_replication.replay_lag).
  ok "$r has the row (seen within $(( ($(date +%s%N) - start_ns) / 1000000 )) ms, incl. docker exec overhead)"
done

echo "PASS"
