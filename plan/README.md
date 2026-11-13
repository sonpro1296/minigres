# Detailed plan: how to use these files

`PLAN.md` gives the 52-week outline. These files expand **every week** into tasks, reading,
a checkable "done when", and the pitfalls that usually cost people time.

| File | Weeks |
|---|---|
| `stage-0-foundations.md` | 1-6 |
| `stage-1-gateway.md` | 7-9 |
| `stage-2-consensus.md` | 10-24 |
| `stage-3-routing.md` | 25-36 |
| `stage-4-streaming.md` | 37-48 |
| `stage-5-wrapup.md` | 49-52 |

## Weekly rhythm (about 10 hours, three sessions)
- **Session A (3 h) learn and design.** Read, sketch, write a one-page note or decision record
  (`docs/adr/`). Do not start coding until you can explain the design out loud.
- **Session B (4 h) build.** Implement the smallest thing that can be tested.
- **Session C (3 h) break and prove.** Tests, fault injection, measurements. Record results in
  `docs/` with the exact command that produced them.
- **20-minute review at the end of the week.** Update `PROGRESS.md`: target met? evidence
  (command and output)? hours spent? If the target is not met, carry it over; do not mark it done.

## Evidence rule
A target counts only when a command or script demonstrates it. "Done when" lines are written so
that they can be checked this way. Keep the commands in the repo (`make` targets).

## Resources named in these files (look them up by title)
- PostgreSQL manual: "Frontend/Backend Protocol", "High Availability, Load Balancing, and
  Replication", "Logical Replication", "Transaction Isolation", `pg_rewind`, `pg_basebackup`,
  `pgbench`.
- Go: "A Tour of Go", "Effective Go", the Go blog posts on contexts and pipelines.
- Raft: the extended Raft paper, Ongaro's thesis, "Students' Guide to Raft", the MIT 6.5840 labs.
  In the current course the Raft lab is Lab 3 (parts 3A election, 3B log, 3C persistence,
  3D snapshots); older course years called it Lab 2. Check the course's collaboration policy
  and keep lab solutions private.
- "Paxos Made Simple" (Lamport); "Flexible Paxos: Quorum intersection revisited"
  (Howard, Malkhi, Spiegelman).
- TLA+: Lamport's TLA+ Video Course; "Learn TLA+" (learntla.com); the TLC model checker.
- Jepsen analyses (jepsen.io) for how correctness is tested under faults.
- "Designing Data-Intensive Applications" (Kleppmann): replication, partitioning, transactions,
  consistency and consensus, stream processing.
- Vitess documentation: vindexes, VReplication, MoveTables, Reshard.
- Go libraries: `jackc/pgx` and `jackc/pgproto3`, `jackc/pglogrepl`,
  `pganalyze/pg_query_go` (needs cgo), the etcd v3 client, Toxiproxy, `uber-go/goleak`,
  `pgregory.net/rapid`.

Titles and library names are from memory: confirm current names and versions before relying on them.
