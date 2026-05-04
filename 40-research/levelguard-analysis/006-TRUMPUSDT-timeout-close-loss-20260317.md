# Case 006: TRUMPUSDT Guard Execution — Timeout Stop Loss (2026-03-17)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-17 |
| Symbol | TRUMPUSDT |
| Guard ID | 33 |
| Reference Level | 3.750 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.01279 |
| Fill | sell 1,022 @ 3.7461 (close_loss) |
| WAEP | 3.9103 |
| Trade ID | 2380 |
| Outcome | Price broke below 3.750, two prior reclaims failed to hold, guard closed; price crashed further |
| Verdict | CORRECT execution |

## LevelMind Decision Trail

This guard had a complex decision trail with two earlier reclaim events before the final execution.

### First Breach (~04:21:26) — Reclaimed

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 04:21:26 | 154 | update_state | inconclusive | 3.748 | Below level by 2 ticks |
| **04:21:26** | **155** | **update_state** | **reclaim** | **3.753** | **Price bounced above level — reclaimed** |

Price dipped to 3.748 and immediately bounced to 3.753 within the same second. Correctly classified as a reclaim.

### Brief Recovery

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 04:21:36 | 156 | update_state | inconclusive | 3.756 | Price above level |

### Second Breach (~04:21:44) — Reclaimed Again

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 04:21:44 | 157 | update_state | inconclusive | 3.749 | Below level again |
| 04:21:44 | 158 | none | inconclusive | 3.749 | |
| **04:21:45** | **159** | **update_state** | **reclaim** | **3.751** | **Second reclaim** |

Another quick dip and bounce. Two reclaims in 19 seconds indicates the level is being heavily contested.

### Third Breach (04:21:55) — Executed

| Time (UTC) | Resp | Action | Classification | Last Price | Note |
|------------|------|--------|----------------|------------|------|
| 04:21:55 | 160 | update_state | inconclusive | 3.747 | Below level for third time |
| 04:21:56 | 161 | update_state | inconclusive | 3.747 | Holding below |
| 04:21:57 | 162 | none | inconclusive | 3.747 | |
| 04:21:57 | 163 | none | inconclusive | 3.748 | Tick up but still below |
| 04:21:58 | 164 | none | inconclusive | 3.748 | |
| 04:21:59 | 165 | none | inconclusive | 3.745 | New low — 5 ticks below |
| 04:21:59 | 166 | none | inconclusive | 3.746 | |
| 04:22:00 | 167 | none | inconclusive | 3.748 | Bounce attempt |
| 04:22:01 | 168 | none | inconclusive | 3.748 | |
| **04:22:01** | **169** | **execute** | **accept** | **3.746** | **timeout_execute — 5s window expired** |

Key observations:
- This is the **third** breach of 3.750 in 35 seconds. The first two reclaimed quickly, but this one didn't.
- Price dropped as low as 3.745 (5 ticks below, 0.39x ATR) during the observation window.
- Brief bounces to 3.748 (still below level) were insufficient for a reclaim.
- The pattern of progressively weaker bounces (3.753 → 3.751 → 3.748) before failure is a classic level breakdown signal.

## Candle Data Around Breach

The 1m candle data covers 03:12–03:31, about an hour before the breach at 04:21. Using 5m candle data:

| Time (5m) | Open | High | Low | Close | Vol | Note |
|-----------|------|------|-----|-------|-----|------|
| 03:10 | 3.864 | 3.864 | 3.823 | 3.830 | 192,059 | Top of range |
| 03:15 | 3.830 | 3.835 | 3.790 | 3.823 | 430,473 | Breakdown begins |
| 03:20 | 3.823 | 3.832 | 3.819 | 3.828 | 69,896 | |
| 03:25 | 3.828 | 3.842 | 3.826 | 3.829 | 81,312 | |
| 03:30 | 3.829 | 3.831 | 3.815 | 3.819 | 90,372 | Downtrend continues |
| 03:35 | 3.819 | 3.823 | 3.808 | 3.811 | 79,833 | |
| 03:40 | 3.811 | 3.811 | 3.783 | 3.792 | 220,060 | High volume, accelerating |
| 03:45 | 3.792 | 3.792 | 3.770 | 3.781 | 271,642 | |
| 03:50 | 3.781 | 3.786 | 3.766 | 3.782 | 158,358 | Testing lower |
| 03:55 | 3.782 | 3.793 | 3.780 | 3.786 | 66,058 | |
| 04:00 | 3.786 | 3.799 | 3.783 | 3.789 | 95,563 | |
| 04:05 | 3.789 | 3.797 | 3.778 | 3.785 | 94,529 | |
| 04:10 | 3.785 | 3.791 | 3.780 | 3.787 | 63,735 | |
| 04:15 | 3.787 | 3.796 | 3.769 | 3.776 | 155,399 | |
| **04:20** | **3.776** | **3.778** | **3.713** | **3.722** | **846,005** | **CRASH candle — level obliterated** |

The 04:20 5m candle is devastating: price crashed from 3.776 to a low of 3.713, closing at 3.722. Volume exploded to 846,005 (highest in dataset by far). The guard's breach at 04:21:55 falls within this candle.

The reference level of 3.750 was destroyed — the low of 3.713 is 37 ticks below the level (2.89x ATR).

## Post-Execution Price Action

Execute price: 3.746 (sell at 04:22:01). Fill at 3.7461.

The 5m data ends at 04:20 (close 3.722). But the 04:20 candle low was **3.713**, which is 33 ticks below the execution price. Since the guard executed at 04:22:01 (inside the 04:20–04:25 candle window), and the 04:20 candle closed at 3.722, price was already well below execution price by the end of that 5m candle.

The WAEP was 3.9103. At execution price 3.7461, the realized loss was:
- Loss per unit: 3.9103 - 3.7461 = **0.1642** (4.2% loss)
- Position: 1,022 units
- Total loss: ~$167.85

But if the position had held through to the candle low of 3.713:
- Additional adverse move: 3.746 - 3.713 = 0.033 more per unit
- Additional loss avoided: ~$33.73
- Plus any further continuation below 3.713

## Verdict

**CORRECT EXECUTION** — This is one of the clearest correct executions in the dataset:

1. **Three strikes**: The level was tested three times in 35 seconds with progressively weaker bounces (3.753 → 3.751 → 3.748 → failed). Classic level failure pattern.
2. **Volume confirmation**: The 04:20 5m candle had 846,005 volume — 4x the average. This was liquidation-driven selling.
3. **Price continued lower**: The 5m candle low of 3.713 (2.89x ATR below level) confirms the break was genuine.
4. **Deep drawdown context**: Position was already -4.2% from WAEP. The guard prevented additional losses.
5. **Trend alignment**: Price had been in a clear downtrend from 3.864 to 3.776 over the preceding hour before the crash candle.

## Signals Assessment

- **CVD**: Would have shown aggressive selling throughout the decline from 3.864 — confirming the trend.
- **OI**: The 846K volume crash candle likely involved mass long liquidations. OI decrease would have confirmed the cascade.
- **Momentum**: Price was in a sustained downtrend for 70+ minutes before the final break. No momentum divergence to suggest a bounce.
- **Extended window**: Not needed. Three failed reclaim attempts within 35 seconds provided more information than a longer single window would have.
