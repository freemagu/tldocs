# Breach-Decision Research — Map of Content

> This index is the entry point for the breach-decision corpus. It is written for an **external AI researcher** who has not previously seen this codebase, and for any human collaborator picking up the work mid-stream. Start here, then follow wiki-links to the doc you need.

## Orientation (read this first)

The **breach-decision** project exists because TradeLens's [[level-guard|LevelGuard]] system executes trades when a guarded price level is breached. The recurring problem: some breaches are liquidity sweeps that reverse immediately (false breaks / SFPs). When LevelGuard fires on a false break, the position is stopped out unnecessarily and then price recovers. The project's goal is to predict — at the moment of breach — whether the breach will sustain (level failed) or reverse (breach rejected), so LevelGuard can apply a delay gate (B7) before firing.

**System status as of 2026-05-04:**

- **Training pipeline shipped** — end-to-end code exists: label-build → train → calibrate → write artefact → metrics persisted to `artefact.json`.
- **Predictive lift over base rate: weak** — pool model calibrated Brier ≈ 0.26–0.27 across all four targets (realised reclaim within 15/30/60/180 s). Base rate Brier ≈ 0.25 (predict the class prior). The gap is real but narrow.
- **Pool beats per-symbol** — on stability grounds only; 5 of 7 per-symbol calibrators collapsed on small calibration folds. Pool is the more reliable choice, not the more accurate one.
- **Critical methodological caveat** — 6 of 7 symbols had `decided_at_utc` compressed into a ~3-day bulk-ingest window (2026-04-27 → 2026-04-30). The chronological train/test split is effectively random for those symbols. Out-of-sample claims are weak.
- **Feature set is the suspected bottleneck** — adding more rows of the same shape probably will not help. The research hypothesis (see §Open threads) is that new *context* features (level-touch history, regime, proximity-to-next-level, order-flow microstructure) are the higher-leverage move.
- **B7 gate is in shadow mode** — [[breach-decision-stage-1-shadow-mode|shadow-mode runbook]] documents how to run the predictor observation-only. Not yet wired to actual gate decisions.
- **Pool promotion pending** — the 2026-05-04 report recommends promoting pool but notes the caveat above; promotion has not happened yet.

---

## Start here

| Doc | What it is |
|---|---|
| **[[INDEX\|This page]]** | Map of Content — start here |
| [[breach-decision-glossary]] | Single source of truth for all terminology (breach / sustained / rejected / reclaim / SFP / execute modes). Read this before any other doc to avoid terminology confusion. |

---

## System architecture

| Doc | One-line description |
|---|---|
| [[breach-decision-training]] | End-to-end training pipeline: label-build, walk-forward CV, LR fit, isotonic calibration, artefact write, CLI. Status: fully implemented. |
| [[breach-decision-retraining-jobs]] | Operational cadence: when each pipeline stage should run (J1–J9), who acts on the output, thresholds and rationale. |
| [[level-guard]] | LevelGuard state machine — the upstream system that generates breach events. Breach-decision sits inside LevelGuard's breach hot-path. |
| [[order-leg-classification]] | How TradeLens classifies exchange orders into trade legs. Relevant for understanding what types of legs produce breach events. |
| [[b9-reclaim-mode-plan]] | Architecture plan for `execute_when='reclaim'` (B9) — the third execute mode, designed but not implemented. Requires persistent per-level state across breach events. |
| [[holds-mode-backtest]] | Backtest of the `execute_when='holds'` strategy (B8). Phase 1 results: 266 filled limit legs, 29% failed within 30 min at 1% tolerance, 68% of failed legs had price return to level within 4h. Phase 2 (actual gate) not started. |

---

## Operational runbooks

| Doc | One-line description |
|---|---|
| [[breach-decision-stage-1-shadow-mode]] | How to run the breach-decision predictor in shadow mode (observation only, no actual gate decisions). Includes pre-checks, migration instructions, health CLI reference, and SQL snippets. |

---

## Latest findings

| Doc | One-line description |
|---|---|
| [[pool-vs-baseline-2026-05-04]] | Training run results: 7-symbol pool vs per-symbol baselines, metrics for all four delay targets, per-symbol verdicts, and promotion recommendations. **Do not modify this doc — it is a frozen result record.** |

---

## Case studies (LevelGuard real-trade analysis)

The `levelguard-analysis/` folder contains 19 post-trade case studies of real LevelGuard executions, each analysed against the guard's decision trail. These are the empirical ground truth for "how does the system perform in practice."

- [[40-research/levelguard-analysis/README|LevelGuard analysis README]] — scorecard (13/16 non-anomalous executions correct), case table, patterns, improvement proposals.
- [[40-research/levelguard-analysis/ideas|Ideas]] — microstructure feature brainstorm (CVD, OI, depth, liquidation cascade, trade flow) motivated by case findings.

Individual case links are in the [[40-research/levelguard-analysis/README|README]].

---

## Adjacent research — swing-levels arc

The swing-levels research is a parallel research stream investigating whether breaches of *swing-level* pivots (structurally meaningful market levels) can be classified as SFP (false break) or Confirmed (real break) using features available at breach time.

**Why it's relevant:** the swing-level research directly tests the same hypothesis as breach-decision — "can we tell a fake break from a real one before acting" — but on a cleaner, market-structure-native dataset rather than on LevelGuard's stop-level events. The feature findings (particularly the one-latent-factor ceiling at F1 ≈ 0.84) are directly applicable to the breach-decision feature-set discussion.

Start with: [[40-research/swing-levels/tracker|Swing-levels tracker]] — phase status, decision log, and finding log.

Also relevant: [[40-research/swing-levels/review-for-external-llm|External-LLM review]] — a comprehensive write-up of all swing-levels work for independent review. Contains the most detailed discussion of what features are missing and what the forward options are.

---

## External methodology reference

The canonical breach-research methodology guide lives at:

```
~/.claude/commands/breach-research.md
```

This file is outside the Obsidian vault (it is a Claude Code slash-command definition). It cannot be wiki-linked but it exists and is the authoritative reference for how to set up the research environment, run the pipelines, and interpret results. Ask the human operator for a copy if needed.

---

## Current state (facts, not aspirations)

**Data:**
- `breach_event` table: 2858 rows (2840 with tick coverage, 18 without — the 18 are documented permanent Bybit-no-publish cases)
- Source distribution: order_level_walk=1361 (81 symbols), swing_pivot=955 (7 symbols), historical_replay=453 (79 symbols), guarded=89 (30 symbols)
- `breach_decision_log` rows: ~3350 labelled (realised_label_at IS NOT NULL)
- Active model versions in log: `ingest-research-2026-04-30` (~2405 rows), `lr-btcusdt-2026-04-25-v1` (~945 rows)

**Models:**
- Per-symbol models: `data/models/breach_decision/<sym_lower>/<version>/artefact.json`
- Pool model: `data/models/breach_decision/_pool/pool-7sym-2026-05-04/artefact.json`
- The pool model is the only one trained on 2026-05-04 data with persisted metrics.

**Pipeline:**
- Label backfill: `bin/server/breach_decision_label_backfill.py` — running; populates `realised_safe_*` columns.
- Outcome backfill: `bin/server/breach_decision_outcome_backfill.py` — running; populates `guard_execution_outcome`.
- Tick archive: daily cron at 03:00 UTC, data-driven from `breach_event ∪ level_guard`, covers 91+ symbols.
- Training CLI: `bin/breach-decision-train --symbol <S>` or `--pool <S1,S2,...>`.
- Retrain trigger CLI: `bin/breach-decision-retrain-trigger` — checks `min_ok_rows` and `min_age_days` thresholds before recommending a retrain.

**What is NOT implemented:**
- B7 gate actually wired to delay LevelGuard decisions (shadow mode only).
- B8 holds-mode gate (Phase 2 pending; [[holds-mode-backtest|Phase 1 results]] available).
- B9 reclaim mode (designed in [[b9-reclaim-mode-plan]]; not started).
- Auto-promotion of trained models to production.

---

## Open threads / questions for the external researcher

The following are concrete open questions where external perspective would be most valuable:

1. **Feature set bottleneck** — the 14-feature LR model has Brier ≈ 0.26 vs base-rate Brier ≈ 0.25. The working hypothesis is that the feature set (not row count) is the bottleneck. What context features would you add? Candidates in the current system: level-touch history before breach, regime context (distance from N-day high/low), proximity to next active level, order-book imbalance at breach time, funding rate trend.

2. **Prediction target design** — the current targets are `realised_safe_{15,30,60,180}s` booleans (did price reclaim within Xs of breach?). Is "did it reclaim within Xs" the right question, or should we predict: (a) reclaim probability as a function of time (survival model), (b) reclaim magnitude / distribution, (c) the probability of a "sustained" breach within the gate's `max_total_delay_s` budget?

3. **Calibration at small folds** — isotonic regression collapsed for 5 of 7 per-symbol models (n_calib < 50). Would Platt scaling (logistic calibration) or beta calibration handle this more gracefully? Or should we simply enforce a minimum calibration-fold size and refuse to calibrate below it?

4. **Honest out-of-sample evaluation** — 6 of 7 symbols' data was ingested in a ~3-day window, collapsing the chronological split to essentially random. What does a *real* out-of-sample evaluation look like? Options: (a) wait 30+ days for new data before evaluating, (b) use a different holdout strategy (symbol-level instead of time-based), (c) accept the caveat and treat current metrics as "in-sample-ish" placeholders.

5. **Swing-level findings → breach-decision features** — the swing-level research (Phases 1–5) found a one-latent-factor ceiling at F1 ≈ 0.84 for SFP/Confirmed classification using breach-bar features. The breach-decision predictor uses a different set of 14 features (mostly level/ATR features, not breach-bar body/wick features). Is there a direct mapping? Specifically: `breach_body_beyond_atr` (the best swing-research SFP predictor) — can an equivalent be computed for LevelGuard's breach events in real time?

6. **Pool dynamics** — the pool model was trained on BTC+ETH+SOL+HYPE+ZEC+XRP+ASTER. BTCUSDT contributes ~35% of pool rows and likely dominates the learned coefficients. How should we validate that the pool model is actually generalising across symbols rather than learning BTC patterns applied to everyone else?

7. **Relationship between swing-level SFP research and breach-decision** — the swing-level research deliberately used a different level type (pivot-based swing levels) than breach-decision (stop-level/LevelGuard-generated events). Are the findings cross-applicable? Is there a way to leverage the swing-level feature findings (particularly the volume/CVD features that were explicitly *not* tested in swing-levels) directly in the breach-decision pipeline?

---

## Link topology

Every architecture doc and the shadow-mode runbook has a back-link to this index. The swing-levels tracker links here. The levelguard-analysis README links here. All cross-references use Obsidian wiki-links.

*Last reviewed: 2026-05-04 — created as Map of Content for external-AI ingest.*
