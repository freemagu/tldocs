# Phase 1 Summary Stats — BTCUSDT 30m Swing-Level Breach Research (run v1)

Window: 2025-10-01T00:00:00 UTC → 2026-03-23T23:59:59 UTC
Candles loaded (incl warmup+tail): 10464

## Pivots
- Raw pivots (loaded range): 272
- Pivots in Phase 1 window:  212
- Dropped (prominence): 2
- Kept: 210

## Breach events
- In window: 191
- Past window (excluded): 4
- Still active (unbreached by end of loaded range): 15
- Events on tick-gap days (tick refinement unavailable): 6
- Events with tick refinement available: 185
  (96.9% of in-window events)

## touch_count_atr distribution
- 0: 104
- 1: 53
- 2: 16
- 3-4: 14
- 5-9: 4
- 10-9999: 0

## touch_count_ticks distribution
- 0: 189
- 1: 2
- 2: 0
- 3-4: 0
- 5-9: 0
- 10-9999: 0

## Parameters (see phase1_parameters.md)
- Timeframe: 30m
- N (pivot): 50L / 10R (strict inequality)
- Prominence: |price − donchMid(21)| ≥ 1.5 × ATR(14), all at pivot bar
- Touch band (ATR):   0.5 × ATR
- Touch exit (ATR):   0.25 × ATR
- Touch band (ticks): 20 × tick_size = 2.0
- Touch exit (ticks): 10 × tick_size
- BTCUSDT tick_size:  0.1
