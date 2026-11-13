# Stage 2: Consensus (weeks 10-24, about 150 hours)

Goal: a failover orchestrator for unmodified Postgres with a pluggable durability policy, fencing,
a TLA+ model, and a fault-injection harness that tries to prove you wrong.

Never cut weeks 22-24. Keep your Raft lab solution private (course policy); publish the orchestrator.

---
## Week 10: Raft, leader election
**Tasks**
- [ ] Read the extended Raft paper through section 5 (Figure 2 is the reference) and "Students' Guide to Raft".
- [ ] Do the Raft lab part on leader election and heartbeats (3A in the current course).
- [ ] Write `scripts/stress.sh` that runs the tests N times with `-race` and stops on the first failure.

**Done when:** the 3A tests pass 100 times in a row with `-race`.

**Pitfalls:** holding a lock while sending an RPC; acting on replies from an old term; an election timeout too close to the
heartbeat interval; reading shared state without the lock.

---
## Week 11: Raft, log replication
**Tasks**
- [ ] Implement the AppendEntries consistency check, `commitIndex`, the apply channel, and the "up-to-date" vote restriction.
- [ ] Implement a faster `nextIndex` back-up on conflicts.
- [ ] Write a one-page trace of one failing run and the bug it exposed.

**Done when:** the 3B tests pass 100 times in a row.

**Pitfalls:** a leader may only advance the commit index by counting replicas for an entry from its *own* term;
apply order must match log order; copy log slices carefully to avoid races.

---
## Week 12: Raft, persistence
**Tasks**
- [ ] Persist `currentTerm`, `votedFor` and the log before replying to any RPC; restore on restart.
- [ ] Run 3A-3C together 100 times. (Snapshots, 3D, are optional; skip them to protect the schedule.)
- [ ] Write `docs/notes/raft-invariants.md`: Election Safety, Leader Append-Only, Log Matching, Leader Completeness,
      State Machine Safety, each with a sentence on how your code upholds it.

**Done when:** 3A-3C pass 100 times in a row; the invariants note exists.

---
## Week 13: Paxos and Flexible Paxos
**Tasks**
- [ ] Read "Paxos Made Simple" and the Flexible Paxos paper.
- [ ] Write `docs/notes/flexpaxos.md`: the idea (the quorums for the two phases only need to intersect each other,
      not each be a majority), plus a worked example for two or three zones.
- [ ] A small script (Go) that brute-forces quorum intersection: given a node set and a rule for commit quorums and election
      quorums, check that every commit quorum intersects every election quorum. You will reuse it in week 20.
- [ ] Map it onto Postgres: a commit waits for standby acknowledgements (commit quorum); a failover must choose a new primary
      from a set that is guaranteed to include a node that holds every acknowledged commit.

**Done when:** the note has a worked example and the checker confirms it, and also rejects a deliberately broken rule.

**Pitfalls:** mixing up the commit quorum and the election quorum; assuming failover can promote "any replica".

---
## Week 14: Durability in Postgres
**Tasks**
- [ ] Reuse the week-4 writer, now as `chaos/writer`: unique id per transaction, logged only after COMMIT returns.
- [ ] Run kill-the-primary experiments under: asynchronous; `synchronous_commit=on` with `ANY 1 (r1, r2)`;
      `FIRST 1`; `remote_write` and `remote_apply` variants. Always promote the most advanced replica by LSN.
- [ ] Count acknowledged ids lost in each case; also record what a client sees for a commit that was in flight at the crash (outcome unknown).
- [ ] `chaos/durability-experiment.sh` reproduces the table.

**Done when:** `docs/notes/durability.md` has the table "configuration → acknowledged writes lost" with raw logs.

**Pitfalls:** the kill has to land during load; names in `synchronous_standby_names` must match each replica's
`application_name`; if all synchronous standbys are gone the primary blocks writes (that is the guarantee, not a bug).

---
## Week 15: TLA+ basics
**Tasks**
- [ ] Watch the first lectures of Lamport's TLA+ Video Course; work through "Learn TLA+" basics.
- [ ] Install the TLA+ tools (Toolbox or VS Code extension) and TLC.
- [ ] Specify a small protocol (two-phase commit or a leader lease) with an invariant. Break it on purpose, read TLC's
      counterexample, fix the spec.

**Done when:** `tla/toy/` has the spec and config; `docs/notes/tla-first-spec.md` shows one counterexample and its fix.

**Pitfalls:** state explosion (use tiny constants); over-detailed specs; confusing invariants (always true) with temporal properties.

---
## Week 16: Failover design
**Tasks**
- [ ] Write `docs/adr/0001-failover.md`: failure model (crash, pause, partition, slow node; no Byzantine faults; clocks only trusted
      for lease durations); components (orchestrators, a small agent beside each Postgres node, etcd, gateway);
      state in etcd (epoch, primary, members, durability policy, lease); promotion rule (candidate must be in a set that covers every
      commit quorum; choose the highest LSN); fencing (the agent demotes itself when its lease lapses; the orchestrator waits out the
      lease before promoting); rejoin (rewind or rebuild); what the gateway does during failover.
- [ ] Sequence diagrams for a planned switchover and a crash failover.
- [ ] Ask at least one other person to review it; record their comments and your answers.

**Done when:** the ADR is merged and one outside comment has been addressed.

**Pitfalls:** a single orchestrator is a single point of failure (use etcd leader election among several);
decide what happens when etcd itself is unreachable (answer: do not promote); do not design features you will not build.

---
## Week 17: Orchestrator v1 (observe)
**Tasks**
- [ ] A node agent (small HTTP or gRPC service next to each Postgres): reports role, timeline, receive and replay LSN, replication state;
      commands: promote, follow(primary), set read-only, stop.
- [ ] The orchestrator polls agents and writes observed state into etcd using leases (etcd v3 client).
- [ ] `orchestratorctl status` prints the live cluster view.
- [ ] Unit tests with fake agents.

**Done when:** killing a replica container shows it unhealthy within a configured number of poll intervals; state-machine tests pass.

**Pitfalls:** detection speed versus flapping (require several consecutive failures); "unreachable from the orchestrator" is not "dead".

---
## Week 18: Orchestrator v2 (act)
**Tasks**
- [ ] Elect the active orchestrator with etcd's `concurrency` election so only one acts.
- [ ] On primary failure: bump the epoch with an etcd compare-and-swap transaction, pick the candidate (highest received LSN among
      allowed nodes), wait until it has replayed what it received, promote, repoint the others, update the topology.
- [ ] Emit timestamped events for each step.
- [ ] Integration test with `docker kill`.

**Done when:** `kill -9` of the primary under load leads to a new primary within your target (record the real number);
the epoch increments exactly once; the test passes 20 runs in a row.

**Pitfalls:** promoting twice; replicas still following the old primary; confusing `docker stop` (graceful) with `docker kill`.

---
## Week 19: Fencing and rejoin
**Tasks**
- [ ] Agent self-fencing: if it cannot renew its lease within the TTL, the primary's agent stops accepting writes
      (stop Postgres, or force read-only plus terminate sessions; choose and justify).
- [ ] The orchestrator waits lease TTL plus a margin before promoting.
- [ ] A partition test: `docker network disconnect` the old primary from the orchestrator and etcd.
- [ ] Rejoin: an agent that sees a newer epoch runs `pg_rewind` against the new primary (fall back to `pg_basebackup`), then starts as a standby.

**Done when:** in the partition test, writes attempted on the old primary after lease expiry plus margin never succeed;
after healing it rejoins as a replica and its checksum matches the new primary; 10 runs in a row.

**Pitfalls:** use monotonic clocks and durations, not wall-clock timestamps compared across machines; a process paused with
SIGSTOP wakes up believing it is still primary (check the epoch before accepting work); `pg_rewind` prerequisites.

---
## Week 20: Durability policies
**Tasks**
- [ ] Interface `Policy` with: is a set of acknowledgements enough, which nodes may be promoted, what `synchronous_standby_names` to configure.
- [ ] Two implementations: majority; cross-zone (at least one standby in a different zone than the primary). Add zone labels in Compose.
- [ ] The orchestrator re-applies the setting when members change and refuses any promotion that violates the policy.
- [ ] Brute-force test with the week-13 intersection checker for each policy.

**Done when:** unit and integration tests pass; with the cross-zone policy, losing the only other-zone standby blocks commits (documented)
and no policy-violating promotion happens.

**Pitfalls:** unsatisfiable policy means a choice between availability and durability: write down the behavior you chose.

---
## Week 21: Gateway integration
**Tasks**
- [ ] The gateway watches the topology in etcd and routes writes to the current primary.
- [ ] While the primary is unknown or the epoch is changing, hold new requests up to a bound.
- [ ] Requests in flight at the moment of failure return an error (outcome unknown). Never silently retry a statement that might have committed;
      retry only requests that had not yet been sent.
- [ ] Metrics: requests held, hold duration histogram, hold timeouts.

**Done when:** with `pgbench` through the gateway and the primary killed, errors are limited to in-flight requests, held requests
succeed after promotion, and the hold-time metric is recorded.

**Pitfalls:** acting on stale topology (check the epoch and verify the backend's role on connect); an unbounded hold queue;
a thundering herd after promotion.

---
## Week 22: Fault-injection harness
**Tasks**
- [ ] `chaos/`: N workload clients that append unique values and record a history (`invoke`, `ok`, `fail`, `info` for unknown outcome)
      as JSON lines.
- [ ] A scheduler ("nemesis") with seeded randomness: kill primary, kill replica, `docker pause`, partition, added latency/loss
      (`tc netem` with `NET_ADMIN`, or Toxiproxy).
- [ ] A checker: every `ok` write is present at the end; no unexpected duplicates; `info` operations may or may not be present;
      periodic probes show at most one writable primary per epoch.
- [ ] Report as Markdown, exit code non-zero on violation.

**Done when:** `make chaos SEED=42 DURATION=10m` produces a report and is reproducible by seed; a deliberately injected bug
(promote a lagging replica) is caught by the checker.

**Pitfalls:** a checker that cannot fail; seeds that are not reproducible (wall-clock dependence); counting `info` as failure; client retries that create duplicates.

---
## Week 23: TLA+ model of your protocol
**Tasks**
- [ ] Model: nodes with role, epoch and WAL; a shared atomic epoch (etcd); lease expiry as a nondeterministic event; fencing; promotion
      rule; policy as quorum sets.
- [ ] Actions: ClientWrite and Ack (ack requires a policy quorum), Crash, Partition, Heal, LeaseExpire, Promote(candidate), Rejoin (truncate a divergent suffix).
- [ ] Invariants: `NoAckedLoss` (every acknowledged entry is in the current primary's WAL), `AtMostOneWritable`.
- [ ] Run TLC with 3 nodes and a short WAL. Remove the promotion guard and confirm TLC finds a violation.
- [ ] Table mapping each invariant to the chaos checks that test it.

**Done when:** `tla/failover/` has the spec, config and TLC output; the mutated spec's counterexample is saved; the mapping table exists.

**Pitfalls:** assuming fencing is atomic in the model; state explosion; the spec and the code drifting apart (keep the mapping table up to date).

---
## Week 24: Chaos soak and write-up 2
**Tasks**
- [ ] Run at least five soaks of 30 minutes with different seeds and fault mixes, including combined faults.
- [ ] For each bug: symptom, root cause, fix, regression test, recorded in `docs/bugs.md`.
- [ ] Publish write-up 2: protocol, spec, harness, results, limits (Docker networking is not a real network; single host).
- [ ] Tag `v0.2-consensus`. Consider applying now.

**Done when:** every soak run ends with zero violations after fixes; reports are committed; the post is public.

**Pitfalls:** declaring victory after short runs; hiding failures; implying production readiness.
