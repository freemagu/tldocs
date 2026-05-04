# Phase 3 calibration / reliability — BTCUSDT

_Generated 2026-04-24 21:55:25 UTC_

- Dataset: `research/swing_levels/phase3/features.csv` (2082 rows)
- Features: 18 MVP columns
- Splits: GroupKFold(5) on `level_index`; OOF predictions pooled across folds
- Models: LogisticRegression (L2, class_weight='balanced') and GradientBoostingClassifier(depth=3, n=100) — identical configs to the trainer

Reliability is computed from **pooled OOF predictions** (every row is scored exactly once, while in its test fold). Per-fold Brier scores are reported alongside the pooled Brier for cross-reference.

Wording discipline: *observation* statements describe what the tables show; *interpretation* statements propose mechanisms and are marked as such. No causal claims about the market are made.

## safe_delay_15s

### safe_delay_15s — Logistic Regression

- N: 2082
- Positive rate: 0.279
- Mean predicted: 0.428
- Calibration gap (mean_predicted − positive_rate): +0.150
- Brier (pooled OOF): 0.1649
- Brier (per-fold mean ± std): 0.1649 ± 0.0071

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.080, 0.156] | 209 | 0.129 | 0.010 | +0.119 |
| 1 | [0.156, 0.190] | 208 | 0.173 | 0.038 | +0.135 |
| 2 | [0.190, 0.231] | 208 | 0.211 | 0.106 | +0.105 |
| 3 | [0.231, 0.285] | 208 | 0.258 | 0.111 | +0.147 |
| 4 | [0.285, 0.344] | 208 | 0.313 | 0.197 | +0.116 |
| 5 | [0.344, 0.430] | 208 | 0.383 | 0.216 | +0.167 |
| 6 | [0.430, 0.535] | 208 | 0.484 | 0.308 | +0.176 |
| 7 | [0.535, 0.674] | 208 | 0.601 | 0.418 | +0.183 |
| 8 | [0.674, 0.877] | 208 | 0.771 | 0.577 | +0.194 |
| 9 | [0.877, 1.000] | 209 | 0.958 | 0.804 | +0.155 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 17 | 0.094 | 0.000 | +0.094 |
| 1 | [0.1, 0.2) | 442 | 0.157 | 0.029 | +0.128 |
| 2 | [0.2, 0.3) | 424 | 0.245 | 0.125 | +0.120 |
| 3 | [0.3, 0.4) | 304 | 0.344 | 0.207 | +0.137 |
| 4 | [0.4, 0.5) | 199 | 0.450 | 0.256 | +0.193 |
| 5 | [0.5, 0.6) | 175 | 0.546 | 0.411 | +0.135 |
| 6 | [0.6, 0.7) | 128 | 0.646 | 0.414 | +0.232 |
| 7 | [0.7, 0.8) | 107 | 0.742 | 0.523 | +0.219 |
| 8 | [0.8, 0.9) | 101 | 0.849 | 0.663 | +0.185 |
| 9 | [0.9, 1.0] | 185 | 0.968 | 0.822 | +0.146 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.429 | 0.886 | 0.578 | 0.639 | 514 | 685 | 817 | 66 |
| 0.50 | 0.575 | 0.690 | 0.627 | 0.771 | 400 | 296 | 1206 | 180 |
| 0.70 | 0.700 | 0.474 | 0.565 | 0.797 | 275 | 118 | 1384 | 305 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 817 | 685 |
| actual pos | 66 | 514 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1206 | 296 |
| actual pos | 180 | 400 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1384 | 118 |
| actual pos | 305 | 275 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 580 | 0.290 | 0.446 | 0.669 | 0.912 | 0.992 |
| actual negative | 1502 | 0.143 | 0.186 | 0.276 | 0.440 | 0.652 |

### safe_delay_15s — Gradient Boosting

- N: 2082
- Positive rate: 0.279
- Mean predicted: 0.280
- Calibration gap (mean_predicted − positive_rate): +0.001
- Brier (pooled OOF): 0.1438
- Brier (per-fold mean ± std): 0.1438 ± 0.0097

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.011, 0.030] | 209 | 0.021 | 0.010 | +0.012 |
| 1 | [0.030, 0.050] | 208 | 0.039 | 0.034 | +0.005 |
| 2 | [0.050, 0.078] | 208 | 0.063 | 0.067 | -0.005 |
| 3 | [0.078, 0.120] | 208 | 0.098 | 0.149 | -0.051 |
| 4 | [0.120, 0.186] | 208 | 0.150 | 0.202 | -0.052 |
| 5 | [0.186, 0.261] | 208 | 0.223 | 0.240 | -0.017 |
| 6 | [0.261, 0.368] | 208 | 0.312 | 0.327 | -0.015 |
| 7 | [0.368, 0.502] | 208 | 0.431 | 0.380 | +0.051 |
| 8 | [0.502, 0.716] | 208 | 0.601 | 0.572 | +0.029 |
| 9 | [0.716, 0.990] | 209 | 0.858 | 0.804 | +0.055 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 735 | 0.048 | 0.052 | -0.004 |
| 1 | [0.1, 0.2) | 347 | 0.144 | 0.199 | -0.055 |
| 2 | [0.2, 0.3) | 244 | 0.246 | 0.242 | +0.004 |
| 3 | [0.3, 0.4) | 189 | 0.348 | 0.370 | -0.023 |
| 4 | [0.4, 0.5) | 147 | 0.448 | 0.381 | +0.067 |
| 5 | [0.5, 0.6) | 104 | 0.544 | 0.538 | +0.005 |
| 6 | [0.6, 0.7) | 95 | 0.646 | 0.579 | +0.067 |
| 7 | [0.7, 0.8) | 70 | 0.748 | 0.686 | +0.062 |
| 8 | [0.8, 0.9) | 70 | 0.850 | 0.814 | +0.035 |
| 9 | [0.9, 1.0] | 81 | 0.940 | 0.889 | +0.051 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.548 | 0.714 | 0.620 | 0.756 | 414 | 342 | 1160 | 166 |
| 0.50 | 0.686 | 0.497 | 0.576 | 0.796 | 288 | 132 | 1370 | 292 |
| 0.70 | 0.801 | 0.305 | 0.442 | 0.785 | 177 | 44 | 1458 | 403 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1160 | 342 |
| actual pos | 166 | 414 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1370 | 132 |
| actual pos | 292 | 288 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1458 | 44 |
| actual pos | 403 | 177 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 580 | 0.123 | 0.259 | 0.496 | 0.761 | 0.917 |
| actual negative | 1502 | 0.025 | 0.046 | 0.113 | 0.274 | 0.469 |


## safe_delay_30s

### safe_delay_30s — Logistic Regression

- N: 2082
- Positive rate: 0.368
- Mean predicted: 0.465
- Calibration gap (mean_predicted − positive_rate): +0.096
- Brier (pooled OOF): 0.1819
- Brier (per-fold mean ± std): 0.1819 ± 0.0051

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.086, 0.195] | 209 | 0.165 | 0.029 | +0.136 |
| 1 | [0.195, 0.233] | 208 | 0.215 | 0.091 | +0.124 |
| 2 | [0.233, 0.278] | 208 | 0.257 | 0.130 | +0.127 |
| 3 | [0.278, 0.333] | 208 | 0.306 | 0.293 | +0.012 |
| 4 | [0.333, 0.397] | 208 | 0.363 | 0.284 | +0.080 |
| 5 | [0.397, 0.479] | 208 | 0.435 | 0.361 | +0.075 |
| 6 | [0.479, 0.574] | 208 | 0.527 | 0.481 | +0.046 |
| 7 | [0.574, 0.702] | 208 | 0.634 | 0.534 | +0.100 |
| 8 | [0.702, 0.881] | 208 | 0.787 | 0.625 | +0.162 |
| 9 | [0.881, 1.000] | 209 | 0.959 | 0.856 | +0.102 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 1 | 0.087 | 0.000 | +0.087 |
| 1 | [0.1, 0.2) | 232 | 0.169 | 0.030 | +0.138 |
| 2 | [0.2, 0.3) | 479 | 0.248 | 0.138 | +0.110 |
| 3 | [0.3, 0.4) | 342 | 0.348 | 0.298 | +0.050 |
| 4 | [0.4, 0.5) | 239 | 0.447 | 0.372 | +0.075 |
| 5 | [0.5, 0.6) | 218 | 0.549 | 0.518 | +0.031 |
| 6 | [0.6, 0.7) | 153 | 0.649 | 0.529 | +0.120 |
| 7 | [0.7, 0.8) | 123 | 0.749 | 0.610 | +0.139 |
| 8 | [0.8, 0.9) | 102 | 0.847 | 0.627 | +0.220 |
| 9 | [0.9, 1.0] | 193 | 0.964 | 0.881 | +0.084 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.507 | 0.905 | 0.650 | 0.640 | 694 | 676 | 639 | 73 |
| 0.50 | 0.638 | 0.656 | 0.647 | 0.736 | 503 | 286 | 1029 | 264 |
| 0.70 | 0.739 | 0.403 | 0.522 | 0.728 | 309 | 109 | 1206 | 458 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 639 | 676 |
| actual pos | 73 | 694 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1029 | 286 |
| actual pos | 264 | 503 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1206 | 109 |
| actual pos | 458 | 309 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 767 | 0.303 | 0.425 | 0.611 | 0.864 | 0.980 |
| actual negative | 1315 | 0.176 | 0.222 | 0.308 | 0.464 | 0.666 |

### safe_delay_30s — Gradient Boosting

- N: 2082
- Positive rate: 0.368
- Mean predicted: 0.369
- Calibration gap (mean_predicted − positive_rate): +0.001
- Brier (pooled OOF): 0.1753
- Brier (per-fold mean ± std): 0.1753 ± 0.0091

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.006, 0.045] | 209 | 0.030 | 0.010 | +0.021 |
| 1 | [0.045, 0.090] | 208 | 0.067 | 0.072 | -0.005 |
| 2 | [0.090, 0.149] | 208 | 0.118 | 0.130 | -0.012 |
| 3 | [0.149, 0.231] | 208 | 0.185 | 0.255 | -0.070 |
| 4 | [0.231, 0.329] | 208 | 0.279 | 0.370 | -0.091 |
| 5 | [0.329, 0.429] | 208 | 0.379 | 0.404 | -0.025 |
| 6 | [0.429, 0.525] | 208 | 0.474 | 0.462 | +0.013 |
| 7 | [0.525, 0.634] | 208 | 0.578 | 0.553 | +0.025 |
| 8 | [0.634, 0.776] | 208 | 0.694 | 0.596 | +0.098 |
| 9 | [0.776, 0.991] | 209 | 0.883 | 0.833 | +0.050 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 459 | 0.053 | 0.046 | +0.007 |
| 1 | [0.1, 0.2) | 313 | 0.147 | 0.182 | -0.035 |
| 2 | [0.2, 0.3) | 209 | 0.251 | 0.368 | -0.118 |
| 3 | [0.3, 0.4) | 204 | 0.349 | 0.348 | +0.001 |
| 4 | [0.4, 0.5) | 220 | 0.448 | 0.491 | -0.043 |
| 5 | [0.5, 0.6) | 192 | 0.546 | 0.505 | +0.041 |
| 6 | [0.6, 0.7) | 188 | 0.647 | 0.580 | +0.067 |
| 7 | [0.7, 0.8) | 109 | 0.746 | 0.606 | +0.140 |
| 8 | [0.8, 0.9) | 104 | 0.853 | 0.846 | +0.007 |
| 9 | [0.9, 1.0] | 84 | 0.943 | 0.869 | +0.074 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.556 | 0.798 | 0.655 | 0.691 | 612 | 489 | 826 | 155 |
| 0.50 | 0.640 | 0.565 | 0.600 | 0.722 | 433 | 244 | 1071 | 334 |
| 0.70 | 0.764 | 0.296 | 0.427 | 0.707 | 227 | 70 | 1245 | 540 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 826 | 489 |
| actual pos | 155 | 612 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1071 | 244 |
| actual pos | 334 | 433 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1245 | 70 |
| actual pos | 540 | 227 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 767 | 0.198 | 0.352 | 0.546 | 0.751 | 0.896 |
| actual negative | 1315 | 0.035 | 0.074 | 0.178 | 0.423 | 0.619 |


## safe_delay_60s

### safe_delay_60s — Logistic Regression

- N: 2082
- Positive rate: 0.463
- Mean predicted: 0.493
- Calibration gap (mean_predicted − positive_rate): +0.029
- Brier (pooled OOF): 0.1931
- Brier (per-fold mean ± std): 0.1931 ± 0.0052

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.121, 0.224] | 209 | 0.195 | 0.081 | +0.113 |
| 1 | [0.224, 0.267] | 208 | 0.246 | 0.154 | +0.092 |
| 2 | [0.267, 0.314] | 208 | 0.290 | 0.255 | +0.035 |
| 3 | [0.314, 0.369] | 208 | 0.342 | 0.385 | -0.043 |
| 4 | [0.369, 0.438] | 208 | 0.403 | 0.409 | -0.006 |
| 5 | [0.438, 0.513] | 208 | 0.475 | 0.524 | -0.050 |
| 6 | [0.513, 0.604] | 208 | 0.556 | 0.591 | -0.035 |
| 7 | [0.604, 0.731] | 208 | 0.661 | 0.620 | +0.041 |
| 8 | [0.731, 0.890] | 208 | 0.801 | 0.736 | +0.065 |
| 9 | [0.890, 1.000] | 209 | 0.959 | 0.880 | +0.078 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 0 | – | – | – |
| 1 | [0.1, 0.2) | 109 | 0.177 | 0.055 | +0.122 |
| 2 | [0.2, 0.3) | 461 | 0.252 | 0.182 | +0.070 |
| 3 | [0.3, 0.4) | 358 | 0.347 | 0.377 | -0.030 |
| 4 | [0.4, 0.5) | 294 | 0.450 | 0.473 | -0.023 |
| 5 | [0.5, 0.6) | 224 | 0.548 | 0.567 | -0.019 |
| 6 | [0.6, 0.7) | 176 | 0.643 | 0.608 | +0.035 |
| 7 | [0.7, 0.8) | 152 | 0.751 | 0.704 | +0.047 |
| 8 | [0.8, 0.9) | 108 | 0.847 | 0.759 | +0.087 |
| 9 | [0.9, 1.0] | 200 | 0.961 | 0.890 | +0.071 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.579 | 0.907 | 0.706 | 0.651 | 875 | 637 | 480 | 90 |
| 0.50 | 0.699 | 0.623 | 0.659 | 0.701 | 601 | 259 | 858 | 364 |
| 0.70 | 0.798 | 0.380 | 0.515 | 0.668 | 367 | 93 | 1024 | 598 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 480 | 637 |
| actual pos | 90 | 875 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 858 | 259 |
| actual pos | 364 | 601 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1024 | 93 |
| actual pos | 598 | 367 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 965 | 0.305 | 0.412 | 0.590 | 0.824 | 0.964 |
| actual negative | 1117 | 0.205 | 0.245 | 0.327 | 0.491 | 0.670 |

### safe_delay_60s — Gradient Boosting

- N: 2082
- Positive rate: 0.463
- Mean predicted: 0.464
- Calibration gap (mean_predicted − positive_rate): +0.001
- Brier (pooled OOF): 0.1931
- Brier (per-fold mean ± std): 0.1931 ± 0.0078

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.014, 0.086] | 209 | 0.051 | 0.043 | +0.008 |
| 1 | [0.086, 0.176] | 208 | 0.129 | 0.135 | -0.006 |
| 2 | [0.176, 0.275] | 208 | 0.227 | 0.274 | -0.047 |
| 3 | [0.275, 0.378] | 208 | 0.328 | 0.418 | -0.090 |
| 4 | [0.378, 0.475] | 208 | 0.431 | 0.505 | -0.073 |
| 5 | [0.475, 0.551] | 208 | 0.511 | 0.519 | -0.008 |
| 6 | [0.551, 0.644] | 208 | 0.598 | 0.606 | -0.008 |
| 7 | [0.644, 0.724] | 208 | 0.682 | 0.553 | +0.129 |
| 8 | [0.724, 0.833] | 208 | 0.776 | 0.712 | +0.064 |
| 9 | [0.833, 0.989] | 209 | 0.912 | 0.871 | +0.041 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 242 | 0.057 | 0.054 | +0.003 |
| 1 | [0.1, 0.2) | 219 | 0.146 | 0.164 | -0.018 |
| 2 | [0.2, 0.3) | 215 | 0.250 | 0.302 | -0.053 |
| 3 | [0.3, 0.4) | 194 | 0.350 | 0.412 | -0.063 |
| 4 | [0.4, 0.5) | 251 | 0.456 | 0.538 | -0.082 |
| 5 | [0.5, 0.6) | 241 | 0.550 | 0.535 | +0.015 |
| 6 | [0.6, 0.7) | 251 | 0.652 | 0.570 | +0.082 |
| 7 | [0.7, 0.8) | 200 | 0.748 | 0.685 | +0.063 |
| 8 | [0.8, 0.9) | 146 | 0.846 | 0.781 | +0.065 |
| 9 | [0.9, 1.0] | 123 | 0.942 | 0.919 | +0.024 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.605 | 0.882 | 0.718 | 0.679 | 851 | 555 | 562 | 114 |
| 0.50 | 0.662 | 0.659 | 0.660 | 0.686 | 636 | 325 | 792 | 329 |
| 0.70 | 0.776 | 0.377 | 0.508 | 0.661 | 364 | 105 | 1012 | 601 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 562 | 555 |
| actual pos | 114 | 851 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 792 | 325 |
| actual pos | 329 | 636 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1012 | 105 |
| actual pos | 601 | 364 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 965 | 0.278 | 0.446 | 0.615 | 0.786 | 0.913 |
| actual negative | 1117 | 0.056 | 0.122 | 0.298 | 0.538 | 0.697 |


## safe_delay_180s

### safe_delay_180s — Logistic Regression

- N: 2082
- Positive rate: 0.620
- Mean predicted: 0.524
- Calibration gap (mean_predicted − positive_rate): -0.095
- Brier (pooled OOF): 0.2098
- Brier (per-fold mean ± std): 0.2098 ± 0.0070

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.162, 0.278] | 209 | 0.243 | 0.263 | -0.020 |
| 1 | [0.278, 0.320] | 208 | 0.299 | 0.385 | -0.085 |
| 2 | [0.320, 0.367] | 208 | 0.342 | 0.481 | -0.139 |
| 3 | [0.367, 0.420] | 208 | 0.392 | 0.534 | -0.141 |
| 4 | [0.420, 0.482] | 208 | 0.450 | 0.630 | -0.180 |
| 5 | [0.482, 0.549] | 208 | 0.517 | 0.649 | -0.132 |
| 6 | [0.549, 0.624] | 208 | 0.585 | 0.750 | -0.165 |
| 7 | [0.624, 0.727] | 208 | 0.672 | 0.764 | -0.093 |
| 8 | [0.727, 0.874] | 208 | 0.796 | 0.812 | -0.016 |
| 9 | [0.874, 1.000] | 209 | 0.946 | 0.928 | +0.018 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 0 | – | – | – |
| 1 | [0.1, 0.2) | 13 | 0.184 | 0.231 | -0.047 |
| 2 | [0.2, 0.3) | 300 | 0.261 | 0.280 | -0.019 |
| 3 | [0.3, 0.4) | 443 | 0.346 | 0.481 | -0.135 |
| 4 | [0.4, 0.5) | 336 | 0.447 | 0.637 | -0.190 |
| 5 | [0.5, 0.6) | 301 | 0.548 | 0.678 | -0.130 |
| 6 | [0.6, 0.7) | 223 | 0.646 | 0.767 | -0.121 |
| 7 | [0.7, 0.8) | 162 | 0.747 | 0.765 | -0.018 |
| 8 | [0.8, 0.9) | 135 | 0.851 | 0.867 | -0.015 |
| 9 | [0.9, 1.0] | 169 | 0.961 | 0.947 | +0.014 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.680 | 0.933 | 0.787 | 0.686 | 1203 | 566 | 226 | 87 |
| 0.50 | 0.784 | 0.602 | 0.681 | 0.650 | 776 | 214 | 578 | 514 |
| 0.70 | 0.861 | 0.311 | 0.457 | 0.542 | 401 | 65 | 727 | 889 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 226 | 566 |
| actual pos | 87 | 1203 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 578 | 214 |
| actual pos | 514 | 776 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 727 | 65 |
| actual pos | 889 | 401 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 1290 | 0.316 | 0.412 | 0.565 | 0.765 | 0.927 |
| actual negative | 792 | 0.247 | 0.291 | 0.371 | 0.511 | 0.659 |

### safe_delay_180s — Gradient Boosting

- N: 2082
- Positive rate: 0.620
- Mean predicted: 0.620
- Calibration gap (mean_predicted − positive_rate): -0.000
- Brier (pooled OOF): 0.1967
- Brier (per-fold mean ± std): 0.1967 ± 0.0079

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.016, 0.252] | 209 | 0.159 | 0.215 | -0.057 |
| 1 | [0.252, 0.389] | 208 | 0.325 | 0.399 | -0.074 |
| 2 | [0.389, 0.507] | 208 | 0.450 | 0.505 | -0.054 |
| 3 | [0.507, 0.600] | 208 | 0.556 | 0.524 | +0.032 |
| 4 | [0.600, 0.673] | 208 | 0.637 | 0.654 | -0.017 |
| 5 | [0.673, 0.731] | 208 | 0.703 | 0.673 | +0.030 |
| 6 | [0.731, 0.780] | 208 | 0.757 | 0.731 | +0.026 |
| 7 | [0.780, 0.834] | 208 | 0.805 | 0.745 | +0.060 |
| 8 | [0.834, 0.900] | 208 | 0.865 | 0.832 | +0.033 |
| 9 | [0.900, 0.986] | 209 | 0.938 | 0.919 | +0.019 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 49 | 0.065 | 0.082 | -0.016 |
| 1 | [0.1, 0.2) | 89 | 0.157 | 0.213 | -0.056 |
| 2 | [0.2, 0.3) | 145 | 0.251 | 0.331 | -0.080 |
| 3 | [0.3, 0.4) | 152 | 0.357 | 0.434 | -0.077 |
| 4 | [0.4, 0.5) | 176 | 0.452 | 0.489 | -0.037 |
| 5 | [0.5, 0.6) | 226 | 0.554 | 0.540 | +0.014 |
| 6 | [0.6, 0.7) | 296 | 0.653 | 0.652 | +0.001 |
| 7 | [0.7, 0.8) | 412 | 0.753 | 0.723 | +0.029 |
| 8 | [0.8, 0.9) | 329 | 0.847 | 0.799 | +0.048 |
| 9 | [0.9, 1.0] | 208 | 0.938 | 0.918 | +0.020 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.678 | 0.945 | 0.789 | 0.687 | 1219 | 580 | 212 | 71 |
| 0.50 | 0.725 | 0.827 | 0.773 | 0.699 | 1067 | 404 | 388 | 223 |
| 0.70 | 0.792 | 0.583 | 0.672 | 0.647 | 752 | 197 | 595 | 538 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 212 | 580 |
| actual pos | 71 | 1219 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 388 | 404 |
| actual pos | 223 | 1067 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 595 | 197 |
| actual pos | 538 | 752 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 1290 | 0.392 | 0.586 | 0.741 | 0.848 | 0.926 |
| actual negative | 792 | 0.162 | 0.287 | 0.511 | 0.697 | 0.807 |


## safe_delay_180s — LR τ=0.30 vs τ=0.50

### Observational (supported by the tables above)

- Positive rate on the full set is 0.620, so "safe" is the MAJORITY class for this target.
- LR's mean predicted probability is 0.524, giving a calibration gap of -0.095 — LR's average score sits BELOW the empirical base rate.
- At τ=0.50: precision=0.784, recall=0.602, F1=0.681 (TP=776, FP=214, TN=578, FN=514).
- At τ=0.30: precision=0.680, recall=0.933, F1=0.787 (TP=1203, FP=566, TN=226, FN=87).
- τ=0.30 vs τ=0.50 deltas (pooled OOF): ΔF1=+0.106, Δprecision=-0.104, Δrecall=+0.331.

### Interpretation (not causal, flagged as such)

LR is fit with `class_weight='balanced'`, which re-weights training losses to make the classes symmetric. When the empirical base rate is > 0.5 (as here, ~0.62), that re-weighting systematically shifts predicted probabilities away from the base rate toward the middle of [0, 1]. The observed negative calibration gap is consistent with that mechanism but this is a MODEL-LEVEL interpretation, not an assertion about the market. The practical consequence — that LR's natural operating point for safe_delay_180s is below 0.5 — is directly supported by the threshold-sweep deltas above, independent of why.
