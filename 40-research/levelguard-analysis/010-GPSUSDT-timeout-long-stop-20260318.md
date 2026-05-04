# Case 010: GPSUSDT Guard Execution (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 |
| Symbol | GPSUSDT |
| Guard ID | 34 |
| Reference Level | 0.008393 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.00000907 |
| Outcome | Price breached by 6 ticks, held below for 5s, timeout executed |
| Verdict | CORRECT |

## Trade Context

- WAEP: 0.00858 (long entry)
- Position: 360,360 contracts
- Loss at execution: ~2.6% (filled at 0.0083564 vs WAEP 0.00858)
- Leg type: close_loss (trade_id=2391)

## LevelMind Decision Trail

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 11:30:49 | 256 | update_state | inconclusive | -- | 0.008387 |
| 11:30:49 | 257 | none | inconclusive | -- | 0.008387 |
| 11:30:50 | 258 | none | inconclusive | -- | 0.008387 |
| 11:30:51 | 259 | none | inconclusive | -- | 0.008387 |
| 11:30:52 | 260 | none | inconclusive | -- | 0.008387 |
| 11:30:52 | 261 | none | inconclusive | -- | 0.008387 |
| 11:30:53 | 262 | none | inconclusive | -- | 0.008387 |
| 11:30:54 | 263 | none | inconclusive | -- | 0.008386 |
| 11:30:54 | 264 | execute | accept | timeout_execute | 0.008386 |

9 ticks over ~5 seconds. Price breached at 0.008387 (6 ticks below the 0.008393 level), remained flat at 0.008387 for 7 checks, then dropped further to 0.008386 before timeout execution.

Breach depth: 0.008393 - 0.008387 = 0.000006 (6 ticks, 0.66x ATR). Below the 1x ATR displacement threshold but a meaningful breach at 6 ticks. No reclaim was attempted.

## Candle Data Around Breach

1m candles available from 10:21-10:40 (about 50 minutes before breach):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 10:21 | 0.008442 | 0.008442 | 0.008439 | 0.008439 | 11,001 |
| 10:25 | 0.008437 | 0.008448 | 0.008437 | 0.008448 | 16,831 |
| 10:31 | 0.008456 | 0.008466 | 0.008456 | 0.008462 | 53,057 |
| 10:35 | 0.008467 | 0.008467 | 0.008452 | 0.008452 | 32,143 |
| 10:38 | 0.008447 | 0.008449 | 0.008437 | 0.008437 | 39,167 |
| 10:40 | 0.008437 | 0.008437 | 0.008435 | 0.008437 | 80,036 |

Price was rangebound 0.00843-0.00847 in the hour before breach, then started drifting lower. The 5m candle data shows the decline accelerating:

## Post-Execution Price Action

5m candles showing the approach and breach:

| Time | Open | High | Low | Close | vs Level |
|------|------|------|-----|-------|----------|
| 11:15 | 0.008467 | 0.008480 | 0.008467 | 0.008474 | above |
| 11:20 | 0.008474 | 0.008480 | 0.008471 | 0.008471 | above |
| 11:25 | 0.008471 | 0.008471 | 0.008403 | 0.008403 | above |
| 11:30 | 0.008403 | 0.008419 | **0.008341** | 0.008367 | **breached** |

The 11:25 candle shows the first sign of trouble -- a drop from 0.008471 to 0.008403, just 1 tick above the guard level. Then the 11:30 candle breaks down hard: low of 0.008341, which is 5.7x ATR below the level. The close at 0.008367 is 2.9x ATR below -- a decisive break.

The breach candle (11:30) has a high of 0.008419, showing price did bounce after the initial drop but could not get anywhere near the 0.008393 level from below. The 0.008341 low confirms deep bearish follow-through.

## Verdict

**CORRECT EXECUTION**

The timeout execution was correct:

1. **Clean non-reclaim**: Price held at 0.008387 for the entire observation window. Zero reclaim attempts.
2. **Post-execution confirmation**: The 5m candle (11:30) shows price ultimately reached 0.008341 -- a 5.7x ATR break below the level. The break was genuine and significant.
3. **Orderly decline**: Not a spike or wick -- price drifted lower systematically from 0.008471 over 10 minutes, suggesting genuine selling pressure rather than a momentary liquidity gap.
4. **Fill quality**: The actual fill at 0.0083564 was close to the 5m candle close at 0.008367, suggesting the exit occurred during the heart of the sell-off rather than at the extremes.

## Signals Assessment

- **CVD**: Useful here to confirm sustained selling vs a single block sell. The 80,036 volume at 10:40 and 53,057 at 10:31 suggest institutional-sized activity. CVD could help quantify the aggression.
- **OI**: An OI decrease would signal long liquidations (confirming the break), while OI increase would signal new shorts being opened. Either confirms the bearish thesis.
- **Momentum**: Breach depth of 0.66x ATR was below displacement but consistent and deepening. A momentum-weighted score could have upgraded this to a faster execution.
- **Extended window**: Not needed -- the 5s timeout was sufficient given the clean non-reclaim. Price was clearly not coming back.
