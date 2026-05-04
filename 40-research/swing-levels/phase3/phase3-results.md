# Phase 3 results — Layer B (soft-stop delay) — BTCUSDT

_Generated 2026-04-24 20:53:15 UTC_

- Dataset: `research/swing_levels/phase3/features.csv` (2082 rows)
- Features: 18 (per `MVP_FEATURE_COLUMNS` in `phase3_features.py`)
- Splits: GroupKFold(5) on `level_index` + single grouped-forward-split by `level_confirmed_at_utc`
- Models: LogisticRegression (L2, class_weight='balanced') + GradientBoostingClassifier(depth=3, n=100)
- Baselines: majority / prior_rate (train base rate for first-breach rows) / idx_only_logistic

Primary metric: **PR-AUC**. Primary operating point: **τ = 0.5** (fixed).
Secondary diagnostic: F1 at per-fold best-train τ (not the headline).

### safe_delay_15s

- Positive rate (full set): 0.279
- Forward test set size: 347

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.279 ± 0.024 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.721 ± 0.024 | 0.201 ± 0.011 |
| prior_rate | 0.291 ± 0.025 | 0.412 ± 0.032 | 0.270 ± 0.027 | 0.868 ± 0.020 | 0.310 ± 0.025 | 0.572 ± 0.028 |
| idx_only_logistic | 0.313 ± 0.028 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.721 ± 0.024 | 0.200 ± 0.012 |
| logistic | 0.680 ± 0.028 | 0.625 ± 0.042 | 0.574 ± 0.052 | 0.687 ± 0.031 | 0.771 ± 0.022 | 0.165 ± 0.007 |
| gbm | 0.672 ± 0.058 | 0.575 ± 0.029 | 0.689 ± 0.059 | 0.496 ± 0.036 | 0.796 ± 0.017 | 0.144 ± 0.010 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.616 ± 0.045 | 0.473 ± 0.033 |
| gbm | 0.603 ± 0.045 | 0.430 ± 0.024 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.291 | 0.000 | 0.000 | 0.000 | 0.709 | 0.207 |
| prior_rate | 0.323 | 0.429 | 0.287 | 0.851 | 0.340 | 0.543 |
| idx_only_logistic | 0.316 | 0.000 | 0.000 | 0.000 | 0.709 | 0.206 |
| logistic | 0.604 | 0.574 | 0.556 | 0.594 | 0.744 | 0.185 |
| gbm | 0.596 | 0.457 | 0.607 | 0.366 | 0.746 | 0.169 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| breach_magnitude_at_tick_atr | -0.850 | 0.037 | 0 |
| pre_velocity_atr_15s | +0.802 | 0.089 | 0 |
| pre_tick_count_60s | +0.515 | 0.124 | 0 |
| prior_bar_range_atr | +0.371 | 0.093 | 0 |
| seconds_since_previous_breach_log | +0.317 | 0.036 | 0 |
| prior_bar_body_atr | -0.225 | 0.059 | 0 |
| prior_rejection_rate_on_level | -0.210 | 0.020 | 0 |
| pre_velocity_atr_60s | +0.190 | 0.047 | 0 |
| bar_so_far_range_atr | +0.153 | 0.054 | 0 |
| pre_volume_60s | +0.138 | 0.200 | 1 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.276 | 0.039 |
| breach_magnitude_at_tick_atr | 0.186 | 0.013 |
| pre_velocity_atr_60s | 0.150 | 0.037 |
| bar_so_far_range_atr | 0.050 | 0.004 |
| seconds_since_previous_breach_log | 0.047 | 0.003 |
| pre_volume_60s | 0.043 | 0.011 |
| seconds_since_level_confirmed_log | 0.041 | 0.007 |
| pre_tick_count_60s | 0.038 | 0.003 |
| breach_ts_position_in_bar_frac | 0.036 | 0.005 |
| prior_bar_body_atr | 0.033 | 0.006 |


### safe_delay_30s

- Positive rate (full set): 0.368
- Forward test set size: 347

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.368 ± 0.025 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.632 ± 0.025 | 0.233 ± 0.007 |
| prior_rate | 0.375 ± 0.025 | 0.508 ± 0.026 | 0.359 ± 0.026 | 0.872 ± 0.011 | 0.378 ± 0.022 | 0.511 ± 0.019 |
| idx_only_logistic | 0.410 ± 0.032 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.632 ± 0.025 | 0.232 ± 0.008 |
| logistic | 0.708 ± 0.021 | 0.646 ± 0.025 | 0.637 ± 0.030 | 0.655 ± 0.023 | 0.736 ± 0.016 | 0.182 ± 0.005 |
| gbm | 0.688 ± 0.015 | 0.599 ± 0.018 | 0.639 ± 0.016 | 0.563 ± 0.022 | 0.722 ± 0.013 | 0.175 ± 0.009 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.655 ± 0.027 | 0.411 ± 0.035 |
| gbm | 0.626 ± 0.012 | 0.444 ± 0.017 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.360 | 0.000 | 0.000 | 0.000 | 0.640 | 0.231 |
| prior_rate | 0.399 | 0.499 | 0.353 | 0.848 | 0.386 | 0.497 |
| idx_only_logistic | 0.383 | 0.000 | 0.000 | 0.000 | 0.640 | 0.231 |
| logistic | 0.655 | 0.611 | 0.606 | 0.616 | 0.718 | 0.195 |
| gbm | 0.625 | 0.548 | 0.600 | 0.504 | 0.700 | 0.191 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| breach_magnitude_at_tick_atr | -0.743 | 0.051 | 0 |
| pre_velocity_atr_15s | +0.628 | 0.089 | 0 |
| pre_tick_count_60s | +0.570 | 0.133 | 0 |
| prior_bar_range_atr | +0.528 | 0.054 | 0 |
| prior_bar_body_atr | -0.328 | 0.050 | 0 |
| pre_velocity_atr_60s | +0.318 | 0.061 | 0 |
| seconds_since_previous_breach_log | +0.280 | 0.046 | 0 |
| approach_velocity_4bar_atr | +0.175 | 0.032 | 0 |
| prior_rejection_rate_on_level | -0.156 | 0.021 | 0 |
| pre_volume_60s | +0.112 | 0.206 | 2 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.235 | 0.038 |
| pre_velocity_atr_60s | 0.189 | 0.038 |
| breach_magnitude_at_tick_atr | 0.153 | 0.018 |
| pre_volume_60s | 0.054 | 0.024 |
| bar_so_far_range_atr | 0.053 | 0.012 |
| prior_bar_range_atr | 0.053 | 0.004 |
| breach_ts_position_in_bar_frac | 0.045 | 0.004 |
| seconds_since_previous_breach_log | 0.043 | 0.005 |
| seconds_since_level_confirmed_log | 0.037 | 0.007 |
| pre_tick_count_60s | 0.036 | 0.009 |


### safe_delay_60s

- Positive rate (full set): 0.463
- Forward test set size: 347

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.463 ± 0.021 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.537 ± 0.021 | 0.249 ± 0.001 |
| prior_rate | 0.469 ± 0.023 | 0.598 ± 0.016 | 0.454 ± 0.018 | 0.878 ± 0.014 | 0.454 ± 0.016 | 0.444 ± 0.013 |
| idx_only_logistic | 0.505 ± 0.036 | 0.286 ± 0.146 | 0.405 ± 0.206 | 0.225 ± 0.120 | 0.536 ± 0.021 | 0.248 ± 0.003 |
| logistic | 0.754 ± 0.014 | 0.658 ± 0.025 | 0.698 ± 0.022 | 0.622 ± 0.029 | 0.701 ± 0.018 | 0.193 ± 0.005 |
| gbm | 0.739 ± 0.018 | 0.659 ± 0.028 | 0.661 ± 0.022 | 0.658 ± 0.036 | 0.686 ± 0.019 | 0.193 ± 0.008 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.710 ± 0.014 | 0.354 ± 0.017 |
| gbm | 0.682 ± 0.019 | 0.460 ± 0.021 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.470 | 0.000 | 0.000 | 0.000 | 0.530 | 0.249 |
| prior_rate | 0.508 | 0.596 | 0.460 | 0.847 | 0.461 | 0.431 |
| idx_only_logistic | 0.513 | 0.422 | 0.533 | 0.350 | 0.550 | 0.247 |
| logistic | 0.701 | 0.599 | 0.664 | 0.546 | 0.657 | 0.213 |
| gbm | 0.681 | 0.642 | 0.652 | 0.632 | 0.669 | 0.209 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| pre_tick_count_60s | +0.737 | 0.099 | 0 |
| breach_magnitude_at_tick_atr | -0.662 | 0.055 | 0 |
| prior_bar_range_atr | +0.652 | 0.085 | 0 |
| pre_velocity_atr_15s | +0.500 | 0.079 | 0 |
| prior_bar_body_atr | -0.338 | 0.055 | 0 |
| pre_velocity_atr_60s | +0.263 | 0.066 | 0 |
| seconds_since_previous_breach_log | +0.255 | 0.056 | 0 |
| approach_velocity_4bar_atr | +0.205 | 0.030 | 0 |
| prior_rejection_rate_on_level | -0.115 | 0.038 | 0 |
| bar_so_far_range_atr | -0.053 | 0.033 | 0 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_60s | 0.240 | 0.043 |
| pre_velocity_atr_15s | 0.145 | 0.026 |
| breach_magnitude_at_tick_atr | 0.131 | 0.014 |
| prior_bar_range_atr | 0.080 | 0.009 |
| bar_so_far_range_atr | 0.067 | 0.013 |
| pre_tick_count_60s | 0.055 | 0.017 |
| breach_ts_position_in_bar_frac | 0.051 | 0.011 |
| pre_volume_60s | 0.042 | 0.014 |
| seconds_since_level_confirmed_log | 0.040 | 0.005 |
| seconds_since_previous_breach_log | 0.038 | 0.006 |


### safe_delay_180s

- Positive rate (full set): 0.620
- Forward test set size: 347

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.620 ± 0.018 | 0.765 ± 0.014 | 0.620 ± 0.018 | 1.000 ± 0.000 | 0.620 ± 0.018 | 0.236 ± 0.004 |
| prior_rate | 0.625 ± 0.020 | 0.760 ± 0.014 | 0.619 ± 0.017 | 0.984 ± 0.004 | 0.614 ± 0.017 | 0.329 ± 0.010 |
| idx_only_logistic | 0.659 ± 0.046 | 0.755 ± 0.016 | 0.619 ± 0.015 | 0.968 ± 0.031 | 0.611 ± 0.020 | 0.234 ± 0.006 |
| logistic | 0.818 ± 0.019 | 0.680 ± 0.027 | 0.783 ± 0.018 | 0.601 ± 0.033 | 0.650 ± 0.019 | 0.210 ± 0.007 |
| gbm | 0.813 ± 0.017 | 0.773 ± 0.015 | 0.725 ± 0.016 | 0.827 ± 0.024 | 0.699 ± 0.017 | 0.197 ± 0.008 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.783 ± 0.015 | 0.304 ± 0.013 |
| gbm | 0.762 ± 0.024 | 0.540 ± 0.025 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.640 | 0.780 | 0.640 | 1.000 | 0.640 | 0.231 |
| prior_rate | 0.674 | 0.771 | 0.639 | 0.973 | 0.631 | 0.311 |
| idx_only_logistic | 0.671 | 0.780 | 0.640 | 1.000 | 0.640 | 0.228 |
| logistic | 0.807 | 0.649 | 0.801 | 0.545 | 0.622 | 0.222 |
| gbm | 0.812 | 0.777 | 0.728 | 0.833 | 0.695 | 0.196 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| breach_magnitude_at_tick_atr | -0.599 | 0.048 | 0 |
| prior_bar_range_atr | +0.592 | 0.070 | 0 |
| pre_volume_60s | +0.438 | 0.128 | 0 |
| pre_tick_count_60s | +0.428 | 0.099 | 0 |
| prior_bar_body_atr | -0.380 | 0.074 | 0 |
| approach_velocity_4bar_atr | +0.234 | 0.040 | 0 |
| seconds_since_previous_breach_log | +0.228 | 0.033 | 0 |
| pre_velocity_atr_15s | +0.226 | 0.081 | 0 |
| bar_so_far_range_atr | +0.122 | 0.039 | 0 |
| swing_type_high | +0.118 | 0.052 | 0 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.158 | 0.048 |
| prior_bar_range_atr | 0.121 | 0.008 |
| breach_magnitude_at_tick_atr | 0.108 | 0.005 |
| pre_velocity_atr_60s | 0.096 | 0.018 |
| bar_so_far_range_atr | 0.088 | 0.013 |
| pre_tick_count_60s | 0.072 | 0.032 |
| pre_volume_60s | 0.057 | 0.010 |
| approach_velocity_4bar_atr | 0.055 | 0.011 |
| seconds_since_level_confirmed_log | 0.047 | 0.011 |
| breach_ts_position_in_bar_frac | 0.044 | 0.010 |

