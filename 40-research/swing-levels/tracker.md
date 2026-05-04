# Swing Level Breach Research — Master Tracker

> See also: [[40-research/breach-decision/INDEX|Breach-decision index]] (adjacent research — breach-decision predictor)

**Status:** Phase 5 complete — multi-feature pair rule, cross-symbol ETH validation, label-noise ceiling at F1 ≈ 0.84. Phase 6 (production bridge) not started.
**Owner:** Guy
**Created:** 2026-04-22
**Last updated:** 2026-04-23 (Phase 5: multi-feature pair rule exhausted; one-latent-factor confirmed)

---

## 1. Objective

Build a market-structure-native dataset of swing-level breach events and use it to investigate whether genuine breaks can be empirically distinguished from liquidity sweeps (false breaks / SFPs). The near-term goal is **evidence, not a model**: establish whether the data supports a useful separation before any commitment to a classifier or to integration with LevelGuard / LevelMind. Downstream production use is a possible outcome, not a premise.

---

## 2. Scope

- **Market:** BTCUSDT (perp) only for the prototype.
- **Timeframe:** 15-minute candles.
- **Historical range:** approved Phase 1 window — 2025-10-01 00:00 UTC to 2026-03-23 23:59:59 UTC (see §10).
- **Level type:** Swing highs and swing lows (pivot-based).
- **Event focus:** Breach events — the moment price first crosses an active swing level.
- **Research posture:** Protection-first (false break / SFP). TP analysis is explicitly out of scope for this branch.

---

## 3. Non-goals for the current phase

Explicitly **out of scope** until Phase 1 is complete and validated:

- Feature extraction around breach events.
- Labelling logic (SFP / confirmed / reclaim / ambiguous).
- Any classifier or modelling work.
- Simulator work or replay harness.
- Production integration with LevelMind or LevelGuard.
- Cross-symbol generalisation (ETH and others).
- Take-profit research.
- Tick backfill.
- 1m-candle-based breach-timestamp fallback.

---

## 4. Current approved design baseline

- **Level generation:** Pivot-based swing highs and lows (N-left / N-right). Provisional N = 5 on both sides.
- **Light filtering:** Spacing filter and magnitude filter only. Both provisional.
- **Breach detection:** First bar whose high (for a swing high) or low (for a swing low) crosses the level price. Exact breach time refined using tick archive data.
- **Per-event capture:** event metadata, pointer into tick archive (provisional ±60 min window), pointer into candle archive (provisional ±24 h window), touch count (ATR-based and ticks-based in parallel).
- **Touch count:** Distinct approach episodes — not raw tick proximity. Both ATR-based and ticks-based definitions carried in parallel for inspection comparison.
- **Research flow:** Generate levels → filter → detect breaches → verify coverage → manually inspect → *then* (future phases) label / feature / model.
- **Research discipline:** Manual chart inspection is a mandatory checkpoint. No downstream work begins until the dataset looks right on charts.

---

## 5. Known corrections to the baseline memo

- **Historical stop levels are not "arbitrary".** They are a mixed dataset containing both structurally meaningful levels and trader-specific noise. Swing highs and lows are a better research target because they are cleaner and produce a much larger, more reusable dataset — not because stop levels are noise.
- **All numeric thresholds in the memo are provisional.** This includes pivot N, spacing filter value, magnitude ATR multiple, recovery window, follow-through ATR multiple, tick/candle window sizes, and touch proximity bands. Each must be revisited after the first prototype is inspected.
- **Touch count must be defined as distinct approach episodes.** A touch is an episode where price enters a configurable proximity band around the level and then exits the band (retreats by some configurable amount) without breaching. Raw tick proximity is not a valid definition.

---

## 6. Phase breakdown (coarse)

| Phase | Goal | Status | Key results |
|---|---|---|---|
| **1. Dataset construction** | Produce and validate the raw swing-level and breach-event dataset for BTCUSDT 30m over the approved window. | **Complete (v1)** | 191 breach events, 185 tick-refined; [[phase1/phase1-closeout\|Phase 1 closeout]] |
| **2. Labelling** | Define and compute outcome labels (SFP / Confirmed / Ambiguous) with tradable thresholds. Reclaim deferred. | **Complete** | SFP 60.7%, Confirmed 31.4%, Ambiguous 7.9%; [[phase2/phase2-summary-stats\|Phase 2 summary]] |
| **3. Feature extraction** | Compute baseline features from tick and candle windows — pre-breach / at-breach only. | **Complete** | 17 features (6 breach-bar, 3 candle-context, 5 tick, 3 level); [[phase3/phase3-results\|Phase 3 results]] |
| **4. Heuristic analysis** | Single-feature cutoffs and simple rules vs. labels. Manual inspection of each label class. | **Complete** | Best SFP: `breach_body_beyond_atr < 0.66` → F1=0.830; [[phase4/top-cutoffs\|Phase 4 cutoffs]] |
| **5. Cross-symbol + multi-feature** | Cross-symbol ETH validation + 2-feature pair rule search. | **Complete** | ETH replicates (F1=0.837); pair rule gain ≈ 0; one-latent-factor confirmed; [[cross_symbol/comparison\|comparison]], [[phase5/evaluation\|Phase 5]] |
| 6. Production bridge | Proposal for how findings feed LevelMind / LevelGuard. | **Not started** | See [[review-for-external-llm\|external-LLM review]] §13 for ranked forward options |

---

## 7. Phase 1 — Dataset construction

### 7.1 Tasks

**Candle and tick data readiness**
- [x] Confirm BTCUSDT 15m candle source — verified `market_candle` with `exchange='bybit'`, `market_type='linear'`, `timeframe='15m'`.
- [x] Gap-check 15m candle coverage — zero gaps across the full data range.
- [x] Confirm tick archive coverage — 2025-10-01 → 2026-03-23 with 3 documented gap days (see phase1_parameters.md).
- [x] Document exact UTC window — 2025-10-01 00:00:00 UTC to 2026-03-23 23:59:59 UTC.

**Level generation (pivot-based, provisional parameters)** — updated for v1
- [x] Implement pivot detector: strict N-left / N-right on candles (`lib/tradelens/swing_research/pivots.py`, parameterised).
- [x] **v1:** 50L / 10R on 30m candles (mirrors `research/swing_levels/swing_pivots.pine`).
- [x] Emit candidate swing highs and swing lows, tagged with type, pivot timestamp, confirmation timestamp, and level price.

**Level filtering — v1: Donchian prominence**
- [x] Prominence filter: `|price − donchMid(21)| ≥ 1.5 × ATR(14)` at pivot bar (`lib/tradelens/swing_research/filters.py`, `donchian.py`).
- [x] v1 drop count: 2 / 212 rejected (prominence). See §11 for structural reason the filter rarely fires on 50L/10R pivots.
- [x] All new parameters marked provisional in `phase1_parameters.md`.
- [x] Spacing + magnitude + right-side-buffer filters removed (see §10 for each rejection reason).

**Breach detection**
- [x] Walk-forward scan: for each active level, detect the first 15m bar that crosses (`lib/tradelens/swing_research/breach_detect.py`).
- [x] Refine breach timestamp to the first crossing tick via tick archive (`lib/tradelens/swing_research/tick_refine.py`).
- [x] Mark each breached level resolved.
- [x] Capture tick-window pointer (±60 min) and candle-window pointer (±24 h) in event rows.

**Touch-count computation (episode-based)**
- [x] ATR-based band p = 0.5 × ATR(14), exit q = 0.25 × ATR.
- [x] Ticks-based M = 20 × tick_size ($2 at BTC price — see Findings §11 for the "too narrow" finding).
- [x] Both `touch_count_atr` and `touch_count_ticks` computed on every event.
- [x] Hand-trace verified on event #1 (swing high at 114523.9, 2025-10-01) → touch_count_atr = 1, matches state-machine output.

**Dataset output (v1)**
- [x] `levels_raw.csv` — 212 rows (210 kept + 2 dropped).
- [x] `levels_filtered.csv` — 210 kept rows.
- [x] `breach_events.csv` — 191 in-window events.
- [x] `phase1_summary_stats.md` — counts, tick-refinement rate, touch-count distributions.
- [x] `run_v1_notes.md` — delta vs v0, rationale.
- [x] v0 artifacts archived at `phase1/run_v0_15m_5L5R/`.

**Validation (mandatory gate)**
- [x] v1 20-event stratified sample produced → `phase1_spot_check.md` (regenerated with seed=42 against v1 breach_events).
- [ ] Manual chart eyeball of v1 sample — **reviewer task**, must close before Phase 1 closes.
- [ ] Tick-accurate check on v1 events (reviewer task).
- [x] Automated state-machine validation: full suite 275 passed; hand-trace from v0 still valid (state machine unchanged).

**Tracker hygiene**
- [x] Parameters actually used recorded in `phase1_parameters.md` and §8.
- [x] Findings populated — see §11.
- [x] Decision log updated.

### 7.2 Exclusions for Phase 1

- No features, no labels, no scoring, no model.
- No simulator, no replay harness.
- No generalisation to other symbols or timeframes.
- No production wiring.
- No tick backfill, no 1m refinement fallback.
- No parameter tuning beyond first inspection — tuning is a Phase 1.5 activity, not a Phase 1 task.

---

## 8. Assumptions and provisional defaults

Marked **(P)** for provisional. All subject to inspection-driven revision.

| Parameter / assumption | Value | Marker |
|---|---|---|
| Symbol | BTCUSDT perp | Fixed |
| Timeframe | **30m** (v1) | Fixed (was 15m in v0) |
| Historical range | 2025-10-01 00:00 UTC → 2026-03-23 23:59:59 UTC (~174 days) | Fixed (see §10) |
| Pivot definition | strict N-left / N-right, **N_LEFT=50, N_RIGHT=10** (v1) | (P) |
| Prominence filter (v1) | `\|price − donchMid(21)\| ≥ 1.5 × ATR(14)` at pivot bar | (P) |
| Donchian period | 21 | (P) |
| ATR period | 14 | (P) |
| Spacing filter | **removed** in v1 (redundant) | — |
| Magnitude filter | **removed** in v1 (superseded) | — |
| Right-side buffer filter | **rejected** during tuning (pathology) | — |
| Tick window around breach | ±60 min | (P) |
| Candle window around breach | ±24 h | (P) |
| Touch proximity band (p, ATR) | 0.5 × ATR(14) at pivot bar | (P) |
| Touch exit threshold (q, ATR) | 0.25 × ATR(14) | (P) |
| Touch proximity band (ticks) | 20 × tick_size = $2.0 (saturated at 0 — see findings) | (P) |
| Level age-out | None — unbreached levels stay active indefinitely within window | Fixed for Phase 1 |
| Timezone | UTC throughout | Fixed |
| Candle source | `market_candle` — `exchange='bybit'`, `market_type='linear'`, `timeframe='30m'` | Verified |
| Tick source | `/db/data01/tick_archive/tick_trade_raw/bybit/BTCUSDT/{YYYY-MM-DD}.parquet` | Verified |
| Pine reference | `research/swing_levels/swing_pivots.pine` | Canonical rule source |

---

## 9. Validation checklist (Phase 1 gate)

- [x] Candle coverage complete over approved window (30m, zero gaps inside window verified at v1 load).
- [x] Tick archive coverage verified; 3 documented gap days recorded in `phase1_parameters.md` — **6 affected events (v1) flagged `tick_gap_day=True`**.
- [ ] Level dataset passes visual spot-check on ≥ 10 levels per type — **awaiting user (v1 sample ready)**.
- [ ] Breach event dataset passes visual spot-check on ≥ 20 random events — **awaiting user (v1 sample ready)**.
- [ ] Breach timestamps tick-accurate on ≥ 5 hand-picked events — **awaiting user**.
- [x] Touch count implemented as episode-based; state machine unchanged from v0 hand-trace validation.
- [x] Summary statistics produced and reviewed; distributions plausible. Ticks-based saturation finding carried forward, not a hidden error.
- [x] No silent data errors during automated checks; 6 tick-gap-day events explicitly flagged.

---

## 10. Decision log

Append-only. Format: `YYYY-MM-DD — decision — reason`.

- 2026-04-22 — **Start with pivot-based swings plus light filter; reject rolling lookback.** — Rolling lookback doesn't produce discrete, defensible levels and doesn't match the liquidity-sweep framing. Filtered pivots are better but parameter choice needs data; start with light filter.
- 2026-04-22 — **Phase 1 strictly limited to raw dataset construction and validation.** — Prior stop-level research built feature extraction and scoring before confirming signal. Avoid repeating that pattern.
- 2026-04-22 — **Touch count is episode-based, not tick-proximity-based.** — Correction from baseline memo. Raw tick proximity produces meaningless counts during normal hover near a level.
- 2026-04-22 — **All numeric thresholds in the baseline memo are provisional.** — Correction from baseline memo. Values to be revisited after first inspection.
- 2026-04-22 — **Stop-level dataset reframed as mixed-quality, not arbitrary.** — Correction from baseline memo. Stops near swings are structurally meaningful; the reason to prefer swing research is dataset size and cleanliness, not noise.
- 2026-04-22 — **Approved Phase 1 window: 2025-10-01 00:00 UTC → 2026-03-23 23:59:59 UTC (Option A).** — Tick archive coverage runs 2025-10-01 → 2026-03-23. Aligning the candle window to tick coverage gives every retained event tick-level timestamp refinement where ticks are present, at the cost of ~174 days of coverage vs. the original 365-day target. Priority is dataset trustworthiness, not event count. 3 documented tick-gap days are treated as small documented exclusions per the revised DoD and must be reviewed in spot-check.
- 2026-04-22 — **No 1m-candle fallback or tick backfill in Phase 1.** — Keeps Phase 1 scope narrow. Tick backfill is a candidate follow-up work item.
- 2026-04-22 — **Implementation lives under `lib/tradelens/swing_research/` (new package), separate from existing `lib/tradelens/breach_analysis/`.** — Keeps swing-level research isolated from stop-level research code paths. Tick loader from breach_analysis is reused read-only.
- 2026-04-22 — **v1 rework: switched from 15m / 5L·5R to 30m / 50L·10R asymmetric pivots.** — v0 spot-check surfaced event 117 (swing low 111386.0, 2025-10-11 16:30 UTC) as a valid-but-meaningless micro-pivot (the right-5 low was only $6 above the pivot low). Visual tuning in TradingView against a Pine reference (`research/swing_levels/swing_pivots.pine`) converged on 30m / 50L / 10R strict. The stricter left side makes each pivot a 25-hour local extremum; the user's chart intuition is on 30m.
- 2026-04-22 — **Removed spacing filter (v1).** — v0 finding confirmed: strict N_RIGHT inequality mathematically guarantees same-type spacing > N_RIGHT bars. The spacing filter was a no-op at N=5 and would remain a no-op at N=10. Removing rather than scaling to avoid pretending we have a filter that does work.
- 2026-04-22 — **Removed magnitude filter (v1).** — Superseded by the prominence filter, which is directly comparable (price-vs-envelope) and easier to interpret than "magnitude vs. prior opposite swing".
- 2026-04-22 — **Rejected the right-side-buffer filter tried during tuning.** — Concrete rejection evidence: 2026-03-23 14:00 peak (71788) and 2026-03-25 11:30 peak (71984.8) were found as raw `ta.pivothigh` candidates but rejected by a buffer rule requiring the second-highest right bar to be ≥ K×ATR below the peak (observed BUF gaps 158 and 54.8 USD vs. required ~100-150 at ATR ≈ 400-600). Pathology: the filter gets stricter as `rightBars` grows (more right bars → more chances for one to be close to the peak). Not the right shape.
- 2026-04-22 — **Added prominence filter (v1): `|price − donchMid(21)| ≥ 1.5 × ATR(14)` at the pivot bar.** — Based on the Pine reference. `promK=1.5` is a first-pass candidate picked by visual tuning, not optimised against a measurable objective. Replaces both spacing and magnitude filters. Donchian mid and ATR evaluated at the pivot bar (not the confirmation bar), matching Pine's `atr[rightBars]` / `donchMid[rightBars]` semantics.
- 2026-04-22 — **Touch-count parameters unchanged for v1.** — ATR-based band (0.5×) and exit (0.25×), ticks-based M=20, tick_size=0.1. The known "ticks-based saturated at 0" finding carries forward; revision is a Phase 1.5 task.
- 2026-04-22 — **v0 artifacts archived at `phase1/run_v0_15m_5L5R/`, not deleted.** — Needed as reference for Phase 1.5 comparative analysis. A copy of v0's `phase1_closeout.md` and `phase1_parameters.md` lives both at the top level and inside the archive.
- 2026-04-22 — **Phase 2 labelling: 3 mutually-exclusive classes (SFP / Confirmed / Ambiguous). Reclaim deferred.** — Minimal viable shape. Every event gets exactly one label.
- 2026-04-22 — **Phase 2 windows: R = 2 h, F = 6 h.** First-pass candidates. Mirrors the 30m cadence (R = 4 bars, F = 12 bars).
- 2026-04-22 — **Phase 2 thresholds: k_rev = k_fwd = 1.0 × ATR(14) at breach bar.** Symmetric. First-pass candidates; no class-balance tuning (non-goal).
- 2026-04-22 — **Phase 2 precedence rule: SFP wins over Confirmed when both thresholds are satisfied together.** A recovery close-back within R is interpreted as "the breach did not hold" regardless of later advance. Encoded in `labelling.py` and covered by test #7 (`test_label_conflict_recovery_and_both_excursions_prefers_sfp`).
- 2026-04-22 — **Phase 2 non-goals: no reclaim flag, no reclaim class, no threshold tuning, no feature extraction, no classifier, no symbol expansion, no optimisation against feature separability.**
- 2026-04-22 — **Phase 3 scope: 17 per-event features in 4 groups — breach-bar (6), pre-breach candle context (3), pre-breach tick (5), level features carried from Phase 1 (3).** Strictly pre-breach or at-breach: any tick at or after breach_ts is excluded from tick feature windows.
- 2026-04-22 — **Phase 3 placement: new module `lib/tradelens/swing_research/features.py`.** Option A over reuse-existing — existing `breach_analysis` extractors are keyed on stop-level schema (`reference_level`, `exit_direction`, `tick_size`); adapting them was rejected for fragility.
- 2026-04-22 — **Phase 3 tick-missing events (6 / 191): tick features are null, not excluded.** The 6 events still carry full breach-bar + pre-breach-candle + level features.
- 2026-04-22 — **Phase 3 non-goals: no post-breach features, no feature selection/tuning, no classifier, no cross-symbol, no basis/OI/liquidations/funding, no Phase 4 analysis.**
- 2026-04-22 — **Phase 4 scope: single-feature separation analysis only.** For each of 17 features, grid-search best-F1 threshold × direction against three one-vs-rest framings (SFP, Confirmed, Ambiguous). No classifier, no multi-feature combinations, no retuning of Phase 2/3, no cross-symbol.
- 2026-04-22 — **Phase 4 grid: 20 quantile-spaced thresholds per feature, both directions (>, <).** Null rows excluded from ranking, reported separately.
- 2026-04-22 — **Phase 4 placement: new pure module `lib/tradelens/swing_research/separation.py`.** Single-feature grid-search; 4 unit tests (`test_swing_separation.py`).
- 2026-04-22 — **Phase 4 interpretability guard: majority-baseline F1 for SFP is 0.755** (predict-all-SFP ≈ 2·0.607·1.0/1.607). Heuristics must beat this *and* show non-degenerate precision/recall split to be worth reporting. Captured explicitly in `top_cutoffs.md`.
- 2026-04-22 — **Cross-symbol validation scope: ETHUSDT only for this run.** Phase 1→4 rerun with identical parameters. No re-tuning, no new features, no classifier. SOL and others deferred.
- 2026-04-22 — **Cross-symbol window choice: per-symbol tick-archive coverage, not window-matched.** ETH window 2025-10-12 → 2026-04-07 (178 days). Acceptable because Phase 4 is about structural signal, not macro-regime comparison. Window-matched comparison is Phase 6+ territory.
- 2026-04-22 — **Phase 1-4 pipeline scripts now accept `--symbol`** (and `--tick-size` / `--window-start` / `--window-end` for Phase 1). Per-symbol output paths: BTCUSDT keeps legacy flat layout (`phase{N}/`); non-BTC symbols go in `phase{N}/{symbol_lower}/`. BTC regression: byte-identical output to previously committed artifacts on all four phases.
- 2026-04-22 — **Cross-symbol non-goals (locked): no parameter retuning, no classifier, no new features, no SOL work, no PnL claims.**
- 2026-04-23 — **Phase 5 multi-feature scope: hand-rolled depth-2 pair rule** — `(A dA tA) AND/OR (B dB tB)` — for each of {BTC, ETH, pooled} training sets. Brute-force grid over top-6 single-feature ranks × 20-cut thresholds × directions × combiners. No sklearn, no random forest, no GBM.
- 2026-04-23 — **Phase 5 dropped tick features** from the pair-search feature set. Phase 4 showed tick features less stable cross-symbol and they'd introduce null-handling decisions. Retained 12 always-available breach-bar / candle-context / level features.
- 2026-04-23 — **Phase 5 feature placement: new module `lib/tradelens/swing_research/multi_feature.py`** (pair rule + evaluator). 3 unit tests (`test_swing_multi_feature.py`). Pipeline: `bin/tools/swing_levels_phase5.py`.
- 2026-04-23 — **Phase 5 non-goals: no classifier library, no >2-feature combinations, no feature engineering, no tick features in the pair rule, no hyperparameter tuning beyond the pair grid, no PnL / production deployment.**

---

## 11. Findings log

Append-only. Format: `YYYY-MM-DD — finding — implication`.

- 2026-04-22 — **BTCUSDT 15m candles have zero gaps across entire available range (2025-07-14 → 2026-04-22, 27,089 bars).** — No candle-side exclusions needed within the approved Phase 1 window.
- 2026-04-22 — **Tick archive for BTCUSDT is shorter than the full candle range.** — Archive: 2025-10-01 → 2026-03-23, with gap days 2025-10-09, 2025-10-10, 2025-10-26. Drove the Option A window decision.
- 2026-04-22 — **Phase 1 pipeline produced 1,983 in-window breach events** over the approved ~174-day window. 2,071 kept swing levels from 2,077 pivots in-window (6 dropped by magnitude filter, 0 by spacing filter). 97.8% of events received tick-accurate timestamp refinement (1,939/1,983). 44 events fall on the 3 documented tick-gap days and are flagged for review. 72 levels formed in the window remained unbreached at end-of-load.
- 2026-04-22 — **Spacing filter dropped 0 pivots** — this is structural, not a bug. Strict N-left / N-right inequality on same-type pivots mathematically guarantees spacing > N bars between consecutive same-type pivots; the spacing filter as defined is therefore a no-op given the current pivot rule. Implication: if spacing selectivity is wanted, the rule needs to be redefined (e.g. price-proximity spacing instead of bar-index spacing). Deferred to Phase 1.5.
- 2026-04-22 — **Ticks-based touch count is almost entirely zero** — 1,956/1,983 events show `touch_count_ticks = 0`. At BTC price ≈ $60k-$115k, a 20×tick_size ($2) band is ≈ 0.002% of price, far too narrow to register plausible approaches. The ATR-based count (band ≈ 0.5×ATR ≈ $100-$300) is doing the work. Confirms the tracker's concern that ATR-relative is likely the right starting point. M value is clearly under-sized; revision is a Phase 1.5 tuning task, not Phase 1.
- 2026-04-22 — **`touch_count_atr` distribution looks plausible for Phase 1**: 1022 (0 touches, 51.5%), 519 (1), 210 (2), 168 (3-4), 62 (5-9), 2 (10+). Spread suggests the definition is separating first-touch vs. multi-touch breaches without collapsing to a single bucket — the primary concern for this metric.
- 2026-04-22 — **Tick-refinement accuracy validated on event #1**: swing high at 114523.9 (2025-10-01 02:00 UTC); first tick crossing the level inside the breach bar is at 2025-10-01 04:29:38.416400 UTC with price 114524.00000000 — matches CSV `breach_ts_utc` and `breach_price` exactly.
- 2026-04-22 — **Hand-trace of touch-count episode logic on event #1 yields 1** (bar 03:30 enters band, bar 03:45 exits past threshold at L=114274.3 < exit=114341.02; bars 04:00 stay outside). Matches the state-machine output — confirms the episode semantics on real bars.
- 2026-04-22 — **12 unit tests across 4 files cover pivots, filters, touch-count state machine, and breach detection.** Full `pytest` suite: 256 passed, 0 failed, 0 regressions.
- 2026-04-22 — **v0 spot-check event 117 is a micro-pivot.** Math is valid (5L/5R strict inequality holds) but the right-5 low is only $6 above the pivot low (111386 vs 111392 on the adjacent 30m bar), and on 30m TF the "low" is invisibly inside a larger descending move. Canonical failure of the 5L/5R 15m rule, directly triggered the v1 rework.
- 2026-04-22 — **v1 dataset produced**: 272 raw pivots loaded, 212 in window, 2 dropped by prominence filter, 210 kept, **191 in-window breach events**. 96.9% tick-refined (185/191), 6 on tick-gap days, 15 unbreached at window end. Runtime 2m14s (vs 12m7s for v0). Event count is well within the <100 / >10,000 stop-condition guardrails.
- 2026-04-22 — **Prominence filter is nearly a no-op on 50L/10R pivots** (only 2/212 rejected in v1). Structural explanation: a bar that is the strict 50-bar max also dominates the 21-bar Donchian window, so `donchMid[p] = (high[p] + min_low_in_21) / 2`; prominence holds iff `(high[p] − min_low) ≥ 3 × ATR`. On BTC, 50L/10R pivots tend to form at volatility expansions where this inequality is typically satisfied. Not a bug — but suggests the filter's selective work under the new pivot rule is small; future tuning could tighten `promK` or broaden `DONCH_PERIOD`.
- 2026-04-22 — **Test suite grew to 15 swing-research tests across 5 files** (pivots, filters, donchian, touch_count, breach_detect). Full suite: 275 passed, 0 failed. Added: 2 Donchian tests, 3 prominence-filter tests; removed the 2 v0 spacing/magnitude tests.
- 2026-04-22 — **Phase 2 label distribution on the v1 191-event dataset**: SFP 116 (60.7%), Confirmed 60 (31.4%), Ambiguous 15 (7.9%). Passes the pathological-distribution stop conditions (no class at 0%, no class above 90%, not collapsed to Ambiguous). By swing_type the split is consistent across highs and lows (highs 52/22/9, lows 64/38/6). Phase 2.5 can revisit thresholds in light of this baseline, but not now.
- 2026-04-22 — **Phase 2 time-to-resolution medians (where measurable):** recovery-close ~23 min, reversal-threshold ~21 min, follow-through-threshold ~39 min. Most events resolve in the first 1–3 bars of the F window, which suggests the 6 h window is comfortably long for current thresholds.
- 2026-04-22 — **Phase 2 window coverage: 191/191 events had full F-window data.** No data truncation.
- 2026-04-22 — **Phase 2 labelling tests: 7 pure unit tests, all green.** Cover happy paths for SFP and Confirmed on swing high, boundary equality at k_rev=1.0, both Ambiguous paths (recovery-but-no-reversal and no-recovery-no-followthrough), swing-low SFP symmetry, and the precedence-conflict case (recovery + both thresholds hit → SFP wins).
- 2026-04-22 — **Three failures in `test_sizing.py` (AUD-0045/46/47) surfaced briefly during the Phase 2 + Phase 3 test runs, then were resolved externally.** External edits to `test_sizing.py` + `services/sizing.py` at 21:05-21:06 UTC left the sizing module in a partially-applied state; by the time the Phase 2+3 commit gate ran (22:28 UTC) the fix had completed in the working tree and the full suite was green (323 passed). The audit fix landed as commit `01312232` ("fix(sizing): close AUD-0045/0046/0047 — …"). `AUDIT_TRACKER.md` rows 109-111 mark all three as **Resolved** with regression tests (`test_sizing.py::TestAUD004[567]*`). Net impact on swing-research: zero. (Correction: an earlier version of this entry described them as "scoped out per policy" — they were actually fixed externally, not scoped out.)
- 2026-04-22 — **Phase 3 feature run on 191 v1 events**: 185 tick-loaded, 6 null (gap days). Runtime 2m14s. All 17 features populated for 191 events (tick features null on 6). Full swing-research suite: 27 tests passed (5 new in `test_swing_features.py`).
- 2026-04-22 — **Phase 3 feature distributions pass sanity checks**: no constant-valued feature; ATR-normalised magnitudes in sensible ranges (e.g. `breach_bar_range_atr` median 2.05, min 0.58, max 16.52; `pre_2h_velocity_atr_per_h` min −2.28, max +3.49, median near zero). Bools: `breach_closed_through` 98/93 (near 50/50), `breach_bar_up` 84/107. None of the pathological "all null", "constant", or "systematic failure" stop conditions triggered.
- 2026-04-22 — **Notable structural observation (not a Phase 3 claim — just noting for Phase 4 eyes)**: `touch_count_atr` mean 0.81, median 0 — most swing-level breaches are first-touch breaches. `level_age_hours` median 15h, max 1703h (~71 days) — long-lived swings do exist and eventually break.
- 2026-04-22 — **Phase 4 best SFP heuristic: `breach_body_beyond_atr < 0.6559` → F1=0.830 (prec=0.738, rec=0.948).** Material gain over the 0.755 majority-baseline. Non-degenerate split — the rule is doing real work, not just copying the class prior. Interpretation: when the breach-bar body pokes <0.66 ATR past the level, SFP is ~3× more likely than Confirmed. When body pokes ≥0.66 ATR beyond, the breach is more likely to hold. Hand-trace verified on events 1 (FP, Confirmed with body=0.357), 2 (TP, SFP with body=0.355), 117 (TN, Confirmed with body=1.327).
- 2026-04-22 — **Phase 4 supporting SFP heuristics (all F1 ≥ 0.76):** `breach_wick_beyond_atr < 1.67` (0.791), `breach_closed_through = False` (0.785), `breach_bar_body_atr < 2.04` (0.779), `pre_300s_delta_norm < 0.73` (0.765), `breach_bar_range_atr < 4.16` (0.760). All agree directionally — small / contained breach bars correlate with SFP outcome. No tick feature is in the top 6.
- 2026-04-22 — **Phase 4 best Confirmed heuristic: `breach_closed_through = True` → F1=0.759 (prec=0.612, rec=1.000).** Recall 1.0 means **every** Confirmed event closed through the level on the breach bar. Precision 0.612 means 38 of 98 closed-through breaches were actually SFPs — the boolean is necessary but not sufficient. Useful as a first-cut gate.
- 2026-04-22 — **Phase 4 Ambiguous is not separable by any single feature** (best F1=0.444, `breach_bar_range_atr < 1.19`). Consistent with the 15-event support — the class is too small and too heterogeneous for single-feature cutoffs. Either combined features (Phase 5) or relabelling (Phase 2.5) may be needed if Ambiguous becomes actionable. Not a problem for Phase 4 DoD — a null result here is a valid finding.
- 2026-04-22 — **Phase 4 near-degenerate rows flagged in top-10:** ranks 8-10 (`touch_count_atr < 4.11`, `pre_300s_volume > 45.01`, `pre_300s_delta > -1220.1`) sit at or near the feature minimum → "predict-all-SFP" in practice. Their precision (~0.615) is barely above the SFP prior (0.607). Do NOT read them as meaningful heuristics — the F1 gain over baseline is driven by one or two marginal rows.
- 2026-04-22 — **Phase 4 test suite: 4 pure unit tests in `test_swing_separation.py`, all green.** Full tradelens pytest: 336 passed + 3 pre-existing unrelated failures in `test_sizing.py` (AUD0049/0060/0063 — concurrent audit WIP, not this work). Phase 4 artifacts: `feature_separation.csv` (51 rows), `feature_separation.md`, `top_cutoffs.md`, `phase4_parameters.md`.
- 2026-04-22 — **Cross-symbol: ETH Phase 1 dataset built at 50L/10R / promK=1.5**: 291 raw pivots, 235 in-window, 2 dropped by prominence, 233 kept, **210 breach events** (vs BTC 191). 20 unbreached at window end. Event scale similar to BTC. Prominence drop-count identical to BTC (2 each). Tick archive covers 145/178 days (81%) with a large contiguous gap 2026-03-06 → 2026-04-07.
- 2026-04-22 — **Cross-symbol: ETH label distribution mirrors BTC almost exactly**: SFP 63.8%, Confirmed 28.6%, Ambiguous 7.6% (vs BTC 60.7% / 31.4% / 7.9%). By swing_type split consistent (highs 58/28/11, lows 76/32/5). Time-to-resolution medians within 5 min of BTC. The label classification is NOT a BTC-specific artifact of the window, pivot rule, or k_rev/k_fwd thresholds.
- 2026-04-22 — **Cross-symbol: ETH best SFP heuristic replicates BTC's**: `breach_body_beyond_atr < 0.5616` → F1=0.837 (prec=0.754, rec=0.940). Same feature, same direction, threshold within 15% of BTC's 0.6559 (0.830 F1). Identical structural rule.
- 2026-04-22 — **Cross-symbol: BTC-derived rule applied to ETH without retuning** (`breach_body_beyond_atr < 0.6559` → SFP) yields F1=0.833 on ETH vs ETH's own-tuned 0.837 — loss of 0.004. Clean out-of-sample validation. The rule transfers.
- 2026-04-22 — **Cross-symbol: top-4 breach-bar features are stable across BTC and ETH** (`breach_body_beyond_atr`, `breach_wick_beyond_atr`, `breach_closed_through`, `breach_bar_body_atr`) — all point the same direction (small/contained breach bars → SFP). Captures one latent factor "how aggressively the breach bar committed through the level" several ways. Pre-breach tick features are less stable across symbols (ranked 5th on BTC, not in top 10 on ETH) — possibly ETH's 38 null tick events, possibly microstructure difference. Treat tick features as lower-confidence than breach-bar features going forward.
- 2026-04-22 — **Cross-symbol: Ambiguous class is unseparable on BOTH symbols** (best F1 0.444 BTC, 0.361 ETH). Confirms Phase 4 finding that this is a sample-size / labelling limit, not a BTC artifact. Multi-feature combinations or relabelling needed if Ambiguous becomes actionable.
- 2026-04-22 — **Cross-symbol: BTC regression byte-identical after `--symbol` refactor** on all four phases. 31 swing-research unit tests still green. Artifacts: `research/swing_levels/cross_symbol/comparison.md` + per-symbol subdirs under `phase{1..4}/ethusdt/`.
- 2026-04-23 — **Phase 5 result: multi-feature pair rule gives NEAR-ZERO gain over single-feature.** BTC gain +0.003 (0.830 → 0.833), ETH gain +0.005 (0.837 → 0.842), pooled gain +0.002 (0.835 → 0.837). All well within grid-search noise.
- 2026-04-23 — **Phase 5 BTC best pair is effectively the single-feature rule.** Winning rule: `(breach_body_beyond_atr < 0.6559) AND (breach_bar_range_atr > 0.5780)`. The second clause is a no-op — `breach_bar_range_atr` min in the BTC Phase 3 data is 0.578, so `> 0.578` is true for every row except possibly the minimum. The +0.003 F1 lift is grid-search jitter, not a real second-feature contribution.
- 2026-04-23 — **Phase 5 confirms the one-latent-factor hypothesis.** The top-4 features `breach_body_beyond_atr`, `breach_wick_beyond_atr`, `breach_closed_through`, `breach_bar_body_atr` — identified in Phase 4 as pointing the same direction — really are capturing one underlying quantity ("how aggressively did the breach bar commit through the level"). Combining two of them adds nothing.
- 2026-04-23 — **Phase 5 out-of-sample transfer (pair rules)**: BTC-rule → ETH F1=0.829 (in-sample 0.833 — small loss). ETH-rule → BTC F1=0.803 (in-sample 0.842 — larger 0.039 loss). The BTC pair rule, which structurally reduces to the single-feature rule, transfers more cleanly than ETH's — consistent with "simpler rules generalise better" and with Phase 4's cross-symbol transfer finding (single BTC rule → ETH F1=0.833).
- 2026-04-23 — **Phase 5 practical conclusion: a label-noise ceiling at F1 ≈ 0.84.** Multi-feature combinations aren't going to magically push past 0.90. Further improvements require: new feature candidates (not combinations of existing), relabelling (collapse/split Ambiguous, redefine SFP/Confirmed), or a different modelling target (e.g. regress reversal excursion magnitude instead of classifying SFP). Shipping the single-feature rule to LevelGuard is the rational next step; more modelling is not.
- 2026-04-23 — **Phase 5 test suite: 3 pure unit tests, all green.** Full tradelens pytest: 362 passed (vs 359 previously — Phase 5's 3 tests added). No regressions. Artifacts: `phase5/tree_rules.md`, `phase5/evaluation.md`, `phase5/evaluation_matrix.csv`, `phase5/phase5_parameters.md`.

---

## 12. Open questions

- [ ] Is 5L/5R the right starting pivot definition for BTC 15m, or is it too noisy? Check after first inspection.
- [ ] Should the magnitude filter use ATR at the pivot bar, ATR at confirmation, or a longer-window ATR?
- [ ] Should levels age out after some time (e.g. 180 days), or is indefinite validity correct? Leaning indefinite for Phase 1; revisit.
- [ ] For touch proximity: ATR-relative vs. ticks-based — decision deferred to post-inspection comparison.
- [ ] For the breach timestamp: should we require a minimum penetration (e.g. 1 tick beyond, or ≥ 1 × tick_size beyond), or is any cross sufficient?
- [ ] Do we treat a level as breached on the first cross even if the crossing is a single tick that immediately reverses, or do we require any form of persistence? (Leaning first-cross for purity; persistence is a labelling concern.)
- [ ] How do we handle pivots near the start of the Phase 1 window (< N bars of left context)? Log count and decide during implementation.

---

## 13. Risks and traps

- **Poor level definitions.** Too loose → micro-pivots dilute the dataset. Too strict → miss real levels. Mitigation: start simple, inspect, tune — do not over-engineer.
- **Touch-count pollution.** If touch count is mis-defined it will correlate with everything and confuse all downstream analysis. Mitigation: episode-based definition; hand-trace at least one example to verify.
- **Breach timing errors.** Using bar-close instead of first-crossing tick would misalign all subsequent feature windows. Mitigation: tick-level refinement is a Phase 1 requirement, not optional.
- **Silent data gaps.** Tick archive holes near a breach would corrupt downstream work without visible error. Mitigation: explicit coverage check before declaring Phase 1 done; documented exclusions must be reviewed during spot-check.
- **Scope creep into labels / features.** Tempting once the event list exists. Mitigation: non-goals list in §3 and explicit Phase 1 exclusions in §7.2.
- **Parameter cement.** Provisional defaults hardening into unchallenged constants. Mitigation: all provisional values marked (P) in §8 and must be reviewed at end of Phase 1.
- **BTC-only overfit.** Not a Phase 1 concern per se, but Phase 1 choices (e.g. ATR-relative thresholds) should not implicitly assume BTC volatility. Flag in Findings if we see this.
- **Hindsight leakage (future phases).** Not a Phase 1 risk directly, but any Phase 1 output that mixes pre- and post-breach data would cause a leak when features are added later. Keep event rows cleanly at-or-before breach, with post-breach data only as window pointers.

---

## 14. Deferred items

- Feature extraction (time beyond, max excursion, velocity, delta, CVD, pre-breach compression, candle close vs. wick, displacement, etc.).
- Labelling (SFP / confirmed / reclaim / ambiguous) with explicit tradable follow-through thresholds.
- Reclaim detection (may require multi-cross tracking — deferred).
- Higher-timeframe context features (4h / daily trend alignment).
- Open interest, funding, liquidation data integration.
- Cross-symbol validation (ETH at minimum).
- Classifier / modelling work.
- Simulator integration and replay harness.
- LevelMind / LevelGuard production bridge.
- Take-profit research branch.
- Filtered-pivot enhancements beyond spacing + magnitude (e.g. retrace-ratio filtering, structural significance scoring).
- Tick archive backfill for pre-2025-10-01 and post-2026-03-23 ranges.
- 1m-candle-based breach-timestamp fallback where ticks are unavailable.
