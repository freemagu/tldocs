# Case 016: XANUSDT Guard Execution — ANOMALOUS (2026-03-19)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-19 |
| Symbol | XANUSDT |
| Guard ID | 31 |
| Reference Level | 0.0140 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.0000488 |
| Outcome | Sold 70,621 @ 0.01425533 (classified as TP), WAEP was 0.01093 — profit of ~30.4% |
| Verdict | ANOMALOUS — needs investigation |

## ANOMALY FLAGS

1. **Exit direction is "above"** — the guard was configured with `exit_direction: above`, meaning it fires when price goes ABOVE the reference level. For a long position with mode "fails", this is unusual (normally exit_direction would be "below" to guard support).
2. **Guard reference is "limit"** — this appears to be guarding a limit order level, not a stop loss.
3. **Breach price ABOVE reference level** — breach_price=0.014002 vs reference_level=0.0140. The price crossed above the level, not below it.
4. **Massive delay: ~63 minutes** — breach at 10:55:18, execution recorded at 10:55:23 in LevelMind, but the fill occurred at 11:58:49 (~63 minutes later).
5. **Fill at TP price, not guard price** — filled at 0.01425533 (leg_type=tp), not at the execute_price 0.014021. Position was in massive profit (WAEP 0.01093).
6. **Same trade_id as guard 30** — trade_id=2405, shared with guard_id=30 (XANUSDT at 0.0122 level).

## LevelMind Decision Trail

Guard 31 had THREE breach cycles — two reclaimed, third executed:

**First breach cycle (reclaimed):**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 10:18:02 | 394 | update_state | inconclusive | 0.014001 | Breach at 0.014001 (above 0.0140) |
| 10:18:03 | 395 | none | inconclusive | 0.014026 | Price rising above level |
| 10:18:04 | 396 | none | inconclusive | 0.014023 | Still above |
| 10:18:04 | 397 | none | inconclusive | 0.014004 | Pulling back toward level |
| 10:18:05 | 398 | none | inconclusive | 0.014017 | Oscillating |
| 10:18:06 | 399 | none | inconclusive | 0.014021 | Still above |
| 10:18:06 | 400 | update_state | **reclaim** | 0.013990 | Price fell below level = reclaimed |

**Second breach cycle (reclaimed):**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 10:55:00 | 402 | update_state | inconclusive | 0.014004 | Second breach at 0.014004 (~37 min later) |
| 10:55:01 | 403 | none | inconclusive | 0.014026 | Above |
| 10:55:02 | 404 | none | inconclusive | 0.014008 | Oscillating |
| 10:55:03-04 | 405-407 | none | inconclusive | 0.014013-0.014015 | Hovering |
| 10:55:05 | 408 | update_state | **reclaim** | 0.013999 | Fell back below again |

**Third breach cycle (executed):**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 10:55:18 | 410 | update_state | inconclusive | 0.014002 | Third breach at 0.014002 (~13 sec after reclaim) |
| 10:55:18-22 | 411-417 | none | inconclusive | 0.014010-0.014023 | Price staying above level |
| 10:55:23 | 418 | **execute** | **accept** | 0.014021 | **timeout_execute** — 5 seconds, no reclaim |

LevelMind executed at 10:55:23 with last price 0.014021. But the actual fill was at 11:58:49 at 0.01425533.

## Candle Data Around Breach

1m candles around the breach area (10:18 and 10:55):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 09:48 | 0.01384 | 0.01398 | 0.01383 | 0.01390 | 3,425,201 |
| 09:50 | 0.01390 | 0.01400 | 0.01390 | 0.01396 | 4,425,350 |
| 09:53 | 0.01392 | 0.01395 | 0.01372 | 0.01378 | 5,426,113 |
| 09:54 | 0.01378 | 0.01379 | 0.01362 | 0.01368 | 6,775,175 |
| 10:01 | 0.01377 | 0.01387 | 0.01374 | 0.01384 | 2,903,771 |

Price was oscillating around the 0.0140 level. It was a contested zone with high volume.

## Post-Execution Price Action

5m candles after LevelMind execution (10:55:23 UTC):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 10:55 | 0.01400 | 0.01436 | 0.01391 | 0.01400 | 32,089,197 |
| 11:00 | 0.01400 | 0.01423 | 0.01384 | 0.01414 | 15,380,658 |
| 11:05 | 0.01414 | 0.01424 | 0.01408 | 0.01416 | 13,333,652 |
| 11:10 | 0.01416 | 0.01421 | 0.01408 | 0.01413 | 8,311,095 |
| 11:15 | 0.01413 | 0.01428 | 0.01407 | 0.01410 | 11,654,369 |
| 11:20 | 0.01410 | 0.01412 | 0.01395 | 0.01402 | 11,279,007 |
| 11:25 | 0.01402 | 0.01425 | 0.01400 | 0.01413 | 10,669,599 |
| 11:30 | 0.01413 | 0.01414 | 0.01398 | 0.01406 | 7,731,649 |
| 11:40 | 0.01406 | 0.01425 | 0.01404 | 0.01417 | 5,382,658 |
| 11:50 | 0.01420 | 0.01445 | 0.01413 | 0.01429 | 25,133,214 |
| 11:55 | 0.01429 | 0.01433 | 0.01422 | 0.01426 | 8,137,061 |

After execution, price continued HIGHER. The 0.0140 level held as support and price rallied to 0.01445 by 11:50 — well above both the reference level and the execute price. The guard sold into a breakout.

## Verdict

**ANOMALOUS — needs investigation**

This guard exhibits several behaviors that do not match normal guard operation:

### Key Anomalies

1. **exit_direction=above with trade_side=long and mode=fails**: This configuration means "execute when price goes ABOVE the level and stays." For a long position, this would mean "sell when price breaks above resistance." This is unusual — it resembles a take-profit mechanism, not a stop-loss guard.

2. **guard_reference=limit**: This guard was attached to a limit order (likely a TP limit order at 0.0140). The guard appears to be monitoring whether a limit order level is breached, not whether a stop-loss level is broken.

3. **63-minute gap between LevelMind execute and fill**: LevelMind decided to execute at 10:55:23, but the fill timestamp in the order leg is 11:58:49. This suggests either:
   - The order took 63 minutes to fill (unlikely for a market sell)
   - The fill was matched to this guard retroactively
   - There was a processing delay or stale state

4. **Fill price (0.01425533) far above execute price (0.014021)**: The position was sold at a better price than the guard's execute price, which is consistent with a TP order filling at a limit price, not a guard-initiated market order.

5. **Position was massively profitable**: WAEP 0.01093 vs fill 0.01426 = +30.4% profit. This was not a protective stop — it was closing a very profitable position.

### Likely Explanation

This guard was likely attached to a take-profit limit order at the 0.0140 level. The guard_reference=limit and exit_direction=above configuration suggest it was monitoring when price crossed above the TP level. The actual fill at 0.01425533 (higher than 0.0140) as leg_type=tp confirms this was a TP execution, with the guard being an associated monitoring mechanism rather than the primary exit trigger.

### Action Items

- Investigate why guard executions against limit order levels are classified the same as stop-loss guard executions
- Clarify the meaning of guard_reference=limit in the guard configuration
- Determine why the fill timestamp is 63 minutes after the LevelMind execute decision

## Signals Assessment

Not applicable — this case requires architectural investigation into how guards interact with limit orders before signal assessment is meaningful.
