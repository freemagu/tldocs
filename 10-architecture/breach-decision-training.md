# Breach-Decision Training Pipeline

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

Plan 4 of the breach-decision tranche. This doc captures the full
retrain-cadence pipeline plan, what is *implemented today*, and what
remains pending. Refer to the [[breach-decision-glossary]] for terminology.

## Context

The breach-decision orchestrator emits one row per breach event into
``breach_decision_log`` containing (a) the 14 features the predictor
saw, (b) the four ``p_safe_delay_*s`` predictions, and (c) a
``status`` of ``ok`` / ``fallback`` / ``skipped`` / ``error``. As of
2026-05-04 the system has ~3350 labelled rows across all model versions.

The current production model artefacts are at:
- Per-symbol: ``data/models/breach_decision/<symbol>/<version>/artefact.json``
- Pool: ``data/models/breach_decision/_pool/pool-7sym-2026-05-04/artefact.json``

Today's results are documented in [[pool-vs-baseline-2026-05-04]].

**Status correction vs earlier versions of this doc:** The pipeline is now end-to-end
implemented. All four pipeline stages (label builder, trainer, calibrator, artefact
writer) plus the CLI are shipped. The training runs on `breach_decision_log` rows with
`realised_label_at IS NOT NULL`. See "What is implemented today" below for current state.

## What "retraining" requires

Retraining is end-to-end:

1. **Data assembly** — pull rows from ``breach_decision_log``, join
   ground-truth labels (did price reclaim within 15 / 30 / 60 / 180 s
   of breach?), and produce a feature/label matrix.
2. **Walk-forward CV** — split chronologically, never randomly.
   Random split leaks future information into training.
3. **Per-target LR fit** — one logistic regression per
   ``p_safe_delay_*s`` head.
4. **Calibration** — fit isotonic regression on a held-out window
   to address overconfidence at the upper tail (the production gate
   already exposes this defect at p>0.95).
5. **Artefact write** — emit a new ``artefact.json`` matching the
   shape consumed by ``BreachDecisionPredictor``.
6. **Operator promotion** — manually update
   ``model_version_<symbol>`` in ``etc/config.yml`` and restart
   ``level-mind`` to engage.

## What is implemented today

### Retrain trigger evaluator

`lib/tradelens/breach_decision/training/trigger.py` (with unit tests
at `tests/unit/test_breach_decision_retrain_trigger.py`).

Pure-logic ``RetrainTrigger`` class. Two thresholds:

- ``min_ok_rows`` (default 500) — enough ok-status rows have
  accumulated since the current model's training cutoff to support
  stable LR coefficients per target.
- ``min_age_days`` (default 7) — enough wall-clock time has elapsed
  to reduce overfitting to recent regime artefacts.

A symbol that meets both criteria gets ``status='retrain'``;
otherwise ``status='wait'`` with a structured ``reason`` so the
operator knows what is missing.

### Operator CLI

`bin/breach-decision-retrain-trigger` (wrapping
`bin/show/show_breach_decision_retrain_trigger.py`).

Discovers configured models, queries ``breach_decision_log``, and
prints a per-symbol verdict:

```
  Symbol     Status   Reason                  OK rows  Age (d)
  BTCUSDT    retrain  thresholds_met             598     7.0
  ETHUSDT    retrain  thresholds_met             327     7.0
```

Run this whenever you want to know "should we retrain". It
short-circuits the rest of the pipeline when the answer is no.

## What is implemented (as of 2026-05-04)

**All four pipeline stages are shipped:**

- **Storage**: `/db/data01/tick_archive/tick_trade_raw/bybit/<SYMBOL>/<YYYY-MM-DD>.parquet`
  — 91+ symbols, running daily refresh via cron at 03:00 UTC (J9, shipped 2026-04-30).
- **Ingestor**: `lib/tradelens/tick_archive/` (`TickIngestor`) reads
  Bybit's daily public CSV dumps and writes the parquet files. Tracked
  in PG via `tick_trade_raw_ingest`.
- **Reader**: `lib/tradelens/breach_analysis/tick_loader.py`
  (`TickLoader` — DuckDB-backed).
- **Active consumer**: `bin/server/breach_decision_label_backfill.py`
  reads pending `breach_decision_log` rows and computes the four
  `realised_safe_*` boolean labels using `TickLoader`. As of 2026-05-04
  there are ~3350 labelled rows.
- **Training CLI** (`bin/breach-decision-train`): per-symbol (`--symbol BTCUSDT`)
  or pooled (`--pool BTCUSDT,ETHUSDT,...`). Pool support landed 2026-05-04.
- **Pool training** writes artefacts to `data/models/breach_decision/_pool/<version>/`;
  per-symbol to `data/models/breach_decision/<sym_lower>/<version>/`.
- **Metrics persistence**: `metrics_per_target` is now persisted into `artefact.json`.
  Previously metrics were printed but not saved.

## What remains open

1. **Promotion to production**: pool model trained 2026-05-04 is not yet in `etc/config.yml`.
   See [[pool-vs-baseline-2026-05-04]] for the promotion recommendation (conditional on
   methodological caveats about the compressed training window).
2. **B7 gate wired to actual delays**: the predictor runs in shadow mode only. See
   [[breach-decision-stage-1-shadow-mode|shadow-mode runbook]]. Stage 2 (actual gate
   decisions) is not started.
3. **Calibration for small folds**: isotonic regression collapsed for 5 of 7 per-symbol
   models. Alternative calibrators (Platt scaling, beta calibration) not yet evaluated.
4. **Optional, future**: live websocket → archive bridge inside `TickSidecar`, eliminating
   the ~1-day lag entirely. Not required for retraining (CSV refresh suffices); only needed
   for same-session retraining, which isn't a current requirement.

## Pipeline modules

``lib/tradelens/breach_decision/training/`` contains:

| Module | Purpose | Status |
|---|---|---|
| ``trigger.py`` | RetrainTrigger evaluator | **Implemented** |
| ``label_builder.py`` | Build feature/label matrix from breach_decision_log | **Implemented** |
| ``trainer.py`` | Walk-forward LR fit per target + isotonic calibration | **Implemented** |
| ``artefact_writer.py`` | Emit JSON in the shape the predictor expects | **Implemented** |
| (CLI) ``bin/breach-decision-train`` | Operator entry point | **Implemented** |

The CLI refuses to train below 200 labelled rows (default; tunable via ``--min-rows``).
As of 2026-05-04 there are ~3350 labelled rows; all four modules are runnable.

Operator workflow (now wired):

```bash
# 1. Should we retrain?
tradelens/bin/breach-decision-retrain-trigger

# 2. If yes — run the pipeline (writes the new artefact dir):
tradelens/bin/breach-decision-train --symbol BTCUSDT \
    --version lr-btcusdt-2026-05-15-v2

# 3. Inspect the printed test-fold metrics. Reject if the new model's
#    log-loss regressed vs the current production model's.

# 4. Promote (manual): update model_version_btcusdt in etc/config.yml,
#    then `tl restart level-mind`.
```

## Current training data status (2026-05-04)

As of 2026-05-04:

- ~3350 labelled rows in `breach_decision_log` (`realised_label_at IS NOT NULL`)
- J9 (daily CSV refresh, `bin/refresh-tick-archive`) is running via cron at 03:00 UTC
- The first real training run (pool + per-symbol baselines) was completed 2026-05-04;
  see [[pool-vs-baseline-2026-05-04]] for results.

**Key caveat on today's training run:** all 1712 pool rows were ingested in a ~3-day window
(2026-04-27 → 2026-04-30). The chronological train/test split is effectively random for 6
of 7 symbols. Treat today's metrics as in-sample-ish approximations, not robust out-of-sample
estimates. A real validation window requires data from at least 30 days of organic breach
events with independent timing.

## Calibration for small folds

The 2026-05-04 training run revealed that isotonic regression calibrators trained on
calibration folds with n_calib < 50 frequently collapsed — producing `log_loss_cal > 5.0`
for several per-symbol baselines. This is expected statistical behaviour, not a code bug.

The pool model (n_calib=256) does not collapse. This is the main operational argument
for pool stability over per-symbol at this data volume.

**Open question:** would Platt scaling (logistic calibration) or beta calibration
handle small folds more gracefully? This is not evaluated yet. See the
[[40-research/breach-decision/INDEX|breach-decision index]] §Open threads for the
full question.

## Open questions

- **Promotion gate**: always manual by policy until the pipeline has a track record.
  See [[breach-decision-retraining-jobs]] J4.
- **Symbol stratification**: pool model with symbol as a feature is the current
  approach. Per-symbol heads are available but have calibration issues at small n.
  Question reopens when the pool model has a longer track record.
- **Schedule**: J1 (retrain-trigger probe) should run daily. With `min_age_days`
  defaulting to 7, a weekly retrain check is sensible. See
  [[breach-decision-retraining-jobs]] for the full job inventory.

## See also

- [[breach-decision-glossary]] — terminology
- [[breach-decision-retraining-jobs]] — job cadence and operational scheduling
- [[pool-vs-baseline-2026-05-04]] — 2026-05-04 training results
- [[40-research/breach-decision/INDEX|Breach-decision index]] — Map of Content
- `lib/tradelens/breach_decision/predictor.py` — predictor implementation
- `bin/breach-decision-health` — production-data health CLI

*Last reviewed: 2026-05-04 — updated for pool training, persisted metrics, and 3350 labelled rows.*
