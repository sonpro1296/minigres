# Minigres: plan overview

A year-long self-learning project: build a small "Vitess for Postgres" in Go to show the skills
behind the **Multigres Engineer** role at Supabase (open-source distributed Postgres).
This is a condensed overview; the week-by-week detail is in `plan/`. The longer planning
document (with the reasoning) is at https://claude.ai/artifact/HcTnh5jfSKBoa8tnyeAV7s.

## What the role tests
Source: the job posting and the Multigres "contributor qualifications" discussion (#78).
- Database sharding and relational algebra: a query engine that splits queries into relational
  operations, pushes them to shards and recombines results.
- Consensus: FlexPaxos-style flexible quorums on top of unmodified Postgres synchronous
  replication, with orchestrators that perform failover. Raft, Paxos and FlexPaxos familiarity.
- Materialization: stream processing that stays correct when sharded; used for resharding,
  migrations, materialized views and change data capture.
- Scale: robust code, observability, timeouts and retries, preventing cascading failures.
- Postgres internals are an added bonus.

## The plan (about 10 hours a week, 52 weeks, about 520 hours)
| Stage | Weeks | Hours | What you build | Proof |
|---|---|---|---|---|
| 0. Foundations | 1-6 | 60 | Docker lab, Go network code, wire-protocol client, manual failover, isolation experiments | Runbook, lab repo, write-up 0 |
| 1. Thin gateway | 7-9 | 30 | Protocol-forwarding proxy with simple pooling and hooks for routing and request holding | Benchmark vs PgBouncer, write-up 1 |
| 2. Consensus (deep) | 10-24 | 150 | Raft labs, FlexPaxos note, failover orchestrator with durability policies, fencing, TLA+ model, chaos harness | TLA+ output, chaos soak, write-up 2 |
| 3. Routing (deep) | 25-36 | 120 | Sharding scheme, rule-based router on an existing parser, scatter-gather, aggregates, co-located joins | Differential tests, supported-shapes table, write-up 3 |
| 4. Streaming (deep) | 37-48 | 120 | Logical-replication consumer, crash-safe apply, verification, live 2→4 reshard, materialized view | Reshard under load with zero divergence, write-up 4 |
| 5. Wrap-up | 49-52 | 40 | Upstream PRs, demo, polish, application | Public repo, demo, PRs |

Consider applying after week 24, with the consensus work published.

## Ground rules
- A target counts only when a command or script demonstrates it.
- Failing loudly beats being almost right: document what is not supported.
- No SQL parser and no WAL decoder of your own: use pg_query_go and pglogrepl.
- Do not copy Multigres code; keep MIT 6.5840 lab solutions private.
- Never cut weeks 22-24 or week 31.
- If you fall more than two weeks behind, cut in this order: week 33, week 40, week 46,
  the reverse-path detail of week 42, then all of stage 4.

## Where to look
- `plan/README.md`: weekly rhythm and reading list.
- `plan/stage-*.md`: tasks, reading, "done when" and pitfalls for every week.
- `PROGRESS.md`: your log. `CLAUDE.md`: instructions for Claude Code.
