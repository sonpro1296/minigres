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
- Met? yes (2026-11-13). Open follow-up: check.sh reports "not in recovery" when a replica
  is unreachable; should say "cannot query".
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
  - [x] Restart path + named replicas (2026-11-13), after adding `cluster_name` (93c567c):
    ```
    $ make lab-down && make lab-up && docker exec pg-primary psql -U postgres -c "SELECT application_name, client_addr, state FROM pg_stat_replication;" && docker logs pg-replica1 2>&1 | head -5
     application_name | client_addr |   state
    ------------------+-------------+-----------
     pg-replica2      | 172.28.0.3  | streaming
     pg-replica1      | 172.28.0.4  | streaming
    replica: data directory exists, starting as-is
    PostgreSQL Database directory appears to contain a database; Skipping initialization
    LOG:  starting PostgreSQL 18.7 ... aarch64
    $ bash ./check.sh; echo "exit=$?"
    ... PASS
    exit=0
    ```
    Container IPs swapped between runs (.3/.4); identify replicas by name, never by IP.
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
  - [x] `lab/check.sh` fails loudly with pg-replica2 stopped (2026-11-13):
    ```
    $ docker stop pg-replica2 && make lab-check; echo "exit=$?"; docker start pg-replica2
    ok:   pg-primary is primary
    ok:   pg-replica1 is in recovery
    Error response from daemon: container 7dbbe985... is not running
    FAIL: pg-replica2 is not in recovery (promoted or misconfigured?)
    make: *** [Makefile:21: lab-check] Error 1
    exit=2
    ```
    Exit is non-zero, but the FAIL message is wrong: the container was down, not promoted.
    Fix: report "cannot query" separately from a wrong answer.
  - [~] External reachability from Windows laptop (2026-11-13), 4 ports only:
    ```
    PS> 22,5432,5433,5434 | % { Test-NetConnection <lab-host> -Port $_ | select RemotePort, TcpTestSucceeded }
    22 True / 5432 False / 5433 False / 5434 False   (as reported)
    ```
    Port 22 is the positive control.
  - [x] nmap connect scan from Windows laptop (2026-11-13; nmap 7.80, `-sT` because Npcap fails):
    ```
    PS> nmap -sT -Pn --unprivileged -p 22,5432,5433,5434 <lab-host>
    PORT     STATE    SERVICE
    22/tcp   open     ssh
    5432/tcp filtered postgresql
    5433/tcp filtered pyrrho
    5434/tcp filtered sgi-arrayd
    ```
    `filtered` = packets dropped by a firewall in front of the host, not merely "closed".
  - [x] Full external scan, all 65,535 TCP ports (2026-11-13, 2905 s):
    ```
    PS> nmap -sT -Pn --unprivileged -T4 -p- <lab-host>
    Host is up (0.062s latency).
    Not shown: 65534 filtered ports
    PORT   STATE SERVICE
    22/tcp open  ssh
    ```
- Decision 2026-11-14: expose Postgres ports to the internet (`LAB_BIND_IP=0.0.0.0` on the
  lab host, cloud firewall opened for 5432-5434) for direct access from the laptop, accepting
  the risk because the lab holds no real data. This overrides the CLAUDE.md rule "keep
  Postgres ports off the public internet". The Week 1 scan evidence above describes the
  setup before this change. Repo default stays `127.0.0.1`.
- What I learned:
- What went wrong / blockers:
- Carry over to next week:
