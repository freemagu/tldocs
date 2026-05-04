# Phase 1 Summary Stats — ETHUSDT 30m Swing-Level Breach Research (run v1)

Window: 2025-10-12T00:00:00 UTC → 2026-04-07T23:59:59 UTC
Candles loaded (incl warmup+tail): 10656

## Pivots
- Raw pivots (loaded range): 291
- Pivots in Phase 1 window:  235
- Dropped (prominence): 2
- Kept: 233

## Breach events
- In window: 210
- Past window (excluded): 3
- Still active (unbreached by end of loaded range): 20
- Events on tick-gap days (tick refinement unavailable): 38
- Events with tick refinement available: 172
  (81.9% of in-window events)

## touch_count_atr distribution
- 0: 108
- 1: 68
- 2: 19
- 3-4: 11
- 5-9: 4
- 10-9999: 0

## touch_count_ticks distribution
- 0: 209
- 1: 1
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
- Touch band (ticks): 20 × tick_size = 0.20
- Touch exit (ticks): 10 × tick_size
- ETHUSDT tick_size:  0.01
