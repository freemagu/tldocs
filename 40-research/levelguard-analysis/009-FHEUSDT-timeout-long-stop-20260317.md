# Case 009: FHEUSDT Guard Execution (2026-03-17)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-17 |
| Symbol | FHEUSDT |
| Guard ID | 27 |
| Reference Level | 0.02017 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.0000486 |
| Outcome | Price breached by 1 tick, held below for 5s, timeout executed |
| Verdict | CORRECT |

## Trade Context

- WAEP: 0.02139 (long entry)
- Position: 74,419 contracts
- Loss at execution: ~5.7% (filled at 0.0201001 vs WAEP 0.02139)
- Leg type: close_loss (trade_id=2393)

## LevelMind Decision Trail

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 17:03:22 | 184 | update_state | inconclusive | -- | 0.02016 |
| 17:03:23 | 185 | none | inconclusive | -- | 0.02016 |
| 17:03:24 | 186 | none | inconclusive | -- | 0.02016 |
| 17:03:24 | 187 | none | inconclusive | -- | 0.02016 |
| 17:03:25 | 188 | none | inconclusive | -- | 0.02016 |
| 17:03:26 | 189 | none | inconclusive | -- | 0.02016 |
| 17:03:27 | 190 | none | inconclusive | -- | 0.02016 |
| 17:03:27 | 191 | none | inconclusive | -- | 0.02016 |
| 17:03:28 | 192 | execute | accept | timeout_execute | 0.02014 |

9 ticks over ~6 seconds. Price stayed at 0.02016 for 7 consecutive checks (1 tick below the 0.02017 level), then dropped further to 0.02014 at execution time. No reclaim attempt was observed at any point during the observation window.

Breach depth: 0.02017 - 0.02016 = 0.00001 (1 tick). This is only 0.21x ATR -- well below the displacement threshold of 1x ATR (0.0000486). The timeout pathway was the correct mechanism.

## Candle Data Around Breach

1m candles available from 15:54-16:13 (approximately 50 minutes before breach):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 15:54 | 0.02043 | 0.02043 | 0.02042 | 0.02043 | 35,725 |
| 15:55 | 0.02043 | 0.02043 | 0.02039 | 0.02039 | 122,500 |
| 16:00 | 0.02040 | 0.02047 | 0.02040 | 0.02041 | 76,285 |
| 16:02 | 0.02041 | 0.02041 | 0.02024 | 0.02029 | 134,249 |
| 16:09 | 0.02034 | 0.02034 | 0.02019 | 0.02025 | 68,728 |

Clear downtrend from 0.02043 to 0.02025 over this window, with the 16:02 candle showing a sharp drop (high 0.02041 to low 0.02024). Price was grinding lower toward the guard level at 0.02017.

## Post-Execution Price Action

5m candles around breach:

| Time | Open | High | Low | Close | vs Level |
|------|------|------|-----|-------|----------|
| 16:50 | 0.02038 | 0.02046 | 0.02034 | 0.02034 | above |
| 16:55 | 0.02034 | 0.02036 | 0.02027 | 0.02027 | above |
| 17:00 | 0.02027 | 0.02031 | **0.02006** | 0.02013 | **breached** |

The 17:00 5m candle shows the breach: open at 0.02027, dropped to low of 0.02006 (2.3x ATR below the reference level), closed at 0.02013. This is the last 5m candle in the dataset.

The low of 0.02006 confirms price continued falling well below the guard level after the breach. The guard level was genuinely broken.

## Verdict

**CORRECT EXECUTION**

Despite the breach being minimal (just 1 tick / 0.21x ATR), the execution was correct for several reasons:

1. **No reclaim attempt**: Price stayed at or below 0.02016 for the entire observation window (all 9 ticks). Not a single check showed price back at or above 0.02017.
2. **Continued deterioration**: At execution, price had dropped further to 0.02014 (3 ticks below the level).
3. **Post-execution confirmation**: The 5m candle shows price ultimately reached 0.02006, which is 2.3x ATR below the level. The break was genuine.
4. **Downtrend context**: The preceding hour showed a clear downtrend from 0.02043 to the breach level.

The 5-second timeout was appropriate here. The breach was small but decisive -- price never made any attempt to reclaim.

## Signals Assessment

- **CVD**: Could confirm selling pressure. In a thin market like FHE, CVD delta might help distinguish between a single large sell order vs sustained selling. Would not have changed the decision here given the clean non-reclaim.
- **OI**: Open interest changes could indicate whether this was closing of longs vs opening of new shorts. Informational but would not change the timeout decision.
- **Momentum**: With only 1 tick of breach depth, a momentum check would show weak but persistent selling. Not actionable for this case.
- **Extended window**: A 10-15 second window would have produced the same result -- price was still at 0.02014 or lower. No benefit from extension here.
