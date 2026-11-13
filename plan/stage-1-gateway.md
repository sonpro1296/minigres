# Stage 1: Thin gateway (weeks 7-9, about 30 hours)

Goal: a Postgres-protocol proxy with simple pooling and two hooks you will need later:
**routing** (stage 3) and **request holding** (failover, stage 2 and resharding, stage 4).
Skip per-user budgets, context-aware pooling and prepared-statement deduplication.

Library note: use `jackc/pgproto3` for message encoding and decoding. This is framing, not SQL parsing.

---
## Week 7: Proxy skeleton
**Tasks**
- [ ] Listener; reply `N` to an `SSLRequest`; read the startup message; reply authentication-ok (lab-only trust).
- [ ] Open a backend connection (`pgproto3.Frontend`, trust auth from the gateway's address in the lab).
- [ ] Two goroutines per client: client → backend and backend → client, forwarding messages in order.
- [ ] Relay `ParameterStatus` and `BackendKeyData`; handle `Terminate`; reject cancel requests for now (document it).
- [ ] An integration test in Go: `pgx` connects to the gateway, runs queries and a transaction.

**Done when:** `psql` runs `\dt`, a `SELECT`, an `INSERT` and a transaction through the gateway;
`pgbench -c 10 -T 30` through the gateway completes with 0 errors.

**Pitfalls:** extended-protocol messages (`Parse`, `Bind`, `Describe`, `Execute`, `Sync`) must be forwarded in order;
startup parameters must reach the client; closing one direction must close the other.

---
## Week 8: Pooling
**Tasks**
- [ ] Transaction-level pooling: take a backend connection on the first message of a transaction;
      release it when `ReadyForQuery` reports idle (`I`).
- [ ] Pin the client to its backend when it uses session state: non-LOCAL `SET`, named prepared statements,
      `LISTEN`, temp tables, advisory locks, cursors `WITH HOLD`. Start conservative: pin on a named `Parse`.
- [ ] Limits: a maximum number of backend connections, a wait queue with a timeout.
- [ ] Metrics: pool wait time, connections in use and idle.

**Done when:** 500 client connections are served by at most 20 backend connections (check
`pg_stat_activity`); `pgbench -c 200 -j 4 -T 60 -S` finishes with 0 failed transactions; a test shows a
client that ran `SET` stays pinned and its setting persists.

**Pitfalls:** releasing a connection in the middle of a Parse→Bind→Execute→Sync sequence breaks the unnamed
statement; a client that vanishes mid-transaction leaks a backend unless you roll back or close; if every
client sits idle in a transaction, a full pool can deadlock (use timeouts).

---
## Week 9: Hooks and benchmark
**Tasks**
- [ ] `type Router interface { Route(ctx, QueryInfo) (Backend, error) }` with a trivial single-backend implementation.
- [ ] A bounded request-hold buffer with a timeout. Test it: make the backend unavailable for 3 seconds;
      new requests wait and then proceed; in-flight requests get an error.
- [ ] Benchmark with `pgbench` (select-only and the default mixed workload) at 1, 50 and 200 clients against:
      direct Postgres, PgBouncer (in Compose), and your gateway. Same host, warm-up first, 5 runs each;
      report median and spread. Capture a `pprof` profile of the gateway.
- [ ] Publish write-up 1.

**Done when:** `bench/README.md` has the method, raw data (CSV) and a chart of p50 and p99 latency;
limits are stated plainly (single host, containers, client and server sharing CPU).

**Pitfalls:** benchmarking client and server on the same saturated CPU; comparing pooling modes unfairly;
confusing connection-setup cost with steady-state cost (test persistent and `-C` separately);
allocating per message (reuse buffers).
