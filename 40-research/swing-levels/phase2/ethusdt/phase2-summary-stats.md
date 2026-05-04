# Phase 2 Summary Stats — ETHUSDT multi-breach soft-stop labelling (v2)

Source: `research/swing_levels/phase1/ethusdt/levels_filtered.csv`
Window end: 2026-04-07T23:59:59 UTC
Events produced: 2781
Unique levels with at least one breach: 210
Max breaches observed on a single level: 52

## Multi-breach distribution (breach_idx_on_level)
| idx | count |
|---|---|
| 0 | 210 |
| 1 | 189 |
| 2 | 179 |
| 3 | 163 |
| 4 | 152 |
| 5 | 145 |
| 6 | 133 |
| 7 | 121 |
| 8 | 113 |
| 9 | 104 |
| 10 | 97 |
| 11 | 87 |
| 12 | 79 |
| 13 | 71 |
| 14 | 69 |
| 15 | 66 |
| 16 | 63 |
| 17 | 60 |
| 18 | 54 |
| 19 | 51 |
| 20 | 50 |
| 21 | 47 |
| 22 | 46 |
| 23 | 46 |
| 24 | 44 |
| 25 | 39 |
| 26 | 37 |
| 27 | 33 |
| 28 | 29 |
| 29 | 24 |
| 30 | 21 |
| 31 | 19 |
| 32 | 17 |
| 33 | 15 |
| 34 | 14 |
| 35 | 12 |
| 36 | 11 |
| 37 | 10 |
| 38 | 9 |
| 39 | 7 |
| 40 | 5 |
| 41 | 5 |
| 42 | 5 |
| 43 | 5 |
| 44 | 5 |
| 45 | 4 |
| 46 | 4 |
| 47 | 4 |
| 48 | 4 |
| 49 | 2 |
| 50 | 1 |
| 51 | 1 |

## Layer A — market_label (tick-derived only; NULL on tick-gap)
- rejected:     1731
- not_rejected: 237
- NULL (tick-gap; see `market_label_bar_fallback` for diagnostic): 813

### Diagnostic `market_label_bar_fallback` (tick-gap events only)
- rejected:     810
- not_rejected: 3

## Layer B — smallest_safe_bucket (reporting only; training targets are the 4 booleans)
- safe_delay_15s: 615
- safe_delay_30s: 177
- safe_delay_60s: 192
- safe_delay_180s: 260
- unsafe_to_delay: 724
- unknown: 813

## Data quality flags
- tick_data_available=True:  1968 (70.8%)
- sequence_uncertain=True:   813 (29.2%)
- same_bar_event=True:       2781 (100.0%)

## Recovery timing
- Median first_cross_back_seconds (tick-available only): 202.7 s

## Blocking downstream invariants (see phase2_parameters.md)
- Train/test splits MUST stratify on `level_index` to avoid same-level leakage.
- Layer B training MUST exclude `sequence_uncertain=True` events by default.
- Adverse excursion is NEVER a Layer B gating rule.
- `market_label_bar_fallback` is diagnostic only; do not read in place of `market_label`.
