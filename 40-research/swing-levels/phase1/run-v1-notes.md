# Phase 1 — Run v1 Notes

**Date:** 2026-04-22
**Trigger:** v0 spot-check surfaced event 117 (swing low at 111386.0, 2025-10-11 16:30 UTC) as a micro-pivot — a valid 5L/5R 15m local minimum by only $6 margin, not a swing a trader would draw.
**Response:** iterative Pine-Script visual tuning in TradingView produced a new rule set; v1 mirrors it exactly.

## What changed from v0

| | v0 (15m, 5L/5R) | v1 (30m, 50L/10R, Donchian prominence) |
|---|---|---|
| Timeframe | 15m | **30m** |
| Pivot rule | 5L/5R strict | **50L/10R strict** |
| Spacing filter | 5 bars same-type | **removed** (structurally redundant — v0 dropped 0 pivots) |
| Magnitude filter | 0.3 × ATR vs prior opp swing | **removed** (superseded by prominence) |
| Right-side buffer filter | not used | **not used** (rejected legitimate peaks during tuning; pathological scaling with rightBars) |
| New: prominence filter | n/a | **\|price − donchMid(21)\| ≥ 1.5 × ATR(14), all at pivot bar** |
| Pine reference | n/a | `research/swing_levels/swing_pivots.pine` |

## Dataset deltas

| | v0 | v1 |
|---|---|---|
| Candles loaded (warmup+window+tail) | 20,928 (15m) | 10,464 (30m) |
| Raw pivots in window | 2,077 | 212 |
| Kept after filters | 2,071 | 210 |
| In-window breach events | **1,983** | **191** |
| Tick-refinement rate | 97.8 % | 96.9 % |
| Tick-gap-day events | 44 | 6 |
| Unbreached at window end | 72 | 15 |
| Runtime | 12m7s | 2m14s |

Smaller dataset by 10×, faster pipeline by 5×. The density drop is the design intent — filter the micro-pivots that polluted v0.

## Where v0 artifacts live

Archived at `phase1/run_v0_15m_5L5R/` (CSVs, summary stats, spot-check, closeout, and the v0 parameters file preserved). Do not delete — needed for Phase 1.5 comparison work.

## Touch-count distribution shifts (interpret-only)

- **`touch_count_atr`** stays well-spread: 104 / 53 / 16 / 14 / 4 / 0 across the same buckets. Proportions shift toward higher-touch events (deeper levels in structural bottoms/tops get more approaches before breach) — expected given the stricter pivot rule.
- **`touch_count_ticks`** remains saturated at 0 (189 / 191). Known finding from v0 carried forward; ticks-based M value is under-sized for BTC prices. Phase 1.5 tuning task.

## Validation still pending (user-gated)

1. Manual chart inspection of the 20 v1 sampled events (`phase1_spot_check.md`).
2. Tick-accuracy verification on at least 5 events (1 auto-verified from the run, 4 manual).
3. If the v1 spot-check passes ≥ 18/20, Phase 1 can close. If < 18/20, the rule needs another revision.

## Provisional markers (unchanged policy)

All new parameters (N_LEFT=50, N_RIGHT=10, PROM_K=1.5, DONCH_PERIOD=21) are first-pass candidates. They were picked by visual inspection in TradingView, not tuned to a measurable objective. Tuning is a Phase 1.5 task, not Phase 1.

## Code references

- Pipeline: `bin/tools/swing_levels_phase1.py`
- Pivot rule: `lib/tradelens/swing_research/pivots.py` (unchanged — parameterised)
- Prominence filter: `lib/tradelens/swing_research/filters.py` (rewritten)
- Donchian mid: `lib/tradelens/swing_research/donchian.py` (new)
- Tests: `tests/unit/test_swing_pivots.py`, `test_swing_filters.py`, `test_swing_donchian.py`, `test_swing_touch_count.py`, `test_swing_breach_detect.py` — 15 tests total, full suite green (275 passed).
