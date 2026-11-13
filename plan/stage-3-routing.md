# Stage 3: Routing (weeks 25-36, about 120 hours)

Goal: a rule-based sharded query router over a small, documented SQL subset, proven correct by
differential testing against a single Postgres. Unsupported shapes fail loudly.

Constraint: **do not write a SQL parser.** Use `pganalyze/pg_query_go` (needs cgo and a C compiler; the first build is slow).
Keep a thin internal representation between parser output and planner so the parser can be swapped.

---
## Week 25: Sharding scheme design
**Tasks**
- [ ] Read the Vitess docs on vindexes and keyspace IDs, the sharding section of the Multigres contributor post, and the partitioning chapter of DDIA.
- [ ] `docs/adr/0002-sharding.md`: a 64-bit keyspace ID from a stable hash of the shard key; shards are ranges of it
      (Vitess-style names such as `-80` and `80-`) so a split is a range split.
- [ ] A YAML config: tables, shard key column, hash vindex, reference tables, unsharded tables. A Go validator with tests.
- [ ] Rule: the primary key of a sharded table includes the shard key (uniqueness stays shard-local; stream events can be routed).
- [ ] Sample schemas: `customers(customer_id PK)`, `orders(customer_id, order_id, ... PK (customer_id, order_id))`, `order_items`.
- [ ] `docs/sql-subset.md` v0: accepted and rejected shapes.

**Done when:** the ADR exists; invalid configs are rejected with tests; the subset document lists at least 15 shapes.

**Pitfalls:** globally unique IDs and sequences; hot keys; secondary indexes that force scatter queries; deciding too much up front.

---
## Week 26: Reading queries
**Tasks**
- [ ] Add `pg_query_go`. In `router/ir`, define `QueryShape` (kind, tables, equality and IN predicates on the shard key, aggregates, ORDER BY, LIMIT, joins, unsupported reason).
- [ ] A tree walker for SELECT, INSERT ... VALUES, UPDATE, DELETE. Extract key predicates from top-level AND conditions.
- [ ] Reject with stable error codes: subqueries, CTEs, window functions, UNION, multiple statements, and anything not in the subset.
- [ ] At least 30 table-driven cases with golden output.

**Done when:** `go test ./router/...` passes with 30+ cases; unsupported queries return stable, documented errors.

**Pitfalls:** an `OR` can hide the key; placeholders (`$1`) carry the key value only at `Bind` time; casts such as `'5'::int`; identifier quoting and schema-qualified names.

---
## Week 27: Key to shard
**Tasks**
- [ ] `vindex/hash`: a stable 64-bit hash (for example xxhash or FNV-1a, never Go's map hash) for integer and string keys. Golden tests that fail if the hash ever changes.
- [ ] Shard map from keyspace ranges; `ShardFor(key)`.
- [ ] A split function (`-80` into `-40` and `40-80`) for week 43.
- [ ] Property tests: deterministic; ranges cover the whole space with no gaps or overlaps; 1M keys spread within ±5% across 4 shards.

**Done when:** all tests pass; a distribution report is committed.

**Pitfalls:** the integer `5` and the string `"5"` must be a deliberate choice, not an accident; changing the hash later invalidates stored data.

---
## Week 28: Single-shard routing
**Tasks**
- [ ] Lab: two shards (one Postgres each for now) with the same schema.
- [ ] Gateway Router implementation using the shard map. For the extended protocol, decide the route at `Bind`, when parameters are known.
- [ ] INSERT with a key routes to its shard; INSERT with rows spanning shards is split per shard or rejected (choose, document).
- [ ] SELECT, UPDATE, DELETE with key equality hit one shard.
- [ ] A gateway-level `SHOW PLAN FOR <sql>` command that prints the chosen route.

**Done when:** an integration test inserts 1,000 customers; each row exists only on its expected shard (checked directly); key lookups touch exactly one shard (per-shard query counters).

**Pitfalls:** prepared statements cached per backend; connection state across shards; transactions come in week 34.

---
## Week 29: Scatter-gather
**Tasks**
- [ ] Fan out to all shards concurrently with per-shard timeouts and cancellation on first error.
- [ ] Merge: concatenate; for ORDER BY, a k-way merge (heap) over per-shard sorted streams. Add hidden sort columns to the rewritten query when needed.
- [ ] `LIMIT n OFFSET m`: push `LIMIT n+m` to each shard, apply offset and limit in the router.
- [ ] Type-aware comparison: ints, text, numeric, timestamps, NULL ordering.

**Done when:** 20 hand-written queries return the same results as a plain Postgres at 1, 2 and 4 shards; memory stays bounded on a large result.

**Pitfalls:** text collation differences between router comparison and database ordering (use a fixed collation and document it); ties need a stable order; `LIMIT` without `ORDER BY` is nondeterministic (do not assert on it).

---
## Week 30: Aggregates
**Tasks**
- [ ] Rewrite and combine: COUNT → sum of counts; SUM → sum; MIN/MAX; AVG → SUM and COUNT then divide.
- [ ] GROUP BY: group per shard on the same keys, then merge by key. HAVING and ORDER BY on aggregates are applied after the merge.
- [ ] Reject DISTINCT aggregates, ARRAY_AGG, STRING_AGG, percentiles, with clear errors.
- [ ] Handle empty shards (SUM is NULL, COUNT is 0) and result types (SUM of integers returns bigint; AVG of integers returns numeric).

**Done when:** tests for each aggregate over uneven shards, including an empty shard, match plain Postgres.

**Pitfalls:** AVG's division and type; overflow; GROUP BY ordinals (`GROUP BY 1`).

---
## Week 31: Differential testing (never cut)
**Tasks**
- [ ] A seeded generator (custom, or `pgregory.net/rapid`) for data (with skew and NULLs) and queries from the supported grammar: key equality and ranges, other filters, ORDER BY, LIMIT, aggregates, GROUP BY.
- [ ] Oracle: one plain Postgres loaded with identical data. Compare result sets (ordered only when ORDER BY gives a total order); normalize floats and types.
- [ ] Run at 1, 2 and 4 shards; shrink failures; log seeds; every failure becomes a regression test.
- [ ] Run it in CI or as a nightly `make` target.

**Done when:** 10,000 generated queries per shard count pass; real bugs found are recorded in `docs/bugs.md`; the harness catches a deliberately seeded router bug.

**Pitfalls:** a generator that mostly returns empty results; unordered comparison done incorrectly; oracle differences from collation or float formatting.

---
## Week 32: Co-located joins
**Tasks**
- [ ] Detect equality joins on the shard keys of tables with the same scheme (`customers.customer_id = orders.customer_id`) and push the whole join down (single shard if the key is pinned, otherwise scatter and merge).
- [ ] Reject all other joins with SQLSTATE `0A000` (feature not supported) and a helpful message.
- [ ] `SHOW PLAN` shows the pushdown. Extend the differential generator with joins.

**Done when:** join tests pass at 1, 2 and 4 shards; non-co-located joins fail clearly and appear in the supported-shapes document.

**Pitfalls:** LEFT JOIN semantics; extra conditions beside the key; a join where each side is filtered to a different key is cross-shard and must be rejected.

---
## Week 33: Reference tables (cut candidate)
**Tasks**
- [ ] Reference tables replicated to every shard; writes fan out to all shards (not atomic; document it); reads use any one shard.
- [ ] Joins between sharded and reference tables are pushed down.
- [ ] A consistency checker that compares reference tables across shards, and a repair command.

**Done when:** differential tests cover reference joins; behavior when one shard's write fails is documented and detectable.

---
## Week 34: Writes and transactions
**Tasks**
- [ ] `BEGIN` pins the transaction to the shard of its first statement; a statement for another shard fails with `0A000`.
- [ ] Multi-row writes spanning shards, and `UPDATE` that changes the shard key, are rejected.
- [ ] Savepoints and errors inside a transaction pass through (including the `ReadyForQuery` error state).
- [ ] `docs/adr/0003-transactions.md`: what is guaranteed (single-shard isolation as Postgres gives it) and what is not (cross-shard atomicity).

**Done when:** tests cover commit, rollback, error-in-transaction, and cross-shard rejection; the ADR is merged.

**Pitfalls:** a first statement without a key; session variables; read-only scatter queries inside a transaction (decide and document).

---
## Week 35: Integration with failover
**Tasks**
- [ ] Each shard is an HA cluster from stage 2 (two shards × three nodes; tune Postgres memory settings for the host).
- [ ] The routing table (ranges → shard → cluster) lives in etcd with a version; gateways watch it.
- [ ] Test: kill a primary in shard 1 during single-shard and scatter workloads. Shard 0 traffic is unaffected; shard 1 requests are held then resume; scatter queries follow a configured policy (wait or fail).
- [ ] Run the chaos checker across both shards.

**Done when:** a chaos run with two shards shows zero acknowledged-write loss; a chart shows shard 0 latency unaffected by shard 1's failover.

**Pitfalls:** host resource limits; stale topology caches; one slow shard stalling scatter queries (per-shard timeouts).

---
## Week 36: Measurement and write-up 3
**Tasks**
- [ ] Benchmark single-shard and scatter-gather latency at 1, 2, 4 and 8 shards (small containers for the larger counts).
- [ ] Breakdown of router time (parse, plan, execute, merge) with `pprof` or traces.
- [ ] A table of supported query shapes: shape, strategy, test name.
- [ ] Publish write-up 3; tag `v0.3-routing`.

**Done when:** charts and the table are committed; differential tests are green; the post is public.

**Pitfalls:** measuring on a saturated host; extrapolating from Docker to real hardware; skipping warm-up.
