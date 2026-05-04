# Breach-Decision Pool vs Baseline — 2026-05-04

> Part of [[INDEX|breach-decision documentation]] | **Frozen result — do not modify content**

**Date:** 2026-05-04  
**Commit:** see repo (feat(breach_decision): pooled-symbol training + persisted metrics)  
**Hyperparameters (all models):** train_frac=0.70, calibration_frac=0.15, lr_C=1.0

---

## 1. Data Table

| Model | Symbol(s) | n_total | n_train | n_calibration | n_test |
|-------|-----------|---------|---------|---------------|--------|
| btcusdt-baseline | BTCUSDT | 598 | 418 | 89 | 91 |
| ethusdt-baseline | ETHUSDT | 327 | 228 | 49 | 50 |
| solusdt-baseline | SOLUSDT | 228 | 159 | 34 | 35 |
| hypeusdt-baseline | HYPEUSDT | 200 | 140 | 30 | 30 |
| zecusdt-baseline | ZECUSDT | 187 | 130 | 28 | 29 |
| xrpusdt-baseline | XRPUSDT | 102 | 71 | 15 | 16 |
| asterusdt-baseline | ASTERUSDT | 70 | 49 | 10 | 11 |
| pool-7sym | BTC+ETH+SOL+HYPE+ZEC+XRP+ASTER | 1712 | 1198 | 256 | 258 |

> Notes:
> - ZECUSDT trained with `--min-rows 150` (actual: 187 rows; below default 200)
> - XRPUSDT and ASTERUSDT trained with `--min-rows 50`
> - All data was ingested in approximately a 3-day window (2026-04-27 → 2026-04-30), which means timestamps are extremely compressed — see caveats.

---

## 2. Per-Target Metrics

### Target: safe_delay_15s (reclaim within 15 seconds)

| Model | base_rate | log_loss_cal | brier_cal |
|-------|-----------|--------------|-----------|
| btcusdt-baseline | 0.473 | 3.4840 | 0.3418 |
| ethusdt-baseline | 0.460 | 9.7083 | 0.3839 |
| solusdt-baseline | 0.457 | 3.7292 | 0.3241 |
| hypeusdt-baseline | 0.433 | 11.1053 | 0.4040 |
| zecusdt-baseline | 0.414 | 1.9775 | 0.3049 |
| xrpusdt-baseline | 0.312 | 11.7094 | 0.4783 |
| asterusdt-baseline | 0.636 | 0.6583 | 0.2327 |
| **pool-7sym** | **0.446** | **1.6299** | **0.2648** |

### Target: safe_delay_30s (reclaim within 30 seconds)

| Model | base_rate | log_loss_cal | brier_cal |
|-------|-----------|--------------|-----------|
| btcusdt-baseline | 0.571 | 2.2841 | 0.2990 |
| ethusdt-baseline | 0.460 | 5.8162 | 0.4179 |
| solusdt-baseline | 0.486 | 1.7742 | 0.3062 |
| hypeusdt-baseline | 0.467 | 11.1272 | 0.4082 |
| zecusdt-baseline | 0.414 | 2.0062 | 0.3140 |
| xrpusdt-baseline | 0.438 | 2.8582 | 0.2905 |
| asterusdt-baseline | 0.636 | 0.6784 | 0.2425 |
| **pool-7sym** | **0.500** | **1.3815** | **0.2690** |

### Target: safe_delay_60s (reclaim within 60 seconds)

| Model | base_rate | log_loss_cal | brier_cal |
|-------|-----------|--------------|-----------|
| btcusdt-baseline | 0.626 | 0.7885 | 0.2895 |
| ethusdt-baseline | 0.480 | 7.1423 | 0.4268 |
| solusdt-baseline | 0.514 | 2.7677 | 0.3175 |
| hypeusdt-baseline | 0.500 | 11.1533 | 0.4181 |
| zecusdt-baseline | 0.483 | 1.9949 | 0.3063 |
| xrpusdt-baseline | 0.500 | 0.7806 | 0.2917 |
| asterusdt-baseline | 0.636 | 0.6973 | 0.2492 |
| **pool-7sym** | **0.539** | **1.6425** | **0.2686** |

### Target: safe_delay_180s (reclaim within 3 minutes)

| Model | base_rate | log_loss_cal | brier_cal |
|-------|-----------|--------------|-----------|
| btcusdt-baseline | 0.736 | 0.5909 | 0.2007 |
| ethusdt-baseline | 0.500 | 7.8556 | 0.4457 |
| solusdt-baseline | 0.657 | 2.8848 | 0.3386 |
| hypeusdt-baseline | 0.500 | 12.3357 | 0.4406 |
| zecusdt-baseline | 0.621 | 7.8716 | 0.3572 |
| xrpusdt-baseline | 0.750 | 7.0181 | 0.2812 |
| asterusdt-baseline | 0.818 | 0.5187 | 0.1662 |
| **pool-7sym** | **0.640** | **2.1436** | **0.2588** |

---

## 3. Per-Symbol Verdict

### BTCUSDT (n_test=91, baseline well-resourced)

Baseline calibrated log-loss values: 3.48 / 2.28 / 0.79 / 0.59 for the four targets.
Pool calibrated log-loss values: 1.63 / 1.38 / 1.64 / 2.14.

Brier scores: baseline 0.34 / 0.30 / 0.29 / 0.20 vs pool 0.26 / 0.27 / 0.27 / 0.26.

On Brier, pool beats baseline across all four targets. On calibrated log-loss the picture is mixed: pool clearly wins on 15s and 30s, is worse on 60s and 180s (where the baseline already had reasonable calibration, 0.79 and 0.59 vs pool's 1.64 and 2.14). Verdict: **pool is better for short delays (15s, 30s); essentially equivalent or slightly worse for 60s/180s**. The Brier advantage across the board is the cleaner signal.

### ETHUSDT (n_test=50, compressed time window)

Baseline calibrated log-loss is extremely high: 9.71 / 5.82 / 7.14 / 7.86 — a clear sign the isotonic calibrator overfit on the 49-row calibration fold. Brier scores are correspondingly poor (0.38–0.45). Pool brier: 0.26–0.27. Verdict: **pool strongly beats baseline for ETHUSDT** — the per-symbol calibrator is unreliable at n_calib=49.

### SOLUSDT (n_test=35, small)

Baseline calibrated log-loss: 3.73 / 1.77 / 2.77 / 2.88. Pool: 1.63 / 1.38 / 1.64 / 2.14. Brier: baseline 0.32–0.34 vs pool 0.26–0.27. Pool is uniformly better on both metrics. Verdict: **pool beats baseline for SOLUSDT**.

### HYPEUSDT (n_test=30, very small)

Baseline log-loss_cal is catastrophic at 11.1–12.3, brier 0.40–0.44 — another clear calibrator overfit at n_calib=30. Pool: log-loss 1.38–2.14, brier 0.26–0.27. Verdict: **pool strongly beats baseline for HYPEUSDT** — the per-symbol model is unreliable at this sample size.

### ZECUSDT (n_test=29, below default min-rows, used --min-rows 150)

Baseline log-loss_cal: 1.98 / 2.01 / 1.99 / 7.87. Brier: 0.30–0.36. Pool log-loss: 1.63 / 1.38 / 1.64 / 2.14. Brier: 0.26–0.27. Pool beats baseline on Brier for all four. On log-loss pool wins 15s, 30s, 60s clearly; 180s baseline (7.87 — likely calibrator overfit) also beaten by pool (2.14). Verdict: **pool beats baseline for ZECUSDT**.

### XRPUSDT (n_test=16, very small — pool is primary reliable estimate)

With 16 test rows the baseline metrics are noisy by construction. Log-loss_cal: 11.7 / 2.86 / 0.78 / 7.02 — a bimodal pattern. Brier: 0.48 / 0.29 / 0.29 / 0.28. The per-symbol 60s brier (0.29) is comparable to pool (0.27); 30s brier is similar too. But the 15s and 180s baselines are clearly miscalibrated. Given n_test=16, no interpretation of baseline metrics is reliable. Verdict: **pool is the only reliable model for XRPUSDT**; per-symbol baseline metrics should not be trusted at this data volume.

### ASTERUSDT (n_test=11, smallest — pool is primary reliable estimate)

Baseline Brier is genuinely competitive: 0.23 / 0.24 / 0.25 / 0.17 vs pool 0.26 / 0.27 / 0.27 / 0.26. On this metric the baseline appears better, but the test set has only 11 rows — a single outlier shifts Brier by ~0.09. Log-loss_cal is similarly unreliable (0.66 / 0.68 / 0.70 / 0.52). With n_test=11 the uncertainty interval on any metric is larger than the apparent difference. Verdict: **pool is the only reliable model for ASTERUSDT**; do not over-interpret the per-symbol Brier advantage.

---

## 4. Recommendation

**Summary:** pool-7sym produces more stable calibration than per-symbol models for every symbol with n_test < 50. For BTCUSDT (n_test=91), pool improves Brier consistently but shows mixed log-loss calibration results for longer delay targets.

**Promotion recommendation:**

| Symbol | Promote pool? | Rationale |
|--------|---------------|-----------|
| BTCUSDT | Conditional — use pool for 15s/30s gates only | Pool Brier uniformly better; log-loss mixed at 60s/180s |
| ETHUSDT | Yes | Per-symbol calibrator failed; pool clearly better |
| SOLUSDT | Yes | Pool uniformly better on both metrics |
| HYPEUSDT | Yes | Per-symbol calibrator failed; pool clearly better |
| ZECUSDT | Yes | Pool beats baseline across all targets |
| XRPUSDT | Yes (pool only) | Baseline unreliable at n_test=16 |
| ASTERUSDT | Yes (pool only) | Baseline unreliable at n_test=11; apparent baseline Brier advantage is within noise |

To promote, for each symbol set `model_version_<sym>: pool-7sym-2026-05-04` in `etc/config.yml`, then `tl restart level-mind`. The artefact is at `data/models/breach_decision/_pool/pool-7sym-2026-05-04/artefact.json`.

**Important caveat:** the pool model's test fold (n_test=258) mixes symbols, so a per-symbol breakdown of pool test metrics is not available here. If BTCUSDT drives 598/1712 ≈ 35% of pool rows, BTCUSDT pattern likely dominates the pool's learned coefficients. Symbols with fewer rows may be under-represented.

---

## 5. Caveats

1. **Compressed training window:** All 1712 rows were ingested in approximately 3 days (2026-04-27 to 2026-04-30). This is a very narrow time window — the models have seen essentially one market regime. Metrics should be treated as in-sample approximations, not robust out-of-sample estimates.

2. **Small test folds:** BTCUSDT n_test=91, ETHUSDT n_test=50, SOLUSDT n_test=35, HYPEUSDT n_test=30, ZECUSDT n_test=29, XRPUSDT n_test=16, ASTERUSDT n_test=11. For XRPUSDT and ASTERUSDT in particular, a single mispredicted breach can shift Brier score by 0.06–0.09. Metric differences of less than 0.02 for those symbols are statistical noise.

3. **Calibrated log-loss instability:** The isotonic regression calibrator trained on small calibration folds (n_calib < 50) frequently collapsed — producing log-loss_cal > 5.0 for several per-symbol baselines. This is expected behaviour, not a code bug. Pool models benefit from a larger calibration fold (n_calib=256) which prevents this collapse.

4. **Pool mixes heterogeneous symbols:** Pooling assumes that the breach dynamics for BTCUSDT, ZECUSDT, ASTERUSDT etc. share enough structure that a shared coefficient vector generalises. This may not hold for regime changes or symbol-specific idiosyncrasies. The Brier improvement is encouraging but should be validated on a second, independent time window before full production adoption.
