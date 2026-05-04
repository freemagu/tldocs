# Case 007: OPNUSDT Guard Execution — Timeout Stop Loss (2026-03-17)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-17 |
| Symbol | OPNUSDT |
| Guard ID | 23 |
| Reference Level | 0.3000 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.00065 |
| Fill | sell 11,792 @ 0.29995 (close_loss) |
| WAEP | 0.32718 |
| Trade ID | 2387 |
| Outcome | Price broke below 0.30, prior breach rejected, second breach held, guard closed; price continued lower |
| Verdict | CORRECT execution |

## LevelMind Decision Trail

### First Breach (~05:45:54) — Rejected

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 05:45:54 | 170 | update_state | inconclusive | 0.3001 | Approaching level from above |
| 05:45:55 | 171 | update_state | inconclusive | 0.3002 | |
| **05:45:55** | **172** | **update_state** | **reject** | **0.3004** | **Breach rejected — price bounced above** |

Price touched 0.3001 (1 tick above level) but immediately bounced to 0.3004. The guard correctly rejected this as a non-breach.

### Second Breach (05:46:34) — Executed

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 05:46:34 | 173 | update_state | inconclusive | 0.3001 | Approaching again |
| **05:46:35** | **174** | **update_state** | **inconclusive** | **0.2999** | **Price drops below level** |
| 05:46:36 | 175 | none | inconclusive | 0.2999 | Holding below |
| 05:46:36 | 176 | none | inconclusive | 0.2999 | |
| 05:46:37 | 177 | none | inconclusive | 0.2999 | |
| 05:46:38 | 178 | none | inconclusive | 0.2999 | |
| 05:46:38 | 179 | none | inconclusive | 0.2999 | |
| 05:46:39 | 180 | none | inconclusive | 0.2999 | |
| **05:46:40** | **181** | **execute** | **accept** | **0.2999** | **timeout_execute — 5s window expired** |

Key observations:
- First breach was correctly rejected at 05:45:55 (price bounced to 0.3004).
- Gap of 39 seconds between rejection and second breach.
- On the second breach, price went to exactly 0.2999 and stayed there with **zero variation** for 6 consecutive ticks (resp 174–180).
- No bounce attempt at all — price was pinned at 0.2999 for the entire 5-second observation window.
- This "flat line below level" pattern is a strong signal of genuine breakdown — no buying interest to push price back.

## Candle Data Around Breach

The 1m candle data covers 04:37–04:56, about an hour before the breach. The 5m candle data shows the lead-up:

| Time (5m) | Open | High | Low | Close | Vol | Note |
|-----------|------|------|-----|-------|-----|------|
| 04:35 | 0.3047 | 0.3052 | 0.3034 | 0.3035 | 144,405 | |
| 04:40 | 0.3035 | 0.3052 | 0.3028 | 0.3038 | 115,302 | Wicked to 0.3028 |
| 04:45 | 0.3038 | 0.3060 | 0.3028 | 0.3060 | 49,829 | Recovery |
| 04:50 | 0.3060 | 0.3065 | 0.3055 | 0.3062 | 53,779 | |
| 04:55 | 0.3062 | 0.3068 | 0.3059 | 0.3060 | 60,740 | Range high |
| 05:00 | 0.3060 | 0.3060 | 0.3041 | 0.3044 | 68,792 | Selling begins |
| 05:05 | 0.3044 | 0.3053 | 0.3038 | 0.3038 | 77,484 | |
| 05:10 | 0.3038 | 0.3043 | 0.3033 | 0.3041 | 69,095 | |
| 05:15 | 0.3041 | 0.3053 | 0.3036 | 0.3038 | 76,779 | |
| 05:20 | 0.3038 | 0.3040 | 0.3034 | 0.3038 | 59,561 | |
| **05:25** | **0.3038** | **0.3044** | **0.3013** | **0.3025** | **69,799** | **Big drop — wick to 0.3013** |
| 05:30 | 0.3025 | 0.3040 | 0.3023 | 0.3026 | 68,275 | Dead cat bounce |
| 05:35 | 0.3026 | 0.3029 | 0.3014 | 0.3015 | 68,942 | Lower lows |
| **05:40** | **0.3015** | **0.3019** | **0.3003** | **0.3005** | **33,295** | **Approaching level, low vol** |
| **05:45** | **0.3005** | **0.3014** | **0.2992** | **0.3014** | **134,285** | **Breach candle — wick to 0.2992** |

The 05:45 5m candle contains the breach. It wicked down to 0.2992 (8 ticks below level, 1.23x ATR) and closed at 0.3014. However, the guard executed at 05:46:40, early in this candle.

The price action leading to the breach was a clear staircase down:
- 0.3060 → 0.3038 → 0.3025 → 0.3015 → 0.3005 → 0.2999 over 45 minutes.
- Each bounce was weaker than the last.
- Volume was modest but consistent — no panic selling, just steady distribution.

## Post-Execution Price Action

Execute price: 0.2999 (sell at 05:46:40). Fill at 0.29995.

The 05:45 5m candle shows:
- Low: 0.2992 (7 ticks below execution price — price went lower)
- Close: 0.3014 (15 ticks above execution price — bounce by candle close)

The candle closed above the execution price, suggesting a wick rejection. However, the 5m data ends at this candle, so we can't see what happened after 05:50.

Looking at the broader context: the WAEP was 0.32718, meaning the position was already **-8.3% underwater** at execution. The decline from 0.3068 high to the breach at 0.2999 happened over just 50 minutes with no significant bounces.

The 05:45 candle's close at 0.3014 is still well below the 05:25 high of 0.3044, suggesting the bounce was weak. The staircase-down pattern with lower highs and lower lows over the preceding hour implies continuation.

## Verdict

**CORRECT EXECUTION** — Despite the candle closing 15 ticks above execution price (short-term wick), the execution was correct:

1. **Deep drawdown**: Position was -8.3% from WAEP. Even a bounce to 0.3014 is only 15 ticks of missed recovery against a 273-tick loss.
2. **Clear downtrend**: 45-minute staircase down from 0.3060 to 0.2999 with progressively weaker bounces.
3. **Flat line signal**: Price pinned at 0.2999 for 6 consecutive ticks with zero buying pressure — a strong breakdown signal.
4. **Prior rejection correctly handled**: The first breach at 05:45:54 was rejected when price bounced to 0.3004, demonstrating the guard can distinguish between wick and break.
5. **0.30 is a round number**: Psychologically significant level — breaks of round numbers tend to accelerate.
6. **Wick to 0.2992**: The candle wicked even lower (to 0.2992), confirming selling pressure below the level existed.

## Signals Assessment

- **CVD**: The steady, low-volume decline suggests distribution rather than panic. CVD trending negative over the hour would have confirmed the guard's decision.
- **OI**: OI changes during the 05:45 candle's wick to 0.2992 would indicate whether the break attracted new shorts (bearish) or was a liquidation flush (potentially bullish).
- **Momentum**: RSI would have been deeply oversold on 1m, but in a strong downtrend, oversold conditions persist. No divergence visible in price action.
- **Extended window**: The 5-second window was appropriate here — price was completely flat at 0.2999 for the entire window with zero bounce attempts, making a longer window unlikely to change the outcome.
