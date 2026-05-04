# Phase 2 Summary Stats — BTCUSDT multi-breach soft-stop labelling (v2)

Source: `research/swing_levels/phase1/levels_filtered.csv`
Window end: 2026-03-23T23:59:59 UTC
Events produced: 2092
Unique levels with at least one breach: 191
Max breaches observed on a single level: 40

## Multi-breach distribution (breach_idx_on_level)
| idx | count |
|---|---|
| 0 | 191 |
| 1 | 170 |
| 2 | 154 |
| 3 | 137 |
| 4 | 122 |
| 5 | 111 |
| 6 | 104 |
| 7 | 99 |
| 8 | 93 |
| 9 | 85 |
| 10 | 78 |
| 11 | 70 |
| 12 | 64 |
| 13 | 61 |
| 14 | 59 |
| 15 | 55 |
| 16 | 51 |
| 17 | 45 |
| 18 | 40 |
| 19 | 34 |
| 20 | 30 |
| 21 | 29 |
| 22 | 27 |
| 23 | 22 |
| 24 | 20 |
| 25 | 17 |
| 26 | 17 |
| 27 | 16 |
| 28 | 14 |
| 29 | 12 |
| 30 | 11 |
| 31 | 10 |
| 32 | 10 |
| 33 | 8 |
| 34 | 7 |
| 35 | 5 |
| 36 | 5 |
| 37 | 5 |
| 38 | 2 |
| 39 | 2 |

## Layer A — market_label (tick-derived only; NULL on tick-gap)
- rejected:     1849
- not_rejected: 233
- NULL (tick-gap; see `market_label_bar_fallback` for diagnostic): 10

### Diagnostic `market_label_bar_fallback` (tick-gap events only)
- rejected:     10
- not_rejected: 0

## Layer B — smallest_safe_bucket (reporting only; training targets are the 4 booleans)
- safe_delay_15s: 580
- safe_delay_30s: 187
- safe_delay_60s: 198
- safe_delay_180s: 325
- unsafe_to_delay: 792
- unknown: 10

## Data quality flags
- tick_data_available=True:  2082 (99.5%)
- sequence_uncertain=True:   10 (0.5%)
- same_bar_event=True:       2092 (100.0%)

## Recovery timing
- Median first_cross_back_seconds (tick-available only): 48.5 s

## Blocking downstream invariants (see phase2_parameters.md)
- Train/test splits MUST stratify on `level_index` to avoid same-level leakage.
- Layer B training MUST exclude `sequence_uncertain=True` events by default.
- Adverse excursion is NEVER a Layer B gating rule.
- `market_label_bar_fallback` is diagnostic only; do not read in place of `market_label`.
