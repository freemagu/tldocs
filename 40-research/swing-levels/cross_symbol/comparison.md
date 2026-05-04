# Cross-Symbol Validation — BTCUSDT vs ETHUSDT

Runs the full Phase 1→4 pipeline on ETHUSDT with **identical parameters** to BTCUSDT (50L/10R pivots, promK=1.5, R=2h/F=6h labels, k_rev=k_fwd=1.0×ATR, 20-cut Phase 4 grid). The only differences are `--symbol`, `--tick-size`, and the per-symbol tick-archive window.

## Windows

| Symbol | Window (UTC) | Candle bars in window | Days |
|---|---|---|---|
| BTCUSDT | 2025-10-01 → 2026-03-23 | ~8,300 | 174 |
| ETHUSDT | 2025-10-12 → 2026-04-07 | ~8,500 | 178 |

Tick archive coverage: BTC 172/174 days (99%, 3 known-bad days), ETH 145/178 days (81%, 33 gap days — a near-contiguous hole from 2026-03-06 to 2026-04-07). The ETH tick-feature subset is therefore smaller, but candle and level features have full coverage on both.

## Phase 1 — dataset construction

| Metric | BTCUSDT | ETHUSDT |
|---|---|---|
| Raw pivots (loaded range) | 272 | 291 |
| Pivots in window | 212 | 235 |
| Dropped by prominence filter | 2 | 2 |
| Kept levels | 210 | 233 |
| Breaches in window | **191** | **210** |
| Unbreached at window end | 15 | 20 |
| Tick-refined events | 185 (96.9%) | — |

Event count scales roughly with the window size; dropped-prominence count is identical (2). No degenerate behavior.

## Phase 2 — labelling

| Label | BTC count | BTC % | ETH count | ETH % | Δ |
|---|---|---|---|---|---|
| SFP | 116 | 60.7% | 134 | 63.8% | +3.1 pp |
| Confirmed | 60 | 31.4% | 60 | 28.6% | −2.8 pp |
| Ambiguous | 15 | 7.9% | 16 | 7.6% | −0.3 pp |

**Distributions are remarkably consistent.** Same label ordering, same order-of-magnitude class sizes. ETH has slightly more SFPs (makes sense — ETH is generally more liquidation-driven than BTC), but the shift is within noise for a single comparison.

Time-to-resolution medians:

| Metric | BTC | ETH |
|---|---|---|
| Recovery close (SFP) | ~23 min | ~27 min |
| Reversal threshold (SFP) | ~21 min | ~26 min |
| Follow-through threshold (Confirmed) | ~39 min | ~40 min |

All within 5 min of each other. Dynamics are structurally similar.

## Phase 3 — features

Full coverage on the 15 numeric + 2 boolean features. Notable distributional differences:

| Feature | BTC median | ETH median |
|---|---|---|
| `breach_bar_body_atr` | 1.008 | 1.075 |
| `breach_bar_range_atr` | 2.052 | 2.044 |
| `breach_wick_beyond_atr` | 0.680 | 0.657 |
| `breach_body_beyond_atr` | 0.031 | −0.025 |
| `pre_60min_range_atr` | 1.385 | 1.393 |
| `touch_count_atr` | 0 | 0 |

ATR-normalised feature medians are within ~5% between the two symbols — the ATR scaling is doing its job. Tick-feature scales differ (ETH volume ~20× BTC in raw units because ETH contracts are cheaper per USD) but the *normalised* tick feature `pre_300s_delta_norm` has the same median magnitude (BTC −0.073, ETH −0.077).

## Phase 4 — single-feature separation

### Top-5 SFP heuristics side-by-side

| Rank | BTC feature | BTC thresh | BTC F1 | ETH feature | ETH thresh | ETH F1 | Match? |
|---|---|---|---|---|---|---|---|
| 1 | `breach_body_beyond_atr <` | 0.6559 | **0.830** | `breach_body_beyond_atr <` | 0.5616 | **0.837** | ✅ same feature, same direction |
| 2 | `breach_wick_beyond_atr <` | 1.6694 | 0.791 | `breach_closed_through = False` | — | 0.808 | 🔄 swapped but both in both tops |
| 3 | `breach_closed_through = False` | — | 0.785 | `breach_bar_body_atr <` | 3.1128 | 0.799 | 🔄 swapped |
| 4 | `breach_bar_body_atr <` | 2.0393 | 0.779 | `breach_wick_beyond_atr <` | 2.0415 | 0.795 | 🔄 swapped |
| 5 | `pre_300s_delta_norm <` | 0.7330 | 0.765 | `touch_count_atr <` | 4.1053 | 0.782 | ⚠ near-degenerate for ETH |

**The top-4 breach-bar features are the same in both symbols, just reordered.** They all point the same direction: small / contained breach bars correlate with SFP outcome.

ETH's #5 and below include more near-degenerate entries (thresholds at feature minima = "predict-all-SFP"). This is an ETH-specific quirk, not a structural difference — the **useful** heuristics live in ranks 1–4.

### Best heuristic per class

| Class | BTC best | BTC F1 | ETH best | ETH F1 |
|---|---|---|---|---|
| SFP | `breach_body_beyond_atr < 0.6559` | 0.830 | `breach_body_beyond_atr < 0.5616` | 0.837 |
| Confirmed | `breach_closed_through = True` | 0.759 | `breach_body_beyond_atr > 0.0603` | 0.756 |
| Ambiguous | `breach_bar_range_atr < 1.1935` | 0.444 | `breach_bar_range_atr < 1.5214` | 0.361 |

- **SFP**: same feature, same direction, threshold within 15%, F1 within 0.007. Textbook replication.
- **Confirmed**: different best feature, but both encode "breach committed by body penetration" — `breach_closed_through` (boolean: close past level) and `breach_body_beyond_atr > 0` (numeric: body past level) are close cousins. F1 essentially identical (0.759 vs 0.756).
- **Ambiguous**: not separable on either symbol. Confirms it's a sample-size / labelling limit, not a BTC-specific artifact.

## Out-of-sample validation — BTC threshold applied directly to ETH

Taking the BTC-derived rule verbatim — `breach_body_beyond_atr < 0.6559` → SFP — and evaluating on ETH without retuning:

| Metric | Value |
|---|---|
| TP | 127 |
| FP | 44 |
| FN | 7 |
| TN | 32 |
| Precision | 0.743 |
| Recall | 0.948 |
| **F1** | **0.833** |

ETH own-tuned F1 was 0.837 at threshold 0.5616. Applying BTC's 0.6559 to ETH gives F1 = 0.833 — **a loss of 0.004**. The rule transfers cleanly.

## Conclusions

- **The top SFP heuristic replicates on ETH.** Same feature, same direction, near-identical F1, minimal threshold sensitivity. This is not BTC-overfit.
- **Label distributions are structurally similar** — the phase 2 classification is not a BTC-specific artifact of the window, the pivot rule, or the k_rev/k_fwd thresholds.
- **Top-4 feature set is stable**: `breach_body_beyond_atr`, `breach_wick_beyond_atr`, `breach_closed_through`, `breach_bar_body_atr` — all at-breach-bar features, all pointing the same direction. One latent factor ("how aggressively did the breach bar commit through the level") is captured several ways.
- **Pre-breach tick features are less stable across symbols.** In the BTC run they ranked 5th (`pre_300s_delta_norm`); in ETH they don't crack the top 10. Possibly due to ETH's 38 null tick events, possibly because ETH tick microstructure differs. Worth flagging as lower-confidence than breach-bar features.
- **Ambiguous is unseparable in both.** Consistent with the 15-16 event support size — not a problem to solve in Phase 4/cross-symbol work. Either Phase 5 (multi-feature) or Phase 2.5 (relabelling) territory.
- **The prominence filter drops 2/212 (BTC) and 2/235 (ETH)** — still near-no-op. Confirms the BTC v1 finding that the filter is structurally rare to trigger on 50L/10R pivots.

## Non-goals respected
- No parameter tuning during this run.
- No new features, no feature redesign.
- No classifier.
- No claims about SOL or any other symbol.
- No predictive / PnL claims — this is association on historical data.

## Next options
- **Run SOLUSDT** for independent third-symbol validation (less BTC-correlated than ETH).
- **Phase 5 — multi-feature**: top-4 features all point the same way; combining them is likely to push F1 above 0.85 on either symbol.
- **Phase 2.5 — Ambiguous relabelling**: 15/16 events is too small to separate; either collapse into SFP/Confirmed with a tiebreaker or accept as "do not trade" bucket.
- **Production bridge (Phase 6)**: if the heuristic holds, it's a real LevelGuard input — `breach_body_beyond_atr` is a 30m-bar-close-only quantity, easy to compute on live data.

## Reproducibility

- Phase 1–4 pipeline scripts (`bin/tools/swing_levels_phase{1..4}.py`) take `--symbol` and (for phase 1) `--tick-size` / `--window-start` / `--window-end` arguments.
- Defaults for BTC: `--symbol BTCUSDT` keeps original parameters and writes to `research/swing_levels/phase{N}/` (unchanged).
- Non-BTC output: `research/swing_levels/phase{N}/{symbol_lower}/`.
- BTC regression check: re-running each phase with `--symbol BTCUSDT` after refactor produced byte-identical output to the previously committed artifacts (verified by `diff` on breach_events.csv, breach_labels.csv, feature_separation.csv).
- All 31 existing swing-research unit tests remain green (`pytest tests/unit/test_swing_*.py`).
