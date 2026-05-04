# Checkpoint: lineage repair tool built + dry-run verified, awaiting --apply on prod for trade 2449

**Saved:** 2026-04-26 14:36:57 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ c462004a
**Session:** 64cb01e6-ffc8-44dd-b0bd-8aa861cf0b6a (this is a /branch session forked off original 5e639453-...; both share the master branch)
**Active task:** none (the propagation fix at c462004a was the last `claude-task done`; the repair-tool tranche is uncommitted, no task created yet)

## Handover Statement

You are picking up a session that has been working through Layer B / `breach_decision` Stage 1 production-rollout debugging on a Bybit DEMO account (NOT real money — ignore any "URGENT" framing in earlier handoffs). The user manually opened **trade 2449** (BTCUSDT long, qty 0.145, entry 77,935.6, opened 14:35 UTC+2 today) specifically to test the breach-decision pipeline end-to-end. That single trade has now surfaced **three distinct bugs**, each addressed in its own tight tranche today: (1) a level-mind worker write-persistence regression (commit `3da2fdcf` on master), (2) a `lineage_id` propagation bug across leg-creation paths (commit `c462004a` on master), and (3) the **uncommitted** lineage-repair tool for existing open trades whose legs already landed mismatched. The repair tool is the in-flight tranche.

**The single most important piece of state right now:** the repair tool is **written, tested (6/6 passed targeted, 1407 passed full gate), and dry-run-verified on prod for trade 2449's group**, but has NOT been committed and has NOT been `--apply`'d on prod. Do NOT re-write the tool, do NOT alter creation paths again, do NOT touch breach_decision code. Two new files exist in the working tree: `bin/tools/repair_trade_lineage.py` and `tests/integration/test_repair_trade_lineage.py`. Nothing else of mine is pending.

**Read FIRST, in order:** (a) the "Files touched" section below, especially #1 (the repair tool), to know what was written; (b) the "Decisions made" section, especially decisions 1–4, to know why the repair rule chose oldest-non-NULL anchor over alternatives; (c) the "Surprises / gotchas" section before running the tool with `--apply`; (d) the dry-run output verbatim in "Commands that mattered" #4. Pay special attention to the trade 2449 leg ID drift — leg `1766` (TP1) was archived to `order_leg_hist` when the autocommit fix executed it at 14:07:28; the level-guard daemon recreated TP1 as id `1767` shortly after. The repair plan correctly targets the live IDs `1764` (Stop) and `1767` (TP1).

**Known landmines:** (i) `psycopg2.pool.ThreadedConnectionPool` returns connections with `autocommit=False` by default — every previously-committed worker fix had to set autocommit-per-acquire (see commit `3da2fdcf` and the codebase-wide invariant test at commit `3d68f177` from the parent session); (ii) the breach-decision orchestrator's `check_sibling_hard_stop` groups by `(account_id, symbol, position_idx, lineage_id)` so any tool that touches `order_leg_live.lineage_id` must preserve hedge-mode separation (`position_idx 1 = long`, `position_idx 2 = short`, NULL = unknown — `IS NOT DISTINCT FROM` semantics); (iii) the user's bibyt_demo account is **`account_id = 3`**, not the more-common `account_id = 1`; (iv) trade 2449's other legs include a Bybit-side "TP2" with id `1763` lineage `2881bf6c-…` which is the OLDEST non-NULL leg → this is the correct anchor.

**What NOT to do:** do not edit the trade-creation paths again (commit `c462004a` already covered the four leg-creation sites); do not change the orchestrator's `check_sibling_hard_stop` SQL shape (out of scope per the user's brief); do not flip `breach_decision.require_confirmed_hard_stop` to `false` as a substitute for the repair (it's a workaround the user already knows about); do NOT run the repair tool with `--apply` on the global scope without reading the dry-run output first — there are 12 broken open-trade groups on prod and the user only explicitly approved trade 2449.

**Exact next action the user is expecting:** the user just answered "what's next?" with a recommendation that includes (a) `/t-done` to commit the repair tool, then (b) operator runs `bin/tools/repair_trade_lineage.py --account-id 3 --symbol BTCUSDT --apply` to fix trade 2449. The user has not yet confirmed they want to proceed. They're expected to either invoke `/t-done` (your cue to commit the two new files), or redirect to a different tranche (ATR freshness or B6 worker wiring per the queued list). Do NOT proactively commit; wait for `/t-done`.

## Session context

### User's stated goal (verbatim where possible)

The most recent task brief from the user, opening this tranche:

> "Start a tiny follow-up tranche: repair lineage_id for currently open existing trades only. Goal: For existing open trades whose legs already have mismatched or NULL lineage_id values, align all legs in the same trade group to the oldest non-NULL sibling lineage so breach-decision hard-stop sibling detection works immediately without needing a brand-new trade."

Scope constraints they imposed verbatim:

> "Smallest possible diff / Prefer one repair tool / one-off SQL / admin-safe script / Do not change schema / Do not touch breach_decision / Do not touch ATR / Do not change creation paths again / This is repair for existing rows only"

Their broader queued tranche order, stated earlier today:

> "next discussion should be about the secondary issues: lineage propagation across legs / ATR candle freshness / then sidecar worker wiring"

Lineage propagation (item 1) was committed earlier as `c462004a`. The repair tool (this tranche) is the natural follow-on for the existing-data side of lineage. ATR freshness and sidecar wiring remain in the queue.

### User preferences and corrections established this session

These are not just for this tranche — they apply to all today's work and should be preserved across sessions:

- **"this trade/order is on bybit demo account so NOT real money (ignore the real money messages and URGENT messages)"** — Trade 2449 is on `account_id = 3` (`bybit_demo`). Earlier diagnostic handoffs framed the broken handoff as urgent / real money; the user explicitly downgraded that framing. Future debugging should treat this as a controlled test environment, not a money-at-risk emergency.

- **"Do not commit until you report back."** — Reproduced verbatim across multiple tranches today. The user wants to see the report before authorizing commit. Apply this default behaviour for any future fix tranche.

- **"Keep the patch tight and focused on trade/leg creation and any related propagation/update paths."** (lineage propagation tranche). And later: **"Smallest possible diff."** (repair tool). The user values tight, mechanical, scope-bounded changes; resist the temptation to widen.

- **"Do not touch breach_decision code in this tranche unless a tiny test fixture update requires it."** — Repeated across both lineage tranches. The breach-decision package was the subject of a separate prior rename and is currently working; do not re-edit unless the user explicitly opens it back up.

- **"Do not touch ATR in this tranche / Do not do sidecar worker wiring in this tranche."** — These are queued for separate tranches in the order specified above.

- **Tone preference observed:** the user prefers crisp report sections (files changed, root cause, fix, test results, tranche-safe-to-commit?) over long explanatory prose. They re-prompt "what's next?" when ready to move on rather than asking for narrative wrap-up.

### Working environment

- **Live daemons (started via `tl` earlier this session):**
  - `level-mind` — PID 1111560 since restart at 14:07:15Z (the autocommit fix's verification restart). Orchestrator initialised at 14:07:21Z with `symbols=['BTCUSDT', 'ETHUSDT'], require_confirmed_hard_stop=True, min_completeness_for_ok=0.70, recent_trade_timeout_s=2.00`.
  - `level-guard` — PID 913656, monitoring 4 guards: g59 (ONDOUSDT), g60 (AKTUSDT), g62 (BTCUSDT, trade 2449's TBE — already executed at 14:07:28Z, archived to hist as id 2737), g63 (BTCUSDT, trade 2449's TP1).
  - `breach-decision-label-backfill` — PID 902266, polling every 60s; `{candidates: 0, labelled: 0, no_data: 0}` on each cycle.
  - `breach-decision-outcome-backfill` — PID 902331, polling every 60s; `{candidates: 0, finalised: 0, always_only: 0, no_guard_id: 0}`.

- **Trade 2449 current state on prod (account_id=3, BTCUSDT, long, position_idx=1):**
  - `order_leg_live`: 3 rows live now — `1763` (TP2, lineage `2881bf6c-…`, status `new`), `1764` (Stop, lineage `5e4393fe-…`, status `untriggered`), `1767` (TP1 recreated after archival, lineage `NULL`, status `guarded`).
  - `order_leg_hist`: row `2737` (TBE archived after the autocommit-fix verification successfully closed 0.036 BTC at market via Bybit demo order `2e3fc8f9-d2c9-4d6a-84a7-a0876466b503`).
  - Position size now ~0.109 (down from 0.145 by the 0.036 TBE close).
  - Mark price last seen ~77,803 (well below the 77,910 TBE level — but TBE already executed; the remaining guard is TP1 @ 77,990, still armed since price is below).

- **Test DB (`tradelens_test`):** clean, baseline state (3 rows in `accounts`, everything else empty per the conftest leak detector).

- **Git working tree:** master @ c462004a + uncommitted repair-tool tranche files. Pre-staged `test_pool_getconn_autocommit_invariant.py` from the parent session was committed independently as `3d68f177` between my two earlier commits. `claude-task status` reports no active task.

- **Branched conversation:** the original `claude-task` session was `5e639453-…`; the user invoked `/branch` mid-session and the new session ID is `64cb01e6-…`. Tasks created earlier (under the original session ID) live in that prior session's history; tasks created in this branch live in `64cb01e6-…`. The `claude-task history` output therefore looks shorter in the branch than the actual list of commits would suggest. Commits on master are shared regardless.

## Objective

The conversation's overall objective is **bringing Stage 1 of the breach-decision predictor to clean operational state on production tradelens (Bybit demo account)**, by clearing every defect surfaced by the user-created live test trade #2449. Three defects were discovered during a single breach event today; today's three tranches address them in order.

The current sub-objective is the **third tranche** — a repair tool that aligns `lineage_id` across legs of currently-open trades whose existing data is already broken. The earlier propagation fix (commit `c462004a`) ensures NEW trades created from now on have consistent lineage; this tranche fixes the in-flight existing trades (most importantly trade 2449 itself, plus 11 other broken groups detected on prod) without forcing the user to close-and-reopen them.

Explicitly **in scope:** a Python CLI repair script with `--dry-run` (default) and `--apply`, narrow filters (`--account-id`, `--symbol`), idempotent SQL UPDATE, integration tests against `tradelens_test`. Explicitly **out of scope:** schema changes, breach_decision changes, creation-path changes, ATR freshness, sidecar wiring, retroactive `order_leg_hist` repair, daemon restarts.

## Narrative: how we got here

**Earlier today (parent session)** completed several Layer B tranches: the rename from `level_b` → `breach_decision` (commit `2ceefdc7`), the B6 websocket tick sidecar lib + orchestrator seam (commit `d7eef05d`), the operator runbook + readiness check (commit `02ae8037`), and `tl` registration of the backfill daemons (commit `752a722b`). Then the user manually applied migration 079 to prod and started both backfill daemons under the renamed names.

**The user then created trade 2449 manually on Bybit demo** to test the pipeline end-to-end. Mark price was sitting at ~77,935 with stop at 74,500 and two guarded legs: TBE @ 77,910 (id 1765) and TP1 @ 77,990 (id 1766). The user said "keep an eye on it" so I started observational monitoring. The parent session at this point ran `/branch` — the conversation forked into this branch session.

**At ~12:50 UTC the price breached the 77,910 TBE level going down.** The level-mind worker correctly detected the breach, ran a 5-second reclaim window, and made an `action=execute, classification=accept, decision_reason=timeout_execute` decision at 12:50:42Z. But the level-guard daemon — which is the actual order-placer reading from `level_mind_response` — never picked it up. The TBE order on Bybit was NOT closed. I went to investigate.

**The investigation surfaced three distinct issues, each its own tranche:**

**Bug 1 (level-mind write persistence — commit `3da2fdcf`):** Querying showed `level_mind_response` had ZERO rows for guard 62's subscription, even though the worker logged `EVENT action=execute`. Tracing the worker code revealed: post-AUD-0291 (Apr 23 commit `8213fb9a`), monitor threads switched to `conn = self._pool.getconn(); db = PostgresDB(connection=conn)`. `psycopg2.pool.ThreadedConnectionPool` returns connections with `autocommit=False` (psycopg2 default). `PostgresDB(connection=external_conn)` deliberately preserves caller session state. Combined with the worker having zero `conn.commit()` calls anywhere, every monitor-thread write since Apr 23 had been silently rolling back on `pool.putconn()`. Latest persisted row in `level_mind_response` was 8 days old. I added `conn.autocommit = True` after `getconn()` in `_monitor_guard`, plus an AST guard in `tests/unit/test_level_mind_worker_pool.py` and a 4-test integration suite at `tests/integration/test_level_mind_worker_persistence.py`. Restarted `tl level-mind`. Trade 2449's TBE then breached again, the worker wrote the response row correctly, level-guard picked it up, submitted Bybit demo order `2e3fc8f9-d2c9-4d6a-84a7-a0876466b503`, leg 1765 archived to `order_leg_hist` as id 2737. Position size dropped from 0.145 to 0.109. End-to-end handoff verified working. After commit, the parent session also added a codebase-wide AUD-0291 invariant test (commit `3d68f177`) so this regression class can't reappear silently.

**Bug 2 (lineage_id propagation in creation paths — commit `c462004a`):** The hard-stop precondition rows for trade 2449 had been emitted as `status='skipped' status_detail='hard-stop precondition not met'` because `breach_decision/orchestrator.py:check_sibling_hard_stop` groups siblings by `lineage_id` AND the four legs of trade 2449 had four different lineage values (stop=`5e4393fe-…`, TP2=`2881bf6c-…`, TBE=NULL, TP1=NULL). Five distinct creation paths each had their own `lineage_id` default and none looked up siblings. I built a single helper `lib/tradelens/services/trade_lineage.py:derive_lineage_id(cursor, account_id, symbol, position_idx, fallback)` that returns the oldest existing sibling's `lineage_id` (matched on `account_id` + `symbol` + `position_idx` via `IS NOT DISTINCT FROM`) or the caller's fallback. Applied at four sites: (i) `lib/tradelens/api/open_orders.py:4123` (new-guard via API — this site had `lineage_id` MISSING from the INSERT column list entirely, the bug-fix root cause for TBE/TP1 NULL), (ii) `bin/pipeline/refresh_order_leg_live.py:1880` (auto-TBE on breakeven trigger), (iii) `bin/pipeline/refresh_order_leg_live.py:2376` (refresh ingest of fresh exchange orders), (iv) `bin/tools/levelguard_cli.py:261`. Did not touch the amend path (already preserves lineage), the stale-order recreation path (already preserves), suspend/resume (uses snapshot), or the LIVE→HIST archival (HIST inherits from LIVE). Tests: 9 unit tests on the helper + 2 integration tests including a trade-2449 replay. Full gate green at 1397/4/0.

**Bug 3 (lineage repair for existing data — UNCOMMITTED, this tranche):** Even with bug 2 fixed, trade 2449's persisted legs still have their broken lineage values — the propagation fix only helps NEW trades. The user asked for a "tiny follow-up tranche" to repair existing open trades. I grounded by querying prod and found 12 broken groups (11 on `account_id=1`, 1 on `account_id=3` which is trade 2449). Built `bin/tools/repair_trade_lineage.py` with pure helpers `compute_repair_plan(cursor, ...)` and `apply_repair_plan(cursor, action)` plus argparse `main()`. Repair rule: for each broken group, anchor = oldest non-NULL lineage; if all NULL, anchor = oldest leg's `exchange_order_id`. Applied via `UPDATE order_leg_live SET lineage_id = <anchor>, updated_at = NOW() WHERE id = ANY(<misaligned ids>)`. 6 integration tests cover the trade 2449 replay, all-NULL seeding, already-aligned no-op, idempotence, group isolation, and terminal-status exclusion. Full gate is at 1407/4/0. Live dry-run on prod for trade 2449 produced a clean plan: anchor `2881bf6c-…` (from leg id 1763), 2 legs to update: `[1764, 1767]`. Tool is executable, tests are green, dry-run output verified. Commit + apply pending user authorization.

**The user then asked "whats next?"** I responded with a recommendation to commit-and-apply the repair, then move to ATR (the next queued tranche), with B6 worker wiring after. The user followed up with `/t-checkpoint` rather than confirming a path, which is why we're here now.

## Work done so far

1. **Investigated trade 2449's broken handoff** by querying `level_mind_response`, `level_guard_attempt`, `level_guard`, `order_leg_live`, and tailing `logs/level_mind_worker.log` + `logs/level_guard_daemon.log`. Discovered zero rows in `level_mind_response` for guard 62 and traced the cause to missing `conn.commit()` in the worker.

2. **Wrote and applied the autocommit fix** at `bin/server/level_mind_worker.py:819-823` (added `conn.autocommit = True` after `self._pool.getconn()` plus a 9-line comment block referencing AUD-0291). Saved + committed as `3da2fdcf`.

3. **Added AST guard `test_monitor_guard_sets_autocommit_after_pool_acquire`** to `tests/unit/test_level_mind_worker_pool.py`, ensuring future refactors can't strip the autocommit assignment without failing tests. Committed in `3da2fdcf`.

4. **Built `tests/integration/test_level_mind_worker_persistence.py`** — 4 tests including a positive `_write_event` round-trip via fresh connection, a negative control demonstrating the failure mode, `_mark_active` status flip persistence, and `_write_state_snapshot` cross-connection visibility. Committed in `3da2fdcf`.

5. **Restarted `tl level-mind` (PID 913711 → 1111560)** and observed trade 2449's TBE leg breach again at 14:07:22Z, with the worker correctly persisting to `level_mind_response` (7 rows for that subscription) and the level-guard daemon submitting Bybit demo order `2e3fc8f9-d2c9-4d6a-84a7-a0876466b503` at 14:07:28Z. End-to-end persistence verified.

6. **Built `lib/tradelens/services/trade_lineage.py`** containing `derive_lineage_id(cursor, *, account_id, symbol, position_idx, fallback) -> str`. Pure helper, takes a cursor, returns the oldest non-NULL sibling's lineage or the caller's fallback. ~80 LOC including the docstring. Committed in `c462004a`.

7. **Added `lib/tradelens/api/open_orders.py:4116-4144`** edit: imported `derive_lineage_id`, added `lineage_id` to the column list of the new-guard INSERT (was missing entirely), and computed it from the helper before INSERT. This is the root-cause fix for trade 2449's TBE/TP1 having NULL lineage. Committed in `c462004a`.

8. **Edited `bin/pipeline/refresh_order_leg_live.py:1846-1898`** (auto-TBE creation): replaced `synthetic_oid` self-referencing lineage with a `derive_lineage_id` lookup. Plus `bin/pipeline/refresh_order_leg_live.py:2375-2402` (refresh ingest): replaced `leg.get('lineage_id', leg['exchange_order_id'])` with explicit-lineage-or-helper-or-fallback chain. Imported the helper at the top of the file. Committed in `c462004a`.

9. **Edited `bin/tools/levelguard_cli.py:259-308`** (CLI tool): added `lineage_id` to the column list of the INSERT and computed it from the helper. Imported the helper. Committed in `c462004a`.

10. **Added `tests/unit/test_trade_lineage.py`** — 9 unit tests on the helper covering fallback, sibling resolution, oldest-wins, position_idx separation, account/symbol separation, NULL-row skipping, real-vs-NULL coexistence, NULL-vs-zero distinction. Committed in `c462004a`.

11. **Added `tests/integration/test_trade_lineage_propagation.py`** — 2 tests: end-to-end trade 2449 creation-order replay (TP first, stop second, TBE third, TP1 fourth — all converge on the first anchor) and a negative test ensuring independent positions don't cross-link. Committed in `c462004a`.

12. **Wrote `bin/tools/repair_trade_lineage.py`** — UNCOMMITTED. ~250 LOC including docstring. Pure helpers `compute_repair_plan(cursor, *, account_id_filter, symbol_filter) -> List[RepairAction]` and `apply_repair_plan(cursor, action) -> int`, plus argparse `main()` with `--dry-run` (default), `--apply`, `--account-id`, `--symbol`. Marked executable. Tested.

13. **Wrote `tests/integration/test_repair_trade_lineage.py`** — UNCOMMITTED. 6 tests: trade 2449 replay (3 legs, 2 distinct lineages + 1 NULL → all converge on oldest non-NULL), all-NULL seeding (anchor from oldest leg's exchange_order_id), already-aligned no-op, idempotence, group isolation across position_idx and account_id, terminal-status legs excluded.

14. **Verified the repair tool by dry-run on prod** for trade 2449's group: `bin/tools/repair_trade_lineage.py --account-id 3 --symbol BTCUSDT` returned a clean plan (anchor `2881bf6c-45d5-4887-beb6-a3b3a08c99af` from leg id 1763, 2 legs to update: [1764, 1767]). No rows were written.

15. **Ran the targeted suite (`pytest tests/integration/test_repair_trade_lineage.py -v`)** — 6/6 passed. Then the full project gate (`scripts/check-tests.sh`) — 1407 passed, 4 skipped, 0 failed. Confirmed safe-to-commit.

## Decisions made (and why)

1. **Decision:** The repair tool is a Python CLI script, not a one-off SQL file or psql `.sql` invocation.
   **Proposed by:** Claude (within scope the user explicitly granted: "Prefer one repair tool / one-off SQL / admin-safe script").
   **Rationale:** A Python script can ship with `--dry-run` as default + structured logging + integration tests against `tradelens_test`. Pure SQL would have been smaller but harder to test and gives operators no preview before applying. The user's brief explicitly listed CLI tool as one acceptable form.
   **Alternatives considered:** raw SQL file in `bin/setup/` (rejected: no dry-run preview, no integration tests, harder for operators to scope by account/symbol). Inline psql one-liner in a runbook (rejected: same reasons, plus operators can't scope easily).
   **Revisit if:** future repair patterns warrant a more general "data-fix" framework — at that point this script could be the first concrete instance.
   **Affects:** Files touched #1, #2; Test results.

2. **Decision:** Repair anchor = oldest existing non-NULL `lineage_id` in the group; if all NULL, seed from the oldest leg's `exchange_order_id`.
   **Proposed by:** Claude (consistent with the propagation helper from commit `c462004a`).
   **Rationale:** This rule mirrors the propagation helper's semantics so repair and propagation produce equivalent results. "Oldest" is `MIN(id)` because new orders get sequential ids; the first leg of a trade is always the lowest id. Seeding from `exchange_order_id` for all-NULL groups keeps the property "trade lineage is anchored on the first leg's exchange-side identity" consistent with how new trades are seeded.
   **Alternatives considered:** (a) Generate a fresh UUID per broken group (rejected: violates the existing convention that lineage = first-leg's exchange_order_id; would create lineages that don't trace back to any real order). (b) Use `MAX(id)` as anchor (rejected: would rewrite the oldest legs' lineages and break the "first-leg anchors the trade" invariant). (c) Pick by leg-type priority (e.g. stop > tp > tbe) (rejected: not all trades have stops; would diverge from propagation rule).
   **Revisit if:** the propagation rule itself changes — they must stay synchronised.
   **Affects:** the SQL-shape of `compute_repair_plan` in `bin/tools/repair_trade_lineage.py`; the test assertions in `tests/integration/test_repair_trade_lineage.py:test_trade_2449_replay_*` and `test_all_null_group_seeds_anchor_from_oldest_leg_exchange_order_id`.

3. **Decision:** Filter out terminal-status legs (`Cancelled`, `Filled`, `Rejected`) from the repair scope.
   **Proposed by:** Claude.
   **Rationale:** Those rows represent historical state — a leg that was cancelled or filled is past tense; rewriting its lineage years after the fact would corrupt audit trails and change analytics outputs. The breach-decision orchestrator only queries active statuses anyway, so closed legs don't impact the bug.
   **Alternatives considered:** Repair every row regardless of status (rejected: blast-radius; would change persisted analytics). Use a tighter "active" filter matching `breach_decision/orchestrator.py:ACTIVE_ORDER_STATUSES = ('new','untriggered','partiallyFilled','guarded')` (considered: stricter — but excludes legitimate active-but-uncategorised statuses; the negative filter is safer).
   **Revisit if:** we discover an active status not in the negative-filter set; or if analytics start needing repaired historical lineage.
   **Affects:** `_TERMINAL_STATUSES` constant in the repair tool; `test_terminal_status_legs_are_excluded_from_repair`.

4. **Decision:** Default mode is `--dry-run`; `--apply` must be explicit.
   **Proposed by:** Claude.
   **Rationale:** Operator safety. The user is comfortable running `--apply` themselves; the tool's job is to make the preview obvious and the apply opt-in. This matches the `migrate.py up --dry-run` convention already in the codebase.
   **Alternatives considered:** Apply by default, `--dry-run` opt-in (rejected: easy to fat-finger; mismatches operator expectations).
   **Revisit if:** never. Default-safe is the right ergonomics for any data-mutating tool.
   **Affects:** the argparse setup in `main()`; the readme/docstring at the top of the file.

5. **Decision:** The repair tool's `apply_repair_plan` runs each group in its own cursor but commits after ALL groups complete.
   **Proposed by:** Claude.
   **Rationale:** Atomicity per `--apply` invocation — either every group is repaired or none. Partial application is harder to reason about than all-or-nothing. A single operator command produces a single audit-trail commit.
   **Alternatives considered:** Commit per group (rejected: half-applied state on early error; harder to roll back). Single explicit BEGIN/COMMIT around the loop (effectively what we do, but the loop happens under one connection).
   **Revisit if:** scaling: if the tool ever needs to repair tens of thousands of groups at once, batched commits become useful. Today's count is 12.
   **Affects:** the `try / except / finally / commit / rollback` structure of `main()`.

6. **Decision:** Do NOT touch `order_leg_hist`. Repair is `order_leg_live`-only.
   **Proposed by:** Claude.
   **Rationale:** Hist is historical record; mutating it changes journal analytics. The breach-decision orchestrator only queries `order_leg_live`. Future legs that archive from LIVE will inherit the repaired lineage automatically (per `level_guard_daemon.py:402` which copies LIVE's `lineage_id` to HIST on archive).
   **Alternatives considered:** Repair both tables (rejected: hist-side is analytics-relevant; one-off rewrite would invalidate existing reports without recourse).
   **Revisit if:** journal analytics start depending on cross-trade lineage grouping (today they don't).
   **Affects:** the WHERE clause in `compute_repair_plan`; the docstring.

## Rejected approaches (and why)

1. **Approach:** Fix only the level-guard creation path at `open_orders.py:4123` (add `lineage_id` to the INSERT) and call it done — leave the refresh pipeline's per-leg default in place.
   **Who proposed it:** Claude considered this as a minimal-diff option during the lineage propagation tranche.
   **Why rejected:** This would only have fixed the symptom for new guarded legs (which is what trade 2449's TBE/TP1 needed), but the underlying problem is broader — the refresh pipeline ingesting fresh exchange orders also creates per-leg lineages for stop/TP that never converge with the trade's other legs. The user's brief explicitly stated "Every leg that belongs to the same trade must carry the same lineage_id, including … stop, tp, dca". A symptom-only fix would have shipped a partial solution that still required the same repair work later.
   **Would we reconsider if:** the user explicitly said "for now only fix the level-guard creation path; we'll revisit refresh ingest later" — they did not.

2. **Approach:** Add a new `trade_id` column to `order_leg_live` and have the orchestrator group by `trade_id` instead of `lineage_id`.
   **Who proposed it:** Claude considered this during plan design for the propagation tranche.
   **Why rejected:** Three reasons: (i) the user's brief said "Do not change schema"; (ii) it would require modifying `breach_decision/orchestrator.py:check_sibling_hard_stop` which the brief excluded; (iii) the existing `lineage_id` semantics already cover trade-grouping correctly when propagated, and the `level_guard.trade_id` column is already available for analytics outside the orchestrator's hot path. Adding a column for redundancy with `lineage_id` would create two divergent grouping keys.
   **Would we reconsider if:** the user opens a tranche to overhaul the trade-grouping model — at that point a column rename and orchestrator refactor become viable together.

3. **Approach:** Use a freshly-generated UUID as the anchor for broken groups.
   **Who proposed it:** Claude considered briefly during decision 2 above.
   **Why rejected:** Breaks the existing "lineage = first-leg's exchange_order_id" convention. Operators expect to be able to grep prod logs / databases for the lineage and find a real Bybit order. A synthetic UUID disconnects the lineage from any actual order's exchange-side identity.
   **Would we reconsider if:** we add a separate trade-uuid column and migrate analytics to it — then synthetic lineages become valid.

4. **Approach:** Apply the repair globally as part of the deploy / `migrate.py up` flow.
   **Who proposed it:** Claude considered briefly when scoping the tool.
   **Why rejected:** Repair tools should be operator-invoked and reviewable, not auto-applied during deploy. Deploys happen frequently; this repair should run at most once per affected trade and ideally just once globally. Tying it to migrations would also conflate schema migrations with data fix-ups, blurring responsibilities.
   **Would we reconsider if:** we hit a class of bugs that needs immediate repair on every deploy — that would be its own infrastructure decision, not specific to this tool.

5. **Approach:** Bypass the bug entirely by setting `breach_decision.require_confirmed_hard_stop: false` in `etc/config.yml`.
   **Who proposed it:** the user asked about it earlier in the diagnosis phase as a workaround.
   **Why rejected (as a substitute for the repair):** Setting that config flag bypasses the hard-stop precondition globally — affecting every guard, not just trade 2449. The orchestrator would then run on breaches that have NO sibling stop in place, which is operationally less safe. Better to repair the data than to weaken the precondition.
   **Would we reconsider if:** the user explicitly wants to weaken the precondition for unrelated reasons (e.g. for testing predictor behaviour without the gate) — but not as the substitute fix for trade 2449.

## Files touched or about to touch

1. `/app/syb/tradesuite/tradelens/bin/tools/repair_trade_lineage.py:1-265`
   - **Status:** edited-saved, NOT committed.
   - **What's there:** Stand-alone CLI repair tool. Top-level dataclasses `GroupKey` and `RepairAction`. Pure helpers `compute_repair_plan(cursor, *, account_id_filter=None, symbol_filter=None) -> List[RepairAction]` and `apply_repair_plan(cursor, action) -> int`. CLI rendering helpers `_short(s, n=12)` and `render_plan_text(actions) -> str`. `main(argv=None) -> int` opens `PostgresDB(config.database)`, calls compute, optionally applies, commits.
   - **What we changed (or plan to change):** Newly written. The file did not exist before. Marked executable via `chmod +x`.
   - **Why it matters:** This is the deliverable of the current tranche. Without it, trade 2449's existing legs stay broken and the breach-decision orchestrator emits `status='skipped'` rows on every breach.
   - **Cross-refs:** Decisions 1, 2, 3, 4, 5, 6 all anchor to this file. Open thread #1 (commit) and #2 (apply on prod). Tests file in #2 below verifies behaviour.

2. `/app/syb/tradesuite/tradelens/tests/integration/test_repair_trade_lineage.py:1-274`
   - **Status:** edited-saved, NOT committed.
   - **What's there:** 6 integration tests using `test_db_conn` rollback fixture. `_seed_leg(cursor, ...) -> (id, exchange_order_id)` and `_read_lineage(cursor, leg_id) -> Optional[str]` helpers. The 6 tests are: `test_trade_2449_replay_all_legs_converge_on_oldest_non_null_lineage` (the load-bearing one — replays trade 2449's exact data shape and asserts the breach-decision sibling-stop SQL would match post-repair), `test_all_null_group_seeds_anchor_from_oldest_leg_exchange_order_id`, `test_already_aligned_group_produces_no_action`, `test_apply_repair_is_idempotent`, `test_repair_does_not_bleed_across_position_idx_or_account`, `test_terminal_status_legs_are_excluded_from_repair`.
   - **What we changed (or plan to change):** Newly written. Imports the repair tool via `importlib.util.spec_from_file_location` (the tool is a CLI script not on the package path).
   - **Why it matters:** Pins the repair contract — anchor selection, idempotence, group isolation, terminal-status exclusion. If a future change to the tool regresses any of these, these tests catch it immediately.
   - **Cross-refs:** Decisions 2, 3, 5, 6.

3. `/app/syb/tradesuite/tradelens/lib/tradelens/services/trade_lineage.py:1-86` (ALREADY COMMITTED in `c462004a`)
   - **Status:** committed.
   - **What's there:** `derive_lineage_id(cursor, *, account_id, symbol, position_idx, fallback) -> str` — the helper used by all four leg-creation paths to look up an existing sibling's lineage or fall back to a caller-provided seed.
   - **Why it matters:** The repair tool's anchor-selection logic mirrors this helper's semantics so repair and propagation produce equivalent results. Decision 2 anchors here.
   - **Cross-refs:** Decision 2; Open threads #1, #2.

4. `/app/syb/tradesuite/tradelens/bin/server/level_mind_worker.py:819-823` (ALREADY COMMITTED in `3da2fdcf`)
   - **Status:** committed.
   - **What's there:** `conn = self._pool.getconn(); conn.autocommit = True; db = PostgresDB(connection=conn)` plus a 9-line comment block above the `autocommit=True` line.
   - **Why it matters:** The autocommit fix is what made trade 2449's TBE close at 14:07:28Z. The level-mind worker would still be silently rolling back writes without this. This file should NOT be touched again in current tranches.
   - **Cross-refs:** Surprise #1; Open thread #4 (don't re-edit).

5. `/app/syb/tradesuite/tradelens/lib/tradelens/breach_decision/orchestrator.py:188-256` (READ ONLY — did not edit)
   - **Status:** read-only reference.
   - **What's there:** `check_sibling_hard_stop(cursor, ctx) -> bool`. SQL: `SELECT 1 FROM order_leg_live WHERE account_id=? AND symbol=? AND id!=ctx.order_leg_live_id AND trigger_price IS NOT NULL AND status = ANY(ACTIVE_ORDER_STATUSES) AND position_idx IS NOT DISTINCT FROM ctx.position_idx AND lineage_id = ctx.lineage_id LIMIT 1` (or `lineage_id IS NULL` when ctx.lineage_id is NULL). `ACTIVE_ORDER_STATUSES = ('new','untriggered','partiallyFilled','guarded')`.
   - **Why it matters:** This is the consumer of `lineage_id` whose precondition fails when legs disagree. The repair tool's correctness criterion is "after apply, this query finds the stop sibling from the guarded leg's perspective". Test #1 in file #2 asserts exactly this.
   - **Cross-refs:** Decisions 2, 3.

6. `/app/syb/tradesuite/tradelens/lib/tradelens/api/open_orders.py:4116-4144` (ALREADY COMMITTED in `c462004a`)
   - **Status:** committed.
   - **What's there:** New-guard INSERT site, now includes `lineage_id` derived from `derive_lineage_id`. This was the `lineage_id`-missing-from-INSERT root cause for trade 2449.
   - **Why it matters:** Future new guarded legs created via this path will share the trade's lineage automatically. No further edits expected.
   - **Cross-refs:** Decision 1 (in the propagation tranche).

7. `/app/syb/tradesuite/tradelens/bin/pipeline/refresh_order_leg_live.py:1846-1898 and 2375-2402` (ALREADY COMMITTED in `c462004a`)
   - **Status:** committed.
   - **What's there:** Auto-TBE creation site (line 1846+) now uses `derive_lineage_id` for anchor; refresh ingest site (line 2375+) prefers explicit lineage from leg dict, then helper sibling lookup, then `exchange_order_id` fallback.
   - **Why it matters:** Future ingestions of fresh exchange orders will converge on the trade's first-leg lineage instead of each getting their own.
   - **Cross-refs:** Decision 1 (propagation tranche); the repair tool only repairs PAST data — this file's edits prevent future divergence.

8. `/app/syb/tradesuite/tradelens/bin/tools/levelguard_cli.py:259-308` (ALREADY COMMITTED in `c462004a`)
   - **Status:** committed.
   - **What's there:** CLI tool's INSERT now includes `lineage_id` column + helper-derived value.
   - **Why it matters:** Operator-driven CLI guard creation joins the trade group correctly. Low-traffic but should be consistent.
   - **Cross-refs:** Decision 1 (propagation tranche).

## Open threads

1. **Thread:** Commit the repair tool tranche.
   **State:** Two new files exist in working tree (the repair tool + its tests). Tests are green. Dry-run on prod verified. Awaiting user `/t-done` invocation.
   **Context needed to resume:** the user's last message recommendation in the conversation; this checkpoint's "Next steps" #1.
   **Expected resolution:** one new commit on master of the form `fix(repair): align lineage_id across legs of currently-open trades` with the two files, then `claude-task done <commit-hash>`.

2. **Thread:** Apply the repair on prod for trade 2449's group.
   **State:** Tool dry-run-verified for trade 2449 (anchor `2881bf6c-…`, 2 legs to update). Not yet `--apply`'d. Operator action.
   **Context needed to resume:** the dry-run output in "Commands that mattered" #4.
   **Expected resolution:** `bin/tools/repair_trade_lineage.py --account-id 3 --symbol BTCUSDT --apply` outputs "2 row(s) updated, committed". Subsequent breach on guard 63 (TP1) emits a non-skipped row in `level_b_decision_log`.

3. **Thread:** Decide whether to also `--apply` the repair globally on the 11 broken `account_id=1` groups.
   **State:** Diagnosed but not actioned. Account 1 is the user's main trading account, not demo. The repair is safe and idempotent per the integration tests, but the user's authorization is currently scoped to trade 2449 (account 3) only.
   **Context needed to resume:** the prod-wide query output in "Surprises / gotchas" #2 and "Commands that mattered" #1.
   **Expected resolution:** explicit user yes/no on global repair before running `--apply` without filters.

4. **Thread:** Queued tranches per the user's earlier statement — order is `lineage propagation` (DONE), `ATR candle freshness`, `B6 sidecar worker wiring`.
   **State:** Both untouched. Lineage tranches are (a) committed and (b) ready-to-commit (this tranche).
   **Context needed to resume:** the prior session's debugging notes that surfaced these as queued items; specifically the worker log line `Insufficient candles for ATR: need 15, got 14` printed every breach, and the `breach_decision.tick_source: rest|sidecar` config flag idea documented in `lib/tradelens/breach_decision/tick_sidecar.py` module docstring.
   **Expected resolution:** ATR debugging produces a fix tranche; B6 worker wiring lands `breach_decision.tick_source` config flag + `level_mind_worker.py` startup wiring + sidecar `start()/stop()` plumbing.

5. **Thread:** Trade 2449 still has TP1 (id 1767) sitting at lineage NULL until the repair runs.
   **State:** Position is at 0.109 BTC long, mark price ~77,803 (well below 77,910 TBE level which already executed; well below 77,990 TP1 level so TP1 is armed but not breached). Trade is open.
   **Context needed to resume:** the live state captured in "Working environment". Position will breach TP1 only if price rises to 77,990 — currently 187 below.
   **Expected resolution:** either price rises and TP1 breaches (which would emit another `skipped` row pre-repair, or work cleanly post-repair), or trade closes naturally, or the user manually intervenes.

## Surprises / gotchas

1. **Finding:** `psycopg2.pool.ThreadedConnectionPool` returns connections with `autocommit=False` by default, even though most production code in this repo treats them as autocommit-on.
   **How we discovered it:** `grep -n "\.commit()\|\.rollback()\|conn\.autocommit" bin/server/level_mind_worker.py` returned no matches; combined with empty `level_mind_response` for guard 62 → traced to AUD-0291 commit `8213fb9a` switching from `PostgresDB(self.db_config)` (which sets autocommit=True in owner-mode at `pg_db.py:73`) to `PostgresDB(connection=pool_conn)` which deliberately preserves caller session state.
   **Time cost:** ~30 minutes from "level_mind_response empty" to root cause; another ~20 minutes confirming the regression window via git log.
   **Implication:** Any future code that takes a connection from `self._pool` in any TradeLens daemon must either (a) set `conn.autocommit = True` per acquire, or (b) make every write path explicitly `conn.commit()`. Pattern (a) is now codified by the parent session's commit `3d68f177` AST invariant test.
   **Where it's documented (if anywhere):** comment block at `bin/server/level_mind_worker.py:819-823`, the AUD-0291 invariant test at `tests/unit/test_pool_getconn_autocommit_invariant.py`, and the canonical pattern at `lib/tradelens/core/pg_pool.py:48` (per AUD-0009).

2. **Finding:** Prod has 12 broken `(account_id, symbol, position_idx)` open-trade groups, not just trade 2449.
   **How we discovered it:** the global query in "Commands that mattered" #1 returned 12 rows. The user's brief framed the repair as "trade 2449"-focused but the underlying bug affected every trade ingested between AUD-0291 and the propagation fix, plus older trades from before the propagation invariant existed.
   **Time cost:** ~3 minutes; the query was straightforward.
   **Implication:** The user's `--apply` decision should be explicit about scope. Default safe path: apply per-trade with `--account-id` + `--symbol` filters; only broaden if the user authorises.
   **Where it's documented:** "Open thread" #3 above; the dry-run output at `--apply` time would surface all 12 groups by default.

3. **Finding:** Trade 2449's TP1 leg id changed from `1766` → `1767` between morning and afternoon.
   **How we discovered it:** the dry-run output for the repair plan listed `[1764, 1767]` instead of the `[1764, 1766]` I expected. Cross-referenced with `level_guard_daemon.log` and `order_leg_hist`: leg 1766 was the original TP1 created at trade open. When the autocommit fix executed at 14:07:28Z, the level-guard daemon's "post-execution cascade" archived TBE leg 1765 to hist (id 2737) and the daemon's resume/recreate logic minted a NEW TP1 leg as id 1767.
   **Time cost:** ~5 minutes verifying via DB query.
   **Implication:** Any test or assertion referencing trade 2449 leg ids by literal value must be updated to use 1767, not 1766. Future operators reading old logs should know the leg-id drift.
   **Where it's documented:** the dry-run output; this checkpoint.

4. **Finding:** The branched conversation has its own `claude-task` session (`64cb01e6-…`) separate from the parent (`5e639453-…`), so `claude-task history` from the branch only shows tasks created within the branch.
   **How we discovered it:** `claude-task history` after the lineage propagation `/t-done` showed only one task even though git history had 4+ commits from this session's work.
   **Time cost:** trivial.
   **Implication:** Future `/t-checkpoint` or session-resume operations need to know the parent session ID to recover full task history. Documented in this checkpoint's header.
   **Where it's documented:** this checkpoint header; not encoded anywhere else.

5. **Finding:** `level_mind_response` table has no `decided_at` or `evidence_price` column despite earlier handoff notes suggesting otherwise — the column list is exactly: `id, request_uuid, action, new_state_json, decision_reason, classification, confidence, next_check_ms, response_json, created_at`.
   **How we discovered it:** initial query `SELECT ... evidence_price ... FROM level_mind_response` returned `ERROR: column "evidence_price" does not exist`.
   **Time cost:** ~2 minutes correcting the query.
   **Implication:** any future analytics on this table must use `created_at` as the timestamp; `last_price` lives in the `response_json` blob, not a top-level column.
   **Where it's documented:** the schema is described in `etc/schema.md` (auto-generated).

6. **Finding:** Empty `level_mind_response` plus `level_mind_request.status='subscribed'` (never advanced to `'active'`) plus `updated_at == created_at` are three correlated symptoms of the same autocommit bug — they all stem from the worker's writes silently rolling back.
   **How we discovered it:** querying `level_mind_request` for guards 62/63 showed `status='subscribed', updated_at=14:37:26+02 == created_at`. `_mark_active` is supposed to flip the status; it had been called every cycle but rolled back.
   **Time cost:** part of the autocommit-diagnosis time.
   **Implication:** if a future session sees this triplet of symptoms again, the autocommit fix may have regressed (the `3d68f177` AST invariant test should catch it earlier).
   **Where it's documented:** the autocommit fix's commit message; the integration test at `tests/integration/test_level_mind_worker_persistence.py`.

## Commands that mattered

1. **Command:**
   ```
   PGPASSWORD=tradelens_poc psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -c "
   SELECT account_id, symbol, position_idx, COUNT(*) AS n_legs, COUNT(DISTINCT lineage_id) AS distinct_lineages, COUNT(*) - COUNT(lineage_id) AS null_count, string_agg(DISTINCT COALESCE(SUBSTRING(lineage_id FROM 1 FOR 8), 'NULL'), ',' ORDER BY COALESCE(SUBSTRING(lineage_id FROM 1 FOR 8), 'NULL')) AS lineage_prefixes FROM order_leg_live WHERE status NOT IN ('Cancelled', 'Filled', 'Rejected') GROUP BY account_id, symbol, position_idx HAVING COUNT(DISTINCT lineage_id) > 1 OR (COUNT(*) > COUNT(lineage_id)) ORDER BY account_id, symbol, position_idx"
   ```
   **Output (relevant portion):** 12 rows. Trade 2449's row was the last one: `account=3, symbol=BTCUSDT, position_idx=1, n_legs=3, distinct_lineages=2, null_count=1, lineage_prefixes=2881bf6c,5e4393fe,NULL`.
   **What we inferred:** The blast radius of the bug — 12 affected groups, 11 on `account_id=1`, 1 on `account_id=3`. Determined that trade 2449 is genuinely the user's test case and account 1's groups are real production trades that need the same repair.

2. **Command:**
   ```
   pytest tests/integration/test_repair_trade_lineage.py -v
   ```
   **Output (relevant portion):** `6 passed in 0.26s`. All six tests green: trade 2449 replay, all-NULL seeding, already-aligned no-op, idempotence, group isolation, terminal-status exclusion.
   **What we inferred:** Repair contract holds. Safe to commit.

3. **Command:**
   ```
   /app/syb/tradesuite/scripts/check-tests.sh
   ```
   **Output (relevant portion):** `1407 passed, 4 skipped, 9 warnings in 69.81s ✅ check-tests: all green`.
   **What we inferred:** No regressions. Up by 6 tests (1401 → 1407) from the new repair-tool integration tests. Safe to commit.

4. **Command:**
   ```
   /app/syb/tradesuite/tradelens/bin/tools/repair_trade_lineage.py --account-id 3 --symbol BTCUSDT
   ```
   **Output (relevant portion, verbatim):**
   ```
   Found 1 broken open-trade group(s):
   ==============================================================================
     account=3   symbol=BTCUSDT    position_idx=1
       distinct lineages before : 2
       NULL legs before         : 1
       anchor lineage_id        : 2881bf6c-45d5-4887-beb6-a3b3a08c99af (from leg id=1763)
       legs to update           : [1764, 1767]
   ==============================================================================
   Total leg rows that would be UPDATEd: 2
   (DRY-RUN — no changes applied. Re-run with --apply to execute.)
   ```
   **What we inferred:** The plan is exactly what we expect. Anchor is TP2's lineage `2881bf6c-…` (oldest non-NULL, leg id 1763). Stop (1764) and TP1 (1767) get rewritten. Ready for `--apply` on user authorization.

5. **Command:**
   ```
   git log --oneline -8
   ```
   **Output (relevant portion):**
   ```
   c462004a fix(trade-lineage): propagate lineage_id so all legs of one trade share an anchor
   3d68f177 test: codebase-wide ThreadedConnectionPool .getconn() autocommit invariant
   3da2fdcf fix(level-mind): worker pool-conn writes silently rolled back since AUD-0291
   05bee9d5 fix(tl): widen Service column to fit renamed breach-decision-* names
   2ceefdc7 refactor(breach-decision): rename level_b / Layer B subsystem to breach_decision
   d7eef05d feat(level-b): B6 — websocket tick sidecar + orchestrator tick_source seam
   ```
   **What we inferred:** Three of today's commits on master directly relate to trade 2449's bug surfacing: `3da2fdcf` (autocommit), `3d68f177` (parent's invariant test), `c462004a` (lineage propagation). The repair tool would be the fourth.

## Schema / API / data facts worth preserving

- **`order_leg_live` columns relevant to trade-grouping:** `id`, `account_id`, `symbol`, `position_idx`, `lineage_id`, `exchange_order_id`, `status`, `trigger_price`, `leg_type`. NO `trade_id` column on this table. Trade-grouping must use `(account_id, symbol, position_idx)` as the primary key, with `lineage_id` as the fine-grained sibling discriminator. — Verified by `\d order_leg_live` against `tradelens_test`.

- **`level_guard.trade_id` exists** (numeric) and links a guard row to its trade. `order_leg_live` has no `trade_id`, so any cross-table join from a leg to its trade goes via `level_guard.order_leg_live_id`. — Documented in `etc/schema.md`.

- **`ACTIVE_ORDER_STATUSES = ('new', 'untriggered', 'partiallyFilled', 'guarded')`** is the orchestrator's "leg is still actively held" set. The repair tool uses the negative form `status NOT IN ('Cancelled', 'Filled', 'Rejected')` to be lenient about future statuses we don't know about. — Defined in `lib/tradelens/breach_decision/orchestrator.py:183`.

- **`position_idx`** semantics: hedge mode → 1=long, 2=short; one-way mode → 0 (sometimes NULL). The repair helper uses `IS NOT DISTINCT FROM` so NULL matches NULL only — does NOT match 0. — Verified by `test_position_idx_null_does_not_match_zero` in `tests/unit/test_trade_lineage.py`.

- **Bybit demo account is `account_id = 3`** in `tradelens_test` and `tradelens` databases. Account 1 is the user's main trading account. — Verified by querying the `accounts` table during diagnosis.

- **Trade 2449's currently-live legs (post-autocommit-fix execution):** `1763` (TP2, lineage `2881bf6c-…`, status `new`), `1764` (Stop, lineage `5e4393fe-…`, status `untriggered`), `1767` (TP1 recreated, lineage `NULL`, status `guarded`). Original TBE `1765` and original TP1 `1766` are in `order_leg_hist`. — Verified by `SELECT id, leg_type, status, lineage_id FROM order_leg_live WHERE id IN (1763, 1764, 1767)`.

- **`level_mind_response` does NOT have `decided_at` or `evidence_price` columns.** Only `id, request_uuid, action, new_state_json, decision_reason, classification, confidence, next_check_ms, response_json, created_at`. — Verified by `\d level_mind_response`.

## Next steps

1. Read this checkpoint's "Handover Statement" and "Decisions made" before any action. Confirm the repair tool's two new files match the descriptions in "Files touched" #1 and #2 by running `git status --short` and verifying both `bin/tools/repair_trade_lineage.py` and `tests/integration/test_repair_trade_lineage.py` are in the `??` set with no other surprises.

2. If the user says "/t-done": create a task with `claude-task new "$(date +%Y%m%d-%H%M%S)-repair-trade-lineage" "Lineage repair tool for currently-open trades"`. Stage the two new files via `git add bin/tools/repair_trade_lineage.py tests/integration/test_repair_trade_lineage.py`. Run `/app/syb/tradesuite/scripts/check-tests.sh` — expect 1407 passed, 4 skipped. Commit with the message template in "Open thread" #1. Mark task done.

3. If the user authorises `--apply` on prod for trade 2449: run `bin/tools/repair_trade_lineage.py --account-id 3 --symbol BTCUSDT --apply`. Expect output `--apply complete: 2 row(s) updated, committed.` Verify post-state by querying `SELECT id, leg_type, lineage_id FROM order_leg_live WHERE id IN (1763, 1764, 1767)` — all three should show `lineage_id = '2881bf6c-45d5-4887-beb6-a3b3a08c99af'`.

4. After --apply, if the user wants live verification: wait for the price to bounce up to 77,990 (or for the user to artificially trigger via mark-price movement). When TP1 (guard 63 / leg 1767) breaches, the orchestrator should emit a NON-skipped row in `level_b_decision_log`. Verify via `SELECT id, status, status_detail FROM level_b_decision_log WHERE breach_ts_utc > NOW() - INTERVAL '5 minutes' ORDER BY id DESC LIMIT 5` — expect `status='ok'` or `status='fallback'` (depending on tick coverage), NOT `status='skipped' status_detail='hard-stop precondition not met'`.

5. If the user moves to the ATR tranche: read the `level_mind_worker.log` lines `Insufficient candles for ATR: need 15, got 14` (or similar variants). Trace from there to `lib/tradelens/services/level_guard.py` ATR computation and `bin/server/pipeline_daemon.py` mdsync 1m candle freshness. The breach-decision orchestrator already correctly refuses to fabricate ATR (B4 review fix #1), so this is purely about getting fresh-enough candles to the precondition. Out of scope for the repair tranche.

6. If the user moves to B6 worker wiring: `bin/server/level_mind_worker.py` currently uses the REST recent-trade fetch for tick coverage at the breach-decision orchestrator. The websocket sidecar lib (`lib/tradelens/breach_decision/tick_sidecar.py`) was shipped at commit `d7eef05d` but never wired in. The plan was: add a `breach_decision.tick_source: rest|sidecar` config flag, instantiate `TickSidecar` at worker startup if the flag is `sidecar`, pass `sidecar.get_pre_breach_ticks` as the orchestrator's `tick_source` callable, call `sidecar.start()` / `sidecar.stop()` in the worker's lifecycle. ~50 LOC plus tests.

## Verification checklist for the next session

- `git rev-parse --short HEAD` returns `c462004a`.
- `git status --short` shows `bin/tools/repair_trade_lineage.py` and `tests/integration/test_repair_trade_lineage.py` as `??` (untracked, new), plus the same auxiliary `?? .claude/` / `?? .codex` / etc lines that have been present all session.
- `bin/tools/repair_trade_lineage.py` exists and is executable (`ls -l` shows `-rwx` mode).
- `pytest tests/integration/test_repair_trade_lineage.py -v` passes 6/6 in <1s.
- `claude-task status` reports session `64cb01e6-ffc8-44dd-b0bd-8aa861cf0b6a`, no active task.
- `tl status` shows `level-mind RUNNING (PID 1111560)` (or similar — check the PID matches the autocommit-fix-restart era), `level-guard RUNNING (PID 913656)`, `breach-decision-label-backfill RUNNING (PID 902266)`, `breach-decision-outcome-backfill RUNNING (PID 902331)`. If any are STOPPED, an unexpected restart happened — investigate before proceeding.
- The breach-decision-stage1-check returns `Overall: READY`.
- Querying `SELECT id, lineage_id FROM order_leg_live WHERE id IN (1763, 1764, 1767)` shows lineages `2881bf6c-…`, `5e4393fe-…`, `NULL` respectively (i.e. trade 2449 still NOT repaired — the `--apply` step is gated on user authorization).
