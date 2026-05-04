# Checkpoint: post-XL-batch + reconciliation + AUD-0375 shipped; idle awaiting next user instruction

**Saved:** 2026-04-26 08:48:31 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ 9582b529
**Session:** a9025389-f8df-4cc5-b357-d7b047e87e7a
**Active task:** 20260426-aud0270-ddl-to-migration (orphan — set by an XL-batch sub-agent and never closed; the conversation is far broader than this label suggests)

## Handover Statement

You're stepping into an audit-autofix workstream on tradelens. The user just shipped a very large autonomous batch ("XL session") that ran ~25 sub-agents in parallel, hit cross-session staging contention bad enough to scramble four commit titles, and was followed by an explicit reconciliation pass and one final targeted fix. **The repo is in a good state right now.** HEAD is `9582b529`; pytest reports 1233 passed, 4 skipped; tracker is at 202 R / 170 C / 8 S. The most recently shipped item, AUD-0375 (move TP fill-reconcile to BackgroundTasks), landed cleanly with 10 new tests; do NOT re-edit it.

Read these files first, in this order: (1) the **"Decisions made"** section below — every approval the user gave came with explicit safety constraints; (2) `docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md` — the source-of-truth report on what shipped where, especially the AUD-to-commit table since FOUR commits carry wrong AUD-IDs in their titles; (3) `docs/30-fixes-and-audits/audits/audit-autofix/decisions-pending.md` — the operational doc listing what's left to ship, parked, and reclassified.

Known landmines that already bit us this session: (a) parallel sub-agents committing concurrently against the same working tree caused commits `41255fe3`, `8f7abdfa`, and `e9d15d3b` to land with mis-attributed titles — trust the tracker rows + reconciliation report, NOT git log titles; (b) AUD-0281 had its tracker meaning silently re-purposed mid-batch — the original concern is now AUD-0376 (Resolved-as-WAI), the new lease-watchdog work is what's under AUD-0281 now; (c) AUD-0117 was reframed mid-XL-batch from "trades.py time.sleep" to "AI batch async polling" — the surviving original concern was tracked as AUD-0375 and is now Resolved by `9582b529`. Working tree contains unstaged Level-B work (`bin/level-b-health`, `bin/show/show_level_b_health.py`, `lib/tradelens/level_b/health.py`, `tests/integration/test_level_b_health.py`) — these belong to the user's parallel session, do NOT touch.

What NOT to do: do NOT dispatch parallel sub-agents at scale (>3 concurrent) without isolating their working trees — see "Methodology lesson" in the reconciliation report. Do NOT touch swing_research, swing_levels, level_b/, level_mind_*, level_guard.py, or etc/config.yml without explicit instruction (concurrent Level-B session). Do NOT close the orphan claude-task `20260426-aud0270-ddl-to-migration` unless asked — it was set by a sub-agent and is functionally meaningless to the actual conversation. Do NOT assume `git log` titles are accurate for AUD-0086 / AUD-0117 / AUD-0125 / AUD-0246 / AUD-0283.

The user's last instruction was satisfied (AUD-0375 shipped). They have NOT given a next instruction. The expected next action is: **wait for the user's next instruction**. If they ask "what's next?" the highest-leverage choices are (a) ship AUD-0375 follow-up bundle with AUD-0119 (BackgroundTasks for trade-event writes — same pattern), (b) plan the AUD-0341+0343 bucket-C bundle with the schema migration (test plan already drafted), or (c) plan the AUD-0227 + AUD-0312 user-identity epic (T3, you-only). Refer to the "Recommended next batch" section of the reconciliation report.

## Session context

### User's stated goal (verbatim where possible)

The session started with the user resuming the audit-autofix workstream after a `/clear` + `/t-checkpoint-load`. Initial framing: "I want you to read the decisions-pending.md and work on all the tasks that I have ticked. Use sub agents." Later, after I proposed M/L/XL scales: "do XL". After XL: "Stop dispatching new audit-fix work. Run a full reconciliation pass now." After reconciliation: "Proceed with AUD-0375 only."

The arc of stated goals across this conversation:
1. Resume the audit-autofix batch they had ticked items for in `decisions-pending.md` (early today).
2. Maximum-throughput XL push — "do XL" — with explicit acceptance of bucket-A + B-recommended + C + new D classifications.
3. Hard stop after XL to reconcile the chaos: "Run a full reconciliation pass now. Do not start any new remediation until the repository, tests, tracker, and AUD-to-commit mapping are reconciled."
4. After reconciliation, ship ONE narrowly-scoped follow-up: AUD-0375 (the surviving time.sleep(0.5) at trades.py:1648-1649, formerly the original AUD-0117 concern), with very specific implementation rules.

### User preferences and corrections established this session

- **"Stop dispatching new audit-fix work. Run a full reconciliation pass now."** — issued after the XL batch when the user saw the cross-session contamination chaos. Hard halt. No new work until reconciled.
- **"Proceed with AUD-0375 only. ... Do not dispatch parallel sub-agents. Do not touch unrelated AUD items. Do not combine this with AUD-0341/AUD-0343, AUD-0227, AUD-0374, or any other tracker item. Keep the change minimal."** — explicit narrow scope for AUD-0375. The user is no longer trusting parallel dispatch at scale.
- **"Do not return before protective TPs are placed. Do not leave the trade without TPs because the background task fails."** — money-path safety constraint for AUD-0375. The fallback (preview-price TPs) had to remain the safe state.
- **"Stop condition: If the fix requires changing trade submission semantics, order-placement timing, database schema, or frontend behaviour, stop and produce a short proposal instead of coding."** — repeated stop condition. Also: "If idempotent TP amendment cannot be done safely with the existing order linkage data, stop and produce a narrower proposal instead of coding."
- The user explicitly authorized Option B (sync TPs at preview prices + background amend) over Option A (full BackgroundTasks for everything) — quote: "Proceed with AUD-0375 using Option B, but treat it as a controlled design change."
- Working-tree boundary established earlier in the session and reaffirmed: do NOT touch swing_research / swing_levels / level_b / level_mind_* / level_guard.py / etc/config.yml — those belong to the user's parallel Level-B research session.

### Working environment

- **HEAD:** master @ `9582b529` (`fix(api): AUD-0375 — move TP fill-reconcile to BackgroundTasks (Option B)`).
- **Pytest:** 1233 passed, 4 skipped, 0 failures on full suite from current HEAD (verified by AUD-0375 sub-agent's final run; should still hold).
- **Working tree (untracked, NOT mine):** `bin/level-b-health`, `bin/show/show_level_b_health.py`, `lib/tradelens/level_b/health.py`, `tests/integration/test_level_b_health.py`, `docs/chat.txt.gz` (302KB, modified 10:05 today, presumably user's chat export), `.claude/` system dirs.
- **No staged or unstaged modifications.** Working tree is clean for tracked files.
- **A symlink** exists at `docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` pointing to `tradelens/AUDIT_TRACKER.md`. Untracked. Harmless. Don't follow + commit it.
- **Background processes:** none from me. Sub-agents from earlier in the session all completed and returned. Several of their reports flagged ambient parallel sessions writing to the same repo (Level-B work).
- **Active claude-task:** `20260426-aud0270-ddl-to-migration` — orphan, set by an XL-batch sub-agent (likely the AUD-0270 migration-078 worker) and never closed. The conversation is unrelated to it now. Do NOT close it without asking the user.

## Objective

The user is consolidating a large remediation push on the tradelens repository. The codebase had ~366 outstanding audit findings (`AUDIT_TRACKER.md`) at the start of the day; today's work brought tracker state from 178 R / 190 C / 9 S → 202 R / 170 C / 8 S (about +24 Resolved). The XL batch alone shipped ~25 commits across as many AUD-IDs over a single push; the subsequent reconciliation captured the audit trail in a dedicated report; AUD-0375 was the one chosen narrow follow-up.

The underlying motivation is operational: the user is the sole maintainer running this trading system live (single-user, single-account mode); audit findings that touch money-path code (order placement, transaction safety, error sanitization) are real production risks. The reason throughput matters is that there's a runway of ~150+ remaining items the user wants to clear before the next architectural phase (Level-B in-flight on a parallel session).

In-scope right now: (a) maintaining the integrity of what just shipped (no re-edits to AUD-0375), (b) recording the lessons from XL contention, (c) being ready for the user's next narrow ship request. Out-of-scope right now: any new audit-fix dispatch, any sub-agent that touches AUD-0341/0343, AUD-0227, AUD-0374, AUD-0303, or any of the parked items. The user has explicitly reserved those for their own ticking process.

## Narrative: how we got here

The session opened with the user picking up the audit-autofix workstream and asking me to dispatch sub-agents for everything they had ticked in `decisions-pending.md`. The earlier 24-commit batch had already landed (it's documented in the doc itself); this session was a fresh push.

I produced an option list (M / L / XL) describing escalating commit volumes. The user picked XL — explicitly authorising bucket-A items, bucket-B "all recommended", the two new bucket-C items from the chunks-11-12 re-triage, and the more ambitious AUD-0118/0150 carry-forward. The expected wall time was a full overnight; the actual wall time was ~5 hours of dense activity.

XL kicked off in phases. Phase 1 (housekeeping + 4 frontend bucket-A items + 1 verification) and Phase 2 batch 1 (4 backend bucket-B items: 0011, 0124, 0270, 0299) ran cleanly. Phase 2 batch 2 (6 sub-agents in parallel: 0086, 0125, 0227, 0283, 0292, 0220) was where contention started biting — three of those commits (`41255fe3`, `8f7abdfa`, `e9d15d3b`) landed with WRONG AUD-IDs in their commit titles because parallel sub-agents staged into the same git index simultaneously and one sub-agent's commit absorbed another's staged hunks. The work was preserved in the codebase but the audit trail in `git log --oneline` became unreliable.

A second-order problem surfaced: AUD-0227 (user-scoped authz) hit a stop-condition correctly — there's no user identity model in tradelens at all, so the proposed middleware-level fix had nothing to verify against. That sub-agent stopped and reported. AUD-0341+0343 (trader_scorecard window functions) similarly hit a stop-condition: the rewrite needed a new `source_channel_key` column + parser updates in both Telegram and Discord paths, which is a schema change. That sub-agent paused at the test-plan approval gate.

A third-order problem: AUD-0281 had its tracker row meaning quietly re-purposed mid-batch. The original AUD-0281 was a positive observation (vwap engines correctly use singleton_lock — flagged as good-pattern source for AUD-0182). The dispatched sub-agent landed a different but valuable fix (background lease-refresh watchdog for `level_mind_worker`) and overwrote the tracker row text. The original concern's text was lost from AUD-0281 but the work it pointed at (AUD-0182's flock propagation) had already shipped 2026-04-23. AUD-0117 had a similar drift — the original tracker description was the `time.sleep(0.5)` at trades.py:1648; the sub-agent's work was the AI batch async-with-polling implementation. Both shipped, both useful, but ID semantics drifted.

Around commit ~20 of the XL push, the user issued a hard stop: "Stop dispatching new audit-fix work. Run a full reconciliation pass now." I executed the reconciliation: confirmed working tree (clean), ran full pytest (1205 pass, 0 fail), built a 7-row AUD-to-commit mapping table for the critical IDs, verified augmentation-loss claims (none materialized), made 5 tracker corrections (AUD-0227 → F; AUD-0303 → B; AUD-0341+0343 → C; AUD-0281 preamble), opened AUD-0375 for the surviving time.sleep concern, opened AUD-0376 to capture the original AUD-0281 row content as Resolved-as-WAI. Wrote the reconciliation report to `docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md`. Committed all of that as `d44c5e3e`.

The user then approved AUD-0375 with very specific narrow rules: single sub-agent, single commit, Option B (sync TPs at preview prices + background amend), with a stop condition on idempotency. I verified the stop condition (TPs ARE tracked by exchange_order_id; `bybit.amend_order` ALREADY supports price-only amends; `submit_trade` has no internal Python callers — safe to inject `BackgroundTasks`). Dispatched a single sub-agent. It hit one transient "file modified since read" linter blip but recovered cleanly, shipped commit `9582b529` with 10 new regression tests covering: no time.sleep in submit_trade body, sync TP placement at preview price, background reconciliation amends on differing fill, background failure leaves preview-price TPs intact, non-market entries unaffected.

We are now sitting at HEAD `9582b529`, suite green at 1233 passed, awaiting the user's next instruction.

## Work done so far

1. **Issued option matrix to user (M / L / XL)** — proposed scaled batches with file-overlap analysis; user picked XL. No file changes.

2. **Phase 1 housekeeping commit `d5ef4953`** — committed the chunks-11-12 re-triage tail doc + closed AUD-0259 as G (duplicate of AUD-0240). Tracker only.

3. **Phase 1 frontend dispatch (4 sub-agents in parallel + 1 verification)** — AUD-0313 delete `_t` cache-buster (`65d31706`), AUD-0322 RR help extracted to `.md` via Vite `?raw` (`be30e93b` + SHA backfill `1cf96ec2`), AUD-0338 NotFound catch-all route (`6e01926d`), AUD-0339 localStorage corrupt-recovery in equity.tsx (`36905b47`), and AUD-0303 verification → reclassified to bucket B (3 picks needed).

4. **Phase 2 batch 1 (4 backend sub-agents in parallel)** — AUD-0011 explicit httpx.Timeout (`3b0c13fa`), AUD-0124 = ANY(%s) journal upgrade (`3dbbd020` + SHA backfill `9889652e`), AUD-0299 cycle-scoped DB conn for alert_engine (`5ec0f0fc` + SHA backfill `7db2d302`), AUD-0270 inline DDL → migration 078 (`879f55bb` + SHA backfill `cb12bbd9`).

5. **Phase 2 batch 2 (6 sub-agents in parallel — contention started)** — AUD-0220 asyncio.gather + Sem(8) for ideas (`a23c11af`, correctly titled), AUD-0086 instrument-info TTL cache (CODE in `e9d15d3b`, mis-titled "AUD-0117 docs"), AUD-0125 single LATERAL JOIN for market_summary (CODE in `41255fe3`, mis-titled "AUD-0283"), AUD-0227 stopped at no-user-identity-model failure (NO commit, reclassified to F), AUD-0283 market_data tuning to config (CODE in `8f7abdfa`, correctly titled but commit ALSO contains AUD-0117 + AUD-0246 + AUD-0086 work due to staging race), AUD-0292 bounded pkill helper (`16538a38`, correctly titled).

6. **Phase 2 batch 3 (6 sub-agents in parallel — more contention + scope changes)** — AUD-0080+0105 ticker fail-fast (`1d550ef7`), AUD-0117+0221+0230 async batch + polling (CODE in `8f7abdfa`, mis-titled "AUD-0283"), AUD-0214 typed adapters in suspend (`eb60d4d7`), AUD-0246 auth-before-body in discord_ingest (CODE in `8f7abdfa`, mis-titled "AUD-0283"), AUD-0281 lease-refresh watchdog (`eef5de75` — but tracker row meaning re-purposed; original concern moved to AUD-0376), AUD-0341+0343 stopped at test-plan approval gate (no commit, reclassified to C with schema-change implications).

7. **Reconciliation pass `d44c5e3e`** — full pytest (1205 pass, 0 fail); 7-row AUD-to-commit mapping; tracker corrections for AUD-0227 → F, AUD-0303 → B, AUD-0341+0343 → C; clarifying preamble on AUD-0281; opened AUD-0375 for surviving trades.py:1648 time.sleep concern; opened AUD-0376 closing original AUD-0281 row content as WAI; wrote `docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md`.

8. **AUD-0375 ship `9582b529`** — moved TP fill-reconcile to `BackgroundTasks` (Option B). Modified `lib/tradelens/api/trades.py`: injected `BackgroundTasks` parameter into `submit_trade`, replaced the blocking `for fill_attempt in range(3)` retry loop (with `time.sleep(0.5)`) at trades.py:1422-1486 with synchronous TP placement at preview prices, added module-level helper `_reconcile_market_entry_tps` at trades.py:3179-3393 that runs as a BackgroundTask after the response is sent. Helper is idempotent by amending existing TP orders by `exchange_order_id` (never places new TPs). Added regression test `tests/integration/test_aud0375_tp_background_reconcile.py` with 10 cases. Tracker AUD-0375 → Resolved. Pytest 1205 → 1233 (+10 from this fix; remainder from concurrent Level-B health-test additions).

## Decisions made (and why)

1. **Decision:** XL scale (~60-commit overnight push) was authorised over M (12 commits) or L (40 commits).
   **Proposed by:** user.
   **Rationale:** "i want to do a much larger tranch of work." User wanted maximum throughput.
   **Alternatives considered:** M (cheap, ~1-2 hr) and L (~40 commits, 4-6 hr) — both rejected as insufficient.
   **Revisit if:** the user changes their mind about throughput (they did, mid-batch — see decision #6).
   **Affects:** the entire XL batch.

2. **Decision:** Run sub-agents up to 6 in parallel (file-disjoint) rather than serially.
   **Proposed by:** Claude.
   **Rationale:** with ~60 items to ship and ~5 hours wall time, serial dispatch (5-15 min/item) wouldn't finish.
   **Alternatives considered:** strict serial (rejected — too slow); fully parallel ≥10 (rejected — too risky on file overlap); per-AUD git worktrees (rejected — would have required setting up the harness).
   **Revisit if:** parallel dispatch produces unrecoverable contamination.
   **Affects:** all of Phase 2; this decision is what produced the commit-title scrambles.

3. **Decision:** Trust each sub-agent's own AUDIT_TRACKER write; do NOT batch-update centrally.
   **Proposed by:** Claude (default behaviour).
   **Rationale:** simpler dispatch; each sub-agent owns its tracker row.
   **Alternatives considered:** central tracker update by parent (rejected as more complex; would have eliminated tracker contention but kept code-file contention).
   **Revisit if:** repeating an XL push — see Methodology lesson in reconciliation report.
   **Affects:** AUDIT_TRACKER.md provenance trail.

4. **Decision:** AUD-0227 (user-scoped authz) reclassified to bucket F (T3 architectural) instead of shipping.
   **Proposed by:** Claude (sub-agent's stop-condition report).
   **Rationale:** there is genuinely no user identity model in tradelens — no `users` table, no auth headers from FE, no JWT/session. Middleware-level authz has nothing to check against.
   **Alternatives considered:** ship a tautological middleware (allow-all or deny-all — rejected as not closing the gap); ship a stub user table + seed (rejected as scope creep).
   **Revisit if:** user wants the 5-step epic (schema + auth + FE + middleware + seed). Bundle AUD-0312 (zero FE auth headers).
   **Affects:** tracker row AUD-0227; recommended next batch C.

5. **Decision:** AUD-0341+0343 (trader_scorecard rewrite) reclassified to bucket C, NOT shipped.
   **Proposed by:** Claude (sub-agent's test-plan stopped at approval gate).
   **Rationale:** the rewrite requires a new `source_channel_key` column on `trade_idea` + migration 079 + parser updates in both `bin/telegram_signals.py` and `lib/tradelens/discord/idea_creator.py`. Schema change + multi-file producer change = bucket C, not B.
   **Alternatives considered:** ship the rewrite without schema change (rejected — performance gain depends on indexed column; the column AND index are what makes the window-function rewrite fast).
   **Revisit if:** user explicitly approves the C-bucket scope. The sub-agent's test plan is documented in the AUD-0341 tracker row.
   **Affects:** tracker rows AUD-0341, AUD-0343; recommended next batch B.

6. **Decision:** Stop XL push and run reconciliation.
   **Proposed by:** user (verbatim: "Stop dispatching new audit-fix work. Run a full reconciliation pass now.").
   **Rationale:** the chaos from cross-session contention was severe enough that without an audit trail consolidation, the work would be hard to verify or build on.
   **Alternatives considered:** push through to ~60 commits (the original XL plan — rejected by user); only spot-check (rejected by user as insufficient).
   **Revisit if:** never; this was the right call.
   **Affects:** ended the XL batch; produced reconciliation report.

7. **Decision:** AUD-0375 fix uses Option B (sync TPs at preview prices + background amend) over Option A (BackgroundTasks for everything).
   **Proposed by:** user (verbatim: "Proceed with AUD-0375 using Option B, but treat it as a controlled design change.").
   **Rationale:** Option B preserves the response shape (TPs are still placed before submit returns) and the safe fallback (preview-price TPs remain in place if background amend fails). Option A would have changed the FE contract (TPs become "pending" until the background task runs).
   **Alternatives considered:** Option A (full BackgroundTasks — rejected for FE contract change); Option C (full async conversion of submit_trade — rejected as not minimal); Option D (single-attempt fetch — rejected as money-path regression); Option E (tune sleep duration — rejected as not a real fix).
   **Revisit if:** the background reconciliation proves unreliable in production (e.g. amend_order error rates spike) — but the safe fallback (preview prices remain) prevents catastrophic failure modes.
   **Affects:** `lib/tradelens/api/trades.py`, `tests/integration/test_aud0375_tp_background_reconcile.py`, AUD-0375 tracker row.

8. **Decision:** Idempotent TP amendment is safe via `bybit.amend_order` keyed by `exchange_order_id`.
   **Proposed by:** Claude (verified before dispatch).
   **Rationale:** TPs are tracked by `(trade_intent_id, leg_type='tp', exchange_order_id)` in `order_leg`. `bybit.amend_order` accepts `price=str(...)` per `bybit_client.py:1232-1272`. Re-running the reconciler computes the same target and amend either succeeds (price already correct → no-op or 110050-class no-op) or returns benign error (e.g., already filled). Never places new TPs.
   **Alternatives considered:** cancel-and-replace pattern (rejected — risky during read-after-write lag; could leave brief unprotected window).
   **Revisit if:** Bybit changes amend semantics or starts rejecting price-only amends.
   **Affects:** `_reconcile_market_entry_tps` helper at trades.py:3179-3393.

9. **Decision:** Open new tracker IDs for ID-drift items (AUD-0375 captures original AUD-0117 concern; AUD-0376 captures original AUD-0281 row).
   **Proposed by:** Claude (during reconciliation).
   **Rationale:** when an audit ID's meaning gets re-purposed mid-batch, both the new work AND the original concern need tracking surface. Reusing the same ID loses one or the other.
   **Alternatives considered:** add a clarifying note within the same row (rejected — invisible to grep-based audits); leave the original concern undocumented (rejected — audit trail integrity).
   **Revisit if:** future re-triage decides to merge them again.
   **Affects:** AUDIT_TRACKER.md rows for AUD-0117, AUD-0281, AUD-0375, AUD-0376.

## Rejected approaches (and why)

1. **Approach:** Run all ~60 XL items in fully parallel sub-agents.
   **Who proposed it:** Claude (briefly considered before Phase 2).
   **Why rejected:** file-overlap risk. Concurrent edits to the same file would block on git's lock or produce merge conflicts. Settled on file-disjoint batches of 3-6.
   **Would we reconsider if:** sub-agents ran in isolated git worktrees (the harness supports `isolation: "worktree"` per the Agent tool docs).

2. **Approach:** AUD-0375 Option A (move ENTIRE TP placement to BackgroundTasks; submit returns before TPs placed; FE polls).
   **Who proposed it:** Claude (initial proposal during analysis phase).
   **Why rejected:** user's stop-condition: "If the fix requires changing trade submission semantics, order-placement timing, database schema, or frontend behaviour, stop and produce a short proposal." Option A would have changed all four.
   **Would we reconsider if:** user explicitly authorises an FE contract change.

3. **Approach:** AUD-0375 Option C (convert `submit_trade` to `async def` + `await asyncio.sleep` + `asyncio.to_thread` for blocking Bybit calls).
   **Who proposed it:** Claude (in proposal).
   **Why rejected:** `submit_trade` is ~1200 LOC; making it async would cascade through too many call paths. Not "minimal" per user's rules.
   **Would we reconsider if:** the broader `api/trades.py` rewrite (AUD-0114 / 0115 / 0126) is undertaken — submit_trade can become async then.

4. **Approach:** AUD-0375 Option D (single-attempt fill fetch, fall back to preview prices on miss).
   **Who proposed it:** Claude (in proposal).
   **Why rejected:** money-path regression. Today's 3-attempts-with-sleep handles Bybit's read-after-write lag; reducing to 1 attempt would cause RR-based TPs to be wrong-priced more often.
   **Would we reconsider if:** Bybit's read-after-write lag is measured to be much smaller than 0.5s in practice (would have to instrument first).

5. **Approach:** AUD-0227 ship a tautological middleware (everyone is "user 1" so allow everything).
   **Who proposed it:** Claude (briefly during Phase 2 batch 2).
   **Why rejected:** doesn't close the audit gap. The gap IS the missing identity model.
   **Would we reconsider if:** never. Closing AUD-0227 requires the 5-step epic.

6. **Approach:** AUD-0341+0343 ship just the SQL rewrite without the schema column.
   **Who proposed it:** Claude (briefly during Phase 2 batch 3).
   **Why rejected:** the perf gain depends on having an indexed column. Rewriting the query without the column is faster than today (still N+1 → 1) but slow without the index.
   **Would we reconsider if:** user opts for partial ship (just the query) and accepts that the index work comes later.

7. **Approach:** AUD-0281 close the original (vwap singleton_lock confirmation) with a clarifying note in the SAME row, no new ID.
   **Who proposed it:** Claude (briefly during reconciliation).
   **Why rejected:** the new lease-watchdog work has its own implementation details; mixing them into one row would be confusing for future readers. Opening AUD-0376 keeps each concern crisp.
   **Would we reconsider if:** the user wants tracker-row consolidation.

## Files touched or about to touch

1. `/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md`
   - **Status:** edited-saved across multiple commits this session
   - **What's there:** the full audit tracker (~378 rows) — the source-of-truth for which findings are Resolved / Confirmed / Suspicious.
   - **What we changed:** appended Resolved notes to AUD-0011, 0080, 0086, 0117, 0124, 0125, 0145, 0214, 0220, 0246, 0259, 0270, 0281, 0283, 0292, 0299, 0313, 0322, 0338, 0339, 0341, 0343, 0344, 0375; added new rows AUD-0375, AUD-0376; appended reclassification preambles to 0227, 0303.
   - **Why it matters:** central audit trail; the reconciliation report cites specific rows.
   - **Cross-refs:** Decisions #4, #5, #7, #9.

2. `/app/syb/tradesuite/tradelens/lib/tradelens/api/trades.py`
   - **Status:** edited-saved (commit `9582b529`)
   - **What's there:** the trades API, including `submit_trade` (line 990, ~1200 LOC), `submit_trade_json` (line 2689), and many helpers.
   - **What we changed:** at trades.py:1422-1486 the blocking `for fill_attempt in range(3)` loop was replaced with synchronous preview-price TP placement + a `background_tasks.add_task(_reconcile_market_entry_tps, ...)` schedule. Added `BackgroundTasks` to imports (line 19) and to the `submit_trade(request, background_tasks: BackgroundTasks)` signature. Added new module-level helper `_reconcile_market_entry_tps` at trades.py:3179-3393 that opens its own DB connection (via `PostgresDB(config.database, logger)` per AUD-0299 pattern), reconstructs a `BybitClient` for the account, runs the 3-attempts × 0.5s fill fetch (now safe to block in a background thread), recalcs TP levels with `calculate_take_profit_levels(...)`, and amends each placed TP via `bybit.amend_order(category, symbol, order_id, price)` if the recalculated price differs from the placed price (post-rounding).
   - **Why it matters:** removes the 1.5s worker block per market submission. The fix is the load-bearing AUD-0375 closure.
   - **Cross-refs:** Decision #7, Decision #8; tested by `tests/integration/test_aud0375_tp_background_reconcile.py`.

3. `/app/syb/tradesuite/tradelens/tests/integration/test_aud0375_tp_background_reconcile.py`
   - **Status:** edited-saved (commit `9582b529`); NEW file
   - **What's there:** 10 regression tests pinning AUD-0375's contract.
   - **What we changed:** N/A — created in `9582b529`.
   - **Why it matters:** future regressions to the synchronous path or the background reconciler will fail this test file. Pre-fix, tests 1, 3, 4 fail; post-fix all 10 pass.
   - **Cross-refs:** AUD-0375 tracker row references this path.

4. `/app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md`
   - **Status:** edited-saved (commit `d44c5e3e`); NEW file
   - **What's there:** the source-of-truth report for the XL session. Includes the AUD-to-commit mapping table, sub-agent stop-conditions, tracker corrections, and recommended next batches.
   - **What we changed:** N/A — created during reconciliation.
   - **Why it matters:** when `git log --oneline` titles are wrong (which they are for `41255fe3`, `8f7abdfa`, `e9d15d3b`), this report is what a future reader uses to find what shipped where.
   - **Cross-refs:** the entire reconciliation pass; Handover Statement points future readers here first.

5. `/app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/decisions-pending.md`
   - **Status:** read-only (last edited in commits `d5ef4953` and earlier today)
   - **What's there:** the operational doc the user uses to tick which AUD-IDs to ship next. Includes "Shipped" tables for batch 1 and batch 2, "Follow-ups requiring user attention" list, parked items, and the bucket-by-bucket pending list.
   - **What we changed:** nothing this session beyond what `d5ef4953` already committed.
   - **Why it matters:** the user's primary interface for the next batch.
   - **Cross-refs:** Handover Statement, recommended next batch.

6. `/app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/t2-retriage-chunks-11-12-tail.md`
   - **Status:** edited-saved (commit `d5ef4953`); NEW file
   - **What's there:** the chunks-11-12 re-triage tail covering 57 previously-Unclassified items. Categorised into A (4) / B (6) / C (2) / D (0) / F (41) / G (1).
   - **What we changed:** N/A — created earlier.
   - **Why it matters:** unblocks the next round of bucket-A/B ticks for the user.

7. `/app/syb/tradesuite/tradelens/lib/tradelens/adapters/bybit_client.py`
   - **Status:** edited-saved (commit `e9d15d3b`, mis-titled "AUD-0117 docs" but actually contains AUD-0086 code)
   - **What's there:** `BybitClient` with `httpx.Client` underneath; `get_instrument_info`, `place_order`, `place_conditional_order`, `amend_order`, `get_order_history`, etc.
   - **What we changed:** added `cachetools.TTLCache(maxsize=1024, ttl=300)` for instrument-info (AUD-0086); explicit `httpx.Timeout(connect=5, read=15, write=10, pool=5)` (AUD-0011, commit `3b0c13fa`).
   - **Why it matters:** cache reduces Bybit round-trips; explicit timeout prevents indefinite blocking. AUD-0375's background helper depends on `bybit.amend_order` here.
   - **Cross-refs:** Decision #8 (AUD-0375 idempotency relies on amend_order).

8. `/app/syb/tradesuite/tradelens/migrations/078_market_candle_pg_schema.sql`
   - **Status:** edited-saved (commit `879f55bb`); NEW file
   - **What's there:** the `market_candle` PG DDL extracted from `lib/tradelens/candle_pg/store_pg.py::ensure_schema`. Idempotent (`IF NOT EXISTS`).
   - **What we changed:** N/A — created in AUD-0270's commit. Applied to both `tradelens` and `tradelens_test`.
   - **Why it matters:** ensure_schema is no longer a runtime DDL site; it's a verify-only stub.

9. **Working tree (untracked, NOT mine — DO NOT TOUCH):**
   - `bin/level-b-health` — Level-B health CLI wrapper
   - `bin/show/show_level_b_health.py` — Level-B health display
   - `lib/tradelens/level_b/health.py` — Level-B health module
   - `tests/integration/test_level_b_health.py` — 18 Level-B health tests (the 18 that account for the 1233 - 1205 - 10 = 18 delta in pytest count)
   - `docs/chat.txt.gz` — 302KB, modified 10:05 today; presumably user's chat export
   - `.claude/agents/`, `.claude/checkpoints/`, `.claude/` — system files

## Open threads

1. **Thread:** orphan claude-task `20260426-aud0270-ddl-to-migration` — set by an XL-batch sub-agent (likely the AUD-0270 worker) and never closed.
   **State:** ACTIVE in the claude-task tracker, even though the AUD-0270 work shipped in `879f55bb` and has been Resolved for hours.
   **Context needed to resume:** `claude-task list-active`. Mismatch is purely cosmetic.
   **Expected resolution:** user may want to `claude-task done <task_id>` it during a later `/t-done`. Don't auto-close.

2. **Thread:** the user's parallel Level-B research session is still committing files (last seen: commit `7725d660` `refactor(level-b): rename soft_stop_*` between my reconciliation `d44c5e3e` and AUD-0375 `9582b529`).
   **State:** active and orthogonal to my work.
   **Context needed to resume:** N/A — don't intervene unless asked.
   **Expected resolution:** user manages it directly.

3. **Thread:** `docs/chat.txt.gz` (302KB, untracked) — not generated by me, appeared during the session.
   **State:** unknown provenance; assumed user's chat export.
   **Context needed to resume:** `ls -la docs/chat.txt.gz` shows mtime 10:05 today.
   **Expected resolution:** leave alone unless user comments.

4. **Thread:** AUD-0341+0343 has a sub-agent's drafted test plan recorded in the tracker row but no implementation — awaiting user's explicit C-bucket sign-off.
   **State:** documented, ready to dispatch when authorised.
   **Context needed to resume:** read `AUDIT_TRACKER.md` AUD-0341 row for the test plan.
   **Expected resolution:** user ticks C-bucket on this in `decisions-pending.md`.

5. **Thread:** AUD-0227 + AUD-0312 user-identity epic — moved to F, no work scheduled.
   **State:** awaiting user's planning-session approval.
   **Context needed to resume:** `xl-session-reconciliation-2026-04-26.md` "Recommended next batch C".
   **Expected resolution:** user schedules a T3 planning session.

6. **Thread:** AUD-0303 `bin/monitor` rewrite — needs 3 picks (target location, psutil dep, YAML loader fold-in).
   **State:** awaiting user's bucket-B picks.
   **Context needed to resume:** `AUDIT_TRACKER.md` AUD-0303 row for the picks.
   **Expected resolution:** user picks (a)/(b)/(c) on each.

7. **Thread:** AUD-0374 (94 prod orphan filled legs) — T3 sessionization investigation, no work scheduled.
   **State:** flagged in tracker, awaiting planning session.
   **Context needed to resume:** `AUDIT_TRACKER.md` AUD-0374 row.
   **Expected resolution:** user schedules a T3 planning session.

## Surprises / gotchas

1. **Finding:** Cross-session staging-area contention can cause one sub-agent's `git commit` to absorb another sub-agent's `git add`-staged hunks if both fire concurrently against the same git index.
   **How we discovered it:** multiple sub-agent reports across Phase 2: "the AUD-0XXX changes were swept into commit YYYYY which is titled for AUD-ZZZ"; verified via `git show --stat` showing files unrelated to the commit title.
   **Time cost:** ~30 minutes of reconciliation effort.
   **Implication:** parallel `git add` + `git commit` across sub-agents in the same working tree is unsafe. Future-XL must use git worktrees per sub-agent OR cap concurrency at 1 (i.e. serial).
   **Where it's documented:** `docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md` "Methodology" section; this checkpoint Decision #2.

2. **Finding:** AUD-0227 (user-scoped authz) presupposes a user identity model that doesn't exist in tradelens.
   **How we discovered it:** the AUD-0227 sub-agent's stop-condition report — "There is NO user identity model in TradeLens: no `users` table, no auth headers in `frontend/web/src/lib/api.ts`, no JWT/session/login mechanism, single-user mode."
   **Time cost:** the sub-agent spent ~80 seconds investigating and stopped cleanly.
   **Implication:** AUD-0227 cannot be closed by middleware alone — it needs a 5-step epic. Reclassified to F.
   **Where it's documented:** `AUDIT_TRACKER.md` AUD-0227 row reclassification preamble.

3. **Finding:** AUD-0117's tracker row originally pointed at `lib/tradelens/api/trades.py:1648-1649` (the `time.sleep(0.5)` issue) — NOT the AI batch concern. The decisions-pending.md doc reframed AUD-0117 to mean the AI batch async-with-polling work. The original concern was lost from the tracker until reconciliation.
   **How we discovered it:** AUD-0117 sub-agent flagged it in the report: "AUD-0117 in the tracker is mislabeled... my fix did not touch [trades.py:1648-1649]."
   **Time cost:** ~10 minutes during reconciliation to verify and open AUD-0375.
   **Implication:** when re-scoping an audit ID mid-batch, ALWAYS open a new ID for the displaced original concern.
   **Where it's documented:** `AUDIT_TRACKER.md` AUD-0117 + AUD-0375 rows; reconciliation report.

4. **Finding:** AUD-0281's tracker row was a *positive* observation (vwap engines correctly use singleton_lock — flagged as good-pattern source for AUD-0182 to propagate). The XL-batch sub-agent landed a different fix (lease-refresh watchdog) and overwrote the tracker row text without preserving the original text anywhere.
   **How we discovered it:** during reconciliation, `git show 16538a38^^^^:tradelens/AUDIT_TRACKER.md | grep AUD-0281` recovered the pre-overwrite text.
   **Time cost:** ~5 minutes during reconciliation.
   **Implication:** opened AUD-0376 to capture the original observation as Resolved-as-WAI (since AUD-0182 has shipped propagation).
   **Where it's documented:** `AUDIT_TRACKER.md` AUD-0281 + AUD-0376 rows.

5. **Finding:** AUD-0341+0343 (trader_scorecard rewrite) requires a NEW database column on `trade_idea` (the `source_channel_key` column) AND parser updates in BOTH `bin/telegram_signals.py` and `lib/tradelens/discord/idea_creator.py`. Not a query rewrite alone.
   **How we discovered it:** the AUD-0341 sub-agent's test plan revealed it before any code shipped: "trade_idea ... needs `source_channel_key` column populated."
   **Time cost:** sub-agent stopped cleanly at the test-plan approval gate.
   **Implication:** reclassified to bucket C. Schema change → migration 079 needed.
   **Where it's documented:** `AUDIT_TRACKER.md` AUD-0341 row reclassification preamble.

6. **Finding:** Tracker line numbers for the original AUD-0117 / AUD-0375 concern said "trades.py:1648-1649" but the actual current location is `trades.py:1446`. ~200-line drift.
   **How we discovered it:** the AUD-0375 sub-agent's grep + line-count.
   **Time cost:** ~1 minute.
   **Implication:** future tracker rows that reference line numbers should be re-anchored when files have grown. Function names + brief descriptions are more durable than line numbers.
   **Where it's documented:** AUD-0375 commit body + this checkpoint.

7. **Finding:** the 1233 - 1205 = 28 pytest count gap after AUD-0375 ships breaks down as +10 from AUD-0375's own tests + 18 pre-existing tests in `tests/integration/test_level_b_health.py` (untracked, your parallel Level-B work).
   **How we discovered it:** sub-agent's pytest report cross-referenced against working-tree files.
   **Time cost:** N/A.
   **Implication:** the 1233-test baseline includes Level-B work that hasn't been committed yet. If Level-B's tests get reverted or moved, baseline drops back to ~1215.
   **Where it's documented:** AUD-0375 commit body.

8. **Finding:** `submit_trade` has NO internal Python callers — it's only invoked via FastAPI route dispatch.
   **How we discovered it:** `grep -rn "submit_trade(" lib/ bin/ tests/ | grep -v test_aud | grep -v "submit_trade_json\|def submit_trade"` returned empty.
   **Time cost:** ~30 seconds.
   **Implication:** safe to add `BackgroundTasks` parameter without breaking any caller. Critical fact for AUD-0375's safety analysis.
   **Where it's documented:** AUD-0375 commit body.

## Commands that mattered

1. **Command:** ```git log --oneline d44c5e3e^..9582b529```
   **Output (relevant portion):** showed `7725d660 refactor(level-b): rename soft_stop_* schema cols + reframe stop-specific wording (Phase 1+2)` between my reconciliation and the AUD-0375 ship — meaning Level-B parallel session committed during my AUD-0375 dispatch.
   **What we inferred:** confirmed parallel session activity is ongoing; AUD-0375 sub-agent had to navigate the working tree carefully. Final HEAD is correct.

2. **Command:** ```grep -nE "time\.sleep" lib/tradelens/api/trades.py```
   **Output (relevant portion):** `1446:                                    time.sleep(0.5)` — only one site.
   **What we inferred:** the AUD-0375 fix only had to modify one block; no scattered sleeps to chase.

3. **Command:** ```grep -nE "BackgroundTasks|asyncio" lib/tradelens/api/trades.py```
   **Output (relevant portion):** empty — no BackgroundTasks / asyncio imports.
   **What we inferred:** had to add `BackgroundTasks` to the imports. Sub-agent's prompt incorrectly claimed it was already imported (line 19) — that was for a different file (batch_ideas.py, line 19 has `from fastapi import APIRouter, BackgroundTasks, HTTPException, status`).

4. **Command:** ```grep -rn "submit_trade(" lib/ bin/ tests/ 2>/dev/null | grep -v "test_aud" | grep -v "submit_trade_json\|def submit_trade"```
   **Output (relevant portion):** empty.
   **What we inferred:** safe to add `BackgroundTasks` parameter without breaking call sites.

5. **Command:** ```PYTHONPATH=.:$PYTHONPATH pytest --tb=no -q```
   **Output (relevant portion):** `1205 passed, 4 skipped, 2 warnings in 53.67s` (during reconciliation) — and later `1233 passed, 4 skipped` (after AUD-0375).
   **What we inferred:** test suite is healthy; AUD-0375 added +10 tests; Level-B parallel work added +18.

6. **Command:** ```grep -cE "^\| AUD-.*\| Resolved " AUDIT_TRACKER.md```
   **Output:** `202` (after reconciliation tracker edits).
   **What we inferred:** tracker is at 202 R / 170 C / 8 S = 380 total rows (after opening AUD-0375 and AUD-0376). Checkpoint baseline: 178/190/9 at start of XL.

7. **Command:** ```git show 16538a38^^^^:tradelens/AUDIT_TRACKER.md 2>/dev/null | grep -E "^\| AUD-0281 "```
   **Output (relevant portion):** `| AUD-0281 | 9 | Major | Reliability | Confirmed | bin/engine/vwap_order_engine.py + vwap_series_worker.py | uses singleton_lock correctly | First subsystem in audit to enforce singleton via flock. ...`
   **What we inferred:** confirmed AUD-0281 was a positive observation pre-XL; the XL-batch sub-agent re-purposed the row. Drove the AUD-0376 opening during reconciliation.

8. **Command:** ```git show --stat 41255fe3 | head -20``` and ```git show --stat 8f7abdfa | head -25``` and ```git show --stat e9d15d3b | head -10```
   **Output (relevant portion):** 41255fe3 contains `journal.py` (149 lines) + `test_journal_aud0125_market_summary_single_query.py` (NEW) — actually AUD-0125 work, not AUD-0283. 8f7abdfa contains 11 files including AUD-0283 + AUD-0117 + AUD-0246 + AUD-0086 work. e9d15d3b contains `bybit_client.py` + `test_aud0086_instrument_info_ttl_cache.py` — actually AUD-0086, not AUD-0117.
   **What we inferred:** confirmed which commits actually contain which work. Drove the AUD-to-commit mapping table in the reconciliation report.

## Schema / API / data facts worth preserving

**Fact:** `submit_trade` in `lib/tradelens/api/trades.py` is a sync FastAPI route handler (`def`, line 990, ~1200 LOC) with NO internal Python callers — only invoked via `@router.post("/trades/submit", response_model=TradeSubmitResponse)`.
**Evidence:** `grep -rn "submit_trade(" lib/ bin/ tests/ | grep -v test_aud | grep -v "submit_trade_json\|def submit_trade"` returns empty.
**Why it matters:** safe to inject `BackgroundTasks` parameter without breaking any caller. This was the critical safety finding for AUD-0375.

**Fact:** TPs are tracked in `order_leg` table by `(trade_intent_id, leg_type='tp', exchange_order_id)` — `exchange_order_id` is the Bybit-returned order ID, set when the TP is placed via `bybit.place_order`.
**Evidence:** `lib/tradelens/api/trades.py:1547-1559` — `tp_leg_id = create_order_leg(conn, trade_intent_id=trade_intent_id, leg_type='tp', ..., exchange_order_id=tp_order_id, ...)`.
**Why it matters:** AUD-0375 background reconciler uses this triple to find existing TPs and amend them via `bybit.amend_order(order_id=exchange_order_id, price=...)`. Idempotent by construction.

**Fact:** `bybit.amend_order(category, symbol, order_id, price)` accepts a price-only amend and returns success or a benign error code (e.g., 110050 "no change") rather than rejecting. Already-filled orders return a different error class.
**Evidence:** `bybit_client.py:1232-1272` (cited by AUD-0375 sub-agent).
**Why it matters:** the AUD-0375 background helper's idempotency relies on this — re-running computes the same target price and amend is a no-op or benign error.

**Fact:** Bybit's `get_order_history` endpoint has read-after-write lag — immediately after placing a market order, the order may not yet appear with `avgPrice > 0`. Empirically takes ~50-500ms to propagate.
**Evidence:** the historical 3-attempts × 0.5s retry loop existed precisely for this reason; comment in trades.py near old line 1430-1432 said "Bybit read-after-write lag".
**Why it matters:** AUD-0375 background helper still uses 3-attempts × 0.5s — but in a background thread where blocking is safe.

**Fact:** Default FastAPI thread pool for sync endpoints is ~40 threads (anyio default, configurable).
**Evidence:** anyio's documented default + FastAPI source.
**Why it matters:** the AUD-0375 audit's "1.5s worker block" claim is per-request latency, not pool starvation. Real impact was the latency, not concurrency limits.

**Fact:** Migration 078 (market_candle PG schema) is applied to BOTH `tradelens` and `tradelens_test`.
**Evidence:** AUD-0270 sub-agent's report — "applied to both DBs ... 75 applied, 0 pending."
**Why it matters:** test DB schema parity preserved; integration tests can rely on `market_candle` existing.

**Fact:** the highest tracker ID is now AUD-0376 (was AUD-0374 at XL start).
**Evidence:** `grep -oE "AUD-0[0-9]+" AUDIT_TRACKER.md | sort -u | tail -3` returns `AUD-0374, AUD-0375, AUD-0376`.
**Why it matters:** next new tracker ID is AUD-0377.

**Fact:** the symlink `docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` points to `tradelens/AUDIT_TRACKER.md` (same inode; `file` reports "symbolic link").
**Evidence:** `ls -la docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` → `lrwxrwxrwx ... -> /app/syb/tradesuite/tradelens/AUDIT_TRACKER.md`.
**Why it matters:** edits to either path go to the same file. Symlink is untracked; harmless. Don't follow + commit it.

## Next steps

1. **Wait for the user's next instruction.** No autonomous next action is appropriate here — the user has explicitly thrown the throttle from XL-fast to one-narrow-thing-at-a-time.

2. If the user asks "what's next?" — point them at the reconciliation report's "Recommended next batch" section (`docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md`), with these top picks:
   - **AUD-0119** (BackgroundTasks for trade-event writes) — same pattern as AUD-0375, would be a good consistency follow-up.
   - **AUD-0271** (candle ingest `ON CONFLICT` batch) — biggest perf win on the bucket-C list.
   - **AUD-0341+0343** (trader_scorecard window functions + schema) — drafted test plan ready, awaiting C-bucket sign-off.

3. If the user wants a `/t-done`: the session has touched many AUD-IDs across many commits, but the only uncommitted work right now is none from me; user's parallel Level-B files are untracked and not mine. A `/t-done` would close the orphan task `20260426-aud0270-ddl-to-migration` (verify with the user first — that task ID is misleading vs. what we actually did this session).

4. If the user wants a fresh AUD-tracker re-baseline: run `grep -cE "^\| AUD-.*\| Resolved " AUDIT_TRACKER.md && grep -cE "^\| AUD-.*\| Confirmed " AUDIT_TRACKER.md && grep -cE "Suspicious|Needs verification" AUDIT_TRACKER.md`.

5. If the user wants to verify AUD-0375 is real: run `git show 9582b529 --stat`, then `pytest tests/integration/test_aud0375_tp_background_reconcile.py -v` and confirm 10/10 pass.

## Verification checklist for the next session

1. `git rev-parse --short HEAD` returns `9582b529`. (If different, work has continued and this checkpoint is stale.)
2. `git status --short` shows ONLY the same untracked files listed in "Working environment" (Level-B health files, `docs/chat.txt.gz`, `.claude/` system dirs, audit-autofix symlink).
3. `grep -E "^\| AUD-0375 " AUDIT_TRACKER.md` returns a row with status `Resolved`.
4. `grep -E "^\| AUD-0376 " AUDIT_TRACKER.md` returns a row with status `Resolved` and "Original AUD-0281 row content" in the body.
5. `PYTHONPATH=.:$PYTHONPATH pytest tests/integration/test_aud0375_tp_background_reconcile.py -q` returns 10 passed.
6. `grep -nE "time\.sleep" lib/tradelens/api/trades.py` returns at most one match — at the line where the helper `_reconcile_market_entry_tps` lives (around trades.py:3272), NOT inside `submit_trade`'s body.
7. `grep -n "BackgroundTasks" lib/tradelens/api/trades.py | head -3` shows the import + the parameter on `submit_trade`'s signature.
8. `claude-task current` returns `20260426-aud0270-ddl-to-migration` (the orphan).
9. `ls /app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/xl-session-reconciliation-2026-04-26.md` exists.
10. The user has NOT given a new instruction since "Proceed with AUD-0375 only" was satisfied.
