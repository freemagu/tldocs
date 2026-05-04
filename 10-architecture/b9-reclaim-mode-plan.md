# B9 — `execute_when='reclaim'` Plan

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

> [!warning] Status: Designed, not implemented
> This plan describes a fully-designed but not-yet-started feature. No code
> has been written, no migration applied. Estimated effort: ~2 days end-to-end.

Architectural plan for the third execute mode. Refer to the
[[breach-decision-glossary]] for the canonical definition of *reclaim*.

## Recap of the term

> **Reclaim** is the state of a level that has been **failed twice
> in opposite directions**, both sustained.
>
> 1. Level fails in direction A (sustained breach upward).
> 2. The same level later fails in direction B (sustained breach
>    downward).
> 3. The state of the level after step 2 is **reclaim**.
> 4. The event of the second sustained breach is the **reclaim
>    event**.
>
> A breach that is *rejected* (price comes back through immediately)
> does NOT contribute to reclaim. The definition requires both
> breaches to be sustained.

## Strategy

`execute_when='reclaim'` fires when a previously-failed level fails
again in the opposite direction. The trader's hypothesis: a level
that has been broken in one direction and is now being broken in
the *other* direction is a strong signal — typical use cases are:

- **Trend-reversal entries**: a former resistance broken upward
  (level failed up, sustained), followed weeks later by a sustained
  break downward (the reclaim event), confirms the level has flipped
  to active resistance once again. Execute a short.
- **Range-break re-entries**: a level that defined the top of a
  range is broken (range expansion), then later broken back through
  in the opposite direction (range re-contraction). Execute on the
  re-contraction.

Operationally indistinguishable from the trader's perspective from
"a level that's been touched and respected twice from opposite
sides", except the touches must have *broken through* (sustained)
rather than just rejected.

## Why it's not a small extension to B7

B7 (`execute_when='fails'`) operates **at the moment of breach**:
the worker sees the trigger condition met and runs the gate to
decide whether to fire now or wait. The lifecycle is contained
within a single breach event.

B9 (`execute_when='reclaim'`) operates **across two breach events
separated by arbitrary time**:

1. The first breach (direction A) must already have happened and
   sustained. The level's history is the input.
2. The system must remember "this level has been failed in
   direction A" indefinitely, until either:
   - The second breach (direction B) happens → reclaim fires.
   - The level is rendered irrelevant (e.g. price moves so far that
     the level is no longer near market).

This requires **persistent per-level state** that survives worker
restarts and is consulted on every breach event for the symbol.

## Data model

### New PostgreSQL table — `level_reclaim_state`

| Column | Type | Notes |
|---|---|---|
| `level_id` | bigint NOT NULL | FK to whatever entity defines the level (likely the existing `level_guard.id` or `swing_level.id`) |
| `symbol` | varchar(32) NOT NULL | denormalised for query performance |
| `first_fail_direction` | varchar(8) NOT NULL CHECK IN ('up','down') | direction of the first sustained breach |
| `first_fail_at_utc` | timestamptz NOT NULL | when the first sustained breach completed |
| `first_fail_attempt_id` | bigint | FK to `level_guard_attempt` for audit |
| `created_at` | timestamptz NOT NULL DEFAULT NOW() | row creation |
| `updated_at` | timestamptz NOT NULL DEFAULT NOW() | last update |
| **PK** | | (level_id) |

One row per level that has had at least one sustained breach.
Updated in-place by the breach completion path (B5/B6 already
detect "breach sustained" on time-cap or adverse-extension).

A level that has been reclaimed (second sustained breach in
opposite direction) **deletes** its row — the reclaim event has
fired, the strategy moves on. If the trader places another
`reclaim` order on the same level later, a new lifecycle starts
from scratch.

### Index

`idx_level_reclaim_state_symbol_dir` on `(symbol, first_fail_direction)`
— supports the "is this incoming breach the reclaim event?" lookup
on the breach hot path.

## State machine additions

In `LevelMindCore`, on every breach event for a guard with
`execute_when='reclaim'`:

```
Guard armed.
   │
   ▼
Breach event detected.
   │
   ▼
Query level_reclaim_state for this level.
   │
   ├── Row exists with first_fail_direction = OPPOSITE of this breach?
   │     → This IS the reclaim event. Wait for breach-sustained
   │       confirmation (existing time-cap / adverse-extension logic),
   │       then EXECUTE the guard's order. Delete the
   │       level_reclaim_state row (lifecycle complete).
   │
   ├── Row exists with first_fail_direction = SAME as this breach?
   │     → Confused state — same direction breached twice without
   │       a reclaim. Strategy choice: refresh first_fail_at_utc
   │       (treat as a new "first" with the latest timestamp), don't
   │       fire. This is the conservative read; document and revisit
   │       once we have data.
   │
   └── No row exists?
         → This is a "first" breach. Wait for sustained confirmation.
           If sustained, INSERT a level_reclaim_state row. Don't fire.
           If rejected, no state change.
```

A `reclaim`-mode guard never fires on the *first* sustained breach
— only on the second-in-opposite-direction. That's the whole
point.

## Interaction with B7

B7's gate is mode-specific. B9 introduces a second mode-specific
flow alongside B7's. Possible compositions:

- A `fails`-mode guard at level L fires on the first sustained
  breach. After it fires, no `level_reclaim_state` row is needed
  — the guard is consumed.
- A `reclaim`-mode guard at level L waits silently through any
  number of breaches in *one* direction (each updates the state
  row), and fires on the first opposite-direction sustained
  breach. The B7 gate's "delay window" pattern *could* apply at
  the reclaim event itself (predict whether the second breach will
  sustain or be rejected) — that's a B9.5 question.

For v1, **B9 fires immediately on the second sustained breach
without consulting B7's predictor**. The predictor is fails-mode-
trained and may not transfer cleanly. Once B9 has accumulated
labelled outcomes, retrain a holds/reclaim-mode-aware predictor.

## Files — current state

**Already implemented** (as of 2026-05-04):
- `level_reclaim_state` table — exists in production DB
- `lib/tradelens/breach_decision/reclaim_state.py` — pure-logic decision engine
- `lib/tradelens/breach_decision/reclaim_persistence.py` — DB read/write wrapper

**Still pending** (the "wiring" step):
- `lib/tradelens/services/level_mind_core.py` — new branch in
  `_handle_breached_*` handlers when `execute_when='reclaim'`
- `bin/server/level_mind_worker.py` — wire reclaim_persistence into
  LevelMindCore construction
- The `execute_when` enum allowlist in any validator that gates the
  trader's order entry (need to trace and add `'reclaim'`)
- Tests if not already present: `tests/unit/test_reclaim_state_decision.py`,
  `tests/integration/test_reclaim_persistence.py`

Estimated remaining effort: ~1 day (infrastructure exists; wiring is the remaining work).

## Open questions

1. **Cross-symbol correlation**: a level that has been failed twice
   in opposite directions on BTC may correlate with similar action
   on ETH. Strategy: ignore for v1; per-symbol state only.
2. **Stale state expiry**: a `level_reclaim_state` row from 6
   months ago — is it still relevant? Possible config: TTL on the
   state row (e.g. 90 days), after which the level is treated as
   "fresh" again. Default TTL: indefinite for v1. Revisit after
   observing rates.
3. **What counts as "sustained" in this context**: B7's adverse-
   extension threshold + time-cap defines "sustained" today.
   Reclaim mode reuses that definition — same thresholds, same
   logic. Keep them coupled until evidence says otherwise.
4. **Precedence with B7 `holds` mode**: a guard with
   `execute_when='holds'` and a row in `level_reclaim_state` —
   does the holds-mode logic still apply (don't fire on this
   breach because we expect rejection), or does the reclaim-state
   override it (fire because this is the reclaim event we've been
   waiting for)? My read: reclaim should take precedence — the
   trader who placed `'reclaim'` is explicitly opting into the
   reclaim semantics, but `'holds'` is a different trader intent.
   The two modes are mutually exclusive on a single guard, so the
   collision is theoretical. Document and move on.
5. **Backtest data for B9**: do we have any historical sequences
   of "level failed in direction A, then direction B"? The Plan 5
   holds-mode dataset doesn't capture this — it labels filled
   limits, not levels-as-history. A new analysis pass on
   `level_guard_attempt` (or `breach_decision_log`) is needed to
   size the opportunity. Out of scope for this plan; flag as a
   prerequisite to building the gate.

## Recommended sequencing

1. **First**: a one-shot analysis script that scans
   `breach_decision_log` (status='ok' rows with realised labels)
   to count: how many distinct levels have been failed twice in
   opposite directions in the last 6 months? If the count is
   zero or very small, B9 doesn't yet have a frequency-of-event
   case — implement only when the dataset supports it.
2. **Second**: ship the persistent state table + decision engine
   (steps 1-3 above) without wiring into the gate. The backfill
   path (`breach_decision_label_backfill`) already runs offline;
   extend it to populate `level_reclaim_state` retrospectively.
   This gives the strategy a clean dataset to validate against.
3. **Third**: wire the gate. By this point we have a reclaim-event
   labelled dataset and can size the strategy's edge.

## See also

- [[breach-decision-glossary]] — reclaim terminology
- [[holds-mode-backtest]] — B8 holds-mode plan (adjacent strategy)
- [[level-guard]] — state machine that B9 extends
- [[40-research/breach-decision/INDEX|Breach-decision index]] — Map of Content
- `lib/tradelens/breach_decision/execute_gate.py` — B7 fails-mode gate (existing)
- `lib/tradelens/breach_decision/reclaim_state.py` — reclaim decision engine (already exists)
- `lib/tradelens/breach_decision/reclaim_persistence.py` — DB wrapper (already exists)

*Last reviewed: 2026-05-04 — status warning added; back-links and wiki-links added. Implementation not started.*
