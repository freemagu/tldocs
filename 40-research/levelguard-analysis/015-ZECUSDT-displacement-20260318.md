# Case 015: ZECUSDT Guard Execution (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 |
| Symbol | ZECUSDT |
| Guard ID | 28 |
| Reference Level | 250.00 |
| Mode | fails |
| Trade Side | long |
| Decision | displacement |
| ATR (frozen) | 0.38286 |
| Outcome | Sold 2.77 @ 249.68 (classified as TP, not close_loss), WAEP was 230.73 — profit of ~8.2% |
| Verdict | MARGINAL |

## LevelMind Decision Trail

Guard 28 had one breach cycle with a fast reclaim followed by immediate displacement execution:

| Time (UTC) | Resp | Action | Classification | Last Price | Evidence | Notes |
|------------|------|--------|----------------|------------|----------|-------|
| 16:58:35 | 375 | update_state | inconclusive | 249.97 | | Breach detected at 249.97, breach_price=249.97 |
| 16:58:36 | 376 | none | inconclusive | 249.97 | | Monitoring |
| 16:58:36 | 377 | none | inconclusive | 249.99 | | Price bouncing |
| 16:58:37 | 378 | none | inconclusive | 249.97 | | Below level again |
| 16:58:38 | 379 | none | inconclusive | 250.00 | | Touching level exactly |
| 16:58:38 | 380 | update_state | reclaim | 250.07 | | Price reclaimed to 250.07, cooldown until 16:58:48 |
| 16:58:41 | 381 | **execute** | **accept** | 249.58 | displacement (1.097x ATR) | **Displacement detected** at 249.58 |

Key observations:
- Breach at 16:58:35 with price 249.97 (just 0.03 below level)
- Price oscillated: 249.97 -> 249.99 -> 249.97 -> 250.00 -> 250.07 (reclaimed)
- During cooldown, price crashed to 249.58 — a displacement of 0.42 below 250.00
- Displacement threshold: 250.00 - 0.383 = 249.617. Price at 249.58 < 249.617 = displacement triggered
- Volatility multiple: 1.097x ATR (just over the 1.0x threshold)
- Confidence: 1.0

**Note on breach_price NULL in the original data:** The guard_attempt table shows breach_price=NULL. However, the LevelMind response data clearly shows the guard went through a breach (price 249.97) followed by reclaim (250.07), then displacement was detected during cooldown. The NULL breach_price in the attempt table may be because the reclaim cleared it before the displacement override.

## Candle Data Around Breach

1m candles around breach (16:58 UTC). The 1m data provided covers 15:49-16:08, approximately 1 hour before breach:

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 15:49 | 255.51 | 255.62 | 255.17 | 255.48 | 259 |
| 15:56 | 255.94 | 256.68 | 255.89 | 256.43 | 633 |
| 16:00 | 256.18 | 256.18 | 255.47 | 255.80 | 249 |
| 16:05 | 255.84 | 256.00 | 255.76 | 255.91 | 105 |

Price was trading around 255-256, well above the 250 guard level, about 1 hour before breach. The crash from 254 to below 250 happened rapidly in the 16:55 5m candle.

## Post-Execution Price Action

5m candles around and after execution (16:58:41 UTC):

| Time | Open | High | Low | Close | Vol | Distance from 250 |
|------|------|------|-----|-------|-----|-------------------|
| 16:35 | 253.11 | 253.68 | 252.11 | 253.49 | 2,068 | +3.49 |
| 16:40 | 253.49 | 254.05 | 253.19 | 253.54 | 1,000 | +3.54 |
| 16:45 | 253.54 | 254.57 | 253.44 | 254.44 | 588 | +4.44 |
| 16:50 | 254.44 | 254.52 | 253.70 | 254.05 | 1,501 | +4.05 |
| 16:55 | **254.05** | **254.05** | **249.00** | **250.08** | **8,248** | +0.08 |

The 16:55 candle is the crash candle — price dropped from 254.05 to a low of 249.00 (a $5.05 drop in one 5m candle), closing just barely above the level at 250.08. This is where the guard triggered.

The execution at 249.58 caught the sharp drop. However, the candle closed at 250.08, meaning price partially recovered within the same candle. No subsequent 5m candle data is available to see what happened after 17:00, so we cannot confirm whether price continued down or bounced.

## Verdict

**MARGINAL**

Arguments for correct execution:
- Displacement was genuine — price fell 1.097x ATR below the level in a violent move (249.00 low).
- The volatility was extreme (8,248 volume in the 16:55 candle vs. ~600-1,500 normal), suggesting a real breakdown.
- For a true "fails" guard, exiting on a sharp break is the right call.

Arguments against:
- **Leg type was classified as TP, not close_loss** — this is unusual for a guard execution and suggests the position was in significant profit (WAEP 230.73, exit 249.68 = +8.2%). The guard closed a winning position.
- The 16:55 candle low hit 249.00 but closed at 250.08, which is a reclaim within the same candle. This is a wick-through-level scenario, not a sustained break.
- With only 1.097x ATR displacement, this was barely over the threshold. The candle was a whipsaw.

The core question is whether guarding a support level at 250.00 for a position entered at 230.73 makes sense. The position had 8.2% unrealized profit — this guard was likely a trailing stop protecting profit, which changes the calculus. Still, the guard mechanically did what it was configured to do.

## Signals Assessment

- **Wick-depth analysis**: A signal checking whether displacement occurred at the candle extreme (wick) vs. the body (close) could distinguish genuine breaks from wicks. In this case, the close was 250.08 (above level) despite a 249.00 wick low.
- **Reclaim-during-cooldown override**: The displacement fired during cooldown after a reclaim. If reclaim has already been confirmed, perhaps displacement during cooldown should require a higher threshold (e.g., 1.5x ATR instead of 1.0x).
- **Position profitability context**: For guards protecting profit (WAEP far below level), more tolerance might be appropriate since the risk of a wick-stop is worse than the risk of giving back some profit.
