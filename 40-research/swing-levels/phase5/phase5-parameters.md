# Phase 5 Parameters — Two-feature combination

All values are **provisional first-pass candidates**. Any change during the
run must be logged in tracker §10 and reflected here in the same commit.

## Inputs

- BTC labels: `research/swing_levels/phase2/breach_labels.csv` (191 events)
- BTC features: `research/swing_levels/phase3/breach_features.csv` (191 × 17)
- ETH labels: `research/swing_levels/phase2/ethusdt/breach_labels.csv` (210 events)
- ETH features: `research/swing_levels/phase3/ethusdt/breach_features.csv` (210 × 17)
- Pooled = BTC + ETH row-concatenated (401 events)

## Method

For each training set in {BTCUSDT, ETHUSDT, pooled}:
  1. Rank all 12 always-available features by single-feature F1 against
     SFP (one-vs-rest), reusing the Phase 4 grid.
  2. Take the top-{TOP_K} features.
  3. For every unordered pair (A, B) in the top-K × top-K:
     - Grid-search (direction_a × threshold_a × direction_b × threshold_b)
       × combiner ∈ {AND, OR} for highest F1 on the training set.
  4. Keep the overall best pair rule.
  5. Evaluate the best rule on BTC, ETH, and pooled test sets. Record F1.

## Feature set (12)

Dropped from consideration: `pre_300s_volume`, `pre_300s_delta`,
`pre_300s_delta_norm`, `pre_300s_cvd_slope_per_s`, `pre_60s_tick_count` —
tick features found less stable cross-symbol in Phase 4 and would introduce
null-handling decisions that add complexity without clear upside for the
multi-feature question.

Retained:

- Breach-bar: `breach_bar_body_atr`, `breach_bar_range_atr`,
  `breach_closed_through`, `breach_wick_beyond_atr`, `breach_body_beyond_atr`,
  `breach_bar_up`
- Pre-breach candle context: `pre_60min_range_atr`, `pre_120min_range_atr`,
  `pre_2h_velocity_atr_per_h`
- Level: `level_age_hours`, `touch_count_atr`, `touch_count_ticks`

Booleans (`breach_closed_through`, `breach_bar_up`) are encoded as 0.0 / 1.0
so the pair-rule search handles them uniformly.

## Top-K per training set (actual)

- **BTCUSDT**: `breach_body_beyond_atr`, `breach_wick_beyond_atr`, `breach_closed_through`, `breach_bar_body_atr`, `breach_bar_range_atr`, `touch_count_atr`
- **ETHUSDT**: `breach_body_beyond_atr`, `breach_closed_through`, `breach_bar_body_atr`, `breach_wick_beyond_atr`, `touch_count_atr`, `breach_bar_range_atr`
- **pooled**: `breach_body_beyond_atr`, `breach_closed_through`, `breach_wick_beyond_atr`, `breach_bar_body_atr`, `touch_count_atr`, `breach_bar_range_atr`


## Parameters

| Parameter | Value |
|---|---|
| Grid size per feature (`n_grid`) | 20 |
| Grid spacing | Quantiles of unique non-null values |
| Positive class | SFP |
| Combiners | AND, OR |
| Top-K feature cap | 6 |

## Non-goals (locked)

- No classifier / sklearn / tree library.
- No >2-feature combinations.
- No feature engineering.
- No tick features.
- No hyperparameter tuning beyond the listed grid.
- No PnL / production deployment.
- No SOL / other-symbol work.

## Reproducibility

- Pipeline: `bin/tools/swing_levels_phase5.py`
- Module: `lib/tradelens/swing_research/multi_feature.py`
- Unit tests: `tests/unit/test_swing_multi_feature.py` (3 pure tests)
