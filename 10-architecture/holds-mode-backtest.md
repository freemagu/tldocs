# Holds-mode Gate Backtest (Plan 5 / B8 Phase 1)

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

> [!warning] Status: Phase 1 complete; Phase 2 not started
> Phase 1 backtest results are documented below. Phase 2 (actual gate implementation
> in LevelMindCore) has not been started. It is gated on the Phase 1 evidence being
> judged strong enough to justify the engineering.

The B8 holds-mode gate is the planned counterpart to B7's fails-mode
gate. The strategy is:

> **Only fire a limit order if the level holds. If the level fails,
> defer — deferring yields a better fill price.**

For a buy limit (DCA buy, or TP buy on short close), "level fails"
means price extended below the limit, so deferring lets us enter at
a lower (better) price. For a sell limit (DCA sell, or TP sell on
long close), "level fails" means price extended above the limit, so
deferring lets us exit at a higher (better) price. The geometry is
identical for both leg types — only the side flips the adverse
direction.

This document captures the **Phase 1 backtest** of that strategy
against historical filled limit DCAs and TPs. Phase 2 (the actual
gate implementation) is gated on whether the backtest evidence is
strong enough to justify it.

Refer to the [[breach-decision-glossary]] for terminology (Breach, Held, Failed, Sustained, Rejected).

## Method

For each filled limit DCA or TP in `order_leg_hist`:

1. Take the limit price and fill timestamp.
2. Pull the post-fill price stream from one of two sources
   (``--source`` flag):
   - **`candles`** (default): 1 m OHLC from `market_candle` over
     the eval window.
   - **`ticks`**: sub-second prints from the parquet archive at
     `/db/data01/tick_archive/` via `TickLoader`. Captures the
     actual deepest / highest print rather than minute-aggregated
     extremes. Inconclusive when the archive doesn't cover the
     symbol/date.
3. Find the adverse-side extreme:
   - For ``side='buy'``: the lowest price across the window.
   - For ``side='sell'``: the highest price.
4. Classify:
   - **Held**: the adverse extreme stayed within
     ``held_tolerance_pct`` of the limit (default 0.20% = 20 bps).
   - **Failed**: the adverse extreme breached the tolerance.
   - **Inconclusive**: no observations in the window.
5. Record the adverse extension percentage (signed, so we can study
   the distribution of foregone-better-price).

The classification logic is in
``lib/tradelens/breach_decision/holds_backtest/level_outcome.py``
(both ``classify_level_outcome`` for candles and
``classify_level_outcome_from_ticks`` for ticks share a private
extreme-based core) and is fully unit-tested. The CLI is
``bin/holds-mode-backtest`` (wraps
``bin/show/show_holds_mode_backtest.py``).

## Phase 1 results — 2026-04-28 / 2026-04-29 runs

Input: 266 filled limit legs (109 DCAs + 157 TPs) across many
symbols, fills from 2025-10-12 to 2026-04-27.

### Source comparison — candles vs ticks (30 m / 0.20% tolerance)

| Source | Held | Failed | Inconclusive | Failed % of classified | Mean adverse % | Max adverse % |
|--------|------|--------|--------------|------------------------|----------------|---------------|
| candles (1m OHLC) | 79 | 187 | 0 | 70.3% | 1.32% | 7.36% |
| ticks (parquet) | 57 | 174 | 35 | 75.3% | 1.25% | 10.47% |

Tick-source numbers are the more accurate read: ticks see the
literal deepest / highest print in the window, while 1 m OHLC
smooths over the second-by-second wick that often defines whether
a level held. The 35 inconclusive ticks-source legs are fills the
parquet archive doesn't cover (mostly April 2026 fills past the
current CSV ingest cutoff — see J9 in the
[retraining jobs doc](./breach-decision-retraining-jobs.md)).

### Outcome distribution by tolerance (30-minute eval window, candles)

| Tolerance | Held % | Failed % |
|-----------|--------|----------|
| 0.20% (20 bps) | 29.7% | 70.3% |
| 0.50% (50 bps) | 49.6% | 50.4% |
| 1.00% (100 bps) | 70.7% | 29.3% |

Tolerance choice is the lever: tighter tolerances treat any wick as
a fail; looser tolerances treat genuine extensions as still-held.
At 1% tolerance — a sensible threshold for "the level held in any
meaningful sense" — **29% of fills failed within 30 minutes**.

### By leg type at 1% tolerance / 30 m window

| Leg type | Held | Failed | Held rate |
|----------|------|--------|-----------|
| dca | 87 | 22 | 79.8% |
| tp | 101 | 56 | 64.3% |

DCAs hold more often than TPs, consistent with DCAs being placed
at structural support (more often respected) and TPs being placed
at structural resistance (which gets pierced on momentum runs).

### Adverse extension on failed legs (0.20% tolerance, 30 m window)

187 failed legs (candle source):

| stat | value |
|------|-------|
| mean abs % | 1.32% |
| median abs % | 0.79% |
| p90 abs % | 2.64% |
| p95 abs % | 4.05% |
| max abs % | 7.36% |

The right tail is meaningful: 1 in 20 failed fills extended ~4%
past the limit. The worst case in the dataset extended 7.36% past
a small-cap altcoin DCA.

### Counterfactual return-to-level analysis (ticks source, 4h search window)

Run on 2026-04-29 with `--source ticks --counterfactual` against
the 174 failed legs the tick path classified:

```
returned     118  (67.8% of classified)
not_returned  56  (32.2% of classified)

By leg_type (return rate):
  tp     returned=70  not_returned=33  → 68.0%
  dca    returned=48  not_returned=23  → 67.6%

Time-to-return on returned legs (minutes past adverse extreme):
  n=118  mean=26.5m  median=8.9m  p90=90.4m  max=190.1m

Oracle savings on RETURNED legs (mean adverse extreme): 1.16%
Oracle 'savings' on NOT-RETURNED legs (mean adverse extreme):  1.42%
```

The headline: **on roughly two-thirds of failed legs, price came
back to within 0.10% of the original limit price within 4 hours,
with median time-to-return of 9 minutes**. For these, a holds-mode
gate is essentially free — defer the bad fill, re-fill at L (or
better) shortly after. The 1.16% oracle saving accrues per
returned leg; over the 118 returned legs that's the budget the
gate has to spend.

For the 32% that didn't return, the gate's "saving" comes with the
cost of a missed entry. Whether that's a net positive depends on
how the trader values the missed positions — beyond the scope of
the dataset itself.

Per-leg-type return rates are nearly identical (DCA 68% / TP 68%),
suggesting the level dynamics are similar across leg intent. A
single shared model is plausible for B8.

## Implications for the holds-mode gate

A perfect gate (impossible in practice) that correctly identifies
all level-fails ahead of fill would, on this dataset, defer 29% of
DCAs and 36% of TPs (at 1% tolerance), saving on average ~1.3% per
deferred fill (mean adverse extension at 20 bps tolerance, which is
the closer-to-real scoring window).

A realistic gate with, say, 60% precision and 50% recall on
level-fails would still capture roughly half of the avoidable
adverse extension at the cost of foregoing some good fills (the
deferred-but-actually-held cases). Net EV depends on:

- The classifier's true precision / recall on this label.
- The asymmetry between foregone-fill cost (you might miss the
  trade entirely) and avoided-bad-fill saving.

## Open issues — methodology

1. **Tolerance tuning is unsettled.** 0.20% is too strict for
   high-vol pairs; 1.00% may be too loose for stable pairs. A
   per-symbol ATR-relative tolerance (mirror the fails-mode gate's
   ATR feature pipeline) is the clean answer.
2. **30 m eval window is one choice of many.** Most gates the user
   would actually fire have a decision horizon of seconds to a few
   minutes. A 5 m window shifts the held / failed split materially
   (53% failed at 0.20% tolerance / 5 m).
3. **No counterfactual on deferred fills.** "If we'd deferred the
   X% that failed, what would the eventual fill price have been?"
   That requires walking the candle stream forward to find when /
   if price returned to a deferred-fillable level. Out of scope
   for Phase 1 but a Phase 2 prerequisite.
4. **No sample-size correction per symbol.** WETUSDT (one of the
   worst failures at -7.36%) is a single observation; treating it
   the same as 80 BTCUSDT observations distorts the aggregate.
5. **Dataset covers a single trader's labelled history.** The gate
   is tuned to those level-placement habits. Generalising assumes
   future levels are placed similarly.

## What Phase 2 needs

To justify implementing the holds-mode gate (i.e. shipping code in
``LevelMindCore`` and the orchestrator):

1. A **predictor** of level-fails for limit fills — likely shares
   the feature pipeline with the fails-mode predictor since the
   features describe the level / approach geometry, not the
   trade-plan side.
2. **Calibration** of the predictor against the labels this Phase 1
   pipeline produces (266 events is small but trainable for an LR
   with reasonable regularisation).
3. **Counterfactual evaluation**: walk forward on the deferred
   cases to determine net P&L vs always-fire baseline. This is the
   acceptance gate for Phase 2.
4. **A decision rule**: probability threshold + tolerance choice,
   tuned against the EV curve.

## Open questions — operator policy

- **Do we defer indefinitely or with a time cap?** A DCA that's
  deferred forever becomes a missed entry. A natural mirror of B7's
  ``time_cap`` would force the fill if the level keeps failing
  beyond N minutes — but on what default?
- **Cancel-and-re-place vs cancel-only?** When the gate defers, do
  we replace the limit with a new one further away (further down for
  a buy, further up for a sell), or just cancel and let the operator
  re-place manually?
- **Emergency-override semantics?** B7 has an ATR-based emergency
  threshold beyond which the gate fires regardless of the model.
  The holds-mode equivalent would be: if price extends K × ATR past
  the limit, fire anyway (treat as confirmed fail and stop waiting).

These are deferred until Phase 2 begins.

## See also

- [[breach-decision-glossary]] — terminology
- [[breach-decision-training]] — training pipeline (relevant for Phase 2 predictor)
- [[breach-decision-retraining-jobs]] — J8 (held-rate drift monitoring, now available)
- [[40-research/breach-decision/INDEX|Breach-decision index]] — Map of Content
- B7 fails-mode gate (live): `etc/config.yml` `execute_gate:` block, `lib/tradelens/breach_decision/execute_gate.py`
- Backtest CLI: `bin/holds-mode-backtest`
- Classifier code: `lib/tradelens/breach_decision/holds_backtest/level_outcome.py`

*Last reviewed: 2026-05-04 — status warning added; wiki-links added.*
