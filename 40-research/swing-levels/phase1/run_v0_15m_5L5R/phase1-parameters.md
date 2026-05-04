# Phase 1 Parameters — BTCUSDT 15m Swing-Level Breach Research

All values below are **provisional starting points for Phase 1 only**. None are finalised design choices. Revisions during execution must be logged in the master tracker Decision log (§10) and reflected here in the same commit.

---

## Dataset window (approved — frozen for Phase 1)

- **Symbol:** BTCUSDT (perp, `market_type='linear'`)
- **Timeframe:** 15m
- **UTC start:** `2025-10-01 00:00:00 UTC`
- **UTC end:**   `2026-03-23 23:59:59 UTC`
- **Duration:**  ~174 days
- **Approval reference:** master tracker §10, decision dated 2026-04-22 (Option A).
- All timestamps stored and compared in UTC.

## Candle source

- **Table:** `market_candle`
- **Filters:** `exchange='bybit'`, `symbol='BTCUSDT'`, `market_type='linear'`, `timeframe='15m'`
- **Coverage within window:** 27,089 bars expected across the full available range; zero gaps verified at task start.
- **ATR basis:** 14-period ATR computed on 15m candles, anchored at the pivot bar.
  - ATR formula: Wilder's smoothing of True Range over the 14 bars ending at the pivot bar.

## Tick source

- **Archive root:** `/db/data01/tick_archive`
- **Path pattern:** `/tick_trade_raw/bybit/BTCUSDT/{YYYY-MM-DD}.parquet`
- **Loader:** reused read-only from `lib/tradelens/breach_analysis/tick_loader.py`.
- **Coverage within Phase 1 window:** 2025-10-01 → 2026-03-23 with documented gap days (see Exclusions section below).

## Pivot detection

- **Rule:** N-left / N-right strict inequality on bar high (swing high) and bar low (swing low).
- **Parameter:** `N = 5` (provisional, first-pass candidate).
- **Confirmation time:** `pivot_bar_open_time + (N+1) × 15m` (i.e. the moment the right-side confirming bar closes).
- **Pivots within the first N bars of the Phase 1 window** (insufficient left context) are excluded; count logged.

## Level filtering (light, provisional)

- **Spacing filter:** drop a same-type swing if another same-type swing exists within **5 bars** of it. Candidate starting value only.
- **Magnitude filter:** drop a swing whose absolute magnitude vs. the prior opposite swing is below **0.3 × ATR(14)** at the pivot bar. Candidate starting value only.
- Dropped levels are retained in the raw artifact with a drop-reason column; the filtered artifact carries the kept set only.

## Breach detection

- A level is **active** from its confirmation time until its first breach (or the end of the Phase 1 window, whichever comes first).
- **Swing high breached:** first 15m bar where `bar.high > level_price`.
- **Swing low breached:** first 15m bar where `bar.low < level_price`.
- **Timestamp refinement:** for each breach bar, scan the tick archive and take the timestamp of the first tick whose price crosses the level.
- **Fallback:** if tick data for the breach bar is unavailable (see exclusions), use the bar's open time and set `tick_refinement_available = false` on the event row. These events will be reviewed during spot-check; per the Decision log, no 1m fallback is introduced in Phase 1.
- **No minimum penetration** required in Phase 1 (any cross counts).

## Event window pointers

- **Tick window:**   `[breach_ts - 60 min, breach_ts + 60 min]` (provisional).
- **Candle window:** `[breach_ts - 24 h,  breach_ts + 24 h]`   (provisional).
- Phase 1 does **NOT** load bulk data from these windows; pointers are stored only, for use by later phases.

## Touch count (episode-based, two parallel definitions)

Both counts are computed and stored on every breach event row. Neither is selected as "the" definition during Phase 1.

### ATR-based — field `touch_count_atr`

- **Proximity band:** `level ± (0.5 × ATR(14) at pivot bar)` (provisional).
- **Exit threshold:** price must retreat by `≥ 0.25 × ATR` from the near edge of the band without breaching (provisional).

### Ticks-based — field `touch_count_ticks`

- **Proximity band:** `level ± (M × tick_size)`.
- **`tick_size`:** `0.1` (BTCUSDT linear on Bybit).
- **`M`:** `20` → band = `2.0` (USD). Used at run time.
  - **Run-time finding:** at BTC prices of $60k–$115k in the window, a $2 band is ≈ 0.002% of price, far too narrow to register plausible approach episodes. 1,956 of 1,983 events produced `touch_count_ticks = 0`. The ticks-based count should be treated as informational only for Phase 1; revision of `M` is deferred to Phase 1.5.
- **Exit threshold:** retreat of `≥ (M/2) × tick_size` = `1.0` (USD).

### Episode definition (shared)

- **Entry:** price enters the proximity band while the level is active.
- **Exit:** price retreats past the exit threshold without breaching.
- Consecutive bars inside the band count as one episode until exit.
- Count only episodes between `confirmed_at` and `breached_at` (exclusive of the breach bar itself).

## Exclusions (documented small exclusions per DoD)

### Tick archive gap days (known at task start)

| UTC date | Notes |
|---|---|
| 2025-10-09 | 2-day gap: archive jumps from 2025-10-08 to 2025-10-11 |
| 2025-10-10 | (part of the above 2-day gap) |
| 2025-10-26 | 1-day gap: archive jumps from 2025-10-26 to 2025-10-27 |

Events whose breach bar falls on one of these dates will have `tick_refinement_available = false` and will be flagged for review in the spot-check step. The count of such events must be logged in `phase1_summary_stats.md`.

### Candle gap exclusions
None expected (zero candle gaps confirmed over the window).

### Levels excluded by insufficient left context
Resolved by the 30-day warmup load: the pipeline pulls candles from 30 days before `window_start` so that pivots formed at the very start of the window still have N=5 bars of left context. No pivots were excluded for insufficient left context at runtime.

### Run-time exclusions

| timestamp_utc | category | detail | action |
|---|---|---|---|
| (none) | — | — | — |

### Tick-gap-day event counts (actual)

- Events with `tick_gap_day=True`: **44** (across 3 gap days listed above).
- Events with `tick_refinement_available=True`: **1,939** (97.8% of 1,983 in-window events).
- Events with tick refinement unavailable despite not being a gap day: **0**.

## Reproducibility

- **Code version:** git commit hash at execution time — to be recorded here on `/t-done` commit.
- **Random seed** for the 20-event spot-check sample: `42` (fixed; used by `swing_levels_phase1_inspect.py`).
- **Artifact output path:** `tradelens/research/swing_levels/phase1/`.
- **Warmup window used:** 30 days before window start, 14 days after window end, to stabilise ATR and allow late-formed levels to resolve. Only pivots with `formed_at ∈ [window_start, window_end]` and events with `breach_bar_open_time ≤ window_end` are retained in artifacts.

## Provisional marker

Every numeric value above is a first-pass candidate. Tuning is a later activity. Any value changed mid-run must be logged in the master tracker Decision log (§10) and this file updated in the same commit.
