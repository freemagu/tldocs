# Phase 3 ablation — prior_rejection_rate investigation — ETHUSDT

_Generated 2026-04-24 23:33:26 UTC_

- Dataset: `research/swing_levels/phase3/features.csv` (1968 rows)
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
| full_mvp | 18 | 0.711 ± 0.060 | 0.675 ± 0.041 | 0.1576 ± 0.0106 |
| minus_prior_rejection_rate | 17 | 0.712 ± 0.059 | 0.675 ± 0.041 | 0.1577 ± 0.0106 |
| minus_all_level_history_in_mvp | 14 | 0.712 ± 0.055 | 0.659 ± 0.033 | 0.1584 ± 0.0106 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.001 | +0.000 | +0.0000 |
| minus_all_level_history_in_mvp | +0.000 | -0.017 | +0.0007 |

#### safe_delay_15s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.690 ± 0.052 | 0.631 ± 0.022 | 0.1500 ± 0.0140 |
| minus_prior_rejection_rate | 17 | 0.689 ± 0.046 | 0.626 ± 0.027 | 0.1503 ± 0.0142 |
| minus_all_level_history_in_mvp | 14 | 0.690 ± 0.041 | 0.608 ± 0.030 | 0.1502 ± 0.0154 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | -0.001 | -0.005 | +0.0003 |
| minus_all_level_history_in_mvp | +0.000 | -0.023 | +0.0002 |


### safe_delay_30s

#### safe_delay_30s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.754 ± 0.039 | 0.691 ± 0.039 | 0.1729 ± 0.0107 |
| minus_prior_rejection_rate | 17 | 0.755 ± 0.039 | 0.688 ± 0.040 | 0.1729 ± 0.0107 |
| minus_all_level_history_in_mvp | 14 | 0.754 ± 0.032 | 0.688 ± 0.027 | 0.1731 ± 0.0092 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.001 | -0.003 | -0.0000 |
| minus_all_level_history_in_mvp | +0.000 | -0.004 | +0.0003 |

#### safe_delay_30s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.750 ± 0.027 | 0.664 ± 0.023 | 0.1708 ± 0.0121 |
| minus_prior_rejection_rate | 17 | 0.749 ± 0.028 | 0.669 ± 0.028 | 0.1708 ± 0.0126 |
| minus_all_level_history_in_mvp | 14 | 0.751 ± 0.030 | 0.667 ± 0.022 | 0.1700 ± 0.0123 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | -0.001 | +0.004 | +0.0000 |
| minus_all_level_history_in_mvp | +0.001 | +0.003 | -0.0008 |


### safe_delay_60s

#### safe_delay_60s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.789 ± 0.036 | 0.691 ± 0.035 | 0.1862 ± 0.0085 |
| minus_prior_rejection_rate | 17 | 0.789 ± 0.036 | 0.695 ± 0.034 | 0.1856 ± 0.0080 |
| minus_all_level_history_in_mvp | 14 | 0.792 ± 0.030 | 0.695 ± 0.032 | 0.1851 ± 0.0061 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.001 | +0.004 | -0.0005 |
| minus_all_level_history_in_mvp | +0.004 | +0.004 | -0.0010 |

#### safe_delay_60s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.780 ± 0.030 | 0.720 ± 0.020 | 0.1871 ± 0.0066 |
| minus_prior_rejection_rate | 17 | 0.781 ± 0.032 | 0.724 ± 0.020 | 0.1868 ± 0.0072 |
| minus_all_level_history_in_mvp | 14 | 0.787 ± 0.024 | 0.722 ± 0.013 | 0.1855 ± 0.0069 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.001 | +0.004 | -0.0003 |
| minus_all_level_history_in_mvp | +0.008 | +0.001 | -0.0016 |


### safe_delay_180s

#### safe_delay_180s — Logistic Regression

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.848 ± 0.016 | 0.712 ± 0.030 | 0.1973 ± 0.0083 |
| minus_prior_rejection_rate | 17 | 0.848 ± 0.016 | 0.712 ± 0.030 | 0.1972 ± 0.0081 |
| minus_all_level_history_in_mvp | 14 | 0.849 ± 0.011 | 0.711 ± 0.029 | 0.1969 ± 0.0044 |

Δ vs full_mvp (Logistic Regression):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.000 | +0.000 | -0.0001 |
| minus_all_level_history_in_mvp | +0.002 | -0.001 | -0.0003 |

#### safe_delay_180s — Gradient Boosting

| variant | n_features | PR-AUC | F1@0.5 | Brier |
|---|---|---|---|---|
| full_mvp | 18 | 0.846 ± 0.008 | 0.793 ± 0.022 | 0.1826 ± 0.0057 |
| minus_prior_rejection_rate | 17 | 0.847 ± 0.009 | 0.795 ± 0.017 | 0.1831 ± 0.0038 |
| minus_all_level_history_in_mvp | 14 | 0.843 ± 0.009 | 0.792 ± 0.014 | 0.1841 ± 0.0038 |

Δ vs full_mvp (Gradient Boosting):

| variant | ΔPR-AUC | ΔF1@0.5 | ΔBrier |
|---|---|---|---|
| minus_prior_rejection_rate | +0.001 | +0.002 | +0.0005 |
| minus_all_level_history_in_mvp | -0.003 | -0.001 | +0.0015 |


## Stratified cross-tabs

### Bin occupancy

**rate_bin**

- (0, 0.5]: n=64 (3.3%)
- (0.5, 0.8]: n=327 (16.6%)
- (0.8, 1.0]: n=1405 (71.4%)
- first_breach: n=172 (8.7%)

**idx_bin**

- 0: n=172 (8.7%)
- 1-2: n=306 (15.5%)
- 3-5: n=369 (18.8%)
- 6+: n=1121 (57.0%)

**time_bin**

- >1800s: n=1796 (91.3%)
- first_breach: n=172 (8.7%)

### Cross-tabs — safe_delay_15s

#### safe_delay_15s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_15s) |
|---|---|---|
| first_breach | 172 | 0.384 |
| (0, 0.5] | 64 | 0.406 |
| (0.5, 0.8] | 327 | 0.245 |
| (0.8, 1.0] | 1405 | 0.315 |

#### safe_delay_15s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.384 (n=172) | – | – | – |
| (0, 0.5] | – | 0.440 (n=50) | 0.125 (n=8) | 0.500 (n=6) |
| (0.5, 0.8] | – | – | 0.369 (n=130) | 0.162 (n=197) |
| (0.8, 1.0] | – | 0.352 (n=256) | 0.359 (n=231) | 0.294 (n=918) |

#### safe_delay_15s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.384 (n=172) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.406 (n=64) |
| (0.5, 0.8] | – | – | – | – | 0.245 (n=327) |
| (0.8, 1.0] | – | – | – | – | 0.315 (n=1405) |


### Cross-tabs — safe_delay_30s

#### safe_delay_30s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_30s) |
|---|---|---|
| first_breach | 172 | 0.477 |
| (0, 0.5] | 64 | 0.484 |
| (0.5, 0.8] | 327 | 0.339 |
| (0.8, 1.0] | 1405 | 0.404 |

#### safe_delay_30s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.477 (n=172) | – | – | – |
| (0, 0.5] | – | 0.500 (n=50) | 0.375 (n=8) | 0.500 (n=6) |
| (0.5, 0.8] | – | – | 0.454 (n=130) | 0.264 (n=197) |
| (0.8, 1.0] | – | 0.438 (n=256) | 0.442 (n=231) | 0.386 (n=918) |

#### safe_delay_30s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.477 (n=172) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.484 (n=64) |
| (0.5, 0.8] | – | – | – | – | 0.339 (n=327) |
| (0.8, 1.0] | – | – | – | – | 0.404 (n=1405) |


### Cross-tabs — safe_delay_60s

#### safe_delay_60s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_60s) |
|---|---|---|
| first_breach | 172 | 0.593 |
| (0, 0.5] | 64 | 0.594 |
| (0.5, 0.8] | 327 | 0.425 |
| (0.8, 1.0] | 1405 | 0.502 |

#### safe_delay_60s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.593 (n=172) | – | – | – |
| (0, 0.5] | – | 0.640 (n=50) | 0.375 (n=8) | 0.500 (n=6) |
| (0.5, 0.8] | – | – | 0.577 (n=130) | 0.325 (n=197) |
| (0.8, 1.0] | – | 0.547 (n=256) | 0.545 (n=231) | 0.478 (n=918) |

#### safe_delay_60s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.593 (n=172) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.594 (n=64) |
| (0.5, 0.8] | – | – | – | – | 0.425 (n=327) |
| (0.8, 1.0] | – | – | – | – | 0.502 (n=1405) |


### Cross-tabs — safe_delay_180s

#### safe_delay_180s — rate_bin (marginal)

| rate_bin | count | mean(safe_delay_180s) |
|---|---|---|
| first_breach | 172 | 0.698 |
| (0, 0.5] | 64 | 0.672 |
| (0.5, 0.8] | 327 | 0.566 |
| (0.8, 1.0] | 1405 | 0.638 |

#### safe_delay_180s — rate_bin × idx_bin (mean + n per cell)

| rate_bin \ idx_bin | 0 | 1-2 | 3-5 | 6+ |
|---|---|---|---|---|
| first_breach | 0.698 (n=172) | – | – | – |
| (0, 0.5] | – | 0.680 (n=50) | 0.625 (n=8) | 0.667 (n=6) |
| (0.5, 0.8] | – | – | 0.708 (n=130) | 0.472 (n=197) |
| (0.8, 1.0] | – | 0.672 (n=256) | 0.706 (n=231) | 0.611 (n=918) |

#### safe_delay_180s — rate_bin × time_bin (mean + n per cell)

| rate_bin \ time_bin | first_breach | ≤60s | 60-300s | 300-1800s | >1800s |
|---|---|---|---|---|---|
| first_breach | 0.698 (n=172) | – | – | – | – |
| (0, 0.5] | – | – | – | – | 0.672 (n=64) |
| (0.5, 0.8] | – | – | – | – | 0.566 (n=327) |
| (0.8, 1.0] | – | – | – | – | 0.638 (n=1405) |


## Interpretation

### Observations (from the tables above)

- LR ΔPR-AUC when removing only `prior_rejection_rate_on_level`:
  - safe_delay_15s: +0.001
  - safe_delay_30s: +0.001
  - safe_delay_60s: +0.001
  - safe_delay_180s: +0.000
- LR ΔPR-AUC when removing all four level-history MVP features:
  - safe_delay_15s: +0.000
  - safe_delay_30s: +0.000
  - safe_delay_60s: +0.004
  - safe_delay_180s: +0.002

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
