# Phase 1 Handoff — Next Claude Session

**Purpose:** paste the block below into a fresh Claude Code session to continue Phase 1 with the tuned pivot rule. Assumes no prior session memory.

---

We're continuing Phase 1 of the Swing Level Breach Research branch for
LevelMind / LevelGuard. Context:

  - Tracker:       tradelens/research/swing_levels/TRACKER.md
  - Phase 1 spec:  tradelens/research/swing_levels/phase1/phase1_parameters.md
  - Pipeline:      tradelens/bin/tools/swing_levels_phase1.py
  - Python pkg:    tradelens/lib/tradelens/swing_research/
  - Unit tests:    tradelens/tests/unit/test_swing_{pivots,filters,touch_count,breach_detect}.py
  - Current task:  see `claude-task status` (active task for Phase 1)

## CONTEXT SINCE LAST HANDOFF

Phase 1 originally ran with 15m candles, 5L/5R pivots, and a
spacing+magnitude filter stack. That run produced 1,983 events. Spot-check
of event #117 (swing low at 111386.0 on 2025-10-11 16:30 UTC) showed it
was a micro-pivot — mathematically a valid 5L/5R local minimum, but only
$6 deeper than the adjacent bar. Not a "swing a trader would draw".

I (the user) spent a session iterating on a TradingView Pine Script to
visually tune a better pivot rule. That Pine script lives at:

  tradelens/research/swing_levels/swing_pivots.pine

After multiple iterations, I settled on these DEFAULTS:

  Timeframe:       30m   (was 15m)
  leftBars:        50    strict >  (was 5)
  rightBars:       10    strict >  (was 5)
  ATR period:      14
  Donchian period: 21
  Prominence:      1.5 × ATR   (vs Donchian-21 mid)
  Buffer filter:   REMOVED (was my addition, rejected legitimate peaks)
  Spacing filter:  REMOVED (structurally redundant — strict N-right
                            already guarantees spacing > N bars)
  Magnitude filter: REMOVED (superseded by prominence)

## PIVOT RULE (final)

A bar at offset `rightBars` is a pivot HIGH iff:
  1. bar.high is strictly greater than every high in the prior `leftBars` bars
  2. bar.high is strictly greater than every high in the next `rightBars` bars
  3. bar.high >= donchMid(21) + promK × ATR(14)    (prominence)
      where donchMid and ATR are evaluated AT the pivot bar.

Mirror for pivot LOW (strictly lower, and low <= donchMid - promK × ATR).

No other filters.

## WHAT I NEED YOU TO DO

1. **Update tracker §10 (Decision log)** with these decisions — dated today:
   - Moved from 15m to 30m on visual-tuning evidence.
   - Pivot rule: asymmetric 50L/10R strict.
   - Removed spacing filter (redundant finding confirmed — dropped 0 in
     the v0 run).
   - Removed magnitude filter (superseded by prominence).
   - Removed the right-side buffer filter I had proposed (reason: it
     rejected legitimate peaks whose second-highest right bar happened
     to be within bufferK × ATR of the peak; the filter gets stricter
     as rightBars grows, which is a pathology).
   - Added prominence filter: pivot ≥ Donchian(21)_mid + 1.5 × ATR(14)
     at the pivot bar (symmetric for lows).

2. **Update tracker §11 (Findings)** with the concrete evidence:
   - Event 117 micro-pivot triggered the reconsideration.
   - Peaks 2026-03-23 14:00 (71788) and 2026-03-25 11:30 (71984.8)
     were confirmed detectable by ta.pivothigh but rejected by the
     buffer filter (BUF gaps 158 and 54.8, required ~100-150 at
     ATR ≈ 400-600).
   - Visual tuning done via TradingView using Pine Script
     (tradelens/research/swing_levels/swing_pivots.pine) for iterative
     parameter inspection.

3. **Update `phase1_parameters.md`:**
   - Change timeframe to 30m.
   - Replace spacing/magnitude filter section with the prominence filter
     spec (Donchian(21) mid, promK=1.5, ATR(14) at pivot bar).
   - Update pivot N_LEFT/N_RIGHT to 50/10.
   - Keep the Phase 1 window the same (2025-10-01 → 2026-03-23 UTC).
   - Keep both touch-count definitions (ATR and ticks) as-is.
   - Mark all new numeric values as provisional — this is still Phase 1.

4. **Code changes:**
   - `lib/tradelens/swing_research/pivots.py`: no change needed (already
     parameterised on n_left/n_right).
   - `lib/tradelens/swing_research/atr.py`: keep.
   - `lib/tradelens/swing_research/filters.py`: replace `apply_light_filters`
     with a prominence-based filter. Inputs: pivots, atr_by_index,
     donch_mid_by_index, prom_k. Output: FilterDecision list as before
     but with drop_reason='prominence'.
   - `lib/tradelens/swing_research/breach_detect.py`: no change.
   - `lib/tradelens/swing_research/touch_count.py`: no change.
   - `lib/tradelens/swing_research/tick_refine.py`: no change.
   - `bin/tools/swing_levels_phase1.py`:
       * Change TIMEFRAME from '15m' to '30m' in the load query.
       * Change TIMEFRAME_SECONDS from 900 to 1800.
       * Change N_LEFT from 5 to 50.
       * Change N_RIGHT from 5 to 10.
       * Add donchian_mid computation (ta-equivalent: 21-bar rolling
         (max_high + min_low) / 2, anchored at pivot bar).
       * Replace filter stack with the new prominence filter.
       * Remove spacing and magnitude filter params.
       * Add PROM_K = Decimal("1.5"), DONCH_PERIOD = 21.
       * NOTE: the buffer filter should be GONE; do not resurrect it.
       * Warmup window will need adjusting: donchian_21 on 30m needs
         10.5h of history; pivot_50 needs 25h; ATR(14) needs a few
         hours. The existing 30-day warmup buffer is more than enough.

5. **Tests:**
   - Update `tests/unit/test_swing_filters.py`: drop the spacing and
     magnitude test cases; add prominence tests:
       * A pivot that sits inside the Donchian band (|pivot - mid| <
         promK × ATR) → dropped with reason='prominence'.
       * A pivot whose magnitude clears the band → kept.
       * Mirror for highs and lows.
   - Existing pivot / breach_detect / touch_count tests stay as-is.
   - Run the full pytest suite; must be green with 0 regressions.

6. **Archive v0 run, then re-run:**
   - Move current `tradelens/research/swing_levels/phase1/*.csv` and
     `*.md` into `tradelens/research/swing_levels/phase1/run_v0_15m_5L5R/`
     (preserve everything — do NOT delete). Exception: keep
     `phase1_closeout.md` at the top level as historical context; copy
     rather than move if easier.
   - Run the updated `bin/tools/swing_levels_phase1.py`.
   - Generate new `levels_raw.csv`, `levels_filtered.csv`,
     `breach_events.csv`, `phase1_summary_stats.md`.
   - Regenerate the 20-event spot-check sample via
     `bin/tools/swing_levels_phase1_inspect.py` (seed=42).
   - Write a short run_v1 note summarising the new event count and the
     shift in dataset characteristics vs v0 (1,983 events).

7. **IMPORTANT behaviour constraints:**
   - Do NOT commit anything. The current task stays active. User will
     validate and /t-done when ready.
   - Do NOT widen scope (no features, labels, classifier, simulator,
     production wiring).
   - Do NOT silently harden any provisional parameter.
   - Before writing production code, invoke /test-plan.
   - All ATR-based defaults are still first-pass candidates; note this
     in commit-ready language in the tracker.
   - Stop and report if the new event count is wildly out of the
     expected range (say <100 or >10,000).

## BACKGROUND — WHY THIS CHANGE

The 15m / 5L/5R rule produced too many micro-pivots that didn't match
trader chart-reading intuition (event 117 was the canonical failure).
Filter stacks tried earlier (spacing, magnitude, and a right-side buffer)
either did nothing (spacing was redundant) or over-rejected legitimate
peaks (buffer). The Donchian-mid-based prominence filter, combined with
strict 50L/10R pivots on 30m, produced visually convincing swing levels
on BTCUSDT during iterative testing in TradingView. The Pine Script
`tradelens/research/swing_levels/swing_pivots.pine` is the reference
implementation of the tuned rule — mirror its logic exactly in the
Python pipeline.
