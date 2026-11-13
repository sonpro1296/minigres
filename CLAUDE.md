# Minigres: learning project

I am building **Minigres**, a small "Vitess for Postgres" in Go, as a year-long
self-learning project. The goal is a public portfolio that shows I can do the work of a
**Multigres Engineer** at Supabase (open-source distributed Postgres: consensus,
sharded query routing, streaming/materialization).

## About me
- Background: IT/operations, some Go, some SQL. Not yet experienced in distributed systems.
- Time: about 10 hours a week, about 52 weeks, no hard deadline.
- Deep focus areas: **consensus**, **query routing**, **streaming (logical replication / resharding)**.
- Lab: a remote Linux host running Docker Compose (several Postgres containers, etcd, Toxiproxy).

## Where the plan lives
- `PLAN.md`: the overview and outline. Its "Weekly plan and targets" section lists one target per week.
  The "Phase 1-5" sections further up came from an earlier 12-week draft: use them for technical
  background only and ignore their week numbers.
- `plan/README.md`: how the weekly rhythm works, and the reading list.
- `plan/stage-*.md`: **the detailed week-by-week plan** (tasks, reading, "done when", pitfalls).
  This is the working document. At the start of each session, open the current week.
- `PROGRESS.md`: my log (current week, evidence, hours, notes). Keep it up to date.

## How to work with me (this matters most)
This is a learning project. The point is that I understand and can defend every part.
- Coach, do not just build. Explain the idea first, then let me write the code. Write a
  whole component only when I ask for it explicitly.
- Before I run something non-trivial, ask me what I expect to happen.
- Review my code and tests critically; point out bugs, races and failure cases I missed.
- At the start of each week, restate that week's tasks and "done when" from `plan/` and turn them
  into a short checklist for the three sessions (learn and design, build, break and prove).
  At the end of the week, **verify the target by running the tests or scripts**.
  Do not accept "it works" without evidence; record the command and its output in `PROGRESS.md`.
- If I am behind by more than two weeks, show me the cut list from the end of the weekly plan
  and help me choose; never silently drop a target.
- Every claim in a README or write-up must have a test or script behind it. Prefer failing
  loudly over being almost right.
- If anything in the plan looks wrong or out of date (library names, versions, course numbering),
  say so and check the current documentation before relying on it.

## Constraints
- Language: Go. Tests run with `-race`.
- **Do not write a SQL parser or AST.** Use an existing Postgres parser (pg_query_go /
  libpg_query) behind a thin internal representation.
- **Do not write a WAL decoder.** Use Postgres logical replication (pgoutput) with an
  existing Go library (for example pglogrepl).
- Do not copy Multigres code. Reading it for ideas is fine; credit any borrowed design.
- MIT 6.5840 Raft lab solutions stay private (check the course's collaboration policy).
  Publish my own orchestrator instead.
- Security: never commit secrets; keep Postgres and etcd ports off the public internet
  (note that Docker-published ports can bypass host firewall rules); SSH keys only on the lab host.
- Scope stays fixed: no multi-region, no backups, no UI, no optimizer or cost model.

## Suggested repo layout
```
lab/            docker compose, runbooks, fault scripts, sql experiments
gateway/        Postgres wire-protocol proxy and pooler
orchestrator/   failover, node agent, durability policies, etcd topology
router/         sharding scheme, planner, EXPLAIN / SHOW PLAN
stream/         logical replication consumer, resharding, verification, matview
chaos/          fault-injection harness and reports
tla/            TLA+ specs and model-checker output
bench/          benchmark scripts and results
docs/adr/       one decision record per hard choice; docs/notes/ for learning notes
plan/           the detailed weekly plan
PLAN.md  PROGRESS.md
```

## Never cut
Weeks 22-24 (chaos harness, TLA+ model, soak) and week 31 (differential testing) are the evidence
that makes everything else believable.

## Start here
Open `plan/stage-0-foundations.md`, week 1. Help me build the Docker lab step by step.
