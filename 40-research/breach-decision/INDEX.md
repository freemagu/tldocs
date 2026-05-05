# Breach-Decision Research — Map of Content

> This index is the entry point for the breach-decision corpus. It is written for an **external AI researcher** who has not previously seen this codebase, and for any human collaborator picking up the work mid-stream. Start here, then follow wiki-links to the doc you need.

## Orientation (read this first)

The **breach-decision** project exists because TradeLens's [[level-guard|LevelGuard]] system executes trades when a guarded price level is breached. The recurring problem: some breaches are liquidity sweeps that reverse immediately (false breaks / SFPs). When LevelGuard fires on a false break, the position is stopped out unnecessarily and then price recovers. The project's goal is to predict — at the moment of breach — whether the breach will sustain (level failed) or reverse (breach rejected), so LevelGuard can apply a delay gate (B7) before firing.

**System status as of 2026-05-04:**

- **Training pipeline shipped** — end-to-end code exists: label-build → train → calibrate → write artefact → metrics persisted to `artefact.json`.
- **Predictive lift over the no-information baseline: weak** — pool model calibrated Brier ≈ 0.26–0.27 across all four targets (realised reclaim within 15/30/60/180 s). The no-information baseline (predict the [[breach-decision-glossary#statistics-terms|breach rejection rate]] as a constant) scores Brier ≈ 0.25. The gap is real but narrow.
- **Pool beats per-symbol** — on stability grounds only; 5 of 7 per-symbol calibrators collapsed on small calibration folds. Pool is the more reliable choice, not the more accurate one.
- **Methodology fix shipped same day (commit `ab4c1910`)** — the chronological split previously sorted rows by `decided_at_utc` (ingest time), which collapsed to ~5 minutes for 6 of 7 symbols, making the split effectively random. The split now sorts by `breach_ts_utc` (real market time of the breach). The 2026-05-04 [[pool-vs-baseline-2026-05-04|pool-vs-baseline metrics]] were computed under the broken split and should be regenerated post-fix before being used to make promotion decisions.
- **Calibrator-collapse guard shipped same day (commit `ab4c1910`)** — trainer now warns at `n_calib < 50` and errors at `n_calib < 20`. Override via `--allow-small-calibration-fold` for diagnostic runs only. Future runs with small per-symbol calibration folds will be flagged before producing broken models, instead of silently emitting them.
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
| [[b9-reclaim-mode-plan]] | Architecture plan for the `execute_when='reclaim'` mode wiring. Decision logic + persistent state already shipped (`level_reclaim_state` table, `reclaim_state.py`, `reclaim_persistence.py`); LevelMindCore wiring is the remaining step. The v1 plan does not include a predictor gate for reclaim — it fires immediately on the second sustained breach. |
| [[holds-mode-backtest]] | Backtest of the `execute_when='holds'` predictor gate (B8). **Holds mode itself is in production** (default for limit orders); the predictor gate that would decide "fire-now vs. defer for a better fill" is what's pending. Phase 1 results: 266 filled limit legs, 29% failed within 30 min at 1% tolerance, 68% of failed legs returned to level within 4h. Phase 2 (gate implementation) not started. |

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

> [!note] Skill freshness — last formal audit predates 2026-05-04
> The 697-line skill has not been audited against today's pipeline changes (chronological-split fix from `decided_at_utc` → `breach_ts_utc`, calibrator-collapse guard with `--allow-small-calibration-fold`, persisted `metrics` block in `artefact.json`, mode-vs-gate distinction). External readers using the skill as a reference should cross-check any methodology claim against the docs in this vault, which were refreshed on 2026-05-04 and are the more current source. A re-audit pass over the skill is queued and tracked under [[#deferred-decisions|Deferred decisions]] below.

---

## Current state (facts, not aspirations)

**Data:**
- `breach_event` table: 2858 rows (2840 with tick coverage, 18 without — the 18 are documented permanent Bybit-no-publish cases)
- Source distribution: order_level_walk=1361 (81 symbols), swing_pivot=955 (7 symbols), historical_replay=453 (79 symbols), guarded=89 (30 symbols)
- `breach_decision_log` rows: ~3350 labelled (realised_label_at IS NOT NULL)
- Active model versions in log: `ingest-research-2026-04-30` (~2405 rows), `lr-btcusdt-2026-04-25-v1` (~945 rows)

**Models:**
- Per-symbol models: `data/models/breach_decision/<sym_lower>/<version>/artefact.json`
- Pool model: `data/models/breach_decision/_pool/pool-7sym-2026-05-04/artefact.json` — trained under the pre-fix split (see methodology caveat above); to use for promotion, re-train under the fixed split first.
- Pre-2026-05-04 artefacts may not have a `metrics` key in their `artefact.json` (the persistence side-fix shipped 2026-05-04). Consumers use `.get('metrics', {})`-style access; no breakage.
- **Currently wired to production** (`etc/config.yml` → `breach_decision.model_version_<sym>`): `lr-btcusdt-2026-04-25-v1`, `lr-ethusdt-2026-04-25-v1`. Today's pool and `*-baseline-2026-05-04` artefacts are research-only; nothing trained on 2026-05-04 has been promoted. Promotion requires (a) re-training under the post-fix split and (b) editing the config + `tl restart level-mind`.

**Pipeline:**
- Label backfill: `bin/server/breach_decision_label_backfill.py` — running; populates `realised_safe_*` columns.
- Outcome backfill: `bin/server/breach_decision_outcome_backfill.py` — running; populates `guard_execution_outcome`.
- Tick archive: daily cron at 03:00 UTC, data-driven from `breach_event ∪ level_guard`, covers 91+ symbols.
- Training CLI: `bin/breach-decision-train --symbol <S>` or `--pool <S1,S2,...>`.
- Retrain trigger CLI: `bin/breach-decision-retrain-trigger` — checks `min_ok_rows` and `min_age_days` thresholds before recommending a retrain.

**What is NOT implemented:**

> Each `B<n>` is a **predictor gate** that decides fire-now vs. defer at the moment of breach. The basic execute-mode wiring (does the worker recognise the mode and trigger an order on the right outcome?) is independent. See [[breach-decision-glossary#execute-modes]] for the full mode/gate matrix.

- **B7 gate** — shadow mode only; not yet wired to actual `fails`-mode gate decisions. (`fails` mode itself is in production.)
- **B8 gate** — Phase 2 not started. [[holds-mode-backtest|Phase 1 results]] available; gate implementation pending. (`holds` mode itself is in production and is the default for limit orders.)
- **B9 wiring** — reclaim-mode infrastructure exists (table, decision engine, persistence wrapper); LevelMindCore wiring is the remaining step. The v1 plan does not include a predictor gate for reclaim.
- Auto-promotion of trained models to production.

---

## Open threads / questions for the external researcher

The following are concrete open questions where external perspective would be most valuable:

1. **Feature set bottleneck** — the 14-feature LR model has Brier ≈ 0.26 vs the [[breach-decision-glossary#statistics-terms|no-information baseline]] Brier ≈ 0.25. The working hypothesis is that the feature set (not row count) is the bottleneck. What context features would you add? Candidates in the current system: level-touch history before breach, regime context (distance from N-day high/low), proximity to next active level, order-book imbalance at breach time, funding rate trend.

2. **Prediction target design** — the current targets are `realised_safe_{15,30,60,180}s` booleans (did price reclaim within Xs of breach?). Is "did it reclaim within Xs" the right question, or should we predict: (a) reclaim probability as a function of time (survival model), (b) reclaim magnitude / distribution, (c) the probability of a "sustained" breach within the gate's `max_total_delay_s` budget?

3. **Calibration at small folds** — isotonic regression collapsed for 5 of 7 per-symbol models (n_calib < 50). Would Platt scaling (logistic calibration) or beta calibration handle this more gracefully? Or should we simply enforce a minimum calibration-fold size and refuse to calibrate below it?

4. **Honest out-of-sample evaluation** — the chronological split now uses `breach_ts_utc` (commit `ab4c1910`), so future training runs are genuinely out-of-sample. The remaining open question: the 2026-05-04 pool-vs-baseline numbers were computed under the broken split and need to be regenerated under the fixed split before any promotion decision. After re-training, is a single time-based holdout sufficient, or should we additionally hold out by symbol (train on 6 symbols, validate on 1) to test cross-symbol generalisation?

5. **Swing-level findings → breach-decision features** — the swing-level research (Phases 1–5) found a one-latent-factor ceiling at F1 ≈ 0.84 for SFP/Confirmed classification using breach-bar features. The breach-decision predictor uses a different set of 14 features (mostly level/ATR features, not breach-bar body/wick features). Is there a direct mapping? Specifically: `breach_body_beyond_atr` (the best swing-research SFP predictor) — can an equivalent be computed for LevelGuard's breach events in real time?

6. **Pool dynamics** — the pool model was trained on BTC+ETH+SOL+HYPE+ZEC+XRP+ASTER. BTCUSDT contributes ~35% of pool rows and likely dominates the learned coefficients. How should we validate that the pool model is actually generalising across symbols rather than learning BTC patterns applied to everyone else?

7. **Relationship between swing-level SFP research and breach-decision** — the swing-level research deliberately used a different level type (pivot-based swing levels) than breach-decision (stop-level/LevelGuard-generated events). Are the findings cross-applicable? Is there a way to leverage the swing-level feature findings (particularly the volume/CVD features that were explicitly *not* tested in swing-levels) directly in the breach-decision pipeline?

---

## Deferred decisions

Decisions that were considered, weighed, and explicitly deferred — recorded so that future sessions don't re-litigate the same ground without new evidence, and so an external reviewer can see what was on the table and why it was set aside.

| Decision | Status | Reason | Re-open trigger |
|---|---|---|---|
| **Widen training pool to 30–50 symbols** | Deferred | Empirical evidence from the 2026-05-04 pool-vs-baseline comparison shows Brier barely moved as row count went from 70 (ASTERUSDT) → 200 (HYPEUSDT) → 598 (BTCUSDT) → 1712 (pool). If features had real signal, more rows would help — they don't, suggesting the feature set is the bottleneck, not the row count. | A feature-engineering experiment shows ≥0.02 Brier improvement on a single symbol at current row counts. That validates the feature carries signal and would justify the row-count multiplication. |
| **Extend tick history backward (BTC/ETH to 2024 / earlier)** | Deferred | Same reason as above. Adding more rows of the same shape probably won't help; new context features (level-touch history, regime, proximity-to-next-level, order-book microstructure) are the higher-leverage move. | Same as above — feature-engineering gain validated first. |
| **Add new synthetic level generators (round-numbers, MAs, prior-day H/L, ORB, VWAP)** | Deferred | Each generator is a few hours of work but increases breach-event diversity in unknown ways. Adding before we understand whether the existing dataset suffices for feature engineering is premature. | After feature engineering establishes a working baseline, add one new generator and measure whether a model trained on the union beats the single-generator baseline. |
| **B9 reclaim-mode LevelMindCore wiring** | Deferred | Infrastructure (table, decision engine, persistence wrapper) is already shipped (~1 day of wiring left). Real production data shows zero levels have been breached twice in opposite directions — the strategy has no observed instances yet. No `execute_when='reclaim'` orders exist. | (a) Trader places a `reclaim`-mode order, OR (b) historical analysis on synthetic datasets finds ≥30 reclaim instances over the past 6 months, OR (c) breach-decision model matures enough that B9 becomes the natural next extension. See [[b9-reclaim-mode-plan]] for the full design. |
| **Promote pool-7sym to production** | Deferred | The 2026-05-04 pool model was trained under the broken `decided_at_utc` chronological split (fixed same-day in `ab4c1910`). The reported metrics are not valid for promotion. Re-training under the post-fix split is required first. | A post-fix re-training run produces metrics that survive a real out-of-sample evaluation (per Open thread #4). |
| **Re-audit `/breach-research` skill against today's changes** | Queued | The 697-line methodology guide hasn't been reviewed against today's pipeline updates (split fix, calibrator guard, persisted metrics, mode-vs-gate distinction). External readers may pick up stale claims. | Next time someone needs to update the skill for any reason, do a full pass simultaneously. Or schedule a one-off audit when no urgent work is in flight. |

---

## Link topology

Every architecture doc and the shadow-mode runbook has a back-link to this index. The swing-levels tracker links here. The levelguard-analysis README links here. All cross-references use Obsidian wiki-links.

*Last reviewed: 2026-05-05 — terminology pass: "base rate"/"base-rate predictor" replaced with domain-specific "breach rejection rate"/"no-information baseline"; cross-references added to the new glossary §Statistics terms section. Earlier 2026-05-04: created as Map of Content for external-AI ingest; refreshed same-day to incorporate fork-child code fixes (commits `ab4c1910`, `749f0f5f`, `786165c5`): chronological-split fix (`breach_ts_utc`), calibrator-collapse guard, additional case-insensitive symbol sites, GLMUSDT decision closed; mode-vs-gate distinction sharpened in the B7/B8/B9 listings; explicit production wiring noted in §Models; skill freshness flag added; Deferred decisions table introduced.*
