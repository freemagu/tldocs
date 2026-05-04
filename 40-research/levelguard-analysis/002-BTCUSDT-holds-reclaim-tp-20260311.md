# Case 002: BTCUSDT Guard Execution — Holds Mode Reclaim (2026-03-11)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-11 |
| Symbol | BTCUSDT |
| Guard ID | 5 |
| Reference Level | 70550.0 |
| Mode | holds |
| Trade Side | long |
| Decision | reclaimed |
| ATR (frozen) | 33.65 |
| Fill | sell 0.003 @ 70541.4 (tp) |
| Outcome | Level held above 70550 for 18 seconds, then reclaim triggered TP sell |
| Verdict | CORRECT execution |

## Context

This guard is in **holds** mode, meaning execution happens when the level **holds** (price reclaims after breaching). The purpose was to take profit when 70550 support confirmed as holding. The exit_direction is "above" — the guard watches for price to stay above the reference level.

## LevelMind Decision Trail

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 20:57:27 | 1 | update_state | inconclusive | 70552.10 | Initial breach detection, price above level |
| 20:57:28 | 2 | none | inconclusive | 70552.00 | |
| 20:57:29 | 3 | none | inconclusive | 70552.00 | |
| 20:57:29 | 4 | none | inconclusive | 70552.10 | |
| 20:57:30 | 5 | none | inconclusive | 70552.10 | |
| 20:57:31 | 6 | none | inconclusive | 70552.10 | |
| 20:57:31 | 7 | none | inconclusive | 70552.00 | |
| 20:57:32 | 8 | none | inconclusive | 70552.00 | |
| **20:57:33** | **9** | **update_state** | **accept** | **70552.00** | **First timeout_execute — 5s reclaim window expired** |
| 20:57:35 | 10 | update_state | inconclusive | 70552.10 | Re-armed, new observation window |
| 20:57:35–40 | 11–17 | none | inconclusive | 70552.00–70552.10 | Price hovering at level |
| **20:57:40** | **18** | **update_state** | **accept** | **70552.10** | **Second timeout_execute — reclaim window expired again** |
| 20:57:42 | 19 | update_state | inconclusive | 70552.10 | Re-armed again |
| 20:57:43–45 | 20–22 | none | inconclusive | 70552.10 | Price still above level |
| **20:57:45** | **23** | **execute** | **reclaim** | **70542.80** | **Final decision: reclaimed — executes TP** |

Key observations:
- Two timeout_execute events at resp 9 and 18 were accepted (level holding), but the guard re-armed each time.
- At resp 23, the final "reclaimed" classification triggered the actual execution order.
- Price dropped from 70552.10 to 70542.80 between resp 22 and 23 (within the same second), suggesting a wick down just before execution.

## Candle Data Around Breach

The 1m candles cover 19:48–20:07 UTC. The breach was at 20:57, which is outside this window. Using the 5m candle data:

| Time (5m) | Open | High | Low | Close | Vol |
|-----------|------|------|-----|-------|-----|
| 19:45 | 70639.4 | 70651.0 | 70580.1 | 70615.3 | 69 |
| 19:50 | 70615.3 | 70691.3 | 70598.6 | 70648.9 | 90 |
| 19:55 | 70648.9 | 70656.4 | 70531.9 | 70606.6 | 169 |
| **20:00** | **70606.6** | **70609.0** | **70432.3** | **70462.0** | **270** |
| 20:05 | 70462.0 | 70496.4 | 70440.5 | 70455.1 | 95 |
| 20:10 | 70455.1 | 70458.3 | 70386.6 | 70391.1 | 140 |

The 20:00 candle is the critical one — it shows price crashing through 70550 down to 70432.3, a 177-point drop. The 20:55 5m candle (which would contain the 20:57 breach time):

| Time (5m) | Open | High | Low | Close | Vol |
|-----------|------|------|-----|-------|-----|
| 20:50 | 70499.0 | 70569.7 | 70408.4 | 70562.5 | 191 |
| **20:55** | **70562.5** | **70675.3** | **70502.4** | **70594.2** | **196** |

The 20:55 candle shows price rallying back above 70550 (high 70675.3), which is when the guard detected the level holding and executed.

## Post-Execution Price Action

Execute price: 70542.8 (sell/TP). Looking at the 5m candles after the 20:55 execution window:

The data ends at the 20:55 candle (close 70594.2). The breach itself happened at 20:57:45 near the end of this candle. From the 1m candle data earlier in the session:

- **20:00–20:03**: Price collapsed from 70606 to 70449 (below level by ~100 points)
- **20:05–20:10**: Price stabilized around 70455–70482
- **20:15**: Bounced to 70477.8
- **20:50**: Rally back to 70562.5
- **20:55**: Continued rally, high 70675.3

The guard sold at 70541.4 (fill price) during a period where price was rallying back above the level. Price subsequently traded as high as 70675.3 in the same 5m candle.

## Verdict

**CORRECT EXECUTION** — This is a "holds" mode guard on a long position. The level (70550) was tested when price crashed to 70432 around 20:00, then recovered back above 70550 by 20:50. The guard correctly identified that the level held after a deep wick and executed the TP. While the fill at 70541.4 was slightly below the reference level (by 8.6 points, about 0.26 ATR), the intended purpose — taking profit when support holds — was fulfilled correctly.

The sell was at 70541.4 against a WAEP that was not provided for this case, but since this was a TP (take profit) leg on a long position, the execution was directionally correct: the level held, confirming it was time to take profit.

## Signals Assessment

- **CVD/OI**: Could have confirmed the bounce strength. The 270 volume on the 20:00 crash candle vs. lower volume on recovery suggests the selling was absorbed — CVD divergence here would have added confidence.
- **Extended window**: Not needed here — the holds mode correctly waited for reclaim confirmation.
- **Momentum**: The rally from 70408 back to 70562 before execution shows strong recovery momentum; an RSI/momentum filter would have confirmed the holds decision.
