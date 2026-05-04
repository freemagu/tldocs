# Phase 1 Closeout — Swing-Level Breach Research

**Date:** 2026-04-22
**Status:** Automated portion complete; manual chart inspection pending before Phase 1 can formally close.

## What was built

A minimum-viable offline research prototype that, given BTCUSDT 15m candles over the approved Phase 1 window, produces:

- a raw list of pivot-based swing levels,
- a filtered kept set,
- a list of breach events with tick-accurate timestamps where tick data is available,
- two parallel episode-based touch counts per event (ATR-relative and ticks-based),
- and a 20-event random sample for manual chart inspection.

New package: `lib/tradelens/swing_research/` (pivots, filters, ATR, breach_detect, touch_count, bar_walk, tick_refine).
Orchestration: `bin/tools/swing_levels_phase1.py`.
Inspection sampler: `bin/tools/swing_levels_phase1_inspect.py`.
Tests: 12 new unit tests covering pivots, filters, touch-count state machine, and breach detection. Full `pytest` suite: 256 passed, 0 failed.

## Dataset summary (frozen for this run)

Approved window: `2025-10-01 00:00:00 UTC` → `2026-03-23 23:59:59 UTC` (Option A).

| Metric | Value |
|---|---|
| Raw pivots (inside window) | 2,077 |
| Dropped by spacing filter | 0 |
| Dropped by magnitude filter | 6 |
| Kept swing levels | 2,071 |
| In-window breach events | 1,983 |
| Events with tick-level refinement | 1,939 (97.8%) |
| Events on tick-gap days (no refinement) | 44 |
| Still-active (unbreached) levels at end | 72 |
| `touch_count_atr` — mode | 0 (51.5%) |

## Validations passed automatically

1. Full `pytest` suite green — including 12 new unit tests directly exercising the Phase 1 primitives.
2. Tick-refinement accuracy cross-checked on event #1: the CSV's `breach_ts_utc` and `breach_price` match the first crossing tick in the archive exactly.
3. Touch-count hand-trace on event #1's real bars matches the state-machine output (1 episode).
4. Candle coverage has zero gaps across the window; tick-gap-day events are explicitly flagged, not silently skipped.

## Validations still pending (user-gated)

1. **Manual chart inspection of 20 sampled events** — `phase1_spot_check.md` is prepared for the reviewer.
2. **Tick-accurate verification on 4 more events** (1 of 5 done automatically).
3. **Visual inspection of at least 10 levels per swing_type** to confirm the pivots look like swings a trader would draw.

Phase 1 cannot be declared complete until these three items are signed off.

## Findings worth carrying into Phase 1.5 / Phase 2

1. **Spacing filter is structurally redundant.** 5L/5R strict inequality mathematically guarantees > 5 bars between consecutive same-type pivots. If we want price-proximity or time-proximity deduplication, the rule must be redefined.
2. **Ticks-based touch count is saturated at zero** with `M = 20 × tick_size`. At BTC price levels the $2 band is too tight to register approaches. This confirms the tracker's suspicion that ATR-relative is the right starting basis. M revision is a Phase 1.5 activity.
3. **`touch_count_atr` distribution is well-spread** — 0 (51.5%), 1 (26%), 2 (10.6%), 3–4 (8.5%), 5–9 (3.1%), 10+ (0.1%). This suggests the definition is actually separating first-touch breaches from multi-touch ones and is a viable signal candidate for Phase 2 (not a Phase 1 claim).
4. **Bar-level OHLC walk is a simplification.** Touch-count state-machine input is a 4-point approximation of each 15m bar (open → low → high → close for up bars; mirrored for down). Using ticks directly for touch count would be more faithful but an order of magnitude more expensive. Defer the decision to Phase 1.5.

## Entry conditions for Phase 2

Before Phase 2 (labelling) starts:

- The three pending manual validations above must be signed off.
- If the chart inspection reveals that the kept levels don't look like swings a trader would recognise, return to Phase 1 and revise the pivot / filter parameters before doing any label work.
- Decide what (if anything) to do about the redundant spacing filter and the undersized ticks-based touch count. Either silently shelve both, or open explicit Phase 1.5 tasks — do not carry ambiguity into Phase 2.
- Labelling design must explicitly separate pre-breach data (feature candidates) from post-breach data (label source). The event rows carry tick and candle window pointers but no loaded data, so this separation is enforceable.

## Things explicitly not done in Phase 1

No features, no labels, no classifier, no simulator, no production wiring, no cross-symbol work, no tick backfill, no 1m fallback. All explicitly deferred in the tracker §14.
