# Phase 3 calibration / reliability — ETHUSDT

_Generated 2026-04-24 23:32:47 UTC_

- Dataset: `research/swing_levels/phase3/features.csv` (1968 rows)
- Features: 18 MVP columns
- Splits: GroupKFold(5) on `level_index`; OOF predictions pooled across folds
- Models: LogisticRegression (L2, class_weight='balanced') and GradientBoostingClassifier(depth=3, n=100) — identical configs to the trainer

Reliability is computed from **pooled OOF predictions** (every row is scored exactly once, while in its test fold). Per-fold Brier scores are reported alongside the pooled Brier for cross-reference.

Wording discipline: *observation* statements describe what the tables show; *interpretation* statements propose mechanisms and are marked as such. No causal claims about the market are made.

## safe_delay_15s

### safe_delay_15s — Logistic Regression

- N: 1968
- Positive rate: 0.312
- Mean predicted: 0.432
- Calibration gap (mean_predicted − positive_rate): +0.120
- Brier (pooled OOF): 0.1576
- Brier (per-fold mean ± std): 0.1576 ± 0.0106

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.048, 0.134] | 197 | 0.110 | 0.005 | +0.105 |
| 1 | [0.134, 0.169] | 197 | 0.150 | 0.041 | +0.110 |
| 2 | [0.169, 0.214] | 197 | 0.192 | 0.086 | +0.106 |
| 3 | [0.214, 0.262] | 196 | 0.237 | 0.143 | +0.094 |
| 4 | [0.262, 0.348] | 197 | 0.303 | 0.188 | +0.115 |
| 5 | [0.348, 0.442] | 197 | 0.395 | 0.289 | +0.106 |
| 6 | [0.442, 0.572] | 196 | 0.506 | 0.332 | +0.174 |
| 7 | [0.572, 0.743] | 197 | 0.649 | 0.548 | +0.100 |
| 8 | [0.743, 0.898] | 197 | 0.817 | 0.675 | +0.142 |
| 9 | [0.898, 1.000] | 197 | 0.965 | 0.817 | +0.147 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 51 | 0.085 | 0.000 | +0.085 |
| 1 | [0.1, 0.2) | 475 | 0.150 | 0.040 | +0.110 |
| 2 | [0.2, 0.3) | 352 | 0.242 | 0.145 | +0.097 |
| 3 | [0.3, 0.4) | 213 | 0.348 | 0.244 | +0.104 |
| 4 | [0.4, 0.5) | 179 | 0.445 | 0.263 | +0.182 |
| 5 | [0.5, 0.6) | 145 | 0.550 | 0.421 | +0.129 |
| 6 | [0.6, 0.7) | 126 | 0.648 | 0.571 | +0.076 |
| 7 | [0.7, 0.8) | 114 | 0.754 | 0.588 | +0.167 |
| 8 | [0.8, 0.9) | 118 | 0.853 | 0.737 | +0.116 |
| 9 | [0.9, 1.0] | 195 | 0.965 | 0.815 | +0.150 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.500 | 0.886 | 0.639 | 0.688 | 545 | 545 | 808 | 70 |
| 0.50 | 0.639 | 0.725 | 0.679 | 0.786 | 446 | 252 | 1101 | 169 |
| 0.70 | 0.733 | 0.509 | 0.601 | 0.789 | 313 | 114 | 1239 | 302 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 808 | 545 |
| actual pos | 70 | 545 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1101 | 252 |
| actual pos | 169 | 446 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1239 | 114 |
| actual pos | 302 | 313 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 615 | 0.276 | 0.457 | 0.712 | 0.904 | 0.989 |
| actual negative | 1353 | 0.121 | 0.160 | 0.243 | 0.429 | 0.652 |

### safe_delay_15s — Gradient Boosting

- N: 1968
- Positive rate: 0.312
- Mean predicted: 0.311
- Calibration gap (mean_predicted − positive_rate): -0.002
- Brier (pooled OOF): 0.1500
- Brier (per-fold mean ± std): 0.1500 ± 0.0140

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.009, 0.028] | 197 | 0.020 | 0.015 | +0.005 |
| 1 | [0.028, 0.044] | 197 | 0.036 | 0.020 | +0.015 |
| 2 | [0.044, 0.073] | 197 | 0.058 | 0.056 | +0.002 |
| 3 | [0.073, 0.126] | 196 | 0.098 | 0.153 | -0.055 |
| 4 | [0.126, 0.212] | 197 | 0.165 | 0.259 | -0.094 |
| 5 | [0.212, 0.320] | 197 | 0.261 | 0.284 | -0.023 |
| 6 | [0.320, 0.455] | 196 | 0.384 | 0.372 | +0.012 |
| 7 | [0.455, 0.601] | 197 | 0.524 | 0.528 | -0.004 |
| 8 | [0.601, 0.776] | 197 | 0.685 | 0.645 | +0.040 |
| 9 | [0.776, 0.988] | 197 | 0.874 | 0.792 | +0.083 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 703 | 0.046 | 0.050 | -0.004 |
| 1 | [0.1, 0.2) | 261 | 0.145 | 0.215 | -0.069 |
| 2 | [0.2, 0.3) | 194 | 0.250 | 0.278 | -0.029 |
| 3 | [0.3, 0.4) | 154 | 0.354 | 0.396 | -0.042 |
| 4 | [0.4, 0.5) | 133 | 0.454 | 0.368 | +0.086 |
| 5 | [0.5, 0.6) | 127 | 0.548 | 0.591 | -0.042 |
| 6 | [0.6, 0.7) | 128 | 0.651 | 0.633 | +0.019 |
| 7 | [0.7, 0.8) | 91 | 0.753 | 0.681 | +0.071 |
| 8 | [0.8, 0.9) | 110 | 0.852 | 0.782 | +0.071 |
| 9 | [0.9, 1.0] | 67 | 0.936 | 0.836 | +0.100 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.580 | 0.764 | 0.660 | 0.754 | 470 | 340 | 1013 | 145 |
| 0.50 | 0.688 | 0.585 | 0.633 | 0.788 | 360 | 163 | 1190 | 255 |
| 0.70 | 0.761 | 0.332 | 0.462 | 0.759 | 204 | 64 | 1289 | 411 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1013 | 340 |
| actual pos | 145 | 470 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1190 | 163 |
| actual pos | 255 | 360 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1289 | 64 |
| actual pos | 411 | 204 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 615 | 0.146 | 0.316 | 0.569 | 0.782 | 0.894 |
| actual negative | 1353 | 0.023 | 0.040 | 0.104 | 0.300 | 0.556 |


## safe_delay_30s

### safe_delay_30s — Logistic Regression

- N: 1968
- Positive rate: 0.402
- Mean predicted: 0.470
- Calibration gap (mean_predicted − positive_rate): +0.067
- Brier (pooled OOF): 0.1729
- Brier (per-fold mean ± std): 0.1729 ± 0.0107

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.063, 0.173] | 197 | 0.147 | 0.025 | +0.122 |
| 1 | [0.173, 0.215] | 197 | 0.194 | 0.091 | +0.102 |
| 2 | [0.215, 0.258] | 197 | 0.237 | 0.168 | +0.070 |
| 3 | [0.258, 0.313] | 196 | 0.285 | 0.270 | +0.015 |
| 4 | [0.313, 0.399] | 197 | 0.355 | 0.320 | +0.035 |
| 5 | [0.399, 0.494] | 197 | 0.447 | 0.371 | +0.076 |
| 6 | [0.494, 0.611] | 196 | 0.551 | 0.520 | +0.031 |
| 7 | [0.611, 0.755] | 197 | 0.683 | 0.650 | +0.033 |
| 8 | [0.755, 0.906] | 197 | 0.834 | 0.756 | +0.078 |
| 9 | [0.906, 1.000] | 197 | 0.965 | 0.853 | +0.112 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 8 | 0.091 | 0.000 | +0.091 |
| 1 | [0.1, 0.2) | 307 | 0.163 | 0.042 | +0.121 |
| 2 | [0.2, 0.3) | 428 | 0.246 | 0.192 | +0.055 |
| 3 | [0.3, 0.4) | 246 | 0.347 | 0.313 | +0.034 |
| 4 | [0.4, 0.5) | 207 | 0.452 | 0.372 | +0.080 |
| 5 | [0.5, 0.6) | 164 | 0.550 | 0.543 | +0.008 |
| 6 | [0.6, 0.7) | 136 | 0.646 | 0.625 | +0.021 |
| 7 | [0.7, 0.8) | 130 | 0.748 | 0.700 | +0.048 |
| 8 | [0.8, 0.9) | 138 | 0.853 | 0.761 | +0.092 |
| 9 | [0.9, 1.0] | 204 | 0.963 | 0.848 | +0.115 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.569 | 0.880 | 0.691 | 0.683 | 697 | 528 | 648 | 95 |
| 0.50 | 0.703 | 0.686 | 0.694 | 0.757 | 543 | 229 | 947 | 249 |
| 0.70 | 0.782 | 0.466 | 0.584 | 0.733 | 369 | 103 | 1073 | 423 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 648 | 528 |
| actual pos | 95 | 697 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 947 | 229 |
| actual pos | 249 | 543 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1073 | 103 |
| actual pos | 423 | 369 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 792 | 0.290 | 0.434 | 0.663 | 0.881 | 0.979 |
| actual negative | 1176 | 0.158 | 0.198 | 0.275 | 0.454 | 0.659 |

### safe_delay_30s — Gradient Boosting

- N: 1968
- Positive rate: 0.402
- Mean predicted: 0.400
- Calibration gap (mean_predicted − positive_rate): -0.002
- Brier (pooled OOF): 0.1708
- Brier (per-fold mean ± std): 0.1708 ± 0.0121

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.014, 0.051] | 197 | 0.036 | 0.015 | +0.021 |
| 1 | [0.051, 0.088] | 197 | 0.069 | 0.071 | -0.002 |
| 2 | [0.088, 0.152] | 197 | 0.117 | 0.183 | -0.065 |
| 3 | [0.152, 0.245] | 196 | 0.195 | 0.276 | -0.080 |
| 4 | [0.245, 0.369] | 197 | 0.309 | 0.345 | -0.036 |
| 5 | [0.369, 0.473] | 197 | 0.421 | 0.396 | +0.025 |
| 6 | [0.473, 0.587] | 196 | 0.531 | 0.531 | +0.000 |
| 7 | [0.587, 0.711] | 197 | 0.647 | 0.594 | +0.053 |
| 8 | [0.711, 0.837] | 197 | 0.774 | 0.736 | +0.038 |
| 9 | [0.837, 0.988] | 197 | 0.902 | 0.878 | +0.024 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 438 | 0.057 | 0.050 | +0.007 |
| 1 | [0.1, 0.2) | 257 | 0.144 | 0.226 | -0.082 |
| 2 | [0.2, 0.3) | 172 | 0.244 | 0.302 | -0.058 |
| 3 | [0.3, 0.4) | 183 | 0.352 | 0.393 | -0.041 |
| 4 | [0.4, 0.5) | 172 | 0.450 | 0.448 | +0.003 |
| 5 | [0.5, 0.6) | 177 | 0.549 | 0.497 | +0.051 |
| 6 | [0.6, 0.7) | 163 | 0.650 | 0.607 | +0.043 |
| 7 | [0.7, 0.8) | 153 | 0.753 | 0.725 | +0.027 |
| 8 | [0.8, 0.9) | 161 | 0.851 | 0.789 | +0.062 |
| 9 | [0.9, 1.0] | 92 | 0.939 | 0.935 | +0.005 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.599 | 0.833 | 0.697 | 0.709 | 660 | 441 | 735 | 132 |
| 0.50 | 0.685 | 0.645 | 0.664 | 0.738 | 511 | 235 | 941 | 281 |
| 0.70 | 0.798 | 0.409 | 0.541 | 0.721 | 324 | 82 | 1094 | 468 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 735 | 441 |
| actual pos | 132 | 660 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 941 | 235 |
| actual pos | 281 | 511 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 1094 | 82 |
| actual pos | 468 | 324 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 792 | 0.198 | 0.393 | 0.622 | 0.812 | 0.908 |
| actual negative | 1176 | 0.040 | 0.070 | 0.178 | 0.431 | 0.650 |


## safe_delay_60s

### safe_delay_60s — Logistic Regression

- N: 1968
- Positive rate: 0.500
- Mean predicted: 0.500
- Calibration gap (mean_predicted − positive_rate): -0.000
- Brier (pooled OOF): 0.1862
- Brier (per-fold mean ± std): 0.1862 ± 0.0085

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.068, 0.209] | 197 | 0.175 | 0.076 | +0.099 |
| 1 | [0.209, 0.257] | 197 | 0.231 | 0.198 | +0.033 |
| 2 | [0.257, 0.305] | 197 | 0.280 | 0.254 | +0.026 |
| 3 | [0.305, 0.366] | 196 | 0.334 | 0.357 | -0.023 |
| 4 | [0.366, 0.444] | 197 | 0.403 | 0.503 | -0.100 |
| 5 | [0.444, 0.537] | 197 | 0.489 | 0.538 | -0.049 |
| 6 | [0.537, 0.636] | 196 | 0.587 | 0.648 | -0.061 |
| 7 | [0.636, 0.765] | 197 | 0.700 | 0.741 | -0.041 |
| 8 | [0.765, 0.901] | 197 | 0.834 | 0.812 | +0.022 |
| 9 | [0.901, 1.000] | 197 | 0.963 | 0.873 | +0.090 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 6 | 0.089 | 0.000 | +0.089 |
| 1 | [0.1, 0.2) | 157 | 0.172 | 0.051 | +0.121 |
| 2 | [0.2, 0.3) | 411 | 0.250 | 0.219 | +0.031 |
| 3 | [0.3, 0.4) | 311 | 0.348 | 0.402 | -0.054 |
| 4 | [0.4, 0.5) | 222 | 0.450 | 0.545 | -0.095 |
| 5 | [0.5, 0.6) | 193 | 0.549 | 0.565 | -0.016 |
| 6 | [0.6, 0.7) | 179 | 0.645 | 0.715 | -0.070 |
| 7 | [0.7, 0.8) | 148 | 0.752 | 0.736 | +0.016 |
| 8 | [0.8, 0.9) | 142 | 0.852 | 0.845 | +0.007 |
| 9 | [0.9, 1.0] | 199 | 0.963 | 0.874 | +0.088 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.636 | 0.900 | 0.745 | 0.692 | 886 | 508 | 476 | 98 |
| 0.50 | 0.743 | 0.650 | 0.694 | 0.713 | 640 | 221 | 763 | 344 |
| 0.70 | 0.824 | 0.410 | 0.547 | 0.661 | 403 | 86 | 898 | 581 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 476 | 508 |
| actual pos | 98 | 886 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 763 | 221 |
| actual pos | 344 | 640 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 898 | 86 |
| actual pos | 581 | 403 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 984 | 0.300 | 0.419 | 0.621 | 0.842 | 0.966 |
| actual negative | 984 | 0.182 | 0.225 | 0.309 | 0.471 | 0.664 |

### safe_delay_60s — Gradient Boosting

- N: 1968
- Positive rate: 0.500
- Mean predicted: 0.505
- Calibration gap (mean_predicted − positive_rate): +0.005
- Brier (pooled OOF): 0.1871
- Brier (per-fold mean ± std): 0.1871 ± 0.0066

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.015, 0.098] | 197 | 0.059 | 0.076 | -0.017 |
| 1 | [0.098, 0.191] | 197 | 0.143 | 0.188 | -0.045 |
| 2 | [0.191, 0.309] | 197 | 0.250 | 0.279 | -0.029 |
| 3 | [0.309, 0.420] | 196 | 0.361 | 0.398 | -0.037 |
| 4 | [0.420, 0.529] | 197 | 0.475 | 0.482 | -0.008 |
| 5 | [0.529, 0.627] | 197 | 0.582 | 0.584 | -0.002 |
| 6 | [0.627, 0.712] | 196 | 0.671 | 0.622 | +0.048 |
| 7 | [0.712, 0.793] | 197 | 0.753 | 0.701 | +0.053 |
| 8 | [0.793, 0.875] | 197 | 0.838 | 0.766 | +0.071 |
| 9 | [0.875, 0.989] | 197 | 0.920 | 0.904 | +0.016 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 204 | 0.060 | 0.078 | -0.018 |
| 1 | [0.1, 0.2) | 205 | 0.148 | 0.195 | -0.047 |
| 2 | [0.2, 0.3) | 161 | 0.248 | 0.267 | -0.019 |
| 3 | [0.3, 0.4) | 188 | 0.347 | 0.383 | -0.036 |
| 4 | [0.4, 0.5) | 168 | 0.449 | 0.488 | -0.039 |
| 5 | [0.5, 0.6) | 192 | 0.551 | 0.542 | +0.010 |
| 6 | [0.6, 0.7) | 237 | 0.652 | 0.608 | +0.045 |
| 7 | [0.7, 0.8) | 231 | 0.751 | 0.714 | +0.037 |
| 8 | [0.8, 0.9) | 258 | 0.854 | 0.795 | +0.059 |
| 9 | [0.9, 1.0] | 124 | 0.939 | 0.911 | +0.028 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.633 | 0.899 | 0.743 | 0.689 | 885 | 513 | 471 | 99 |
| 0.50 | 0.702 | 0.743 | 0.722 | 0.713 | 731 | 311 | 673 | 253 |
| 0.70 | 0.788 | 0.491 | 0.605 | 0.679 | 483 | 130 | 854 | 501 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 471 | 513 |
| actual pos | 99 | 885 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 673 | 311 |
| actual pos | 253 | 731 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 854 | 130 |
| actual pos | 501 | 483 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 984 | 0.300 | 0.490 | 0.697 | 0.842 | 0.911 |
| actual negative | 984 | 0.062 | 0.131 | 0.315 | 0.576 | 0.744 |


## safe_delay_180s

### safe_delay_180s — Logistic Regression

- N: 1968
- Positive rate: 0.632
- Mean predicted: 0.531
- Calibration gap (mean_predicted − positive_rate): -0.102
- Brier (pooled OOF): 0.1973
- Brier (per-fold mean ± std): 0.1973 ± 0.0083

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.071, 0.238] | 197 | 0.195 | 0.193 | +0.002 |
| 1 | [0.238, 0.292] | 197 | 0.266 | 0.350 | -0.084 |
| 2 | [0.292, 0.350] | 197 | 0.321 | 0.492 | -0.171 |
| 3 | [0.350, 0.414] | 196 | 0.384 | 0.541 | -0.157 |
| 4 | [0.414, 0.486] | 197 | 0.449 | 0.665 | -0.216 |
| 5 | [0.486, 0.576] | 197 | 0.530 | 0.665 | -0.135 |
| 6 | [0.576, 0.668] | 196 | 0.621 | 0.765 | -0.144 |
| 7 | [0.668, 0.786] | 197 | 0.728 | 0.838 | -0.109 |
| 8 | [0.786, 0.906] | 197 | 0.845 | 0.893 | -0.048 |
| 9 | [0.906, 1.000] | 197 | 0.965 | 0.919 | +0.046 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 7 | 0.090 | 0.143 | -0.053 |
| 1 | [0.1, 0.2) | 74 | 0.166 | 0.108 | +0.058 |
| 2 | [0.2, 0.3) | 343 | 0.253 | 0.329 | -0.076 |
| 3 | [0.3, 0.4) | 315 | 0.349 | 0.517 | -0.168 |
| 4 | [0.4, 0.5) | 275 | 0.447 | 0.633 | -0.186 |
| 5 | [0.5, 0.6) | 223 | 0.550 | 0.691 | -0.140 |
| 6 | [0.6, 0.7) | 186 | 0.646 | 0.801 | -0.155 |
| 7 | [0.7, 0.8) | 174 | 0.749 | 0.833 | -0.085 |
| 8 | [0.8, 0.9) | 164 | 0.849 | 0.890 | -0.041 |
| 9 | [0.9, 1.0] | 207 | 0.962 | 0.923 | +0.039 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.727 | 0.902 | 0.805 | 0.724 | 1122 | 422 | 302 | 122 |
| 0.50 | 0.823 | 0.631 | 0.714 | 0.681 | 785 | 169 | 555 | 459 |
| 0.70 | 0.884 | 0.387 | 0.539 | 0.581 | 482 | 63 | 661 | 762 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 302 | 422 |
| actual pos | 122 | 1122 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 555 | 169 |
| actual pos | 459 | 785 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 661 | 63 |
| actual pos | 762 | 482 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 1244 | 0.303 | 0.415 | 0.605 | 0.820 | 0.952 |
| actual negative | 724 | 0.201 | 0.249 | 0.335 | 0.486 | 0.659 |

### safe_delay_180s — Gradient Boosting

- N: 1968
- Positive rate: 0.632
- Mean predicted: 0.636
- Calibration gap (mean_predicted − positive_rate): +0.004
- Brier (pooled OOF): 0.1826
- Brier (per-fold mean ± std): 0.1826 ± 0.0057

#### Reliability — equal-frequency deciles (primary)

| decile | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.009, 0.232] | 197 | 0.139 | 0.203 | -0.064 |
| 1 | [0.232, 0.391] | 197 | 0.306 | 0.330 | -0.024 |
| 2 | [0.391, 0.517] | 197 | 0.459 | 0.492 | -0.034 |
| 3 | [0.517, 0.616] | 196 | 0.568 | 0.561 | +0.007 |
| 4 | [0.616, 0.699] | 197 | 0.660 | 0.660 | -0.000 |
| 5 | [0.699, 0.768] | 197 | 0.737 | 0.711 | +0.026 |
| 6 | [0.768, 0.825] | 196 | 0.795 | 0.740 | +0.055 |
| 7 | [0.825, 0.874] | 197 | 0.852 | 0.827 | +0.024 |
| 8 | [0.874, 0.916] | 197 | 0.894 | 0.868 | +0.026 |
| 9 | [0.916, 0.989] | 197 | 0.947 | 0.929 | +0.018 |

_Observation: the sign of `gap` indicates direction — negative means the model's average prediction in that decile was LOWER than the empirical positive rate (under-confident in positives); positive means OVER-confident._

#### Reliability — equal-width bins (appendix, for cross-reference)

| bin | p_range | count | mean_predicted | actual_positive_rate | gap |
|---|---|---|---|---|---|
| 0 | [0.0, 0.1) | 57 | 0.066 | 0.105 | -0.039 |
| 1 | [0.1, 0.2) | 107 | 0.154 | 0.206 | -0.052 |
| 2 | [0.2, 0.3) | 128 | 0.252 | 0.297 | -0.045 |
| 3 | [0.3, 0.4) | 117 | 0.351 | 0.359 | -0.008 |
| 4 | [0.4, 0.5) | 148 | 0.454 | 0.554 | -0.101 |
| 5 | [0.5, 0.6) | 191 | 0.550 | 0.503 | +0.047 |
| 6 | [0.6, 0.7) | 239 | 0.652 | 0.657 | -0.005 |
| 7 | [0.7, 0.8) | 306 | 0.754 | 0.732 | +0.022 |
| 8 | [0.8, 0.9) | 408 | 0.854 | 0.814 | +0.041 |
| 9 | [0.9, 1.0] | 267 | 0.937 | 0.918 | +0.019 |

#### Threshold sweep (pooled OOF)

| τ | precision | recall | F1 | accuracy | TP | FP | TN | FN |
|---|---|---|---|---|---|---|---|---|
| 0.30 | 0.703 | 0.947 | 0.807 | 0.713 | 1178 | 498 | 226 | 66 |
| 0.50 | 0.747 | 0.847 | 0.794 | 0.722 | 1054 | 357 | 367 | 190 |
| 0.70 | 0.817 | 0.644 | 0.720 | 0.683 | 801 | 180 | 544 | 443 |

Confusion matrix at τ=0.30:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 226 | 498 |
| actual pos | 66 | 1178 |

Confusion matrix at τ=0.50:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 367 | 357 |
| actual pos | 190 | 1054 |

Confusion matrix at τ=0.70:

| | pred neg | pred pos |
|---|---|---|
| actual neg | 544 | 180 |
| actual pos | 443 | 801 |

#### Score separation (predicted probability quantiles by actual label)

| group | n | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| actual positive | 1244 | 0.425 | 0.615 | 0.782 | 0.886 | 0.936 |
| actual negative | 724 | 0.135 | 0.257 | 0.494 | 0.699 | 0.830 |


## safe_delay_180s — LR τ=0.30 vs τ=0.50

### Observational (supported by the tables above)

- Positive rate on the full set is 0.632, so "safe" is the MAJORITY class for this target.
- LR's mean predicted probability is 0.531, giving a calibration gap of -0.102 — LR's average score sits BELOW the empirical base rate.
- At τ=0.50: precision=0.823, recall=0.631, F1=0.714 (TP=785, FP=169, TN=555, FN=459).
- At τ=0.30: precision=0.727, recall=0.902, F1=0.805 (TP=1122, FP=422, TN=302, FN=122).
- τ=0.30 vs τ=0.50 deltas (pooled OOF): ΔF1=+0.091, Δprecision=-0.096, Δrecall=+0.271.

### Interpretation (not causal, flagged as such)

LR is fit with `class_weight='balanced'`, which re-weights training losses to make the classes symmetric. When the empirical base rate is > 0.5 (as here, ~0.62), that re-weighting systematically shifts predicted probabilities away from the base rate toward the middle of [0, 1]. The observed negative calibration gap is consistent with that mechanism but this is a MODEL-LEVEL interpretation, not an assertion about the market. The practical consequence — that LR's natural operating point for safe_delay_180s is below 0.5 — is directly supported by the threshold-sweep deltas above, independent of why.
