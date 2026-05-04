# Case 014: MOODENGUSDT Guard Execution (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 |
| Symbol | MOODENGUSDT |
| Guard ID | 17 |
| Reference Level | 0.0512 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.0000471 |
| Outcome | Sold 28,742 @ 0.05116 (close_loss), WAEP was 0.05168 — loss of ~1.0% |
| Verdict | CORRECT |

## LevelMind Decision Trail

Guard 17 had two breach cycles before execution:

**First breach cycle (reclaimed):**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 16:16:20 | 347 | update_state | inconclusive | 0.05119 | Breach detected at 0.05119 |
| 16:16:21 | 349 | none | inconclusive | 0.05119 | Monitoring |
| 16:16:22 | 351 | none | inconclusive | 0.05119 | Monitoring |
| 16:16:22 | 353 | update_state | reclaim | 0.05121 | Price reclaimed above level, cooldown until 16:16:32 |
| 16:16:33 | 355 | update_state | inconclusive | 0.05124 | Cooldown expired, re-armed |

**Second breach cycle (executed):**

| Time (UTC) | Resp | Action | Classification | Last Price | Notes |
|------------|------|--------|----------------|------------|-------|
| 16:18:54 | 357 | update_state | inconclusive | 0.05116 | Second breach at 0.05116 |
| 16:18:54 | 358 | none | inconclusive | 0.05116 | Monitoring |
| 16:18:55 | 360 | none | inconclusive | 0.05116 | Price holding below level |
| 16:18:56 | 362 | none | inconclusive | 0.05116 | Still below |
| 16:18:56 | 364 | none | inconclusive | 0.05116 | Still below |
| 16:18:57 | 366 | none | inconclusive | 0.05116 | Still below |
| 16:18:58 | 368 | none | inconclusive | 0.05116 | Still below |
| 16:18:58 | 370 | none | inconclusive | 0.05116 | Still below |
| 16:18:59 | 372 | **execute** | **accept** | 0.05116 | **timeout_execute** — 5s expired, no reclaim |

Total decision time: 5 seconds from second breach to execution. The first breach was reclaimed after ~2 seconds, demonstrating LevelMind's reclaim detection working correctly before the second, decisive breach.

## Candle Data Around Breach

1m candles around the breach time (16:18 UTC):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 16:10 | 0.05144 | 0.05145 | 0.05127 | 0.05130 | 424,973 (5m) |
| 16:15 | 0.05130 | 0.05133 | 0.05115 | 0.05120 | 756,690 (5m) |

The 1m candle data provided covers 15:09-15:28, approximately 1 hour before breach. Price was already in a clear downtrend from 0.0521 toward the 0.0512 level. The 5m data shows the final approach:

- 16:00: Close at 0.05149 — level still holding
- 16:05: Close at 0.05144 — weakening
- 16:10: Close at 0.05130 — accelerating decline
- 16:15: Close at 0.05120 — level being tested, breach at 16:16:20

The downward momentum was sustained and steady over more than an hour.

## Post-Execution Price Action

5m candles after execution (16:18:59 UTC):

The 5m data ends at the 16:15 candle (close at 0.05120), which is the candle during which execution occurred. The breach at 0.05116 and execute at 0.05116 both happened within the 16:15-16:20 window.

Looking at the price trajectory leading into execution, price had been declining steadily:
- 15:05: 0.05208
- 15:25: 0.05169 (5m close)
- 15:45: 0.05166 (5m close)
- 16:00: 0.05149
- 16:15: 0.05120

The sustained downtrend (0.0521 to 0.0512, roughly -1.7% over 70 minutes) and the failure of the first reclaim at the level strongly suggested continued weakness.

## Verdict

**CORRECT EXECUTION**

This is a textbook LevelGuard execution:

1. **First breach was properly reclaimed** — price dipped to 0.05119 at 16:16:20 but bounced back to 0.05121 within 2 seconds, correctly classified as "reclaim" and re-armed.
2. **Second breach showed no bounce** — price fell to 0.05116 at 16:18:54 and stayed there for the full 5-second window with zero recovery attempt.
3. **Execution aligned with trend** — the broad trend was bearish, declining steadily over 70+ minutes.
4. **Fill price matched execute price** — both at 0.05116, indicating good liquidity and no slippage.
5. **Exit direction = below, mode = fails** — correctly configured. For a long position, "fails" means "execute if the support level breaks."

The loss was small (WAEP 0.05168 vs exit 0.05116 = -1.0%), and the guard protected against what could have been a larger drawdown.

## Signals Assessment

No additional signals needed. This execution performed as designed:
- The reclaim mechanism worked on the first test.
- The timeout mechanism correctly identified the second break as genuine.
- A potential improvement would be a "failed retest" signal: when a level is reclaimed once but broken again shortly after, it could warrant faster execution (e.g., reduced timeout window on the second breach).
