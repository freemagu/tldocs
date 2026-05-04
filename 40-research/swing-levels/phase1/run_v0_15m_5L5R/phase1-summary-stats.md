# Phase 1 Summary Stats — BTCUSDT 15m Swing-Level Breach Research

Window: 2025-10-01T00:00:00 UTC → 2026-03-23T23:59:59 UTC
Candles loaded (incl warmup+tail): 20928

## Pivots
- Raw pivots (loaded range): 2588
- Pivots in Phase 1 window:  2077
- Dropped (spacing): 0
- Dropped (magnitude): 6
- Kept: 2071

## Breach events
- In window: 1983
- Past window (excluded): 16
- Still active (unbreached by end of loaded range): 72
- Events on tick-gap days (tick refinement unavailable): 44
- Events with tick refinement available: 1939
  (97.8% of in-window events)

## touch_count_atr distribution
- 0: 1022
- 1: 519
- 2: 210
- 3-4: 168
- 5-9: 62
- 10-9999: 2

## touch_count_ticks distribution
- 0: 1956
- 1: 27
- 2: 0
- 3-4: 0
- 5-9: 0
- 10-9999: 0

## Parameters (see phase1_parameters.md)
- N (pivot): 5L / 5R
- Spacing: ≥ 5 bars same-type
- Magnitude: ≥ 0.3 × ATR(14)
- Touch band (ATR):   0.5 × ATR
- Touch exit (ATR):   0.25 × ATR
- Touch band (ticks): 20 × tick_size = 2.0
- Touch exit (ticks): 10 × tick_size
- BTCUSDT tick_size:  0.1
