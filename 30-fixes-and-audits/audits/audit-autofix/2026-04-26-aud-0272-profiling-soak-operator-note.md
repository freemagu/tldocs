---
status: operator-note
generated: 2026-04-26
audit-id: AUD-0272
related-commits:
  - f4c40aeb (step E instrumentation shipped)
relates-to:
  - 2026-04-26-batch-report-rolling.md (campaign final report)
  - 2026-04-29 scheduled remote agent (trig_0133UPru5FHiPg61gLQzNZ1m)
---

# AUD-0272 step E — profiling soak setup (operator note)

## TL;DR

Step E (profile instrumentation) shipped in commit `f4c40aeb`. It is **opt-in** via the config flag `market_data.tuning.profile_aud0272`. The committed default is **`false`** so production workloads pay zero overhead. Step A (per-thread PG connections + `database.pool_max: 10 → 20` bump) is gated on profile data confirming that the upsert phase dominates the live loop — soak data is needed before the go/no-go.

## How to enable profiling — three options

The committed `etc/config.yml` is the only source the runner reads (`_load_runner_tuning` at `lib/tradelens/mdsync/runner.py:82`). The config loader only env-overrides `default_risk_usd` and `logging_level` — there is **no env-var hook** for the per-tuning keys today. So three operational options exist:

### Option A — RECOMMENDED if you want zero tracked-file diff

Ship a small code change (separate AUD-style commit, ~10 lines) that adds an env-var override branch in `_load_runner_tuning`:

```python
# Inside _load_runner_tuning, after `tuning = (cfg.get('market_data') or {}).get('tuning') or {}`
env_profile = os.environ.get('TRADELENS_AUD0272_PROFILE')
if env_profile is not None:
    tuning = {**tuning, 'profile_aud0272': env_profile.lower() in ('1', 'true', 'yes')}
```

Then operator workflow becomes:

```bash
export TRADELENS_AUD0272_PROFILE=true
./bin/tl restart pipeline
# … soak …
unset TRADELENS_AUD0272_PROFILE
./bin/tl restart pipeline
```

No `etc/config.yml` edit, no tracked-file diff, no risk of accidental commit. This is the cleanest path long-term.

**Implementation status:** NOT shipped in this note. Author this as a small follow-up commit if/when you want to soak.

### Option B — RECOMMENDED if you want zero code change today

Edit the live `etc/config.yml` to flip the flag to `true`, restart pipeline, soak, then revert:

```bash
# 1. Edit the line `profile_aud0272: false` → `profile_aud0272: true` in tradelens/etc/config.yml
sed -i 's/profile_aud0272: false/profile_aud0272: true/' /app/syb/tradesuite/tradelens/etc/config.yml

# 2. Restart pipeline daemon
./bin/tl restart pipeline

# 3. Wait for soak (recommended ≥ 24h to capture diurnal patterns; ≥ 100 cycles minimum)

# 4. Revert flag
sed -i 's/profile_aud0272: true/profile_aud0272: false/' /app/syb/tradesuite/tradelens/etc/config.yml

# 5. Restart pipeline again
./bin/tl restart pipeline
```

**Caveat:** the working-tree `etc/config.yml` will be modified during the soak window. Do **NOT** stage or commit it. The parallel-session WIP already shows `etc/config.yml` as modified for unrelated mdsync-live-loop-narrowing work — coordinate with that session's owner so you don't accidentally bundle unrelated changes when they eventually commit. If the parallel session commits during your soak, your flip will land alongside theirs unless you are careful.

### Option C — DO NOT USE without explicit reauthorisation

Permanently flip the committed default to `true`. This means production pays the perf_counter overhead forever; AUD-0272 step E was specifically designed as opt-in for this reason. Reject by default.

## Where the profile lines appear

`/app/syb/tradesuite/tradelens/logs/pipeline_daemon.log` (and any rotated archives `pipeline_daemon.log.1`, `.gz`, etc.).

The log line shape per cycle is:

```
AUD-0272-PROFILE cycle=N symbols=42 fetch_total=2.341s upsert_total=0.842s ratio=0.36 candles=1287
```

`ratio = upsert_total / fetch_total`. If ratio > 0.5 in a majority of cycles, the upsert is comparable to or larger than fetch and per-thread connections become valuable. If ratio < 0.5, fetch is the bottleneck (rate-limit-bound at ~5 RPS) and per-thread connections will not help.

## Soak window — recommended duration

- **Minimum**: 100 cycles (~17 minutes at the default 10s `live_loop_interval_seconds`).
- **Recommended**: 24 hours (~8640 cycles) to cover one full diurnal traffic cycle. Bybit volume varies significantly by UTC hour; a 17-minute snapshot can mislead.
- **Conservative**: 3 days, which is what the scheduled agent at `trig_0133UPru5FHiPg61gLQzNZ1m` is set to evaluate against.

## Threshold for proceeding with step A

Use this decision matrix (from the rolling report's plan + the scheduled-agent decision tree):

| Cycle count | Ratio > 0.5 in N% of cycles | Decision |
|---|---|---|
| ≥ 100 | ≥ 50% | **GO**. Ship step A: refactor `lib/tradelens/candle_pg/store_pg.py` `upsert_candles` to acquire a connection per call from the pool; bump `database.pool_max: 10 → 20` in `etc/config.yml`. |
| ≥ 100 | < 50% | **PARK PERMANENTLY**. Upsert is not the bottleneck — fetch is. Update AUD-0272 row to "Investigated; not pursued — fetch-bound, not upsert-bound." |
| < 100 | any | **EXTEND SOAK**. Either the flag never went on, the daemon hasn't been running long, or logs were rotated. Verify with `grep -c AUD-0272-PROFILE /app/syb/tradesuite/tradelens/logs/pipeline_daemon.log*`. |

## Quick analysis commands (for after soak)

```bash
# Cycle count
grep -h 'AUD-0272-PROFILE' /app/syb/tradesuite/tradelens/logs/pipeline_daemon.log* 2>/dev/null | wc -l

# Ratio percentiles
grep -h 'AUD-0272-PROFILE' /app/syb/tradesuite/tradelens/logs/pipeline_daemon.log* 2>/dev/null \
  | grep -oE 'ratio=[0-9.]+' | sed 's/ratio=//' | sort -n \
  | awk 'BEGIN{c=0} {a[c++]=$1} END{print "count="c, "p25="a[int(c*0.25)], "median="a[int(c*0.50)], "p75="a[int(c*0.75)], "p95="a[int(c*0.95)]}'

# % of cycles where ratio > 0.5
grep -h 'AUD-0272-PROFILE' /app/syb/tradesuite/tradelens/logs/pipeline_daemon.log* 2>/dev/null \
  | awk -F'ratio=' 'NF>1 {split($2,a," "); r=a[1]; total++; if (r > 0.5) high++} END {if (total>0) printf "%.1f%% (%d/%d cycles with ratio>0.5)\n", 100*high/total, high, total}'
```

## What this note does NOT do

- Does **not** implement per-thread DB connections (step A is gated on the soak data this note's analysis would produce).
- Does **not** implement Option A's env-var hook (separate small AUD-style commit if you authorise).
- Does **not** flip the flag in any tracked or live file.
