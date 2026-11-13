# Stage 4: Streaming (weeks 37-48, about 120 hours)

Goal: snapshot-and-stream copy with crash-safe apply, a verification tool, a live reshard from
2 to 4 shards under write load, and one materialized view that stays correct through it.

Constraint: **no WAL decoder of your own.** Use Postgres logical replication (`pgoutput`) with `jackc/pglogrepl`.

---
## Week 37: Logical decoding
**Tasks**
- [ ] Read the manual on logical replication and the replication protocol's `pgoutput` messages: Relation, Begin, Insert, Update, Delete, Commit, Truncate.
- [ ] `stream/cmd/tail`: connect with `replication=database`; `IdentifySystem`; create a logical slot with `pgoutput`; `StartReplication` with `proto_version` and `publication_names`.
- [ ] Loop: receive CopyData, decode with `pglogrepl`, keep a relation cache, print changes readably, and send standby status updates so the slot advances.
- [ ] Demonstrate an unconsumed slot holding WAL back (`pg_replication_slots`, `pg_wal_lsn_diff`).

**Done when:** `tail` prints inserts, updates and deletes from a publication; `docs/notes/slots.md` explains LSN, slot, `confirmed_flush_lsn` and the disk risk of abandoned slots; cleanup drops slots.

**Pitfalls:** no status updates means the connection times out; abandoned slots fill the disk; column values arrive as text; a Relation message precedes the first change of a table; tables need a primary key or replica identity.

---
## Week 38: Snapshot plus catch-up
**Tasks**
- [ ] Algorithm: create the slot over the replication connection and take its exported snapshot name; keep that connection open and idle. In another connection run
      `BEGIN ISOLATION LEVEL REPEATABLE READ; SET TRANSACTION SNAPSHOT '<name>'`, copy the table (`COPY` out and in), then start streaming from the slot's consistent point.
- [ ] Apply streamed changes with upsert semantics so changes to rows already copied are harmless.
- [ ] Test with a concurrent random writer (inserts, updates, deletes) during the copy.

**Done when:** after catch-up and with writes stopped, source and target checksums match; repeated 5 times with a multi-minute concurrent write load.

**Pitfalls:** the exported snapshot is valid only while the creating connection stays open; copying without the snapshot loses consistency; sequences are not copied.

---
## Week 39: Idempotent apply and checkpoints
**Tasks**
- [ ] Apply each source transaction atomically on the target: `BEGIN`; apply changes (`INSERT ... ON CONFLICT (pk) DO UPDATE`, `UPDATE`, `DELETE` by key); update a `stream_checkpoint` row with the commit LSN in the same transaction; `COMMIT`.
- [ ] Confirm the LSN to the source only after the target commit is durable.
- [ ] On restart, read the checkpoint and resume from it; skip transactions at or below it.
- [ ] Crash test: `kill -9` the consumer at random moments under write load, 100 runs.

**Done when:** after 100 randomized kills, source equals target by checksum every time; applying the same transaction twice is harmless (unit test).

**Pitfalls:** confirming before the target commit loses data; interplay between your checkpoint and the slot's `confirmed_flush_lsn`; transaction order across tables.

---
## Week 40: Real-world limits (cut candidate)
**Tasks**
- [ ] Multi-table streams: apply in source commit order.
- [ ] Unchanged TOAST columns: an update may mark a large column "unchanged"; build the `UPDATE` from changed columns only so you never overwrite with NULL.
- [ ] TRUNCATE: decide to reject or handle. Sequences are not replicated: decide how IDs are allocated after resharding. DDL is not replicated: write the policy.
- [ ] Large transactions: a memory limit and what happens beyond it.
- [ ] `docs/limits.md` listing each limit with a test or a rationale.

**Done when:** tests cover the TOAST case and multi-table ordering; `docs/limits.md` exists.

---
## Week 41: Verification tool
**Tasks**
- [ ] `stream/verify`: split the primary-key space into chunks; for each, compute row count and a checksum (for example `md5` over a deterministic row serialization ordered by key) on both sides; on mismatch, narrow the range recursively to the exact keys.
- [ ] Live data: compare after applying to a known LSN, or re-verify mismatching ranges after lag reaches zero; report lag.
- [ ] Corruption tests: change a row, delete a row, add an extra row.

**Done when:** one injected corruption in 1M rows is localized to its exact key; a clean idle run has no false positives; timings are recorded.

**Pitfalls:** serialization differences between nodes (timezone, `extra_float_digits`); comparing moving data produces false positives; non-deterministic functions in the checksum.

---
## Week 42: Reshard design
**Tasks**
- [ ] `docs/adr/0004-reshard.md`. Split each range in two (2 → 4 shards). State machine: Created → Copying → Streaming → Verified → Hold → Switched → Complete, plus Cancelled and Reversed.
- [ ] Cutover protocol: (1) gateways hold writes for the affected ranges; (2) wait for in-flight transactions; (3) wait for lag zero and verify changed ranges; (4) etcd compare-and-swap of the routing version; (5) gateways acknowledge the new version (or the old routing lease expires); (6) fence the old shards (read-only, terminate sessions) and release the hold.
- [ ] Reverse replication (new → old) is running before the switch so rollback is possible.
- [ ] A failure table: crash at each step and the recovery action. Optional: a small TLA+ model of the cutover with the invariant "no acknowledged write is lost and no write is accepted by two owners".

**Done when:** the ADR has the state diagram and failure table and has been reviewed by someone else.

**Pitfalls:** a gateway still routing with old data is the split-brain risk (fence the old shards); unbounded holds; writes in flight when the hold starts.

---
## Week 43: Copy into new shards
**Tasks**
- [ ] For each of the two source shards run the snapshot-and-stream pipeline, routing every row to one of four targets with the stage-3 hash and shard map. Each target applies only its range; streams into one target must cover disjoint ranges.
- [ ] Per-stream checkpoints; a `reshardctl start --from 2 --to 4` command; per-stream lag metrics.
- [ ] Verify each target range with the week-41 tool.

**Done when:** with the differential workload running, copy and catch-up complete and every range verifies clean; steady-state lag stays under your threshold.

**Pitfalls:** deletes carry only the primary key, which is why the shard key must be in it; foreign keys on targets (copy parents first or defer constraints); different tables streaming out of order.

---
## Week 44: Cutover
**Tasks**
- [ ] Implement the week-42 protocol: gateway hold (watch an etcd flag), drain in-flight transactions with a bound, wait for lag zero, final verification, etcd compare-and-swap of the routing table, gateway acknowledgements (`/gateways/<id>/routing_version`), fence old shards, release.
- [ ] Measure total pause with a constant write load (for example 500 transactions per second); run 10 cutovers.

**Done when:** 10 cutovers under load show zero acknowledged-write loss (chaos checker); p50 and p99 pause reported; clients see only a latency spike (errors only for in-flight requests, counted).

**Pitfalls:** a gateway that never acknowledges (timeout policy); long-running transactions blocking the drain; relying on clocks.

---
## Week 45: Rollback and failure drills
**Tasks**
- [ ] Keep reverse streaming running for a period after the switch; `reshardctl reverse` flips routing back using the same hold protocol.
- [ ] Drills with the chaos nemesis: kill the consumer, `reshardctl`, a gateway, a source or target primary, and partition etcd, at every protocol step.
- [ ] `reshardctl` resumes idempotently from state stored in etcd.

**Done when:** the drill matrix (fault × step → outcome) shows every run ending Complete or Rolled back with a clean verification; manual recovery steps are documented for anything not automatic.

**Pitfalls:** non-idempotent steps that run twice after a restart; leaving old shards writable.

---
## Week 46: Materialized view (cut candidate)
**Tasks**
- [ ] `stream/matview`: from changes on `orders`, maintain `customer_totals(customer_id, order_count, total_amount)`. Use `REPLICA IDENTITY FULL` on `orders` (or recompute by key) to see old values on updates and deletes.
- [ ] Apply deltas in the same transaction as the checkpoint.
- [ ] Shard the view by `customer_id` so it reshards with its data; after cutover, the view's consumers resume from the new shards' positions at the cutover point.
- [ ] A script comparing the view with `SELECT customer_id, count(*), sum(amount) FROM orders GROUP BY 1`.

**Done when:** after a reshard under load the view equals the recomputed aggregate for every customer.

**Pitfalls:** applying a delta twice after a restart (checkpoint must be transactional); updates need the old value; ordering across shards.

---
## Week 47: Reshard under test load
**Tasks**
- [ ] Run the stage-3 differential workload through the gateway while a reshard runs with nemesis faults. Writes also go to the oracle Postgres; reads are compared.
- [ ] Treat ambiguous write outcomes as unknown and reconcile them afterwards.
- [ ] Run at least five seeds; fix and record bugs.

**Done when:** zero divergence in all seeds; bugs and fixes are in `docs/bugs.md`.

---
## Week 48: Polish and write-up 4
**Tasks**
- [ ] Break the cutover pause into phases (hold wait, lag drain, verify, etcd flip, acknowledgement wait, release); optimize the largest.
- [ ] Update diagrams and docs; publish write-up 4; tag `v0.4-streaming`.

**Done when:** the pause breakdown chart is committed; the post is public.
