# Case 008: DEXEUSDT Guard Execution (2026-03-17)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-17 |
| Symbol | DEXEUSDT |
| Guard ID | 22 |
| Reference Level | 5.40 |
| Mode | fails |
| Trade Side | short |
| Decision | displacement |
| ATR (frozen) | 0.01059 |
| Outcome | Immediate displacement; price 5.4342 already 3.2x ATR above level at first tick |
| Verdict | CORRECT |

## Trade Context

- WAEP: 5.13483 (short entry)
- Position: 935 contracts
- Loss at execution: ~6.6% (filled at 5.47302 vs WAEP 5.13483)
- Leg type: close_loss (trade_id=2392)

## LevelMind Decision Trail

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 08:47:27 | 182 | update_state | inconclusive | -- | 5.4342 |
| 08:47:28 | 183 | execute | accept | displacement (5.38x ATR) | 5.4569 |

Only 2 ticks total. Price at breach was already 5.4342, which is 0.0342 above the 5.40 level (3.23x ATR). By the next 500ms check, price had surged further to 5.4569 (5.38x ATR multiple reported by LevelMind). Immediate execution with confidence=1.0.

## Candle Data Around Breach

1m candles are available from 07:38-07:57, approximately 50 minutes before the breach. These show steady upward momentum from 5.17 to 5.25:

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 07:38 | 5.1709 | 5.1715 | 5.1698 | 5.1708 | 117 |
| 07:40 | 5.1732 | 5.1959 | 5.1732 | 5.1948 | 349 |
| 07:46 | 5.2073 | 5.2218 | 5.2073 | 5.2180 | 322 |
| 07:48 | 5.2240 | 5.2376 | 5.2240 | 5.2312 | 1195 |
| 07:55 | 5.2326 | 5.2439 | 5.2326 | 5.2439 | 980 |
| 07:57 | 5.2473 | 5.2545 | 5.2467 | 5.2545 | 507 |

The 5m candle containing the breach (08:45) tells the story:

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 08:45 | 5.2994 | **5.5141** | 5.2994 | 5.4980 | 33,582 |

This is a massive bullish candle -- a 4% move in 5 minutes with 33,582 volume (vs prior 5m candles averaging ~2,000). Price blew through 5.40 with extreme momentum.

## Post-Execution Price Action

Using 5m candles after breach (08:47):

| Time | Open | High | Low | Close | Ref Level |
|------|------|------|-----|-------|-----------|
| 08:45 | 5.2994 | 5.5141 | 5.2994 | 5.4980 | 5.40 |

Only one 5m candle covers the breach window. The candle closed at 5.4980, high of 5.5141 -- price remained far above the 5.40 reference level. The close at 5.4980 is 9.3x ATR above the reference. This was a genuine breakout, not a wick.

Earlier 5m candles show the sustained rally:
- 07:40: 5.17 -> 5.21 (acceleration begins)
- 08:00: 5.24 -> 5.28 (continued push)
- 08:30: 5.27 -> 5.30 (momentum building)
- 08:45: 5.30 -> 5.50 (explosive breakout through 5.40)

## Verdict

**CORRECT EXECUTION**

This is a textbook displacement case. Price arrived at the guard level having already moved 3.2x ATR beyond it -- there was no ambiguity about whether this was a wick or a genuine break. The explosive 5m candle (33,582 volume, 4% range) confirms this was a momentum-driven breakout, not a brief spike.

The guard correctly identified that the short's stop level at 5.40 had failed catastrophically. Waiting for a 5-second timeout would have served no purpose -- price was already deep into displacement territory on the very first tick.

Fill slippage was moderate: execute_price=5.4569, fill=5.47302 (0.16 difference, ~16 ticks). Given the velocity of the move, this slippage is expected.

## Signals Assessment

- **CVD**: Would likely show aggressive buying -- confirms displacement. Not needed; pure price action was sufficient.
- **OI**: A large OI spike during this candle would indicate new positions being opened (short squeeze). Useful for context but would not change the decision.
- **Momentum**: Already captured by the displacement threshold itself. The 5.38x ATR multiple speaks for itself.
- **Extended window**: Would have been counterproductive here. With price already 3.2x ATR beyond the level, any delay risks worse fill.
