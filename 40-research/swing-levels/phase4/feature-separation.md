# Phase 4 Feature Separation — per-feature detail

Per-class descriptive stats and the best single-cutoff F1 for each (feature × positive-class), one-vs-rest.

Non-null support only. Nulls reported separately per class.

## `breach_bar_body_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 1.175 | 0.786 | 0.210 | 0.418 | 1.420 | 2.099 |
| Confirmed | 60 | 0 | 2.204 | 1.921 | 0.839 | 1.240 | 2.688 | 3.647 |
| Ambiguous | 15 | 0 | 0.652 | 0.325 | 0.107 | 0.167 | 0.522 | 1.513 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 2.0393 | 0.779 | 0.689 | 0.897 | 116 | 191 | 0 |
| Confirmed | > | 0.9441 | 0.642 | 0.515 | 0.850 | 60 | 191 | 0 |
| Ambiguous | < | 0.6256 | 0.348 | 0.222 | 0.800 | 15 | 191 | 0 |

## `breach_bar_range_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 2.328 | 1.990 | 0.967 | 1.365 | 2.622 | 3.599 |
| Confirmed | 60 | 0 | 3.046 | 2.550 | 1.460 | 1.934 | 3.775 | 5.433 |
| Ambiguous | 15 | 0 | 1.284 | 1.102 | 0.730 | 0.792 | 1.278 | 2.106 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 4.1555 | 0.760 | 0.637 | 0.940 | 116 | 191 | 0 |
| Confirmed | > | 1.7189 | 0.547 | 0.412 | 0.817 | 60 | 191 | 0 |
| Ambiguous | < | 1.1935 | 0.444 | 0.333 | 0.667 | 15 | 191 | 0 |

## `breach_wick_beyond_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 0.640 | 0.460 | 0.106 | 0.221 | 0.853 | 1.426 |
| Confirmed | 60 | 0 | 1.669 | 1.325 | 0.608 | 0.851 | 2.117 | 3.481 |
| Ambiguous | 15 | 0 | 0.457 | 0.263 | 0.150 | 0.187 | 0.553 | 0.734 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 1.6694 | 0.791 | 0.679 | 0.948 | 116 | 191 | 0 |
| Confirmed | > | 0.8306 | 0.667 | 0.590 | 0.767 | 60 | 191 | 0 |
| Ambiguous | < | 0.4162 | 0.293 | 0.183 | 0.733 | 15 | 191 | 0 |

## `breach_body_beyond_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | -0.252 | -0.259 | -0.946 | -0.603 | 0.170 | 0.512 |
| Confirmed | 60 | 0 | 1.000 | 0.812 | 0.143 | 0.400 | 1.409 | 1.785 |
| Ambiguous | 15 | 0 | -0.079 | -0.146 | -0.549 | -0.377 | 0.018 | 0.336 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.6559 | 0.830 | 0.738 | 0.948 | 116 | 191 | 0 |
| Confirmed | > | 0.0861 | 0.755 | 0.626 | 0.950 | 60 | 191 | 0 |
| Ambiguous | < | -0.0219 | 0.210 | 0.122 | 0.733 | 15 | 191 | 0 |

## `pre_60min_range_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 1.596 | 1.276 | 0.685 | 0.982 | 1.871 | 3.132 |
| Confirmed | 60 | 0 | 1.852 | 1.542 | 0.757 | 1.231 | 2.388 | 3.157 |
| Ambiguous | 15 | 0 | 1.184 | 0.927 | 0.587 | 0.698 | 1.441 | 1.666 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 0.2940 | 0.758 | 0.611 | 1.000 | 116 | 191 | 0 |
| Confirmed | > | 1.4116 | 0.523 | 0.438 | 0.650 | 60 | 191 | 0 |
| Ambiguous | < | 1.0019 | 0.246 | 0.160 | 0.533 | 15 | 191 | 0 |

## `pre_120min_range_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 2.187 | 1.722 | 0.940 | 1.258 | 2.657 | 3.753 |
| Confirmed | 60 | 0 | 2.473 | 2.231 | 1.023 | 1.608 | 3.175 | 4.302 |
| Ambiguous | 15 | 0 | 1.792 | 1.470 | 0.967 | 1.165 | 2.377 | 3.274 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 0.4860 | 0.758 | 0.611 | 1.000 | 116 | 191 | 0 |
| Confirmed | > | 1.6648 | 0.518 | 0.400 | 0.733 | 60 | 191 | 0 |
| Ambiguous | < | 1.6648 | 0.208 | 0.123 | 0.667 | 15 | 191 | 0 |

## `pre_2h_velocity_atr_per_h`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | -0.043 | -0.058 | -1.082 | -0.589 | 0.369 | 0.674 |
| Confirmed | 60 | 0 | -0.216 | -0.371 | -1.323 | -0.750 | 0.431 | 0.989 |
| Ambiguous | 15 | 0 | -0.129 | 0.147 | -1.140 | -0.595 | 0.378 | 0.460 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -2.2820 | 0.752 | 0.605 | 0.991 | 116 | 191 | 0 |
| Confirmed | < | -0.2531 | 0.500 | 0.438 | 0.583 | 60 | 191 | 0 |
| Ambiguous | > | 0.2389 | 0.182 | 0.113 | 0.467 | 15 | 191 | 0 |

## `pre_300s_volume`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 114 | 2 | 1309.570 | 786.274 | 278.946 | 464.142 | 1604.406 | 2889.428 |
| Confirmed | 57 | 3 | 842.913 | 641.750 | 312.772 | 456.656 | 1158.900 | 1531.601 |
| Ambiguous | 14 | 1 | 780.121 | 641.521 | 269.168 | 342.044 | 1104.818 | 1450.668 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 45.0130 | 0.758 | 0.614 | 0.991 | 114 | 185 | 6 |
| Confirmed | < | 1718.9355 | 0.500 | 0.342 | 0.930 | 57 | 185 | 6 |
| Ambiguous | < | 340.0257 | 0.182 | 0.133 | 0.286 | 14 | 185 | 6 |

## `pre_300s_delta`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 114 | 2 | 20.655 | -30.852 | -569.031 | -293.187 | 166.690 | 556.553 |
| Confirmed | 57 | 3 | -47.079 | -90.382 | -418.470 | -238.717 | 126.268 | 441.453 |
| Ambiguous | 14 | 1 | 37.262 | 75.108 | -235.280 | -113.513 | 241.551 | 339.486 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -1220.0970 | 0.758 | 0.614 | 0.991 | 114 | 185 | 6 |
| Confirmed | < | 21.7933 | 0.488 | 0.374 | 0.702 | 57 | 185 | 6 |
| Ambiguous | > | 109.7890 | 0.192 | 0.119 | 0.500 | 14 | 185 | 6 |

## `pre_300s_delta_norm`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 114 | 2 | -0.018 | -0.041 | -0.486 | -0.326 | 0.276 | 0.448 |
| Confirmed | 57 | 3 | -0.071 | -0.143 | -0.558 | -0.381 | 0.212 | 0.518 |
| Ambiguous | 14 | 1 | 0.060 | 0.202 | -0.465 | -0.301 | 0.378 | 0.402 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.7330 | 0.765 | 0.620 | 1.000 | 114 | 185 | 6 |
| Confirmed | < | 0.0780 | 0.482 | 0.367 | 0.702 | 57 | 185 | 6 |
| Ambiguous | > | 0.3200 | 0.200 | 0.130 | 0.429 | 14 | 185 | 6 |

## `pre_300s_cvd_slope_per_s`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 114 | 2 | 0.069 | -0.103 | -1.898 | -0.979 | 0.556 | 1.871 |
| Confirmed | 57 | 3 | -0.157 | -0.301 | -1.396 | -0.796 | 0.421 | 1.474 |
| Ambiguous | 14 | 1 | 0.124 | 0.251 | -0.787 | -0.379 | 0.805 | 1.132 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -4.0670 | 0.758 | 0.614 | 0.991 | 114 | 185 | 6 |
| Confirmed | < | 0.0682 | 0.488 | 0.374 | 0.702 | 57 | 185 | 6 |
| Ambiguous | > | 0.3645 | 0.192 | 0.119 | 0.500 | 14 | 185 | 6 |

## `pre_60s_tick_count`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 114 | 2 | 10558.281 | 6145.000 | 2534.600 | 3531.000 | 10181.250 | 19443.000 |
| Confirmed | 57 | 3 | 6891.614 | 4845.000 | 2543.200 | 3471.000 | 9202.000 | 13121.200 |
| Ambiguous | 14 | 1 | 6327.000 | 6982.500 | 2756.100 | 3588.000 | 8075.500 | 9677.700 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 253.0000 | 0.758 | 0.614 | 0.991 | 114 | 185 | 6 |
| Confirmed | < | 22118.1053 | 0.491 | 0.326 | 1.000 | 57 | 185 | 6 |
| Ambiguous | < | 10725.7895 | 0.163 | 0.089 | 0.929 | 14 | 185 | 6 |

## `level_age_hours`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 139.895 | 21.779 | 1.853 | 5.027 | 90.281 | 396.002 |
| Confirmed | 60 | 0 | 44.656 | 12.287 | 1.622 | 5.320 | 25.401 | 85.918 |
| Ambiguous | 15 | 0 | 77.734 | 7.589 | 1.105 | 2.352 | 55.510 | 228.174 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 0.0010 | 0.752 | 0.605 | 0.991 | 116 | 191 | 0 |
| Confirmed | < | 39.6200 | 0.516 | 0.377 | 0.817 | 60 | 191 | 0 |
| Ambiguous | < | 9.2310 | 0.212 | 0.129 | 0.600 | 15 | 191 | 0 |

## `touch_count_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 0.845 | 0.000 | 0.000 | 0.000 | 1.000 | 2.000 |
| Confirmed | 60 | 0 | 0.717 | 0.000 | 0.000 | 0.000 | 1.000 | 2.100 |
| Ambiguous | 15 | 0 | 0.933 | 1.000 | 0.000 | 0.000 | 1.000 | 2.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 4.1053 | 0.759 | 0.615 | 0.991 | 116 | 191 | 0 |
| Confirmed | < | 5.0526 | 0.480 | 0.316 | 1.000 | 60 | 191 | 0 |
| Ambiguous | > | 0.0000 | 0.196 | 0.115 | 0.667 | 15 | 191 | 0 |

## `touch_count_ticks`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 0.009 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Confirmed | 60 | 0 | 0.017 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Ambiguous | 15 | 0 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.0526 | 0.754 | 0.608 | 0.991 | 116 | 191 | 0 |
| Confirmed | < | 0.0526 | 0.474 | 0.312 | 0.983 | 60 | 191 | 0 |
| Ambiguous | < | 0.0526 | 0.147 | 0.079 | 1.000 | 15 | 191 | 0 |

## `breach_closed_through`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 0.293 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |
| Confirmed | 60 | 0 | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 |
| Ambiguous | 15 | 0 | 0.267 | 0.000 | 0.000 | 0.000 | 0.500 | 1.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.0526 | 0.785 | 0.882 | 0.707 | 116 | 191 | 0 |
| Confirmed | > | 0.0000 | 0.759 | 0.612 | 1.000 | 60 | 191 | 0 |
| Ambiguous | < | 0.0526 | 0.204 | 0.118 | 0.733 | 15 | 191 | 0 |

## `breach_bar_up`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 116 | 0 | 0.466 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |
| Confirmed | 60 | 0 | 0.367 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |
| Ambiguous | 15 | 0 | 0.533 | 1.000 | 0.000 | 0.000 | 1.000 | 1.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.0526 | 0.556 | 0.579 | 0.534 | 116 | 191 | 0 |
| Confirmed | < | 0.0526 | 0.455 | 0.355 | 0.633 | 60 | 191 | 0 |
| Ambiguous | > | 0.0000 | 0.162 | 0.095 | 0.533 | 15 | 191 | 0 |

