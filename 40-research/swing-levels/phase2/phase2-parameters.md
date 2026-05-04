# Phase 2 Parameters — Multi-breach Soft-Stop Labelling (v2)

**Status**: PROVISIONAL numeric parameters. Blocking invariants below are NOT provisional — they must be honoured by downstream consumers.

This file documents the v2 redesign (April 2026) that replaced the 2 h / 6 h
SFP-vs-Confirmed framing with a short-horizon, soft-stop execution framing
aligned with LevelGuard's real decision: *"At breach time, should I delay
soft-stop execution for 15 / 30 / 60 / 180 seconds?"*

---

## Inputs

- **Source levels**: `research/swing_levels/phase1/{symbol?}/levels_filtered.csv` (ALL filtered levels, not just first-breach events)
- **Candle source**: `market_candle` with filters `exchange='bybit'`, `symbol=<arg>`, `market_type='linear'`, `timeframe='30m'`
- **Tick archive**: `/db/data01/tick_archive/tick_trade_raw/bybit/{symbol}/{YYYY-MM-DD}.parquet`
- **ATR anchor**: each level's `atr_at_pivot` carried through from Phase 1
- **Window cap**: matches Phase 1's research window (`DEFAULT_WINDOWS[symbol]` in `bin/tools/swing_levels_phase2.py`); enumeration stops at `window_end`

---

## Event enumeration (re-arm rule, v2.1)

Phase 2 enumerates **all** breach events per level via a state machine in `lib/tradelens/swing_research/breach_enumerate.py`. Phase 1's first-breach-only output (`breach_detect.py`) is untouched.

### State machine

```
state = INSIDE, armed = True

breach_cond   = (high: bar.high > L) | (low: bar.low < L)    # strict
recovery_cond = (high: bar.low  <= L) | (low: bar.high >= L) # inclusive
fully_inside  = (high: bar.high < L)  | (low: bar.low  > L)  # no touch

INSIDE + fully_inside                 -> armed = True                          (re-arm)
INSIDE + breach_cond AND armed        -> emit event, state = BREACHED,
                                         armed = False
                                         (if same-bar recovery_cond -> state = INSIDE)
INSIDE + breach_cond AND NOT armed    -> no event (chatter suppressed)
BREACHED + recovery_cond              -> state = INSIDE, armed stays False
                                         (a fully-inside bar is then required
                                          before the next breach can fire)
```

### Why the re-arm rule exists

Without hysteresis, the bar-level state machine with inclusive recovery emits an event on every oscillation. Evidence from BTCUSDT diagnostic (`bin/tools/swing_levels_phase2_diagnose.py`):

| Metric | permissive (`rearm=False`) | re-armed (`rearm=True`) |
|---|---|---|
| Total events | 9,444 | **2,092** |
| Median breaches / level | 34 | **8** |
| Max breaches / level | 193 | **40** |
| Min inter-breach gap | 30 min (one bar) | **1.0 h** |
| Median inter-breach gap | 30 min | **8.5 h** |
| Breached levels retained | 191 | **191** (100 %) |

In the permissive dataset, ~80 % of events had `breach_idx ≥ 10` and were clustered within single 30 m bars. Training on that population models "is this same-bar chatter?" rather than "should I delay the soft-stop?". The re-arm rule matches trader semantics of a **fresh retest** — price must have stepped clear of the level for the next breach to count.

### Design choices locked here

- **Fully-inside bar, not close-inside.** A wick above the level still engaged with the level and does not count as a pullback. `bar.high < L` (swing high), not `bar.close < L`.
- **Parameter-free.** No `K × ATR` threshold. Simpler, ATR-independent, easier to audit.
- **Case D preserved.** When state is `BREACHED` and a single 30 m bar satisfies both `breach_cond` and `recovery_cond`, the enumerator emits NO phantom event; state returns to `INSIDE` with `armed=False`. Same-bar disambiguation without ticks is not possible and this is the conservative interpretation. A subsequent fully-inside bar is required before the next breach can fire.
- **All kept events are `same_bar_event=True`** in practice for swing highs: a fresh organic crossing from the inside naturally produces a bar with `low ≤ L` (came from below) AND `high > L` (crossed above). Symmetric for swing lows. The non-same-bar events in the permissive dataset were continuation artefacts that the re-arm rule removes.

### Diagnostic escape hatch

`enumerate_breaches(..., rearm=False)` reproduces the pre-v2.1 permissive population and is retained **only** for before/after comparison. Research and production consumers MUST use `rearm=True` (the default). `rearm=False` output is never a valid training input — see blocking invariant 5 below.

---

## Architecture — three layers per event

1. **Raw measurements** (always recorded; single source of truth; ATR-normalised)
2. **Layer A — market_label** (`rejected` / `not_rejected` / NULL on tick-gap)
3. **Layer B — execution labels** (four independent booleans, NULL on tick-gap)

Raw is computed ONCE per event from one tick load. Labels are derived views.
Re-labelling is possible without re-running ingest.

---

## Blocking invariants (downstream consumers MUST honour)

These are **not** provisional. Any violation contaminates the research signal.

1. **Train/test splits MUST stratify on `level_index`** — the same level can produce many breach events; random splits leak same-level correlations into the test set and inflate F1. All downstream Phase 3/4/5 pipelines must use level-stratified splits.

2. **Layer B training MUST exclude `sequence_uncertain=True` by default**. Opt-in inclusion is permitted for robustness testing only, and the opt-in must be declared in the analysis artifact.

3. **Adverse excursion is NEVER a Layer B gating rule**. Per-bucket adverse is recorded in raw for downstream risk-budget reasoning ("would my hard stop at D × ATR have fired during delay N?"), but labelling is recovery-only. LevelGuard operates on soft stops; a separate hard stop caps catastrophic loss.

4. **`market_label_bar_fallback` is diagnostic only**. Never read in place of `market_label` for ML training. Its purpose is manual inspection of tick-gap events.

5. **Enumeration MUST use `rearm=True`**. The permissive population (`rearm=False`) is ~4.5× larger, dominated by same-bar oscillation chatter on stale levels (~80 % of events have `breach_idx ≥ 10`; median inter-breach gap of one 30 m bar), and trains classifiers on "is this chatter?" rather than on the soft-stop execution decision. Using `rearm=False` output for any downstream classifier is disallowed. The `rearm=False` flag is retained in `enumerate_breaches()` purely for diagnostic before/after comparison. See the "Event enumeration" section above.

6. **Counterfactual assumption** (state explicitly): labels assume price evolution is independent of whether the soft stop fired. This is true by construction for a soft stop that is not yet in market.

---

## Raw fields — what is recorded per event

### Recovery timing

- `first_touch_back_seconds` — first sample where favourable excursion ≥ 0 (permissive; diagnostic)
- `first_cross_back_seconds` — first sample where favourable excursion ≥ `k_recovery_atr × ATR` (strict; **drives all labels**)

### Per-bucket extremes (ATR-normalised)

For each `N ∈ {15, 30, 60, 180, 300, 600}` seconds, measured over `[breach_ts, breach_ts + N]`:

- `max_adverse_within_Ns_atr`
- `max_favourable_within_Ns_atr`

Nested invariant: `max_*_within_15s_atr ≤ … ≤ max_*_within_600s_atr`.

### Full-window (3600 s) extremes

- `max_adverse_full_window_price` / `_atr`
- `max_favourable_full_window_price` / `_atr`
- `time_to_max_adverse_seconds` / `time_to_max_favourable_seconds`

PRICE kept for debugging. PCT dropped — reconstructable as `atr × atr_anchor / level_price × 100`.

### End-of-window

- `end_of_window_price`
- `end_of_window_price_vs_level_atr` — signed (positive = breach side)

### Multi-breach context

- `breach_idx_on_level` — 0-indexed within the level
- `seconds_since_level_confirmed`
- `seconds_since_previous_breach` — NULL for first breach
- `total_prior_breaches_on_level`
- `total_prior_rejections_on_level`
- `previous_breach_market_label`
- `previous_breach_first_cross_back_seconds`

### Ambiguity flags

- `tick_data_available`
- `sequence_uncertain` = `same_bar_event AND NOT tick_data_available`
- `same_bar_event` — breach bar also satisfied recovery_cond within itself

### Diagnostics

- `tick_count_in_observation`
- `window_covered_seconds`
- `breach_ts_source` — `'tick'` / `'bar'`

---

## Label rules

### Layer A — `market_label`

| Label | Condition |
|---|---|
| `rejected` | `tick_data_available=True` AND `first_cross_back_seconds` is not NULL |
| `not_rejected` | `tick_data_available=True` AND `first_cross_back_seconds` is NULL |
| NULL | `tick_data_available=False` |

On tick-gap events, `market_label_bar_fallback` is populated from the bar-level fallback measurement (diagnostic only).

**Rename rationale** (v2): `not_rejected` replaces `held`. Absence of observed strict cross-back is NOT proof the level structurally held — it is the absence of observed rejection, which is what the label should honestly claim.

### Layer B — execution booleans

Four independent booleans, driven by `first_cross_back_seconds`:

| Field | True iff | Else False | NULL when |
|---|---|---|---|
| `safe_delay_15s` | `first_cross_back_seconds ≤ 15` | — | `execution_data_available=False` |
| `safe_delay_30s` | `first_cross_back_seconds ≤ 30` | — | ditto |
| `safe_delay_60s` | `first_cross_back_seconds ≤ 60` | — | ditto |
| `safe_delay_180s` | `first_cross_back_seconds ≤ 180` | — | ditto |

**Nested by construction**: `safe_delay_15s → safe_delay_30s → safe_delay_60s → safe_delay_180s`.

`execution_data_available` = `tick_data_available`.

### `smallest_safe_bucket` (convenience only — NOT a training target)

One of: `safe_delay_15s` / `safe_delay_30s` / `safe_delay_60s` / `safe_delay_180s` / `unsafe_to_delay` / `unknown`.

- `unknown` is used iff `execution_data_available=False` (tick-gap). It is explicitly separate from `unsafe_to_delay` — do NOT conflate these in ML training.

---

## Same-bar / tick-gap handling

### Case table

| Case | Enumerator state | Tick data | Enumerator policy | Pipeline flags |
|---|---|---|---|---|
| A | INSIDE | ✓ | Emit 1+ events via tick-driven sequence | `same_bar_event=T`, `sequence_uncertain=F` |
| B | INSIDE | ✗ | Assume breach-first; emit 1 event | `same_bar_event=T`, `sequence_uncertain=T` |
| C | BREACHED | ✓ | Tick-driven (recover-then-rebreach ⇒ emit new event; wick-only ⇒ recovery only) | `same_bar_event=T`, `sequence_uncertain=F` |
| D | BREACHED | ✗ | **Recovery only, NO phantom event** | `same_bar_event=T`, `sequence_uncertain=T` |

Case D is the structurally ambiguous case: a 30 m bar in BREACHED state that both crosses back and re-breaches within itself cannot be disambiguated without ticks. Policy is the conservative interpretation (recovery only), and the event is flagged.

### Tick-gap Layer B policy

On tick-gap days, Layer B booleans are NULL and `smallest_safe_bucket='unknown'`. Downstream filters on `execution_data_available=True` for Layer B training.

---

## Provisional parameters

| Parameter | Value | Marker | Notes |
|---|---|---|---|
| `observation_window_seconds` | **3600 s** (60 min) | (P) | Supports all 6 per-bucket measurements + Layer A structural read + future re-labelling |
| `bucket_seconds` | **(15, 30, 60, 180, 300, 600)** | (P) | Covers all 4 Layer B buckets; 300 and 600 kept for research headroom |
| `k_recovery_atr` | **0.1** | (P) | Strict recovery threshold; filters kiss-and-continue |
| `delay_buckets_seconds` (Layer B) | **(15, 30, 60, 180)** | Fixed per LevelGuard spec | User-approved buckets |
| `bar_seconds` | 1800 (30 m) | Fixed | Matches Phase 1 v1 |
| `tick_archive_root` | `/db/data01/tick_archive/tick_trade_raw/bybit` | Fixed | |
| `rearm` (enumerator) | **True** | Fixed (v2.1) | Fully-inside-bar re-arm rule (see "Event enumeration" above). `False` is diagnostic-only. |

No parameter should be tuned to achieve a target class balance. Threshold revision is a Phase 2.5 activity after manual inspection.

---

## Explicit non-goals (v2)

- **No reclaim class** (deferred).
- **No 2 h / 6 h structural labels** (replaced by the short-horizon execution framing).
- **No classifier work** (that is Phase 4/5).
- **No feature engineering** beyond the raw measurements (that is Phase 3).
- **No PCT form of excursions** (reconstructable from ATR + level_price).
- **No Phase 3/4/5 refactor** — those pipelines will break at runtime against the new Phase 2 schema; refactor is a separate work item.
- **No tuning for class balance**.

---

## Artifact layout

| File | Purpose |
|---|---|
| `breach_labels.csv` | One row per breach event with raw measurements + Layer A + Layer B labels |
| `phase2_summary_stats.md` | Distribution, data quality, and multi-breach stats; auto-generated |
| `phase2_manual_review.md` | Stratified sample for manual chart inspection; generated by `swing_levels_phase2_inspect.py` |
| `phase2_parameters.md` | This file |

---

## Reproducibility

- Pipeline: `bin/tools/swing_levels_phase2.py`
- Inspector: `bin/tools/swing_levels_phase2_inspect.py`
- Pure logic: `lib/tradelens/swing_research/{measurement,breach_enumerate,labelling,multi_breach_context}.py`
- Unit tests (52): `tests/unit/test_swing_{measurement,labelling,breach_enumerate,multi_breach_context}.py` (includes 5 re-arm tests + `rearm=False` parity test)
- Random seed for manual-review sampling: `42` (fixed in inspector)

---

## Downstream consumer checklist

Before training any Layer B model:

- [ ] Filter rows: `execution_data_available == True`
- [ ] Filter rows: `sequence_uncertain == False` (unless doing explicit robustness test)
- [ ] Use LEVEL-stratified train/test split (group key: `level_index`)
- [ ] Train 4 independent binary classifiers (one per bucket), not a multi-class
- [ ] Never use `market_label_bar_fallback` as a training label
- [ ] Record feature-set and bucket in the model artifact for reproducibility
