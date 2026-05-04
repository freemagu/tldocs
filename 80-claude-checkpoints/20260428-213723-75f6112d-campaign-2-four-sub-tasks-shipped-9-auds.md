# Checkpoint: Campaign 2 four sub-tasks shipped — 9 AUDs Resolved + 1 partial; ~104 actionable items remain

**Saved:** 2026-04-28 21:37:23 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ 004774a1
**Session:** 75f6112d-08ab-44e9-a783-88ff484cafb0
**Active task:** (none — last `/t-done` closed `20260428-170000-c2d2-waves-2a-2b-backend-clusters` at commit `2dccb8e3`; parallel session has since pushed one more commit on top — see Working environment)

## Handover Statement

You are picking up a **closed and clean intermission** between Campaign 2's Day 2 close and any potential Day 3 work. Three claude-tasks were spun up and closed cleanly this session: Wave A first half (`68d8f235`), Wave A continuation (`0432a656`), and Day 2 Waves 2A + 2B (`2dccb8e3`). All four AUD code commits + four tracker commits + one campaign kickoff commit went green through pytest at 1903/4-skipped at the time of the last full sweep. No active claude-task. No uncommitted tracked files. The single most important piece of state right now: **you are between tasks; do NOT auto-resume Day 3 if the user says "continue" without a target.** The user explicitly removed the "discuss before editing" rule on Day 1 of the prior campaign and authorised "run unattended with sensible gates," but a fresh start requires a new claude-task and a stated target. This session deliberately stopped at "Day 2 done"; Day 3 is a question for the user, not an implicit continuation.

What to read FIRST in order: (1) this checkpoint (you are reading it); (2) `tradelens/AUDIT_TRACKER.md` lines 460-520 for the Wave A entry that shows `CLOSED ✅` (the canonical wrap-then-`_<endpoint>_locked`-helper pattern is documented there as the shape for any future mutation endpoint); (3) `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md` for the campaign's operating contract (this is the dispatch document I produced at session start and committed in `4a7549e5`); (4) the previous-session checkpoint at `/app/syb/tradesuite/.claude/checkpoints/20260428-120925Z.md` for context on how Campaign 2 was framed (it documents Campaign 1's close).

Known landmines: (a) the parallel session is HOT in `breach_decision/`, `level_guard/`, `level_mind/`, `sizing.py`, `state_manager.py` — they pushed five commits between my own commits this session (`d6c7bd23`, `ec47a069`, `a9d814b6`, `d8da4b96`, `004774a1`). Stay clear of those zones. (b) HEAD is currently `004774a1` (parallel-session "Plan 5 holds-mode gate backtest"); my last commit was `2dccb8e3` (Day 2 tracker close). The two are not in conflict — parallel session works in their own breach_decision tree — but a future task that does `git log --oneline 2dccb8e3..HEAD` will see only their work. (c) Three open-orders.py mutation endpoints — `cancel_order`, `convert_to_limit`, `amend_order`, `create_order` — now live as thin AppLock wrappers around `_<endpoint>_locked` helpers (AUD-0081). Any test or new code that does `inspect.getsource(amend_order)` and looks for body content will fail; the body is in `_amend_order_locked`. Five existing test files were updated this session for this; future test-writers must remember the pattern. (d) `get_tick_size` now accepts EITHER a `BybitClient` instance OR an `account_name: str` (AUD-0087 backward-compat shape) — branch-detect via `isinstance(arg, str)`, not `isinstance(arg, BybitClient)`, because test fixtures monkeypatch the class.

What NOT to do: do NOT re-write the campaign plan (it's at the path above and is the operating contract); do NOT touch the parallel-session hot zones; do NOT auto-pick a Day 3 wave without user confirmation; do NOT remove the `contextlib.nullcontext()` shim at `_amend_order_locked`'s former-inner-AppLock site without first reading the AUD-0081 residual commit message (`ac17e4df`) — it explains why the inner lock had to be neutralised rather than removed; do NOT re-litigate the conservative-time-estimate framing that the user pushed back on (see User preferences below). The exact next action depends entirely on what the user asks. There is no implicit "continue" path — Campaign 2 is at a clean stopping point with three days' worth of Resolved AUDs (98 → 89 Confirmed; 249 → 257 Resolved).

## User note

*(The user invoked `/t-checkpoint` without a free-form note.)*

## Session context

### User's stated goal (verbatim where possible)

The session opened immediately after a `/clear` followed by `/t-checkpoint-load`, which loaded the prior-session checkpoint `20260428-120925Z.md`. That prior checkpoint left off at the clean close of Campaign 1's 3-day audit-fix campaign, with Confirmed at 98 and the campaign report shipped. The user's first new instruction was: *"plan for another large campaign to work through the audit fixes list"* — i.e. Campaign 2.

After I produced a candidate plan (3-day main + 1.5-day Wave C tail; 25–30 AUD target), the user locked in six design choices in a single line of replies: *"1. 3 days. 2. Wave A. 3. re-execute fresh. 4. yes. 5. yes. 6. produce the formal per-wave AUD-by-AUD tables then kickoff"*. That meant: 3-day duration, start with Wave A, do not salvage from preserved worktrees, include Wave C, keep tightened gates, and produce the formal dispatch doc before kicking off.

Mid-session the user gave one chained directive after Day 1 Wave A first half closed: *"then do 1. New task → finish Wave A (AUD-0081 + AUD-0082) before moving on."* This explicitly required keeping the focus on Wave A (not jumping to Day 2) until all 4 of its audits were closed.

After the partial AUD-0081 ship (cancel + convert only), the user said *"1. Finish the AUD-0081 residual (amend + create) before leaving Wave A."* — i.e. don't park amend + create, finish them in the same task.

After the Day 2 task (Waves 2A + 2B) closed cleanly, the user asked *"how many issues left to fix?"* and then pushed back on my answer: *"these estimates of days and weeks are ridiculous. You finished a days work in a few minutes. Your estimates are wildly conservative, so much that they are a joke. Give me realistic figures"*. I revised the framing from "human-developer-days" to focused-work hours.

The broader objective across the session: **continue closing the audit-fix backlog at the same pace as Campaign 1 (or faster), bundling related AUDs into clean wave commits, with the wrap-then-helper pattern as the canonical shape for new AppLock work.** The campaign plan I produced at session start is the operating contract; everything since then has been execution against it.

### User preferences and corrections established this session

- **Run unattended with sensible gates; no pre-edit discussion.** Carried forward from prior sessions and reaffirmed implicitly throughout this one — every commit was made without asking permission first. This SUPERSEDES any older "ALWAYS Discuss Before Editing Code" instruction. Memory entry at `/app/syb/.claude/projects/-app-syb-tradesuite/memory/MEMORY.md` under "Run Unattended With Sensible Gates" remains authoritative.

- **Don't project calendar-days onto AUD effort.** Verbatim user pushback: *"these estimates of days and weeks are ridiculous. You finished a days work in a few minutes. Your estimates are wildly conservative, so much that they are a joke."* The fix: bucket remaining AUDs by actual focused-work hours (mechanical / medium / real multi-file refactor / out-of-scope), not by "Day N" calendar labels which were artifacts of the campaign-plan framing. Future communications should give effort estimates in hours with a "...assuming today's pace continues" qualifier, not in days/weeks.

- **Finish what you start within a wave before moving on.** Verbatim user instruction post-Wave-A-partial: *"1. Finish the AUD-0081 residual (amend + create) before leaving Wave A."* The pattern: when a wave has 4 AUDs, ship all 4 (or explicit-park them with rationale) before the next wave starts. Don't half-ship a wave.

- **Park aggressively with rationale, but in the SAME commit boundary as the wave's other items.** The Day 2 Wave 2B narrowing from 6 → 1 AUD was an example: rather than half-ship 6 audits with mixed quality, I shipped only AUD-0169 (clean test addition) and recorded explicit park rationale for the other 5 in the commit message + tracker.

- **Single tracker commit per wave (orchestrator-only).** Carried forward from Campaign 1. The pattern held: each wave gets one tracker-only commit at close that flips the relevant rows. No row-by-row updates inline with code commits.

- **Wrap-then-`_<endpoint>_locked`-helper pattern is canonical for AppLock-on-mutation work.** Established this session via AUD-0081's four-endpoint sweep (cancel + convert + amend + create). The Wave A entry in `AUDIT_TRACKER.md`'s Follow-up section now documents this pattern as the canonical shape for any future mutation endpoint that needs the same treatment. Don't re-invent the pattern; copy-adapt it.

### Working environment

- **Master HEAD:** `004774a1` (`feat(breach-decision): Plan 5 v1 — holds-mode gate backtest (B8 Phase 1)`) — this is parallel-session work, NOT mine. My last commit was `2dccb8e3`.
- **Branch:** `master`. No other branches active in this checkout. `backup/aud-triage-*` refs were deleted at end of Campaign 1's Day 1 (those refs are reflog-only now).
- **No active claude-task.** Last `/t-done` closed `20260428-170000-c2d2-waves-2a-2b-backend-clusters` at `2dccb8e3`.
- **Tracked-files state:** clean. Only untracked items: the AUDIT_TRACKER.md symlink at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` (pre-existing artifact from before this session), plus parallel-session WIP files that I have NEVER touched: `tradelens/bin/holds-mode-backtest`, `tradelens/bin/show/show_holds_mode_backtest.py`, `tradelens/lib/tradelens/breach_decision/holds_backtest/`, `tradelens/tests/unit/test_holds_backtest_level_outcome.py`. These are part of the parallel session's Plan 5 work and should be left alone.
- **Five parallel-session commits interleaved with my own commits this session:** `d6c7bd23` (breach-decision glossary + B7 rename), `ec47a069` (gitignore Claude artefacts), `a9d814b6` (Plan 3 sidecar health watchdog), `d8da4b96` (Plan 4 retrain trigger), `004774a1` (Plan 5 holds-mode backtest). All in their own breach_decision tree — no merge conflicts with my open_orders.py work.
- **Campaign 1's 9 preserved stale worktrees still on disk** under `/app/syb/tradesuite/.claude/worktrees/agent-*`. User explicitly chose "park all" Campaign 1; user explicitly chose "re-execute fresh" Campaign 2. NOT touched this session. The previous-session checkpoint at `20260428-120925Z.md` lists each one's contents; if Day 3 needs to revisit any (e.g. AUD-0089 work in `agent-a8046d87976e802d9` that I redid fresh this session), the inventory is there.
- **No background processes I started.** This was a pure code-edit session.
- **Pytest baseline at session end:** `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1` reported `1903 passed, 4 skipped, 9 warnings in 80.99s` at the time of the Day 2 final sweep.

## Objective

The user's stated objective: **plan and execute Campaign 2 to continue working through the audit-fix list**. The surface ask was a single-line "plan for another large campaign to work through the audit fixes list"; the underlying motivation is to keep reducing the Confirmed-AUD count (which started this session at 98 post-Campaign-1) toward zero. The Campaign 1 final report at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-3day-campaign-final.md` and the Wave A entry in `tradelens/AUDIT_TRACKER.md` (now `CLOSED ✅`) are the authoritative records of where each AUD stands.

The campaign's IN-scope work for this session was: Wave A (AUD-0079, 0081, 0082, 0083 LevelGuard CREATE remainder), Day 2 Waves 2A (Chunk 3 open_orders.py remainder) + 2B (pipeline cluster). Across the three task boundaries, this session shipped 5 audits as full Resolved, 1 as Resolved (partial), and explicitly parked 13 with rationale. Wave C (multi-table tx wrap), Day 3 Waves 3A + 3B, Wave B (auth epic), Wave D (frontend mega-refactors), Wave E (tech debt) are explicitly NOT in scope for this session — they're future-day candidates.

The user's pace expectation, established late in the session via the time-estimate pushback: **fast.** "A days work in a few minutes" was their characterisation. Future work should follow the same edit→test→commit cadence, with no calendar-day estimates.

## Narrative: how we got here

The session opened with `/clear` followed by `/t-checkpoint-load`, which pulled in the prior-session checkpoint `20260428-120925Z.md`. That checkpoint had documented Campaign 1's clean close (Confirmed 128 → 98, full campaign report shipped, follow-up section added to `AUDIT_TRACKER.md`). I ran the verification checklist from that checkpoint — all 10 items passed (HEAD `b13bb2d0`, no modified tracked files, claude-task empty, Confirmed count 98, no backup refs, 9 preserved worktrees, tracker tail "*End of tracker*", final report file present, 1 Follow-up section). Pytest was not re-run since the prior checkpoint had documented it green at 1849/4-skipped.

The user's first instruction was a single-line "plan for another large campaign to work through the audit fixes list". I surveyed the 98 remaining Confirmed audits (severity breakdown: ~17 Critical, mostly Major, some Minor), the Follow-up section's 5 already-bundled waves (A AppLock+orderLinkId, B Auth epic, C multi-table tx, D frontend mega-refactors, E tech debt), the campaign final report's lessons learned, and the parallel-session hot-zone exclusion list. I then produced a candidate 3-day plan with five waves (1A, 2A/B, 3A/B, plus Wave C as a 1.5-day tail) and surfaced six open decisions for the user.

The user replied with all six answers in one line: 3 days, Wave A, re-execute fresh, include Wave C, keep tightened gates, produce the formal per-wave dispatch tables then kickoff. The combination "3 days" + "yes to Wave C +1.5 day tail" was technically a 4.5-day plan; I surfaced the resolution explicitly and proceeded.

I produced the formal dispatch document at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md` (308 lines covering the architecture rules, hot-zone exclusions, six waves' pre-dispatch tables with file/function/fix-shape/test-plan/park-rationale per AUD). Then I started the first claude-task (`20260428-150000-c2d1-wave-a-applock-orderlinkid`) and shipped Day 0 housekeeping: AUD-0077 had been fixed by the parallel session at `068f199b` but the tracker still showed Confirmed — I flipped it to Resolved as the campaign's first commit (`4a7549e5`).

Wave A's first half (AUD-0079 + AUD-0083 LG CREATE remainder) was straightforward. AUD-0079 needed a new `BybitClient.cancel_batch_orders` method (chunked at Bybit's documented 10/call limit) plus a `bulk_cancel_orders` rewrite that classifies orders into LevelGuard-local / conditional-TP-per-order / simple-batchable buckets and runs ONE refresh per affected symbol at end of batch. AUD-0083 LG CREATE needed `_atomic_block` applied to the LevelGuard CREATE path in `create_order` — same shape as the Campaign 1 amend→guard wrap that already existed, with the inner level_guard log-warning swallow removed. Tests: 17 cases for AUD-0079 + 4 added to the existing AUD-0083 test file. One regression in `test_aud0078_bg_refresh.py` because the `_FakeCursor` only had `fetchone` and my new bulk SELECT used `fetchall`; I extended the fake. Final pytest: 1829/4-skipped. Commit `51f02b6e` for code, `68d8f235` for tracker. `/t-done` closed Task 1.

The user's chained directive "then do 1. New task → finish Wave A (AUD-0081 + AUD-0082) before moving on" started Task 2 (`20260428-160000-c2d1-wave-a-continuation-applock-orderlinkid`). I shipped AUD-0082 first (orderLinkId pre-generation at 4 placement callsites + persistence into `order_leg_live.order_link_id` — `BybitClient`'s adapter already auto-generated, the gap was threading `trade_id` + `leg_kind` + persistence). Tests: 9 source-shape cases. Commit `b8674f35`.

AUD-0081 was the bigger problem. The audit asked for AppLock on every mutation path — cancel, amend, convert, create. The first three have a per-leg lock_key (`f'leg-{request.order_id}'`); create has no pre-existing leg_id. I shipped cancel + convert first via the wrap-then-`_<endpoint>_locked`-helper pattern (commit `829f2405`) and considered parking amend + create. The commit's tracker close (`a7a32726`) flipped AUD-0081 to Resolved (partial). Then the user said "1. Finish the AUD-0081 residual (amend + create) before leaving Wave A", so I went back and shipped them: amend with the same per-leg lock_key, with the existing inner AppLock at the disable-LG subpath replaced with `contextlib.nullcontext()` to preserve the ~600-line indented body without rewrite (the inner lock had the same key as the outer wrap and would have deadlocked on PostgreSQL PK conflict). Create used a composite lock_key `f'create-trade-{trade_id}-{order_type}-{order_kind}'` — that prevents same-button double-click duplicates without serialising legitimate concurrent multi-leg setup. Commit `ac17e4df`. The body extractions broke 9 source-inspection tests across 4 files (every test that did `inspect.getsource(amend_order)` or `_extract_function(src, "create_order")`); I retargeted them all to `_amend_order_locked` / `_create_order_locked`. Final pytest: 1854/4-skipped. Commit `0432a656` flipped AUD-0081 to full Resolved and marked the Wave A Follow-up entry CLOSED ✅. `/t-done` closed Task 2.

The user said "Day 2 Wave 2A and 2b". Started Task 3 (`20260428-170000-c2d2-waves-2a-2b-backend-clusters`). Wave 2A was scoped down from 8 to 4 AUDs (0087, 0089, 0091, 0092) after schema verification showed `reduce_only` is still `varchar(5)` — AUD-0100 needs a real schema migration not a single-AUD ship — and after evaluating that AUD-0093/0095/0098 were each multi-callsite refactors too broad for one batch. AUD-0087 changed `get_tick_size`'s signature to accept either `BybitClient` or `account_name: str` (with `isinstance(arg, str)` branching, not `isinstance(arg, BybitClient)` — the latter would break test fixtures that mock the class). AUD-0089 made `calc_trigger_direction` deterministic from `(side, leg_type)` with loss/profit-side frozensets exported as module-level constants. AUD-0091 broadened `check_existing_stop`'s SQL to match `leg_type IN ('stop', 'tl', 'trailing_tl')` OR `qty >= running_qty`. AUD-0092 added a `logger.info` at the auto-classification site (visibility-only fix; full structural fix needs frontend `leg_type` field — Resolved partial). Three regressions from the signature changes: `test_aud0078_option_b_inline_insert.py` fixture row needed extending from 2-tuple to 3-tuple (added `running_qty`); `test_amend_order_single_bybit_client.py` monkeypatched `calc_trigger_direction` lambda needed `**kwargs`. Commit `c8569cee`.

Wave 2B was scoped down from 6 to 1 (AUD-0169 only — sessionize_legs unit-test scaffold). The other 5 each needed bigger architecture decisions: AUD-0167's headline win is "persistent daemon" not pool-reuse; AUD-0168 is a multi-file refactor; AUD-0176 had ambiguous scope between TypedDict and full merge; AUD-0154/0166 are pipeline-perf wave candidates. AUD-0169 was a clean pure-test addition: 10 unit tests using a `_make_leg(...)` factory to construct synthetic `TradeLeg` objects. Commit `4f39627d`. Tracker close `2dccb8e3` flipped 5 rows. Final pytest: 1903/4-skipped. `/t-done` closed Task 3.

The user asked "how many issues left to fix?" — I gave a status-bucketed answer (89 Confirmed + 15 Resolved-partial + 9 T3 designs + 1 Suspicious + 2 Runbook + 1 Parked = 117 open) and made the mistake of estimating "10 more campaign-days" in calendar time. The user pushed back hard: *"these estimates of days and weeks are ridiculous. You finished a days work in a few minutes."* I revised to focused-work-hour buckets: ~30 mechanical AUDs at ~6 hours, ~25 medium at ~8 hours, ~25 real multi-file refactors at "several days" (legitimate this time), ~15 out-of-scope (T3/auth/runbook). Headline: ~55 actionable AUDs in 2-3 more sessions of similar pace. The user ran `/t-done` on Task 3 (already closed) and now `/t-checkpoint`.

## Work done so far

1. **Loaded the prior-session checkpoint and verified state.** Read `20260428-120925Z.md` (the Campaign 1 close checkpoint) in full and ran its verification checklist. All 10 items passed. **State:** read-only.

2. **Surveyed the audit backlog.** Ran `awk` over `tradelens/AUDIT_TRACKER.md` to count Confirmed AUDs by chunk and severity (98 Confirmed at start; 17 Critical, mostly Major). Reviewed the Follow-up section's 5 already-bundled waves. Reviewed the campaign final report's lessons learned. **State:** investigation-only.

3. **Produced the Campaign 2 dispatch document.** Wrote `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md` (308 lines). Sections: architecture rules carried forward from Campaign 1, hot-zone exclusion list, tracker housekeeping for AUD-0077, six waves' pre-dispatch tables (A, 2A, 2B, 3A, 3B, C) with per-AUD file/function/fix-shape/test-plan/park-rationale, verification checklist, out-of-scope list, target outcome metrics. **State:** committed in `4a7549e5`.

4. **Day 0 housekeeping: flipped AUD-0077 from Confirmed to Resolved in the tracker.** Parallel session had shipped the fix at `068f199b` (sizing.py public-boundary Numeric type) but the tracker row was stale. **State:** committed in `4a7549e5`.

5. **Started claude-task `20260428-150000-c2d1-wave-a-applock-orderlinkid`.** Shipped Wave A first half:
   - **AUD-0079** at `tradelens/lib/tradelens/adapters/bybit_client.py` — added `cancel_batch_orders(category, orders)` method + `CANCEL_BATCH_LIMIT = 10` constant. Calls `/v5/order/cancel-batch` chunked at Bybit's documented 10-orders-per-call limit. Empty input short-circuits; missing `symbol` / `orderId`+`orderLinkId` raise `ValueError`; unsupported category raises.
   - **AUD-0079** at `tradelens/lib/tradelens/api/open_orders.py:~736-936 (cancel_order)` and `:~990-1230 (bulk_cancel_orders)` — added `_defer_refresh: bool = False` parameter to `cancel_order` so bulk callers can suppress the per-order refresh trigger. Rewrote `bulk_cancel_orders` with single bulk SELECT (`WHERE id = ANY(%s)`), classification into LevelGuard-local / conditional-TP / simple-batchable buckets, batch dispatch via `cancel_batch_orders` for the simple bucket with per-order fallback on whole-batch failure, ONE refresh per affected (symbol, account_name) pair at end-of-batch.
   - **AUD-0083 LevelGuard CREATE remainder** at `tradelens/lib/tradelens/api/open_orders.py:~4500-4580 (create_order LevelGuard CREATE path)` — applied `_atomic_block(conn)` to the order_leg_live + level_guard INSERTs; removed the inner level_guard log-warning swallow; rollback returns `CreateOrderResponse(success=False, ...)` with sanitised message. The `vwap_linked_order` INSERT remains intentionally OUTSIDE the block.
   - **Tests:** new `tests/unit/test_aud0079_cancel_batch.py` (17 cases); 4 cases added to `tests/unit/test_aud0083_atomic_block.py`; updated `tests/integration/test_aud0078_bg_refresh.py` `_FakeCursor` to support `fetchall()` with the new SELECT shape (added `id` as the first column of the row tuple).
   - **State:** committed `51f02b6e` (code) + `68d8f235` (tracker close: AUD-0079 Confirmed → Resolved, AUD-0083 Resolved-partial → Resolved). `/t-done` closed Task 1.

6. **Started claude-task `20260428-160000-c2d1-wave-a-continuation-applock-orderlinkid`** for Wave A continuation:
   - **AUD-0082** at `tradelens/lib/tradelens/api/open_orders.py:18 (import)` and 4 placement callsites (~2146 amend disable-LG, ~3179 convert_to_limit, ~4675 create_order conditional, ~4691 create_order market/limit) — pre-generate `orderLinkId` via `_generate_order_link_id(trade_id, leg_kind)`, pass to `place_order` / `place_conditional_order` explicitly, log alongside placement, persist in corresponding INSERT/UPDATE site (UPDATE for amend disable-LG, INSERT for convert + create option-B). LevelGuard CREATE path skipped (LG orders use `LG-{uuid}` synthetic IDs and never hit Bybit place_order).
   - **AUD-0081 (cancel + convert)** at `cancel_order` (line ~736) and `convert_to_limit` (line ~3025) — wrapped each in `AppLock(namespace='order-mutation', lock_key=f'leg-{request.order_id}', ttl_seconds=30, wait_seconds=2, role='cancel'|'convert-to-limit')`. Body extracted to `_cancel_order_locked` / `_convert_to_limit_locked`. 409 on `LockAcquireError`.
   - **Tests:** new `tests/unit/test_aud0082_order_link_id_persistence.py` (9 cases); new `tests/unit/test_aud0081_applock_mutations.py` (initial 9 cases for cancel + convert).
   - **Test relocations** (necessitated by body extraction): updated 4 existing test files to inspect `_cancel_order_locked` / `_convert_to_limit_locked` instead of the public functions: `test_aud0078_bg_refresh.py`, `test_aud0079_cancel_batch.py`, `test_aud0082_order_link_id_persistence.py`, `test_aud0101_0103_decimal_compare.py`.
   - **State (mid-task):** committed `b8674f35` (AUD-0082) + `829f2405` (AUD-0081 partial: cancel + convert) + `a7a32726` (tracker close: AUD-0082 Resolved, AUD-0081 Resolved-partial).

7. **AUD-0081 residual ship after user instruction "Finish the AUD-0081 residual (amend + create) before leaving Wave A":**
   - **`amend_order`** (line ~1552) — wrapped in `AppLock` with same per-leg lock_key, role='amend'. Body extracted to `_amend_order_locked`. The pre-existing inner `AppLock(role='guard-disable', wait_seconds=5)` at line ~2075 was REPLACED with `with contextlib.nullcontext():` to preserve the ~600-line indented body of the disable-LG subpath without rewrite — leaving the inner AppLock would have deadlocked against the outer (same lock_key acquired twice by the same process → PostgreSQL PK conflict). The re-read-under-lock pattern below the former inner lock remains as a cheap defensive extra DB read (semantically redundant once the outer lock is held but harmless).
   - **`create_order`** (line ~4259) — wrapped in `AppLock` with composite lock_key `f'create-trade-{request.trade_id}-{request.order_type}-{request.order_kind}'`, role='create'. Body extracted to `_create_order_locked`. Concurrency profile: same Create button double-clicked → both compute the same lock_key → contention → 409 on second; different Create operations on the same trade (entry+SL+TP) → different (order_type, order_kind) tuples → different keys → all proceed concurrently.
   - **Tests:** extended `test_aud0081_applock_mutations.py` to 16 cases total (added 7 for amend + create wraps). Test relocations: updated 5 source-inspection tests across 4 files to inspect `_amend_order_locked` / `_create_order_locked` (`test_aud0078_bg_refresh.py`, `test_aud0079_cancel_batch.py`, `test_aud0082_order_link_id_persistence.py`, `test_aud0083_atomic_block.py`, `test_aud0101_0103_decimal_compare.py`).
   - **State:** committed `ac17e4df` (code) + `0432a656` (tracker: AUD-0081 promoted to Resolved + Wave A Follow-up entry flipped to CLOSED ✅). `/t-done` closed Task 2.

8. **Started claude-task `20260428-170000-c2d2-waves-2a-2b-backend-clusters`** for Day 2:
   - **AUD-0087** at `tradelens/lib/tradelens/api/open_orders.py:3982 (get_tick_size)` — signature changed to `get_tick_size(bybit_or_name, category, symbol)`. Branches via `isinstance(bybit_or_name, str)` (str triggers legacy construct-a-short-lived-client path; anything else is treated as a caller-owned live client). `owns_client` flag drives the cleanup. All 8 existing callers continue to work via the legacy str path.
   - **AUD-0089** at `tradelens/lib/tradelens/api/open_orders.py:3987 (calc_trigger_direction)` — added `side` and `leg_type` keyword-only kwargs. When provided, computes direction deterministically from position semantics via two module-level frozensets `_LOSS_SIDE_LEG_TYPES = {stop, tl, trailing_tl}` and `_PROFIT_SIDE_LEG_TYPES = {tp, be, trailing_tp, trailing_be}`. When kwargs missing or leg_type unclassified (entry/dca), falls back to the legacy `current_price > trigger_price` comparison. All 3 internal callsites updated to pass side+leg_type (~2225 amend disable-LG, ~4346 create_order conditional bybit_params, ~4951 create_order non-LG conditional placement).
   - **AUD-0091** at `tradelens/lib/tradelens/api/open_orders.py:3786 (check_existing_stop)` — broadened to read `running_qty` from `trade_journal` in addition to symbol+side, and broadened the SQL match clause to `leg_type IN ('stop', 'tl', 'trailing_tl') OR (qty IS NOT NULL AND qty >= running_qty AND running_qty > 0)`. Function signature unchanged.
   - **AUD-0092** at `tradelens/lib/tradelens/api/open_orders.py:3708-area (determine_leg_type auto-relabel)` — added `logger.info` capturing all input fragments when the auto-classification fires. Visibility-only fix; full structural fix (require explicit leg_type from caller) is parked because it needs a frontend `leg_type` field on `CreateOrderRequest`. Marked Resolved (partial) in the tracker.
   - **Tests:** new `tests/unit/test_aud0087_0089_0091_0092_wave_2a.py` (28 cases — 16 parametrized direction checks, 4 fallback cases, source-shape guards, caplog-driven log-emission test).
   - **Test fixture updates** required by the signature changes: `tests/unit/test_amend_order_single_bybit_client.py` (monkeypatched `calc_trigger_direction` lambda gained `**kwargs`); `tests/integration/test_aud0078_option_b_inline_insert.py` (`existing_stop_trade_row` fixture extended from 2-tuple to 3-tuple to match the new running_qty SELECT).
   - **State:** committed `c8569cee`.

9. **Day 2 Wave 2B narrowed to AUD-0169 only:**
   - **AUD-0169** new file `tradelens/tests/unit/test_aud0169_sessionize_legs.py` — first ever unit-test scaffold for any pipeline script. 10 cases on synthetic `TradeLeg` objects via a `_make_leg(...)` factory that builds row dicts. State machine: empty input, single hist entry, entry+full-TP closure, two full round-trips (split into 2 sessions), live-leg attachment to most recent open session. Stream classification: orphan exit dropped, separate symbols → separate sessions, hedge-mode long+short → 2 sessions via position_idx. Source-shape guards: public signature kwargs pinned, `normalize_side` helper public-surface availability.
   - The other 5 audits in Wave 2B's original scope (0154 batch upsert, 0166 batch archive, 0167 pool reuse, 0168 shared `bin/pipeline/_lib/` base, 0176 typed dataclass) all parked-with-rationale in the commit message + tracker rows.
   - **State:** committed `4f39627d`.

10. **Day 2 tracker close:** flipped 5 AUD rows in `tradelens/AUDIT_TRACKER.md` (0087 + 0089 + 0091 + 0169 → Resolved; 0092 → Resolved partial). Wave A Follow-up entry left as CLOSED ✅ from the prior task. **State:** committed `2dccb8e3`. `/t-done` closed Task 3.

11. **User asked "how many issues left to fix?"** I produced a status-bucketed answer (89 Confirmed + 15 Resolved-partial + 9 T3 designs + 1 Suspicious + 2 Runbook + 1 Parked = 117 open) with severity sub-counts. Initial answer estimated remaining work in calendar-days (10+ campaign days for the Confirmed pool, multi-week for T3 + Wave D). User pushed back. I revised to focused-work hours: ~30 mechanical AUDs at ~6 hours; ~25 medium at ~8 hours; ~25 real multi-file refactors at "several actual days" (legitimate this time, e.g. a 6.7k LOC frontend file split is genuinely 1-2 days each); ~15 out-of-scope (T3/auth/runbook). Headline: ~55 actionable AUDs in 2-3 more sessions of similar pace. **State:** conversational only, no code change. The User-preferences section above captures the "don't project calendar-days onto AUDs" rule for future application.

12. **Five claude-task records closed in the system.** Task 1 (`...c2d1-wave-a-applock-orderlinkid`) at `68d8f23`; Task 2 (`...c2d1-wave-a-continuation-applock-orderlinkid`) at `0432a65`; Task 3 (`...c2d2-waves-2a-2b-backend-clusters`) at `2dccb8e`. Context files written for each at `/app/syb/.claude/tasks/context/`.

## Decisions made (and why)

1. **Decision:** Direct main-session editing for all task work — no `Agent`-tool dispatch.
   **Proposed by:** Carried forward from Campaign 1's lessons learned.
   **Rationale:** Campaign 1's 6-agent parallel dispatch hit Anthropic per-day usage limits with 0/6 useful output. Direct main-session edits are faster per-AUD because there's no agent context-loading overhead, and they eliminate cherry-pick conflicts entirely.
   **Alternatives considered:** (a) Try agent dispatch again with smaller batches — rejected: same context-load issue. (b) Sequential agent dispatch with feedback loop — rejected: still incurs per-agent overhead. (c) Direct edits — chosen.
   **Revisit if:** Anthropic raises quotas significantly AND a future task is genuinely parallel (20+ independent ≥30-min sub-tasks).
   **Affects:** Every code commit this session.

2. **Decision:** Use the wrap-then-`_<endpoint>_locked`-helper pattern for AppLock-on-mutation work (AUD-0081).
   **Proposed by:** Claude (after considering the indent-shift alternative).
   **Rationale:** `cancel_order` body is ~170 lines, `convert_to_limit` ~480, `amend_order` ~1200, `create_order` ~520. Indenting any of these under `with AppLock(...):` would produce massive diffs. The thin-wrapper pattern keeps each endpoint's diff focused on the wrap addition + minimal rename. Trade-off: source-inspection tests need to point to the helpers — paid that cost as a one-time test-relocation sweep across 5 test files.
   **Alternatives considered:** (a) Indent body 4 spaces under `with AppLock(...):` — rejected: 1200-line diffs are unreviewable. (b) Manual `try/finally` with `acquire()`/`release()` — rejected: adds duplicated cleanup paths. (c) FastAPI decorator `@_with_order_mutation_lock(...)` — rejected: signature-introspection complexity with `*args, **kwargs`. (d) Wrap-then-helper — chosen.
   **Revisit if:** Adding a 5th mutation endpoint that doesn't fit the pattern. The Wave A Follow-up entry now documents this pattern as canonical.
   **Affects:** All four mutation endpoints in `open_orders.py`; 5 test files retargeted to inspect the helpers.

3. **Decision:** Replace amend_order's inner AppLock with `contextlib.nullcontext()` rather than removing or re-keying it.
   **Proposed by:** Claude (after considering 4 alternatives).
   **Rationale:** The inner AppLock at the disable-LG subpath used the same lock_key (`f'leg-{request.order_id}'`) as the new outer wrap. Same key acquired twice by the same process → PostgreSQL PK conflict on the `app_lock` row → `LockAcquireError` → 409 on legitimate disable-LG calls. Replacing with `contextlib.nullcontext()` preserves the ~600-line indented body of the disable-LG subpath without a rewrite. The re-read-under-lock pattern remains as a cheap defensive extra read.
   **Alternatives considered:** (a) Remove the inner AppLock + re-indent ~600 lines — rejected: massive diff. (b) Change inner lock_key to `f'leg-{request.order_id}-disable-inner'` — rejected: defense-in-depth that's effectively a no-op (unique key, never contended). (c) Use `if True:` for indent preservation — rejected: less explicit than nullcontext.
   **Revisit if:** A future audit revisits the disable-LG re-read pattern OR if the AppLock implementation changes its same-key-same-process semantics.
   **Affects:** `_amend_order_locked` body at the former-inner-AppLock site; `test_aud0081_applock_mutations.py::test_aud0081_amend_order_inner_app_lock_replaced_with_nullcontext` is the source-shape tripwire.

4. **Decision:** `create_order`'s AppLock lock_key uses (trade_id, order_type, order_kind), not a per-trade-only key.
   **Proposed by:** Claude.
   **Rationale:** `create_order` has no pre-existing leg_id when the endpoint fires, so `f'leg-{leg_id}'` doesn't apply. A per-trade-only key would over-serialise multi-leg setup (user can't fire entry+SL+TP concurrently). The composite key prevents same-button double-clicks (same (order_type, order_kind) tuple → same key → contention) while allowing concurrent legitimate multi-leg setup (different tuples → different keys → no collision).
   **Alternatives considered:** (a) `f'create-trade-{trade_id}'` — rejected: over-serialises. (b) `f'create-{account_id}-{symbol}-{leg_type}'` — rejected: requires computing leg_type before lock acquisition. (c) (trade_id, order_type, order_kind) tuple — chosen: derives only from request fields available at entry.
   **Revisit if:** Frontend ever adds an explicit `leg_type` field to `CreateOrderRequest` — at that point a per-(trade, leg_type) key becomes feasible.
   **Affects:** `create_order` wrapper at `open_orders.py:~4259`.

5. **Decision:** AUD-0087's `get_tick_size` branch uses `isinstance(arg, str)`, NOT `isinstance(arg, BybitClient)`.
   **Proposed by:** Claude (after the first pytest run failed).
   **Rationale:** Several test fixtures (e.g. `test_aud0106_raise_on_unknown_instrument.py`) monkeypatch `BybitClient` itself with a mock. `isinstance(arg, BybitClient)` then raises `TypeError: isinstance() arg 2 must be a type` because the patched class is no longer a type. The str-vs-not split is robust to that pattern: anything that's not a string is treated as a live client.
   **Alternatives considered:** (a) `isinstance(arg, BybitClient)` — rejected: tests broke. (b) Duck-typing via `hasattr(arg, 'get_instrument_info')` — rejected: less explicit. (c) `isinstance(arg, str)` — chosen.
   **Revisit if:** A caller passes neither a str nor a BybitClient (defensive — currently no such caller).
   **Affects:** `get_tick_size` at `open_orders.py:~4106`; `test_aud0087_get_tick_size_source_branches_on_str_check` is the tripwire.

6. **Decision:** Wave 2B narrowed from 6 audits to 1 (AUD-0169 only).
   **Proposed by:** Claude.
   **Rationale:** AUD-0167's headline win is "persistent daemon" architecture, not pool-reuse — out of single-AUD scope. AUD-0168 is a multi-file refactor extracting CLI/classifier/upsert boilerplate from 3 scripts — own commit boundary. AUD-0176 has ambiguous scope between TypedDict annotation and full merge. AUD-0154/0166 are pipeline-perf wave candidates. Shipping only AUD-0169 (clean test-only addition with zero code-change risk and high coverage value — was 0% pipeline-script coverage) was the responsible scope.
   **Alternatives considered:** (a) Ship all 6 with mixed quality — rejected: violates "park aggressively" principle. (b) Park all 6 — rejected: test coverage win was achievable. (c) AUD-0169 only — chosen.
   **Revisit if:** A dedicated pipeline-architecture wave picks up the parked items.
   **Affects:** Wave 2B's tracker rows; the 5 parked items remain Confirmed.

7. **Decision:** AUD-0092 is Resolved (partial), not Resolved.
   **Proposed by:** Claude.
   **Rationale:** The audit's stated fix is "require explicit leg_type from caller". The full structural fix needs a frontend change to add a `leg_type` field to `CreateOrderRequest`. The visibility-only fix (logger.info at the auto-classification site) delivers half of the audit's intent ("caller intent visible"); the structural half is a frontend-coordination follow-up. Marking Resolved (partial) is honest accounting.
   **Alternatives considered:** (a) Mark Resolved — rejected: overclaims. (b) Don't ship anything — rejected: visibility win is real. (c) Resolved partial — chosen.
   **Revisit if:** Frontend ships a `leg_type` field; the structural half can then ship.
   **Affects:** AUD-0092 tracker row.

8. **Decision:** Single tracker commit per wave, after all code commits in the wave land.
   **Proposed by:** Carried forward from Campaign 1.
   **Rationale:** Keeps `AUDIT_TRACKER.md` history coherent (one commit = one wave's status changes) and avoids merge conflicts on the tracker file from concurrent agent runs. Pattern held throughout this session: Wave A first half = 1 cluster + 1 tracker; Wave A continuation = 3 commits + 1 tracker; Day 2 = 2 clusters + 1 tracker.
   **Affects:** Every wave's commit shape this session.

## Rejected approaches (and why)

1. **Approach:** Re-attempt the 6-agent parallel `Agent`-tool dispatch from Campaign 1.
   **Who proposed it:** Considered briefly at session start.
   **Why rejected:** Campaign 1 proved this pattern hits Anthropic per-day usage limits with 0/6 useful output. Direct main-session edits are faster AND more controlled.
   **Would we reconsider if:** Anthropic raises quotas significantly AND work is genuinely parallel.

2. **Approach:** Salvage Campaign 1's preserved stale worktrees for AUDs that overlap Wave 2A's scope.
   **Who proposed it:** Mentioned at planning time as Decision Q3 ("Salvage from preserved worktrees?").
   **Why rejected:** User explicitly chose "re-execute fresh". The 3 unshipped worktrees (`agent-a8046d87976e802d9` AUD-0089, `agent-ac4b5b31f18522d07` AUD-0087, `agent-a4ea7068c7d953296` AUD-0120) had partial work that would have required rebase + cherry-pick + conflict resolution. Fresh execution was cleaner.
   **Would we reconsider if:** Never for AUDs already shipped fresh; the unshipped AUD-0120 (calculate_quantity) might still salvage from `agent-a4ea7068c7d953296` if a future Wave E picks it up.

3. **Approach:** Indent the body of each mutation endpoint under `with AppLock(...):` for AUD-0081.
   **Who proposed it:** Claude (considered first).
   **Why rejected:** 1200-line diffs are unreviewable. The wrap-then-helper pattern is cleaner.
   **Would we reconsider if:** Never. The pattern is now canonical and documented.

4. **Approach:** Remove `amend_order`'s inner AppLock entirely and re-indent ~600 lines of disable-LG body.
   **Who proposed it:** Claude (considered as cleanup).
   **Why rejected:** Massive mechanical diff. `contextlib.nullcontext()` preserves the indentation while making the no-op explicit.
   **Would we reconsider if:** A future cleanup wave specifically targets indentation-debt removal.

5. **Approach:** Ship AUD-0093 (in-process refresh, replacing subprocess invocation of refresh scripts) in Wave 2A.
   **Who proposed it:** Mentioned in original Wave 2A scope (8 AUDs).
   **Why rejected:** Pipeline scripts (`bin/pipeline/refresh_*.py`) may have global state and side effects on import. Importing them into the FastAPI process means their import-time work happens at every API startup. Needs careful design re. lazy import + side-effect isolation. Out of single-AUD scope.
   **Would we reconsider if:** A dedicated pipeline-as-library wave that establishes the import-safety contract.

6. **Approach:** Ship AUD-0095 (`calculate_quantity` qty=0 sentinel) in Wave 2A.
   **Who proposed it:** Mentioned in original Wave 2A scope.
   **Why rejected:** Multi-callsite signature refactor. `calculate_quantity` returns '0' for `qty_mode='entire'`; callers special-case '0' for amend (which doesn't accept qty=0). Replacing with explicit `close_entire: bool` requires updating ALL callers. Too broad for one batch.
   **Would we reconsider if:** A dedicated calculate_quantity refactor wave; the helper code is at `open_orders.py:3838-area`.

7. **Approach:** Ship AUD-0098 (VWAP local-DB-primary writer) in Wave 2A.
   **Who proposed it:** Mentioned in original Wave 2A scope.
   **Why rejected:** Risky multi-step rework of the post-place_order DB stamp pattern. Currently the subprocess refresh is the primary writer; making local DB primary requires writing BEFORE the network call (with rollback on network failure). Architecturally similar to Wave C's atomic-block work but for a different code path.
   **Would we reconsider if:** A dedicated pipeline-DB-primary-writer wave that addresses both AUD-0098 and AUD-0150.

8. **Approach:** Ship AUD-0100 (`reduce_only` schema migration to boolean) in Wave 2A.
   **Who proposed it:** Mentioned in original Wave 2A scope.
   **Why rejected:** Verified via `grep -n "reduce_only" tradelens/etc/schema.md`: column is `varchar(5) NULL` on `order_leg_live` (line 859), `order_leg_hist` (line 801), and a third table at line 736. Migration to boolean requires: new migration file in `tradelens/migrations/`, update to `setup_database_pg.py`, data migration for existing string values, code updates at all read sites that currently do `.lower() in ('true', 'yes', '1')`. Out of single-AUD scope.
   **Would we reconsider if:** A dedicated schema-migration wave bundles this with similar string-as-boolean migrations.

9. **Approach:** Hardcode the AUD-0089 callsite at line 4346 to compute trigger_direction inline rather than pass side+leg_type to the helper.
   **Who proposed it:** Claude (briefly).
   **Why rejected:** The helper now has the deterministic computation logic; duplicating it inline would split the source of truth.
   **Would we reconsider if:** Never.

10. **Approach:** Use a Python decorator `@_with_order_mutation_lock(...)` for the AppLock wrapping.
    **Who proposed it:** Claude (briefly).
    **Why rejected:** FastAPI introspects function signatures via `inspect.signature` for parameter parsing. A `*args, **kwargs` wrapper would shadow the signature unless `functools.wraps` carefully preserves it. Even with `functools.wraps`, the introspection edge cases are subtle (e.g. follows `__wrapped__` since Python 3.4 but FastAPI's behaviour with deeply-wrapped routes is empirically less reliable than direct functions). Wrap-then-helper is more explicit and FastAPI-safe.
    **Would we reconsider if:** Never for FastAPI route handlers.

11. **Approach:** Estimate remaining-backlog work in calendar-days.
    **Who proposed it:** Claude (initial answer to "how many issues left to fix?").
    **Why rejected:** User pushed back: *"these estimates of days and weeks are ridiculous. You finished a days work in a few minutes."* The "Day N" labels in the campaign plan are not human-developer-days; they're scoping units that map to ~hours of focused work in practice.
    **Would we reconsider if:** Never. Use focused-work-hour buckets going forward.

## Files touched or about to touch

1. `/app/syb/tradesuite/tradelens/lib/tradelens/api/open_orders.py`
   - **Status:** edited-saved (committed across `51f02b6e`, `b8674f35`, `829f2405`, `ac17e4df`, `c8569cee`).
   - **What's there:** the consolidated open_orders.py FastAPI module (~5400 lines after this session's edits). Houses `cancel_order`, `bulk_cancel_orders`, `amend_order`, `convert_to_limit`, `create_order` (the 4 mutation endpoints + bulk), plus all the helpers (`get_tick_size`, `get_qty_step`, `calc_trigger_direction`, `check_existing_stop`, `determine_leg_type`, `calculate_quantity`, `_atomic_block` context manager, `round_to_tick`, etc.).
   - **What we changed:** AUD-0079 (cancel_order `_defer_refresh` parameter; `bulk_cancel_orders` rewrite); AUD-0083 (LevelGuard CREATE atomic-block); AUD-0082 (orderLinkId at 4 placement callsites + persistence); AUD-0081 (4 mutation endpoints wrapped + body extraction to `_<endpoint>_locked` helpers + inner AppLock → nullcontext); AUD-0087 (`get_tick_size` signature accepts BybitClient or account_name); AUD-0089 (`calc_trigger_direction` deterministic kwargs + module-level frozensets); AUD-0091 (`check_existing_stop` SQL broadened + reads running_qty); AUD-0092 (`determine_leg_type` auto-classification logger.info).
   - **Why it matters:** This is the single largest file in the API layer; every order-mutation operation flows through it. Most of Campaign 2's Day 1+2 commits land here.
   - **Cross-refs:** Decisions 2, 3, 4, 5; the `_<endpoint>_locked` helper pattern is the Wave A canonical shape.

2. `/app/syb/tradesuite/tradelens/lib/tradelens/adapters/bybit_client.py`
   - **Status:** edited-saved (committed in `51f02b6e`).
   - **What's there:** the `BybitClient` adapter wrapping Bybit's v5 API. Has `place_order`, `place_conditional_order`, `cancel_order`, `cancel_by_order_link_id`, `amend_order`, `get_instrument_info` (with TTL cache), `_generate_order_link_id` helper, `_validate_order_link_id` helper.
   - **What we changed:** Added `cancel_batch_orders(category, orders)` method at line ~1391 + `CANCEL_BATCH_LIMIT = 10` constant. Calls `/v5/order/cancel-batch` chunked at the documented limit. Rejects unsupported category + missing required fields.
   - **Why it matters:** The new helper is the API-level half of AUD-0079's win.
   - **Cross-refs:** AUD-0079 in `bulk_cancel_orders` is the only existing caller.

3. `/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md`
   - **Status:** edited-saved (committed across `4a7549e5`, `68d8f235`, `a7a32726`, `0432a656`, `2dccb8e3`).
   - **What's there:** the 590-line pipe-separated audit tracker. Plus the "Follow-up waves — operator action paths" section starting at line 452, with Wave A now showing CLOSED ✅.
   - **What we changed:** AUD-0077 row (Day 0 housekeeping, parallel-session retroactive); AUD-0079, AUD-0081, AUD-0082, AUD-0083, AUD-0087, AUD-0089, AUD-0091, AUD-0092, AUD-0169 rows (Confirmed/partial → Resolved or Resolved partial); the Follow-up section's Wave A entry was updated through three iterations: items + scope (after first commit), partial-shipped status (after second commit), CLOSED ✅ (after third commit).
   - **Why it matters:** Source of truth for AUD status. Confirmed count went 98 → 89 (−9) in this session.
   - **Cross-refs:** Every wave's tracker commit.

4. `/app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md`
   - **Status:** edited-saved (committed in `4a7549e5`).
   - **What's there:** 308-line dispatch document for Campaign 2. Sections: architecture rules carried forward from Campaign 1, hot-zone exclusion list, tracker housekeeping for AUD-0077, six waves' pre-dispatch tables (A, 2A, 2B, 3A, 3B, C) with per-AUD file/function/fix-shape/test-plan/park-rationale, verification checklist, out-of-scope list, target outcome metrics.
   - **Why it matters:** The campaign's operating contract. Future Day 3 work should follow the Wave 3A / 3B / C dispatch tables in this file.
   - **Cross-refs:** Every code commit this session is keyed to a row in this document's pre-dispatch tables.

5. **New test files created this session (4):**
   - `tradelens/tests/unit/test_aud0079_cancel_batch.py` (17 cases) — `cancel_batch_orders` empty/1/11/20-order chunking, orderLinkId alternative, missing-arg rejection, unsupported-category rejection, `CANCEL_BATCH_LIMIT == 10` sentinel; `cancel_order` `_defer_refresh` parameter and body guard; `bulk_cancel_orders` source-shape guards.
   - `tradelens/tests/unit/test_aud0082_order_link_id_persistence.py` (9 cases) — module-level import sanity, traceable-seed sanity, source-shape guards on each of the 4 placement callsites verifying `_generate_order_link_id` call + `order_link_id=order_link_id` placement-call kwarg + INSERT/UPDATE column inclusion + value-tuple inclusion + cross-callsite log-fragment count check.
   - `tradelens/tests/unit/test_aud0081_applock_mutations.py` (16 cases — initial 9 for cancel + convert; +7 added when amend + create shipped) — wrap source-shape per endpoint, namespace + lock_key per endpoint, role tag per endpoint, 409 translation per endpoint, helper-body sanity guards per endpoint, inner-AppLock-replaced-with-nullcontext check on `_amend_order_locked`, wait_seconds=2 / ttl_seconds=30 invariants across all 4 wrappers, lock_key composition check for create_order.
   - `tradelens/tests/unit/test_aud0087_0089_0091_0092_wave_2a.py` (28 cases) — 16 parametrized direction checks + 4 fallback cases for AUD-0089; AUD-0087 signature shape + isinstance(arg, str) source-shape guard + owns_client ownership flag + close() guarded; AUD-0091 source-shape guards on running_qty query + broadened leg_type IN clause + qty>=running_qty branch; AUD-0092 caplog-driven log emission + negative test.
   - `tradelens/tests/unit/test_aud0169_sessionize_legs.py` (10 cases) — first ever unit-test scaffold for `sessionize_legs`. State machine + stream classification + source-shape guards.
   - **Cross-refs:** Each maps to its AUD's commit.

6. **Existing test files updated for body-extraction collateral:**
   - `tradelens/tests/integration/test_aud0078_bg_refresh.py` — `_FakeCursor` extended with `fetchall()` and row 9-tuple → 10-tuple to match the new bulk SELECT shape (AUD-0079); 6 source-inspection tests retargeted via `_extract_function(src, "<helper>")` to `_cancel_order_locked`, `_convert_to_limit_locked`, `_amend_order_locked`, `_create_order_locked` (AUD-0081 body extraction).
   - `tradelens/tests/integration/test_aud0078_option_b_inline_insert.py` — `existing_stop_trade_row` fixture extended from 2-tuple to 3-tuple to match AUD-0091's running_qty query.
   - `tradelens/tests/unit/test_aud0079_cancel_batch.py` — `_defer_refresh` body-guard test retargeted to `_cancel_order_locked` (AUD-0081 body extraction).
   - `tradelens/tests/unit/test_aud0083_atomic_block.py` — 4 new CREATE-path cases added (AUD-0083); 2 existing amend tests retargeted to `_amend_order_locked` and 4 create tests retargeted to `_create_order_locked` (AUD-0081 body extraction).
   - `tradelens/tests/unit/test_aud0101_0103_decimal_compare.py` — `convert_to_limit` float-compare implementation guard retargeted to `_convert_to_limit_locked` (AUD-0081 body extraction).
   - `tradelens/tests/unit/test_amend_order_single_bybit_client.py` — `calc_trigger_direction` monkeypatch lambda gained `**kwargs` (AUD-0089 signature extension).

## Open threads

1. **Thread:** No active claude-task; campaign at clean stopping point.
   **State:** All 3 tasks closed. No uncommitted code. No in-flight edit.
   **Context needed to resume:** This checkpoint + the campaign plan doc + the prior-session checkpoint (Campaign 1 close).
   **Expected resolution:** User starts a new task with a stated Day 3 target (Wave 3A api/*, Wave 3B peripheral, Wave C tail, or a fresh mechanical sweep across the unbundled Confirmed pool).

2. **Thread:** Parallel-session breach_decision work continues actively.
   **State:** Pushed 5 commits between my own commits this session: `d6c7bd23`, `ec47a069`, `a9d814b6`, `d8da4b96`, `004774a1`. Their hot zones: `breach_decision/`, `level_guard/`, `level_mind/`, `sizing.py`, `state_manager.py`. Plus their newly-created `tradelens/lib/tradelens/breach_decision/holds_backtest/` directory (Plan 5 ship).
   **Context needed to resume:** `git log --oneline 2dccb8e3..HEAD` to see what they've added since my last commit; `git status --short` to see their untracked WIP files.
   **Expected resolution:** Stay clear of those files. If a future session is asked to touch them, first check parallel-session activity and confirm `git status` is clean.

3. **Thread:** AUD-0092 structural fix (require explicit leg_type from caller) parked pending frontend coordination.
   **State:** Visibility-only fix shipped (logger.info at the auto-classification site). Marked Resolved (partial) in the tracker.
   **Context needed to resume:** AUD-0092 tracker row carries the rationale; the structural half needs `CreateOrderRequest` to grow a `leg_type` field. Frontend file: `tradelens/frontend/web/src/...` (the create-order modal).
   **Expected resolution:** Either ship in a coordinated frontend+backend wave OR explicitly close as Resolved-partial-permanent.

4. **Thread:** Wave 2B's 5 parked items remain Confirmed.
   **State:** AUD-0154 (batch upsert), AUD-0166 (batch archive), AUD-0167 (pool/persistent-daemon), AUD-0168 (shared `bin/pipeline/_lib/` base), AUD-0176 (typed dataclass for 3 classifier maps).
   **Context needed to resume:** `tracelens/AUDIT_TRACKER.md` for each row's audit text; the campaign plan doc's Wave 2B section for park rationale.
   **Expected resolution:** A dedicated pipeline-architecture wave bundles 0167 + 0168 + 0176 (and possibly 0154/0166 as a perf sub-wave).

5. **Thread:** Day 3 candidate waves not yet started.
   **State:** Wave 3A (api/{stops, suspend, batch_ideas, ideas} — 6 AUDs: 0212, 0215, 0216, 0219, 0224, 0225); Wave 3B (peripheral — 5 AUDs: 0342, 0345, 0346, 0350, 0371); Wave C tail (multi-table tx wrap, AUD-0140 + lift `_atomic_block` to `core/db_helpers.py`).
   **Context needed to resume:** The campaign plan doc's pre-dispatch tables for each wave have file/function/fix-shape/test-plan per AUD.
   **Expected resolution:** User picks a Day 3 wave; new claude-task started; execution follows the same edit→test→commit cadence.

6. **Thread:** AUD-0341 + AUD-0343 bundled "awaiting C-bucket sign-off" (operator/product decision).
   **State:** From the campaign plan: trader_scorecard + system_monitor optimisations are bundled into a "C-bucket" awaiting operator sign-off because they require schema changes (new `source_channel_key` column on `trade_idea`). NOT shipped this session.
   **Context needed to resume:** AUD-0341 + AUD-0343 tracker rows; the C-bucket sign-off conversation is in the campaign plan's Wave 3B section.
   **Expected resolution:** Operator decision needed.

## Surprises / gotchas

1. **Finding:** AUD-0082's adapter-boundary auto-generation already existed (AUD-0039 ship), so the audit's "no orderLinkId generated anywhere" was misleading.
   **How discovered:** While reading `BybitClient.place_order` I noticed `if order_link_id is None: order_link_id = _generate_order_link_id(trade_id, leg_kind)` at line 1080. The comment said "AUD-0039: Every order leaving the adapter has a populated orderLinkId."
   **Time cost:** ~5 minutes to re-scope AUD-0082 from "add orderLinkId" to "thread trade_id + leg_kind for human-readable IDs + persist in `order_leg_live.order_link_id`".
   **Implication:** The actionable AUD-0082 fix is not what the audit text suggested; it's the persistence + traceability half. Documented in the AUD-0082 commit message and tracker row.
   **Where it's documented:** AUD-0082 tracker row in `tradelens/AUDIT_TRACKER.md`.

2. **Finding:** The `_FakeCursor` in `test_aud0078_bg_refresh.py` only mocks `fetchone`, but my new `bulk_cancel_orders` uses `fetchall`.
   **How discovered:** First post-AUD-0079 pytest run failed with `AttributeError: '_FakeCursor' object has no attribute 'fetchall'`.
   **Time cost:** ~5 minutes (clear error message, easy fix).
   **Implication:** Future tests that mock cursors need to support both `fetchone` and `fetchall`. Added a 2-line fix to the existing `_FakeCursor`.
   **Where it's documented:** Inline comment in the test file.

3. **Finding:** `isinstance(arg, BybitClient)` breaks when `BybitClient` itself is monkeypatched.
   **How discovered:** First post-AUD-0087 pytest run for `test_aud0106_raise_on_unknown_instrument.py` failed with `TypeError: isinstance() arg 2 must be a type, a tuple of types, or a union`.
   **Time cost:** ~10 minutes (had to read the test fixture to understand the mock pattern, then redesign the branch).
   **Implication:** Any production code that does `isinstance(arg, SomeClass)` where SomeClass might be patched in tests needs an alternative branch. The `isinstance(arg, str)` split is the robust pattern when the alternative is "anything else is treated as the live instance".
   **Where it's documented:** AUD-0087 commit message + the `test_aud0087_get_tick_size_source_branches_on_str_check` test.

4. **Finding:** Body extraction broke 9 source-inspection tests across 4 files.
   **How discovered:** Post-AUD-0081-residual pytest run showed 9 failures, all in tests that did `inspect.getsource(<endpoint>)` or `_extract_function(src, "<endpoint>")`.
   **Time cost:** ~15 minutes (mechanical sweep across 4 files).
   **Implication:** Source-shape regression guards are useful but couple tightly to the function-body location. Future refactors that extract bodies into helpers will have the same collateral. The fix is mechanical: retarget to the helper. The benefit (cleaner wraps, smaller diffs) outweighs the test-relocation cost.
   **Where it's documented:** AUD-0081-residual commit message lists each test file updated.

5. **Finding:** Parallel session pushed 5 commits between my own commits this session.
   **How discovered:** `git log --oneline -10` after each of my commits showed unfamiliar SHAs.
   **Time cost:** Zero (their work is in their hot zones, not mine).
   **Implication:** Parallel-session activity is constant during these campaigns. Always check `git log` post-commit; their work is harmless to mine but the commit graph is interleaved.
   **Where it's documented:** Working environment section above.

6. **Finding:** `reduce_only` is `varchar(5)` on three tables, not boolean as I initially assumed.
   **How discovered:** `grep -n "reduce_only" tradelens/etc/schema.md` showed three rows with `varchar(5) NULL`.
   **Time cost:** ~2 minutes (clear schema check).
   **Implication:** AUD-0100 is a schema-migration ship, not a code-only fix. Parked from Wave 2A with explicit rationale.
   **Where it's documented:** AUD-0100 tracker row + Wave 2A commit message.

7. **Finding:** User's "Day N" labels in the campaign plan are not human-developer-days.
   **How discovered:** User pushback: *"these estimates of days and weeks are ridiculous. You finished a days work in a few minutes."*
   **Time cost:** ~3 minutes to re-frame the answer.
   **Implication:** Future communications should give effort estimates in focused-work hours, not in days/weeks. Bucket by mechanical / medium / real-multi-file-refactor / out-of-scope.
   **Where it's documented:** User preferences section above + the corrected backlog estimate I gave in the conversation.

## Commands that mattered

1. **Command:** `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $4); sev=$4; gsub(/^ +| +$/, "", $6); status=$6; if (status == "Confirmed") print sev }' tradelens/AUDIT_TRACKER.md | sort | uniq -c | sort -rn`
   **Output (relevant portion):**
   ```
        58 Major
        18 Critical
        12 Minor
         1 Architecture
   ```
   **What we inferred:** Of the 89 remaining Confirmed AUDs, 18 are Critical and 58 are Major. The 18 Criticals are the highest-value targets for any future wave.

2. **Command:** `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | sort | uniq -c | sort -rn`
   **Output (post-Day-2):**
   ```
        257 Resolved
         89 Confirmed
         15 Resolved (partial)
          9 Design ready (T3 implementation pending)
          3 Works as intended
          2 Runbook prepared (user-only execution pending)
          2 Resolved (duplicate)
          1 Suspicious
          1 Parked
          1 Doc shipped (event-driven NOTIFY/LISTEN deferred)
   ```
   **What we inferred:** 89 Confirmed + 15 Resolved (partial) = 104 actionable items remain. 9 T3 designs + 1 Suspicious + 2 Runbook + 1 Parked = 13 items needing decisions/operator-only execution.

3. **Command:** `grep -n "reduce_only" tradelens/etc/schema.md | head -20`
   **Output:**
   ```
   736:| `reduce_only` | varchar(5) | NULL |
   778:| `reduce_only` | varchar(5) | NULL |
   835:| `reduce_only` | varchar(5) | NULL |
   ```
   **What we inferred:** `reduce_only` is `varchar(5)` on three tables; AUD-0100's "migrate to boolean" needs a schema change. Parked.

4. **Command:** `grep -n "exchange_order_link_id\|order_link_id" tradelens/etc/schema.md | head -10`
   **Output:**
   ```
   801:| `order_link_id` | varchar(36) | NULL |
   859:| `order_link_id` | varchar(36) | NULL |
   ```
   **What we inferred:** Column is `order_link_id` (not `exchange_order_link_id` as I'd written in the campaign plan). Already exists on both `order_leg_live` (859) and `order_leg_hist` (801). AUD-0082 persistence is shippable without DDL change.

5. **Command:** `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -5`
   **Output (final at session end):**
   ```
   1903 passed, 4 skipped, 9 warnings in 80.99s
   ```
   **What we inferred:** Master is green at the end of Day 2. The 9 warnings are AUD-0010 DeprecationWarnings doing their job per-design.

6. **Command:** `grep -n "calc_trigger_direction(" tradelens/lib/tradelens/api/open_orders.py | head -10`
   **Output (post-AUD-0089-edit):**
   ```
   2225:                    trigger_direction = calc_trigger_direction(
   3987:def calc_trigger_direction(
   4346:            bybit_params['triggerDirection'] = calc_trigger_direction(current_price, float(effective_trigger_price))
   4951:                trigger_direction = calc_trigger_direction(current_price, float(request.trigger_price))
   ```
   **What we inferred:** 3 internal callsites (excluding the function definition). All updated to pass side+leg_type.

7. **Command:** `grep -n "get_tick_size(" tradelens/lib/tradelens/api/open_orders.py | head -15`
   **Output:**
   ```
   1343:            tick_size = get_tick_size(account_name, category, symbol)
   1859:                        tick_size = get_tick_size(account_name, category, symbol)
   1873:            tick_size = get_tick_size(account_name, category, symbol)
   2417:        tick_size = get_tick_size(account_name, category, symbol) ...
   3982:def get_tick_size(bybit_or_name, category: str, symbol: str) -> Decimal:
   4131:                tick_size = get_tick_size(account_name, trade['category'], trade['symbol'])
   ...
   ```
   **What we inferred:** 8 callers, all using the legacy `account_name` shape. Backward compat preserved; updates to live-client path are an opportunistic-callsite-by-callsite future cleanup.

## Schema / API / data facts worth preserving

- **Fact:** `order_leg_live.order_link_id` and `order_leg_hist.order_link_id` are both `varchar(36) NULL` (matches Bybit's `ORDER_LINK_ID_MAX_LEN = 36`). **Evidence:** `etc/schema.md:801, 859`. **Why it matters:** AUD-0082 persistence works without a schema change. The 36-char cap is a hard upper bound from Bybit's API spec.

- **Fact:** `reduce_only` is `varchar(5) NULL` on `order_leg_live`, `order_leg_hist`, and `order_leg_smart`. **Evidence:** `etc/schema.md:736, 778, 835`. **Why it matters:** AUD-0100 migration to boolean is a schema-change ship requiring data migration of `'true'/'false'/'yes'/'no'/'1'/'0'` strings.

- **Fact:** `BybitClient.place_order` and `place_conditional_order` already auto-generate `orderLinkId` at the adapter boundary if `order_link_id=None`. **Evidence:** `bybit_client.py:1079-1082`. **Why it matters:** AUD-0082's actionable scope is threading `trade_id`+`leg_kind` for human-readable IDs and persisting in the DB, not "add orderLinkId". The audit text was misleading.

- **Fact:** `AppLock` uses PostgreSQL as a coordination store with PK on `(namespace, lock_key, lock_type)`. Same key acquired twice by the same process → PK conflict → `LockAcquireError`. **Evidence:** `lib/tradelens/locking/app_lock.py` + observed during AUD-0081 residual ship. **Why it matters:** Cannot have nested AppLock blocks with the same key in the same code path; must use either different keys or `contextlib.nullcontext()` for the inner.

- **Fact:** `AppLock(namespace='order-mutation', ...)` with `wait_seconds=2` is the canonical fast-fail-on-contention setting for mutation endpoints. `ttl_seconds=30` matches the historical convention. **Evidence:** AUD-0081 ship; documented in the Wave A Follow-up entry. **Why it matters:** Future mutation endpoints should adopt these constants for consistency.

- **Fact:** `_LOSS_SIDE_LEG_TYPES = frozenset({'stop', 'tl', 'trailing_tl'})` and `_PROFIT_SIDE_LEG_TYPES = frozenset({'tp', 'be', 'trailing_tp', 'trailing_be'})` are exported as module-level constants in `open_orders.py`. **Evidence:** AUD-0089 ship at `open_orders.py:~3978-3985`. **Why it matters:** Any new code that needs to classify a leg_type by direction-of-firing should import these rather than re-categorising.

- **Fact:** `check_existing_stop` at `open_orders.py:3786` reads `running_qty` from `trade_journal` (not just `symbol, side`). The function signature is `(cursor, trade_id, account_id) → bool`. **Evidence:** AUD-0091 ship. **Why it matters:** Tests/fixtures that mock the trade_journal SELECT must return a 3-tuple `(symbol, side, running_qty)`, not the old 2-tuple.

- **Fact:** Body of `cancel_order` lives in `_cancel_order_locked`; `convert_to_limit` body in `_convert_to_limit_locked`; `amend_order` body in `_amend_order_locked`; `create_order` body in `_create_order_locked`. **Evidence:** AUD-0081 ship. **Why it matters:** Any test/code that does `inspect.getsource(<endpoint>)` looking for body content gets the thin wrapper, not the body. Use the helper.

- **Fact:** `BybitClient.CANCEL_BATCH_LIMIT = 10` is the documented Bybit cancel-batch ceiling. `bybit_client.cancel_batch_orders(category, orders)` chunks at this limit. **Evidence:** AUD-0079 ship at `bybit_client.py:~1391`. **Why it matters:** Any future code that calls `/v5/order/cancel-batch` must respect this; raising it requires a Bybit API contract review.

- **Fact:** `bin/pipeline/` is added to sys.path by `tests/conftest.py:15`, so `import refresh_trade_journal as rtj` works from tests without sys.path-munging boilerplate. **Evidence:** AUD-0169 test file imports cleanly. **Why it matters:** Future pipeline-script tests can use plain imports.

## Next steps

The campaign is at a clean stopping point. There is no implicit next action — the user must direct the next move. Possible directions, in priority order from highest leverage to lowest:

1. **Day 3 Wave 3A** — api/{stops, suspend, batch_ideas, ideas}. 6 AUDs: 0212 (Critical: stops endpoint never worked, BybitClient construction crashes), 0215 (Critical: resume_trade marks status=open regardless of per-order failures), 0216 (Critical: batch_create_ideas async + sync DB blocks event loop), 0219 (Major: list_trade_ideas no SQL LIMIT/OFFSET), 0224 (Major: PooledDB pattern across 30+ endpoints), 0225 (Major: async cursors held across await). Estimated effort: ~4 hours of focused work in this session's pace. Pre-dispatch table in the campaign plan doc.

2. **Day 3 Wave 3B** — peripheral cluster. 5 AUDs: 0342 (Critical: trader_scorecard N+1), 0345 (Major: breach_* CLI scaffolding), 0346 (Major: breach_analysis tests), 0350 (Major: system_monitor TOCTOU), 0371 (Major: log rotation for 8 daemons). Estimated effort: ~4 hours. Pre-dispatch table in the campaign plan doc.

3. **Wave C tail** — multi-table tx wrap. AUD-0140 (cancel-seed, cancel-pending, force-open in journal.py — 3 endpoints). First step: lift `_atomic_block` from `open_orders.py:46-72` to `lib/tradelens/core/db_helpers.py`. Then for each AUD-0140 endpoint, find the Bybit-API call boundary, split DB writes around it, wrap each side in `_atomic_block`. Estimated effort: ~6-8 hours (real, not "1.5 days"). Pre-dispatch table in the campaign plan doc.

4. **Mechanical sweep across the unbundled Confirmed pool.** ~30 AUDs that are mechanical signature-changes / source-shape guards / log additions. No bundling, just rip through them. Estimated effort: ~6 hours. Would clear ~1/3 of the remaining backlog.

5. **AUD-0341 + AUD-0343 C-bucket** — needs operator sign-off first, then ~3 hours implementation.

6. **Wave D** — frontend mega-refactors. These are legitimately multi-day work each (AUD-0308 6,731 LOC trade-journal-chart split; AUD-0314 3,192 LOC api.ts split). Schedule one per session.

If the user says "continue" with no other context, do NOT auto-pick from this list — ask what they want.

## Verification checklist for the next session

1. `git rev-parse --short HEAD` should be `004774a1` OR a more-recent master tip (parallel session may have shipped further). If significantly different, re-run `git log --oneline -10` and re-check parallel-session activity.

2. `git status --short` should show NO modified tracked files. Untracked items should be `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` (symlink), parallel-session WIP files (`tradelens/bin/holds-mode-backtest`, `tradelens/bin/show/show_holds_mode_backtest.py`, `tradelens/lib/tradelens/breach_decision/holds_backtest/`, `tradelens/tests/unit/test_holds_backtest_level_outcome.py`), plus the usual `.claude/` artefacts. None of these are session work.

3. `claude-task current` should return empty (no active task).

4. `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | grep -c "Confirmed$"` should return 89.

5. `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | grep -c "Resolved$"` should return 257.

6. `grep -c "## Follow-up waves" tradelens/AUDIT_TRACKER.md` should return 1.

7. `grep "Wave A — AppLock" tradelens/AUDIT_TRACKER.md | head -1` should show `### Wave A — AppLock + orderLinkId (open_orders.py + bybit_client.py) — CLOSED ✅`.

8. `ls tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md` should exist (the campaign dispatch doc).

9. `ls tradelens/lib/tradelens/api/open_orders.py | xargs wc -l` should report ~5400 lines (was ~4645 pre-Wave-A; grew with body extractions and helper additions). The actual count post-edit should be well above 5000.

10. `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1` should report ~1903 passed (or higher if the parallel session has added tests). If `test_breach_decision_orchestrator.py` is currently green, no need to ignore it; check `pytest tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1` first.

If any of these fail, the checkpoint is stale on that point; re-validate before acting.
