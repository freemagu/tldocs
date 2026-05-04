# Phase 3 Design — Layer B Prediction (BTC MVP)

**Scope**: predict the four Layer B targets `safe_delay_{15,30,60,180}s` on the 2,082 tick-available BTC events that survive the Phase 2 `sequence_uncertain` filter. ETH and any feature-extension work are Phase 3.5+.

This doc is the locked spec for the BTC-only MVP. Any deviation must be recorded as a new dated revision.

---

## 1. Leakage rule (load-bearing)

> A feature is admissible iff **every scalar it depends on is known strictly at or before `breach_ts`**.

All four targets share a single feature matrix. This means every feature is usable for the tightest-horizon target (`safe_delay_15s`), which rules out any post-breach data whatsoever. Worth the small signal loss on the 180s model for a zero-bug leakage guarantee.

Explicit exclusions:

- All `max_{adverse,favourable}_within_Ns_atr` — outcomes of the observation window.
- All `first_{touch,cross}_back_seconds` — label generators.
- `market_label`, `market_label_bar_fallback`, sibling `safe_delay_*` — label leakage.
- Full-window / end-of-window fields.
- `tick_count_in_observation` / `window_covered_seconds`.
- `same_bar_event` — 100% constant on the re-armed dataset. A unit-test sentinel asserts this remains constant; the feature-row composer does not include it.
- `sequence_uncertain` — row-level filter, not a feature.

---

## 2. MVP feature bundle (18 columns)

| # | Column | Category | Source |
|---|---|---|---|
| 1 | `swing_type_high` | level context | one-hot of `swing_type` |
| 2 | `seconds_since_level_confirmed_log` | multi-breach / level | `log1p(seconds_since_level_confirmed)` |
| 3 | `breach_hour_utc` | level context | integer 0–23 (training script adds sin/cos for LR; GBM uses raw) |
| 4 | `breach_idx_on_level` | multi-breach | Phase 2 CSV |
| 5 | `seconds_since_previous_breach_log` | multi-breach | `log1p(seconds_since_previous_breach)`; `-1.0` sentinel for first breach |
| 6 | `total_prior_breaches_on_level` | multi-breach | Phase 2 CSV |
| 7 | `prior_rejection_rate_on_level` | multi-breach | `total_prior_rejections / max(total_prior_breaches, 1)`; 0.0 for first breach |
| 8 | `breach_magnitude_at_tick_atr` | breach shape | `(first_crossing_tick_price − level_price) / atr_anchor`, signed toward breach direction |
| 9 | `breach_ts_position_in_bar_frac` | breach shape | `(breach_ts − bar_open).seconds / 1800` |
| 10 | `bar_so_far_range_atr` | breach shape | `(max_price_before_breach − min_price_before_breach) / atr_anchor`, from ticks in `[bar_open, breach_ts)` |
| 11 | `prior_bar_range_atr` | breach shape | `(prev_bar.high − prev_bar.low) / atr_anchor` |
| 12 | `prior_bar_body_atr` | breach shape | `abs(prev_bar.close − prev_bar.open) / atr_anchor` |
| 13 | `approach_velocity_4bar_atr` | breach shape | `(bar_open.open − bar[−4].open) / atr_anchor`, signed toward breach direction |
| 14 | `pre_velocity_atr_60s` | microstructure | `(last_price − first_price) / atr_anchor` over ticks in `[breach_ts − 60s, breach_ts)`, signed toward breach direction |
| 15 | `pre_velocity_atr_15s` | microstructure | same formula over 15s |
| 16 | `pre_volume_60s` | microstructure | `sum(tick.size)` over `[breach_ts − 60s, breach_ts)` |
| 17 | `pre_delta_60s` | microstructure | `sum(±tick.size) / pre_volume_60s` over 60s (+1 Buy, −1 Sell); `0.0` when volume is zero |
| 18 | `pre_tick_count_60s` | microstructure | `len(ticks)` over 60s |

**Dropped from the earlier draft** (per revision):
- `atr_anchor_abs` — raw-scale feature, captured implicitly by the log-time features and ATR-normalized others.
- `previous_breach_first_cross_back_seconds_log` — sparse (NaN for first breaches), related signal partially captured by `prior_rejection_rate_on_level`.
- `previous_breach_market_label_rejected` — redundant with `prior_rejection_rate_on_level` on a per-level basis.

**Deferred to Phase 3.5** (not in MVP, documented for visibility):
- `pre_large_tick_count_300s`, `pre_vol_atr_60s`, `pre_velocity_atr_5s`
- `bar_so_far_direction`, `prior_bar_close_position`
- `regime_vol_4h_atr`
- Cyclic encodings and interaction features beyond what the training script does internally

---

## 3. Signed-toward-breach convention

For any directional magnitude feature (velocity, approach, breach magnitude), the sign is positive when the quantity points **toward** the breach direction.

| swing_type | convention |
|---|---|
| `high` | price-up is positive (breach direction is up) |
| `low`  | price-down is positive (breach direction is down) |

So `pre_velocity_atr_60s > 0` means the market was moving into the breach direction in the 60s before breach, regardless of whether the level is a swing high or swing low.

---

## 4. Evaluation methodology

### 4.1 Splits (both are required; reported side-by-side)

| Split | Purpose |
|---|---|
| **GroupKFold(5)** grouped on `level_index` | Primary cross-validated generalization across levels. Random partition of level IDs into 5 folds; a level's events are in exactly one test fold. |
| **Grouped forward split** grouped on `level_index` **with time ordering** | Harsher deployability test. Sort level IDs by `level_confirmed_at_utc`, take the first 80% of levels (by level-confirmation time) as train and the last 20% as test. A level's events are in exactly one side, and every test-side level was confirmed strictly after every train-side level. |

### 4.2 Metrics (per target × per model × per fold, then aggregated mean ± std)

| Metric | Role |
|---|---|
| **PR-AUC** | **Primary.** Robust to imbalance; right metric for minority-class utility. |
| **F1 @ τ = 0.5** | **Primary reported operating point.** Fixed threshold, reproducible, no train-leakage of tuning. |
| F1 @ best-train-fold τ | **Secondary diagnostic only.** Threshold is chosen per fold from the train set and applied to that fold's test set. Reported for comparison, never used as the headline. |
| Precision, Recall @ τ = 0.5 | Standard. |
| Accuracy @ τ = 0.5 | Reported, not headline. |
| Brier score | Calibration. |
| Reliability (decile) | Calibration diagnostic. |

### 4.3 Baselines (per target, recomputed per fold on train, scored on test)

| Baseline | Predicts |
|---|---|
| `majority_class` | Constant: the majority label of `y_train`. |
| `prior_rate` | For a test row: `total_prior_rejections_on_level / max(total_prior_breaches_on_level, 1)` where priors are already carried in the row (these are cumulative pre-breach counts, no leakage). **For first-breach rows** (`breach_idx_on_level == 0`), predicts the global training-fold base rate of the target (not `0.5`). |
| `idx_only_logistic` | Single-feature logistic regression on `breach_idx_on_level`. |

### 4.4 Decision thresholds for MVP

The model bundle passes the MVP bar iff **every one** of the following holds on the GroupKFold mean:

1. PR-AUC > `majority_class` PR-AUC for all four targets.
2. PR-AUC ≥ `prior_rate` PR-AUC for at least two of four targets with fold-mean separation.
3. PR-AUC > `idx_only_logistic` PR-AUC for all four targets with fold-mean separation.

If the grouped forward split collapses (test PR-AUC near `majority_class`) while GroupKFold is healthy, that is evidence of temporal drift — flag but do not block.

### 4.5 Feature-importance stability

Reported per model family, per target, aggregated across the 5 GroupKFold folds:

| Family | Quantity | Aggregation |
|---|---|---|
| LogisticRegression | coefficient per feature | mean, std, count of sign-flips across folds |
| GradientBoosting | `feature_importances_` per feature | mean, std |

Output: a table per target ordered by absolute mean importance. A feature whose sign flips between folds is a flag for an unstable signal, not necessarily a bug, but worth naming before using it as a pillar in a narrative.

---

## 5. Model shape — four separate binary classifiers

Per target, train:
- `LogisticRegression` (L2, `class_weight='balanced'`) — linear baseline, interpretable.
- `GradientBoostingClassifier` (default depth=3, 100 estimators) — non-linear, handles interactions.

**Why separate**: decoupled operating points per bucket, independent calibration, failure isolation, trivially parallel training, cleaner feature-importance accounting. The `p_15 ≤ p_30 ≤ p_60 ≤ p_180` monotonicity is enforced post-hoc if consumed hard-labelled (`pred_30 OR= pred_15`, etc.).

**Revisit**: after MVP results, if the four models converge on the same feature-weight shape, consider a multi-output or ordinal regressor in Phase 3.5. Not before.

---

## 6. Pipeline layout

| Stage | Script | Input | Output | Runtime |
|---|---|---|---|---|
| Feature extraction | `bin/tools/swing_levels_phase3.py --symbol BTCUSDT` | `research/swing_levels/phase2/breach_labels.csv` + tick archive + `market_candle` | `research/swing_levels/phase3/features.csv` (2,082 × ~22: 18 features + identity cols + all 4 labels) | ~45 min (dominated by pre-breach tick loads) |
| Training + report | `bin/tools/swing_levels_phase3_train.py --symbol BTCUSDT` | `research/swing_levels/phase3/features.csv` | `research/swing_levels/phase3/phase3_results.md` + per-target importance tables | < 1 min |

Two stages because extraction is slow and iterative evaluation should not require re-extracting features.

---

## 7. Test plan (TDD — tests land before production code)

### 7.1 Test files

- `tests/unit/test_phase3_features.py` — pure feature functions + composer + leakage guard
- `tests/unit/test_phase3_evaluation.py` — splits, baselines, metrics, importance aggregation
- `tests/integration/test_phase3_pipeline.py` — end-to-end with mocked TickLoader

### 7.2 Tests

**Features** (`test_phase3_features.py`):

1. `test_pre_breach_microstructure_on_synthetic_ticks` — hand-built tick stream; assert `pre_tick_count_60s`, `pre_volume_60s`, `pre_delta_60s`, `pre_velocity_atr_60s`, `pre_velocity_atr_15s` match analytically computed values.
2. `test_microstructure_features_reject_post_breach_ticks` — include ticks with `ts >= breach_ts`; assert they are excluded from all `pre_*` features (leakage guard).
3. `test_breach_shape_features_on_synthetic_inputs` — bar + at-breach tick + prior bars; assert `breach_magnitude_at_tick_atr`, `breach_ts_position_in_bar_frac`, `bar_so_far_range_atr`, `prior_bar_range_atr`, `prior_bar_body_atr`, `approach_velocity_4bar_atr` match expected arithmetic.
4. `test_breach_shape_sign_symmetry_swing_low` — repeat #3 with `swing_type='low'`; directional features must flip sign relative to swing_high.
5. `test_multi_breach_derived_features_from_phase2_row_first_breach` — row with `breach_idx_on_level=0`; assert `seconds_since_previous_breach_log == -1.0` (sentinel), `prior_rejection_rate_on_level == 0.0`, `total_prior_breaches_on_level == 0`.
6. `test_multi_breach_derived_features_from_phase2_row_repeat_breach` — row with priors; assert derived values match analytical.
7. `test_feature_row_column_invariant` — composer output has EXACTLY the 18 `MVP_FEATURE_COLUMNS` in the fixed order; no extra, no missing, no post-breach column names.
8. `test_same_bar_event_is_constant_sentinel` — sanity: every Phase 2 row should have `same_bar_event=True`; if not, flag — the feature composer must not silently include it.

**Evaluation** (`test_phase3_evaluation.py`):

9. `test_grouped_kfold_respects_level_index` — synthetic 10 levels × 3 events; `GroupKFold(5)` never puts same `level_index` in both train and test of a fold.
10. `test_grouped_forward_split_respects_level_and_time` — synthetic levels with distinct `level_confirmed_at_utc`; assert (a) no `level_index` overlap between train and test, (b) every test-side level has `level_confirmed_at > every train-side level`.
11. `test_majority_baseline_metrics_are_expected` — known label distribution; assert majority predictor's precision/recall/F1 for the minority class = 0, accuracy = majority rate.
12. `test_prior_rate_baseline_uses_train_base_rate_for_first_breach` — synthetic train set with known base rate; test rows with `breach_idx_on_level=0` receive that base rate as their prediction, not 0.5.
13. `test_idx_only_baseline_returns_valid_probabilities` — fit on synthetic data; predictions ∈ [0, 1], sensible monotonicity.
14. `test_feature_importance_aggregation_across_folds` — feed three (features, importances) arrays; assert mean / std / sign-flip count match analytical.

**Integration** (`test_phase3_pipeline.py`):

15. `test_phase3_pipeline_smoke_5_events` — mock `TickLoader`; seed `market_candle` with synthetic bars; run the feature-extraction pipeline on 5 events; assert `features.csv` has 5 rows and exactly the 18 feature columns + identity + labels with no NaN in required columns.

### 7.3 Seams

| Dependency | Seam |
|---|---|
| `TickLoader.load()` | `monkeypatch.setattr(TickLoader, 'load', fake_load)` returning a canned `TickData` per call. |
| `market_candle` DB rows | `test_db_cursor` fixture; insert synthetic rows at test setup. |
| sklearn classifiers | Not mocked — trained on in-memory synthetic data per test. |

### 7.4 Commit gate

- All 15 tests green.
- Coverage ≥ 80% on the three new files.
- Commit message states Phase 3 MVP scope; no exemption category.

---

## 8. Non-goals (explicit)

- ETH / SOL / any multi-symbol training.
- The Phase 3.5 feature set (large-tick, regime vol, cyclic / interaction features beyond in-model handling).
- Ordinal / multi-output models.
- Neural networks.
- Production serving / Phase 4 integration into LevelGuard runtime.
- Refactoring Phase 4/5 legacy pipelines against the new Phase 2 schema.

---

## 9. Revision log

| Date | Rev | Change |
|---|---|---|
| 2026-04-24 | v1.0 | Initial lock. 18-feature MVP, fixed τ=0.5 headline F1, GroupKFold + grouped forward split, prior-rate baseline uses train base rate for first-breach rows, feature-importance stability reporting. |
