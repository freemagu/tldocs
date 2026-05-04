# Case 019: ICPUSDT Guard Execution (2026-03-19)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-19 |
| Symbol | ICPUSDT |
| Guard ID | 38 |
| Reference Level | 2.50 |
| Mode | fails |
| Trade Side | long |
| Decision | displacement |
| ATR (frozen) | 0.000929 |
| Outcome | Sold 2,261.4 @ 2.49819 (close_loss), WAEP was 2.72805 — loss of ~8.4% |
| Verdict | CORRECT |

## LevelMind Decision Trail

Guard 38 had a long observation phase (price sitting exactly at the level) followed by breach and immediate displacement:

**Observation phase — price exactly at level:**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 12:51:00 | 419 | update_state | inconclusive | 2.500 | Armed, obs_started |
| 12:51:00 | 421 | update_state | inconclusive | 2.500 | Exactly at level |
| 12:51:01 | 423 | update_state | inconclusive | 2.500 | Exactly at level |
| 12:51:02 | 425 | update_state | inconclusive | 2.500 | Still exactly 2.500 |
| 12:51:03 | 427 | update_state | inconclusive | 2.500 | Sitting on the line |
| 12:51:04-05 | 429-431 | update_state | inconclusive | 2.500 | Unchanged |
| 12:51:05-06 | 433-435 | update_state | inconclusive | 2.500 | Unchanged |
| 12:51:06-09 | 437-441 | update_state | inconclusive | 2.500 | 13 seconds at exactly 2.500 |
| 12:51:09-11 | 443-449 | update_state | inconclusive | 2.500 | Still flat |
| 12:51:11-13 | 451-457 | update_state | inconclusive | 2.500 | 13+ seconds of price pinned at 2.500 |

**Breach and immediate displacement:**

| Time (UTC) | Resp | Action | Classification | Last Price | Evidence | Notes |
|------------|------|--------|----------------|------------|----------|-------|
| 12:51:13 | 459 | update_state | inconclusive | 2.498 | | **Breach** at 2.498 (below 2.500) |
| 12:51:14 | 461 | **execute** | **accept** | 2.498 | displacement (2.154x ATR, conf=1.0) | **Immediate displacement** |

Key observations:
- Price sat at exactly 2.500 for 13 seconds (19 responses) — perfectly balanced on the level
- Then broke to 2.498, a 0.002 drop
- Displacement threshold: 2.500 - 0.000929 = 2.4991. Price at 2.498 < 2.4991 = displacement
- Volatility multiple: 2.154x ATR — a clear displacement
- Only 1 second from breach to execute (displacement was immediate)
- Confidence: 1.0

## Candle Data Around Breach

1m candles approaching the breach (12:51 UTC):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 11:42 | 2.524 | 2.525 | 2.523 | 2.524 | 429 |
| 11:45 | 2.526 | 2.528 | 2.525 | 2.528 | 182 |
| 11:50 | 2.527 | 2.527 | 2.527 | 2.527 | 148 |
| 11:55 | 2.526 | 2.526 | 2.524 | 2.526 | 20 |
| 12:00 | 2.525 | 2.527 | 2.525 | 2.526 | 2,592 |
| 12:01 | 2.526 | 2.526 | 2.524 | 2.525 | 836 |

Steady decline from 2.528 toward the 2.500 level over ~70 minutes. Volume was generally low, indicating thin liquidity. The approach was gradual, not a sudden dump.

## Post-Execution Price Action

5m candles after execution (12:51:14 UTC):

| Time | Open | High | Low | Close | Vol | Distance from 2.500 |
|------|------|------|-----|-------|-----|---------------------|
| 12:50 | 2.509 | 2.509 | 2.492 | 2.496 | 77,005 | -0.004 |
| 12:45 | 2.511 | 2.511 | 2.505 | 2.509 | 19,223 | +0.009 |
| 12:40 | 2.511 | 2.514 | 2.509 | 2.511 | 11,554 | +0.011 |
| 12:35 | 2.509 | 2.514 | 2.509 | 2.511 | 14,384 | +0.011 |
| 12:30 | 2.508 | 2.512 | 2.507 | 2.509 | 13,205 | +0.009 |
| 12:25 | 2.515 | 2.515 | 2.505 | 2.508 | 30,657 | +0.008 |
| 12:20 | 2.519 | 2.519 | 2.513 | 2.515 | 36,617 | +0.015 |
| 12:15 | 2.526 | 2.526 | 2.518 | 2.519 | 9,375 | +0.019 |
| 12:10 | 2.520 | 2.526 | 2.519 | 2.526 | 8,676 | +0.026 |
| 12:05 | 2.523 | 2.524 | 2.519 | 2.520 | 9,142 | +0.020 |
| 12:00 | 2.525 | 2.527 | 2.523 | 2.523 | 11,102 | +0.023 |

Reading the 5m data chronologically leading up to and including the breach:

| Time | Open | Close | Direction |
|------|------|-------|-----------|
| 12:00 | 2.525 | 2.523 | Down |
| 12:05 | 2.523 | 2.520 | Down |
| 12:10 | 2.520 | 2.526 | Up (bounce) |
| 12:15 | 2.526 | 2.519 | Down |
| 12:20 | 2.519 | 2.515 | Down |
| 12:25 | 2.515 | 2.508 | Down |
| 12:30 | 2.508 | 2.509 | Flat |
| 12:35 | 2.509 | 2.511 | Flat |
| 12:40 | 2.511 | 2.511 | Flat |
| 12:45 | 2.511 | 2.509 | Flat |
| **12:50** | **2.509** | **2.496** | **Breakdown** |

The 12:50 candle is the breakdown candle — price dropped from 2.509 to a low of 2.492 with a spike in volume (77,005 vs. 10,000-20,000 normal). The guard triggered within this candle. Price closed the candle at 2.496, confirming the level break was sustained.

## Verdict

**CORRECT EXECUTION**

This is a clean, well-executed guard:

1. **Clear trend leading to breakdown**: Steady decline from 2.528 to 2.500 over 70+ minutes, then a clean break below.
2. **Price sat on the level first**: 13 seconds of price at exactly 2.500 before the break — this is the market testing and then rejecting the level.
3. **Displacement was decisive**: 2.154x ATR below the level, with high confidence. Not a marginal call.
4. **Volume confirmed the break**: 77,005 volume in the breakdown candle vs. ~10,000-20,000 in preceding candles.
5. **Post-break, price held below level**: The candle closed at 2.496, below the level, confirming the break was real.
6. **Fill was clean**: Fill at 2.49819, close to the breach_price of 2.498. No significant slippage.
7. **exit_direction=below, guard_reference=auto**: Standard configuration for a long stop-loss guard.

The position loss was significant (-8.4%), but the guard correctly identified the level break. Without the guard, the loss could have been larger as price was trending lower.

### Displacement Calculation

```
Reference level:      2.5000
ATR:                  0.000929
Displacement threshold: 2.5000 - 0.000929 = 2.4991
Breach price:         2.498
Distance below level: 2.5000 - 2.498 = 0.002
Volatility multiple:  0.002 / 0.000929 = 2.153x ATR
```

A 2.15x ATR displacement is well beyond the 1.0x threshold, making this a high-confidence displacement call.

## Signals Assessment

- **Volume surge detection**: The 77K volume vs. ~15K average could serve as a confirming signal. If volume spikes above 3-4x average at the moment of breach, it adds conviction to the displacement call. In this case, it would have reinforced the already-strong 2.15x ATR displacement.
- **Pre-breach stagnation signal**: The 13 seconds of price at exactly 2.500 before the break is a characteristic "coiling before breakdown" pattern. A signal that detects price pinning at a level (multiple ticks at the exact level) could serve as a preemptive warning.
- **Trending approach**: Price had been declining for 70 minutes before reaching the level. A signal measuring the approach velocity or the number of consecutive lower closes could provide additional context for the guard decision.
