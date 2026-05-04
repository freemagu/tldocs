# Phase 3 Summary Stats — ETHUSDT 30m breach-event features

Source: `research/swing_levels/phase1/ethusdt/breach_events.csv`
Events processed: 210

## Numeric features (count / nulls / min / max / mean / median)

| feature | count | nulls | min | max | mean | median |
|---|---|---|---|---|---|---|
| `breach_bar_body_atr` | 210 | 0 | 0.008 | 7.067 | 1.412 | 1.075 |
| `breach_bar_range_atr` | 210 | 0 | 0.568 | 10.244 | 2.515 | 2.044 |
| `breach_wick_beyond_atr` | 210 | 0 | 0.001 | 5.681 | 1.014 | 0.657 |
| `breach_body_beyond_atr` | 210 | 0 | -2.505 | 4.921 | 0.132 | -0.025 |
| `pre_60min_range_atr` | 210 | 0 | 0.309 | 8.305 | 1.679 | 1.393 |
| `pre_120min_range_atr` | 210 | 0 | 0.535 | 8.675 | 2.211 | 1.866 |
| `pre_2h_velocity_atr_per_h` | 210 | 0 | -3.581 | 3.725 | -0.101 | -0.078 |
| `pre_300s_volume` | 172 | 38 | 2808.010 | 499513.260 | 24754.892 | 16632.610 |
| `pre_300s_delta` | 172 | 38 | -31573.750 | 24523.270 | -2092.504 | -1153.370 |
| `pre_300s_delta_norm` | 172 | 38 | -0.758 | 0.712 | -0.054 | -0.077 |
| `pre_300s_cvd_slope_per_s` | 172 | 38 | -107.553 | 81.829 | -6.994 | -3.846 |
| `pre_60s_tick_count` | 172 | 38 | 1037.000 | 185821.000 | 10376.983 | 6872.000 |
| `level_age_hours` | 210 | 0 | 0.000 | 1695.178 | 79.460 | 13.024 |
| `touch_count_atr` | 210 | 0 | 0.000 | 6.000 | 0.786 | 0.000 |
| `touch_count_ticks` | 210 | 0 | 0.000 | 1.000 | 0.005 | 0.000 |

## Boolean features

| feature | True | False |
|---|---|---|
| `breach_closed_through` | 104 True | 106 False |
| `breach_bar_up` | 100 True | 110 False |

## Parameters (see phase3_parameters.md)
- Bar duration: 30 min
- Pre-breach candle bars: 4  (spans 2 h)
- Pre-breach tick window: 60 min (last 5 min used for tick features)
- ATR anchor: Phase 1 `level_atr_at_pivot` (ATR(14) at pivot bar)
- All values strictly pre-breach or at-breach. No post-breach data.
