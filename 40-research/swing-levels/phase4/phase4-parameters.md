# Phase 4 Parameters — Single-feature separation analysis

All values are **provisional first-pass candidates**. Any change during the run
must be logged in tracker §10 and reflected here in the same commit.

## Inputs

- Phase 2 labels: `research/swing_levels/phase2/breach_labels.csv` — 191 rows.
- Phase 3 features: `research/swing_levels/phase3/breach_features.csv` — 191 rows, 17 features.
- Join: inner on `event_id` (1:1 mapping, 191 rows both sides).

## Outputs

- `feature_separation.csv` — 51 rows (17 features × 3 positive classes) before
  skipping degenerate combinations.
- `feature_separation.md` — per-feature summary stats + per-class cutoffs.
- `top_cutoffs.md` — ranked by F1, top 10, with interpretation anchors.

## Method

For each (feature × positive-class) triple:
  1. Drop null rows for that feature (reported separately).
  2. Grid: `np.linspace(0, 1, 20)` quantiles of unique non-null feature values.
  3. For each grid threshold × direction ∈ {>, <}: compute TP/FP/FN vs. the
     one-vs-rest positive-class indicator, then precision/recall/F1.
  4. Keep the highest-F1 cutoff. Ties broken by first-seen (direction '>' first,
     then ascending threshold).

Boolean features use the same path with `True→1.0`, `False→0.0`.

## Non-goals (explicit)

- No classifier / tree / logistic / any learned model.
- No multi-feature combinations (Phase 5 work).
- No retuning of Phase 2 labels or Phase 3 feature definitions.
- No cross-symbol work.
- No PnL / trade-simulation impact.
- No claims of predictive validity — association only.

## Parameters

| Parameter | Value |
|---|---|
| Grid size (`n_grid`) | 20 |
| Grid spacing | Quantiles of unique non-null values, linear interpolation |
| Directions searched | `>` and `<` |
| Positive classes | `SFP`, `Confirmed`, `Ambiguous` (three one-vs-rest sweeps) |
| Null handling | Excluded from ranking, reported in `null_count` column |
| Tie-breaking | First-seen higher-F1 wins (strict `>` comparison) |

## Class priors (baselines)

- SFP     = 116 / 191 = 0.607
- Confirmed = 60 / 191 = 0.314
- Ambiguous =  15 / 191 = 0.079

Majority-vote baseline F1 on SFP (predict all positive) = 2·0.607·1.0 / 1.607 ≈ 0.755.
Heuristics that don't beat this cleanly aren't interesting, regardless of raw F1.

## Reproducibility

- Pipeline: `bin/tools/swing_levels_phase4.py`
- Analyser: `lib/tradelens/swing_research/separation.py`
- Unit tests: `tests/unit/test_swing_separation.py` (4 pure tests)

## Provisional marker

Every numeric parameter above is a first-pass candidate. Threshold refinement,
multi-feature combinations, and out-of-sample validation are Phase 5+ work —
out of scope here.
