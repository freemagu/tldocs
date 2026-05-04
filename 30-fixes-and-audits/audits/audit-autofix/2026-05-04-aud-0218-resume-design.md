---
status: design — decisions locked, ready for implementation
generated: 2026-05-04
audit-row: AUD-0218 (Critical / Reliability — `resume_trade` two-phase shape)
prerequisites:
  - AUD-0218 (a) — suspend/close intra-lock transaction wrap (commit `306af910`)
  - AUD-0231 — deterministic orderLinkId on both `place_order` and `place_conditional_order` recreate branches
  - AUD-0229 — `suspend_state_enum` dual-write (commit `4f03a8ac`)
  - AUD-0039 / AUD-0039 (b) — adapter-level orderLinkId policy
related-audits:
  - AUD-0140 — sibling `force_open_trade` Phase 3 PARK uses the same precedent
  - AUD-0118 — multi-table cross-file txn wrap (Wave C grouping)
estimated-effort: 2-3 days end-to-end (schema → helpers → handler refactor → UI affordance → tests)
---

# AUD-0218 Phase 2 Design — `resume_trade` Pause-on-Error With Manual Retry

## Goal

Today: `resume_trade` runs an exchange call + DB inserts loop with no
transaction wrap (PARK NOTE at `lib/tradelens/api/suspend.py:685-702`).
On partial failure the trade is left in an under-defined intermediate
state — entry market order may have filled, some recreated TPs/stops
may exist on Bybit + DB, others may be missing. Operator's only recourse
today is manual reconciliation.

After Phase 2 of AUD-0218:
- A failed leg in the recreate loop **halts the loop** and persists the
  trade in the `'resuming'` enum state.
- The frozen `surviving_orders` plan and per-leg progress are tracked
  so a retry can resume from where the previous attempt stopped.
- Hitting the same Resume button on a `'resuming'` trade re-enters
  the handler, which detects the paused state and continues from the
  failed leg.
- Bybit's orderLinkId dedupe is the safety net for the
  "Bybit-succeeded-but-network-dropped-the-response" window: a
  duplicate-orderLinkId response is recognised as success and the DB
  insert proceeds.
- The entry market order (step 4 — additional_qty) is **kept** on
  partial failure — the position is correct, only the protective
  orders are missing. `'resuming'` conveys "incomplete protective
  stack — operator action required".

This closes the AUD-0218 PARK NOTE and removes the last entry from
Wave C in the audit-fix follow-up plan.

## Non-goals (explicit)

- **Auto-revert from `'resuming'`** — strictly manual. A trade in
  `'resuming'` stays there until the operator retries successfully or
  takes some other action. No background job auto-rolls it back to
  `'suspended'` or auto-cancels surviving orders. (Decision Q5.)
- **Compensate-on-failure** (cancel the just-placed Bybit orders before
  pausing) — not done. Pause-on-error means "leave succeeded legs in
  place"; the deterministic orderLinkId makes them retry-safe.
- **Separate "retry resume" button or endpoint** — the same `POST
  /trades/{id}/resume` handler covers both first-attempt and retry,
  branching on the `status` enum. (Decision Q6.)
- **`force_open_trade` Phase 3** — same architectural shape, but
  parked under AUD-0140 with its own follow-up. Not in this scope.
- **`bulk_resume_trades`** — already calls `resume_trade` per-trade;
  inherits the new behaviour for free. No bulk-level retry semantics.

## Decisions (locked 2026-05-04)

The seven open design questions in conversation `6d629b39` were each
answered. Locked decisions:

| Q | Question | Decision |
|---|---|---|
| 1 | Pinning `surviving_orders` across retries | **(a) Persist** the resolved list in a new `trade_suspend_snapshot.resume_plan_json` column on the first attempt; retries reuse it verbatim |
| 2 | Per-leg progress tracking | **(a) Query `order_leg_live`** by `(trade_id, lineage_id)` before each leg; skip if a row exists |
| 3 | "Bybit succeeded, DB INSERT failed" orphan window | **Treat duplicate-orderLinkId response as success** and proceed to DB insert |
| 4 | Entry market order on partial failure | **Keep it** — position is correct, only protective stack is incomplete |
| 5 | Time bound on `'resuming'` | **Manual-only** — no auto-revert |
| 6 | UI surface for retry | **Same Resume button** — handler detects state and branches |
| 7 | AUD-0229 enum dual-write to terminal `'resuming'` | **Yes** — extend the dual-write contract to cover the paused state |

The full Q&A discussion that led to these answers is captured in the
4-prompt session `6d629b39-a242-44ed-8e99-d5028b3cf4e0`.

## Implementation outline

### Schema (migration 096)

```sql
-- migration 096: AUD-0218 Phase 2 — resume retry plan + progress
ALTER TABLE trade_suspend_snapshot
    ADD COLUMN IF NOT EXISTS resume_plan_json    text NULL,
    ADD COLUMN IF NOT EXISTS resume_attempt_count int  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS resume_failed_idx    int  NULL,
    ADD COLUMN IF NOT EXISTS resume_last_error    text NULL,
    ADD COLUMN IF NOT EXISTS resume_first_attempt_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS resume_last_attempt_at  timestamptz NULL;
```

**Lifecycle:**
- All NULL on snapshot creation (existing `suspend_trade` write path).
- `resume_plan_json` set once, on the first `resume_trade` call after
  `_determine_consumed_levels` resolves `surviving_orders`. Frozen
  thereafter.
- `resume_attempt_count` bumps once per `resume_trade` call (first
  attempt = 1).
- `resume_failed_idx` set to the loop index that failed; cleared to
  NULL on a successful end-to-end resume.
- `resume_last_error` mirrors `resume_failed_idx` lifecycle.
- `resume_first_attempt_at` / `resume_last_attempt_at` for forensics.

Schema reference (`etc/schema.md`) updated in same commit.

### Code — new helpers in `lib/tradelens/api/suspend.py` (or a small `_resume_helpers.py`)

```python
def _load_or_freeze_resume_plan(
    conn,
    snapshot_id: int,
    *,
    resolve_now: Callable[[], list[dict]],
) -> tuple[list[dict], int]:
    """
    Returns (plan, attempt_count).
    First call: resolve_now() runs, plan persisted, attempt_count=1.
    Subsequent calls: returns the frozen plan from the DB,
    increments attempt_count, updates resume_last_attempt_at.
    Both branches commit on the same connection's open transaction.
    """

def _leg_already_placed(
    conn,
    *,
    trade_id: int,
    lineage_id: Optional[str],
) -> bool:
    """
    True if order_leg_live has any row for (trade_id, lineage_id).
    Used by the per-leg loop to skip legs that were placed in a
    prior attempt — covers both Bybit-success+DB-success and
    Bybit-success+DB-success-but-this-attempt-already-saw-it.
    """

def _is_duplicate_order_link_id_error(exc: ExchangeError) -> bool:
    """
    Bybit returns retCode for a duplicate orderLinkId (verify exact
    code at implementation time — Bybit V5 docs + a one-off probe
    against testnet). On True, caller treats the place_order as
    success and proceeds to the DB insert.
    """
```

### Code — `resume_trade` refactor

Branch on incoming `trade_journal.status_enum`:
- `'suspended'` → first attempt; freeze plan; bump count to 1
- `'resuming'` → retry; load frozen plan; bump count
- anything else → 400 with the existing message

Inside the AppLock, in **one** transaction (similar to the AUD-0218 (a)
suspend/close shape), do the *plan-resolution / counter-bump* writes.
COMMIT, release autocommit, then enter the per-leg loop.

Per-leg loop (now driven by the **frozen** plan, not a re-derived
list):

```python
for recreate_idx, leg in enumerate(plan):
    if _leg_already_placed(conn, trade_id=trade_id, lineage_id=leg.get('lineage_id')):
        recreated_order_log.append((leg.get('leg_type'), leg.get('order_kind'), 'AlreadyPlaced', '-', None))
        continue

    olid = _resume_recreate_order_link_id(trade_id, leg_type, recreate_idx)
    try:
        # Phase A: Bybit place (outside any tx)
        try:
            bybit_resp = bybit.place_order(...) | bybit.place_conditional_order(...)
        except ExchangeError as e:
            if _is_duplicate_order_link_id_error(e):
                # Already placed in a prior attempt; fall through to DB insert
                bybit_resp = None  # caller queries by orderLinkId if needed
            else:
                raise

        # Phase B: DB inserts for THIS leg, in a small transaction
        with atomic_block(conn):
            cursor.execute("INSERT INTO order_leg_live ...")
            if guarded_leg:
                cursor.execute("INSERT INTO level_guard ...")
            if vwap_leg:
                cursor.execute("INSERT INTO vwap_linked_order ...")

        recreated_order_log.append((leg_type, order_kind, 'Success', olid, place_params))

    except Exception as exc:
        # Pause-on-error: persist failed_idx + error, set status='resuming', return 502
        with atomic_block(conn):
            cursor.execute("""
                UPDATE trade_suspend_snapshot
                   SET resume_failed_idx = %s,
                       resume_last_error = %s,
                       resume_last_attempt_at = CURRENT_TIMESTAMP
                 WHERE id = %s
            """, (recreate_idx, str(exc)[:1000], snapshot_id))
            cursor.execute("""
                UPDATE trade_journal
                   SET status = 'resuming', status_enum = 'resuming'
                 WHERE trade_id = %s
            """, (trade_id,))
            cursor.execute("""
                INSERT INTO trade_journal_notes
                       (trade_id, event_type, note, ...)
                VALUES (%s, 'note', %s, ...)
            """, (trade_id, f"Resume paused at leg {recreate_idx} ({leg_type}): {exc}"))
        raise HTTPException(
            status_code=502,
            detail=f"Resume paused at leg {recreate_idx} ({leg_type}). "
                   f"Error: {exc}. Hit Resume again to retry from this leg."
        )
```

On full success at the end of the loop, in a final atomic_block: clear
`resume_failed_idx` + `resume_last_error`, set `status='open'`,
`status_enum='open'`, append the journal note, schedule the
`refresh_order_data` background task.

### Code — entry market order (step 4)

The `additional_qty > 0` block at `suspend.py:882-907` stays as-is
**except** for one guard: skip the entry market call entirely if
`resume_attempt_count > 1` AND the position is already at target
(query `get_combined_portfolio()` for current size). The
`RESM-{trade_id}-{snapshot_id}` orderLinkId already protects against
double-fill via Bybit dedupe, but the explicit skip avoids the wasted
round-trip and clarifies the log line.

### AUD-0229 dual-write extension

Two new write sites for `'resuming'`:
- The pause-on-error path (above) — writes both `status='resuming'` and
  `status_enum='resuming'`.
- The successful end-of-loop path — writes both `status='open'` and
  `status_enum='open'` (already done in the existing write but verify
  on read of the diff).

Existing `'resuming'` (transient, mid-call) writes at
`api/suspend.py:1116` continue to dual-write. No new enum value needed
— the same `'resuming'` value is used for both transient and persisted
"paused" states; the differentiator is whether the AppLock is held
(transient = lock held; persisted = lock released, awaiting retry).

### UI changes (`frontend/`)

- **Status badge:** `'resuming'` shown as a distinct visual state
  (amber? — match the existing palette for in-flight states). Today
  the FE only ever sees `'resuming'` for the brief in-flight window;
  after this ship it's a real persistent state operators must see and
  act on.
- **Resume button:** label becomes "Retry Resume" when
  `status='resuming'`. Same `POST /trades/{id}/resume` call.
- **Tooltip / hover-card on `'resuming'`:** show
  `resume_attempt_count`, `resume_failed_idx` (+ leg name from the
  frozen plan), and `resume_last_error`. Lets operator decide whether
  to retry now or investigate first.
- No auto-refresh polling change required — existing trade-journal
  poll picks up the new column values.

### Tests (mandatory per `/test-plan`)

Unit (no DB):
- `_resume_recreate_order_link_id` — already covered by AUD-0231 tests; re-verify.
- `_is_duplicate_order_link_id_error` — true on the actual Bybit retCode, false on 110001 ("Order not found"), false on generic 5xx.

Integration (`tests/integration/test_aud0218_resume_pause_on_error.py`):
1. **First-attempt happy path** — `'suspended'` → all legs succeed → `'open'`, `resume_plan_json` cleared (or kept; lock in at impl), `resume_attempt_count=1`.
2. **First-attempt mid-loop failure** — leg 2 of 4 raises `ExchangeError` → status=`'resuming'`, `resume_failed_idx=2`, leg-1 row exists in `order_leg_live`, leg-3/leg-4 do not, entry market position unchanged.
3. **Retry from paused state** — set up case 2's end-state, call `resume_trade` again → `_leg_already_placed` skips leg 1, leg 2-4 placed → status=`'open'`, `resume_attempt_count=2`.
4. **Retry hits duplicate-orderLinkId on the failed leg** — simulate Bybit returning duplicate-orderLinkId for leg 2 (i.e. it actually placed first time but response was lost). Assert: leg 2's DB insert proceeds, status=`'open'`.
5. **Retry double-failure** — leg 2 fails again → still `'resuming'`, `resume_attempt_count=3`, `resume_failed_idx=2`, error message updated.
6. **Plan freezing across price drift** — first attempt at price X freezes plan, retry at price Y reuses the frozen plan (assert plan JSON byte-equal across attempts).
7. **AUD-0229 dual-write** — both `status` and `status_enum` written for the persistent `'resuming'` state.
8. **Concurrent retry blocked by AppLock** — second `resume_trade` call while first is in flight returns 409.

## Commit plan (5 commits)

| # | Commit | Files | Test |
|---|---|---|---|
| 1 | Migration 096 + schema.md update | `migrations/096_*.sql`, `etc/schema.md`, `bin/setup/setup_database_pg.py` | DDL idempotency + column presence test |
| 2 | Helpers + duplicate-olid detection | new `lib/tradelens/api/_resume_helpers.py` (or in suspend.py), bybit_client error-code constant | unit tests for the 3 helpers |
| 3 | `resume_trade` refactor — branch on status, freeze plan, per-leg skip, pause-on-error | `lib/tradelens/api/suspend.py` | integration test cases 1-3, 5, 6, 8 |
| 4 | Duplicate-olid handling in the per-leg loop | `lib/tradelens/api/suspend.py` | integration test case 4 |
| 5 | FE — `'resuming'` badge + Retry Resume button + tooltip | `frontend/src/components/...` | manual smoke per CLAUDE.md UI testing rule |

After all 5 land: flip the AUD-0218 row from "Resolved (partial)" to
"Resolved" and move it out of Wave C in the follow-up waves section.

## Open implementation questions (low-risk, resolve at impl time)

- **Q-impl-1:** the exact Bybit V5 retCode for "duplicate orderLinkId".
  Verify against `docs.bybit.com` and a one-off testnet probe before
  shipping commit 4. Constant goes in `bybit_client.py` (e.g.
  `BYBIT_RETCODE_DUPLICATE_ORDER_LINK_ID`).
- **Q-impl-2:** `resume_plan_json` storage — clear after success, or
  keep for forensics? Lean: clear (so a fresh suspend → resume cycle
  starts with NULL and the failed_idx columns aren't ambiguous), but
  the failed-attempt history lives in `trade_journal_notes` so nothing
  is lost.
- **Q-impl-3:** atomic_block helper is the same `core/db_helpers.py`
  function lifted in AUD-0140. Confirm scope at impl time — should
  already be importable.

## Risks

- **Medium:** the per-leg loop now interleaves transactions with
  exchange calls, which is the exact pattern the AUD-0218 PARK NOTE
  warned about. The mitigation is per-leg granularity — each leg's
  transaction wraps only its own DB inserts (not the Bybit call), so
  the "transaction held across exchange calls" anti-pattern is avoided.
- **Low-medium:** duplicate-orderLinkId handling is the first place in
  the codebase that treats a Bybit error as a success signal. Easy to
  get wrong (treating a real failure as success → orphaned DB row).
  The unit test for `_is_duplicate_order_link_id_error` is the gate.
- **Low:** the FE change adds a new persistent status that operators
  need to learn to recognise. Mitigated by clear visual distinction
  and the tooltip showing exactly what failed.

## Cross-references

- AUD-0140 `force_open_trade` Phase 3 — same shape, parked with the
  same precedent. Worth scheduling immediately after AUD-0218 ships
  so the pattern stays fresh.
- AUD-0118 — broader cross-file txn wrap; same Wave C grouping.
- AUD-0231 — supplies the deterministic orderLinkId that this design
  depends on. Its conditional-branch follow-up shipped 2026-04-27
  (commit `fffbed2f`), so both branches are covered.
