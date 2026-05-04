# Case 001: MNTUSDT Wick Execution (2026-03-19)

## Summary

| Field | Value |
|-------|-------|
| **Date** | 2026-03-19 |
| **Symbol** | MNTUSDT |
| **Category** | Linear (perp) |
| **Guard ID** | 37 |
| **Reference Level** | 0.7250 |
| **Mode** | fails |
| **Trade Side** | long |
| **ATR (frozen)** | 0.00085 |
| **Outcome** | **Bad execution** — sold into a wick rejection |
| **Verdict** | Guard should NOT have executed |

## Position Context

- Original entry: 0.7772 (E1, 6510.4 qty) on 2026-03-15
- TP1 filled at 0.8000 (1085 qty)
- TP2 filled at 0.8500 (1085 qty)
- Position suspended at 0.8405, resumed at 0.7628 (resume_entry + resume_add)
- DCA at 0.7736 (E2, 1935.6 qty)
- WAEP at execution time: 0.7700
- Guarded quantity: 9,678.1
- Remaining after execution: 1,935.6 (with SL at 0.7000, TP at 0.9200)

## Timeline (UTC)

| Time | Price | Event |
|------|-------|-------|
| 15:45:00 | 0.7294 | Sell-off accelerates, 1m candle drops from 0.7294 to low 0.7262 |
| 15:46:00 | 0.7268 | Price approaches level; 1m candle low touches 0.7250 exactly |
| **15:46:48** | **0.7251** | LevelMind starts touch observation (price in touch band) |
| 15:46:48-55 | 0.7251 | 12 consecutive "inconclusive" readings at 0.7251 |
| **15:46:56** | **0.7254** | Classification: **REJECT** — touch bounce confirmed, price moved to safe zone |
| 15:46:56-15:47:17 | ~0.725x | Idle armed period (no events written, price hovering near level) |
| **15:47:18** | **0.7248** | **BREACH DETECTED** — price crosses below 0.7250. 5-second reclaim window starts |
| 15:47:19 | 0.7247 | Below level, not reclaimed |
| 15:47:19 | 0.7247 | Still below |
| 15:47:20 | 0.7246 | **Low point** of the breach window |
| 15:47:21 | 0.7247 | Recovering... |
| 15:47:21 | 0.7248 | Recovering... |
| 15:47:22 | 0.7249 | **1 tick from reclaim** |
| 15:47:23 | 0.7249 | **TIMEOUT_EXECUTE** — 5s window expires. Price was 1 tick short of reclaiming |
| 15:47:24 | — | Market sell fills at **0.7242** (7-tick slippage on market order) |
| **15:48:00** | **0.7255** | Price reclaims level (next candle closes above 0.7250) |
| 15:49:00 | 0.7273 | Full recovery |
| 15:50:00 | 0.7295 | +53 ticks above execution price |
| 15:52:00 | 0.7316 | +74 ticks above execution price |

## 1-Minute Candle Data Around Breach

```
Time   Open    High    Low     Close   Volume
15:44  0.7296  0.7296  0.7294  0.7294    6,870
15:45  0.7294  0.7294  0.7262  0.7268  131,040   <- sell-off intensifies
15:46  0.7268  0.7269  0.7250  0.7260   69,618   <- touches level, closes above
15:47  0.7260  0.7260  0.7222  0.7244  199,803   <- THE BREACH CANDLE
15:48  0.7244  0.7256  0.7239  0.7255   18,574   <- reclaims level
15:49  0.7255  0.7276  0.7254  0.7273   72,727   <- full recovery
15:50  0.7273  0.7300  0.7273  0.7295  116,432   <- continues higher
15:51  0.7295  0.7299  0.7291  0.7297   13,677
15:52  0.7297  0.7319  0.7294  0.7316   59,929   <- +74 ticks above fill
```

## Breach Candle Analysis (15:47)

```
O=0.7260  H=0.7260  L=0.7222  C=0.7244

Price
0.7260 ─ ━━━ Open / High
         ┃
0.7250 ─ ┃ ── reference level ──
         ┃
0.7244 ─ ━━━ Close (body bottom)
         │
         │   ← lower wick: 22 ticks
         │
0.7222 ─ ╵   Low

Total range:  38 ticks (0.7260 - 0.7222)
Body:         16 ticks (0.7260 - 0.7244) = 42% of range
Lower wick:   22 ticks (0.7244 - 0.7222) = 58% of range
Upper wick:    0 ticks

Wick ratio: 0.58 — classic rejection / pin bar pattern
```

**Key observation**: The candle wick extends 28 ticks below the reference level (0.7250 - 0.7222), but the close is only 6 ticks below (0.7250 - 0.7244). The body barely breaches the level while the wick does the damage. This is textbook stop-hunt / liquidity grab price action.

## What LevelMind Saw vs What Actually Happened

### What LevelMind saw (tick polling at 500ms):
- Price crossed below 0.7250 to 0.7248
- Stayed below for 5 seconds (0.7246-0.7249 range)
- Never reclaimed 0.7250
- → Executed per rules: "reclaim window expired"

### What actually happened (full candle context):
- Price flash-wicked to 0.7222 (below displacement threshold of 0.7242!)
- LevelMind never saw 0.7222 — it happened between polls
- By the time LevelMind polled, price was already recovering (0.7248)
- Price was in a clear V-shaped recovery during the entire breach window
- The 15:47 candle formed a rejection candle (58% lower wick)
- The very next candle closed above the level (0.7255)
- 5 minutes later price was at 0.7316 — 74 ticks above the fill

### Damage assessment:
- Fill price: 0.7242
- Price 5 min later: 0.7316
- **Adverse move from execution: 74 ticks / $71.73 per 1000 qty / ~$694 on 9,678 qty**

## Root Causes Identified

### 1. Fixed 5-second reclaim window is too short
Price was at 0.7249 (1 tick from reclaiming) when the timer expired. Even 1-2 more seconds would have caught the reclaim. The window doesn't adapt to volatility or price direction.

### 2. No candle structure awareness
The system evaluates individual ticks with no concept of the forming candle's shape. A 58% lower wick is a screaming rejection signal that any manual trader would recognize.

### 3. No price momentum tracking during breach
The readings during breach: 0.7248 → 0.7246 → 0.7247 → 0.7248 → 0.7249. Price was RECOVERING (positive slope). The system doesn't track direction — it only checks "is price above/below the threshold?"

### 4. Tick-polling blind spot
The flash wick to 0.7222 was actually below the displacement threshold (0.7242). But LevelMind polls at 500ms intervals and never saw this price. The wick happened and recovered between polls. Ironically, if LevelMind HAD seen 0.7222, displacement would have triggered an even earlier (worse) execution.

### 5. Market order fills at worst possible price
Even after deciding to execute, the market order filled at 0.7242 — worse than any of the tick readings during the breach window (0.7246-0.7249). During volatile wick conditions, market orders suffer maximum slippage.

## Contrast: Guard ID 29 (Correct Execution)

For comparison, the earlier MNTUSDT guard at 0.7600 (guard_id=29) executed correctly:
- Price dropped from 0.76 to 0.7591 with clear displacement
- Classification: immediate **accept** with evidence="displacement", confidence=1.0
- This was a genuine breakdown that kept going — displacement detection worked as designed

The difference: guard 29 was a sustained breakdown with momentum. Guard 37 was a wick/stop-hunt with immediate recovery.

## Ideas for Improvement

See `IDEAS.md` in this folder for the full brainstorm and proposals arising from this case.
