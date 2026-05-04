# Swing-Level Breach Research — Comprehensive Review for External LLM

**Purpose of this document**: A detailed, honest review of all breach-analysis work done to date, the current state, the hard findings, and the forward options. Intended as briefing material for an external LLM to provide independent feedback **before** we commit to a production bridge.

**Authorial voice**: Written by Claude Code (Anthropic) in collaboration with the human operator (Guy). All F1 numbers, thresholds, and counts are pulled from the actual committed artifacts in `research/swing_levels/`. Hypothetical claims are flagged as such.

**Thesis for review**: We have found a real structural signal for distinguishing SFPs (false breaks) from Confirmed breaches at BTCUSDT / ETHUSDT 30m, but the signal has a clear ceiling (F1 ≈ 0.84) driven by a one-latent-factor structure. The feature set used so far has deliberately excluded tick-level volume microstructure, open interest, funding, liquidations, and post-breach flow. The operator (correctly, in our view) suspects the ceiling is a *feature-set* limitation, not a label-noise limitation, and that volume / CVD / OI will be the key to pushing past it. This document is the ground-truth evidence base to let an external LLM challenge or confirm that hypothesis.

---

## Table of contents

1. [Terminology](#1-terminology)
2. [Why this project exists](#2-why-this-project-exists)
3. [Prior work: stop-level breach analysis (`lib/tradelens/breach_analysis/`)](#3-prior-work-stop-level-breach-analysis)
4. [Phase 1 — dataset construction](#4-phase-1--dataset-construction)
5. [Phase 2 — labelling](#5-phase-2--labelling)
6. [Phase 3 — feature extraction](#6-phase-3--feature-extraction)
7. [Phase 4 — single-feature separation](#7-phase-4--single-feature-separation)
8. [Phase 5a — cross-symbol validation on ETHUSDT](#8-phase-5a--cross-symbol-validation-on-ethusdt)
9. [Phase 5b — multi-feature pair rule](#9-phase-5b--multi-feature-pair-rule)
10. [The F1 ≈ 0.84 ceiling — what it means](#10-the-f1--084-ceiling--what-it-means)
11. [What the current feature set is MISSING](#11-what-the-current-feature-set-is-missing)
12. [Data availability — what's in the system, what isn't](#12-data-availability)
13. [Forward options, ranked by expected information value](#13-forward-options)
14. [Open questions for the external reviewer](#14-open-questions-for-the-external-reviewer)
15. [Risks and traps we want independent feedback on](#15-risks-and-traps)
16. [Reproducibility appendix](#16-reproducibility-appendix)

---

## 1. Terminology

All definitions are used consistently throughout the codebase and research artifacts.

- **Level** / **swing level**: a swing high or swing low price at which market structure pivoted. Identified by a strict N-left / N-right pivot rule (N_LEFT=50, N_RIGHT=10 on 30-minute bars in v1) plus a Donchian-prominence filter.
- **Breach**: the first moment price crosses an active level in the direction that would invalidate it. For a swing high at price L, a breach is the first tick (or bar) where `price > L`. Refined to tick-level timestamp where possible.
- **SFP** (**Stop Fail Pattern** / **swept fake pattern**): a breach that fails — price puncturesthe level, then closes back through within a recovery window (R=2h) AND produces an opposite-direction excursion ≥ k_rev × ATR (1.0 × ATR in v1). "Liquidity sweep" in common trader parlance.
- **Confirmed**: a breach that holds — price does NOT close back through within R, AND produces a same-direction excursion ≥ k_fwd × ATR (1.0 × ATR) within a follow-through window (F=6h). The kind of break that should trigger an executed order in LevelGuard.
- **Ambiguous**: neither clear SFP nor clear Confirmed. The default class; small (7–8% of events).
- **Reclaim** (deferred): a level breached, abandoned, then breached again in the opposite direction. Out of scope for v1.
- **Precedence**: when a single event's R-window close-back AND F-window excursion both trigger, **SFP wins**. Rationale: a recovery close-back is evidence the breach "did not hold" regardless of later advance.

---

## 2. Why this project exists

### 2.1 The production problem

LevelGuard / LevelMind is a perpetual-futures execution system that posts trade-management orders (stops, reduce orders, re-entries) at *trader-specified levels*. The recurring pain:

- A stop is placed near a swing high/low.
- Price **puncturesthe level intrabar**, filling the stop (liquidating the position or triggering a reduce).
- Price then **reverses immediately** — the puncturewas a liquidity sweep, not a real break.

This is the "stop hunt" problem. A simple bar-close gate reduces but does not eliminate it — many real SFPs still produce bar-closes just past the level before reversing. We want a **probabilistic at-breach signal** that distinguishes SFP from Confirmed before we act, so LevelGuard can either (a) delay execution briefly, (b) use a different order type, or (c) require a confirming signal.

### 2.2 The research question

> **Can we, using only information available at-or-before a breach occurs, distinguish a breach that will fail (SFP) from a breach that will hold (Confirmed), on a dataset of market-structure-native swing levels?**

Success criterion for production-worthiness, approximately:
- F1 ≥ 0.85 on SFP-vs-rest, one-vs-rest
- Cross-symbol replication (at minimum BTC + ETH; ideally + SOL)
- Feature engineering that is implementable in real-time with ≤ 1-second latency after breach detection
- No data leakage (strictly pre-breach or at-breach features)

Where we are as of 2026-04-23: **F1 ≈ 0.83 on BTC, 0.84 on ETH, out-of-sample transfer clean, ceiling apparent, feature set deliberately narrow.**

---

## 3. Prior work: stop-level breach analysis

### 3.1 Context

Before the swing-level research began (April 2026), we ran a six-month-plus project on **stop-level breach analysis** — analysing breaches of prices where actual stops had been placed (or would plausibly have been placed), using a large internal dataset of historical trade ideas and journal entries. That project produced the `lib/tradelens/breach_analysis/` package, which contains:

- `tick_loader.py` — raw-trade tick loading from the local parquet archive (`/db/data01/tick_archive/tick_trade_raw/bybit/{symbol}/{date}.parquet`); produces `TickData` with ticks bucketed before/after breach.
- `extractors.py` — `FeatureExtractor` base class and `FeatureSet` composer.
- `volume.py` — **VolumeExtractor**. Computes per-side (buy, sell, total) volume in multiple windows: 5s / 10s / 30s / 60s, plus extended 120s / 300s windows for pre-breach ramp detection.
- `delta.py` — **DeltaExtractor** and **CVDExtractor**. Delta = buy − sell volume; CVD = cumulative delta over a window. Windows: 5s, 10s, 30s, 60s.
- `basis.py` — **BasisExtractor**. Perp-spot basis at the breach moment and change during the post-breach window. Reads `breach_spot_candle` (research table) and `market_candle` (spot). Designed to capture the perp-led liquidation signature of SFPs.
- `bounce_depth.py` — how far price bounced (or failed to bounce) from the level after breach.
- `time_at_level.py` — how long price spent hovering at the level before breach.
- `price_velocity.py` — the approach velocity into the level.
- `candle_volume.py` — candle-level volume baselines (used to normalise tick volumes against 30m-bar norms).
- `signal_functions.py` — 520 lines of "signal scoring" logic that combined the above extractors into a scalar signal score. This was the stop-level research's attempt at a classifier.

### 3.2 Why we pivoted to swing-level research

The stop-level project had two structural problems:

1. **The "arbitrary level" concern** — stops are placed where traders decide to place them, which is a mix of structurally meaningful locations (swing highs/lows, round numbers, prior pivots) and arbitrary noise (percent-based stops, VWAP-relative, personal habits). Training a classifier on a mixed dataset means the "breach" event is not a well-defined structural phenomenon.
2. **Dataset size** — we had thousands of stop events but the active-level duration was short (stops expire or get moved), so each event had less "shelf time" and fewer approach attempts.

The swing-level research was framed as: **generate a clean, structurally meaningful level dataset from market structure alone (pivots), then build up from there**. The baseline memo explicitly said "stop levels are not arbitrary, but swings are cleaner." See TRACKER §5.

The swing-level research is intentionally starting narrower than the stop-level research was: fewer features, simpler labelling, no classifier in v1. The plan was to only add complexity if evidence supported it.

### 3.3 What we inherited vs. what we chose to leave out

**Inherited** (and still in use by swing research):
- `TickLoader` — directly imported by the swing Phase 1 and Phase 3 pipelines
- The general "TickData with before/after" abstraction
- The general feature-extractor pattern

**Deliberately not ported** (feature extractors from breach_analysis):
- **VolumeExtractor** — the swing Phase 3 reimplemented a *subset* of this, narrower (5m / 60s tick-count only). The full ladder of 5s / 10s / 30s / 60s / 120s / 300s windows × per-side volumes was NOT brought over.
- **DeltaExtractor / CVDExtractor** — reimplemented as `pre_300s_delta_norm` and `pre_300s_cvd_slope_per_s`. Only one window. The 5s / 10s / 30s / 60s delta ladder was NOT brought over.
- **BasisExtractor** — NOT ported. Spot data coverage is available for BTC (1m) and ETH (1m/30m) over our window but the extractor wasn't adapted to the swing schema.
- **BounceDepth, TimeAtLevel, PriceVelocity, CandleVolume** — NOT ported.

The user's instinct ("volume, CVD, OI will be key") is directly aligned with this: we chose simplicity in v1 and now the data is telling us the simplicity may be hiding the real signal.

---

## 4. Phase 1 — dataset construction

### 4.1 Goal
Produce a clean, inspectable dataset of swing-level breach events, each with event metadata plus pointers into tick and candle archives for downstream work.

### 4.2 Window
Approved UTC window: **2025-10-01 00:00 → 2026-03-23 23:59:59** (174 days). The window was aligned to BTCUSDT tick archive coverage (`/db/data01/tick_archive/tick_trade_raw/bybit/BTCUSDT/{YYYY-MM-DD}.parquet`). Documented tick-gap days: 2025-10-09, 2025-10-10, 2025-10-26 (missing file or empirically bad coverage).

### 4.3 v0 (15m / 5L / 5R) — retired

First attempt: 15-minute bars, pivot rule N_LEFT=N_RIGHT=5 strict inequality. Produced ~2000 breach events. Spot-check surfaced **event 117** (swing low at 111386.0 on 2025-10-11 16:30 UTC) as mathematically valid but structurally meaningless — the right-5 low was only $6 above the pivot low, so on a 30m chart the "low" was invisible inside a larger descending move. Classic 15m/5L5R noise.

v0 archived at `research/swing_levels/phase1/run_v0_15m_5L5R/` for reference.

### 4.4 v1 (30m / 50L / 10R + Donchian prominence) — current

Adopted:
- **Timeframe**: 30m bars (timeframe_seconds=1800).
- **Pivot rule**: strict inequality, N_LEFT=50 (25 hours of left context), N_RIGHT=10 (5 hours of right confirmation).
- **Prominence filter**: `|price − donchMid(21)| ≥ 1.5 × ATR(14)` at the pivot bar. Mirrors `research/swing_levels/swing_pivots.pine`. Structural effect: a pivot must be meaningfully separated from the Donchian mid, i.e. can't be a small ripple in a tight range.
- **Touch count**: episode-based — price enters a configurable proximity band around the level and then exits. Computed two ways:
  - ATR-band: p=0.5×ATR enter, q=0.25×ATR exit
  - Tick-band: M=20×tick_size enter (found too narrow empirically — `touch_count_ticks` is ≈0 for virtually all events)

### 4.5 v1 results (BTCUSDT)
- Raw pivots in loaded range: 272
- Pivots in Phase 1 window: 212
- Dropped by prominence filter: 2 (filter is structurally near-no-op on 50L/10R pivots — see §4.7)
- Kept levels: 210
- **Breach events in window: 191**
- Unbreached at window end: 15
- Tick-refined events: 185 / 191 (96.9%)
- Events on tick-gap days: 6 / 191

### 4.6 v1 results (ETHUSDT — Phase 5a, same parameters)
- Raw pivots in loaded range: 291
- Pivots in window: 235
- Dropped: 2
- Kept: 233
- **Breach events: 210**
- Unbreached at window end: 20
- Tick-coverage: 172 / 210 (81.9%) — ETH tick archive has a 33-consecutive-day gap 2026-03-06 → 2026-04-07

### 4.7 Known Phase 1 limitations / findings
- **Spacing filter is a no-op** on 50L/10R pivots. Strict N-left / N-right inequality mathematically guarantees same-type pivots are separated by > N bars, so a separate spacing filter at N=10 does nothing. Not a bug — deferred as Phase 1.5 work (would require redefining spacing as price-proximity, not bar-index).
- **Prominence filter rarely fires** (2/212 BTC, 2/235 ETH). Structural explanation: a bar that is the strict 50-bar extreme tends to dominate the 21-bar Donchian window, so `(high[p] − min_low_21) ≥ 3 × ATR` is usually satisfied. Not a bug — but means the "filter" is doing less selective work than the name suggests.
- **`touch_count_ticks` is saturated at 0** (1956/1983 events in earlier v0 run). 20-tick band at BTC price ≈ $60–115k is ≈ 0.002% of price, too narrow to register real approaches. The ATR-based count does the work. Feature kept in the schema as a null anchor.
- **Phase 1 parameters are marked `provisional` throughout `phase1_parameters.md`**. They have not been tuned against any measurable objective.

### 4.8 Files
- `bin/tools/swing_levels_phase1.py` — pipeline
- `lib/tradelens/swing_research/{pivots,filters,breach_detect,touch_count,atr,donchian,bar_walk,tick_refine}.py` — module files
- `tests/unit/test_swing_{pivots,donchian,filters,touch_count,breach_detect}.py` — 12 pure unit tests
- `research/swing_levels/phase1/{levels_raw,levels_filtered,breach_events}.csv` + `phase1_summary_stats.md` + `phase1_parameters.md` + `phase1_closeout.md` — artifacts

---

## 5. Phase 2 — labelling

### 5.1 Goal
Assign each breach event exactly one label ∈ {SFP, Confirmed, Ambiguous}. No reclaim class. No threshold tuning against class balance.

### 5.2 Rules
For a swing-high breach at price L, with ATR(14) at the pivot bar = `atr_anchor`:
- **Recovery close-back**: any bar within `[breach_ts, breach_ts + 2h]` whose close < L.
- **Reversal excursion (SFP signal)**: max excursion below L within F-window = 6h, normalised by `atr_anchor`. Must exceed `k_rev = 1.0 × ATR` for SFP.
- **Follow-through excursion (Confirmed signal)**: max excursion above L within F=6h, normalised by `atr_anchor`. Must exceed `k_fwd = 1.0 × ATR` for Confirmed.
- **Label rule**:
  - If `recovery_closed_back` AND `reversal_hit`: **SFP** (precedence: SFP wins over Confirmed even if follow-through also triggered).
  - Elif NOT `recovery_closed_back` AND `followthrough_hit`: **Confirmed**.
  - Else: **Ambiguous**.
- Swing-low rules are symmetric (invert all comparisons).

### 5.3 Results (BTCUSDT, 191 events)
| Label | Count | Share |
|---|---|---|
| SFP | 116 | 60.7% |
| Confirmed | 60 | 31.4% |
| Ambiguous | 15 | 7.9% |

By swing_type: highs 52 / 22 / 9, lows 64 / 38 / 6. Consistent across types.

Time-to-resolution medians:
- Recovery close (SFP): ~23 min (less than 1 × 30m bar)
- Reversal threshold (SFP): ~21 min
- Follow-through threshold (Confirmed): ~39 min
- Almost all resolutions happen within the first 1–3 bars of the F window → F=6h is comfortably long for current thresholds.

### 5.4 Results (ETHUSDT, 210 events) — Phase 5a
| Label | Count | Share | Δ vs BTC |
|---|---|---|---|
| SFP | 134 | 63.8% | +3.1 pp |
| Confirmed | 60 | 28.6% | −2.8 pp |
| Ambiguous | 16 | 7.6% | −0.3 pp |

Label distribution is essentially identical to BTC. The classifier **is not a BTC-specific artifact of the window, pivot rule, or k_rev/k_fwd thresholds**.

### 5.5 Known Phase 2 limitations
- **Ambiguous is small** (15–16 events per symbol) — single-feature separation is numerically underpowered on this class. Confirmed in Phase 4.
- **k_rev = k_fwd = 1.0 × ATR is first-pass**. Not tuned against any measurable objective.
- **Precedence rule is a judgment call**. The alternative "recovery-close gated by *no* follow-through" was rejected to preserve "close-back means the breach didn't hold" semantics.
- **Reclaim class deferred**. A valid real market phenomenon; excluded from v1 to keep labels mutually exclusive.

### 5.6 Files
- `bin/tools/swing_levels_phase2.py` — pipeline
- `lib/tradelens/swing_research/labelling.py` — pure labelling logic (141 LOC)
- `tests/unit/test_swing_labelling.py` — 7 pure unit tests (SFP happy path, Confirmed happy path, boundary-equal, both Ambiguous paths, swing-low symmetry, precedence conflict)
- `research/swing_levels/phase2/{breach_labels,phase2_summary_stats,phase2_manual_review,phase2_parameters}.md/csv`

---

## 6. Phase 3 — feature extraction

### 6.1 Scope
**17 per-event features**, strictly pre-breach or at-breach. No post-breach information. Tick features null on gap-day events.

### 6.2 Feature groups

#### A. Breach-bar features (6) — from the 30m bar containing the breach
| Name | Formula | Interpretation |
|---|---|---|
| `breach_bar_body_atr` | `|close − open| / ATR` | Bar-body magnitude, ATR-normalised |
| `breach_bar_range_atr` | `(high − low) / ATR` | Bar-range magnitude |
| `breach_closed_through` | `close > level` (high) / `close < level` (low), strict | Boolean: did the bar close past the level |
| `breach_wick_beyond_atr` | `(high − level) / ATR` (high) / `(level − low) / ATR` (low) | How far the wick pokedbeyond the level |
| `breach_body_beyond_atr` | `(max(open,close) − level) / ATR` (high) / `(level − min(open,close)) / ATR` (low) | How far the body pokedbeyond. **Can be negative** if wick broke but body stayed inside. |
| `breach_bar_up` | `close > open` | Direction of the bar |

#### B. Pre-breach candle context (3) — from 4 bars (2h) before the breach bar
| Name | Formula |
|---|---|
| `pre_60min_range_atr` | range over last 2 bars / ATR (compression over last hour) |
| `pre_120min_range_atr` | range over all 4 bars / ATR |
| `pre_2h_velocity_atr_per_h` | `(breach_bar.open − pre_bars[0].open) / ATR / 2` — signed approach speed |

#### C. Pre-breach tick features (5) — from ticks in `[breach_ts − 300s, breach_ts)`
| Name | Formula |
|---|---|
| `pre_300s_volume` | sum(size) over 300s (raw, unnormalised) |
| `pre_300s_delta` | buy_volume − sell_volume (raw) |
| `pre_300s_delta_norm` | delta / total, range −1..+1 |
| `pre_300s_cvd_slope_per_s` | linear endpoints slope of CVD series |
| `pre_60s_tick_count` | count of ticks in `[breach_ts − 60s, breach_ts)` |

#### D. Level features (3) — carried from Phase 1
| Name | Source |
|---|---|
| `level_age_hours` | `(breach_ts − confirmed_at) / 3600` |
| `touch_count_atr` | Phase 1 episode count (ATR band) |
| `touch_count_ticks` | Phase 1 episode count (tick band — saturated at 0) |

### 6.3 Tick-window leak protection
- `TickLoader` called with `window_end = breach_ts`
- Orchestration filter: `[t for t in ticks if t[0] < breach_ts]` before feature computation
- Verified: no post-breach tick ever enters a Phase 3 feature

### 6.4 Null handling
- Events on tick-gap days (6/191 BTC, 38/210 ETH): tick features null, candle and level features unaffected
- No events excluded

### 6.5 Summary stats (BTCUSDT)
Full detail in `research/swing_levels/phase3/phase3_summary_stats.md`. Highlights:
- `breach_bar_range_atr`: min 0.578, max 16.517, median 2.052 — breach bars run the gamut from tight to explosive
- `breach_body_beyond_atr`: min −3.750, max 6.590, median 0.031 — symmetric around zero; many events have the body stay inside despite a wick poke
- `pre_2h_velocity_atr_per_h`: median −0.119 — small net approach-from-below bias
- `breach_closed_through`: 98 True / 93 False — nearly 50/50
- `breach_bar_up`: 84 True / 107 False

### 6.6 Known limitations of Phase 3
- **Only 5m + 60s tick windows**. We explicitly did not port the stop-level breach_analysis Volume/Delta ladder (5s/10s/30s/60s/120s/300s × per-side). This is the *single biggest gap* in the current feature set.
- **Tick size / venue noise**: raw `pre_300s_volume` and `pre_300s_delta` are in contract units, not USD-normalised. Cross-symbol comparability suffers (seen directly in Phase 5).
- **No at-level volume**: we don't distinguish between ticks far from the level and ticks right at the level. If SFPs are "stops trigger at level → cascade → exhaustion," the at-level tick volume in the last seconds should be the specific signature.
- **No multi-horizon features**: we have one 5m delta, not a ladder of 15s/60s/5m/15m deltas that would show acceleration.
- **No post-breach features**: strictly pre-breach is correct for production use, but for research diagnostics (how does the immediate post-breach tick flow differ between SFP and Confirmed) we're blind.
- **No OI / funding / liquidation / book features**: not in the archive.

### 6.7 Files
- `bin/tools/swing_levels_phase3.py` — pipeline
- `lib/tradelens/swing_research/features.py` — pure extractors (187 LOC)
- `tests/unit/test_swing_features.py` — 5 pure unit tests
- `research/swing_levels/phase3/{breach_features.csv, phase3_summary_stats.md, phase3_parameters.md}`

---

## 7. Phase 4 — single-feature separation

### 7.1 Method
For each of the 17 features × each of the 3 label classes (one-vs-rest): grid-search 20 quantile-spaced thresholds × 2 directions → keep the highest-F1 cutoff. Nulls excluded from ranking.

### 7.2 Interpretability guard
Majority-vote baseline for SFP: F1 = 2·0.607·1.0 / (0.607+1.0) ≈ **0.755**. Any heuristic that doesn't meaningfully beat this AND show a non-degenerate precision/recall split is suspect.

### 7.3 Results — best heuristic per class (BTCUSDT)
| Class | Rule | F1 | Precision | Recall |
|---|---|---|---|---|
| **SFP** | `breach_body_beyond_atr < 0.6559` | **0.830** | 0.738 | 0.948 |
| **Confirmed** | `breach_closed_through = True` | 0.759 | 0.612 | 1.000 |
| **Ambiguous** | `breach_bar_range_atr < 1.19` | 0.444 | 0.333 | 0.667 |

### 7.4 Interpretation
- **SFP is separable**. The single feature `breach_body_beyond_atr` (how far the body poked beyond the level, ATR-normalised) at cutoff 0.6559 delivers F1=0.830. Structural reading: when the breach bar's body pokes < ~0.66 ATR past the level, the breach is ~3× more likely to fail than hold. When it pokes ≥ 0.66 ATR, the breach more often holds. Hand-traced on events 1 (FP, Confirmed, body=0.357), 2 (TP, SFP, body=0.355), 117 (TN, Confirmed, body=1.327) — confirms the mechanics.
- **Confirmed's best rule is a necessary but not sufficient condition.** Recall=1.0 means every Confirmed event closed through the level on the breach bar. Precision=0.612 means 38 of the 98 closed-through breaches were actually SFPs. A useful first-cut gate for downstream filtering, not a standalone classifier.
- **Ambiguous is not separable by any single feature.** Best F1 = 0.444. Sample size (15) is too small, and the label is defined as "neither" which is definitionally heterogeneous.
- **Top-5 SFP heuristics all point the same direction.** `breach_wick_beyond_atr < 1.67` (F1=0.791), `breach_closed_through = False` (F1=0.785), `breach_bar_body_atr < 2.04` (F1=0.779), `pre_300s_delta_norm < 0.73` (F1=0.765), `breach_bar_range_atr < 4.16` (F1=0.760). They are all encoding one underlying quantity: **how aggressively did the breach bar commit through the level**.
- **No tick feature in the top-3.** The best tick-based SFP heuristic (pre_300s_delta_norm) is ranked 5th on BTC. Ranks 8–10 (`touch_count_atr < 4.11`, `pre_300s_volume > 45.01`, `pre_300s_delta > −1220.1`) are flagged as near-degenerate — thresholds at feature minima, effectively "predict all SFP".

### 7.5 Files
- `bin/tools/swing_levels_phase4.py` — pipeline
- `lib/tradelens/swing_research/separation.py` — pure grid-search module (150 LOC)
- `tests/unit/test_swing_separation.py` — 4 pure unit tests
- `research/swing_levels/phase4/{feature_separation.csv, feature_separation.md, top_cutoffs.md, phase4_parameters.md}`

---

## 8. Phase 5a — cross-symbol validation on ETHUSDT

### 8.1 Goal
Rerun Phases 1–4 on ETHUSDT with **identical parameters** to check whether the BTC-derived signal is structural or a BTC-specific artifact.

### 8.2 Method
- Pipelines parameterised with `--symbol` (+ `--tick-size`, `--window-start`, `--window-end` for Phase 1)
- BTC regression verified byte-identical after refactor (diff on all four phases' artifacts)
- ETH window = ETH tick archive coverage = 2025-10-12 → 2026-04-07 (178 days)
- All Phase 1–4 parameters held constant

### 8.3 Results — top-5 SFP heuristic side-by-side
| Rank | BTC feature | BTC thresh | BTC F1 | ETH feature | ETH thresh | ETH F1 |
|---|---|---|---|---|---|---|
| 1 | `breach_body_beyond_atr <` | 0.6559 | **0.830** | `breach_body_beyond_atr <` | 0.5616 | **0.837** |
| 2 | `breach_wick_beyond_atr <` | 1.6694 | 0.791 | `breach_closed_through = False` | — | 0.808 |
| 3 | `breach_closed_through = False` | — | 0.785 | `breach_bar_body_atr <` | 3.1128 | 0.799 |
| 4 | `breach_bar_body_atr <` | 2.0393 | 0.779 | `breach_wick_beyond_atr <` | 2.0415 | 0.795 |
| 5 | `pre_300s_delta_norm <` | 0.7330 | 0.765 | `touch_count_atr <` | 4.1053 | 0.782 |

**The top-4 breach-bar features are the same, just reordered.** All point the same direction.

### 8.4 Out-of-sample transfer
BTC-derived rule (`breach_body_beyond_atr < 0.6559 → SFP`) applied **directly** to ETH without re-tuning:
| Metric | Value |
|---|---|
| TP / FP / FN / TN | 127 / 44 / 7 / 32 |
| Precision | 0.743 |
| Recall | 0.948 |
| **F1** | **0.833** |

ETH own-tuned F1 was 0.837 (threshold 0.5616). The BTC threshold applied blindly gives 0.833. **Loss of only 0.004.** Rule transfers.

### 8.5 Where tick features differ
BTC's top-5 had `pre_300s_delta_norm` at rank 5. ETH's top-10 has **no tick feature** — all the ranked features are breach-bar or candle-context. Candidate explanations:
1. ETH tick microstructure is different from BTC (more cascading liquidations / different liquidity profile)
2. ETH's 38 null tick events distort the rankings (tick features ranked among only 172 events, making them noisier)
3. The 5m window is inappropriately short for ETH's slower microstructure dynamics

We don't know which. This is a **flag** for the forward plan: tick features as currently defined are less cross-symbol stable than breach-bar features.

### 8.6 Files
- `research/swing_levels/phase{1,2,3,4}/ethusdt/*` — full ETH pipeline output
- `research/swing_levels/cross_symbol/comparison.md` — detailed side-by-side

---

## 9. Phase 5b — multi-feature pair rule

### 9.1 Goal
Combine two features into a depth-2 decision rule `(A dA tA) AND/OR (B dB tB)`. Measure whether multi-feature gives F1 gain over single-feature ceiling.

### 9.2 Method
- **Hand-rolled** pair-rule grid search, no sklearn (we didn't want to add a heavy dep for one phase)
- For each training set ∈ {BTC, ETH, pooled}: rank all 12 always-available features (tick features dropped for cross-symbol stability + null handling); take top-6; brute-force all pairs × 20-cut thresholds × 2 directions × 2 combiners {AND, OR}
- Evaluate each rule on all three test sets

### 9.3 Results — multi-feature gain
| Train set | Best single-feature F1 | Best pair-rule F1 | Gain |
|---|---|---|---|
| BTC | 0.830 | 0.833 | **+0.003** |
| ETH | 0.837 | 0.842 | **+0.005** |
| Pooled | 0.835 | 0.837 | **+0.002** |

**All gains are within grid-search noise.**

### 9.4 The BTC "winning" rule is degenerate
`(breach_body_beyond_atr < 0.6559) AND (breach_bar_range_atr > 0.5780)`
But `breach_bar_range_atr` minimum across BTC events is 0.578 (per Phase 3 summary). So `> 0.578` is essentially always True. The "pair rule" reduces structurally to the single-feature rule; the +0.003 lift is noise, not signal.

### 9.5 Cross-symbol transfer
| Train | Test | F1 |
|---|---|---|
| BTC | ETH | 0.829 |
| ETH | BTC | 0.803 |

The simpler BTC rule (which reduces to single-feature) transfers better to ETH than ETH's AND/OR rule transfers to BTC. Consistent with "simpler rules generalise."

### 9.6 Interpretation — the one-latent-factor hypothesis
The top-4 features in Phase 4 all point the same direction. Adding a second feature to any of them does not help. This is strong evidence that they are **all encoding the same underlying quantity — how aggressively the breach bar committed through the level.** Adding more features of the same shape would likely also not help.

This is the **F1 ≈ 0.84 ceiling** — see §10.

### 9.7 Files
- `bin/tools/swing_levels_phase5.py` — pipeline
- `lib/tradelens/swing_research/multi_feature.py` — pure module (162 LOC)
- `tests/unit/test_swing_multi_feature.py` — 3 pure unit tests
- `research/swing_levels/phase5/{evaluation.md, tree_rules.md, evaluation_matrix.csv, phase5_parameters.md}`

---

## 10. The F1 ≈ 0.84 ceiling — what it means

### 10.1 Three possible explanations

1. **Label-noise ceiling.** Our SFP/Confirmed labels have a ~15% irreducible noise floor — some events are inherently ambiguous, mis-labelled by the 2h/6h + 1.0-ATR rule, or too close to the decision boundary to be predictable even in principle. **Implication**: no feature engineering can push past ~0.85.

2. **Feature-set ceiling.** Our 17 features are all encoding the same "how aggressive was the breach bar" latent factor. A genuinely orthogonal signal — volume microstructure, order flow imbalance, derivatives-market context (OI, funding, basis) — would push past the ceiling because it sees information the current features cannot. **Implication**: the ceiling is a *feature selection* problem, not a label problem.

3. **Modelling-complexity ceiling.** We stayed shallow (single feature + 2-feature pair rules) because the data suggested it. A deeper classifier (deeper tree, logistic, GBM, etc.) on the same features might eke out another +0.03. **Implication**: we're under-using the existing features.

### 10.2 Evidence for each

- **Label-noise**: Ambiguous is ~8% of events and definitionally un-separable. If Ambiguous is the hard floor of "events where prediction is definitionally hard," the maximum possible F1 for SFP-vs-rest would be around 92% of the total (excluding Ambiguous) × some factor. But 8% can't fully explain a ~16% gap from perfect (1.00 − 0.84 = 0.16).
- **Feature-set**: we deliberately dropped an entire research-grade feature library (breach_analysis/) and built v1 with a narrow 5m/60s tick set. The user's hypothesis that volume/CVD/OI contain incremental information is structurally reasonable and not tested yet.
- **Modelling-complexity**: Phase 5 pair rule gave +0.003 to +0.005 gain over single feature. A deeper model on the same features wouldn't push much more.

### 10.3 Our reading

The label-noise hypothesis is *partial* — there's some irreducible noise, plausibly ~0.05. But **we strongly suspect the dominant contribution to the ceiling is feature-set underfitting**, not label noise. Reasons:

1. The one-latent-factor result (Phase 5b) is *structurally* one latent factor. If there were two or three latent factors in the data, different pairs of features in Phase 5b would have given materially different F1s. Instead they gave the same F1, suggesting we're seeing one dimension of a higher-dimensional signal.
2. Tick features were less stable cross-symbol — this could mean they're noisy, OR that 5m is the wrong horizon and shorter/longer tick windows would reveal a stable signal.
3. The prior stop-level research used 5s/10s/30s/60s delta ladders + basis + book-level features + more. The fact that the prior work got further on a worse dataset suggests more features ≠ diminishing returns in this problem.

---

## 11. What the current feature set is MISSING

This is the most important section for the external LLM reviewer. The user's intuition about volume / CVD / OI is aligned with our reading of the evidence.

### 11.1 Tick volume microstructure (MISSING — highest priority)

**What we have**:
- `pre_300s_volume` (raw sum over 5m)
- `pre_60s_tick_count` (intensity over 60s)
- `pre_300s_delta` / `pre_300s_delta_norm` (signed imbalance over 5m)
- `pre_300s_cvd_slope_per_s` (linear slope of CVD over 5m)

**What we don't have**:
- **Volume ladder across horizons**: 5s, 10s, 30s, 60s, 120s, 300s, 900s, 1800s. Each window captures a different time-scale of flow. SFP vs Confirmed likely have very different signatures at different horizons.
- **Per-side (buy vs sell) volume ladder** at each horizon.
- **Volume acceleration**: ratio of 60s window to preceding 300s window. A late-stage buildup is not the same as a steady flow.
- **Delta ladder**: `pre_Ns_delta_norm` at each of 5s/10s/30s/60s/120s/300s/900s. If the last 10s has extremely negative delta (sellers aggressive) on a long-stop hunt, that's a different signature than 300s having mildly negative delta.
- **At-level flow**: tick volume specifically within ±p×ATR of the level price (rather than all ticks in the window). If stops cluster right at the level, at-level volume is the *specific* SFP signature.
- **Breach-bar-local flow**: volume during the final 10% of the breach bar (the seconds just before close). Did the bar close with buying pressure or selling pressure?
- **Post-breach reversal volume** (research-only, for understanding): volume in the 15s / 60s / 300s after breach with sign *opposite* the breach direction. An SFP should show fast opposite-direction volume; a Confirmed should show continuation.

### 11.2 CVD shape (MISSING)

**What we have**: `pre_300s_cvd_slope_per_s` — linear slope between CVD[first_tick] and CVD[last_tick]. This is a crude summary.

**What we don't have**:
- **CVD curvature**: is the CVD accelerating (concave) or decelerating (convex) into the breach? An accelerating absorption pattern looks different from a decelerating one.
- **Divergence against price**: CVD going down while price going up (or vice versa) is a classic exhaustion signal. We don't compute this.
- **CVD reset timing**: when did CVD last cross zero before breach? If CVD has been positive for 2h and suddenly flips just before breach, that's a different signature than CVD oscillating.
- **CVD at multiple horizons** (same argument as §11.1).

### 11.3 Open interest (MISSING — ENTIRELY)

**What we have**: Nothing. No OI archive.

**What exists**: Bybit publishes OI via REST (`/v5/market/open-interest`) and WebSocket. The `lib/tradelens/adapters/bybit_client.py` has the adapter layer but there is no historical ingest.

**Why it matters for SFP detection**:
- SFPs are liquidation cascades. OI drops sharply during a liquidation cascade (longs getting liquidated, OI decreasing) and then stabilises or increases in the bounce.
- Confirmed breaks typically have OI *increase* during the break (new positions opening in the direction of the break).
- **Δ-OI over the breach window** is potentially one of the single most informative features we could add. Every instinct and trader-folklore about "liquidation hunts vs real breaks" centres on position flow, which is OI.
- The sign+magnitude of the OI change in the last 5m before breach, the 5m during breach, and the 5m post-breach would together tell a clear story.

**What we'd need**: a historical OI ingest job (hourly or 5-minute granularity over our research window, for BTC and ETH). OI is published at 1m granularity by Bybit; the historical API goes back ~180 days. This is a moderate-scope ingest task.

### 11.4 Funding rate (MISSING — ENTIRELY)

**What we have**: `funding_fee_event` table, but that's *our* paid funding fees, not the historical rate.

**Why it matters**:
- A heavily-negative funding rate (shorts paying longs) signals crowded shorts. A SFP at a swing high in a heavily-negative-funding environment is more likely to be a stop hunt.
- Funding rate + OI together give a clean picture of positioning.

**What we'd need**: historical funding rate ingest. Bybit publishes this 3× daily at fixed times, or continuously-computed intrabar. Also a moderate-scope ingest task.

### 11.5 Liquidation feed (MISSING — ENTIRELY)

**What we have**: Nothing. `lib/tradelens/api/liquidation.py` is a live position-risk endpoint.

**Why it matters**: the *direct* SFP signal. A wave of longliquidations in the 60 seconds around a breach of a swing low is literally the "stops cluster below the level" phenomenon being observed.

**What we'd need**: historical liquidation feed ingest. Bybit publishes this via WebSocket (not easily backfillable) or via third-party data services (e.g. CoinGlass, Laevitas). This is a bigger ingest project and likely involves paid data.

### 11.6 Basis (perp-spot) — PARTIALLY AVAILABLE

**What exists**: `lib/tradelens/breach_analysis/basis.py` — the stop-level research already wrote a BasisExtractor. Not ported to swing schema.

**Data availability**:
- BTC spot 1m: 2025-10-01 → 2026-04-13 (covers our window)
- ETH spot 1m / 5m / 15m / 30m: covers our window
- `breach_spot_candle` (research table) has patchy coverage

**Why it matters**:
- SFPs are typically perp-led (perp drops faster than spot on a long cascade). Basis should dislocate briefly.
- Confirmed breaks move perp and spot together. Basis stays roughly stable.

**Adapting effort**: low-moderate. Port `BasisExtractor` to take swing-schema events, add spot-market_candle join at the breach bar.

### 11.7 Higher-TF regime context (MISSING)

**What we have**: 30m breach bar + 4 × 30m pre-breach bars (2h context). Nothing above that.

**What we don't have**:
- 1h / 4h trend direction (EMA slope, or simple close − open sign)
- Distance from daily open, distance from daily VWAP
- 4h range percentile (where is the breach price in the last 4h range?)
- Longer-term volatility regime (current 30m ATR / 1d ATR)

**Why it matters**: same level-breach event has very different success rates in different regimes. A swing-low break in an established downtrend is much more likely to be Confirmed than a swing-low break against the 4h trend.

**Adapting effort**: trivial — market_candle has 1h/4h/1d bars, just query and compute.

### 11.8 Level-specific context (MISSING)

**What we have**: `level_age_hours`, `touch_count_atr`, `touch_count_ticks`.

**What we don't have**:
- **How clean was the level** — range compression near the level (coil before breach)
- **Was the level retested after formation but before breach** — if yes, the level was "defended" → a breach is more meaningful
- **Is there a cluster of levels nearby** — if this level is one of many similar levels within X ATR, it's a less meaningful breach than if it's a standalone
- **Distance to next Phase 1 level** — gives the "room to run" implicit in a Confirmed break

### 11.9 Summary: three dimensions missing

1. **Volume / flow microstructure** at multiple horizons and per-side (§11.1-11.2) — requires no new data, just feature engineering on the existing tick archive
2. **Derivatives context** (OI, funding, liquidations) (§11.3-11.5) — requires new historical ingest
3. **Higher-TF structural context** (regime, level cluster, basis) (§11.6-11.8) — minor new queries, mostly feature engineering on existing candle data

---

## 12. Data availability

### 12.1 What we have
| Source | Path / table | Coverage | Notes |
|---|---|---|---|
| Linear candles (BTC, ETH) | `market_candle` | 1m/5m/15m/30m/1h/4h/1d, Apr 2025 → present | Full coverage, no gaps |
| Spot candles | `market_candle` with market_type='spot' | BTC 1m only; ETH 1m/5m/15m/30m/1h/4h/1d | BTC spot coverage is 1m-only |
| Tick archive | `/db/data01/tick_archive/tick_trade_raw/bybit/{symbol}/{YYYY-MM-DD}.parquet` | Raw trades per day | BTC 172/174 days (99%), ETH 145/178 days (82%) |
| Research tables | `breach_spot_candle` (legacy stop-level research) | Patchy | Needs checking before reuse |

### 12.2 What we would need to ingest
| Feed | Bybit endpoint | Historical backfill difficulty |
|---|---|---|
| Open interest | `/v5/market/open-interest` | ~180 days, moderate effort |
| Funding rate | `/v5/market/funding/history` | ~720 records (each funding event), easy |
| Liquidations | WebSocket stream | Backfill difficult; third-party service (CoinGlass etc.) recommended |
| Order book L1/L2 | WebSocket stream | Not backfillable; would need to start recording |
| Premium index | `/v5/market/premium-index-price-kline` | ~2 years, easy |

### 12.3 Implicit data we haven't leveraged
- `trade_idea` table — real trader signals; could cross-reference with breach events to see if SFPs coincide with known trader positioning
- `trade_journal` — our executed trade history; could validate the signal against live performance
- `accounts` — multi-account; relevant for production scope but not research

---

## 13. Forward options

Ranked by our estimate of **information value per unit effort**. This is opinionated — external reviewer should challenge.

### Option A — Expand tick-volume feature set (NO new ingest, HIGH value)
**Scope**: port and extend `lib/tradelens/breach_analysis/volume.py` and `delta.py` to the swing schema. Add:
- Volume ladder: 5s, 10s, 30s, 60s, 120s, 300s, 900s, 1800s — per-side (buy/sell/total)
- Delta ladder: same horizons, normalised
- CVD curvature: 2nd-order derivative of CVD in the last 60s vs last 300s
- Volume acceleration: 60s / 300s / 900s ratios
- At-level volume: ticks within ±0.25 ATR of the level in the last 5m
- **Breach-bar-local flow**: volume in last 10% of the breach bar
- **Post-breach research-only features** (clearly flagged as research-only, not for live classification): 15s/60s volume post-breach, signed delta post-breach, **reversal-signed volume** (volume in first 60s with side opposite breach direction — the cleanest expected SFP signature)

**Expected new feature count**: ~20–30

**Risk**: multiple-testing. Need to pre-register feature list, require cross-symbol replication, and apply an explicit multi-testing discount.

**Expected F1 gain**: unknown — could be +0.02 (label-noise story wins) or could be +0.10 (feature-set story wins). The point of this phase is *to find out*.

**Cost**: ~1–2 sessions.

### Option B — Ingest OI + funding rate, add to feature set (ONE new ingest, HIGH value)
**Scope**: add an ingest for Bybit OI (1m granularity, ~180 days backfill) and funding rate (~720 records). Build features:
- OI level at breach, ATR-normalised
- Δ-OI over last 5m, 15m, 1h pre-breach
- Funding rate at breach
- 24h funding-rate cumulative
- Trend sign of OI in last 60m

**Expected new feature count**: ~8–10

**Risk**: ingest reliability. Bybit historical OI endpoint can be rate-limited; quality-check against live values.

**Expected F1 gain**: potentially high — OI is the most direct proxy for "are stops piled up here" that's available without a liquidation feed.

**Cost**: ~2 sessions (one for ingest, one for feature engineering + Phase 4/5 rerun).

### Option C — Port basis extractor + add HTF regime context (NO new ingest, MEDIUM value)
**Scope**: adapt `lib/tradelens/breach_analysis/basis.py` to swing schema; add 1h/4h trend direction, daily range percentile, 4h/30m ATR ratio.

**Expected new feature count**: ~8

**Expected F1 gain**: modest — basis is interesting but the prior stop-level work didn't find it conclusive, and HTF context is known-useful but low-magnitude.

**Cost**: ~1 session.

### Option D — Add liquidation data (NEW paid data service, VERY HIGH value if data is clean)
**Scope**: subscribe to CoinGlass, Laevitas, or Amberdata for historical liquidation feed; ingest into a `liquidation_archive` table; build features:
- Long / short liquidation volume in 60s / 300s before breach
- Liquidation cluster price
- Post-breach liquidation cascade magnitude

**Expected new feature count**: ~6–10

**Expected F1 gain**: potentially very high. This is the most direct observation of the stop-hunt phenomenon we can get.

**Cost**: moderate engineering + data vendor cost. Worth pricing separately.

### Option E — Alternative labelling / targets (NO new data, conceptual shift)
**Scope**: reframe the target:
- Regression: predict reversal excursion magnitude (not SFP/Confirmed binary). This gives a richer signal and admits continuous features better.
- Stricter SFP definition: require a reversal excursion ≥ 2 × ATR instead of 1 × ATR. Fewer but cleaner SFPs. Effect on class balance and F1 ceiling.
- Collapse Ambiguous into SFP or Confirmed with a tiebreak rule. Simplifies the target.

**Expected benefit**: may increase the cleanness of the signal but doesn't add information. Useful as a complement to Options A/B, not a replacement.

**Cost**: ~0.5 sessions for each reframing.

### Option F — Production bridge (Phase 6) (DEFER)
Build a LevelGuard integration that emits the current single-feature SFP probability (`breach_body_beyond_atr < ~0.6`) as a real-time signal. **Defer until at least Option A is done** — we'd be shipping a 0.83-F1 signal that might become 0.90-F1 after Option A, at which point production re-tuning is wasted work.

### Option G — SOL (or third-symbol) validation (LOW marginal value now)
Quick rerun of Phases 1–5 on SOL. Confirms cross-symbol stability one more time. ETH already replicated cleanly; SOL would be confirming what we already believe, not generating new info.

### Our recommendation for the external reviewer to challenge

**Pursue Option A first, then Option B.** Option A is cheapest and tests the user's volume-ladder hypothesis directly with existing data. If Option A pushes F1 to 0.90, we've confirmed feature-set underfitting was the real ceiling and Option B (OI/funding) becomes much higher priority. If Option A only gives +0.02, the label-noise ceiling hypothesis gains credibility and Option E (relabelling) or D (liquidation data) become the path forward.

**Production bridge (Option F) should follow Option A**, not precede it.

---

## 14. Open questions for the external reviewer

1. **Is the F1 ≈ 0.84 ceiling primarily a label-noise limit or a feature-set limit?** Our best guess is feature-set; what evidence would change your mind either way?
2. **For tick-volume features (Option A), what window ladder do you recommend?** We proposed 5s / 10s / 30s / 60s / 120s / 300s / 900s / 1800s. Too many? Not enough? Different horizons?
3. **Is "at-level volume" (ticks within ±p×ATR of level) the right way to isolate the "stops cluster at level" phenomenon, or is there a cleaner proxy?** Alternative: volume in ticks whose trade price crosses the level vs. volume in ticks whose price stays just below.
4. **OI data at 1m granularity from Bybit has known-clean history back ~180 days.** Is that long enough for a cross-symbol research context? Should we widen the symbol set (add SOL) to use the full OI window more efficiently?
5. **Reversal-signed post-breach volume** (our candidate "cleanest SFP signature") — is the 60s horizon right? Alternative: use the time-to-recovery-close from Phase 2 as a per-event window length.
6. **How seriously should we take the ETH tick-feature instability?** (ETH had no tick feature in its top-10, BTC had one at rank 5.) Is this a "ETH microstructure is different" fact we should design around, or a "too few events to rank stably" statistical artifact?
7. **Should Ambiguous be collapsed, relabelled, or dropped from the target?** Currently 7–8% of events, unseparable. Affects the baseline numerator.
8. **How much does multi-testing correction erode the findings?** We did ~51 Phase 4 cutoff searches; a proper Bonferroni would be strict. What's the right correction for this research-design?
9. **What's the right production shape if we stop at F1 ≈ 0.85?** A probability gate on a single feature (`breach_body_beyond_atr`) applied to every at-breach decision? Or should we keep the current bar-close gate and use this as a confidence adjuster?
10. **Is there a feature we've missed that's obvious from your training data but not present in ours?** We haven't looked at: open-interest-weighted volume, L2 book imbalance (not available), spread widening, funding-rate convexity, aggregated-exchange-volume (not just Bybit), spot-futures volume ratio.

---

## 15. Risks and traps

**Methodological risks we have tried to guard against:**
- **Data leakage**: every Phase 3 feature is strictly pre-breach or at-breach; tick windows end at `breach_ts` with a `<` filter. Hand-verified.
- **Overfitting thresholds to BTC**: addressed by Phase 5a cross-symbol validation on ETH; threshold transferred with 0.004 F1 loss.
- **Cherry-picking features post-hoc**: we've been explicit in the tracker about pre-registering feature lists, and Phase 4 reported all 51 cutoffs (not just the best).
- **Silent class-balance tuning**: Phase 2 thresholds have been held constant across BTC and ETH runs.
- **Parameter cement**: all Phase 1–3 numeric choices are flagged "(P)" for provisional; none have been tuned against a measurable objective.

**Risks we want external-reviewer feedback on:**
- **Cross-symbol sample is n=2** (BTC + ETH). Replication on 2 symbols isn't a robust generalisation proof. SOL, SUI, XRP behaviour could diverge.
- **Window is n=1** (one ~180-day period). No bull-market-only or bear-market-only subsample. Any macro-regime artifact is undetectable.
- **The 8% Ambiguous class is definitionally heterogeneous** — any classifier will struggle on it. Excluding it would inflate the nominal F1 in a misleading way.
- **We have not tested stability of the v1 pivot rule (50L/10R)** to small perturbations. If changing N_LEFT from 50 to 40 produces wildly different levels, the finding is fragile.
- **Multi-testing correction hasn't been formalised**. Phase 4 ran 51 F1 searches; at p=0.05 we'd expect ~2-3 false positives in ranked order.
- **The whole framework assumes `breach_ts` is the right decision point.** Real production detection will have latency (WebSocket delay, candle-close wait). An "effective breach_ts + 30s" feature set might look very different.

---

## 16. Reproducibility appendix

### 16.1 Key files

| Purpose | File |
|---|---|
| Master tracker | `research/swing_levels/TRACKER.md` |
| Phase 1 pipeline | `bin/tools/swing_levels_phase1.py` |
| Phase 2 pipeline | `bin/tools/swing_levels_phase2.py` |
| Phase 3 pipeline | `bin/tools/swing_levels_phase3.py` |
| Phase 4 pipeline | `bin/tools/swing_levels_phase4.py` |
| Phase 5 pipeline | `bin/tools/swing_levels_phase5.py` |
| Pure logic: pivots | `lib/tradelens/swing_research/pivots.py` |
| Pure logic: filters | `lib/tradelens/swing_research/filters.py` |
| Pure logic: donchian | `lib/tradelens/swing_research/donchian.py` |
| Pure logic: breach detection | `lib/tradelens/swing_research/breach_detect.py` |
| Pure logic: touch count | `lib/tradelens/swing_research/touch_count.py` |
| Pure logic: ATR | `lib/tradelens/swing_research/atr.py` |
| Pure logic: tick refine | `lib/tradelens/swing_research/tick_refine.py` |
| Pure logic: labelling | `lib/tradelens/swing_research/labelling.py` |
| Pure logic: features | `lib/tradelens/swing_research/features.py` |
| Pure logic: separation | `lib/tradelens/swing_research/separation.py` |
| Pure logic: multi-feature | `lib/tradelens/swing_research/multi_feature.py` |
| Legacy: stop-level feature extractors | `lib/tradelens/breach_analysis/` |
| Tick loader (shared) | `lib/tradelens/breach_analysis/tick_loader.py` |

### 16.2 Test suite
- 34 pure unit tests under `tests/unit/test_swing_*.py`
- All green as of 2026-04-23
- Full tradelens suite: 362 passed; 3 pre-existing unrelated failures in `test_sizing.py` (concurrent audit WIP)

### 16.3 Running the pipelines
```bash
# Phase 1 — dataset construction (~2-3 min per symbol)
python3 bin/tools/swing_levels_phase1.py --symbol BTCUSDT
python3 bin/tools/swing_levels_phase1.py --symbol ETHUSDT

# Phase 2 — labelling (~1 sec)
python3 bin/tools/swing_levels_phase2.py --symbol BTCUSDT
python3 bin/tools/swing_levels_phase2.py --symbol ETHUSDT

# Phase 3 — feature extraction (~2-3 min per symbol; tick loading dominates)
python3 bin/tools/swing_levels_phase3.py --symbol BTCUSDT
python3 bin/tools/swing_levels_phase3.py --symbol ETHUSDT

# Phase 4 — single-feature separation (<1 sec)
python3 bin/tools/swing_levels_phase4.py --symbol BTCUSDT
python3 bin/tools/swing_levels_phase4.py --symbol ETHUSDT

# Phase 5 — multi-feature pair rule (~5 sec)
python3 bin/tools/swing_levels_phase5.py
```

### 16.4 Data schemas
- Full DB schema: `$TLHOME/etc/schema.md`
- Tick archive: `/db/data01/tick_archive/tick_trade_raw/bybit/{symbol}/{YYYY-MM-DD}.parquet`
- Config: `$TLHOME/etc/config.yml`

### 16.5 Commits to date (this research arc)
```
f5df9201  feat(swing-research): cross-symbol ETH validation (Phase 5 cross-symbol)
3777db76  feat(swing-research): Phase 4 single-feature separation analysis
ae2e2229  feat(swing-research): Phase 2 labelling + Phase 3 feature extraction
0286fe77  feat(swing-research): Phase 1 v1 dataset (30m/50L/10R/Donchian prominence)
```
Plus preceding Phase 1 v0 work (retired, archived at `research/swing_levels/phase1/run_v0_15m_5L5R/`).

---

## Closing note for the external reviewer

We want you to challenge, not just affirm. Specifically:

- If you think the F1 ≈ 0.84 ceiling is a genuine label-noise limit and no feature-set expansion will break it, say so. We'll absorb that and pivot to production.
- If you think OI / funding / liquidation / volume microstructure will move the needle, tell us the minimum viable feature set to test that hypothesis cheaply — we don't want to boil the ocean.
- If you think our labelling rule (SFP = recovery-close-back + 1×ATR reversal within 2h/6h) is obscuring the signal, propose a reframing and say why.
- If there's a methodological hole we've missed — data leakage, multi-testing, cherry-picked thresholds, survivorship, lookahead bias — flag it hard.

The cost of pausing to get this right is low. The cost of shipping a flawed production signal and eroding trust in the research pipeline is high. We'd rather hear you say "stop, this is wrong" than "keep going."

Thanks.

— Guy (operator) and Claude Code (Anthropic, claude-opus-4-7), 2026-04-23
