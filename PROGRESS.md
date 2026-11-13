# Progress log

Start date: 2026-11-13    Hours per week: about 10

## Status
| Stage | Weeks | Status | Notes |
|---|---|---|---|
| 0. Foundations | 1-6 | in progress | week 1 started 2026-11-13 |
| 1. Thin gateway | 7-9 | not started | |
| 2. Consensus | 10-24 | not started | |
| 3. Routing | 25-36 | not started | |
| 4. Streaming | 37-48 | not started | |
| 5. Wrap-up | 49-52 | not started | |

## Weekly entries
Copy this block for each week. A target is met only with evidence: the command and its output.

### Week N: title
- Planned hours / actual hours:
- Target (from `plan/`):
- Met? yes / no / partly
- Evidence (command and output, or file path):
- What I learned:
- What went wrong / blockers:
- Carry over to next week:

### Week 1: Docker lab
- Planned hours / actual hours: 10 /
- Target (from `plan/stage-0-foundations.md`): `pg_stat_replication` on the primary shows two
  `streaming` rows; `lab/check.sh` passes; a port scan from outside shows only SSH.
- Met? partly
- Evidence (command and output, or file path):
  - [x] Two streaming replicas (2026-11-13):
    ```
    $ docker exec pg-primary psql -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
     client_addr |   state   | sync_state
    -------------+-----------+------------
     172.28.0.3  | streaming | async
     172.28.0.4  | streaming | async
    (2 rows)
    $ docker exec pg-replica1 psql -U postgres -c "SELECT pg_is_in_recovery();"
     t
    ```
  - [x] Ports bound to 127.0.0.1 only (2026-11-13):
    ```
    $ sudo ss -tlnp | grep -E '543[2-4]'
    LISTEN 0 4096 127.0.0.1:5434 0.0.0.0:* users:(("docker-proxy",pid=207159,fd=8))
    LISTEN 0 4096 127.0.0.1:5433 0.0.0.0:* users:(("docker-proxy",pid=207247,fd=8))
    LISTEN 0 4096 127.0.0.1:5432 0.0.0.0:* users:(("docker-proxy",pid=206975,fd=8))
    ```
  - [ ] Restart path: second `make lab-up` reuses data, no re-clone
  - [x] `lab/check.sh` passes (2026-11-13), also confirms pg-replica2 in recovery:
    ```
    $ make lab-check; echo "exit=$?"
    ok:   pg-primary is primary
    ok:   pg-replica1 is in recovery
    ok:   pg-replica2 is in recovery
    ok:   pg-primary reports 2 streaming replicas
    ok:   wrote check-1794582335367442771-9258 on pg-primary
    ok:   pg-replica1 has the row after 109 ms
    ok:   pg-replica2 has the row after 106 ms
    PASS
    exit=0
    ```
    The ms figures are dominated by `docker exec` overhead, not replication lag.
  - [ ] `lab/check.sh` fails loudly with pg-replica2 stopped
  - [~] External reachability from Windows laptop (2026-11-13), 4 ports only:
    ```
    PS> 22,5432,5433,5434 | % { Test-NetConnection <lab-host> -Port $_ | select RemotePort, TcpTestSucceeded }
    22 True / 5432 False / 5433 False / 5434 False   (as reported)
    ```
    Port 22 is the positive control. Still to do: full `nmap -Pn -p-` scan for "only SSH visible".
- What I learned:
- What went wrong / blockers:
- Carry over to next week:
