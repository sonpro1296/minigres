# Stage 0: Foundations (weeks 1-6, about 60 hours)

Goal: a reproducible Docker lab, Go comfort for network code, and hands-on feel for Postgres
replication, failure and isolation. Output: a lab repo, a failover runbook, write-up 0.

---
## Week 1: Docker lab
**Tasks**
- [ ] Provision a Linux host (about 4 vCPU / 8 GB is a good start). SSH keys only; disable
      password login; install Docker and Compose.
- [ ] `lab/docker-compose.yml`: `pg-primary`, `pg-replica1`, `pg-replica2` (one Postgres major
      version of your choice), named volumes, healthchecks.
- [ ] Primary config: `wal_level=logical` (needed later), `max_wal_senders` and
      `max_replication_slots` of at least 10, `hot_standby=on`, a replication role, and
      `pg_hba.conf` entries for the replication user from the Compose network only.
- [ ] Bootstrap replicas with `pg_basebackup -R -X stream` (never `initdb`).
- [ ] Publish no database ports to the internet; bind to `127.0.0.1` and use an SSH tunnel.
- [ ] `lab/check.sh`: writes on the primary, reads the row on both replicas, exits non-zero on any failure.

**Read:** the manual chapters on streaming replication and `pg_basebackup`.

**Done when:** `SELECT client_addr, state, sync_state FROM pg_stat_replication;` shows two
`streaming` rows; `lab/check.sh` passes; a port scan from outside shows only SSH.

**Pitfalls**
- Ports published by Docker can bypass host firewall rules such as ufw. Bind to `127.0.0.1` or do not publish.
- Recreating a container with a stale volume resurrects old data. Know how to reset the lab (`make lab-reset`).

---
## Week 2: Go for network code
**Tasks**
- [ ] Work through "A Tour of Go" and the concurrency parts of "Effective Go".
- [ ] `lab/echo`: a TCP echo server with a goroutine per connection, read/write deadlines,
      context-based graceful shutdown (stop accepting, drain with a timeout), and a connection counter.
- [ ] A load client that opens N concurrent connections.
- [ ] Table-driven tests; add `goleak` to catch leaked goroutines.

**Done when:** `go test -race -count=20 ./...` passes; 1,000 concurrent clients echo within a
timeout; the shutdown test shows no leaked goroutines.

**Pitfalls:** forgetting to close connections on error paths; blocking on unbuffered channels;
shared state without a mutex; a context that cannot interrupt a blocking `Read` (use deadlines or close the connection).

---
## Week 3: Postgres wire protocol
**Tasks**
- [ ] Read "Frontend/Backend Protocol": startup, authentication, simple query, an overview of extended query.
- [ ] `lab/pgclient`: no driver. Send the startup message (protocol 3.0 with user and database), handle
      authentication-ok (use `trust` on the lab network for this exercise), send a simple `Query`,
      decode `RowDescription`, `DataRow`, `CommandComplete`, `ReadyForQuery`, `ErrorResponse`.
- [ ] Capture traffic with `tcpdump -w` and open it in Wireshark; match each packet to a decoded message.

**Done when:** your client runs `SELECT 1` and `SELECT generate_series(1,1000)`; an invalid query
prints its SQLSTATE; `docs/notes/wire-protocol.md` has the annotated message sequence.

**Pitfalls:** the startup message has no type byte; lengths include themselves but not the type byte;
integers are big-endian; remember the `ReadyForQuery` status byte (`I`, `T`, `E`): you need it in week 8.

---
## Week 4: Failover by hand
**Tasks**
- [ ] Run a write load that logs each id only after its commit returns (a small Go writer; fsync the log).
- [ ] `kill -9` the primary container mid-load. Pick the most advanced replica
      (`pg_last_wal_receive_lsn()` / `pg_last_wal_replay_lsn()`), promote it with `pg_promote()`,
      repoint the other replica, and rejoin the old primary with `pg_rewind`
      (needs `wal_log_hints=on` or data checksums; set it in the lab config).
- [ ] Repeat under (a) asynchronous replication and (b) `synchronous_commit=on` with
      `synchronous_standby_names='ANY 1 (r1, r2)'`. Count acknowledged ids missing afterwards.
- [ ] Time every step.

**Done when:** `docs/runbook-failover.md` has exact commands, timings, and a table
"setting → acknowledged writes lost"; you can follow the runbook from scratch the next day.

**Pitfalls:** the old primary can hold WAL the new primary never saw (needs rewind or rebuild);
set `restart: "no"` on database containers during experiments or the old primary comes back and writes.

---
## Week 5: Isolation and logical replication
**Tasks**
- [ ] With two `psql` sessions, reproduce: a non-repeatable read at READ COMMITTED; write skew at
      REPEATABLE READ (e.g. two on-call doctors each going off duty); the same scenario at SERIALIZABLE
      failing with SQLSTATE 40001 and needing a retry. Save each as a script in `lab/sql/`.
- [ ] Observe lock waits with `pg_locks` and `pg_stat_activity`; compare `EXPLAIN (ANALYZE, BUFFERS)` for an indexed lookup and a sequential scan.
- [ ] Logical replication: `CREATE PUBLICATION` on one instance and `CREATE SUBSCRIPTION` on another;
      watch raw changes with `pg_recvlogical` and `test_decoding`.

**Done when:** `docs/notes/isolation.md` lists three reproducible anomalies and which level prevents each;
`lab/logical-demo.sh` shows an insert, update and delete arriving on the second instance.

**Pitfalls:** in Postgres, REPEATABLE READ is snapshot isolation (no phantoms, but write skew is possible);
logical replication does not copy DDL; tables need a primary key (replica identity).

---
## Week 6: Slack and write-up 0
**Tasks**
- [ ] Finish whatever slipped from weeks 1-5.
- [ ] Add `make lab-up`, `make lab-check`, `make lab-reset`; test them from a fresh clone on a fresh host.
- [ ] README with a lab architecture diagram.
- [ ] Publish write-up 0 ("failing over Postgres by hand").
- [ ] Retrospective in `PROGRESS.md`: hours planned versus spent; adjust later stages if needed.

**Done when:** `git clone && make lab-up && make lab-check` is green on a fresh host; the post is public.
