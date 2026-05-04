# Case 017: ATOMUSDT Guard Execution — ANOMALOUS (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 (breach) / 2026-03-19 (fill) |
| Symbol | ATOMUSDT |
| Guard ID | 25 |
| Reference Level | 2.00 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.0011 |
| Outcome | Sold 333.3 @ 1.8403 (close_loss), WAEP was 1.98447 — loss of ~7.3% |
| Verdict | ANOMALOUS — needs investigation |

## ANOMALY FLAGS

1. **Exit direction is "above"** — configured with `exit_direction: above` for a long position in "fails" mode.
2. **Guard reference is "limit"** — monitoring a limit order level, not a stop loss.
3. **Breach price ABOVE reference level** — breach_price=2.0004 vs reference_level=2.00.
4. **~32-HOUR delay between LevelMind execute and fill** — LevelMind executed at 2026-03-18 03:24:20 UTC, but fill was at 2026-03-19 11:58:50 UTC.
5. **Massive price gap: execute at 2.0007, fill at 1.8403** — an 8% price difference between execute decision and actual fill. Price had fallen dramatically in the 32 hours between.

## LevelMind Decision Trail

Guard 25 monitored price approaching the 2.00 level from below (exit_direction=above), with obs_started at 03:24:09.

**Armed/observation phase (price just below level):**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 03:24:09 | 193 | update_state | inconclusive | 1.9999 | Armed, observing. Price at 1.9999 |
| 03:24:10 | 194 | update_state | inconclusive | 1.9999 | Still just below |
| 03:24:10-14 | 195-200 | update_state | inconclusive | 1.9999 | 8 consecutive checks at 1.9999 |

**Breach and execution:**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 03:24:15 | 201 | update_state | inconclusive | 2.0004 | **Breach** at 2.0004 (above 2.00) |
| 03:24:15 | 202 | none | inconclusive | 2.0005 | Continuing above |
| 03:24:16 | 203 | none | inconclusive | 2.0005 | Holding above |
| 03:24:17 | 204 | none | inconclusive | 2.0006 | Pushing higher |
| 03:24:17 | 205 | none | inconclusive | 2.0007 | Higher |
| 03:24:18 | 206 | none | inconclusive | 2.0007 | Stable above |
| 03:24:19 | 207 | none | inconclusive | 2.0007 | Stable |
| 03:24:19 | 208 | none | inconclusive | 2.0007 | Stable |
| 03:24:20 | 209 | **execute** | **accept** | 2.0007 | **timeout_execute** — 5 seconds, no reclaim |

LevelMind correctly observed the 5-second timeout: breach at 03:24:15, execute at 03:24:20. Price moved from 2.0004 to 2.0007 during the window, consistently above the level. No reclaim occurred.

## Candle Data Around Breach

1m candles approaching the 2.00 level (data covers 02:15-02:34):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 02:15 | 1.9720 | 1.9730 | 1.9720 | 1.9730 | 471 |
| 02:24 | 1.9746 | 1.9755 | 1.9746 | 1.9754 | 1,636 |
| 02:25 | 1.9754 | 1.9763 | 1.9753 | 1.9763 | 786 |
| 02:32 | 1.9764 | 1.9778 | 1.9757 | 1.9764 | 4,295 |
| 02:34 | 1.9773 | 1.9815 | 1.9773 | 1.9798 | 14,818 |

Price was slowly grinding upward toward 2.00. The 1m candle data doesn't extend to the 03:24 breach time, but the trend is clear — steady approach from below.

## Post-Execution Price Action

**Critical: The 5m data provided for guard 25 is timestamped 2026-03-19, more than 32 hours after the LevelMind execute decision.**

5m candles at the time of the actual fill (~2026-03-19 11:58):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 10:45 | 1.8542 | 1.8549 | 1.8516 | 1.8524 | 6,603 |
| 10:50 | 1.8524 | 1.8524 | 1.8421 | 1.8437 | 156,851 |
| 10:55 | 1.8437 | 1.8440 | 1.8404 | 1.8423 | 31,212 |
| 11:00 | 1.8423 | 1.8426 | 1.8400 | 1.8403 | 21,899 |
| 11:05 | 1.8403 | 1.8406 | 1.8373 | 1.8387 | 28,633 |
| 11:10 | 1.8387 | 1.8426 | 1.8381 | 1.8404 | 26,716 |
| 11:15 | 1.8404 | 1.8404 | 1.8368 | 1.8391 | 13,451 |
| 11:30 | 1.8422 | 1.8438 | 1.8414 | 1.8416 | 12,295 |
| 11:55 | 1.8403 | 1.8407 | 1.8395 | 1.8406 | 3,478 |

By the time of the actual fill, price was at 1.84 — a massive 8% below the guard's execute price of 2.0007. The position was filled at 1.8403, turning what would have been a +0.8% exit (at 2.0007 vs WAEP 1.98447) into a -7.3% loss.

## Verdict

**ANOMALOUS — needs investigation**

### Key Anomalies

1. **32-hour gap between LevelMind execute decision and actual fill**: LevelMind decided to sell at 03:24:20 on March 18 with last_price=2.0007. The fill happened at 11:58:50 on March 19 at 1.8403. This is not a normal guard execution — there is a catastrophic delay.

2. **exit_direction=above for a long position**: Like guard 31 (Case 016), this guard is configured to fire when price goes ABOVE the level. Combined with guard_reference=limit, this was likely monitoring a limit TP order at the 2.00 level.

3. **Price deteriorated 8% during the delay**: If the guard had executed immediately at 2.0007, the position would have been closed at a small profit. Instead, the 32-hour delay meant the fill happened at 1.8403, far below entry.

4. **Fill price vs execute price mismatch**: Execute_price=2.0007 but fill=1.8403. This suggests:
   - The guard's sell order was not placed immediately at execute time
   - Or the market order was placed but took 32 hours to fill (impossible for a market order)
   - Or the fill was matched to this guard retroactively from a different execution

### Likely Explanation

This guard was monitoring a limit order at the 2.00 level (guard_reference=limit, exit_direction=above). When price crossed 2.00 on March 18, LevelMind marked the state as "executed." However, the underlying limit order may not have been filled at that time. Price subsequently reversed and fell to 1.84 by March 19, where the position was eventually closed as a loss.

The 32-hour delay and the 8% price gap strongly suggest a bug in guard state management or order execution:
- Either the sell order was never actually placed at 03:24:20
- Or the guard execution was recorded but the actual order submission failed/was delayed
- Or this represents a "zombie" guard state from the stale monitor thread issue mentioned in the git log (commit 8b4c5373: "fix: Stop LevelMind zombie monitor threads")

### Action Items

- **Critical**: Investigate why the execute decision at 03:24:20 did not result in an immediate order placement
- Check if this guard was affected by the zombie monitor thread bug
- Verify order placement logs for the 03:24:20 timeframe
- Determine whether the fill at 11:58:50 was from a separate order or the delayed guard order

## Signals Assessment

Not applicable until the timing anomaly is resolved. The 32-hour delay between execute decision and fill is a systemic issue, not a signal quality issue.
