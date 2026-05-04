# Phase 4 Top Cutoffs — ranked by F1

Best 10 single-feature heuristics (feature × positive-class) by F1, one-vs-rest. **These are associations, not predictions.** No classifier, no multi-feature combinations. Baselines below.

Class priors (positive-rate baselines): SFP=0.607, Confirmed=0.314, Ambiguous=0.079

| rank | feature | positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `breach_body_beyond_atr` | SFP | < | 0.5616 | **0.837** | 0.754 | 0.940 | 134 | 210 | 0 |
| 2 | `breach_closed_through` | SFP | < | 0.0526 | **0.808** | 0.915 | 0.724 | 134 | 210 | 0 |
| 3 | `breach_bar_body_atr` | SFP | < | 3.1128 | **0.799** | 0.683 | 0.963 | 134 | 210 | 0 |
| 4 | `breach_wick_beyond_atr` | SFP | < | 2.0415 | **0.795** | 0.681 | 0.955 | 134 | 210 | 0 |
| 5 | `touch_count_atr` | SFP | < | 4.1053 | **0.782** | 0.646 | 0.993 | 134 | 210 | 0 |
| 6 | `breach_bar_range_atr` | SFP | < | 10.2440 | **0.781** | 0.641 | 1.000 | 134 | 210 | 0 |
| 7 | `pre_60min_range_atr` | SFP | > | 0.3090 | **0.781** | 0.641 | 1.000 | 134 | 210 | 0 |
| 8 | `touch_count_ticks` | SFP | < | 0.0526 | **0.781** | 0.641 | 1.000 | 134 | 210 | 0 |
| 9 | `level_age_hours` | SFP | > | 0.0000 | **0.778** | 0.639 | 0.993 | 134 | 210 | 0 |
| 10 | `pre_120min_range_atr` | SFP | > | 0.5350 | **0.776** | 0.636 | 0.993 | 134 | 210 | 0 |

## Interpretation anchors

Predicting the prior-class blindly (majority-vote on SFP) gives F1 = 2·0.607·1.0/(0.607+1.0) ≈ 0.755 on SFP, 0.0 on the others. A heuristic that beats the prior-baseline meaningfully must score higher *and* show non-degenerate precision/recall split (i.e. not just predicting the majority class).

## Best heuristic per class

- **SFP**: `breach_body_beyond_atr < 0.5616` → F1=0.837 (prec=0.754, recall=0.940)
- **Confirmed**: `breach_body_beyond_atr > 0.0603` → F1=0.756 (prec=0.615, recall=0.983)
- **Ambiguous**: `breach_bar_range_atr < 1.5214` → F1=0.361 (prec=0.232, recall=0.812)

