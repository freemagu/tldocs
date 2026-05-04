# Case 003: PHAUSDT Guard Execution — Timeout Stop Loss (2026-03-14)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-14 |
| Symbol | PHAUSDT |
| Guard ID | 12 |
| Reference Level | 0.03249 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.0000457 |
| Fill | sell 100,000 @ 0.0324289 (close_loss) |
| WAEP | 0.03377 |
| Trade ID | 2377 |
| Outcome | Price sat below level for 5 seconds, guard closed; price continued lower |
| Verdict | CORRECT execution |

## LevelMind Decision Trail

The guard had two breach attempts:

### First Breach (15:32:53) — Rejected

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 15:32:53 | 66 | update_state | inconclusive | 0.03249 | First breach — price exactly at level |
| 15:32:53–33:00 | 67–77 | update_state | inconclusive | 0.03249 | Price stuck at level for 7 seconds |
| 15:33:01 | 78 | update_state | inconclusive | 0.03251 | Price ticked above level |
| **15:33:01** | **79** | **update_state** | **reject** | **0.03251** | **Breach rejected — price reclaimed** |

The first breach was correctly rejected. Price touched 0.03249 but bounced to 0.03251 within ~8 seconds.

### Second Breach (15:35:10) — Executed

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 15:35:10 | 80 | update_state | inconclusive | 0.03250 | Second approach, above level by 1 tick |
| 15:35:11–32 | 81–112 | update_state | inconclusive | 0.03250 | Price hovering at 0.03250 for ~21 seconds |
| **15:35:33** | **113** | **update_state** | **inconclusive** | **0.03246** | **Price drops below level** |
| 15:35:34 | 114 | none | inconclusive | 0.03245 | Below level, 5s window starts |
| 15:35:34–37 | 115–119 | none | inconclusive | 0.03245–0.03246 | Oscillating below level |
| 15:35:38 | 120 | none | inconclusive | 0.03247 | Price ticks back to 0.03247 (still below 0.03249) |
| **15:35:38** | **121** | **execute** | **accept** | **0.03247** | **timeout_execute — 5s window expired** |

Key observations:
- From resp 80 to 112, price hovered at 0.03250 (1 tick above level) for 22 seconds before the decisive break.
- The actual break below 0.03249 happened at resp 113 (15:35:33) with price at 0.03246 (3 ticks below, ~0.66 ATR).
- Execution 5 seconds later at 0.03247, still 2 ticks below the level.
- The gap between first and second breach was about 2 minutes — suggests a genuine level retest.

## Candle Data Around Breach

The 1m candles cover 14:26–14:45, well before the breach. Using data from the 5m candle window:

| Time (5m) | Open | High | Low | Close | Vol | Note |
|-----------|------|------|-----|-------|-----|------|
| 14:25 | 0.03290 | 0.03292 | 0.03287 | 0.03291 | 131,632 | |
| 14:30 | 0.03291 | 0.03292 | 0.03270 | 0.03275 | 418,004 | Large sell volume, breakdown |
| 14:35 | 0.03275 | 0.03285 | 0.03271 | 0.03271 | 148,595 | |
| 14:40 | 0.03271 | 0.03278 | 0.03266 | 0.03267 | 156,177 | |
| 14:45 | 0.03267 | 0.03280 | 0.03266 | 0.03277 | 129,804 | |
| 14:50 | 0.03277 | 0.03284 | 0.03277 | 0.03281 | 114,450 | |
| 14:55 | 0.03281 | 0.03281 | 0.03256 | 0.03258 | 447,656 | Second big sell, approaches level |
| 15:00 | 0.03258 | 0.03275 | 0.03257 | 0.03275 | 136,541 | |
| 15:05 | 0.03275 | 0.03275 | 0.03272 | 0.03273 | 22,160 | Low volume, weak |
| 15:10 | 0.03273 | 0.03275 | 0.03266 | 0.03267 | 199,565 | |
| 15:15 | 0.03267 | 0.03272 | 0.03245 | 0.03263 | 561,421 | Wicked below level |
| 15:20 | 0.03263 | 0.03263 | 0.03255 | 0.03260 | 113,665 | |
| 15:25 | 0.03260 | 0.03264 | 0.03260 | 0.03263 | 4,882 | Dead volume |
| 15:30 | 0.03263 | 0.03263 | 0.03249 | 0.03254 | 103,413 | Touches level |
| **15:35** | **0.03254** | **0.03255** | **0.03234** | **0.03255** | **678,814** | **Breach candle — massive volume, long lower wick** |

The 15:35 breach candle has the highest volume in the dataset (678,814) and a wick down to 0.03234 (1.5 ATR below level). The candle closed at 0.03255, but by that time the guard had already executed at 15:35:38.

Wick analysis for the 15:35 5m candle:
- Range: 0.03255 - 0.03234 = 0.00021
- Lower wick: 0.03254 - 0.03234 = 0.00020 (95% of range is lower wick)
- This is almost entirely a wick candle — but the guard executed mid-wick.

## Post-Execution Price Action

Execute price: 0.03247 (sell). Using 5m candles after the 15:35 breach:

The 5m data ends at the 15:35 candle. However, the 15:35 candle closed at 0.03255 — above the execution price. Let's analyze what we know:

- The 15:35 candle low was 0.03234 (lower than execution at 0.03247)
- The candle closed at 0.03255 (higher than execution, above the level)
- This suggests the wick was rejected and price recovered

But we don't have post-15:35 5m candle data. Based on the tick data in the LevelMind trail, after execution (15:35:38), price was at 0.03247. The 5m candle closed at 0.03255 by 15:40, meaning price recovered by 8 ticks in the next ~2 minutes.

Looking at the bigger picture: the 1m candle data shows a steady decline from 0.03291 to 0.03267 over the preceding hour, with the 15:15 candle wicking to 0.03245. The overall trend was bearish. The WAEP was 0.03377 — the trade was already deeply underwater (loss of -3.85% at execution).

## Verdict

**MARGINAL** — The guard's execution was defensible given the bearish context (steady decline, level tested multiple times). However:

1. The 15:35 5m candle's close at 0.03255 (above execution price) suggests the immediate wick was rejected.
2. The first breach at 15:32:53 was correctly rejected (price bounced).
3. The second breach held below for only 5 seconds before execution.
4. With WAEP at 0.03377, the position was already -3.85% underwater — closing was reasonable regardless of short-term bounce.

The execution didn't obviously save from further loss (the candle's close was above execution price), but the overall trend context and deep drawdown made closing a defensible decision.

## Signals Assessment

- **CVD**: The 678,814 volume on the breach candle (highest in dataset) with a long lower wick could indicate selling exhaustion. CVD divergence might have suggested waiting longer.
- **OI**: OI changes during the wick would have indicated whether the move was liquidation-driven (likely recoverable) vs. new shorts (likely continuation).
- **Extended window**: A 10-15 second window instead of 5 would have caught the wick rejection.
- **Momentum**: The hourly trend was clearly bearish, but 1m RSI near the breach was likely oversold, suggesting a bounce was probable.
