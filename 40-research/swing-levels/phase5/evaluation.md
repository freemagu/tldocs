# Phase 5 — Multi-feature evaluation

Did combining two features beat the best single-feature rule? By how much? Does it transfer across symbols?

## F1 matrix — train × test

| train \ test | BTCUSDT | ETHUSDT | pooled |
|---|---|---|---|
| **BTCUSDT** | 0.833* | 0.829 | 0.831 |
| **ETHUSDT** | 0.803 | 0.842* | 0.824 |
| **pooled** | 0.828* | 0.845* | 0.837* |

`*` = in-sample (train ⊇ test) — expect optimistic F1.

## Multi-feature gain over single-feature (in-sample)

| train set | single-feature best | pair-rule F1 | gain |
|---|---|---|---|
| BTCUSDT | 0.830 | 0.833 | **+0.003** |
| ETHUSDT | 0.837 | 0.842 | **+0.005** |
| pooled | 0.835 | 0.837 | **+0.002** |

## Out-of-sample transfer

Rule trained on symbol A, tested on symbol B:

| train | test | rule | F1 | prec | recall |
|---|---|---|---|---|---|
| BTCUSDT | ETHUSDT | `(`breach_body_beyond_atr` < 0.6559) AND (`breach_bar_range_atr` > 0.5780)` | 0.829 | 0.741 | 0.940 |
| ETHUSDT | BTCUSDT | `(`breach_body_beyond_atr` < 0.1344) OR (`breach_bar_body_atr` < 1.7319)` | 0.803 | 0.727 | 0.897 |

## Interpretation anchors

- **Gain > +0.05** → real multi-feature value; worth pursuing to production.
- **Gain +0.01 to +0.04** → modest; suggests a label-noise ceiling around ~0.85.
- **Gain ≈ 0** → one latent factor hypothesis confirmed; single feature captured everything useful.

## Non-goals respected

- No sklearn / tree library.
- No classifier beyond 2-feature AND/OR rule.
- No feature engineering (no ratios, no derived features).
- No hyperparameter tuning beyond pair choice + threshold grid.
- No tick features (dropped for cross-symbol stability).
- No PnL / production deployment claims.
