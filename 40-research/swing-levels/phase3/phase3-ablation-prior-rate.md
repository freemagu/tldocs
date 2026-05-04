# Phase 3 ablation — prior_rejection_rate investigation — BTCUSDT

_Generated 2026-04-24 22:15:41 UTC_

- Dataset: `research/swing_levels/phase3/features.csv` (2082 rows)
- Splits: GroupKFold(5) on `level_index` — identical to the trainer
- Models: LogisticRegression (L2, class_weight='balanced') and GradientBoostingClassifier(depth=3, n=100) — identical configs to the trainer

## Ablation design

Three feature sets, all drawn strictly from the current MVP 18-feature schema:

- `full_mvp` — 18 features (baseline)
- `minus_prior_rejection_rate` — 17 features (drops `prior_rejection_rate_on_level`)
- `minus_all_level_history_in_mvp` — 14 features (drops `breach_idx_on_level`, `seconds_since_previous_breach_log`, `total_prior_breaches_on_level`, `prior_rejection_rate_on_level`)

No re-extraction. Phase 2 context fields outside the MVP schema (e.g. `previous_breach_first_cross_back_seconds_log`) are not evaluated here — they are explicitly out of scope for this diagnostic.

## Per-target ablation tables

### safe_delay_15s

#### safe_delay_15s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.680 ± 0.028 | 0.625 ± 0.042 | 0.1649 ± 0.0071 |
| minus_prior_rejection_rate | 17 | 0.679 ± 0.026 | 0.623 ± 0.044 | 0.1651 ± 0.0078 |
| minus_all_level_history_in_mvp | 14 | 0.676 ± 0.026 | 0.622 ± 0.032 | 0.1653 ± 0.0071 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | -0.000 | -0.002 | +0.0002 |
| minus_all_level_history_in_mvp | -0.003 | -0.004 | +0.0005 |

#### safe_delay_15s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.672 ± 0.058 | 0.575 ± 0.029 | 0.1438 ± 0.0097 |
| minus_prior_rejection_rate | 17 | 0.670 ± 0.054 | 0.567 ± 0.045 | 0.1446 ± 0.0104 |
| minus_all_level_history_in_mvp | 14 | 0.672 ± 0.053 | 0.560 ± 0.041 | 0.1436 ± 0.0090 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | -0.002 | -0.008 | +0.0008 |
| minus_all_level_history_in_mvp | +0.000 | -0.015 | -0.0002 |


### safe_delay_30s

#### safe_delay_30s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.708 ± 0.021 | 0.646 ± 0.025 | 0.1819 ± 0.0051 |
| minus_prior_rejection_rate | 17 | 0.709 ± 0.021 | 0.643 ± 0.023 | 0.1821 ± 0.0055 |
| minus_all_level_history_in_mvp | 14 | 0.708 ± 0.021 | 0.644 ± 0.020 | 0.1821 ± 0.0051 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.000 | -0.003 | +0.0002 |
| minus_all_level_history_in_mvp | -0.000 | -0.002 | +0.0002 |

#### safe_delay_30s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.688 ± 0.015 | 0.599 ± 0.018 | 0.1753 ± 0.0091 |
| minus_prior_rejection_rate | 17 | 0.696 ± 0.018 | 0.613 ± 0.030 | 0.1733 ± 0.0097 |
| minus_all_level_history_in_mvp | 14 | 0.691 ± 0.024 | 0.608 ± 0.031 | 0.1749 ± 0.0118 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.008 | +0.014 | -0.0020 |
| minus_all_level_history_in_mvp | +0.002 | +0.009 | -0.0004 |


### safe_delay_60s

#### safe_delay_60s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.754 ± 0.014 | 0.658 ± 0.025 | 0.1931 ± 0.0052 |
| minus_prior_rejection_rate | 17 | 0.755 ± 0.013 | 0.659 ± 0.020 | 0.1930 ± 0.0055 |
| minus_all_level_history_in_mvp | 14 | 0.754 ± 0.012 | 0.664 ± 0.017 | 0.1929 ± 0.0046 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.000 | +0.001 | -0.0001 |
| minus_all_level_history_in_mvp | -0.001 | +0.006 | -0.0001 |

#### safe_delay_60s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.739 ± 0.018 | 0.659 ± 0.028 | 0.1931 ± 0.0078 |
| minus_prior_rejection_rate | 17 | 0.739 ± 0.019 | 0.676 ± 0.029 | 0.1924 ± 0.0090 |
| minus_all_level_history_in_mvp | 14 | 0.739 ± 0.016 | 0.670 ± 0.025 | 0.1931 ± 0.0083 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | -0.000 | +0.016 | -0.0007 |
| minus_all_level_history_in_mvp | -0.000 | +0.011 | +0.0000 |


### safe_delay_180s

#### safe_delay_180s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.818 ± 0.019 | 0.680 ± 0.027 | 0.2098 ± 0.0070 |
| minus_prior_rejection_rate | 17 | 0.818 ± 0.018 | 0.680 ± 0.026 | 0.2098 ± 0.0068 |
| minus_all_level_history_in_mvp | 14 | 0.817 ± 0.018 | 0.684 ± 0.023 | 0.2106 ± 0.0064 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.001 | +0.000 | -0.0001 |
| minus_all_level_history_in_mvp | -0.001 | +0.004 | +0.0008 |

#### safe_delay_180s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.813 ± 0.017 | 0.773 ± 0.015 | 0.1967 ± 0.0079 |
| minus_prior_rejection_rate | 17 | 0.816 ± 0.017 | 0.777 ± 0.024 | 0.1959 ± 0.0089 |
| minus_all_level_history_in_mvp | 14 | 0.813 ± 0.017 | 0.776 ± 0.015 | 0.1969 ± 0.0081 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.002 | +0.005 | -0.0008 |
| minus_all_level_history_in_mvp | -0.001 | +0.003 | +0.0002 |


## Stratified cross-tabs

### Bin occupancy

**rate_bin**

- (0, 0.5]: n=75 (3.6%)
- (0.5, 0.8]: n=315 (15.1%)
- (0.8, 1.0]: n=1504 (72.2%)
- first_breach: n=188 (9.0%)

**idx_bin**

- 0: n=188 (9.0%)
- 1-2: n=320 (15.4%)
- 3-5: n=367 (17.6%)
- 6+: n=1207 (58.0%)

**time_bin**

- >1800s: n=1894 (91.0%)
- first_breach: n=188 (9.0%)

### Cross-tabs — safe_delay_15s

#### safe_delay_15s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_15s) |
|---|---|---|
| first_breach | 188 | 0.330 |
| (0, 0.5] | 75 | 0.360 |
| (0.5, 0.8] | 315 | 0.270 |
| (0.8, 1.0] | 1504 | 0.270 |

#### safe_delay_15s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.330 (n=188) | – | – | – |
| (0, 0.5] | – | 0.377 (n=61) | 0.273 (n=11) | 0.333 (n=3) |
| (0.5, 0.8] | – | – | 0.276 (n=127) | 0.266 (n=188) |
| (0.8, 1.0] | – | 0.313 (n=259) | 0.314 (n=229) | 0.249 (n=1016) |

#### safe_delay_15s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.330 (n=188) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.360 (n=75) |
| (0.5, 0.8] | – | – | – | – | 0.270 (n=315) |
| (0.8, 1.0] | – | – | – | – | 0.270 (n=1504) |


### Cross-tabs — safe_delay_30s

#### safe_delay_30s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_30s) |
|---|---|---|
| first_breach | 188 | 0.447 |
| (0, 0.5] | 75 | 0.413 |
| (0.5, 0.8] | 315 | 0.359 |
| (0.8, 1.0] | 1504 | 0.358 |

#### safe_delay_30s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.447 (n=188) | – | – | – |
| (0, 0.5] | – | 0.426 (n=61) | 0.364 (n=11) | 0.333 (n=3) |
| (0.5, 0.8] | – | – | 0.386 (n=127) | 0.340 (n=188) |
| (0.8, 1.0] | – | 0.409 (n=259) | 0.406 (n=229) | 0.335 (n=1016) |

#### safe_delay_30s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.447 (n=188) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.413 (n=75) |
| (0.5, 0.8] | – | – | – | – | 0.359 (n=315) |
| (0.8, 1.0] | – | – | – | – | 0.358 (n=1504) |


### Cross-tabs — safe_delay_60s

#### safe_delay_60s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_60s) |
|---|---|---|
| first_breach | 188 | 0.543 |
| (0, 0.5] | 75 | 0.520 |
| (0.5, 0.8] | 315 | 0.460 |
| (0.8, 1.0] | 1504 | 0.451 |

#### safe_delay_60s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.543 (n=188) | – | – | – |
| (0, 0.5] | – | 0.557 (n=61) | 0.364 (n=11) | 0.333 (n=3) |
| (0.5, 0.8] | – | – | 0.496 (n=127) | 0.436 (n=188) |
| (0.8, 1.0] | – | 0.486 (n=259) | 0.507 (n=229) | 0.430 (n=1016) |

#### safe_delay_60s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.543 (n=188) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.520 (n=75) |
| (0.5, 0.8] | – | – | – | – | 0.460 (n=315) |
| (0.8, 1.0] | – | – | – | – | 0.451 (n=1504) |


### Cross-tabs — safe_delay_180s

#### safe_delay_180s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_180s) |
|---|---|---|
| first_breach | 188 | 0.686 |
| (0, 0.5] | 75 | 0.680 |
| (0.5, 0.8] | 315 | 0.613 |
| (0.8, 1.0] | 1504 | 0.610 |

#### safe_delay_180s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.686 (n=188) | – | – | – |
| (0, 0.5] | – | 0.656 (n=61) | 0.727 (n=11) | 1.000 (n=3) |
| (0.5, 0.8] | – | – | 0.614 (n=127) | 0.612 (n=188) |
| (0.8, 1.0] | – | 0.641 (n=259) | 0.664 (n=229) | 0.590 (n=1016) |

#### safe_delay_180s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.686 (n=188) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.680 (n=75) |
| (0.5, 0.8] | – | – | – | – | 0.613 (n=315) |
| (0.8, 1.0] | – | – | – | – | 0.610 (n=1504) |


## Interpretation

### Observations (from the tables above)

- LR ΔPR-AUC when removing only `prior_rejection_rate_on_level`:
  - safe_delay_15s: -0.000
  - safe_delay_30s: +0.000
  - safe_delay_60s: +0.000
  - safe_delay_180s: +0.001
- LR ΔPR-AUC when removing all four level-history MVP features:
  - safe_delay_15s: -0.003
  - safe_delay_30s: -0.000
  - safe_delay_60s: -0.001
  - safe_delay_180s: -0.001

- The marginal (rate_bin) cross-tab reports mean(safe_delay_*) by bucket.
  The two-way cross-tabs show whether that marginal relationship
  persists once `breach_idx_on_level` or `seconds_since_previous_breach`
  is fixed.

### Interpretation framing (mechanism-level, flagged as such)

- If the stratified cross-tabs show a monotone drop of mean(safe_delay)
  as `rate_bin` moves from first_breach → (0.8, 1.0] *within each idx
  and time stratum*, the negative LR coefficient is CONSISTENT WITH a
  conditional effect (historical rejection rate contributing signal
  beyond what idx and time alone provide).
- If the per-stratum means are flat or reverse within strata, the
  marginal signal is CONSISTENT WITH absorption of correlation from
  `breach_idx_on_level` / `seconds_since_previous_breach`.
- These are statements about correspondence, not causation. The data
  cannot by itself distinguish a real mechanism from a hidden common
  cause; any mechanistic claim (e.g. "rejected breaches fade because
  market memory X") is an interpretation, not a finding.
