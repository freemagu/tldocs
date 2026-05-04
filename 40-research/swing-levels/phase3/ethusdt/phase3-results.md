# Phase 3 results — Layer B (soft-stop delay) — ETHUSDT

_Generated 2026-04-24 23:31:56 UTC_

- Dataset: `research/swing_levels/phase3/features.csv` (1968 rows)
- Features: 18 (per `MVP_FEATURE_COLUMNS` in `phase3_features.py`)
- Splits: GroupKFold(5) on `level_index` + single grouped-forward-split by `level_confirmed_at_utc`
- Models: LogisticRegression (L2, class_weight='balanced') + GradientBoostingClassifier(depth=3, n=100)
- Baselines: majority / prior_rate (train base rate for first-breach rows) / idx_only_logistic

Primary metric: **PR-AUC**. Primary operating point: **τ = 0.5** (fixed).
Secondary diagnostic: F1 at per-fold best-train τ (not the headline).

### safe_delay_15s

- Positive rate (full set): 0.312
- Forward test set size: 302

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.313 ± 0.050 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.687 ± 0.050 | 0.216 ± 0.019 |
| prior_rate | 0.339 ± 0.049 | 0.448 ± 0.053 | 0.303 ± 0.048 | 0.874 ± 0.012 | 0.332 ± 0.039 | 0.540 ± 0.036 |
| idx_only_logistic | 0.363 ± 0.058 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.687 ± 0.050 | 0.213 ± 0.018 |
| logistic | 0.711 ± 0.060 | 0.675 ± 0.041 | 0.636 ± 0.048 | 0.721 ± 0.037 | 0.786 ± 0.025 | 0.158 ± 0.011 |
| gbm | 0.690 ± 0.052 | 0.631 ± 0.022 | 0.685 ± 0.038 | 0.586 ± 0.023 | 0.788 ± 0.025 | 0.150 ± 0.014 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.665 ± 0.038 | 0.510 ± 0.039 |
| gbm | 0.644 ± 0.026 | 0.432 ± 0.035 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.341 | 0.000 | 0.000 | 0.000 | 0.659 | 0.226 |
| prior_rate | 0.345 | 0.472 | 0.327 | 0.845 | 0.354 | 0.540 |
| idx_only_logistic | 0.417 | 0.000 | 0.000 | 0.000 | 0.659 | 0.221 |
| logistic | 0.783 | 0.687 | 0.622 | 0.767 | 0.762 | 0.159 |
| gbm | 0.732 | 0.674 | 0.722 | 0.631 | 0.791 | 0.154 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| pre_tick_count_60s | +0.943 | 0.114 | 0 |
| pre_velocity_atr_15s | +0.825 | 0.108 | 0 |
| breach_magnitude_at_tick_atr | -0.819 | 0.038 | 0 |
| pre_volume_60s | -0.669 | 0.180 | 0 |
| bar_so_far_range_atr | +0.365 | 0.065 | 0 |
| pre_velocity_atr_60s | +0.332 | 0.093 | 0 |
| seconds_since_previous_breach_log | +0.276 | 0.082 | 0 |
| prior_bar_range_atr | +0.252 | 0.100 | 0 |
| prior_bar_body_atr | -0.155 | 0.112 | 1 |
| pre_delta_60s | +0.110 | 0.023 | 0 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.231 | 0.056 |
| pre_velocity_atr_60s | 0.213 | 0.064 |
| breach_magnitude_at_tick_atr | 0.142 | 0.009 |
| bar_so_far_range_atr | 0.087 | 0.020 |
| pre_tick_count_60s | 0.080 | 0.006 |
| seconds_since_previous_breach_log | 0.043 | 0.006 |
| pre_volume_60s | 0.035 | 0.007 |
| breach_ts_position_in_bar_frac | 0.030 | 0.005 |
| seconds_since_level_confirmed_log | 0.029 | 0.007 |
| prior_bar_body_atr | 0.023 | 0.007 |


### safe_delay_30s

- Positive rate (full set): 0.402
- Forward test set size: 302

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.402 ± 0.035 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.598 ± 0.035 | 0.241 ± 0.008 |
| prior_rate | 0.430 ± 0.043 | 0.543 ± 0.033 | 0.393 ± 0.036 | 0.880 ± 0.008 | 0.404 ± 0.031 | 0.478 ± 0.030 |
| idx_only_logistic | 0.449 ± 0.045 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.000 ± 0.000 | 0.598 ± 0.035 | 0.238 ± 0.006 |
| logistic | 0.754 ± 0.039 | 0.691 ± 0.039 | 0.703 ± 0.036 | 0.682 ± 0.056 | 0.757 ± 0.019 | 0.173 ± 0.011 |
| gbm | 0.750 ± 0.027 | 0.664 ± 0.023 | 0.686 ± 0.025 | 0.646 ± 0.035 | 0.738 ± 0.028 | 0.171 ± 0.012 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.694 ± 0.022 | 0.402 ± 0.037 |
| gbm | 0.675 ± 0.023 | 0.468 ± 0.029 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.447 | 0.000 | 0.000 | 0.000 | 0.553 | 0.250 |
| prior_rate | 0.447 | 0.574 | 0.432 | 0.852 | 0.434 | 0.470 |
| idx_only_logistic | 0.514 | 0.000 | 0.000 | 0.000 | 0.553 | 0.244 |
| logistic | 0.795 | 0.715 | 0.697 | 0.733 | 0.738 | 0.177 |
| gbm | 0.744 | 0.667 | 0.699 | 0.637 | 0.715 | 0.187 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| pre_tick_count_60s | +0.929 | 0.101 | 0 |
| breach_magnitude_at_tick_atr | -0.757 | 0.041 | 0 |
| pre_velocity_atr_15s | +0.752 | 0.114 | 0 |
| pre_volume_60s | -0.551 | 0.159 | 0 |
| prior_bar_range_atr | +0.349 | 0.061 | 0 |
| bar_so_far_range_atr | +0.324 | 0.051 | 0 |
| seconds_since_previous_breach_log | +0.273 | 0.065 | 0 |
| prior_bar_body_atr | -0.261 | 0.074 | 0 |
| pre_velocity_atr_60s | +0.246 | 0.104 | 0 |
| approach_velocity_4bar_atr | +0.203 | 0.031 | 0 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.219 | 0.050 |
| pre_velocity_atr_60s | 0.156 | 0.066 |
| pre_tick_count_60s | 0.128 | 0.030 |
| breach_magnitude_at_tick_atr | 0.105 | 0.005 |
| bar_so_far_range_atr | 0.102 | 0.023 |
| seconds_since_previous_breach_log | 0.045 | 0.014 |
| approach_velocity_4bar_atr | 0.041 | 0.008 |
| pre_volume_60s | 0.038 | 0.007 |
| seconds_since_level_confirmed_log | 0.035 | 0.012 |
| prior_bar_range_atr | 0.032 | 0.007 |


### safe_delay_60s

- Positive rate (full set): 0.500
- Forward test set size: 302

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.500 ± 0.033 | 0.387 ± 0.316 | 0.286 ± 0.234 | 0.600 ± 0.490 | 0.472 ± 0.017 | 0.251 ± 0.001 |
| prior_rate | 0.532 ± 0.044 | 0.650 ± 0.014 | 0.497 ± 0.029 | 0.948 ± 0.053 | 0.491 ± 0.021 | 0.408 ± 0.022 |
| idx_only_logistic | 0.558 ± 0.030 | 0.602 ± 0.015 | 0.542 ± 0.039 | 0.681 ± 0.033 | 0.551 ± 0.018 | 0.245 ± 0.002 |
| logistic | 0.789 ± 0.036 | 0.691 ± 0.035 | 0.743 ± 0.027 | 0.647 ± 0.050 | 0.713 ± 0.018 | 0.186 ± 0.008 |
| gbm | 0.780 ± 0.030 | 0.720 ± 0.020 | 0.701 ± 0.019 | 0.741 ± 0.028 | 0.713 ± 0.008 | 0.187 ± 0.007 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.745 ± 0.020 | 0.348 ± 0.005 |
| gbm | 0.727 ± 0.021 | 0.468 ± 0.017 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.560 | 0.000 | 0.000 | 0.000 | 0.440 | 0.251 |
| prior_rate | 0.566 | 0.662 | 0.541 | 0.852 | 0.513 | 0.386 |
| idx_only_logistic | 0.641 | 0.702 | 0.594 | 0.858 | 0.593 | 0.242 |
| logistic | 0.838 | 0.757 | 0.788 | 0.728 | 0.738 | 0.179 |
| gbm | 0.820 | 0.759 | 0.744 | 0.775 | 0.725 | 0.180 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| pre_tick_count_60s | +0.992 | 0.122 | 0 |
| breach_magnitude_at_tick_atr | -0.706 | 0.058 | 0 |
| pre_velocity_atr_15s | +0.627 | 0.158 | 0 |
| pre_volume_60s | -0.485 | 0.169 | 0 |
| prior_bar_range_atr | +0.278 | 0.061 | 0 |
| bar_so_far_range_atr | +0.247 | 0.044 | 0 |
| pre_velocity_atr_60s | +0.217 | 0.117 | 0 |
| prior_bar_body_atr | -0.216 | 0.068 | 0 |
| approach_velocity_4bar_atr | +0.143 | 0.020 | 0 |
| seconds_since_level_confirmed_log | +0.132 | 0.059 | 0 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.203 | 0.029 |
| pre_velocity_atr_60s | 0.190 | 0.038 |
| pre_tick_count_60s | 0.115 | 0.032 |
| breach_magnitude_at_tick_atr | 0.091 | 0.010 |
| bar_so_far_range_atr | 0.079 | 0.019 |
| pre_volume_60s | 0.048 | 0.007 |
| prior_bar_range_atr | 0.045 | 0.007 |
| approach_velocity_4bar_atr | 0.042 | 0.008 |
| seconds_since_level_confirmed_log | 0.035 | 0.008 |
| pre_delta_60s | 0.032 | 0.011 |


### safe_delay_180s

- Positive rate (full set): 0.632
- Forward test set size: 302

#### GroupKFold(5) — fold mean ± std

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.632 ± 0.028 | 0.774 ± 0.021 | 0.632 ± 0.028 | 1.000 ± 0.000 | 0.632 ± 0.028 | 0.233 ± 0.007 |
| prior_rate | 0.676 ± 0.034 | 0.770 ± 0.018 | 0.632 ± 0.026 | 0.988 ± 0.011 | 0.628 ± 0.023 | 0.305 ± 0.016 |
| idx_only_logistic | 0.680 ± 0.021 | 0.772 ± 0.021 | 0.653 ± 0.029 | 0.944 ± 0.023 | 0.647 ± 0.028 | 0.227 ± 0.008 |
| logistic | 0.848 ± 0.016 | 0.712 ± 0.030 | 0.823 ± 0.009 | 0.629 ± 0.049 | 0.681 ± 0.014 | 0.197 ± 0.008 |
| gbm | 0.846 ± 0.008 | 0.793 ± 0.022 | 0.746 ± 0.018 | 0.846 ± 0.032 | 0.722 ± 0.019 | 0.183 ± 0.006 |

#### GroupKFold(5) — secondary diagnostic: F1 at best-train-fold τ

| method | F1@τ(train-best) mean ± std | τ mean ± std |
|---|---|---|
| logistic | 0.803 ± 0.015 | 0.284 ± 0.010 |
| gbm | 0.791 ± 0.019 | 0.520 ± 0.024 |

#### Grouped forward split — single partition (time-ordered, no level overlap)

| method | PR-AUC | F1@0.5 | Precision@0.5 | Recall@0.5 | Accuracy@0.5 | Brier |
|---|---|---|---|---|---|---|
| majority | 0.699 | 0.823 | 0.699 | 1.000 | 0.699 | 0.217 |
| prior_rate | 0.710 | 0.818 | 0.697 | 0.991 | 0.692 | 0.276 |
| idx_only_logistic | 0.761 | 0.823 | 0.699 | 1.000 | 0.699 | 0.208 |
| logistic | 0.892 | 0.778 | 0.853 | 0.716 | 0.715 | 0.181 |
| gbm | 0.872 | 0.833 | 0.797 | 0.872 | 0.755 | 0.171 |

#### Feature importance — Logistic (coefficient on standardised features)

| feature | mean | std | sign_flips |
|---|---|---|---|
| breach_magnitude_at_tick_atr | -0.664 | 0.051 | 0 |
| pre_tick_count_60s | +0.660 | 0.168 | 0 |
| pre_velocity_atr_15s | +0.519 | 0.149 | 0 |
| prior_bar_range_atr | +0.471 | 0.056 | 0 |
| pre_volume_60s | +0.413 | 0.077 | 0 |
| prior_bar_body_atr | -0.384 | 0.056 | 0 |
| bar_so_far_range_atr | +0.243 | 0.062 | 0 |
| prior_rejection_rate_on_level | +0.217 | 0.061 | 0 |
| pre_delta_60s | +0.162 | 0.047 | 0 |
| approach_velocity_4bar_atr | +0.145 | 0.036 | 0 |

#### Feature importance — GBM (feature_importances_)

| feature | mean | std |
|---|---|---|
| pre_velocity_atr_15s | 0.182 | 0.029 |
| pre_velocity_atr_60s | 0.165 | 0.026 |
| prior_bar_range_atr | 0.098 | 0.013 |
| pre_tick_count_60s | 0.077 | 0.014 |
| pre_volume_60s | 0.074 | 0.010 |
| breach_magnitude_at_tick_atr | 0.070 | 0.010 |
| approach_velocity_4bar_atr | 0.051 | 0.009 |
| breach_ts_position_in_bar_frac | 0.043 | 0.006 |
| bar_so_far_range_atr | 0.041 | 0.012 |
| seconds_since_level_confirmed_log | 0.034 | 0.005 |

