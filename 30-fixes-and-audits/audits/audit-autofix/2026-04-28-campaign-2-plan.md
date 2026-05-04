# Campaign 2 — Audit-fix dispatch plan (3-day main + 1.5-day Wave C tail)

**Author:** Claude Opus 4.7 (1M context), 2026-04-28
**Predecessor:** [Campaign 1 final report](./2026-04-28-3day-campaign-final.md) — closed 30 AUDs (Confirmed 128 → 98)
**Tracker SOT:** [`AUDIT_TRACKER.md`](../../../../AUDIT_TRACKER.md)
**Master at kickoff:** `b13bb2d0`

This document is the operating contract for Campaign 2. Each wave below is a
**pre-dispatch table**: file, function, fix shape, test plan, gate. Park
rationale is recorded for items that won't fit. Tracker rows get updated in
single per-wave commits at wave close.

---

## Architecture (carry forward from Campaign 1)

**Keep:**
- Direct main-session editing — no `Agent`-tool dispatch (Campaign 1 proved
  6-agent parallel hits Anthropic per-day limits with 0/6 useful output).
- One-cluster-per-file rule. Disjoint clusters can run as separate commits
  in the same wave; no overlapping line edits.
- Single tracker commit per wave (orchestrator-only).
- `/test-plan` mandatory for non-trivial production changes (waivers go in
  the commit message with category).
- Per-wave full pytest gate before next wave starts (under 5 AUDs = targeted
  sweep is enough; 5+ AUDs OR money/schema/backend = full pytest).
- Schema verified via `etc/schema.md` before any SQL.
- Rounding via existing helpers (`round_to_tick`, `round_qty_to_step`,
  `round_price`, `round_qty`); never hand-roll formatting.
- No `git add -A`; per-file staging.
- Run unattended with sensible gates; no pre-edit discussion.

**Drop:**
- `Agent`-tool parallel dispatch.
- Plan mode → `ExitPlanMode` → fire-and-forget.

## Hot-zone exclusion list (parallel session)

DO NOT touch these files/dirs unless explicitly verified quiet:
`lib/tradelens/breach_decision/`, `lib/tradelens/services/level_guard.py`,
`bin/server/level_guard_daemon.py`, `lib/tradelens/services/level_mind*`,
`bin/server/level_mind_worker.py`, `lib/tradelens/services/sizing.py`,
`lib/tradelens/services/state_manager.py`.

Pre-wave check (every wave): `git log --oneline -10 | head -3` and `git status`
to confirm no in-flight parallel edits.

## Tracker housekeeping (Day 1, before Wave A)

| AUD | Current | Target | Reason |
|---|---|---|---|
| AUD-0077 | Confirmed | Resolved | Parallel session shipped at `068f199b refactor(sizing): AUD-0077 — accept Numeric (Decimal\|int\|float\|str) at public boundary`; tracker is stale. |

Ship as the first commit of Day 1, before Wave A code work, so the campaign
delta math stays accurate.

---

## Day 1 — Wave A: AppLock + orderLinkId + LevelGuard CREATE atomic block

**Files in scope:** `lib/tradelens/api/open_orders.py`,
`lib/tradelens/adapters/bybit_client.py`, plus tests.
**Cluster commits:** 3 (bybit_client batch helper; open_orders mutations; tests).
**Tracker commit:** 1.
**Effort estimate:** 6–8h.
**Risk:** medium (money path).

| AUD | Severity | File / Location | Fix shape | Test plan |
|---|---|---|---|---|
| 0079 | Critical | `bybit_client.py:~63+` (new method) and `open_orders.py:801-858` (`bulk_cancel_orders`) | Add `BybitClient.cancel_batch_orders(orders, category)` chunked at Bybit's 10-per-call limit (`/v5/order/cancel-batch`). Replace `bulk_cancel_orders`'s per-order loop with batch call + single subprocess refresh at end. | Unit: `test_aud0079_cancel_batch.py` — 1-order batch, 11-order batch (chunks 10+1), batch failure response surfaces per-order success/fail. Integration: `bulk_cancel_orders` smoke test that 10 orders use 1 batch call (mocked) instead of 10. |
| 0081 | Critical | `open_orders.py` mutation paths: cancel (~801), convert-to-limit (~1471 has the only existing `AppLock`), create (~3711-3734), most amend paths (~3385) | Wrap every mutation in `AppLock(namespace='order-mutation', lock_key=f'leg-{leg_id}')`. Use AUD-0211 / AUD-0184 as reference patterns. Return HTTP 409 on lock-acquire failure with body `{ok: False, message: "Order is currently being modified"}`. | Unit: `test_aud0081_applock_mutations.py` — each mutation path acquires the lock; double-call collides with 409; lock released on both success and exception paths. |
| 0082 | Critical | `open_orders.py` placement calls at 2385, 3385, 3711-3734 (existing `_generate_order_link_id` at `bybit_client.py:51`) | Thread `_generate_order_link_id(prefix, ...)` through every `place_order` / `place_conditional_order` call. Persist the generated ID in `order_leg_live.exchange_order_link_id` (verify column exists; if not, **STOP and ask** — schema change is out of wave scope). | Unit: each placement call site receives a unique `orderLinkId`; idempotent retry of the same placement (same orderLinkId) is a no-op. |
| 0083 (LevelGuard CREATE remainder) | Critical | `open_orders.py:~4155` `Creating LevelGuard-protected order for trade` block | Apply existing `_atomic_block` (already at `open_orders.py:46-72`) to the LevelGuard CREATE path — same shape as the amend→guard wrap that shipped in `d0a560b0`. Keep `vwap_linked_order` insert OUTSIDE the block (intentionally non-fatal). | Extend `tests/unit/test_aud0083_atomic_block.py` — CREATE-path partial failure rolls back order_leg_live + level_guard but leaves vwap_linked_order untouched. Source-shape regression guard for the `_atomic_block` callsite. |

**Pre-flight:**
1. `git status` clean; HEAD = `b13bb2d0` or fresh master tip.
2. Verify column `order_leg_live.exchange_order_link_id` exists (`grep "exchange_order_link_id" tradelens/etc/schema.md`); if not, STOP — Wave A becomes 3 AUDs without 0082.
3. Pre-wave parallel-session check.

**Park (Wave A):**
- AUD-0083 vwap_linked_order block — intentionally non-fatal per audit text; not a Wave A deliverable.

**Wave-close:** full pytest, then single tracker commit moving 0079/0081/0082
to Resolved and 0083 from Resolved (partial) to Resolved.

**Salvage policy:** re-execute fresh per user direction. Do NOT pull from
`/app/syb/tradesuite/.claude/worktrees/agent-*`.

---

## Day 2 — Backend file-localized clusters

### Wave 2A — `open_orders.py` remainder (Chunk 3)

**Files in scope:** `lib/tradelens/api/open_orders.py`, plus tests.
**Cluster commits:** 1 monolithic open_orders.py commit (all edits in one
file, one logical sweep).
**Effort estimate:** 4–5h.
**Risk:** medium (money path; touches several leg-classification helpers).

| AUD | Severity | Location | Fix shape | Test plan |
|---|---|---|---|---|
| 0087 | Major | `open_orders.py:2939-2953` `get_tick_size` | Pass `bybit` client through instead of constructing fresh `BybitClient(account_name)`. Update all callers. | Unit: callers receive shared client; close() not called per-invocation. |
| 0089 | Major | `open_orders.py:2918-2929` `calc_trigger_direction` | Take `side` and `leg_type` as inputs; compute deterministically (no current-price comparison). | Unit: `test_aud0089_calc_trigger_direction.py` — every (side, leg_type) combo yields the documented direction; current-price-equals-trigger no longer ambiguous. |
| 0091 | Major | `open_orders.py:2761-2792` `check_existing_stop` | Treat any conditional close with `qty >= position_size` as existing stop, regardless of `leg_type`. | Unit: trailing_tl/trailing_be/tl/be each detected as existing stop when full-position-qty. |
| 0092 | Major | `open_orders.py:2683-2684` `determine_leg_type` | Remove auto-relabel-to-stop. Require explicit `leg_type` from caller; raise `ValueError` if ambiguous. | Unit: explicit leg_type round-trips; missing leg_type raises. |
| 0093 | Major | `open_orders.py:26-30` `REFRESH_SCRIPT` path | Replace subprocess invocation with in-process call to the relevant `refresh_*.main()`. Drop the `../../../bin/pipeline/` hardcode. | Unit: refresh-trigger path no longer calls `subprocess.run`; mock the function call. |
| 0095 | Major | `open_orders.py:2795-2825` `calculate_quantity` (special-cases at 991-994, 2053-2064) | Replace `qty=0 means entire` sentinel with explicit `close_entire: bool` flag on the helper. Update both call sites + amend endpoint to pass the flag. | Unit: explicit-flag round-trip; `qty=0` without flag now raises (or returns 0); legacy "qty=0 reduce-only" Bybit semantics still passed through to the API layer unchanged. |
| 0098 | Major | `open_orders.py:2084-2104` VWAP stamp-into-leg block | Make local DB the primary writer on exchange success: write to DB BEFORE the subprocess refresh fires (instead of relying on refresh to persist). Subprocess refresh becomes idempotent reconciliation. | Unit: VWAP value is in DB even if subprocess refresh fails; double-refresh is idempotent. |
| 0100 | Minor | `open_orders.py:259, 514, 2393, 3579` `reduce_only` strings | Schema check: confirm `order_leg_live.reduce_only` is already boolean (per migration history). If yes, drop the `.lower() in (...)` parsing. If no, **park** — schema change is out of wave scope. | Unit: bool true/false round-trip; raw bool from DB no longer crashes. |

**Park (Wave 2A):**
- AUD-0096 (file-size SRP refactor — 3,867 LOC split into routes/services/utils):
  multi-day mega-refactor; do NOT bundle into a sweep wave. Pair with Wave D
  follow-up.

**Pre-flight:** parallel-session check; verify schema for AUD-0100 boolean
column status.

**Wave-close:** targeted pytest of changed test files, then full pytest.

### Wave 2B — pipeline cluster (Chunk 5)

**Files in scope:** `bin/pipeline/refresh_order_leg_live.py`,
`bin/pipeline/refresh_trade_journal.py`, plus tests.
**Cluster commits:** 2 (one per file).
**Effort estimate:** 4–5h.
**Risk:** medium (data integrity).

| AUD | Severity | Location | Fix shape | Test plan |
|---|---|---|---|---|
| 0154 | Major | `refresh_order_leg_live.py:2112-2304` `upsert_legs_to_db` | Replace SELECT-then-UPDATE-per-leg with batch SELECT (load existing snapshots once) + `INSERT ... ON CONFLICT (id) DO UPDATE`. | Unit: 100-leg batch produces 1 SELECT + 1 INSERT-on-conflict (mocked); existing snapshot semantics preserved. |
| 0166 | Major | `refresh_order_leg_live.py:2432-2471` stale-order archival | Replace serial loop with batch fetch from Bybit's order-history endpoint (one call covers many) + batch INSERT into order_leg_hist. | Unit: 50-disappeared-orders test produces ≤2 Bybit calls (mocked) instead of 50; one failure no longer blocks the rest. |
| 0167 | Major | `refresh_*.py` per-invocation DB connect | Replace per-invocation `PostgresDB(config.database).connect()` with module-level pool reuse via existing `pg_pool.get_db_connection()` (matches FastAPI's pattern). | Unit: connect call site count goes from N (per pipeline run) to 1; closing path still releases. |
| 0168 | Major | `bin/pipeline/_lib/` (new) | Extract shared base: classifier helpers, fetch helpers, upsert boilerplate, CLI argparse boilerplate. New `bin/pipeline/_lib/cli_base.py`, `bin/pipeline/_lib/upsert_base.py`. Refactor 3 refresh scripts to import. | Unit: `_lib` modules have direct unit tests; refresh scripts shrink by 200+ lines each. |
| 0169 | Major | `tests/unit/` | Add `test_pipeline_sessionize.py` (covers `sessionize_legs` from refresh_trade_journal — currently 0 coverage). Mock DB fixtures. | This IS the test plan: unit-test `sessionize_legs` first; covers AUD-0169's audit ask. |
| 0176 | Minor | `refresh_order_leg_live.py:55-58` 3 maps | Merge `seed_orders`, `seeded_entry_orders`, `smart_order_positions` into a single typed dataclass `ClassifierState`. | Unit: classifier state round-trips through ClassifierState equivalently. |

**Park (Wave 2B):**
- AUD-0150 (pipeline transactions — Bybit-API-interleaved, see audit text;
  same class as AUD-0140; defer to Wave C if scoped, else stays Confirmed
  pending architectural rework).
- AUD-0159 (refresh_trade_journal.py 3,499-line SRP split — multi-day refactor).

**Pre-flight:** parallel-session check.

**Wave-close:** full pytest (touches money-adjacent pipeline).

---

## Day 3 — API + peripheral close

### Wave 3A — `api/{stops,suspend,batch_ideas,ideas}.py` (Chunk 7 partial)

**Files in scope:** `lib/tradelens/api/stops.py`, `lib/tradelens/api/suspend.py`,
`lib/tradelens/api/batch_ideas.py`, `lib/tradelens/api/ideas.py`, plus tests.
**Cluster commits:** 4 (one per file).
**Effort estimate:** 4h.
**Risk:** low–medium (mostly per-endpoint fixes).

| AUD | Severity | Location | Fix shape | Test plan |
|---|---|---|---|---|
| 0212 | Critical | `stops.py:70` `POST /stops` | `BybitClient()` with no `account_name` crashes at construction. Either (a) pass `AccountContext`-resolved `account_name`, or (b) delete the endpoint if unused. Decision: grep the frontend for `/stops` POST callers; if zero, delete; else fix. | Unit: endpoint with valid account_name round-trips; missing account → 400 with clear message. |
| 0215 | Critical | `suspend.py:892-903` `resume_trade` | Currently logs-and-continues per-order failures, then UPDATE trade_journal SET status='open'. Change: collect per-order results; if any critical failure (no-stop-recreated, no-entry-recreated), surface partial-success in response and DO NOT mark the trade as fully-resumed. | Unit: per-order failure cases — at least one critical failure leaves status != 'open'; response carries explicit `partial: true` + `failed_orders: [...]`. |
| 0216 | Critical | `batch_ideas.py:1467+` `batch_create_ideas` | `async def` with sync `PooledDB` blocks the event loop. Wrap the sync DB section in `asyncio.to_thread(...)`. | Unit: concurrent batch_create_ideas calls don't serialise on a shared lock; event loop responsiveness preserved (smoke test with mock slow-DB). |
| 0219 | Major | `ideas.py:804-819` `list_trade_ideas` | Push LIMIT/OFFSET into SQL when no Python-only sort is requested (gated, same shape as Wave 1's AUD-0116 fix in `journal.py`). | Unit: pagination test — large result set + `limit=10, offset=20` returns exactly 10 rows; SQL query string contains `LIMIT 10 OFFSET 20`. |
| 0224 | Major | `ideas.py` all endpoints | Migrate `PooledDB` pattern to `with get_db_connection()` (matches AUD-0008 / Wave 1 pattern). 30+ endpoint sweep; cluster as one commit. | Unit: endpoint smoke tests (existing) still pass; source-shape guard `with get_db_connection()` count ≥ N. |
| 0225 | Major | `batch_ideas.py:1657-1685` async-cursor-across-await | Close cursor before `await`. Restructure: build the data inside the `with` block, then issue `await` after the block exits. | Unit: cursor lifetime tests; mock async transport ensures cursor is closed before await. |

**Park (Wave 3A):**
- AUD-0227 (auth epic — Wave B kickoff; needs product decision on identity model).
- AUD-0233 (batch_ideas hand-rolled rollback — depends on AUD-0217 transaction wrap).

**Pre-flight:** parallel-session check; grep frontend for `/stops` POST.

**Wave-close:** full pytest.

### Wave 3B — peripheral cluster (Chunk 13)

**Files in scope:** `lib/tradelens/api/system_monitor.py`,
`lib/tradelens/api/trader_scorecard.py`, `lib/tradelens/breach_analysis/`,
`bin/tools/breach_*.py`, `lib/tradelens/core/logging.py`, plus tests.
**Cluster commits:** ~5 (system_monitor; trader_scorecard; breach_analysis tests; breach CLI base; log rotation).
**Effort estimate:** 4h.
**Risk:** low (read-side and tooling).

| AUD | Severity | Location | Fix shape | Test plan |
|---|---|---|---|---|
| 0342 | Critical | `trader_scorecard.py:163-180` recent-trades N+1 | Replace per-trade UPDATE-count + one-liner queries with a single window-function query that joins all needed columns up-front. | Unit: 20-trade scorecard fetch produces 1 query (mocked) instead of 41. |
| 0345 | Major | `bin/tools/breach_*.py` (10 scripts) | Extract shared scaffolding to new `bin/tools/_lib/cli_base.py`: `sys.path` bootstrap, `PostgresDB` connect, argparse common args, logging setup. Refactor each of 10 scripts to import. | Unit: `cli_base` has direct tests; sample script smoke-tests post-refactor. |
| 0346 | Major | `lib/tradelens/breach_analysis/` (1,542 LOC) | Add fixture-based unit tests per FeatureExtractor — at least 1 test per extractor file. Synthetic tick fixtures + golden-output assertions. | Unit: `tests/unit/test_breach_analysis_*.py`. |
| 0350 | Major | `system_monitor.py:283-338` PID TOCTOU | Replace 3 subprocess round-trips with single atomic `/proc/<pid>/status` read. If PID dead between read and status, return null cleanly. | Unit: test fixture with stale PID → null result; live PID → metrics. |
| 0352 | Minor | `system_monitor.py` (528 LOC) | **DEPENDS:** if AUD-0341 + 0343 are still awaiting C-bucket sign-off (they are), DO NOT rewrite system_monitor — would conflict. **Park-with-rationale.** | n/a — parked. |
| 0371 | Major | `lib/tradelens/core/logging.py` (helper) + 8 daemon entry-points | Add `setup_rotating_logger(name)` helper using stdlib `RotatingFileHandler(maxBytes=50_000_000, backupCount=10, encoding='utf-8', delay=True)`. Wire into: alert_engine, mdsync_pg, vwap_order_engine, vwap_series_worker, correlation_worker, telegram_signals, discord_signals, monitor. | Unit: helper produces a RotatingFileHandler with correct config; smoke test that one daemon entry-point invokes it. |

**Park (Wave 3B):**
- AUD-0341 + 0343 (bundled, awaiting C-bucket sign-off — operator decision required).
- AUD-0352 (parked above; depends on 0341 redesign landing).
- AUD-0347 (production/research schema separation — multi-day data-engineering wave).
- AUD-0349 (breach_pipeline orchestrator — requires identifying canonical 6-stage ordering with operator).
- AUD-0358 (4.4% test coverage — meta; partially served by 0169 + 0346).
- AUD-0360 (4 schema sources of truth — multi-day infrastructure refactor).
- AUD-0368 (vwap_series_worker memory leak — investigation-heavy; "stop the worker" workaround active).
- AUD-0370 (mdsync invalid-symbol cleanup — needs watchlist-source identification).
- AUD-0374 (94 prod orphan filled legs — explicitly T3 investigation per audit, "do NOT auto-ship code").

**Pre-flight:** parallel-session check.

**Wave-close:** full pytest, then Day-3 tracker commit covering Wave 3A + 3B.

---

## Day 4–5 — Wave C: Multi-table tx wrap

**Files in scope:** `lib/tradelens/core/db_helpers.py` (new),
`lib/tradelens/api/open_orders.py` (re-export), `lib/tradelens/api/journal.py`
(3 endpoints), plus tests.
**Cluster commits:** 4 (db_helpers lift; cancel-seed; cancel-pending; force-open).
**Effort estimate:** 1.5 days (~12h).
**Risk:** high (user-facing trade-state changes).

### Step 0 — Lift `_atomic_block` to `core/db_helpers.py`

| Action | Detail |
|---|---|
| Create | `lib/tradelens/core/db_helpers.py` with `_atomic_block` (verbatim from `open_orders.py:46-72`). |
| Backward-compat | `open_orders.py` re-exports: `from tradelens.core.db_helpers import _atomic_block`. |
| Tests | Move `tests/unit/test_aud0083_atomic_block.py` to import from the new module location; add a smoke test that imports both spellings. |

### AUD-0140 endpoints (3 cluster commits, one per endpoint)

| Endpoint | Location | API-call boundary | Pre-API tx | Post-API tx |
|---|---|---|---|---|
| cancel-seed | `journal.py:3863-4222` (~9 mutations / 8 tables) | Find the `bybit.cancel_*` call(s) inside the body; split. | DELETE level_guard, DELETE order_leg_live, DELETE vwap_linked_order — all in one `_atomic_block`. | UPDATE trade_journal status, INSERT trade_journal_notes, DELETE pending_position_context, etc. — all in one `_atomic_block`. |
| cancel-pending | `journal.py:4223-4514` (~9 mutations / 8 tables) | Same pattern. | Same shape as cancel-seed. | Same shape. |
| force-open | `journal.py:4515+` (~7 mutations / 4-5 tables) | Same pattern; identify the `bybit.place_order` call. | Pre-API DB writes wrapped. | Post-API DB writes wrapped. |

**Tests for each endpoint:** integration-level. Simulate Bybit-API failure
mid-endpoint; assert pre-API DB state is fully-applied OR fully-rolled-back
(never half); assert post-API DB state is fully-applied OR fully-rolled-back.

**Park (Wave C):**
- AUD-0118 (cross-file trades.py + journal.py + helpers): per its own
  tracker row, requires architectural decision on the helper-conn-passing
  pattern (notes/tags/AI-conv helpers open their own pool conns and won't
  enrol in the caller's tx). Multi-call-site refactor outside this wave's
  scope. STAYS Confirmed pending architectural decision.
- AUD-0218 (resume_trade two-phase commit-or-compensate): needs product
  decision on two-phase shape. Park unchanged.
- AUD-0150 (pipeline transactions): same Bybit-interleaved class; see audit
  text. Defer to a separate pipeline-architecture wave.

**Wave-close:** full pytest, then single tracker commit moving AUD-0140 to
Resolved (and noting the parked items above).

---

## Final tracker housekeeping (Wave C close)

| Section | Update |
|---|---|
| Progress section (top of tracker) | Update Confirmed count: ~98 → ~70 (target). |
| Follow-up waves section | Mark Wave A as Resolved; Wave C as Resolved (AUD-0140 only); update Wave B / D / E status notes. |
| Campaign report | Write `2026-04-30-campaign-2-final.md` (or relevant date) following Campaign 1's structure. |

---

## Verification checklist (run after each wave)

1. `git status` clean on tracked files (untracked agents/checkpoints OK).
2. `git rev-parse --short HEAD` matches expected wave-close SHA.
3. `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1`
   reports green. (Drop `--ignore` if parallel-session orchestrator tests
   are currently green; check first.)
4. `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | grep -c "Confirmed$"`
   matches the running count from the wave's tracker commit.
5. Frontend: `cd tradelens/frontend/web && npm test -- --run` green; if any
   frontend file changed, `npm run build` clean.
6. No new entries in `/app/syb/tradesuite/.claude/worktrees/agent-*` (we are
   not using agent dispatch this campaign).

---

## Out-of-scope items (explicit, agreed Day 1 of Campaign 1, still applicable)

- Wave B (auth epic): needs product decision.
- Wave D (frontend mega-refactors AUD-0308/0309/0310/0311/0314/0319/0330): each multi-week.
- Wave E remainder (AUD-0030, 0316, 0324, 0340, 0352): schedule individually.
- 9 T3 design implementations (AUD-0361 P2+, 0332 P2+, 0002, 0008, 0114, 0115, 0155, 0170, 0171): each 1–3 weeks dedicated.
- AUD-0353 + 0354 (security secret-rotation runbook): operator-only.
- AUD-0218: needs product decision.

---

## Target outcome (Campaign 2 close)

| Metric | Campaign 1 close | Campaign 2 target |
|---|---|---|
| Confirmed AUDs | 98 | ~68–72 (target −26 to −30) |
| Resolved (full) | tracker-dependent | +25–28 |
| Resolved (partial) | tracker-dependent | +1–3 |
| Park-with-rationale rows | tracker-dependent | +5–8 |

If Wave A or Wave C scope creep blocks the campaign close, park aggressively
and document. Better to ship 20 AUDs cleanly than 30 with regressions.

—
Claude Opus 4.7 (1M context), 2026-04-28
