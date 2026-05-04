# Phase 5 — Two-feature rules per training set

Best `(A dA tA) AND/OR (B dB tB)` rule found on each training set, one-vs-rest with positive class = SFP. Features restricted to the top-6 single-feature ranks on that training set.

Baselines (best single-feature F1, in-sample):
- **BTCUSDT**: 0.830
- **ETHUSDT**: 0.837
- **pooled**: 0.835

## Train: BTCUSDT

**Rule**: (`breach_body_beyond_atr` < 0.6559) AND (`breach_bar_range_atr` > 0.5780)

**Combiner**: AND

In-sample: F1=0.833 (prec=0.743, rec=0.948, n+=116/191, nulls=0)

## Train: ETHUSDT

**Rule**: (`breach_body_beyond_atr` < 0.1344) OR (`breach_bar_body_atr` < 1.7319)

**Combiner**: OR

In-sample: F1=0.842 (prec=0.767, rec=0.933, n+=134/210, nulls=0)

## Train: pooled

**Rule**: (`breach_body_beyond_atr` < 0.5178) OR (`breach_wick_beyond_atr` < 0.6549)

**Combiner**: OR

In-sample: F1=0.837 (prec=0.765, rec=0.924, n+=250/401, nulls=0)

