# Phase 3 Summary Stats — BTCUSDT 30m breach-event features

Source: `research/swing_levels/phase1/breach_events.csv`
Events processed: 191

## Numeric features (count / nulls / min / max / mean / median)

| feature | count | nulls | min | max | mean | median |
|---|---|---|---|---|---|---|
| `breach_bar_body_atr` | 191 | 0 | 0.006 | 12.045 | 1.457 | 1.008 |
| `breach_bar_range_atr` | 191 | 0 | 0.578 | 16.517 | 2.472 | 2.052 |
| `breach_wick_beyond_atr` | 191 | 0 | 0.000 | 6.667 | 0.949 | 0.680 |
| `breach_body_beyond_atr` | 191 | 0 | -3.750 | 6.590 | 0.155 | 0.031 |
| `pre_60min_range_atr` | 191 | 0 | 0.294 | 5.730 | 1.644 | 1.385 |
| `pre_120min_range_atr` | 191 | 0 | 0.486 | 8.074 | 2.246 | 1.784 |
| `pre_2h_velocity_atr_per_h` | 191 | 0 | -2.282 | 3.490 | -0.104 | -0.119 |
| `pre_300s_volume` | 185 | 6 | 45.013 | 12764.288 | 1125.723 | 691.807 |
| `pre_300s_delta` | 185 | 6 | -1220.097 | 2766.876 | 1.042 | -50.117 |
| `pre_300s_delta_norm` | 185 | 6 | -0.767 | 0.733 | -0.028 | -0.073 |
| `pre_300s_cvd_slope_per_s` | 185 | 6 | -4.067 | 9.224 | 0.004 | -0.168 |
| `pre_60s_tick_count` | 185 | 6 | 253.000 | 111528.000 | 9108.346 | 5834.000 |
| `level_age_hours` | 191 | 0 | 0.001 | 1702.783 | 105.095 | 15.018 |
| `touch_count_atr` | 191 | 0 | 0.000 | 6.000 | 0.812 | 0.000 |
| `touch_count_ticks` | 191 | 0 | 0.000 | 1.000 | 0.010 | 0.000 |

## Boolean features

| feature | True | False |
|---|---|---|
| `breach_closed_through` | 98 True | 93 False |
| `breach_bar_up` | 84 True | 107 False |

## Parameters (see phase3_parameters.md)
- Bar duration: 30 min
- Pre-breach candle bars: 4  (spans 2 h)
- Pre-breach tick window: 60 min (last 5 min used for tick features)
- ATR anchor: Phase 1 `level_atr_at_pivot` (ATR(14) at pivot bar)
- All values strictly pre-breach or at-breach. No post-breach data.
