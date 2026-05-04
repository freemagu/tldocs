# Case 011: POLUSDT Guard Execution (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 |
| Symbol | POLUSDT |
| Guard ID | 21 |
| Reference Level | 0.0985 |
| Mode | fails |
| Trade Side | long |
| Decision | displacement |
| ATR (frozen) | 0.0000557 |
| Outcome | Displacement by 1 tick (1.26x ATR); immediate execution |
| Verdict | MARGINAL |

## Trade Context

- WAEP: 0.10139 (long entry)
- Position: 66,666 contracts
- Loss at execution: ~2.9% (filled at 0.09840 vs WAEP 0.10139)
- Leg type: close_loss (trade_id=2401)

## LevelMind Decision Trail

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 11:31:03 | 265 | update_state | inconclusive | -- | 0.09843 |
| 11:31:04 | 266 | execute | accept | displacement (1.26x ATR) | 0.09843 |

Only 2 ticks, ~1 second apart. Price at breach was 0.09843.

Displacement threshold calculation:
- Reference level: 0.0985
- 1x ATR below: 0.0985 - 0.0000557 = 0.09844
- Breach price: 0.09843

Price was just **1 tick** below the displacement threshold (0.09843 < 0.09844). LevelMind reported 1.26x ATR volatility multiple and executed immediately with confidence=1.0.

## Candle Data Around Breach

1m candles from 10:22-10:41 (about 50 minutes before breach at 11:31):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 10:22 | 0.09983 | 0.09984 | 0.09981 | 0.09982 | 37,016 |
| 10:27 | 0.09985 | 0.09985 | 0.09978 | 0.09983 | 34,285 |
| 10:30 | 0.09983 | 0.09983 | 0.09977 | 0.09983 | 97,226 |
| 10:35 | 0.09985 | 0.09985 | 0.09961 | 0.09966 | 306,835 |
| 10:36 | 0.09966 | 0.09970 | 0.09966 | 0.09970 | 13,890 |
| 10:39 | 0.09971 | 0.09971 | 0.09970 | 0.09970 | 44,728 |

Notable: the 10:35 candle has huge volume (306,835) and a sharp drop from 0.09985 to 0.09961. This signals the beginning of a sell-off. Price then stabilized around 0.09970 but the damage was done.

## Post-Execution Price Action

5m candles showing the decline:

| Time | Open | High | Low | Close | vs Level |
|------|------|------|-----|-------|----------|
| 10:30 | 0.09983 | 0.09990 | 0.09977 | 0.09985 | above |
| 10:35 | 0.09985 | 0.09985 | 0.09961 | 0.09970 | above |
| 10:40 | 0.09970 | 0.09976 | 0.09940 | 0.09953 | above |
| 10:45 | 0.09953 | 0.09958 | 0.09938 | 0.09953 | above |
| 10:55 | 0.09958 | 0.09966 | 0.09955 | 0.09965 | above |
| 11:05 | 0.09951 | 0.09970 | 0.09946 | 0.09970 | above |
| 11:10 | 0.09970 | 0.09991 | 0.09970 | 0.09978 | above |
| 11:15 | 0.09978 | 0.09986 | 0.09976 | 0.09984 | above |
| 11:20 | 0.09984 | 0.09984 | 0.09961 | 0.09962 | above |
| 11:25 | 0.09962 | 0.09962 | 0.09908 | 0.09912 | above |
| 11:30 | 0.09912 | 0.09918 | **0.09816** | 0.09832 | **breached** |

The 11:30 5m candle contains the breach. It shows a dramatic drop: open 0.09912, low 0.09816, close 0.09832. The low of 0.09816 is 6.1x ATR below the reference level. This was a genuine breakdown.

Price never recovered to the 0.0985 level within this candle -- the high was only 0.09918, still 12 ticks below the guard level. The break was conclusive.

## Verdict

**MARGINAL**

The execution was ultimately correct (price continued lower to 0.09816, 6.1x ATR below the level), but the displacement trigger mechanism is borderline:

1. **Razor-thin displacement**: The breach exceeded the displacement threshold by just 1 tick (0.09843 vs threshold 0.09844). Rounding or a slightly different ATR calculation could have changed the path from displacement to observation.
2. **Would timeout have been worse?** No. Price was at 0.09843 and stayed below -- a 5-second timeout would have produced the same execution at similar or better prices. The 5m candle low of 0.09816 didn't come until well after.
3. **Correct outcome**: Despite the marginal trigger, the execution was the right decision. The 5m candle confirms complete failure of the level with price ultimately trading 6.1x ATR below. The 11:25 5m candle already showed deterioration (0.09962 to 0.09908).

The concern is not whether to execute but *how* the decision was made. A 1-tick displacement should not have higher confidence than a timeout. The displacement path skips the observation window, yet this case had only 1 tick of evidence.

## Signals Assessment

- **CVD**: The 306,835 volume candle at 10:35 and the subsequent downtrend suggest sustained selling. CVD would have confirmed selling aggression and supported the execution decision.
- **OI**: Would help determine if this was forced liquidation or new shorts. The large volume spike at 10:35 suggests possible liquidation cascade.
- **Momentum**: Critical here. The displacement was just 1 tick -- momentum analysis could provide additional evidence to justify the immediate execution vs falling to the timeout path.
- **Extended window**: A 10-second window would have been appropriate for this edge case. With only 1.26x ATR displacement, an extra 5 seconds of observation would have added confidence without materially worsening the fill. Price was not moving fast enough to cause significant slippage in that window.
