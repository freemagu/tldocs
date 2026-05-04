# Phase 4 Top Cutoffs — ranked by F1

Best 10 single-feature heuristics (feature × positive-class) by F1, one-vs-rest. **These are associations, not predictions.** No classifier, no multi-feature combinations. Baselines below.

Class priors (positive-rate baselines): SFP=0.607, Confirmed=0.314, Ambiguous=0.079

| rank | feature | positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `breach_body_beyond_atr` | SFP | < | 0.6559 | **0.830** | 0.738 | 0.948 | 116 | 191 | 0 |
| 2 | `breach_wick_beyond_atr` | SFP | < | 1.6694 | **0.791** | 0.679 | 0.948 | 116 | 191 | 0 |
| 3 | `breach_closed_through` | SFP | < | 0.0526 | **0.785** | 0.882 | 0.707 | 116 | 191 | 0 |
| 4 | `breach_bar_body_atr` | SFP | < | 2.0393 | **0.779** | 0.689 | 0.897 | 116 | 191 | 0 |
| 5 | `pre_300s_delta_norm` | SFP | < | 0.7330 | **0.765** | 0.620 | 1.000 | 114 | 185 | 6 |
| 6 | `breach_bar_range_atr` | SFP | < | 4.1555 | **0.760** | 0.637 | 0.940 | 116 | 191 | 0 |
| 7 | `breach_closed_through` | Confirmed | > | 0.0000 | **0.759** | 0.612 | 1.000 | 60 | 191 | 0 |
| 8 | `touch_count_atr` | SFP | < | 4.1053 | **0.759** | 0.615 | 0.991 | 116 | 191 | 0 |
| 9 | `pre_300s_volume` | SFP | > | 45.0130 | **0.758** | 0.614 | 0.991 | 114 | 185 | 6 |
| 10 | `pre_300s_delta` | SFP | > | -1220.0970 | **0.758** | 0.614 | 0.991 | 114 | 185 | 6 |

## Interpretation anchors

Predicting the prior-class blindly (majority-vote on SFP) gives F1 = 2·0.607·1.0/(0.607+1.0) ≈ 0.755 on SFP, 0.0 on the others. A heuristic that beats the prior-baseline meaningfully must score higher *and* show non-degenerate precision/recall split (i.e. not just predicting the majority class).

## Best heuristic per class

- **SFP**: `breach_body_beyond_atr < 0.6559` → F1=0.830 (prec=0.738, recall=0.948)
- **Confirmed**: `breach_closed_through > 0.0000` → F1=0.759 (prec=0.612, recall=1.000)
- **Ambiguous**: `breach_bar_range_atr < 1.1935` → F1=0.444 (prec=0.333, recall=0.667)

