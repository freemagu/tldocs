# Case 013: INJUSDT Guard Execution (2026-03-18)

## Summary

| Field | Value |
|-------|-------|
| Date | 2026-03-18 |
| Symbol | INJUSDT |
| Guard ID | 19 |
| Reference Level | 3.12 |
| Mode | fails |
| Trade Side | long |
| Decision | timeout_execute |
| ATR (frozen) | 0.00243 |
| Outcome | First breach reclaimed; second breach held for 5s; timeout executed |
| Verdict | CORRECT |

## Trade Context

- WAEP: 3.2677 (long entry)
- Position: 1,058.2 contracts
- Loss at execution: ~4.6% (filled at 3.1162 vs WAEP 3.2677)
- Leg type: close_loss (trade_id=2394)

## LevelMind Decision Trail

This guard had two breach attempts. The first was reclaimed, the second led to execution.

### Breach Attempt 1 (12:32:02-12:32:04) -- RECLAIMED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:02 | 274 | update_state | inconclusive | breach | 3.1190 |
| 12:32:03 | 275 | none | inconclusive | -- | 3.1180 |
| 12:32:04 | 277 | none | inconclusive | -- | 3.1200 |
| 12:32:04 | 279 | update_state | reclaim | reclaimed | 3.1210 |

Price dipped to 3.119, fell further to 3.118, then reclaimed to 3.120 and 3.121 within 2 seconds. The reclaim was genuine -- price moved 3 ticks above the 3.12 level. Cooldown set until 12:32:14.

### Cooldown Expiry + Observation (12:32:14-12:32:17) -- REJECTED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:14 | 287 | update_state | inconclusive | -- | 3.1210 |
| 12:32:15 | 288 | update_state | inconclusive | obs start | 3.1210 |
| 12:32:16 | 289 | update_state | inconclusive | -- | 3.1210 |
| 12:32:16 | 290 | update_state | inconclusive | safe_count=1 | 3.1220 |
| 12:32:17 | 291 | update_state | reject | -- | 3.1220 |

After cooldown, price was at 3.121-3.122 (above level). Observation found safe_count=1, rejected the trigger.

### Observation Phase 2 (12:32:39-12:32:45) -- Level Weakening

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:39 | 293 | update_state | inconclusive | obs start | 3.1210 |
| 12:32:40 | 295 | update_state | inconclusive | -- | 3.1210 |
| 12:32:40 | 297 | update_state | inconclusive | -- | 3.1210 |
| 12:32:41 | 299 | update_state | inconclusive | -- | 3.1210 |
| 12:32:42 | 300 | update_state | inconclusive | -- | 3.1210 |
| 12:32:42 | 303 | update_state | inconclusive | -- | 3.1210 |
| 12:32:43 | 305 | update_state | inconclusive | -- | 3.1210 |
| 12:32:44 | 307 | update_state | inconclusive | -- | 3.1210 |
| 12:32:44 | 308 | update_state | inconclusive | -- | 3.1210 |
| 12:32:45 | 310 | update_state | inconclusive | -- | 3.1210 |

Price held exactly at 3.121 (1 tick above the level) for ~6 seconds. The level was barely holding.

### Breach Attempt 2 (12:32:46-12:32:51) -- EXECUTED

| Time (UTC) | Resp ID | Action | Classification | Reason | Price |
|------------|---------|--------|---------------|--------|-------|
| 12:32:46 | 312 | update_state | inconclusive | breach | 3.1190 |
| 12:32:46 | 314 | none | inconclusive | -- | 3.1190 |
| 12:32:47 | 316 | none | inconclusive | -- | 3.1190 |
| 12:32:48 | 318 | none | inconclusive | -- | 3.1190 |
| 12:32:48 | 320 | none | inconclusive | -- | 3.1190 |
| 12:32:49 | 321 | none | inconclusive | -- | 3.1180 |
| 12:32:50 | 322 | none | inconclusive | -- | 3.1180 |
| 12:32:51 | 323 | none | inconclusive | -- | 3.1190 |
| 12:32:51 | 324 | execute | accept | timeout_execute | 3.1190 |

Second breach at 3.119, held below for ~5 seconds. Price dipped to 3.118 twice and never attempted a reclaim. Timeout fired.

Breach depth: 3.12 - 3.119 = 0.001 (1 tick, 0.41x ATR). Below displacement threshold.

## Candle Data Around Breach

1m candles from 11:23-11:42 (about 50 minutes before breach):

| Time | Open | High | Low | Close | Vol |
|------|------|------|-----|-------|-----|
| 11:23 | 3.209 | 3.210 | 3.206 | 3.207 | 14,424 |
| 11:25 | 3.205 | 3.205 | 3.197 | 3.199 | 324 |
| 11:27 | 3.194 | 3.196 | 3.190 | 3.196 | 4,751 |
| 11:29 | 3.193 | 3.193 | 3.186 | 3.187 | 13,424 |
| 11:30 | 3.187 | 3.190 | 3.172 | 3.173 | 26,638 |
| 11:31 | 3.173 | 3.176 | 3.158 | 3.165 | 32,317 |
| 11:36 | 3.159 | 3.163 | 3.155 | 3.156 | 7,176 |
| 11:37 | 3.156 | 3.156 | 3.147 | 3.148 | 15,903 |
| 11:38 | 3.148 | 3.151 | 3.141 | 3.143 | 10,385 |

Clear downtrend from 3.21 to 3.14. The 11:30-11:31 candles show a sharp sell-off with high volume (26,638 and 32,317). Price was under sustained selling pressure.

## Post-Execution Price Action

5m candles around execution:

| Time | Open | High | Low | Close | vs Level |
|------|------|------|-----|-------|----------|
| 11:35 | 3.164 | 3.164 | 3.139 | 3.143 | above |
| 11:40 | 3.143 | 3.160 | 3.139 | 3.160 | above |
| 11:45 | 3.160 | 3.164 | 3.153 | 3.154 | above |
| 11:55 | 3.151 | 3.156 | 3.150 | 3.156 | above |
| 12:00 | 3.156 | 3.156 | 3.143 | 3.148 | above |
| 12:10 | 3.142 | 3.149 | 3.139 | 3.145 | above |
| 12:20 | 3.147 | 3.150 | 3.141 | 3.147 | above |
| 12:25 | 3.147 | 3.150 | 3.146 | 3.149 | above |
| 12:30 | 3.149 | 3.149 | **3.109** | 3.114 | **breached** |

The 12:30 5m candle contains the breach: open 3.149, massive drop to low of 3.109, close at 3.114. The low of 3.109 is 4.5x ATR below the 3.12 reference level. This was a decisive break.

Note that price was hovering around 3.14-3.15 for nearly an hour before the final breakdown. The guard level at 3.12 was approached gradually, with the first breach attempt being a brief probe that was reclaimed.

## Verdict

**CORRECT EXECUTION**

The execution was correct, and the reclaim mechanism worked well:

1. **First reclaim was genuine**: Price bounced from 3.118 to 3.122 in 2 seconds -- a real attempt to hold the level. The guard correctly gave it another chance.
2. **Level weakening visible**: After the reclaim, price sat at exactly 3.121 (1 tick above the level) for 6 seconds. This proximity to the edge was a bearish sign.
3. **Second breach decisive**: Price dropped to 3.119 and stayed there for 5+ seconds with no reclaim attempt. The timeout fired correctly.
4. **Post-execution confirmation**: The 5m candle shows price ultimately crashed to 3.109 (4.5x ATR below level). The break was genuine.
5. **Contextual confirmation**: INJ had been trending down from 3.21 for over an hour. The level at 3.12 was the last support before a larger move.

## Signals Assessment

- **CVD**: Relevant during the observation at 3.121. If CVD showed selling pressure even while price was marginally above the level, it would have signaled that the level was likely to fail. Could have shortened the observation period.
- **OI**: The hour-long drift from 3.21 to 3.12 with increasing volume suggests liquidations. OI data would confirm whether this was cascading stops or new short positioning.
- **Momentum**: The first breach to 3.119 was shallow (0.41x ATR) but the trend context was strongly bearish. A trend-aware momentum score could have weighted the breach more heavily, potentially bypassing the first reclaim and executing sooner.
- **Extended window**: Not needed. The 5-second timeout was sufficient for both breach attempts. Price behavior was clear -- the first was a genuine wick, the second was a clean break.
