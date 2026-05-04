# Case 012: DASHUSDT Guard Execution (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 |
| Symbol | DASHUSDT |
| Guard ID | 35 |
| Reference Level | 33.40 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.04143 |
| Outcome | Third breach attempt succeeded after two reclaims; timeout executed |
| Verdict | CORRECT |

## Trade Context

- WAEP: 34.337 (long entry)
- Position: 34.12 contracts
- Loss at execution: ~2.8% (filled at 33.36 vs WAEP 34.337)
- Leg type: close_loss (trade_id=2397)

## LevelMind Decision Trail

This guard had the most complex decision trail of the batch, with **three separate breach attempts** and two reclaims before final execution.

### Breach Attempt 1 (12:31:30-12:31:31) -- RECLAIMED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:31:30 | 267 | update_state | inconclusive | -- | 33.39 |
| 12:31:31 | 268 | update_state | reclaim | reclaimed | 33.41 |

Price briefly dipped to 33.39 (1 tick below 33.40) but snapped back to 33.41 within 1 second. LevelMind classified this as a reclaim and entered 10-second cooldown.

### Cooldown + Observation (12:31:41-12:31:46) -- REJECTED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:31:41 | 269 | update_state | inconclusive | -- | 33.43 |
| 12:31:44 | 270 | update_state | inconclusive | obs start | 33.41 |
| 12:31:44 | 271 | update_state | inconclusive | -- | 33.41 |
| 12:31:45 | 272 | update_state | inconclusive | safe_count=1 | 33.42 |
| 12:31:46 | 273 | update_state | reject | -- | 33.42 |

After cooldown expired, price was at 33.43 (above level). Observation began, and with price at 33.42 (safe_count=1), LevelMind rejected the guard trigger as the level was holding.

### Observation Phase 2 (12:32:03-12:32:06) -- REJECTED AGAIN

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:03 | 276 | update_state | inconclusive | obs start | 33.41 |
| 12:32:04 | 278 | update_state | inconclusive | -- | 33.41 |
| 12:32:05 | 280 | update_state | inconclusive | -- | 33.41 |
| 12:32:05 | 281 | update_state | inconclusive | safe_count=1 | 33.42 |
| 12:32:06 | 282 | update_state | reject | -- | 33.42 |

Same pattern: price hovered at 33.41-33.42, generated a safe count, and was rejected. The level appeared to be holding.

### Breach Attempt 2 (12:32:11-12:32:13) -- RECLAIMED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:10 | 283 | update_state | inconclusive | obs start | 33.40 |
| 12:32:11 | 284 | update_state | inconclusive | breach | 33.39 |
| 12:32:12 | 285 | none | inconclusive | -- | 33.40 |
| 12:32:13 | 286 | update_state | reclaim | reclaimed | 33.42 |

Price dipped to 33.39 again, bounced to 33.40, then reclaimed to 33.42. Second reclaim, second cooldown.

### Observation Phase 3 + Breach Attempt 3 (12:32:39-12:32:48) -- EXECUTED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:23 | 292 | update_state | inconclusive | -- | 33.43 |
| 12:32:39 | 294 | update_state | inconclusive | obs start | 33.41 |
| 12:32:40 | 296 | update_state | inconclusive | -- | 33.41 |
| 12:32:41 | 298 | update_state | inconclusive | -- | 33.41 |
| 12:32:42 | 301 | update_state | inconclusive | -- | 33.40 |
| 12:32:42 | 302 | update_state | inconclusive | breach | 33.39 |
| 12:32:43 | 304 | none | inconclusive | -- | 33.39 |
| 12:32:44 | 306 | none | inconclusive | -- | 33.39 |
| 12:32:44 | 309 | none | inconclusive | -- | 33.39 |
| 12:32:45 | 311 | none | inconclusive | -- | 33.39 |
| 12:32:46 | 313 | none | inconclusive | -- | 33.39 |
| 12:32:46 | 315 | none | inconclusive | -- | 33.39 |
| 12:32:47 | 317 | none | inconclusive | -- | 33.39 |
| 12:32:48 | 319 | execute | accept | timeout_execute | 33.39 |

This time, after the third breach to 33.39, price did not reclaim. It stayed at 33.39 for 6+ seconds through 8 consecutive checks, triggering timeout execution.

## Candle Data Around Breach

1m candles from 11:23-11:42 (about 50 minutes before breach):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 11:23 | 35.20 | 35.20 | 35.17 | 35.17 | 11 |
| 11:25 | 35.11 | 35.11 | 35.02 | 35.02 | 213 |
| 11:28 | 34.92 | 34.96 | 34.70 | 34.82 | 5,638 |
| 11:30 | 34.74 | 34.74 | 34.47 | 34.52 | 3,423 |
| 11:31 | 34.52 | 34.52 | 34.22 | 34.31 | 17,506 |
| 11:37 | 34.05 | 34.05 | 33.72 | 33.75 | 9,567 |
| 11:40 | 33.78 | 33.92 | 33.73 | 33.91 | 1,121 |

Massive downtrend: from 35.20 to 33.75 in 15 minutes. Volume spiked on the way down (17,506 at 11:31). Price was collapsing toward the guard level at 33.40.

## Post-Execution Price Action

5m candles around execution:

| Time | Open | High | Low | Close | vs Level |
|------|------|------|-----|-------|----------|
| 12:05 | 33.85 | 33.91 | 33.72 | 33.73 | above |
| 12:10 | 33.73 | 33.87 | 33.70 | 33.82 | above |
| 12:15 | 33.82 | 33.86 | 33.72 | 33.78 | above |
| 12:20 | 33.78 | 33.84 | 33.75 | 33.76 | above |
| 12:25 | 33.76 | 33.81 | 33.69 | 33.75 | above |
| 12:30 | 33.75 | 33.75 | **33.27** | 33.39 | **breached** |

The 12:30 5m candle tells the story: opened at 33.75, crashed to a low of 33.27, closed at 33.39. The level at 33.40 was breached decisively. The low of 33.27 is 3.14x ATR below the level -- a genuine break.

## Verdict

**CORRECT EXECUTION**

This is the most interesting case in the batch because it demonstrates the reclaim mechanism working as designed:

1. **Two successful reclaims**: The first two breaches (12:31:30 and 12:32:11) were correctly identified as wick rejections. Price bounced back above the level both times. The guard correctly did NOT execute on these.
2. **Third breach stuck**: On the third breach at 12:32:42, price stayed at 33.39 for 6+ seconds with no bounce. The timeout fired correctly.
3. **Post-execution confirmation**: The 5m candle low of 33.27 (3.14x ATR below level) confirms the level was genuinely broken. The fills before that wick would have been better than letting the trade run.
4. **Overall context**: DASH had been in freefall from 35.20 to 33.40 in the preceding hour. The two temporary reclaims above 33.40 were dead cat bounces in a brutal downtrend.

The guard correctly gave the level two chances to hold, then executed when it was clear the support had failed.

## Signals Assessment

- **CVD**: Highly relevant here. CVD during the reclaim periods could distinguish between genuine buying interest (large positive delta) vs thin bounces (low delta). If CVD showed weak buying on the reclaims, it could have accelerated execution on the second breach instead of waiting for a third.
- **OI**: During the 35.20-to-33.40 waterfall, tracking OI could reveal whether this was a liquidation cascade. Large OI decreases would suggest forced selling, making reclaims less likely to hold.
- **Momentum**: A downward momentum score across the preceding 5m candles would have added context to the breach decisions. The trend was clearly bearish.
- **Extended window**: Not needed for the final execution (price was flat at 33.39 for 6+ seconds). However, a shorter timeout for repeated breach attempts could be valuable -- if a level has already been breached and reclaimed twice, the third breach arguably deserves faster execution.
