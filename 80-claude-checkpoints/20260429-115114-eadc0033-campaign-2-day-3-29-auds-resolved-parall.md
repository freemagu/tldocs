# Checkpoint: Campaign 2 Day 3 — 29 AUDs Resolved + parallel-session AUD-0371 follow-up landed

**Saved:** 2026-04-29 11:51:14 UTC
**Working dir:** /app/syb/tradesuite
**Git:** master @ dede1709
**Session:** eadc0033-f5c4-4626-9e5b-c0e01a50e785
**Active task:** none (closed via `/t-done` at d9aad8ca; parallel-session has pushed 6 commits on top)

## Handover Statement

You are joining at a closed session boundary, AFTER `/t-done` ran. The Day 3 campaign work is complete and committed: 29 AUDs were Resolved this session across five phases (Wave 3A close, Wave 3B partial, mechanical sweep, the four-batch, tier-2). The active claude-task `20260429-093000-c2d3-mechanical-medium-sweep` was closed at commit `d9aad8ca` (Day 3 tier-2 batch tracker). Confirmed audit count went 89 → 60 (−33% of the day-start backlog); pytest grew 1903 → 2108 (+205 cases). Every commit is pushed to `origin/master`. **Do NOT auto-resume Day 4 if the user says "continue" without a target — the session is at a clean stopping point and a fresh task must be started for any new work.**

A parallel session has pushed six commits on top of `d9aad8ca` since `/t-done`: `dede1709`, `0dab9dee`, `d3b2067e`, `c8bdf6c8`, `d6c955f7`, `63089c60`. The most relevant one for THIS session's history is `c8bdf6c8` (`fix(daemons): AUD-0371 follow-up — gate StreamHandler on isatty()`) — it touched three files I edited this session (`tradelens/lib/tradelens/core/logging.py`, `tradelens/bin/mdsync_pg.py`, `tradelens/tests/unit/test_aud0371_log_rotation_daemons.py`) to fix a duplicate-log-line bug that my AUD-0371 ship introduced. Don't be confused if those files don't match my session's commit content — they're already past the AUD-0371 follow-up. The parallel session's other commits (`dede1709` AUD-0354, `0dab9dee` AUD-0260) are in their hot zones (config secrets + recursive ${VAR} expansion), unrelated to my work. There is also uncommitted working-tree state (3 modified files) that is NOT mine — leave it untouched; it belongs to whatever the parallel session has in flight.

What to read FIRST in order: (1) this checkpoint; (2) `tradelens/AUDIT_TRACKER.md` — the canonical record of audit status, now at 60 Confirmed / 285 Resolved / 16 Resolved-partial; (3) the prior-session checkpoint at `tradelens/.claude/checkpoints/20260428-213723Z.md` for Campaign 2 Day 2 close context (this session built directly on it); (4) the AUD-0345 cli_base helper at `tradelens/lib/tradelens/utils/cli_base.py` because it's the new canonical scaffolding that future pipeline / tooling work should reuse rather than re-creating boilerplate.

Known landmines from this session: (a) the AUD-0371 ship I made added a `StreamHandler(sys.stdout)` to `setup_logging` and to mdsync_pg's `setup_logging` AND attached a `RotatingFileHandler` for the same log file. When the daemon launcher does `nohup ... >> logs/<svc>.log 2>&1`, stdout IS that log file, so the StreamHandler wrote each line that the RotatingFileHandler also wrote, producing byte-identical duplicate lines. The parallel session's `c8bdf6c8` follow-up gates the StreamHandler on `sys.stdout.isatty()` so foreground/interactive runs still get console output but daemon paths skip it. Internalise this pattern when adding any future log handler to a daemon. (b) `set_trading_stop` in `bybit_client.py` has zero live callers — verified by grep. Do NOT add policy defaults to it expecting use; future work should treat it as deprecated. (c) AUD-0224 (the 23-site PooledDB→get_db_connection sweep in api/ideas.py) is parked because AUD-0008's broader convergence is still T3 design-ready. Doing the per-file sweep now is mechanical churn. The natural shape is one cross-file sweep across all ~25 PooledDB-using api/ files at once, when AUD-0008 implementation kicks off. (d) The pre-existing `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` symlink in the working tree is from before this session; ignore it.

What NOT to do: do NOT re-litigate any of the four audits I parked this session (AUD-0098 VWAP write-after-refresh; AUD-0167 pipeline persistent-daemon; AUD-0224 PooledDB sweep; AUD-0166 was actually shipped — don't park-it-again). All four park decisions are documented with rationale in the AUDIT_TRACKER.md rows. Do NOT touch the parallel session's uncommitted files (`tradelens/bin/setup/migrate_parser_inbox.py`, `tradelens/tests/unit/test_aud0260_recursive_expansion_loaders.py`, `tradelens/bin/mdsync_pg.py`'s further-modified state). Do NOT redeploy mdsync_pg on rocky2 again unless the user requests it — already redeployed twice this session (AUD-0371, AUD-0370) and verified live; the parallel session's `c8bdf6c8` AUD-0371 follow-up has NOT yet been deployed to rocky2 and probably should be soon, but that's a separate decision. The exact next action depends entirely on what the user asks. There is no implicit continuation — Day 3 is done, Day 4 is a question.

## User note

*(The user invoked `/t-checkpoint` without a free-form note.)*

## Session context

### User's stated goal (verbatim where possible)

The session opened immediately after `/clear` followed by `/t-checkpoint-load`, which loaded the prior-session checkpoint `20260428-213723Z.md` (Campaign 2 Day 2 close). After verification the user gave a single-line directive: *"I want you to work on the roughly 55 are mechanical/medium fixes"*. That phrase ("roughly 55 mechanical/medium fixes") came from my own backlog estimate at the end of Campaign 2 Day 2, where I bucketed the 89-Confirmed pool by focused-work-hours into roughly 30 mechanical, 25 medium, 25 multi-file, 15 out-of-scope.

After I asked clarifying scope questions partway through, the user pushed back hard with: *"i asked you to finish roughly 55 are mechanical/medium fixes. Did you complete that work? If not, stop asking me questions and continue with it"*. This established a clear contract for the rest of the session: **ship audits unattended at the user's stated pace, don't pause for approval, don't re-scope conservatively**. After the four-batch I had named at the end of one summary (AUD-0036, AUD-0095, AUD-0166, AUD-0345) the user said *"keep going on those four next"* — same directive, more specific target. Then after that batch closed, the user said *"keep going on the next tier"* — a third shipping directive.

### User preferences and corrections established this session

- **Run unattended; stop asking permission to ship the next AUD.** Verbatim correction: *"stop asking me questions and continue with it"*. This SUPERSEDES any "discuss before editing" instinct I had at the start of the session. The pattern: edit → test → commit → next AUD. Brief one-line status updates between AUDs are fine, but pre-edit approval requests are not.

- **Mechanical/medium estimates may be optimistic; honest accounting is required.** When I parked AUD-0098 / AUD-0167 / AUD-0276/0277 with rationale rather than ship them, the user accepted that — but only because I described WHAT was blocking each of them in concrete terms (subprocess-timeout half handled by AUD-0078; persistent-daemon needs main() extracted; VWAP cluster is multi-day). Vague "this is hard" would not have flown.

- **Don't ship breaking changes to existing test fixtures without updating the fixtures.** When I made `place_order`'s reduce_only + position_idx required (AUD-0036), 11 tests broke because their fixtures called `place_order(...)` without those kwargs. I wrote a one-off Python regex script in `/tmp/migrate_place_order_tests.py` to add `reduce_only=False, position_idx=0` to each call site, ran it, deleted the script post-run. Same pattern for the AUD-0345 breach script migration (`/tmp/migrate_breach_scripts.py`). The user did not directly comment on this, but the smooth pytest-green outcome confirmed it as the right approach.

- **rocky2 deploy is the user's responsibility to remind me about.** When I shipped AUD-0371 (RotatingFileHandler for mdsync_pg, which runs on rocky2), the user reminded me mid-session: *"dont forget that mdsync runs on rocky2 so you need to git pull on that host and restart the service there"*. I acted on this immediately for AUD-0371, then proactively redeployed again later for AUD-0370 (which also touched mdsync). For ANY future change touching `tradelens/lib/tradelens/mdsync/*` or `tradelens/bin/mdsync_pg.py`, the rocky2 redeploy is part of "shipping" the audit, not a separate concern.

### Working environment

- **Master HEAD:** `dede1709` (parallel-session AUD-0354 Phase A.5/A.6/A.7 — config.yml secrets via ${VAR} + .example template). My session's last commit was `d9aad8ca` (Day 3 tier-2 batch tracker close). Six parallel-session commits sit on top of mine.
- **Branch:** `master`. No other branches active in this checkout.
- **No active claude-task.** `claude-task current` returns empty after the `/t-done` close.
- **Tracked-file state:** three files modified vs HEAD, all parallel-session work — `tradelens/bin/mdsync_pg.py` (further simplified post-c8bdf6c8 follow-up), `tradelens/bin/setup/migrate_parser_inbox.py` (parser inbox migration WIP), `tradelens/tests/unit/test_aud0260_recursive_expansion_loaders.py` (AUD-0260 test WIP). I have NEVER touched these files since `/t-done`. Untracked: pre-existing `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` symlink (created Apr 26).
- **rocky2 mdsync_pg:** running PID 183849 on commit `4998134a` (AUD-0370 ship) per my last verification. The parallel-session `c8bdf6c8` AUD-0371 follow-up has NOT been deployed there. Operator decision pending.
- **No background processes I started.** Pure code-edit + test session.
- **Pytest baseline at session close:** `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1` reported `2108 passed, 4 skipped, 9 warnings in 91.36s`.

## Objective

The user's stated objective: **finish roughly 55 mechanical/medium audit fixes from the unbundled Confirmed pool.** The estimate came from my own Campaign 2 Day 2 closing report, which bucketed the 89-Confirmed audits by focused-work-hours.

This session shipped 29 of those AUDs — about 53% of the user's "~55" target. The remaining gap reflects honest re-classification: many audits I labeled "mechanical/medium" at Day 2 close turned out to depend on broader architectural decisions (AUD-0008 PooledDB convergence, AUD-0118 helper-conn pattern, AUD-0170 OrderClassifier god-object decomposition), or to need product/operator decisions (C-bucket AUD-0341/0343), or to be multi-day refactors (frontend megas, daemon supervision). Of the 60 still Confirmed at session close, my honest re-classification: ~5–8 actually mechanical and tractable next session; ~25 multi-day refactors; ~10 architecture-blocker; ~10 product/operator decision; ~5 investigation-heavy; ~5 wide pattern fixes that touch 10+ files.

The campaign 2 plan (`tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md`) is the operating contract for this campaign. Wave 3A and Wave 3B partial closed cleanly this session. Wave C (multi-table tx wrap, AUD-0140 + lift `_atomic_block` to `core/db_helpers.py`) was NOT touched — it's the natural Day 4 candidate.

## Narrative: how we got here

The session opened immediately after `/clear` followed by `/t-checkpoint-load`, which pulled the prior-session checkpoint `20260428-213723Z.md` (Campaign 2 Day 2 close). I ran the verification checklist from that checkpoint — all 10 items passed cleanly (HEAD `004774a1`, Confirmed count 89, no active claude-task, `Wave A — AppLock` entry shows CLOSED ✅, etc.). Pytest was not re-run since the prior checkpoint had documented 1903/4-skipped at Day 2 close.

The user's first instruction was the single line *"I want you to work on the roughly 55 are mechanical/medium fixes"*. I started a new claude-task `20260429-093000-c2d3-mechanical-medium-sweep` and did a fresh survey of the 89 Confirmed AUDs. The survey output bucketed by severity and category showed 18 Critical, 58 Major, 12 Minor, 1 Architecture remaining. I picked Wave 3A (Chunk 7 partial — `api/{stops, suspend, batch_ideas, ideas}.py`) as the first batch since it was already pre-planned in the campaign-2 dispatch document with 6 AUDs (0212, 0215, 0216, 0219, 0224, 0225).

Phase 1 — Wave 3A close — shipped 5 of the 6 AUDs. AUD-0212 (the dead `/stops` POST endpoint) turned out to be a delete-not-fix: frontend `stopsApi` had zero callers, `services/stops.py` was only imported by `api/stops.py`, the `stop_config` table didn't exist in `etc/schema.md`, and both stops services used Sybase-style `?` placeholders (further evidence of long-stale code). I deleted the entire stops subsystem (-583 LOC). AUD-0215 added a `_CRITICAL_RESUME_LEG_TYPES` frozenset and gated the `UPDATE trade_journal SET status='open'` on `if not resume_partial:`. AUD-0216 + AUD-0225 were bundled — converting `batch_create_ideas` from `async def` → `def` (and its two helper functions `_save_images_as_screenshots` + `_save_ai_conversation_to_idea`) eliminated both the event-loop-blocking and the cursor-across-await issues at once. AUD-0219 pushed LIMIT/OFFSET into SQL. AUD-0224 was parked with rationale: pure cleanup migration to AUD-0008 architecture, but AUD-0008 itself is still T3, so per-file sweep is churn.

Phase 2 — Wave 3B partial — shipped AUD-0342 (trader_scorecard N+1 collapsed via `array_agg(content ORDER BY id DESC)[1]` PostgreSQL pattern, 41 round-trips → 2) and AUD-0350 (system_monitor TOCTOU via `/proc/<pid>/status` atomic read; FileNotFoundError → all-None graceful path). The remaining Wave 3B items (0345 breach CLI, 0346 breach tests, 0371 log rotation) ended up shipping in later phases.

After Wave 3B I gave the user a status report estimating ~10 more campaign-days of work remained. The user's response was the pivotal directive: *"i asked you to finish roughly 55 are mechanical/medium fixes. Did you complete that work? If not, stop asking me questions and continue with it"*. I switched into unattended-shipping mode for the rest of the session.

Phase 3 — mechanical sweep — ripped through 13 audits without further user input: 0030 (db_pool shim deletion + 30-file import migration via sed), 0056 (sizing profit_pct test added — the actual fix already shipped via commit `068f199b`'s AUD-0077 refactor and just needed tracker flip + missing regression test), 0093 (REFRESH_SCRIPT TLHOME-aware via `_resolve_refresh_script()` helper), 0112 (submit_trade verifies submitter account_name matches preview's account_name; 403 on mismatch; None preserves legacy compat), 0120 (execution-result note INSERTs new row instead of appending — the audit's "row grows with every submit" bug), 0122 (SL trigger_direction routes through `calc_trigger_direction(side=..., leg_type='stop')` shared helper), 0233 (batch_create CREATE-branch cascade wrapped in `autocommit=False` mirroring AUD-0217's overwrite-branch shape — drops the hand-rolled DELETE rollback), 0247 (StateManager.save() takes flock + re-reads disk + merges in-memory + atomic-renames), 0248 + 0249 (extension validateBackendUrl + chrome.permissions.request), 0304 (subsumed by 0371), 0370 (mdsync watchlist denylist + canonicalisation in `lib/tradelens/mdsync/reconcile.py`), 0371 (RotatingFileHandler for 6 daemons + new `setup_rotating_logger` helper at `lib/tradelens/core/logging.py`).

Mid-phase 3, the user reminded me about rocky2 deployment for mdsync_pg. I pushed to gitlab, ssh'd to `sybase@10.50.0.2`, did the `git stash push -- tradelens/etc/config.yml && git pull origin master && git stash pop` dance to preserve rocky2's 3 local config overrides, restarted mdsync_pg via `bin/mdsync_pg restart`, verified PID and log freshness. Same dance for AUD-0370 later in the session.

Phase 4 — the user named four parked items from my earlier triage (0036, 0095, 0166, 0345) and said *"keep going on those four next"*. AUD-0345 was the largest mechanical win: extracted `tradelens/lib/tradelens/utils/cli_base.py` with `add_debug_arg / apply_debug_arg / connect_db / DecimalEncoder` and migrated 10 of 11 breach_*.py scripts via a one-off Python regex script `/tmp/migrate_breach_scripts.py`. AUD-0166 split the I/O step from the DB-touching step: new `_fetch_history_for_disappeared(stale_order, bybit) → (orders, exception_or_None)` helper, plus a `prefetched_history=None` keyword parameter on `archive_disappeared_order`; cleanup loop runs all Bybit history fetches concurrently via `ThreadPoolExecutor(max_workers=4)` then iterates serial DB writes. AUD-0095 made `calculate_quantity` return `QtyResult(qty: str, close_entire: bool)` NamedTuple instead of a bare str — eliminates the magic-`'0'`-string overload while preserving wire format and backward-compat (NamedTuple IS a tuple). AUD-0036 made `place_order`'s `reduce_only` + `position_idx` required keyword-only args (matches AUD-0006 pattern for `place_conditional_order`); 11 test fixtures updated via the migration script.

Phase 5 — the user said *"keep going on the next tier"*. I named four candidates (AUD-0098, AUD-0167, AUD-0276, AUD-0277) but ended up parking 0098 + 0167 with rationale and skipping 0276/0277 (multi-day VWAP cluster). While investigating, hit a vein of related medium-tier items that were tractable now: 0141 (extract trade-alerts subsystem from journal.py — −667 LOC, 6 endpoints + 6 classes moved to `api/trade_alerts.py`, main.py registers both routers under same /api/v1 prefix so URL shape unchanged), 0201 (5 of 6 sync-DB-only `async def` handlers in guards.py converted to `def` — same shape as the AUD-0216 fix; `list_guards` stays async because it owns a real `await fetch_market_data_for_symbols(...)` per AUD-0220), 0154 (batch-load previous snapshots in `upsert_legs_to_db` via single `WHERE exchange_order_id = ANY(%s)` query — 100-200 round-trips → 1), 0176 (merge `OrderClassifier`'s 3 overlapping maps into typed `_classified_orders: Dict[str, ClassifiedOrder]` + properties for backward-compat; `smart_order_positions` had no live writer — deleted), 0168 (share `--debug` scaffolding across 3 pipeline scripts via cli_base; partial because the bigger classifier/fetch/upsert merge is parked under AUD-0170's god-object decomposition).

The user ran `/t-done`. I scanned conversation history, confirmed all session work was already in commits, wrote the task context to `~/.claude/tasks/context/20260429-093000-c2d3-mechanical-medium-sweep.md`, and closed via `claude-task done`. Then `/t-checkpoint` came in, plus three system reminders informing me that `tradelens/lib/tradelens/core/logging.py`, `tradelens/bin/mdsync_pg.py`, and `tradelens/tests/unit/test_aud0371_log_rotation_daemons.py` had been further modified — they reflect a parallel-session AUD-0371 follow-up at commit `c8bdf6c8` that gates the StreamHandler on `sys.stdout.isatty()` to avoid duplicate log lines under daemon redirect. That follow-up fixed a bug my AUD-0371 ship introduced — under `nohup ... >> logs/<svc>.log 2>&1` stdout IS the log file, so my StreamHandler + RotatingFileHandler combo wrote each line twice. The parallel session caught and fixed it.

## Work done so far

1. **Loaded prior-session checkpoint and verified state.** Read `20260428-213723Z.md` in full, ran the 10-item verification checklist, all passed. **State:** read-only.

2. **Started claude-task `20260429-093000-c2d3-mechanical-medium-sweep`.** Tracking handle for the entire session's work. **State:** closed at commit `d9aad8ca` via `/t-done`.

3. **Wave 3A close — 5 AUDs Resolved + AUD-0224 parked, 5 commits + 1 tracker:**
   - `214f96d5` AUD-0212: deleted `tradelens/lib/tradelens/api/stops.py` (119 LOC), `tradelens/lib/tradelens/services/stops.py` (480 LOC), `services/portfolio.py:load_stop_configs` (28 LOC), `models/dto.py:StopConfigRequest/Response`, `frontend/web/src/lib/api.ts:stopsApi`, `frontend/web/src/lib/types.ts:StopConfig`, `main.py` import + router include. Total LOC removed: -583. Test maintenance: removed `services/stops.py` from `EXPECTED_CALL_SITES` in `tests/unit/test_aud0006_place_conditional_order_required.py`. Test policy: dead-code-removal exemption.
   - `6ed858ce` AUD-0215: added module-level `_CRITICAL_RESUME_LEG_TYPES = frozenset({'stop', 'sl', 'trailing_tl', 'trailing_be'})` at `tradelens/lib/tradelens/api/suspend.py`; gated `UPDATE trade_journal SET status='open'` on `if not resume_partial:`; added `partial: bool = False` and `failed_orders: List[Dict[str,str]] = []` to `ResumeTradeResponse`. Tests at `tests/unit/test_aud0215_resume_partial_failure.py` (6 cases).
   - `b4183c8a` AUD-0216 + AUD-0225 bundled: converted `batch_create_ideas` from `async def` → `def`, plus the two private helpers `_save_images_as_screenshots` and `_save_ai_conversation_to_idea`. Updated 4 `await _save_*` call sites to drop the `await`. Test fixture `_async_zero` in `test_aud0217_batch_ideas_overwrite_transaction.py` became sync `_zero`; `_run = asyncio.run` wrapper dropped at 6 invocation sites; `import asyncio` removed. Tests at `tests/unit/test_aud0216_0225_batch_create_sync.py` (5 cases).
   - `628a090e` AUD-0219: added `LIMIT %s OFFSET %s` to row-fetch SQL in `list_trade_ideas` at `api/ideas.py:~830`; pagination params bound, not interpolated. Tests at `tests/unit/test_aud0219_list_trade_ideas_sql_pagination.py` (3 cases).
   - `a34ff3bb` Wave 3A tracker close — 5 AUDs Resolved + AUD-0224 parked.

4. **Wave 3B partial — 2 AUDs Resolved, 2 commits + 1 tracker:**
   - `5b22833a` AUD-0342: collapsed 2N per-trade note queries in `trader_scorecard.py`'s recent-trades loop via `SELECT trade_idea_id, COUNT(*) AS note_count, (array_agg(content ORDER BY id DESC))[1] AS latest_content FROM trade_journal_notes WHERE trade_idea_id = ANY(%s) AND event_type = %s GROUP BY trade_idea_id`. 41 round-trips → 2. Tests at `tests/unit/test_aud0342_trader_scorecard_n_plus_1.py` (4 cases).
   - `bb087cff` AUD-0350: `get_process_metrics` in `system_monitor.py` reads `/proc/<pid>/status` atomically for VmRSS + Threads (replacing `ps -o rss=,%cpu=,nlwp=`). FileNotFoundError → all-None graceful return. CPU% kept on `ps -o %cpu=` because /proc/stat needs delta sampling. Tests at `tests/unit/test_aud0350_system_monitor_proc_atomic.py` (5 cases).
   - `60de9f27` Wave 3B partial tracker close.

5. **Mechanical sweep — 13 AUDs Resolved, 13 commits + 2 tracker batches:** AUD-0093 (REFRESH_SCRIPT TLHOME), AUD-0120 (execution-result note INSERT-not-append), AUD-0122 (SL trigger via shared helper), AUD-0233 (batch_create cascade tx wrap), AUD-0247 (StateManager flock + on-disk merge with `_max_message_id` helper), AUD-0056 (test added — actual fix already shipped via `068f199b`), AUD-0370 (mdsync watchlist denylist + `_canonicalise_or_drop` helper in `mdsync/reconcile.py`, wired into 3 watchlist-construction loops), AUD-0112 (submit_trade verifies account_name with 403 on mismatch), AUD-0248 (extension `validateBackendUrl` in popup.js + `isAcceptableBackendUrl` at all 3 fetch boundaries in background.js), AUD-0371 (new `setup_rotating_logger` helper at `lib/tradelens/core/logging.py`; wired into 4 engine daemons via shared helper + 2 cold-start daemons via inline `RotatingFileHandler`), AUD-0030 (deleted `core/db_pool.py` shim; migrated 30 imports via sed), AUD-0249 (added `optional_host_permissions` to manifest.json + runtime `chrome.permissions.request` in popup.js), AUD-0304 (subsumed by AUD-0371). Each ships with regression tests.

6. **The four-batch — 4 AUDs Resolved, 4 commits + 1 tracker:** AUD-0036 (place_order required kwargs; 11 test fixtures updated via `/tmp/migrate_place_order_tests.py`), AUD-0095 (calculate_quantity returns `QtyResult` NamedTuple; AUD-0088 tests updated), AUD-0166 (parallel Bybit history fetch via `_fetch_history_for_disappeared` + `prefetched_history` kwarg + `ThreadPoolExecutor(max_workers=4)`; test fixture `fake_archive` in `test_refresh_order_leg_live_archive_guard.py` updated to accept `**kwargs`), AUD-0345 (extracted `tradelens/lib/tradelens/utils/cli_base.py` with 4 helpers + class; migrated 10 breach_*.py scripts via `/tmp/migrate_breach_scripts.py`).

7. **Tier-2 — 5 AUDs Resolved, 5 commits + 1 tracker:** AUD-0141 (extracted `tradelens/lib/tradelens/api/trade_alerts.py` from `journal.py` — 668 LOC moved, journal.py 5873 → 5206 lines), AUD-0201 (5 sync-DB-only `async def` handlers in `guards.py` → `def`; `list_guards` stays async per AUD-0220's real await), AUD-0154 (batch-load previous snapshots in `upsert_legs_to_db` via single `ANY(%s)` query; `if old_snapshot is not None:` guard preserves `if row:` semantic), AUD-0176 (merge `OrderClassifier`'s 3 maps into `_classified_orders: Dict[str, ClassifiedOrder]` NamedTuple; `smart_order_positions` deleted; `seeded_entry_orders` + `seed_orders` retained as backward-compat properties), AUD-0168 (share `--debug` via cli_base across 3 pipeline scripts; Resolved-partial because classifier/fetch/upsert merge stays parked under AUD-0170).

8. **Two rocky2 redeployments.** First for AUD-0371 (commit `d9e86f2a`): `ssh sybase@10.50.0.2 'cd /app/syb/tradesuite && git stash push -- tradelens/etc/config.yml && git pull origin master && git stash pop'` then `ssh sybase@10.50.0.2 'source sourceme.sh && bin/mdsync_pg restart'`. Verified PID 182965 → 183849 transition with PID 183853 as the python child. Second for AUD-0370 (commit `4998134a`) with same dance.

9. **`/t-done` close.** Wrote `~/.claude/tasks/context/20260429-093000-c2d3-mechanical-medium-sweep.md` capturing the session's full chronology with commit SHAs, parked items, and rocky2 status. Called `claude-task done $(git rev-parse HEAD)` at HEAD `d9aad8ca`.

## Decisions made (and why)

1. **Decision:** Run unattended after the user's "stop asking me questions and continue with it" directive — every commit shipped without pre-edit approval.
   **Proposed by:** User.
   **Rationale:** The user's first response to my mid-session "want me to keep going?" was a strong correction. Pausing for approval after each AUD wastes their time and breaks pace. The alternative (asking after each commit) was explicitly rejected.
   **Alternatives considered:** (a) Pause after each AUD for confirmation — rejected by user verbatim. (b) Pause only for Critical-severity AUDs — not asked, but the user's pattern across the session suggests they don't want this either. (c) Run continuously — chosen.
   **Revisit if:** A future user signals a different working style ("let's discuss each one before shipping").
   **Affects:** All 29 commits this session.

2. **Decision:** Park AUD-0224 (PooledDB→get_db_connection sweep in api/ideas.py) rather than do a partial migration.
   **Proposed by:** Claude.
   **Rationale:** The audit asks for a 23-site sweep across all ideas.py endpoints, not a per-site demonstration. The 30-line pattern shift (manual `db = PooledDB(...)`, `conn = db.connect()`, `if db: db.close()` → `with get_db_connection() as conn:`) requires substantial re-indenting per endpoint. AUD-0008's broader convergence is still T3 design-ready; doing the per-file sweep before the cross-file convergence ships means re-reviewing all of it. The AUD-0008 design doc identifies ~25 PooledDB-using files in api/; doing them as one cross-file sweep at AUD-0008-implementation time is the natural shape.
   **Alternatives considered:** (a) Migrate all 23 endpoints in one big commit — rejected because the line-by-line re-indent risk is high and the AUD-0008 architectural decision is still pending. (b) Migrate 5–8 endpoints as a "demonstration" — rejected because the audit explicitly says "30+ endpoint sweep; cluster as one commit"; partial migrations leave inconsistent state. (c) Park entirely — chosen.
   **Revisit if:** AUD-0008 implementation begins. At that point AUD-0224 absorbs into the cross-file sweep cleanly.
   **Affects:** ideas.py untouched; AUDIT_TRACKER.md row carries the explicit park rationale.

3. **Decision:** Park AUD-0098 (VWAP write-after-refresh) rather than implement a make-local-DB-primary path.
   **Proposed by:** Claude.
   **Rationale:** The audit's specific concern was "subprocess refresh timeouts leave stale state that a later refresh overwrites." The "subprocess timeouts" half was already eliminated by AUD-0078's BackgroundTasks switch (no subprocess fork; refresh runs in-process with bounded latency). The remaining "BG refresh overwrites stamp" race is documented at `amend_order:2803-2813` as an accepted trade-off. The deeper "make local DB primary writer" fix needs a refresh-respects-local-stamp pattern: the pipeline's UPSERT must include a WHERE clause that doesn't overwrite when the local row's `updated_at` is newer than Bybit's `exchange_updated_at`. That's a cross-file change to refresh_order_leg_live.py outside the api/ scope of AUD-0098.
   **Alternatives considered:** (a) Add a "locally amended" timestamp/flag that the refresh respects — rejected because it requires both api/ and pipeline/ changes coordinated. (b) Inverse the order: stamp DB BEFORE Bybit call — rejected because two-phase write needs status='amending' bookkeeping; complex. (c) Accept the existing trade-off and park — chosen because the inline comment already documents acceptance.
   **Revisit if:** A real production incident shows the BG-overwrites-stamp race causing user-visible damage. Or when the refresh script's UPSERT layer is being touched for another reason.
   **Affects:** open_orders.py amend_order is unchanged; the existing trade-off comment at lines 2803-2813 stays as the documentation.

4. **Decision:** Park AUD-0167 (pipeline persistent-daemon / pool reuse).
   **Proposed by:** Claude.
   **Rationale:** Two paths considered. The "pool" path doesn't help because each pipeline subprocess is a fresh Python process — there's no in-process state to reuse. The "persistent daemon" path requires extracting `refresh_order_leg_live.py`'s `main()` into a callable function the API can invoke in-process, bypassing subprocess entirely. That's a ~2500-line file with `db = PostgresDB(config.database, logger)` opened inside `main()`; refactoring to make the work callable from outside is multi-day architectural work.
   **Alternatives considered:** (a) Lighter pool wrapper inside each subprocess — rejected because each subprocess opens exactly one connection, which the pool would not improve. (b) Extract main() into callable — rejected as multi-day. (c) Park — chosen.
   **Revisit if:** A dedicated pipeline-as-library refactor is undertaken (likely paired with AUD-0093's TLHOME path resolution which already laid groundwork).
   **Affects:** refresh_order_leg_live.py main() unchanged; api/open_orders.py:refresh_order_data subprocess wrapper unchanged.

5. **Decision:** AUD-0036's scope is "make `place_order`'s `reduce_only` + `position_idx` required" rather than the audit's literal "Move into services/".
   **Proposed by:** Claude.
   **Rationale:** AUD-0006 had already made `place_conditional_order`'s `trigger_direction` + `reduce_only` required keyword-only args (commit `45aba896`). That's the pattern the audit's "adapter encodes trading policy" concern actually wanted. Doing the literal "move into services/" would require relocating 5 helpers + updating all 16 + 5 = 21 callers, which is multi-file architectural work. Making the defaults required is the AUD-0006-precedent surgical fix. Verified all 16 production call sites already pass both kwargs explicitly, so it's API-tightening with no behaviour change.
   **Alternatives considered:** (a) Literal "Move into services/" — rejected as multi-file architectural work outside this audit's mechanical scope. (b) Make reduce_only required only — rejected because position_idx default of 0 silently miscategorises hedge-mode orders just as readily. (c) Make both required keyword-only (AUD-0006 pattern) — chosen.
   **Revisit if:** A dedicated services/ layer wave decides to fully relocate.
   **Affects:** bybit_client.py:place_order signature; 11 test fixture files updated via migration script.

6. **Decision:** AUD-0095 returns `QtyResult` NamedTuple, not a typed dataclass.
   **Proposed by:** Claude.
   **Rationale:** NamedTuple IS a tuple, so legacy `calculate_quantity(...)[0]` indexing keeps working — backward compat free. A frozen `@dataclass` would not be a tuple, breaking any callers I missed. The AUD-0088 tests' 5 `raw_qty = calculate_quantity(...)` calls all unpacked the result, so they migrate cleanly to `raw_qty, _close_entire = calculate_quantity(...)`.
   **Alternatives considered:** (a) Frozen `@dataclass` — rejected because it loses tuple semantics. (b) Plain dict — rejected as untyped. (c) NamedTuple — chosen.
   **Revisit if:** A future caller needs methods on the result.
   **Affects:** open_orders.py:calculate_quantity signature; 2 production call sites + 5 test sites updated.

7. **Decision:** Migrate breach_*.py scripts and pipeline scripts to use `tradelens.utils.cli_base`, not `bin/tools/_lib/cli_base.py` as the audit suggested.
   **Proposed by:** Claude.
   **Rationale:** `bin/` isn't a Python package (no `__init__.py`). To put helpers under `bin/tools/_lib/` I'd have to add `__init__.py` files to `bin/` and `bin/tools/`, then add `sys.path.insert(0, str(TRADELENS_HOME))` to every script that wants to import. That's more setup boilerplate than the helper saves. `tradelens.utils.cli_base` is already importable via the existing `sys.path.insert(0, str(TRADELENS_HOME / "lib"))` bootstrap each script does. The audit's location was indicative; the conventional Python-package layout is the right shape.
   **Alternatives considered:** (a) Literal `bin/tools/_lib/` per audit text — rejected because of the `bin/` package issue. (b) `tradelens.cli_tools.cli_base` as a new sub-package — rejected as needless new namespace; `utils/` already exists. (c) `tradelens.utils.cli_base` — chosen.
   **Revisit if:** A future reorganisation moves CLI helpers out of `utils/`.
   **Affects:** AUD-0345 (10 breach_* scripts) and AUD-0168 (3 pipeline scripts) both import from this location.

8. **Decision:** AUD-0176's merge keeps `seeded_entry_orders` and `seed_orders` as backward-compat properties returning legacy dict shapes.
   **Proposed by:** Claude.
   **Rationale:** The classifier has 4 internal read sites + 2 external (in `upsert_legs_to_db`) that consume these as `oid in self.seed_orders` or `self.seed_orders[oid]['position_idx']`. Updating all 6 sites to the new typed `_classified_orders` API would be a wider refactor than the audit's "Cleanup" severity supports. Properties returning fresh dict views preserve external contract without semantic drift. Mutations on the returned dict don't leak back (one of my regression tests pins this).
   **Alternatives considered:** (a) Update all 6 sites to use the new map directly — rejected as wider refactor than the Minor severity supports. (b) Keep separate dicts with same names but enforce kind-disjoint via runtime check — rejected because that doesn't actually solve the audit's "3 maps clutter the API" complaint. (c) Properties over the merged map — chosen.
   **Revisit if:** AUD-0170's god-object decomposition picks up `_classified_orders` into a `ClassifierState` cache class; at that point the properties can move with it.
   **Affects:** refresh_order_leg_live.py:OrderClassifier.

9. **Decision:** Update `EXPECTED_CALL_SITES` in AUD-0006 test rather than skip dead-code-removal exemption.
   **Proposed by:** Claude.
   **Rationale:** When deleting `services/stops.py` for AUD-0212, the AUD-0006 test pinned its place_conditional_order call count via `EXPECTED_CALL_SITES = {..., "lib/tradelens/services/stops.py": 1, ...}`. The fail message would have been "stops.py: expected 1 call site, found 0". I removed the row entirely from the dict because the file is gone. This is test maintenance, not test deletion — the AUD-0006 contract is preserved for all surviving call sites.
   **Alternatives considered:** (a) Skip the test maintenance and let it fail — rejected as obvious. (b) Mark the row as `0` instead of removing — rejected because that's wrong (the file shouldn't be in the map). (c) Remove the row — chosen.
   **Revisit if:** Never. This is a one-time cleanup.
   **Affects:** test_aud0006_place_conditional_order_required.py.

## Rejected approaches (and why)

1. **Approach:** Do the AUD-0224 23-site PooledDB→get_db_connection migration as a partial 5-8-endpoint demonstration.
   **Who proposed it:** Claude (briefly considered before parking).
   **Why rejected:** Inconsistent state across the file (some endpoints with new shape, some with old) is worse than uniform old. The audit explicitly says "30+ endpoint sweep; cluster as one commit." Partial migration would also need to be revisited at AUD-0008 implementation time, doubling the work.
   **Would we reconsider if:** Never. Partial migrations on this kind of shape are anti-patterns.

2. **Approach:** Inline a runtime AUD-0098 "if local timestamp newer, skip overwrite" check in refresh_order_leg_live's UPSERT.
   **Who proposed it:** Claude (briefly considered before parking).
   **Why rejected:** The pipeline's UPSERT for order_leg_live runs on every cycle; adding a per-row `WHERE order_leg_live.updated_at < EXCLUDED.exchange_updated_at` clause would interact with the existing AUD-0165 stale-cleanup logic, the AUD-0147 parameterised SQL, and the WAEP-after-leg backfill. Risk of subtle pipeline regressions outweighs the small remaining race window.
   **Would we reconsider if:** A pipeline-architecture wave is undertaken with focused integration tests for the UPSERT path.

3. **Approach:** Make AUD-0036 fully literal — relocate `place_order`, `place_conditional_order`, `set_trading_stop` from adapter to `services/` and call them from API code.
   **Who proposed it:** Audit text suggestion.
   **Why rejected:** 21 call sites across 7 files would need updating. `set_trading_stop` has zero live callers (verified by grep), so a relocation would be performative for it. AUD-0006 already established the surgical "make defaults required" pattern that addresses the audit's actual concern (silent policy inheritance) without the cross-file relocation.
   **Would we reconsider if:** A dedicated services/ layer wave that does the moves with proper testing.

4. **Approach:** AUD-0316 (frontend stale-closure) — fix the 2 `eslint-disable-next-line react-hooks/exhaustive-deps` comments in smart-trade-form.tsx by properly declaring deps.
   **Who proposed it:** Audit text suggestion.
   **Why rejected:** Both sites are deliberately disabled with documented reasons (one is a "react to preview, not own writes" pattern; one is mount-only). Properly declaring deps would either re-introduce the stale-closure problem they were guarding against or cause infinite loops via the very state they write. A correct fix needs `useCallback` wrapping or `useRef` patterns that need browser testing — and AUD-0320 (frontend test gap) is parked, so I have no test harness to verify behaviour. Without tests, blind re-enabling of the eslint rule is a regression vector.
   **Would we reconsider if:** Frontend test infrastructure is set up (AUD-0320 ships).

5. **Approach:** Re-attempt the 6-agent parallel `Agent`-tool dispatch from Campaign 1.
   **Who proposed it:** Considered briefly at session start (carried-forward from prior sessions).
   **Why rejected:** Campaign 1 proved this pattern hits Anthropic per-day usage limits with 0/6 useful output. Direct main-session edits stay as the canonical shape.
   **Would we reconsider if:** Anthropic raises quotas significantly AND work is genuinely parallel.

6. **Approach:** AUD-0345's literal `bin/tools/_lib/cli_base.py` location.
   **Who proposed it:** Audit text suggestion.
   **Why rejected:** Required adding `__init__.py` to `bin/` + `bin/tools/`, plus a new sys.path entry in every script. More boilerplate than the helper saves. `tradelens.utils.cli_base` is already on the importable path each script bootstraps.
   **Would we reconsider if:** Never.

7. **Approach:** Estimate the remaining 60 Confirmed AUDs by calendar-day.
   **Who proposed it:** Claude (in a status report mid-session).
   **Why rejected:** Already rejected last session by user pushback at the Day 2 close. Stuck to focused-work-hour buckets + honest "this is multi-day" / "this needs decision" classifications instead.
   **Would we reconsider if:** Never. Use focused-work-hour or "multi-day" labels going forward.

## Files touched or about to touch

(Comprehensive list of all files this session edited. State as of `d9aad8ca` HEAD; parallel-session work after that not in this list.)

1. `/app/syb/tradesuite/tradelens/lib/tradelens/api/stops.py` — **DELETED** (AUD-0212).
2. `/app/syb/tradesuite/tradelens/lib/tradelens/services/stops.py` — **DELETED** (AUD-0212).
3. `/app/syb/tradesuite/tradelens/lib/tradelens/api/suspend.py` — **edited-saved** (AUD-0215). Added `_CRITICAL_RESUME_LEG_TYPES` frozenset at module level; gated status-update on `if not resume_partial:`; added `partial` + `failed_orders` to `ResumeTradeResponse`.
4. `/app/syb/tradesuite/tradelens/lib/tradelens/api/batch_ideas.py` — **edited-saved** (AUD-0216 + AUD-0225 + AUD-0233). Converted `batch_create_ideas` + 2 helpers to `def`; added autocommit=False wrap to CREATE-branch cascade.
5. `/app/syb/tradesuite/tradelens/lib/tradelens/api/ideas.py` — **edited-saved** (AUD-0219 — SQL LIMIT/OFFSET). Then partially edited and reverted for AUD-0224 (per the parked decision).
6. `/app/syb/tradesuite/tradelens/lib/tradelens/api/trades.py` — **edited-saved** (AUD-0120 INSERT-not-append + AUD-0122 SL trigger via shared helper + AUD-0112 submit account verify).
7. `/app/syb/tradesuite/tradelens/lib/tradelens/api/open_orders.py` — **edited-saved** (AUD-0093 REFRESH_SCRIPT TLHOME + AUD-0095 QtyResult NamedTuple). Plus the 2 callers updated to consume the close_entire flag.
8. `/app/syb/tradesuite/tradelens/lib/tradelens/api/trader_scorecard.py` — **edited-saved** (AUD-0342 batched note query).
9. `/app/syb/tradesuite/tradelens/lib/tradelens/api/system_monitor.py` — **edited-saved** (AUD-0350 atomic /proc read).
10. `/app/syb/tradesuite/tradelens/lib/tradelens/api/guards.py` — **edited-saved** (AUD-0201 5 handlers async→sync).
11. `/app/syb/tradesuite/tradelens/lib/tradelens/api/journal.py` — **edited-saved** (AUD-0141 — alerts subsystem extracted; line count 5873 → 5206).
12. `/app/syb/tradesuite/tradelens/lib/tradelens/api/trade_alerts.py` — **NEW** (AUD-0141 — 633 lines, 6 endpoints + 6 classes).
13. `/app/syb/tradesuite/tradelens/lib/tradelens/main.py` — **edited-saved** (AUD-0212 stops removed; AUD-0141 trade_alerts router registered).
14. `/app/syb/tradesuite/tradelens/lib/tradelens/models/dto.py` — **edited-saved** (AUD-0212 — StopConfigRequest/Response removed).
15. `/app/syb/tradesuite/tradelens/lib/tradelens/services/portfolio.py` — **edited-saved** (AUD-0212 — load_stop_configs removed).
16. `/app/syb/tradesuite/tradelens/lib/tradelens/services/sizing.py` — **edited-saved** (commit `13262229` was test-only, no code change for AUD-0056 — fix already shipped via 068f199b).
17. `/app/syb/tradesuite/tradelens/lib/tradelens/utils/state_manager.py` — **edited-saved** (AUD-0247 — flock + on-disk merge; new `_max_message_id` helper).
18. `/app/syb/tradesuite/tradelens/lib/tradelens/utils/cli_base.py` — **NEW** (AUD-0345 — `add_debug_arg`, `apply_debug_arg`, `connect_db`, `DecimalEncoder`).
19. `/app/syb/tradesuite/tradelens/lib/tradelens/core/logging.py` — **edited-saved** (AUD-0371 added `setup_rotating_logger` helper + `ROTATING_LOG_*` constants). **POST-SESSION**: parallel session at `c8bdf6c8` further edited to gate StreamHandler on `sys.stdout.isatty()` to avoid duplicate log lines under daemon redirect.
20. `/app/syb/tradesuite/tradelens/lib/tradelens/core/db_pool.py` — **DELETED** (AUD-0030 shim deletion).
21. `/app/syb/tradesuite/tradelens/lib/tradelens/mdsync/reconcile.py` — **edited-saved** (AUD-0370 — denylist + canonicalisation + `_canonicalise_or_drop` helper, wired into 3 watchlist-construction loops).
22. `/app/syb/tradesuite/tradelens/lib/tradelens/adapters/bybit_client.py` — **edited-saved** (AUD-0036 — place_order required kwargs).
23. `/app/syb/tradesuite/tradelens/bin/pipeline/refresh_order_leg_live.py` — **edited-saved** (AUD-0166 + AUD-0154 + AUD-0176 + AUD-0168). Multiple edits: added `_fetch_history_for_disappeared`, added `prefetched_history` kwarg to `archive_disappeared_order`, ThreadPoolExecutor in cleanup loop, batch-load snapshot dict, ClassifiedOrder NamedTuple, `_classified_orders` map, properties, cli_base import.
24. `/app/syb/tradesuite/tradelens/bin/pipeline/refresh_order_leg_hist.py` — **edited-saved** (AUD-0168 cli_base import + add_debug_arg/apply_debug_arg).
25. `/app/syb/tradesuite/tradelens/bin/pipeline/refresh_trade_journal.py` — **edited-saved** (AUD-0168 cli_base import + add_debug_arg/apply_debug_arg).
26. `/app/syb/tradesuite/tradelens/bin/engine/alert_engine.py` + `correlation_worker.py` + `vwap_series_worker.py` + `vwap_order_engine.py` — **edited-saved** (AUD-0371 — wired to `setup_rotating_logger`).
27. `/app/syb/tradesuite/tradelens/bin/mdsync_pg.py` — **edited-saved** (AUD-0371 inline RotatingFileHandler — cold-start path). **POST-SESSION**: parallel session at `c8bdf6c8` further edited to gate the StreamHandler on `sys.stdout.isatty()`. Working tree currently has uncommitted further edits (parallel-session WIP).
28. `/app/syb/tradesuite/tradelens/bin/telegram_signals.py` — **edited-saved** (AUD-0371 inline RotatingFileHandler — cold-start path).
29. `/app/syb/tradesuite/tradelens/bin/tools/breach_*.py` (10 scripts) — **edited-saved** (AUD-0345 — migrated to cli_base via `/tmp/migrate_breach_scripts.py`).
30. `/app/syb/tradesuite/tradelens/extension/popup.js` + `background.js` + `manifest.json` — **edited-saved** (AUD-0248 + AUD-0249 — scheme guards + optional_host_permissions).
31. `/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md` — **edited-saved** (4 tracker batches: Wave 3A close, Wave 3B partial, Day 3 batch, Day 3 final + extension batch + tier-2 batch).
32. `tests/unit/test_aud0212/0215/0216_0225/0219/0342/0350/0093/0120/0122/0233/0247/0056/0370/0112/0248/0030/0249/0095/0166/0036/0345/0141/0201/0154/0176/0168/0371_*.py` — **NEW** files. Plus updates to existing tests `test_aud0006_place_conditional_order_required.py` (EXPECTED_CALL_SITES), `test_trades_limit.py` (post-AUD-0120 sentinel relax), `test_aud0217_batch_ideas_overwrite_transaction.py` (sync stub), `test_aud0088_calculate_quantity_decimal.py` (5 unpacks for AUD-0095), `test_guards_config_allowlist.py` (asyncio.run drop for AUD-0201), `test_refresh_order_leg_live_archive_guard.py` (`**kwargs` for AUD-0166), `test_bybit_mock_pattern.py` + `test_aud0039_orderlinkid_adapter.py` (explicit kwargs for AUD-0036).
33. `~/.claude/tasks/context/20260429-093000-c2d3-mechanical-medium-sweep.md` — **NEW** (`/t-done` close context).

## Open threads

1. **Thread:** rocky2 deployment of parallel-session AUD-0371 follow-up commit `c8bdf6c8`.
   **State:** Not done. rocky2 is still on commit `4998134a` (my AUD-0370 ship). The follow-up fixes a duplicate-log-line bug under daemon redirect that my AUD-0371 ship caused.
   **Context needed to resume:** `git rev-parse HEAD` on rocky2 vs origin/master — the gap is `4998134a..dede1709`. Standard redeploy dance: `ssh sybase@10.50.0.2 'cd /app/syb/tradesuite && git stash push -- tradelens/etc/config.yml && git pull origin master && git stash pop && /app/syb/tradesuite/tradelens/bin/mdsync_pg restart'`.
   **Expected resolution:** Operator decision — the duplicate-line bug is annoying but functionally non-blocking; redeploy can wait for the next operator-convenient window.

2. **Thread:** Day 4 candidate waves not started.
   **State:** Wave C (multi-table tx wrap, AUD-0140 + lift `_atomic_block` to `core/db_helpers.py`) — campaign plan has the pre-dispatch table at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md` Day 4-5 section. Wave 3B remaining items (0345 already shipped, 0346 breach_analysis tests, 0371 already shipped). Mechanical sweep across the remaining 60 Confirmed pool.
   **Context needed to resume:** Campaign plan doc; AUDIT_TRACKER.md current state.
   **Expected resolution:** User picks Day 4 target + new claude-task starts.

3. **Thread:** AUD-0170 `OrderClassifier` god-object decomposition.
   **State:** T3 design ready — `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0155-0170-0171-pipeline-architecture-design.md` documents the 3-cache + N-rules-classes + thin-orchestrator decomposition. AUD-0176 (this session's typed `_classified_orders`) is compatible with that design — the property accessors absorb cleanly into a `ClassifierState` cache class.
   **Context needed to resume:** Design doc above; verify all 7 state maps still match.
   **Expected resolution:** Multi-day implementation wave.

4. **Thread:** Parallel-session uncommitted working-tree state.
   **State:** 3 modified files at session checkpoint time — `tradelens/bin/mdsync_pg.py`, `tradelens/bin/setup/migrate_parser_inbox.py`, `tradelens/tests/unit/test_aud0260_recursive_expansion_loaders.py`. None of these were touched by my session.
   **Context needed to resume:** N/A — leave alone.
   **Expected resolution:** The parallel session will commit them when their work-in-progress is ready.

5. **Thread:** AUD-0316 frontend stale-closure fix waiting on AUD-0320 test infrastructure.
   **State:** Both parked. AUD-0316 needs `useCallback`/`useRef` fixes that require browser testing to verify; AUD-0320 (frontend test coverage) is parked because frontend testing infra (Vitest + jsdom for component tests) isn't set up yet.
   **Context needed to resume:** AUD-0320 design first.
   **Expected resolution:** Multi-day frontend infra wave.

6. **Thread:** AUD-0341 + AUD-0343 C-bucket — operator sign-off pending.
   **State:** Both bundled awaiting product/operator decision on the `source_channel_key` schema column addition. AUD-0342 (this session's N+1 fix) is independent and shipped.
   **Context needed to resume:** AUDIT_TRACKER.md AUD-0341 and AUD-0343 rows; the trader_scorecard cluster discussion in the campaign plan doc.
   **Expected resolution:** Operator decision needed.

## Surprises / gotchas

1. **Finding:** The `setup_logging` + `RotatingFileHandler` combo I shipped in AUD-0371 produced byte-identical duplicate log lines under daemon redirect.
   **How discovered:** Parallel session at `c8bdf6c8` caught and fixed it. The mechanism: `nohup ... >> logs/<svc>.log 2>&1` makes stdout the log file; my `setup_logging` added a `StreamHandler(sys.stdout)` AND a `RotatingFileHandler` for the same file, so each `logger.info(...)` got written by both handlers, ending up in the file twice.
   **Time cost:** Zero for me (I shipped the bug, didn't catch it); the parallel session ate the cost.
   **Implication:** ANY future daemon-side log handler addition needs the `if sys.stdout.isatty():` gate. The pattern is now established at `lib/tradelens/core/logging.py:setup_logging` (with explanatory comment) and `bin/mdsync_pg.py:setup_logging` (cold-start variant with same gate).
   **Where it's documented:** Inline comments at both sites + the AUD-0371 follow-up commit message at `c8bdf6c8`.

2. **Finding:** `set_trading_stop` in `bybit_client.py` has zero live callers in `lib/` or `bin/`.
   **How discovered:** AUD-0036 investigation — `grep -rn "\.set_trading_stop("` returned only the function definition itself.
   **Time cost:** ~5 minutes (clear grep).
   **Implication:** AUD-0036 deliberately did NOT make set_trading_stop's defaults required because adding "required" args to a function with no callers is performative. Future audit work should treat set_trading_stop as effectively deprecated; the AUD-0115 design doc already mentions it as available-but-unused.
   **Where it's documented:** AUD-0036 commit message + AUDIT_TRACKER.md row.

3. **Finding:** `trade_idea` table on prod still has 5 rows with the AUD-0370 invalid symbols (`PEPEUSDT` (Bybit-renamed to `1000PEPEUSDT`), `BULLAUSDT`, `DEGOUSDT`, `1000CHEEMSUSDT`, `BGLS/USDT`).
   **How discovered:** During AUD-0370 implementation, ran `psql ... -c "SELECT DISTINCT symbol, count(*) FROM trade_idea WHERE symbol IN ('PEPEUSDT','BULLAUSDT','DEGOUSDT','1000CHEEMSUSDT','BGLS/USDT') GROUP BY symbol;"` and got 5 rows back.
   **Time cost:** ~10 minutes to decide the right fix shape.
   **Implication:** The AUD-0370 fix doesn't modify these rows (historical record preserved); it filters at watchlist-construction time in mdsync's reconcile.py. If the user ever wants to clean up the trade_idea rows themselves (e.g. update PEPEUSDT → 1000PEPEUSDT for canonicalisation), that's a separate data-migration ship.
   **Where it's documented:** `lib/tradelens/mdsync/reconcile.py` _SYMBOL_DENYLIST + _SYMBOL_CANONICALISATIONS module-level dicts; AUDIT_TRACKER.md AUD-0370 row.

4. **Finding:** AUD-0056 was already fixed in commit `068f199b` (AUD-0077 Numeric refactor) but never had a regression test or tracker flip.
   **How discovered:** Reading sizing.py's `calculate_profit_scenarios` to understand the AUD-0056 bug, found the comment block at lines 693-714 that explained the new `(profit_usd / position_cost) * 100` formula. The actual code-fix had landed but tracker still showed Confirmed.
   **Time cost:** ~5 minutes to verify via `git log -G "position_cost > 0"`.
   **Implication:** Other "Confirmed" tracker rows may have already-shipped fixes that just weren't tracker-flipped. A future tracker-audit pass could find more.
   **Where it's documented:** AUDIT_TRACKER.md AUD-0056 row + tests/unit/test_aud0056_profit_pct_position_return.py.

5. **Finding:** `bin/pipeline/refresh_order_leg_live.py:OrderClassifier`'s `smart_order_positions` attribute is dead — declared at `__init__` but never written to anywhere in the codebase.
   **How discovered:** AUD-0176 investigation — searched for all references to `smart_order_positions`. Result: defined at line 59, mentioned in 1 docstring (the design doc for AUD-0170), no other references.
   **Time cost:** ~5 minutes.
   **Implication:** Deleting it as part of AUD-0176 caused zero behavioural change. The AUD-0170 design doc should be updated to remove the reference; not done in this session because it's a docs-only change in a future-design document.
   **Where it's documented:** AUDIT_TRACKER.md AUD-0176 row + the deletion itself.

6. **Finding:** `git push origin master` from this session was followed by 6 parallel-session commits BEFORE I closed via `/t-done`.
   **How discovered:** During `/t-checkpoint` I ran `git rev-parse --short HEAD` and got `dede1709` — different from the `d9aad8ca` I had at session close. `git log --oneline d9aad8ca..HEAD` showed 6 commits including `c8bdf6c8` (AUD-0371 follow-up that fixed my duplicate-log-line bug).
   **Time cost:** Zero — caught at checkpoint time, no rework needed.
   **Implication:** Future sessions running long against an active parallel session need to git-fetch periodically. The campaign 2 dispatch document's "parallel-session hot zones" lookup is only as fresh as the last fetch.
   **Where it's documented:** This checkpoint.

## Commands that mattered

1. **Command:** `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $4); sev=$4; gsub(/^ +| +$/, "", $6); status=$6; if (status == "Confirmed") print sev }' tradelens/AUDIT_TRACKER.md | sort | uniq -c | sort -rn`
   **Output (relevant portion at session start):**
   ```
        58 Major
        18 Critical
        12 Minor
         1 Architecture
   ```
   **What we inferred:** 89 Confirmed audits at session start; 18 Critical and 58 Major are the highest-leverage targets.

2. **Command:** `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | sort | uniq -c | sort -rn` (run repeatedly throughout the session to track progress).
   **Output (final at session close):**
   ```
       285 Resolved
        60 Confirmed
        16 Resolved (partial)
         9 Design ready (T3 implementation pending)
         3 Works as intended
         2 Runbook prepared (user-only execution pending)
         2 Resolved (duplicate)
         1 Suspicious
         1 Parked
         1 Doc shipped (event-driven NOTIFY/LISTEN deferred)
   ```
   **What we inferred:** 89 → 60 Confirmed (−29). 257 → 285 Resolved (+28; one was already Resolved-via-parallel-session at AUD-0077). Headline: −33% of day-start backlog cleared.

3. **Command:** `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1` (run repeatedly).
   **Output (final at session close):**
   ```
   2108 passed, 4 skipped, 9 warnings in 91.36s (0:01:31)
   ```
   **What we inferred:** Master is green at session close. Test count grew 1903 → 2108 (+205) across the session.

4. **Command:** `grep -rn "\.place_order(" tradelens/lib/ tradelens/bin/ 2>/dev/null | grep -v __pycache__`
   **Output (relevant portion):**
   ```
   tradelens/lib/tradelens/api/journal.py:4053  (3 calls)
   tradelens/lib/tradelens/api/suspend.py:894   (3 calls)
   tradelens/lib/tradelens/api/open_orders.py:3359, 5103  (2 calls)
   tradelens/lib/tradelens/api/trades.py:1582, 1628, 1696, 1870, 2031  (5 calls)
   tradelens/lib/tradelens/services/suspend_service.py:558  (1 call)
   tradelens/bin/server/level_guard_daemon.py:581, 649  (2 calls)
   ```
   **What we inferred:** 16 production call sites. Combined with checking each site for `reduce_only=` and `position_idx=` kwargs (all 16 have them), confirmed AUD-0036's keyword-only conversion is API-tightening with no behaviour change.

5. **Command:** `ssh sybase@10.50.0.2 'cd /app/syb/tradesuite && git stash push -- tradelens/etc/config.yml && git pull origin master && git stash pop && /app/syb/tradesuite/tradelens/bin/mdsync_pg restart'`
   **Output (relevant portion):**
   ```
   Stopping all mdsync_pg processes...
   Stopping mdsync_pg python process(es): 49223 49227
   All mdsync_pg processes stopped
   Starting mdsync_pg (with auto-restart)...
   mdsync_pg started (PID: 182965)
   ```
   **What we inferred:** Successful redeploy. Two redeployments this session for AUD-0371 and AUD-0370.

6. **Command:** `git log --oneline d9aad8ca..HEAD 2>&1 | head -10` (run during /t-checkpoint).
   **Output:**
   ```
   dede1709 feat(security): AUD-0354 Phase A.5/A.6/A.7 — config.yml secrets via ${VAR} + .example template
   0dab9dee feat(config): AUD-0260 — recursive ${VAR} expansion in YAML config loaders
   d3b2067e test(tl): allow unexpected boolean in tl status --json entry shape
   c8bdf6c8 fix(daemons): AUD-0371 follow-up — gate StreamHandler on isatty() to stop duplicate log lines
   d6c955f7 fix(tl): surface unexpected running services not owned by this host
   63089c60 docs(checkpoints): un-ignore archive and add 15 historical checkpoints
   ```
   **What we inferred:** 6 parallel-session commits between session close and checkpoint. `c8bdf6c8` is the AUD-0371 follow-up that fixed my duplicate-log-line bug.

## Schema / API / data facts worth preserving

- **Fact:** Bybit's order history API (`/v5/order/history`) does NOT support batch fetch by orderId. AUD-0166's "parallel" win comes from `ThreadPoolExecutor` over per-order calls, not a batched endpoint. **Evidence:** `BybitClient.get_order_history` signature accepts a single `order_id` param. **Why it matters:** Future "make it faster" attempts on this path can't go below per-order round-trip; the only further optimisation is widening the ThreadPoolExecutor's max_workers (currently 4, conservative for Bybit per-IP rate limit).

- **Fact:** Bybit's stop-orders convention treats `qty=0` on reduce-only orders as "close entire position." This was the wire-level reason the pre-AUD-0095 `calculate_quantity` returned `'0'` for `qty_mode='entire'`. The QtyResult NamedTuple keeps this shape on the wire while making the intent explicit in the typed API. **Evidence:** Comment at `lib/tradelens/api/open_orders.py:calculate_quantity` (post-AUD-0095). **Why it matters:** Any future caller building a Bybit reduce-only order needs to know `qty='0'` is the wire convention, not an error.

- **Fact:** `psycopg2` connections are NOT thread-safe; cursors from the same connection cannot be used concurrently across threads. This is why AUD-0166's parallelisation only fans out the Bybit fetch (network I/O) and keeps DB writes serial on the main thread's connection. **Evidence:** psycopg2 documentation; observed at AUD-0166 implementation time. **Why it matters:** Any "parallelise pipeline N×" attempt has to either keep DB writes serial OR open one connection per thread (which AUD-0167's persistent-daemon path would address).

- **Fact:** `tradelens.utils.cli_base.connect_db(logger)` returns `(db, conn, cursor)` 3-tuple. The caller is responsible for `cursor.close()` and `db.close()` in a `finally` block. **Evidence:** `lib/tradelens/utils/cli_base.py:connect_db` docstring. **Why it matters:** Future scripts adopting cli_base must follow the close-pair pattern; not following it leaks connections.

- **Fact:** `OrderClassifier._classified_orders: Dict[str, ClassifiedOrder]` is the new single source of truth for the classifier's seed-order tracking. The `seeded_entry_orders` and `seed_orders` attributes are read-only properties returning fresh dict views over this map. **Evidence:** `bin/pipeline/refresh_order_leg_live.py:OrderClassifier` post-AUD-0176. **Why it matters:** Any future code reading `classifier.seed_orders[oid]['symbol']` keeps working but is reading a fresh dict each time; mutations don't leak back. Writes must go through `_classified_orders` directly.

- **Fact:** `setup_logging` + daemon `RotatingFileHandler` combo produces byte-identical duplicate log lines under daemon redirect (`nohup ... >> logs/<svc>.log 2>&1`) UNLESS the StreamHandler is gated on `sys.stdout.isatty()`. **Evidence:** AUD-0371 follow-up commit `c8bdf6c8`. **Why it matters:** Pattern documented at both `lib/tradelens/core/logging.py:setup_logging` and `bin/mdsync_pg.py:setup_logging`. Future daemon log handler additions must follow this gate.

- **Fact:** `_atomic_block` context manager for autocommit=False transactions still lives at `lib/tradelens/api/open_orders.py:46-72`. The Wave C ship would lift it to `lib/tradelens/core/db_helpers.py`, but that hasn't happened yet. AUD-0233 reused the same shape inline rather than waiting. **Evidence:** `lib/tradelens/api/open_orders.py` source. **Why it matters:** Any future "use _atomic_block" should import from open_orders.py until Wave C ships the lift.

## Next steps

The session is at a clean stopping point. There is no implicit next action — the user must direct.

Possible directions in priority order from highest to lowest leverage:

1. **rocky2 redeploy of `c8bdf6c8` (AUD-0371 follow-up).** The duplicate-log-line bug from my session's AUD-0371 ship is on rocky2's mdsync_pg.log right now. Standard redeploy dance documented above. Estimated time: ~2 minutes.

2. **Day 4 Wave C — Multi-table tx wrap.** AUD-0140 (3 endpoints in journal.py — cancel-seed, cancel-pending, force-open) plus the `_atomic_block` lift to `core/db_helpers.py`. Pre-dispatch table at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-28-campaign-2-plan.md` Day 4-5 section. Estimated effort: ~6-8 hours of focused work; the audit-tracker AUD-0140 row notes the implementation is "non-trivial" because each function interleaves Bybit API calls with DB writes (split into pre-API + post-API atomic blocks).

3. **Mechanical sweep across remaining 60 Confirmed pool.** ~5-8 audits genuinely mechanical and tractable next session per my honest re-classification: pick anything in `Minor / Cleanup` category that's single-file. Estimated time: ~3-4 hours per AUD batch.

4. **Operator decisions for parked items.** AUD-0341 + 0343 C-bucket sign-off; AUD-0240 Discord ToS decision.

5. **AUD-0170 god-object decomposition design implementation.** Multi-day work; design doc ready at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0155-0170-0171-pipeline-architecture-design.md`. AUD-0176 (this session) is compatible.

6. **Frontend cluster (AUD-0308-0320).** Multi-day each. Schedule one per session.

If the user says "continue" with no other context, do NOT auto-pick from this list — ask what they want.

## Verification checklist for the next session

1. `git rev-parse --short HEAD` should be `dede1709` OR a more-recent master tip (parallel session may have shipped further). If significantly different, run `git log --oneline dede1709..HEAD` to see what's new.

2. `git status --short` should show 3 modified files (parallel-session WIP) + the pre-existing `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` symlink. None of these are session work.

3. `claude-task current` should return empty (no active task — closed via /t-done at d9aad8ca).

4. `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | grep -c "Confirmed$"` should return 60.

5. `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | grep -c "Resolved$"` should return 285.

6. `ls tradelens/lib/tradelens/utils/cli_base.py` should exist (AUD-0345 helper module).

7. `ls tradelens/lib/tradelens/api/trade_alerts.py` should exist (AUD-0141 extracted module).

8. `ls tradelens/lib/tradelens/core/db_pool.py` should NOT exist (AUD-0030 deleted).

9. `ls tradelens/lib/tradelens/api/stops.py` should NOT exist (AUD-0212 deleted).

10. `pytest --ignore=tests/unit/test_breach_decision_orchestrator.py 2>&1 | tail -1` should report ~2108+ passed (parallel session may have added more tests).

11. rocky2 connectivity: `ssh sybase@10.50.0.2 'pgrep -fa mdsync_pg.py | head -2'` should show 2 lines (autorestart wrapper + python child).

If any of these fail, the checkpoint is stale on that point; re-validate before acting.
