# Multi-Host Deployment — `rocky2`

**Status**: Production
**Established**: 2026-04-27
**Owner**: Operator (`coinsage.bot@`)
**Audience**: Anyone changing where mdsync runs, or wondering why a service status looks wrong on the dashboard

---

## 1. Why this exists

TradeLens used to run as a single-host deployment on `rocky-8gb` (Hetzner CCX33, public IP `49.13.64.98`). Every Bybit-calling component shared one egress IP, which means they shared one per-IP rate-limit budget on Bybit's public market-data endpoints (`/v5/market/kline`, `/v5/market/recent-trade`, etc.).

In April 2026 we narrowed `mdsync_pg`'s Phase C live loop to active-trading symbols only (171 → ~20 symbols, cycle wall-clock 235 s → 30 s). The narrowing made `mdsync_pg` 8× more aggressive against Bybit, which in turn starved every other Bybit consumer on `rocky-8gb` (level-guard, level-mind, dashboard charts, BybitATR fallback, ~50 call sites in total — none of which coordinate through `mdsync_pg`'s own rate limiter).

Two architectural answers were on the table:

1. **Move the limiter to `bybit_client.py`** so all 50+ call sites share one budget.
2. **Move `mdsync_pg` to its own host** so Bybit sees a different IP and the budget split is automatic.

The user chose (2) because it solves the problem **today** with no code coordination across daemons, and because moving compute is cheap on Hetzner. Option (1) is still on the table as the architectural cleanup.

---

## 2. Topology

```
                      ┌──────────────────────────┐                 ┌──────────────────────┐
                      │  rocky-8gb (CCX33)       │                 │  rocky2 (CPX32)      │
                      │  Falkenstein             │                 │  Falkenstein         │
                      │                          │                 │                      │
   public eth0  ─────►│ 49.13.64.98              │                 │ 178.104.179.251      │◄───── public eth0
                      │                          │                 │                      │
   private net  ─────►│ 10.50.0.3 / enp7s0       │◄────────────────┤ 10.50.0.2 / enp7s0   │◄───── private net
                      │                          │   PG over priv  │                      │
                      │                          │                 │                      │
                      │  Runs:                   │                 │  Runs:               │
                      │  - api  (FastAPI :8088)  │                 │  - mdsync_pg ONLY    │
                      │  - dashboard (vite :3000)│                 │                      │
                      │  - pipeline              │                 │                      │
                      │  - level-guard           │                 │  All other tl        │
                      │  - level-mind            │                 │  services on rocky2  │
                      │  - breach-decision-*     │                 │  show as STOPPED —   │
                      │  - alert-engine          │                 │  expected.           │
                      │  - vwap-*                │                 │                      │
                      │  - correlation-engine    │                 │                      │
                      │  - telegram-signals      │                 │                      │
                      │  - monitor               │                 │                      │
                      │  - postgresql 16 (data)  │                 │                      │
                      └──────────────────────────┘                 └──────────────────────┘
                                  │                                            │
                                  └─────────► same Bybit, but TWO ◄────────────┘
                                              independent per-IP budgets
```

**Key facts:**
- Both VMs are in Hetzner Falkenstein, on the same private subnet `10.50.0.0/24`. Inter-VM RTT is sub-millisecond.
- The private interface (`enp7s0`) is in firewalld's `trusted` zone on both hosts — every TCP port is reachable between them.
- The single PostgreSQL instance lives on `rocky-8gb` (`/db/data01/pgdata`, PG 16). It listens on `localhost:5432` AND `10.50.0.3:5432`.
- `rocky2` is also on the user's Tailscale network (`100.67.8.43`) but mdsync uses the Hetzner private network, not Tailscale (lower latency + no Tailscale dependency).

---

## 3. What runs where (and why)

| Service | Host | Reason |
|---|---|---|
| **`mdsync_pg`** | `rocky2` | Dedicated Bybit per-IP budget. With the live-loop narrowing, mdsync hits Bybit ~4-5 RPS sustained, which on `rocky-8gb` was monopolising the budget shared with 50 other clients. |
| `api` | `rocky-8gb` | FastAPI server, must live with the DB and the other daemons. |
| `dashboard` | `rocky-8gb` | Frontend, must live with `api`. |
| `pipeline` | `rocky-8gb` | Reads/writes to PG; tightly coupled to other refresh services. |
| `level-guard`, `level-mind` | `rocky-8gb` | Trading-critical; must be co-located with PG and the API for low-latency order placement and breach decisions. |
| `breach-decision-*` (label-backfill, outcome-backfill) | `rocky-8gb` | Backfill workers, share PG connections. |
| `alert-engine`, `vwap-*`, `correlation-engine`, `telegram-signals`, `monitor` | `rocky-8gb` | All other workers stay co-located. |
| `postgresql` | `rocky-8gb` | Single source of truth. Listens on `localhost` AND `10.50.0.3` so `rocky2` can reach it. |

**Why only mdsync moved:** mdsync is the only service whose Bybit traffic is high-volume + uncoordinated + not latency-critical. Trading-critical services (`level-guard`, `level-mind`) need to be co-located with PG so order-placement decisions complete in milliseconds, not network roundtrips.

---

## 4. How `mdsync_pg` works on `rocky2`

### 4.1 Code parity

`rocky2` has its own clone of the `tradesuite` git repo at `/app/syb/tradesuite/`. Same git remote (`git@gitlab.com:freemagu-group/tradesuite.git`), same branch (`master`). After the cutover, code stays in sync via **manual `git pull` on rocky2** (the user picked this over hooks/rsync — see CLAUDE memory and the rocky2 setup conversation log).

Standard update workflow:

```bash
# On rocky2:
cd /app/syb/tradesuite
git pull origin master
/app/syb/tradesuite/tradelens/bin/mdsync_pg restart
```

If `etc/config.yml` has uncommitted local overrides (which it always does — see §4.2), pull will refuse. Standard fix:

```bash
git stash push -m "rocky2 local config" -- tradelens/etc/config.yml
git pull origin master
git stash pop
```

### 4.2 Per-host config overrides

Two values in `tradelens/etc/config.yml` differ from the in-repo defaults on `rocky2`:

| Key | Repo default | rocky2 value | Why |
|---|---|---|---|
| `database.host` | `"127.0.0.1"` | `"10.50.0.3"` | PG lives on rocky-8gb |
| `postgresql.host` | `"127.0.0.1"` | `"10.50.0.3"` | Candle reader pool, same DB |
| `market_data.tuning.rate_limit_rps` | `5` | `20` | Dedicated IP, mdsync is the only Bybit consumer here, so it can safely run at 4× the rocky-8gb cap (which is throttled to leave headroom for the 50+ other Bybit clients sharing that IP). |

These three live-edits exist only on rocky2 and never get committed back to git. The pre-fix flow was a hardcoded `RATE_LIMIT_RPS = 5` literal in `fetcher.py`; that was lifted to a config knob in commit `2bd5d8a4` precisely so per-host overrides could exist without code divergence.

### 4.3 Daemon lifecycle

`mdsync_pg` on rocky2 uses the same `tl`-style wrapper as on rocky-8gb (`bin/mdsync_pg start|stop|restart|status`). Auto-restart is provided by `bin/lib/autorestart.sh` (the wrapper spawns it; if the python process dies, the wrapper restarts it).

Two PIDs:
- **PID `<wrapper>`** — the `bash autorestart.sh` daemon.
- **PID `<python>`** (= wrapper PID + ~4) — the actual `mdsync_pg.py` process.

`tl status` on rocky2 will show `mdsync_pg RUNNING (PID <wrapper>)`. Every other `tl` service on rocky2 will show STOPPED — that's correct, they don't run there.

### 4.4 Three-phase execution (recap)

`mdsync_pg.py` on rocky2 runs the same three-phase model as it always has:

| Phase | What it does | Notes for rocky2 |
|---|---|---|
| **A** — Coverage Reconciliation | Queries `trade_journal` + `trade_idea` to compute the full coverage catalog (~171 symbols × 7 timeframes). | Reads from PG on rocky-8gb via `10.50.0.3`. |
| **B** — Catch-up Backfill | Walks the full catalog, fetches any missing historical candles. ~5-10 min on a fresh start. | Skipped with `--live-only`. |
| **C** — Live Loop | Re-computes the active-trading set every cycle (`compute_live_loop_symbols` from commit `8f803111`); fetches recent candles for that set; recon thread runs concurrently with its own dedicated PG connection. | This is what runs ~99% of the time. |

### 4.5 Live-loop set composition (post commit `8f803111`)

Each Phase C cycle, mdsync re-queries the active-trading set from rocky-8gb's PG:

```sql
SELECT symbol, market_type FROM (
  SELECT symbol, category AS market_type FROM level_guard WHERE status='active'
  UNION
  SELECT symbol, category FROM trade_journal
    WHERE status NOT IN ('closed','cancelled')
  UNION
  SELECT symbol, market_type FROM trade_idea
    WHERE created_at >= NOW() - INTERVAL '3 days'
  UNION
  SELECT symbol, category FROM trade_journal
    WHERE status='closed' AND closed_at >= NOW() - INTERVAL '3 days'
)
```

Both day-windows are configurable (`market_data.tuning.live_loop_idea_lookback_days`, `live_loop_closed_trade_lookback_days`).

Today on prod this returns ~20 symbols. Cycle wall-clock at 20 RPS: ~9 s. Hot-symbol 1m candle freshness: ~10-30 s (one candle period plus the cycle interval).

### 4.6 Recon thread

Recon (gap detection + finalisation across the full catalog) runs in a **dedicated daemon thread** with its OWN PG connection (psycopg2 connections aren't thread-safe) and its OWN `CandleFetcher` (so the `_invalid_symbols` cache is independent). The thread cadence is `market_data.tuning.recon_interval_seconds` (default 600 s = 10 min).

Effect: recon never blocks the live loop. Hot symbols stay fresh even during a recon iteration.

On rocky2 with the dedicated IP and 20 RPS: a recon iteration takes ~6 minutes (down from 23 minutes when it was contesting `rocky-8gb`'s 5-RPS budget with 50 other clients).

---

## 5. Common operations

### 5.1 Restart `mdsync_pg`

```bash
ssh sybase@10.50.0.2
source /app/syb/tradesuite/sourceme.sh
/app/syb/tradesuite/tradelens/bin/mdsync_pg restart
```

For a Phase-C-only restart (skip the catch-up backfill, faster):
```bash
/app/syb/tradesuite/tradelens/bin/mdsync_pg restart --live-only
```

### 5.2 View logs

```bash
ssh sybase@10.50.0.2 'tail -f /app/syb/tradesuite/tradelens/logs/mdsync_pg.log'
ssh sybase@10.50.0.2 'tail -f /app/syb/tradesuite/tradelens/logs/mdsync_pg-recon.log'
```

The TradeLens dashboard's Services panel does NOT see rocky2's logs as of 2026-04-27. Cross-host service awareness is a planned tranche — see §7.

### 5.3 Check status

```bash
ssh sybase@10.50.0.2 'source /app/syb/tradesuite/sourceme.sh && /app/syb/tradesuite/tradelens/bin/mdsync_pg status'
```

### 5.4 Update code

```bash
ssh sybase@10.50.0.2
cd /app/syb/tradesuite
git stash push -m "rocky2 local config" -- tradelens/etc/config.yml
git pull origin master
git stash pop
/app/syb/tradesuite/tradelens/bin/mdsync_pg restart
```

### 5.5 Verify candle freshness from rocky-8gb

```bash
PGPASSWORD=tradelens_poc psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -c "
SELECT symbol, timeframe,
       to_char(MAX(open_time) AT TIME ZONE 'UTC', 'HH24:MI:SS') AS newest,
       EXTRACT(EPOCH FROM (NOW() - MAX(open_time)))::INT AS age_s
FROM market_candle
WHERE symbol IN ('BTCUSDT','SOLUSDT','ETHUSDT')
  AND timeframe = '1m' AND market_type = 'linear'
GROUP BY symbol, timeframe ORDER BY symbol"
```

Expected: `age_s` in the 10-60 second range (one candle period + cycle interval). If it's much larger, mdsync isn't running or its writes aren't reaching PG.

---

## 6. Security boundary

- **Public surface**: `rocky2` exposes SSH on its public IP (`178.104.179.251`) for operator access; no other ports.
- **Private surface**: the `enp7s0` interface (`10.50.0.0/24`) is in firewalld's `trusted` zone on both hosts. Every TCP port reachable. This is treated as a trusted boundary because Hetzner private networks are routed only between the operator's own VMs.
- **PG auth**: `pg_hba.conf` on rocky-8gb allows `tradelens` user from `10.50.0.0/24` with `md5` password auth. Same `tradelens_poc` password as the local connection — the private network is the security boundary, not the password.
- **SSH auth**: `sybase@10.50.0.2` uses key auth with the `id_ed25519` key from `sybase@rocky-8gb`. Future-Claude-on-rocky-8gb can SSH to rocky2 without prompting (the key is already on rocky2's `authorized_keys`).

---

## 7. Known gaps + planned work

### 7.1 Dashboard Services panel doesn't show rocky2's mdsync (planned)

The Services panel in the TradeLens dashboard reads PID files from `rocky-8gb`'s local FS. Since `mdsync_pg` runs on rocky2, the panel currently shows it as `STOPPED`. Same for log viewing.

Planned fix: extend `lib/tradelens/api/services.py` so the service definition for `mdsync-pg` carries an optional `host: '10.50.0.2'` field. When set, status checks (PID file read, `pgrep` fallback) and log reads (`tail`/`wc`) route through SSH instead of local subprocess. Service control (start/stop/restart) likewise.

This is the next planned tranche after the rate-limit-config one (commit `2bd5d8a4`).

### 7.2 Centralised log search (deferred)

The user picked "ship rocky2 logs to rocky-8gb via journald/rsyslog" as a future option. Not yet implemented. For now, view rocky2 logs via SSH (§5.2) or once the dashboard fix above lands, via the Services panel.

### 7.3 Architectural cleanup: shared limiter in `bybit_client.py` (deferred)

The 50+ Bybit call sites in `lib/tradelens/adapters/bybit_client.py` still don't coordinate through any shared limiter. The rocky2 split solved the symptom for mdsync; the underlying smell remains. If level-guard or some other daemon ever ramps up its Bybit call volume, it could exhaust rocky-8gb's per-IP budget and cause 429 storms again — and the rocky2 split won't help because those daemons are co-located on rocky-8gb for trading-critical reasons.

The fix is to move `RATE_LIMIT_RPS` enforcement up into `bybit_client._request` so every consumer on rocky-8gb shares one budget. ~50-80 LOC, no infra change. Tracked but not scheduled.

---

## 8. Reference: setup history

For provenance / re-setup instructions, see the conversation that established this deployment: 2026-04-27, Claude session `c9372634-0e55-4af3-9706-08c1830f3324`. The setup phases were:

1. Provision rocky2 on Hetzner (operator action, web console)
2. Hetzner private network created between rocky-8gb and rocky2
3. Filesystem cloned from rocky-8gb to rocky2 (operator action)
4. SSH key from `sybase@rocky-8gb` added to `sybase@rocky2`'s authorized_keys
5. Fork-child mdsync work (`8f803111`) committed and pushed
6. PG on rocky-8gb configured: `listen_addresses += '10.50.0.3'`, `pg_hba.conf` allows `10.50.0.0/24` with md5
7. firewalld on rocky-8gb: `enp7s0` added to `trusted` zone
8. PG restarted
9. rocky2: pulled commit, configured `etc/config.yml` host overrides, smoke-tested `--live-only`
10. mdsync_pg stopped on rocky-8gb
11. mdsync_pg started on rocky2 (full catch-up first, then steady state)
12. Rate-limit lifted to config (`2bd5d8a4`); rocky2's `etc/config.yml` set `rate_limit_rps: 20`

---

## 9. Quick-reference table for future-you

| Question | Answer |
|---|---|
| Which host runs mdsync_pg? | `rocky2` (`178.104.179.251`, private `10.50.0.2`) |
| Where does it write candles? | PG on `rocky-8gb` (`10.50.0.3:5432`, db=`tradelens`) over the Hetzner private network |
| Why isn't it running on rocky-8gb? | To get a dedicated Bybit per-IP rate-limit budget |
| Why is the dashboard's Services panel showing it as STOPPED? | Panel reads local PID files; rocky2-aware mode is a planned tranche (§7.1) |
| How do I view rocky2's mdsync logs? | `ssh sybase@10.50.0.2 'tail -f /app/syb/tradesuite/tradelens/logs/mdsync_pg.log'` |
| How do I restart mdsync? | `ssh sybase@10.50.0.2 '/app/syb/tradesuite/tradelens/bin/mdsync_pg restart'` (after sourceme) |
| What's special about rocky2's `etc/config.yml`? | `database.host=10.50.0.3`, `postgresql.host=10.50.0.3`, `rate_limit_rps=20` — the rest matches the repo |
| How do I update rocky2's code? | Stash config.yml, pull, pop, restart mdsync_pg (§5.4) |
| What if rocky2 goes down? | Restart mdsync_pg on rocky-8gb (`tl start mdsync_pg`) — same code, will fall back to local PG since rocky-8gb's `etc/config.yml` says `127.0.0.1`. Hot symbols may briefly use the wider 56-min ATR lookback to ride out the candle staleness gap. |
