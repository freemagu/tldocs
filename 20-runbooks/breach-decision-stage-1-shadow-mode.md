# Breach Decision — Stage 1 Shadow-Mode Operator Runbook

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

> [!warning] Status: runbook written; shadow mode is active but Stage 2 (actual gate wiring) is not started.
> The predictor runs after every breach event, writes to `breach_decision_log`, and returns.
> It does not gate or delay order execution. Stage 2 (wiring `recommended_max_delay_s`
> into LevelGuard) is out of scope for Stage 1.

Single-page runbook for bringing the Breach decision predictor up in shadow mode.
Stage 1 means **observation only**: the predictor runs after every
breach, writes a row to `breach_decision_log`, and the backfill daemons
populate realised labels and execution outcomes asynchronously. The
predictor's recommendation is **not** consumed by LevelGuard, so order
placement is unchanged from pre-Stage-1 behaviour.

If you only need a one-shot readiness check, run:

```bash
$TLHOME/bin/breach-decision-stage1-check
```

The rest of this runbook unpacks what that check verifies and what to do
when something is amber.

## Shadow-mode invariants

These properties are load-bearing — if any of them is no longer true, you
are not in Stage 1 any more and this runbook does not apply.

- `bin/server/level_mind_worker.py` invokes the orchestrator via an
  `on_breached` callback only.
- The orchestrator (`lib/tradelens/breach_decision/orchestrator.py`) writes a
  log row and returns. It does not mutate guard state. It does not gate
  order placement.
- `guard_chose_to_delay` and `guard_delay_seconds_chosen` on every
  populated row stay at `FALSE` / `0` — the B5 outcome backfill enforces
  this.
- The recommendation column `recommended_max_delay_s` is recorded but
  not consumed anywhere downstream.

## Pre-checks (run these once before starting Stage 1)

| Check | Command | Expected |
|---|---|---|
| Environment loaded | `echo $TLHOME` | `/app/syb/tradesuite/tradelens` |
| Postgres reachable | `pg_isready -h 127.0.0.1 -p 5432` | `accepting connections` |
| Migrations up to date | `python3 bin/setup/migrate.py status` | `Pending: 0` |
| Migration 079 applied | see SQL §1 below | one row in `schema_migration` |
| Columns renamed | see SQL §2 below | `guard_execution_outcome`, `guard_executed_at_utc` present; `soft_stop_*` absent |
| tl sees backfills | `tl status --json \| jq -r '.services[].service' \| grep level-b` | both `breach-decision-label-backfill` and `breach-decision-outcome-backfill` listed |

## Apply migration 079 to production (one-time)

The `breach_decision_log` table on production carries the historical
`soft_stop_*` outcome columns. Migration 079 renames them to
`guard_execution_*` and rebuilds the partial index that referenced the
old name. The migration is idempotent — a second run is a no-op.

```bash
source $TSHOME/sourceme.sh
cd $TLHOME

# Optional dry-run preview
python3 bin/setup/migrate.py up --dry-run

# Apply (idempotent; ~30ms in test-DB validation)
python3 bin/setup/migrate.py up
```

Verify:

```bash
python3 bin/setup/migrate.py status \
    | grep 079_breach_decision_log_rename_outcome
```

## Start the backfill daemons

```bash
tl breach-decision-label-backfill start         # populates realised_safe_*
tl breach-decision-outcome-backfill start       # populates guard_execution_outcome
tl status                               # confirm both RUNNING
```

Both default to `--poll 60` (one batch every 60s). Override by passing
extra args: `tl breach-decision-label-backfill start --poll 30`. Logs:

- `$TLHOME/logs/breach_decision_label_backfill.log`
- `$TLHOME/logs/breach_decision_outcome_backfill.log`

## Check health

The Stage 1 health surface is `bin/breach-decision-health`. Read-only; safe to
run any time.

```bash
# Default 24-hour window
tl breach-decision-health 2>/dev/null \
    || $TLHOME/bin/breach-decision-health
$TLHOME/bin/breach-decision-health --since-hours 1
$TLHOME/bin/breach-decision-health --symbol BTCUSDT
$TLHOME/bin/breach-decision-health --json | jq '.status_counts'
```

(The CLI is a `bin/show/` script; `tl` does not manage it because it has
no daemon lifecycle.)

## What "healthy" looks like

After running Stage 1 for an hour or two with active breaches, expect:

- `status_counts.ok` is the largest bucket; `error` is zero or
  near-zero.
- `fallback` count tracks tick-coverage availability — sustained
  > 30 % suggests a tick-feed problem worth investigating, not a
  predictor bug.
- `skipped` rows are dominated by the hard-stop precondition message
  when `level_b.require_confirmed_hard_stop = true`.
- `backfill_arrears.label_pending` rises during quiet periods (waiting
  for the 180s observation window) and drains during active markets.
- `backfill_arrears.outcome_pending` reflects open guards still in
  flight; this can stay non-zero indefinitely if guards are long-lived.
- Every symbol with breach activity shows up in `per_symbol`. A
  symbol that should be active but is missing is the first flag worth
  investigating.

The Stage 1 progression criterion is **≥ 100 logged decisions per
symbol**. Read this off `per_symbol.<symbol>.total` in the CLI text or
JSON.

## First troubleshooting checks

| Symptom | First check |
|---|---|
| Health CLI: `UndefinedColumn: guard_execution_outcome` | Migration 079 not applied. See "Apply migration 079" above. |
| `tl status` shows backfill services as `STOPPED` | `tl breach-decision-{label,outcome}-backfill start` and tail the log. |
| Backfill log shows `tick archive missing` | The label backfill is conservative: missing tick data leaves the row pending and retries on the next poll. Check tick-archive freshness at `/db/data01/tick_archive/...`. |
| Decision log empty in the recent window | Either no breaches happened or the LevelMind worker isn't passing `on_breached` callbacks. `tl level-mind status`; tail `logs/level_mind_worker.log` for orchestrator wiring errors. |
| `status_counts.error` rising | Tail `logs/level_mind_worker.log` for the swallowed exception traceback (the orchestrator catches and logs every exception so the breach path stays alive). |
| `outcome_pending` growing without bound | Outcome backfill needs the guard to reach a terminal state. If the guard is still active, the row legitimately stays pending. If guards have terminated but rows haven't been picked up, restart `breach-decision-outcome-backfill`. |

## Stop / pause / resume

```bash
tl breach-decision-label-backfill stop
tl breach-decision-outcome-backfill stop

# Or stop the whole Breach decision + LevelMind stack together:
tl stop level-mind breach-decision-label-backfill breach-decision-outcome-backfill
```

Pausing the LevelMind worker (`tl level-mind pause` / `resume`) freezes
breach evaluation upstream — no new decision-log rows will be written
while paused. Backfill daemons are independent and continue draining
arrears.

## SQL snippets — copy-paste

All against `tradelens` on `127.0.0.1:5432`. Use:

```bash
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -c "<SQL>"
```

### §1 Confirm migration 079 is applied

```sql
SELECT filename, applied_at
FROM schema_migration
WHERE filename = '079_breach_decision_log_rename_outcome.sql';
```

### §2 Confirm canonical column names

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'breach_decision_log'
  AND column_name IN (
      'guard_execution_outcome',
      'guard_executed_at_utc',
      'soft_stop_outcome',
      'soft_stop_executed_at_utc'
  )
ORDER BY column_name;
```

Expected: only `guard_execution_outcome` and `guard_executed_at_utc`.

### §3 Latest 20 rows in the decision log

```sql
SELECT decided_at_utc, symbol, swing_type, status, status_detail,
       feature_completeness, tick_count_60s_observed
FROM breach_decision_log
ORDER BY decided_at_utc DESC
LIMIT 20;
```

### §4 Counts by status (last 24h)

```sql
SELECT status, COUNT(*) AS n
FROM breach_decision_log
WHERE breach_ts_utc >= NOW() - INTERVAL '24 hours'
GROUP BY status
ORDER BY n DESC;
```

### §5 Pending label backfill (rows past the 180s observation window
without a label)

```sql
SELECT COUNT(*) AS pending_label_rows,
       MIN(breach_ts_utc) AS oldest_pending
FROM breach_decision_log
WHERE realised_label_at IS NULL
  AND breach_ts_utc <= NOW() - INTERVAL '180 seconds';
```

### §6 Pending outcome backfill

```sql
SELECT COUNT(*) AS pending_outcome_rows,
       MIN(breach_ts_utc) AS oldest_pending
FROM breach_decision_log
WHERE guard_execution_outcome IS NULL;
```

### §7 Per-symbol totals (last 24h)

```sql
SELECT symbol,
       COUNT(*)                                          AS total,
       COUNT(*) FILTER (WHERE status = 'ok')             AS ok,
       COUNT(*) FILTER (WHERE status = 'fallback')       AS fallback,
       COUNT(*) FILTER (WHERE status = 'skipped')        AS skipped,
       COUNT(*) FILTER (WHERE status = 'error')          AS error
FROM breach_decision_log
WHERE breach_ts_utc >= NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY total DESC;
```

## Out of scope for Stage 1

- Wiring `recommended_max_delay_s` into LevelGuard's actual delay
  decision (Stage 2).
- Websocket sidecar for sub-second tick streaming (Bundle B6).
- ETH or other multi-symbol training artefacts.
- Alerting thresholds. Stage 1 is eyeball-driven via the health CLI;
  thresholds are a deliberate later tranche after we have observed
  baselines.

## See also

- [[breach-decision-glossary]] — terminology (breach / sustained / rejected)
- [[breach-decision-training]] — training pipeline (produces artefacts consumed by the predictor)
- [[breach-decision-retraining-jobs]] — job cadence including label-backfill monitoring
- [[pool-vs-baseline-2026-05-04]] — latest training results (pool-7sym artefact)
- [[40-research/breach-decision/INDEX|Breach-decision index]] — Map of Content

*Last reviewed: 2026-05-04 — status callout added; see-also section added.*
