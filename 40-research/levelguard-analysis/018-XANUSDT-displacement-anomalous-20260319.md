# Case 018: XANUSDT Guard Execution — ANOMALOUS (2026-03-19)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-19 |
| Symbol | XANUSDT |
| Guard ID | 30 |
| Reference Level | 0.0122 |
| Mode | fails |
| Trade Side | long |
| Decision | displacement |
| ATR (frozen) | 0.0000488 |
| Outcome | Sold 35,310 @ 0.01425460 (classified as TP), WAEP was 0.01093 — profit of ~30.4% |
| Verdict | ANOMALOUS — needs investigation |

## ANOMALY FLAGS

1. **Exit direction is "above"** — fires when price goes ABOVE 0.0122, not below. For a long position, this guards an upward crossing.
2. **Guard reference is "limit"** — attached to a limit order level.
3. **Breach price ABOVE reference level** — breach_price=0.012328 vs reference_level=0.0122.
4. **~9-hour delay between LevelMind execute and fill** — LevelMind executed at 02:47:44, fill at 11:58:50.
5. **Fill price (0.01425460) massively above execute price (0.012332)** — price moved 16% higher between execute and fill.
6. **Same trade_id=2405 as guard 31 (Case 016)** — both guards were on the same XANUSDT position.
7. **Only 2 LevelMind responses** — breach and immediate displacement, no observation phase for the breach.

## LevelMind Decision Trail

Guard 30 had the fastest decision trail of any guard in this batch — only 2 responses:

| Time (UTC) | Resp | Action | Classification | Last Price | Evidence | Notes |
|------------|------|--------|----------------|------------|----------|-------|
| 02:47:43 | 392 | update_state | inconclusive | 0.012328 | | Breach at 0.012328 (above 0.0122 level) |
| 02:47:44 | 393 | **execute** | **accept** | 0.012332 | displacement (2.706x ATR, conf=1.0) | **Immediate displacement** |

Key observations:
- Only 1 second between breach detection and execution
- Displacement was strong: 2.706x ATR (well above the 1.0x threshold)
- Breach price 0.012328 is 0.000128 above the 0.0122 level = 2.62x ATR above
- The guard detected a clear displacement above the level and executed immediately with confidence=1.0

## Candle Data Around Breach

1m candles around breach (02:47 UTC). The data provided covers 01:38-01:57, about 50 minutes before breach:

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 01:38 | 0.011775 | 0.011775 | 0.011741 | 0.011763 | 209,673 |
| 01:45 | 0.011774 | 0.011812 | 0.011774 | 0.011802 | 233,001 |
| 01:48 | 0.011794 | 0.011846 | 0.011791 | 0.011828 | 486,535 |
| 01:49 | 0.011828 | 0.011840 | 0.011740 | 0.011747 | 531,908 |
| 01:53 | 0.011732 | 0.011739 | 0.011689 | 0.011694 | 431,529 |
| 01:57 | 0.011664 | 0.011718 | 0.011664 | 0.011710 | 781,626 |

At 01:57, price was around 0.01171 — well below the 0.0122 level. The 1m data doesn't extend to 02:47. Between 01:57 and 02:47 (~50 minutes), price moved from 0.01171 to 0.01233, a rally of ~5.3%. The guard detected this upward displacement as the price broke through 0.0122 convincingly.

## Post-Execution Price Action

5m candles around the fill time (~11:58:50 UTC, ~9 hours after execute):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 10:45 | 0.01375 | 0.01378 | 0.01360 | 0.01369 | 10,302,021 |
| 10:50 | 0.01369 | 0.01402 | 0.01369 | 0.01400 | 12,820,880 |
| 10:55 | 0.01400 | 0.01436 | 0.01391 | 0.01400 | 32,089,197 |
| 11:00 | 0.01400 | 0.01423 | 0.01384 | 0.01414 | 15,380,658 |
| 11:05 | 0.01414 | 0.01424 | 0.01408 | 0.01416 | 13,333,652 |
| 11:40 | 0.01406 | 0.01425 | 0.01404 | 0.01417 | 5,382,658 |
| 11:50 | 0.01420 | 0.01445 | 0.01413 | 0.01429 | 25,133,214 |
| 11:55 | 0.01429 | 0.01433 | 0.01422 | 0.01426 | 8,137,061 |

By the time of the actual fill, price was at 0.01425 — significantly above both the guard level (0.0122) and the execute price (0.012332). The fill at 0.01425460 represents a much better price than the guard's execute moment.

## Relationship to Guard 31 (Case 016)

Guards 30 and 31 both belong to **trade_id=2405** (XANUSDT long, WAEP 0.01093):

| Guard | Level | exit_direction | Breach Time | Execute Time | Fill Time | Fill Price |
|-------|-------|----------------|-------------|--------------|-----------|------------|
| 30 | 0.0122 | above | 02:47:43 | 02:47:44 | 11:58:50 | 0.01425460 |
| 31 | 0.0140 | above | 10:55:18 | 10:55:23 | 11:58:49 | 0.01425533 |

Both guards:
- Had exit_direction=above (fire when price crosses above)
- Were attached to limit orders (guard_reference=limit)
- Filled within 1 second of each other at nearly identical prices (~0.01425)
- Had massive delays between execute decision and fill
- Were classified as leg_type=tp

This suggests both guards were monitoring different price levels for the same TP order. When the position was eventually closed via TP at 0.01425, both guard executions were retroactively linked to the same fill.

## Verdict

**ANOMALOUS — needs investigation**

### Key Anomalies

1. **9-hour delay between execute and fill**: LevelMind decided to execute at 02:47:44 but the fill occurred at 11:58:50. This is not explained by normal order processing.

2. **Fill price 16% above execute price**: The guard decided to sell at 0.012332 but the fill was at 0.01425. Market sell orders would fill immediately at the current price, not 9 hours later at a 16% better price.

3. **Two guards on the same trade, same fill**: Guards 30 and 31 both linked to the same trade and filled at nearly the same price/time. This strongly suggests the TP fill was a single event that was attributed to both guards.

4. **guard_reference=limit with exit_direction=above**: This configuration means the guard was watching for price to cross above a limit order level. This is monitoring a TP trigger, not a stop-loss.

### Likely Explanation

This guard was attached to a TP limit order at or near the 0.0122 level (which represents a ~11.6% profit from WAEP 0.01093). When price breached above 0.0122 with displacement, LevelMind marked the guard as "executed." However, the actual TP limit order was likely set at a higher price (around 0.01425), and it wasn't until price reached that level ~9 hours later that the position was closed.

The guard execution and the TP fill are two separate events that were linked retroactively. The guard's "execute" was a monitoring event, not the actual order that closed the position.

### Action Items

- Clarify how guard_reference=limit guards interact with existing limit orders
- Investigate whether LevelMind's "execute" action for limit-type guards places a new order or simply flags the guard state
- Consider whether limit-type guard executions should be tracked separately from stop-loss guard executions in analytics

## Signals Assessment

Not applicable — the displacement detection was technically correct (price did move 2.7x ATR above the level), but the guard was monitoring a TP level, not a stop-loss. Signal assessment requires understanding the intended behavior for limit-type guards.
