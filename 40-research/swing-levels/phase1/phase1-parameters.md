# Phase 1 Parameters — BTCUSDT 30m Swing-Level Breach Research (run v1)

> **Run v1** supersedes the initial run v0 (15m / 5L·5R / spacing+magnitude filters).
> v0 artifacts preserved at `run_v0_15m_5L5R/`. See `run_v1_notes.md` for the delta and the reason for the switch (event 117 micro-pivot finding).

All values below are **provisional starting points for Phase 1 only**. None are finalised design choices. Revisions during execution must be logged in the master tracker Decision log (§10) and reflected here in the same commit.

---

## Dataset window (approved — frozen for Phase 1)

- **Symbol:** BTCUSDT (perp, `market_type='linear'`)
- **Timeframe:** 30m
- **UTC start:** `2025-10-01 00:00:00 UTC`
- **UTC end:**   `2026-03-23 23:59:59 UTC`
- **Duration:**  ~174 days
- **Approval reference:** master tracker §10, Option A decision (window), and §10 2026-04-22 v1 rework decision (rule).
- All timestamps stored and compared in UTC.

## Candle source

- **Table:** `market_candle`
- **Filters:** `exchange='bybit'`, `symbol='BTCUSDT'`, `market_type='linear'`, `timeframe='30m'`
- **Coverage at run-time (warmup+window+tail, 2025-09-01 → 2026-04-10):** 10,464 bars loaded; no gaps in the Phase 1 window.
- **Reference series (all anchored at the pivot bar):**
  - **ATR(14):** Wilder's smoothed True Range over the 14 bars ending at the pivot bar.
  - **Donchian mid (21):** `(max(high) + min(low)) / 2` over the 21 bars ending at the pivot bar. Mirrors Pine's `(ta.highest(high,21) + ta.lowest(low,21)) / 2`.

## Tick source

- **Archive root:** `/db/data01/tick_archive`
- **Path pattern:** `/tick_trade_raw/bybit/BTCUSDT/{YYYY-MM-DD}.parquet`
- **Loader:** reused read-only from `lib/tradelens/breach_analysis/tick_loader.py`.
- **Coverage within Phase 1 window:** 2025-10-01 → 2026-03-23 with documented gap days (see Exclusions section below).

## Pivot detection

- **Rule:** strict N-left / N-right inequality on bar high (swing high) and bar low (swing low).
- **Parameters (provisional, first-pass candidates):** `N_LEFT = 50`, `N_RIGHT = 10`.
- **Confirmation time:** `pivot_bar_open_time + (N_RIGHT + 1) × 30m` = pivot_open + 5h 30m.
- **Reference implementation:** `research/swing_levels/swing_pivots.pine` (Pine Script used for visual tuning).
- **Python implementation:** `lib/tradelens/swing_research/pivots.py` (parameterised).
- Pivots whose left context extends before the loaded range are skipped (the 30-day warmup buffer makes this effectively unreachable for pivots inside the Phase 1 window).

## Level filtering (prominence only — provisional)

Pivots pass the filter iff their price is at least `PROM_K × ATR(14)` outside the Donchian mid at the pivot bar. Pine rule, distilled:

```
swing high passes iff  price >= donchMid(21)[pivot] + promK × ATR(14)[pivot]
swing low  passes iff  price <= donchMid(21)[pivot] − promK × ATR(14)[pivot]
```

- **`PROM_K`:** `1.5` (provisional, first-pass candidate — picked via visual tuning in TradingView).
- **`DONCH_PERIOD`:** `21` (provisional).
- **`ATR_PERIOD`:** `14` (provisional).
- Pivots with missing reference values (insufficient warmup history for either ATR or Donchian) are rejected. Not expected to occur inside the Phase 1 window given the 30-day warmup.

**Filters explicitly not used in v1:**
- *Spacing filter* — removed. v0 dropped 0 pivots; finding in §11 of tracker: strict N-right inequality already guarantees same-type spacing > N_RIGHT bars.
- *Magnitude filter* — removed. Superseded by the prominence filter, which is a directly-comparable and more defensible criterion.
- *Right-side buffer filter* — tried during tuning, then removed. It rejected legitimate peaks whose second-highest right bar fell within a small ATR fraction of the pivot, and the rule gets stricter as `N_RIGHT` grows, which is a pathology. See tracker §11.

Dropped levels are retained in `levels_raw.csv` with `drop_reason='prominence'`; `levels_filtered.csv` carries the kept set only.

## Breach detection

- A level is **active** from its confirmation time until its first breach (or the end of the Phase 1 window, whichever comes first).
- **Swing high breached:** first 30m bar where `bar.high > level_price`.
- **Swing low breached:** first 30m bar where `bar.low < level_price`.
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
  - **Run-time finding (carried from v0, confirmed in v1):** at BTC prices of $60k–$115k in the window, a $2 band is ≈ 0.002% of price, far too narrow to register plausible approach episodes. v0: 1,956 of 1,983 events at 0. v1: 189 of 191 events at 0. Ticks-based count is informational only for Phase 1; `M` revision is deferred to Phase 1.5.
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

### Tick-gap-day event counts (actual — run v1)

- Events with `tick_gap_day=True`: **6** (across 3 gap days listed above).
- Events with `tick_refinement_available=True`: **185** (96.9% of 191 in-window events).
- Events with tick refinement unavailable despite not being a gap day: **0**.

### v0 counts (archived for reference)

- Events with `tick_gap_day=True`: 44 / 1,983 in-window events.
- Events with `tick_refinement_available=True`: 1,939 (97.8%).

## Reproducibility

- **Code version:** git commit hash at execution time — to be recorded here on `/t-done` commit.
- **Random seed** for the 20-event spot-check sample: `42` (fixed; used by `swing_levels_phase1_inspect.py`).
- **Artifact output path:** `tradelens/research/swing_levels/phase1/`.
- **Warmup window used:** 30 days before window start, 14 days after window end, to stabilise ATR and allow late-formed levels to resolve. Only pivots with `formed_at ∈ [window_start, window_end]` and events with `breach_bar_open_time ≤ window_end` are retained in artifacts.

## Provisional marker

Every numeric value above is a first-pass candidate. Tuning is a later activity. Any value changed mid-run must be logged in the master tracker Decision log (§10) and this file updated in the same commit.
