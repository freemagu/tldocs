# Phase 4 Feature Separation — per-feature detail

Per-class descriptive stats and the best single-cutoff F1 for each (feature × positive-class), one-vs-rest.

Non-null support only. Nulls reported separately per class.

## `breach_bar_body_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 1.071 | 0.778 | 0.164 | 0.385 | 1.360 | 2.210 |
| Confirmed | 60 | 0 | 2.417 | 2.094 | 0.915 | 1.294 | 3.169 | 4.428 |
| Ambiguous | 16 | 0 | 0.495 | 0.459 | 0.122 | 0.251 | 0.651 | 0.953 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 3.1128 | 0.799 | 0.683 | 0.963 | 134 | 210 | 0 |
| Confirmed | > | 1.7319 | 0.634 | 0.619 | 0.650 | 60 | 210 | 0 |
| Ambiguous | < | 0.6363 | 0.286 | 0.176 | 0.750 | 16 | 210 | 0 |

## `breach_bar_range_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 2.323 | 1.902 | 1.153 | 1.520 | 2.783 | 3.828 |
| Confirmed | 60 | 0 | 3.277 | 2.704 | 1.408 | 2.032 | 4.284 | 5.674 |
| Ambiguous | 16 | 0 | 1.263 | 1.273 | 0.891 | 1.009 | 1.498 | 1.666 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 10.2440 | 0.781 | 0.641 | 1.000 | 134 | 210 | 0 |
| Confirmed | > | 1.9955 | 0.544 | 0.422 | 0.767 | 60 | 210 | 0 |
| Ambiguous | < | 1.5214 | 0.361 | 0.232 | 0.812 | 16 | 210 | 0 |

## `breach_wick_beyond_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 0.722 | 0.495 | 0.107 | 0.272 | 0.920 | 1.581 |
| Confirmed | 60 | 0 | 1.798 | 1.352 | 0.546 | 0.718 | 2.151 | 4.218 |
| Ambiguous | 16 | 0 | 0.515 | 0.483 | 0.124 | 0.321 | 0.757 | 0.921 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 2.0415 | 0.795 | 0.681 | 0.955 | 134 | 210 | 0 |
| Confirmed | > | 0.7057 | 0.599 | 0.485 | 0.783 | 60 | 210 | 0 |
| Ambiguous | < | 1.0189 | 0.199 | 0.110 | 1.000 | 16 | 210 | 0 |

## `breach_body_beyond_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | -0.290 | -0.262 | -0.941 | -0.587 | 0.039 | 0.446 |
| Confirmed | 60 | 0 | 1.130 | 0.678 | 0.104 | 0.329 | 1.677 | 2.809 |
| Ambiguous | 16 | 0 | -0.074 | -0.090 | -0.410 | -0.258 | 0.121 | 0.309 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.5616 | 0.837 | 0.754 | 0.940 | 134 | 210 | 0 |
| Confirmed | > | 0.0603 | 0.756 | 0.615 | 0.983 | 60 | 210 | 0 |
| Ambiguous | < | 0.4405 | 0.185 | 0.102 | 1.000 | 16 | 210 | 0 |

## `pre_60min_range_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 1.683 | 1.373 | 0.730 | 0.956 | 2.035 | 3.062 |
| Confirmed | 60 | 0 | 1.818 | 1.510 | 0.617 | 0.948 | 2.223 | 3.222 |
| Ambiguous | 16 | 0 | 1.131 | 0.978 | 0.643 | 0.862 | 1.296 | 1.922 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 0.3090 | 0.781 | 0.641 | 1.000 | 134 | 210 | 0 |
| Confirmed | > | 0.3090 | 0.446 | 0.287 | 1.000 | 60 | 210 | 0 |
| Ambiguous | < | 1.2595 | 0.224 | 0.132 | 0.750 | 16 | 210 | 0 |

## `pre_120min_range_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 2.216 | 1.744 | 0.989 | 1.337 | 2.651 | 3.860 |
| Confirmed | 60 | 0 | 2.361 | 2.027 | 0.982 | 1.510 | 2.795 | 4.446 |
| Ambiguous | 16 | 0 | 1.606 | 1.528 | 0.744 | 1.226 | 1.656 | 2.747 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 0.5350 | 0.776 | 0.636 | 0.993 | 134 | 210 | 0 |
| Confirmed | > | 1.5704 | 0.461 | 0.336 | 0.733 | 60 | 210 | 0 |
| Ambiguous | < | 1.5704 | 0.232 | 0.139 | 0.688 | 16 | 210 | 0 |

## `pre_2h_velocity_atr_per_h`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | -0.116 | -0.117 | -0.953 | -0.570 | 0.267 | 0.737 |
| Confirmed | 60 | 0 | -0.137 | -0.155 | -1.047 | -0.700 | 0.398 | 0.776 |
| Ambiguous | 16 | 0 | 0.158 | 0.187 | -0.540 | -0.177 | 0.509 | 0.793 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -3.5810 | 0.776 | 0.636 | 0.993 | 134 | 210 | 0 |
| Confirmed | > | -3.5810 | 0.446 | 0.287 | 1.000 | 60 | 210 | 0 |
| Ambiguous | > | 0.1173 | 0.215 | 0.130 | 0.625 | 16 | 210 | 0 |

## `pre_300s_volume`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 108 | 26 | 26579.663 | 16952.000 | 6646.792 | 11761.142 | 29087.420 | 43990.676 |
| Confirmed | 50 | 10 | 24328.415 | 17608.325 | 3968.061 | 8284.462 | 36843.963 | 50681.685 |
| Ambiguous | 14 | 2 | 12201.222 | 9146.875 | 5317.805 | 6306.090 | 17019.857 | 22692.864 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 2808.0100 | 0.774 | 0.632 | 1.000 | 108 | 172 | 38 |
| Confirmed | < | 499513.2600 | 0.452 | 0.292 | 1.000 | 50 | 172 | 38 |
| Ambiguous | < | 9808.3600 | 0.305 | 0.200 | 0.643 | 14 | 172 | 38 |

## `pre_300s_delta`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 108 | 26 | -2690.099 | -2382.290 | -12200.814 | -8112.400 | 3371.885 | 7477.105 |
| Confirmed | 50 | 10 | -1538.193 | -780.525 | -10833.600 | -6643.227 | 2191.862 | 6575.914 |
| Ambiguous | 14 | 2 | 537.841 | 787.835 | -4891.926 | -2576.765 | 2989.285 | 6502.866 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -31573.7500 | 0.774 | 0.632 | 1.000 | 108 | 172 | 38 |
| Confirmed | > | -14496.9200 | 0.462 | 0.302 | 0.980 | 50 | 172 | 38 |
| Ambiguous | > | -5834.8500 | 0.198 | 0.111 | 0.929 | 14 | 172 | 38 |

## `pre_300s_delta_norm`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 108 | 26 | -0.073 | -0.161 | -0.494 | -0.383 | 0.264 | 0.419 |
| Confirmed | 50 | 10 | -0.043 | -0.082 | -0.439 | -0.296 | 0.230 | 0.321 |
| Ambiguous | 14 | 2 | 0.059 | 0.151 | -0.359 | -0.239 | 0.328 | 0.479 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -0.7580 | 0.767 | 0.626 | 0.991 | 108 | 172 | 38 |
| Confirmed | < | 0.3366 | 0.474 | 0.319 | 0.920 | 50 | 172 | 38 |
| Ambiguous | > | 0.1994 | 0.200 | 0.125 | 0.500 | 14 | 172 | 38 |

## `pre_300s_cvd_slope_per_s`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 108 | 26 | -8.975 | -7.949 | -40.692 | -27.067 | 11.253 | 24.987 |
| Confirmed | 50 | 10 | -5.176 | -2.606 | -36.138 | -22.165 | 7.321 | 21.924 |
| Ambiguous | 14 | 2 | 1.788 | 2.628 | -16.345 | -8.603 | 9.972 | 21.690 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | -107.5530 | 0.774 | 0.632 | 1.000 | 108 | 172 | 38 |
| Confirmed | > | -48.3530 | 0.462 | 0.302 | 0.980 | 50 | 172 | 38 |
| Ambiguous | > | -19.4570 | 0.198 | 0.111 | 0.929 | 14 | 172 | 38 |

## `pre_60s_tick_count`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 108 | 26 | 11637.222 | 7336.000 | 3103.200 | 4781.000 | 12659.000 | 21066.700 |
| Confirmed | 50 | 10 | 8938.040 | 5784.000 | 2369.700 | 4098.000 | 10616.750 | 18106.000 |
| Ambiguous | 14 | 2 | 5794.214 | 5358.000 | 3029.800 | 3486.250 | 6649.750 | 8347.500 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 1037.0000 | 0.774 | 0.632 | 1.000 | 108 | 172 | 38 |
| Confirmed | > | 1037.0000 | 0.452 | 0.292 | 1.000 | 50 | 172 | 38 |
| Ambiguous | < | 8699.3158 | 0.211 | 0.119 | 0.929 | 14 | 172 | 38 |

## `level_age_hours`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 92.904 | 15.084 | 1.512 | 5.091 | 50.923 | 200.477 |
| Confirmed | 60 | 0 | 47.333 | 10.518 | 1.941 | 4.341 | 43.912 | 133.486 |
| Ambiguous | 16 | 0 | 87.347 | 9.326 | 0.940 | 4.519 | 32.288 | 317.224 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | > | 0.0000 | 0.778 | 0.639 | 0.993 | 134 | 210 | 0 |
| Confirmed | < | 381.7840 | 0.463 | 0.302 | 1.000 | 60 | 210 | 0 |
| Ambiguous | < | 1.2101 | 0.200 | 0.214 | 0.188 | 16 | 210 | 0 |

## `touch_count_atr`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 0.761 | 0.000 | 0.000 | 0.000 | 1.000 | 2.000 |
| Confirmed | 60 | 0 | 0.700 | 0.000 | 0.000 | 0.000 | 1.000 | 2.000 |
| Ambiguous | 16 | 0 | 1.312 | 1.000 | 0.000 | 0.000 | 1.000 | 3.500 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 4.1053 | 0.782 | 0.646 | 0.993 | 134 | 210 | 0 |
| Confirmed | < | 3.1579 | 0.452 | 0.294 | 0.983 | 60 | 210 | 0 |
| Ambiguous | > | 4.1053 | 0.200 | 0.500 | 0.125 | 16 | 210 | 0 |

## `touch_count_ticks`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Confirmed | 60 | 0 | 0.017 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Ambiguous | 16 | 0 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.0526 | 0.781 | 0.641 | 1.000 | 134 | 210 | 0 |
| Confirmed | < | 0.0526 | 0.439 | 0.282 | 0.983 | 60 | 210 | 0 |
| Ambiguous | < | 0.0526 | 0.142 | 0.077 | 1.000 | 16 | 210 | 0 |

## `breach_closed_through`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 0.276 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |
| Confirmed | 60 | 0 | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 |
| Ambiguous | 16 | 0 | 0.438 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.0526 | 0.808 | 0.915 | 0.724 | 134 | 210 | 0 |
| Confirmed | > | 0.0000 | 0.732 | 0.577 | 1.000 | 60 | 210 | 0 |
| Ambiguous | < | 0.0526 | 0.148 | 0.085 | 0.562 | 16 | 210 | 0 |

## `breach_bar_up`

### Per-class summary

| class | n | null | mean | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| SFP | 134 | 0 | 0.463 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |
| Confirmed | 60 | 0 | 0.467 | 0.000 | 0.000 | 0.000 | 1.000 | 1.000 |
| Ambiguous | 16 | 0 | 0.625 | 1.000 | 0.000 | 0.000 | 1.000 | 1.000 |

### Best cutoff per positive class

| positive | direction | threshold | F1 | prec | recall | n+ | n | null |
|---|---|---|---|---|---|---|---|---|
| SFP | < | 0.0526 | 0.590 | 0.655 | 0.537 | 134 | 210 | 0 |
| Confirmed | < | 0.0526 | 0.376 | 0.291 | 0.533 | 60 | 210 | 0 |
| Ambiguous | > | 0.0000 | 0.172 | 0.100 | 0.625 | 16 | 210 | 0 |

