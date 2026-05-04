# Phase 3 Parameters — Breach-event feature extraction

All values are **provisional first-pass candidates**. Any change during the run must
be logged in tracker §10 and reflected here in the same commit.

---

## Inputs

- Source events: `research/swing_levels/phase1/breach_events.csv` — 191 events.
- Candle source: `market_candle` with filters `exchange='bybit'`, `symbol='BTCUSDT'`,
  `market_type='linear'`, `timeframe='30m'`.
- Tick source: `/db/data01/tick_archive/tick_trade_raw/bybit/BTCUSDT/{YYYY-MM-DD}.parquet`
  (60-min window before breach, pre-breach portion only).
- ATR anchor: Phase 1 `level_atr_at_pivot` column (ATR(14) at the pivot bar).

## Output

- `breach_features.csv` — 191 rows, 19 columns (event_id, swing_type, 17 feature columns).
- `phase3_summary_stats.md` — per-feature count, null, min, max, mean, median.

## Strict constraint

Every feature is **pre-breach or at-breach**. No post-breach data. Tick loading is
clamped to `[breach_ts − 60min, breach_ts)`; ticks at or after `breach_ts` are excluded.

## Feature groups

### 1. Breach-bar features (6) — from the 30m breach bar only

| Field | Formula | Notes |
|---|---|---|
| `breach_bar_body_atr` | `\|close − open\| / ATR` | non-negative |
| `breach_bar_range_atr` | `(high − low) / ATR` | non-negative |
| `breach_closed_through` | high: `close > level`; low: `close < level` | **strict inequality** — matches Phase 1 breach detection |
| `breach_wick_beyond_atr` | high: `(high − level) / ATR`; low: `(level − low) / ATR` | always ≥ 0 on a breach bar |
| `breach_body_beyond_atr` | high: `(max(open,close) − level) / ATR`; low: `(level − min(open,close)) / ATR` | negative if body stayed inside despite wick |
| `breach_bar_up` | `close > open` | direction of the bar, independent of swing_type |

### 2. Pre-breach candle context (3) — from the 4 bars before the breach bar

| Field | Formula | Notes |
|---|---|---|
| `pre_60min_range_atr` | `(max(high) − min(low)) / ATR` over last 2 bars | compression over the most recent hour |
| `pre_120min_range_atr` | same, over all 4 bars | compression over the last 2 hours |
| `pre_2h_velocity_atr_per_h` | `(breach_bar.open − pre_bars[0].open) / ATR / 2` | signed approach speed per hour |

### 3. Pre-breach tick features (5) — `[breach_ts − 300s, breach_ts)` unless noted

Null for events where `tick_refinement_available=False` (6 / 191 events on gap days).

| Field | Formula | Notes |
|---|---|---|
| `pre_300s_volume` | `sum(size)` over 300s window | raw (not ATR-normalised — scale is contract-dependent) |
| `pre_300s_delta` | `buy_volume − sell_volume` over 300s window | raw |
| `pre_300s_delta_norm` | `delta / total` | range −1..+1, 3 dp |
| `pre_300s_cvd_slope_per_s` | `(final_cvd − initial_cvd) / (last_ts − first_ts)` | linear-endpoint slope, 3 dp |
| `pre_60s_tick_count` | count of ticks in `[breach_ts − 60s, breach_ts)` | integer, intensity signal |

### 4. Level features (3) — carried or derived from Phase 1

| Field | Source | Notes |
|---|---|---|
| `level_age_hours` | `(breach_ts − confirmed_at) / 3600` | how long the level was active |
| `touch_count_atr` | Phase 1 event row | episode-based (ATR proximity band) |
| `touch_count_ticks` | Phase 1 event row | known saturated at 0 (v1 finding) |

## Parameters (first-pass candidates)

| Parameter | Value |
|---|---|
| Bar duration | 30 min |
| Pre-breach candle bars (`N_PRE_BARS`) | **4** (spans 2 h) |
| Pre-breach tick window load | 60 min (last 5 min used) |
| Tick-feature 300s window | 5 min |
| Tick-feature 60s window | 60 s |
| Closed-through comparison | strict inequality (matches breach detection) |
| Delta norm precision | 3 dp |
| Slope precision | 3 dp |

## Non-goals (explicit)

- No post-breach features.
- No feature tuning or selection.
- No normalisation beyond per-feature ATR scaling where stated.
- No classifier / scoring / modelling.
- No feature-vs-label separation analysis (that's Phase 4).
- No cross-symbol work.
- No basis / OI / liquidations / funding.

## Reproducibility

- Pipeline: `bin/tools/swing_levels_phase3.py`
- Labeller: `lib/tradelens/swing_research/features.py`
- Unit tests: `tests/unit/test_swing_features.py` (5 pure tests, all green)
- Tick refinement source: same archive as Phase 1 (same gap days apply: 2025-10-09, 2025-10-10, 2025-10-26).

## Provisional marker

Every numeric parameter above is a first-pass candidate. Selection, transforms, and
additional features are Phase 3.5 / Phase 4 work — out of scope here.
