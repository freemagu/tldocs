# LevelGuard / LevelMind Analysis

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]] | See also: [[ideas]] (microstructure improvement proposals)

Post-trade analysis of LevelGuard behavior across live scenarios, plus improvement proposals.

## Purpose

This folder is a living lab for evaluating and improving the LevelGuard/LevelMind system. The goal is to build a body of evidence across many different market scenarios so we can:

1. **Identify patterns** — What types of price action does LevelMind handle well vs poorly?
2. **Validate proposals** — Do the proposed improvements (CVD, OI, depth analysis) actually help across cases?
3. **Tune parameters** — What config values work best across different market conditions?
4. **Track progress** — As changes are implemented, compare new behavior against historical cases.

## For Other Claude Sessions

If the user asks you to **analyse a guarded order execution**, use the `/review-guard` skill. It walks through the complete process: pulling data, analyzing the decision trail, evaluating the outcome, and saving a case study here.

**Quick reference:**
```
/review-guard 37          # By guard ID
/review-guard MNTUSDT     # Most recent guard for symbol
/review-guard latest       # Most recently executed guard
```

### Key files to read first

| File | What it contains |
|------|-----------------|
| `IDEAS.md` | Master brainstorm for improvements: CVD, OI, depth, composite scoring, implementation phases |
| `001-*.md` etc. | Individual case studies — read these to understand the analysis format and prior findings |
| `lib/tradelens/services/level_mind_core.py` | The decision engine source code |
| `etc/config.yml` (level_guard section) | Current configuration parameters |

### What to do when adding a case

1. Run `/review-guard` — it handles data collection and analysis structure
2. Save as `NNN-symbol-description-YYYYMMDD.md`
3. Update the case table below
4. If new insights arise, update `IDEAS.md` (don't duplicate, extend/refine)
5. If a proposed signal would have changed the outcome, note it explicitly

## Scorecard Summary

| Metric | Count |
|--------|-------|
| Total executed guards analyzed | 19 |
| **CORRECT** executions | 13 |
| **MARGINAL** | 2 |
| **INCORRECT** | 1 |
| **ANOMALOUS** (needs investigation) | 3 |
| Accuracy (excl. anomalous) | 81% (13/16) |

**Breakdown by decision type:**

| Decision Type | Count | Correct | Marginal | Incorrect | Anomalous |
|---------------|-------|---------|----------|-----------|-----------|
| timeout_execute | 11 | 7 | 1 | 1 | 2 |
| displacement | 6 | 5 | 1 | 0 | 0* |
| reclaimed (holds) | 1 | 1 | 0 | 0 | 0 |

*Case 018 (XANUSDT displacement) is anomalous but due to guard config, not the displacement logic.

## Case Studies

| # | Date | Symbol | Guard | Decision | Verdict | Key Finding |
|---|------|--------|-------|----------|---------|-------------|
| 001 | 03-19 | MNTUSDT | 37 | timeout_execute | **INCORRECT** | Sold into wick rejection; price 1 tick from reclaiming; recovered +74 ticks |
| 002 | 03-11 | BTCUSDT | 5 | reclaimed (holds) | **CORRECT** | Holds mode TP; level held after deep wick to 70432 |
| 003 | 03-14 | PHAUSDT | 12 | timeout_execute | **MARGINAL** | 5m candle showed wick rejection, but broader trend bearish; position underwater |
| 004 | 03-15 | BTCUSDT | 15 | displacement (6.2x) | **CORRECT** | Short stop; price 860 ticks above level; immediate displacement; kept rallying |
| 005 | 03-17 | BANANAS31 | 16 | timeout_execute | **CORRECT** | Short stop; price stayed above level; continued higher |
| 006 | 03-17 | TRUMPUSDT | 33 | timeout_execute | **CORRECT** | 2 prior reclaims with weakening bounces; 3rd breach was genuine |
| 007 | 03-17 | OPNUSDT | 23 | timeout_execute | **CORRECT** | Price pinned at 0.2999 for 6 ticks; zero variation = genuine breakdown |
| 008 | 03-17 | DEXEUSDT | 22 | displacement (3.2x) | **CORRECT** | Short stop; explosive breakout candle; only 2 ticks in trail |
| 009 | 03-17 | FHEUSDT | 27 | timeout_execute | **CORRECT** | Zero reclaim attempts over 6 seconds; post-exec low 2.3x ATR below |
| 010 | 03-18 | GPSUSDT | 34 | timeout_execute | **CORRECT** | Flat at breach price for full 5s; post-exec low 5.7x ATR below |
| 011 | 03-18 | POLUSDT | 21 | displacement (1.26x) | **MARGINAL** | Triggered by 1 tick over threshold; outcome correct but razor-thin |
| 012 | 03-18 | DASHUSDT | 35 | timeout_execute | **CORRECT** | 3 breach attempts, 2 reclaims; demonstrates reclaim mechanism working |
| 013 | 03-18 | INJUSDT | 19 | timeout_execute | **CORRECT** | Genuine reclaim then second breach held; crashed 4.5x ATR post-exec |
| 014 | 03-18 | MOODENG | 17 | timeout_execute | **CORRECT** | First breach reclaimed, second held; textbook execution |
| 015 | 03-18 | ZECUSDT | 28 | displacement (1.1x) | **MARGINAL** | Barely over displacement threshold; wick-through with close above |
| 016 | 03-19 | XANUSDT | 31 | timeout_execute | **ANOMALOUS** | TP guard (exit_dir=above); 63-min delay; +30.4% profit. Not a stop-loss guard. |
| 017 | 03-18 | ATOMUSDT | 25 | timeout_execute | **ANOMALOUS** | 32-hour gap between execute decision and fill; 8% price drop during delay |
| 018 | 03-19 | XANUSDT | 30 | displacement | **ANOMALOUS** | 9-hour delay; same trade_id as case 016; TP guard on same position |
| 019 | 03-19 | ICPUSDT | 38 | displacement (2.15x) | **CORRECT** | Price sat at exactly 2.500 for 13s then broke down; 5x volume spike |

## Key Patterns Observed

### What LevelGuard does well:
- **Displacement detection** works reliably for genuine breakdowns (cases 004, 008, 019)
- **Reclaim mechanism** correctly identifies temporary dips that recover (cases 006, 012, 013, 014)
- **Flat-price breaches** (zero variation at breach level) are reliable genuine-break indicators (007, 010)

### Where it struggles:
- **Wick rejections with near-reclaims** (case 001): 5-second window too short when price is recovering
- **Razor-thin displacement** (cases 011, 015): 1-tick over ATR threshold may be noise
- **No market microstructure context**: All decisions are price-only; CVD/OI/depth would add confidence

### Anomalous cases needing investigation:
- Cases 016, 017, 018 involve TP/limit guards (exit_direction=above) with massive execution delays
- These may indicate a different guard mode (monitoring TPs vs stops) that shouldn't be evaluated the same way

## Improvement Proposals

See [IDEAS.md](IDEAS.md) for the complete brainstorm covering:
- **CVD (Cumulative Volume Delta)** — distinguish absorption from genuine selling
- **Open Interest Delta** — stops being flushed (OI drops) vs new shorts (OI rises)
- **Order Book Depth** — bid support near the level
- **Liquidation Cascade Detection** — hallmark of stop hunts
- **Trade Flow Ratio** — aggressor imbalance in real-time
- **Price Recovery Momentum** — slope of price during breach window
- **Composite Breach Confidence Score** — weighted combination of all signals

## Evidence Tracker

Which proposed signals would have helped across cases (based on analysis):

| Signal | Helps | Doesn't Help | Unknown |
|--------|-------|-------------|---------|
| CVD slope | 001 | | 003, 015 |
| OI delta | 001 | | 003, 015 |
| Price momentum | 001 | | |
| Multi-candle close | 001 | | 003 |
| Extended reclaim window | 001 | 007, 009, 010 | |
| Depth imbalance | | | all |
| Liquidation cascade | | | all |

**Key observation**: Most executions (13/16 non-anomalous) were CORRECT. The improvement focus should be on reducing false positives (case 001 type) without degrading the true positive rate. This means new signals should only ADD patience (extend observation), not override correct executions.
