# Breach-Decision Glossary

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

Single source of truth for breach-decision and level-mind terminology. All
docs, plans, code comments, and prose references should align with this
file. When code identifiers must diverge (e.g. existing `execute_when='fails'`
config string), this glossary is the prose-side anchor and explicitly notes
the mapping.

Last updated: 2026-04-28.

---

## Lifecycle: events

| Term | Definition |
|---|---|
| **Approach** | Price moves toward a guarded level. |
| **Touch** | Price reaches the level. Neutral — does not by itself imply a breach. |
| **Breach** | Price crosses the level by ≥ the configured threshold. The event is binary; whether it sustains is a separate outcome. |
| **Reclaim event** | The second sustained breach of the same level, in the opposite direction from the first sustained breach. The transition into reclaim state. See *Reclaim* below. |

## Lifecycle: outcomes

After a **breach** event, exactly one of the following resolves:

| Term | Synonyms (all equivalent) | Meaning |
|---|---|---|
| **Breach sustained** | *Level failed* | Price extends past trigger and stays. The level has now failed in this direction. |
| **Breach rejected** | *Level held* (post-breach), *false break* | Price reverses back through the level. The breach did not sustain; the level remains structurally intact. |

If no breach event occurred but price approached the level and turned away:

| Term | Synonyms | Meaning |
|---|---|---|
| **Approach rejected** | *Level held* (no breach) | Price touched the level but never crossed. |

**Primary prose convention:** prefer "level failed" / "level held" when
describing what happened to the level; prefer "breach sustained" / "breach
rejected" when describing what happened to the breach event itself.
"Failed" is the primary form (mirrors the `execute_when='fails'` config
string).

## States

| Term | Type | Definition |
|---|---|---|
| **Reclaim** | state | The state of a level that has been failed twice in opposite directions, both sustained. Sequence: level fails in direction A (sustained breach upward, say), then later the same level fails in direction B (sustained breach downward). Both crossings are sustained — neither is a rejected breach. |

Reclaim is the *state of the level*. The transition into reclaim state is
the *reclaim event* (see Lifecycle: events).

A breach that is rejected does NOT produce a reclaim. The reclaim definition
requires two sustained fails in opposite directions.

## Execute modes

The trade plan's `execute_when` field selects which level-outcome event
fires the order:

| Mode (config string) | Fires on | Mode wired in `LevelMindCore`? | Predictor gate shipped? |
|---|---|---|---|
| `execute_when='fails'` | Level failed (= breach sustained) | ✅ Production | ⚠️ **B7** — shadow mode only; not wired to actual gate decisions |
| `execute_when='holds'` | Level held (= breach rejected, OR approach rejected) | ✅ Production (default for limit orders) | ❌ **B8** — Phase 1 backtest done; Phase 2 gate not started |
| `execute_when='reclaim'` | Reclaim event (second sustained breach in opposite direction) | ❌ **B9** — infrastructure exists (`level_reclaim_state` table, `reclaim_state.py`, `reclaim_persistence.py`); LevelMindCore wiring deferred | n/a — v1 plan fires immediately on second sustained breach without a predictor gate |

> **Mode vs. gate distinction.** Each `B<n>` label in this codebase
> refers to a **predictor gate** that decides "fire now vs. defer" at
> the moment of breach for a given mode — *not* the mode itself. The
> basic execute-mode plumbing (does the worker recognise this mode and
> trigger an order on the right outcome?) is wired independently of
> whether the predictor gate for that mode has been built. Holds-mode
> orders work today; the holds-mode predictor gate (B8) does not. Same
> distinction will apply to reclaim mode: B9's wiring is the mode
> plumbing; the v1 plan does not include a predictor gate for it.

## Breach-decision gate (B7)

The gate sits at the moment of breach (in `execute_when='fails'` mode only,
v1) and predicts whether the breach will sustain or be rejected. If the
model says rejection is likely, the gate enters a delay window and re-checks
on each tick. Outcomes recorded in `execute_gate_log.delay_outcome`:

| Outcome (column value) | Meaning |
|---|---|
| `fall_through` | Gate condition not met; legacy 5s-timeout path runs. |
| `breach_rejected` | Gate held delay; breach was rejected within the window; execute cancelled. *(Renamed from `reclaim_cancel` — see Renames below.)* |
| `adverse_cap` | Gate held delay; price extended past trigger past the slippage budget; execute fired. |
| `time_cap` | Gate held delay to `max_total_delay_s` without resolution; execute fired. |

The gate's "delay window" is sometimes referred to as the **rejection
window** (the period during which we wait to see if the breach gets
rejected). The legacy 5s timeout in `LevelMindCore` was historically
called `reclaim_window_sec`; the rename to `rejection_window_sec` is queued.

## Protective hard stop invariant

> Every trade carrying a guarded conditional-market close (TTP / TTL / TBE
> / stop) must also carry at least one **unguarded** protective hard stop —
> a leg with `leg_type='stop'`, `status IN ('new','untriggered')`, and no
> active `level_guard` row.

The reasoning: a guard can delay or cancel its leg's execution. A guarded
stop is therefore not a reliable safety net — its execution can be deferred
by the same machinery that's deferring the rest of the trade. The
invariant guarantees there's always one stop on the trade whose firing is
unconditional.

**Where the invariant is enforced:** API layer, at the three guard-creation
endpoints. See `open_orders.has_unguarded_hard_stop` and the gate at
`POST /open-orders/{preview, create, amend}`. The gate fires when:

- `request.guard_enabled = True`, AND
- the new (or existing, for amend) leg's classified `leg_type IN
  {'trailing_tp','trailing_tl','trailing_be','stop'}` (the conditional-market
  close-side family — see `order-leg-classification.md`).

In-scope leg types (gate fires):

| Leg type | TradeLens label | Why in-scope |
|---|---|---|
| `trailing_tp` | TTP — trailing take profit | Conditional-market close, fires market-like on trigger |
| `trailing_tl` | TTL — trailing take loss | Same |
| `trailing_be` | TBE — trailing break-even | Same |
| `stop` | Primary protective stop | Itself a conditional-market close; can't be guarded if it's the only stop |

Out-of-scope leg types (gate does **not** fire even with `guard_enabled=True`):

- `tp`, `be`, `tl` — non-trailing close family (limit / conditional-limit-on-book / market). Doesn't fire market-like on trigger.
- `entry`, `dca`, `seed` — entries.
- `auto_trailing_be` — synthetic guard-system label, never produced by user creation flow.

**Cancel-side gate:** `POST /open-orders/cancel` rejects with
`error_code='would_break_unguarded_hard_stop_invariant'` when:

- the leg being cancelled has `leg_type='stop'` AND no active guard, AND
- the trade is `status='open'`, AND
- post-cancel, no other unguarded `stop` exists on the trade
  (verified by `has_unguarded_hard_stop(excluding_leg_id=cancel_target)`).

The rule is unconditional on the trade's other orders — an open trade
must always have at least one unguarded protective stop. Cancelling a
guarded stop, a non-stop leg, or any leg on a closed trade is
unaffected.

**Earlier behaviour (removed):** the breach-decision orchestrator at
ARMED→BREACHED transition formerly ran a sibling-stop check and wrote
`status='skipped'` rows for breaches lacking a sibling stop. That filter
has been removed — the invariant is now enforced at the API layer where
guards are created, not at the breach hot path. The legacy
`breach_decision_log.hard_stop_confirmed` column was dropped in
migration 089.

## Statistics terms

| Term | Meaning |
|---|---|
| **Breach rejection rate (within Xs)** | The empirical proportion of breaches that were rejected (= level held) within X seconds of the breach event. One value per target window: 15s / 30s / 60s / 180s. Equal to the `realised_safe_*s` column's mean over the dataset. The artefact JSON stores this per-target as the field `base_rate` — same number, generic ML name. As of 2026-05-04: ≈ 0.45 / 0.50 / 0.54 / 0.64 across the four windows. |
| **Base rate** | Generic statistics / ML term for the proportion of positive cases in any binary classification dataset. In our system, "base rate of `realised_safe_30s`" and "30-second breach rejection rate" refer to the same number. Use *breach rejection rate* in domain text; *base rate* is fine in ML-flavoured discussion. |
| **No-information baseline** | The constant-output "model" that ignores all features and predicts the breach rejection rate as a fixed probability for every breach. Not a real predictor — it's just the historical frequency emitted on every input. Used as the floor any real model must beat: a model that scores worse than the no-information baseline on Brier or log-loss is contributing zero (or negative) information beyond the prior. Sometimes called "base-rate predictor" in ML literature. |

> **Why these terms matter for evaluation.** Brier and log-loss scores are
> scale-dependent: a Brier of 0.25 on a 50/50 problem is uninformative,
> while a Brier of 0.09 on a 90/10 problem looks impressive but is also
> uninformative (the no-information baseline scores 0.09 on 90/10 too).
> Always report the no-information baseline alongside the model's score.

## Direction terms

| Term | Meaning |
|---|---|
| **Long-side level** | Level above current price relative to the position's PNL geometry — breach upward fails the level. |
| **Short-side level** | Mirror of the above. |
| **Trigger** (prose) / **`reference_level`** (DB column) | The price at which the breach event evaluates. Same value, different surface. |
| **Trigger threshold** | The min distance past trigger required for the breach to count (anti-noise). |

## Deprecated / do-not-use

The following terms have been retired; do not introduce them in new prose
or code:

| Don't use | Use instead |
|---|---|
| **Confirmed** (as a breach outcome) | *Sustained* / *Failed* |
| **Validated** | *Sustained* / *Failed* |
| **Reversal** (as a breach outcome) | *Rejected* |
| **Reclaim** (for the false-break / breach-rejected case) | *Breach rejected* — reclaim now means specifically the two-sustained-fails state. |

Existing code/data using the old terms is grandfathered until renamed. New
work must align with this glossary.

## Renames in flight

| Surface | Old | New | Status |
|---|---|---|---|
| `execute_gate_log.delay_outcome` value | `reclaim_cancel` | `breach_rejected` | Confirmed 2026-04-28; migration pending |
| `level_mind_core.py` constant | `reclaim_window_sec` | `rejection_window_sec` | Confirmed 2026-04-28; rename pending |

## See also

- `lib/tradelens/breach_decision/` — orchestrator and gate code
- `lib/tradelens/services/level_mind_core.py` — per-monitor state machine
- `etc/schema.md` — `breach_decision_log` and `execute_gate_log` columns
- [[level-guard]] — guard lifecycle (upstream of breach events)
- [[breach-decision-training]] — training pipeline
- [[40-research/breach-decision/INDEX|Breach-decision index]] — Map of Content

*Last reviewed: 2026-05-05 — added Statistics terms section defining "breach rejection rate (within Xs)", "base rate" (as the ML synonym), and "no-information baseline" (the constant-output benchmark). Earlier 2026-05-04: back-links and wiki-links; execute-modes table split into "mode wired" vs. "predictor gate shipped" columns.*
