# AUD-0381 — Rename `tbe` leg-type literal to `auto_trailing_be`

**Date:** 2026-04-29
**Audit ID:** AUD-0381
**Severity:** Minor / Cleanup
**Status:** Design ready, implementation pending

## Background

The breakeven-trigger auto-armer (the "Move SL to B/E after TP1 (25% @ 0.25R)"
toggle on the smart-trade form, with the default sub-checkbox "Use Level Guard
for B/E stop" enabled) is the only path that produces leg rows with the literal
`leg_type='tbe'`. Every other guarded leg uses the canonical `trailing_*` /
`stop` / etc. vocabulary.

`tbe` is semantically "auto-armed BE protector at WAEP, sitting alongside the
original hard stop" — distinct from a user-armed `trailing_be` leg, which is
the primary protection set at trade creation. The leg_type literal is the only
DB distinguisher: `level_guard.origin='system'` is shared by both this path AND
user-set guarded legs created via `create_order`.

## Decision

Rename the literal `'tbe'` → `'auto_trailing_be'` in code and DB.

**Why this name (over `tbe`, `auto_be`, `auto_tbe`):**
- Composes from the canonical `trailing_be` with an `auto_` prefix marking who
  armed it. No new stem, no truncation.
- Symmetric with future `auto_trailing_tp` / `auto_trailing_tl` slots if
  auto-arming is ever extended to TP / TL legs.
- Unambiguous about family membership: same conditional-market-on-trigger
  behaviour as `trailing_be`; only the "armed by whom" differs.

## Data flow (recap)

```
smart-trade-form.tsx:2497-2528         (UI: "Move SL to B/E after TP1" + "Use Level Guard for B/E stop")
  ↓
idea-spec-helpers.ts:60-66             (writes idea_spec_json.breakeven_trigger.use_level_guard)
  ↓
models/dto.py:48                        (BreakevenTriggerConfig.use_level_guard, default True)
  ↓
refresh_order_leg_live.py:1898          (Path C branch when use_level_guard=True)
  ↓
refresh_order_leg_live.py:1961, 1994    ← INSERT leg_type='tbe'  (renames to 'auto_trailing_be')
```

## Scope of change

### Code (4 sites)

| File | Line | Change |
|---|---|---|
| `bin/pipeline/refresh_order_leg_live.py` | 1961 | `'tbe'` → `'auto_trailing_be'` (order_leg_live INSERT) |
| `bin/pipeline/refresh_order_leg_live.py` | 1994 | `'tbe'` → `'auto_trailing_be'` (level_guard INSERT) |
| `frontend/web/src/components/journal/trade-journal-chart.tsx` | 225 | `case 'tbe':` → `case 'auto_trailing_be':` |
| `frontend/web/src/components/journal/trade-journal-chart.tsx` | 300 | `case 'tbe':` → `case 'auto_trailing_be':` |

The two frontend cases already alias to `trailing_be` (label "TBE" + neutral
grey colour). After rename, they alias to the same target — no UI change.

### Database (one numbered migration)

```sql
-- 091_rename_tbe_to_auto_trailing_be.sql

UPDATE order_leg_live  SET leg_type = 'auto_trailing_be' WHERE leg_type = 'tbe';
UPDATE order_leg_hist  SET leg_type = 'auto_trailing_be' WHERE leg_type = 'tbe';
UPDATE level_guard     SET leg_type = 'auto_trailing_be' WHERE leg_type = 'tbe';
```

Production row counts (verified via psql 2026-04-29):
- `order_leg_live`: 1 row
- `order_leg_hist`: 7 rows
- `level_guard`: 10 rows (8 origin='system', 2 origin='resume')
- **Total: 18 rows**

No schema changes needed — `leg_type` is a free-form string column with no CHECK
constraint or enum. Verified zero migrations / DDL reference the literal
`'tbe'`.

### Documentation

- `tradelens/docs/10-architecture/order-leg-classification.md` — rename row
  header `tbe` → `auto_trailing_be`; update the Notes to reference the
  breakeven-trigger feature path; remove the AUD-0381 reference (resolved by
  this work); update the Overview bullet at line 10 to swap `tbe` for
  `auto_trailing_be`.
- `tradelens/AUDIT_TRACKER.md` — mark AUD-0381 Resolved with commit hash; the
  Resolved counts at the top of the tracker are not currently broken out by
  AUD-0381's category, so no totals change is required.

### Tests

Add `tests/unit/test_aud0381_auto_trailing_be_literal.py`:
- Pin the literal `'auto_trailing_be'` at refresh_order_leg_live.py:1961, 1994
  (AST-based or static-source-text check, mirrors the AUD-0080 / AUD-0325
  pattern used elsewhere in the suite).
- Pin the absence of `'tbe'` from these two source files.
- Pin the frontend chart-render mapping: `getOrderLevelLabel('auto_trailing_be')
  === 'TBE'`. (vitest, in `frontend/web/src/components/journal/__tests__/`.)

## Implementation order

The frontend already aliases `'tbe'` to `trailing_be`'s rendering. To avoid a
deploy-window where new code inserts `auto_trailing_be` while old `tbe` rows
still exist:

1. **PR #1 — Frontend dual-case (zero-risk additive change)**
   Add `case 'auto_trailing_be':` alongside the existing `case 'tbe':` in both
   chart switch blocks. Both map to "TBE" label + grey colour. Deploy.

2. **PR #2 — Backend rename + migration (single ship)**
   - Edit `refresh_order_leg_live.py:1961, 1994` to insert `auto_trailing_be`.
   - Add migration `091_rename_tbe_to_auto_trailing_be.sql`.
   - Deploy: backend now inserts `auto_trailing_be`. Existing `tbe` rows
     continue to render correctly via the dual-case alias from PR #1.
   - Run migration `python3 bin/setup/migrate.py up` → all 18 rows renamed.

3. **PR #3 — Frontend cleanup + tests + docs (post-migration)**
   - Verify zero `tbe` rows remain: `SELECT COUNT(*) FROM order_leg_live WHERE
     leg_type='tbe';` (and same for the other two tables).
   - Remove the `case 'tbe':` lines from chart-tsx.
   - Add the regression tests above.
   - Update `docs/10-architecture/order-leg-classification.md`.
   - Update AUD-0381 entry in AUDIT_TRACKER.md to Resolved with this PR's
     commit hash.

This three-PR sequence is deploy-safe at every step: no row is ever
unrenderable, no INSERT ever uses an unknown literal.

If we don't care about the brief deploy-window (because the system has low
traffic and no auto-armed TBEs are likely to fire during the deploy itself),
PR #1 and PR #3 can be combined into a single post-migration cleanup PR. PR #2
must remain its own ship to keep the migration co-located with the code change
that introduces the new literal.

## Risks

- **Live trade running with auto-armed BE during PR #2 deploy.** A position
  that hits BE between backend deploy and migration completion would have its
  new leg inserted as `auto_trailing_be` while the existing 1 live `tbe` row
  is still in flight. PR #1's dual-case alias covers this — both render as
  "TBE" in the chart. Migration then converges them.
- **Hot reload / cached orderClassifier instances** — none. The pipeline reads
  `leg_type` from the Bybit response per call; no in-memory cache holds the
  literal.
- **Backwards-compat for replay tooling.** `bin/tools/`-style replay scripts
  that filter on `leg_type='tbe'` would need updating. Initial grep shows zero
  such scripts; verify again before PR #2.

## Verification (post-migration)

1. `pytest tests/unit/test_aud0381_*` — green.
2. `pytest` full suite — green.
3. psql checks:
   ```sql
   SELECT COUNT(*) FROM order_leg_live  WHERE leg_type = 'tbe';  -- 0
   SELECT COUNT(*) FROM order_leg_hist  WHERE leg_type = 'tbe';  -- 0
   SELECT COUNT(*) FROM level_guard     WHERE leg_type = 'tbe';  -- 0

   SELECT COUNT(*) FROM order_leg_live  WHERE leg_type = 'auto_trailing_be';  -- ≥1
   SELECT COUNT(*) FROM order_leg_hist  WHERE leg_type = 'auto_trailing_be';  -- ≥7
   SELECT COUNT(*) FROM level_guard     WHERE leg_type = 'auto_trailing_be';  -- ≥10
   ```
4. End-to-end smoke: place a testnet trade, enable "Move SL to B/E after TP1"
   with "Use Level Guard for B/E stop", let TP1 fill → confirm a new
   `order_leg_live` row appears with `leg_type='auto_trailing_be'` and the
   chart renders it as "TBE".

## Out of scope

- The `level_guard.origin='system'` collapse between auto-armer and
  create_order paths. If we ever want operator-readable origin tags, that's a
  separate ticket — the rename here keeps the leg_type-based distinguisher
  intact.
- Ranaming `tbe` references in archived `docs/80-claude-checkpoints/` — those
  are point-in-time records; leave them alone.
