# Checkpoint: AUD-0008 fully shipped + AUD-0002 retry flag flipped on rocky-8gb only — mdsync scope-gap documented

**Saved:** 2026-04-30 15:23:43 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ 95842190
**Session:** def3f248-ba94-452a-872b-b46e229bc0f4
**Active task:** none

## Handover Statement

You are picking up a tradelens session that has FINISHED two pieces of audit-tracker work (AUD-0008 is now fully Resolved with all 7 phases shipped over 6 commits this session; AUD-0002 was already Resolved at session start and the post-soak retry flag has been operationally flipped on rocky-8gb api with the circuit-breaker flag still parked). The user closed both tasks via `/t-done` (`20260430-115500-aud-0008-b2-pooled-db` → c4cffeb3, then `20260430-163139-aud-0002-mdsync-scope-note` → 775124e3). At time of writing there is **no active claude-task**, the working tree is clean of any work I did, and the only uncommitted files in `git status --short` belong to an unrelated parallel session (a tick-archive refactor + 5 swing-research markdown files + the pre-existing Obsidian-viewing AUDIT_TRACKER.md symlink). Do NOT touch those files. HEAD has moved past my last commit too: a parallel session committed `95842190 fix(api): Resolve postgres log path via pg_current_logfile()` between my session-end and this checkpoint — that's not my work either.

The single most important state-of-the-world fact to know: **`TRADELENS_BYBIT_RETRY_ENABLED='true'` is set on rocky-8gb api only.** It was set on rocky2 mdsync_pg too at first, but I rolled it back when I discovered (via post-flip log inspection) that `lib/tradelens/mdsync/fetcher.py` opens its own `httpx.Client` and bypasses `bybit_client._request` entirely — meaning the AUD-0002 retry/throttle/breaker code path I shipped never gets exercised on rocky2 regardless of the flag. The rocky2 secrets file (`/app/syb/.tradelens.secrets`) now has an explanatory comment block where the export used to be. This scope gap is also documented in the AUD-0002 row of `tradelens/AUDIT_TRACKER.md` (commit `775124e3`). The circuit-breaker flag `TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED` is parked (commented out) in both secrets files; flip plan is ~Day 7-14 after observing retry-rate logs on rocky-8gb.

What to Read FIRST, in order: (1) THIS checkpoint's "Handover Statement" + "Decisions still in effect" + "Rejected approaches"; (2) the previous checkpoint that this session loaded at start, `tradelens/docs/80-claude-checkpoints/20260430-094733-140fa7f4-aud-0002-fully-shipped-4-commits-aud-000.md` (it was the input to this session); (3) `tradelens/AUDIT_TRACKER.md` rows for AUD-0008 (now `Resolved`) and AUD-0002 (now `Resolved`, with the post-flip soak scope-note appended); (4) `lib/tradelens/mdsync/fetcher.py:73` (the comment that explains why mdsync uses its own httpx client and not bybit_client).

Known landmines that already bit us this session: (a) **A parallel claude session committed while my B-3 staged files were in the index, sweeping them into commit `0992a6f0` titled `feat(breach-decision): retrain B7 — bridge breach_event into decision_log`**. The B-3 migration content is correct but the message is misleading. The user explicitly said: *"if there's no corruption then I don't care … it's not a problem if both are committed in the same commit"*. **DO NOT propose `git reset` / `rebase -i` to fix this** — the rule is now in memory at `feedback_no_cosmetic_git_rewrites.md`. (b) Multiple operator-style sessions appear to be running in this cwd in parallel; assume any uncommitted changes you didn't make yourself belong to them. (c) `ps -o lstart` reports system-local time (CEST = UTC+2) while api logs use UTC `Z`-suffixed timestamps; don't confuse them when correlating events. (d) The autorestart wrapper at `bin/lib/autorestart.sh` re-spawns uvicorn on crashes and inherits env from `~/.tradelens.secrets` via `sourceme.sh`, so env-flag flips persist across crashes but NOT across operator-driven `tl restart` cycles where the operator has unset them.

What NOT to do: do not propose circuit-breaker flag flip yet (still in the 7-14 day soak window starting 2026-04-30); do not migrate `mdsync.fetcher` to use `bybit_client` without an explicit operator decision (logged as a follow-up option, not a committed plan); do not touch `/app/syb/.tradelens.secrets` on either host without explicit operator request; do not run `git reset`/`rebase -i` for cosmetic commit-message issues (see landmine A).

The exact next action the user is expecting: **none — both tasks are closed and the user invoked `/t-checkpoint`, not a fresh request.** If they come back with a new prompt, read it carefully; if they come back with `/t-done` again, just confirm there's nothing to commit.

## User note

(none — `/t-checkpoint` invoked without a free-form note)

## Session context

### User's stated goal (verbatim where possible)

This session opened with `/clear` and `/t-checkpoint-load`, which loaded the previous session's checkpoint (`20260430-094733-140fa7f4-aud-0002-fully-shipped-4-commits-aud-000.md`). After loading, the previous checkpoint's "Next steps" said *"Wait for user to pick option 1 / 2 / 3 (continue grinding / schedule autonomous / stop)"* on the AUD-0008 B-2..B-7 remainder. The user picked **option 1**: *"option 1 — continue grinding"* (10:05 UTC, prompt #1 of this session).

The implicit framing was: ship AUD-0008 to completion in this session. That expanded mid-session into an operational follow-up sequence: at 11:31 the user asked *"when should we flip the AUD-0002 env-flags (TRADELENS_BYBIT_RETRY_ENABLED / TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED) ?"* and at 11:45 escalated to *"You say 'the running api was last restarted at 10:35 UTC pre-this-session'. Show me the proof to back up this claim? Then flip TRADELENS_BYBIT_RETRY_ENABLED=true and run the relevant steps"* — i.e. ship the operational flip in addition to the code work. At 11:50 they pivoted to a sysadmin task: *"I just resized by /db/data01 volume from 150gb to 300gb on hetzner. can you help to resize the filesystem accordingly"*.

### User preferences and corrections established this session

Three corrections worth carrying forward:

1. **Don't pitch git-history rewrites for cosmetic message issues.** The user said verbatim (11:23 UTC): *"is there a problem here … is there any corruption ? If there's no corruption then I don't care right I don't it's not a problem if both are committed in the same commit. And why are you asking me questions about whether you can do a force push or not just do what you always do what's I don't get it"*. This was triggered by my flagging the parallel-session commit `0992a6f0` as a hygiene issue. I saved this lesson to memory at `/app/syb/.claude/projects/-app-syb-tradesuite/memory/feedback_no_cosmetic_git_rewrites.md` and indexed it from `MEMORY.md`.

2. **Always verify factual claims before stating them.** At 11:45 the user challenged *"You say 'the running api was last restarted at 10:35 UTC pre-this-session'. Show me the proof"*. My claim came from stale checkpoint text; the actual api had been restarted at 13:25 UTC during this session. The user accepted the correction and proceeded with the flip. This reinforces the existing memory `feedback_no_guessing_ever.md`.

3. **Confirmed approach for option-pick on AUD-0008 remainder.** At 10:05 UTC the user picked option 1 ("continue grinding") from the three options the previous session had laid out. This validated the prior session's framing and committed me to shipping B-2..B-7 in-session.

### Working environment

- **rocky-8gb (10.50.0.3, this host)** runs the api, dashboard, alert_engine, and other services. api PID 2769091 was started at 13:46:27 UTC by my `tl restart api` after I added `TRADELENS_BYBIT_RETRY_ENABLED='true'` to `/app/syb/.tradelens.secrets`. The autorestart wrapper later re-spawned it (probably from operator-driven external restart cycles between 14:00:01-14:02:24 system-local) into PID 2813497 (started 14:02 system-local = 12:02 UTC). At time of checkpointing, current uvicorn PID may have moved again — read `/proc/$(pgrep -f 'uvicorn.*tradelens.main')/environ` to confirm the env-flag persisted.
- **rocky2 (10.50.0.2)** runs only `mdsync_pg` (per memory `project_rocky2_mdsync_host.md`). At 13:47 UTC I flipped its retry flag, then at ~16:29 UTC I rolled it back after discovering the scope gap. Current mdsync_pg PID was 373262 (autorestart wrapper) → 373266 (python child), `TRADELENS_BYBIT_*` count in env is 0. SSH access via `ssh rocky2` is passwordless from rocky-8gb.
- **PostgreSQL** is in `/db/data01` on `/dev/sdb`. The block device was 300G on disk (Hetzner-grown) but the ext4 filesystem only saw 148G of it until I ran `sudo resize2fs /dev/sdb` at ~11:51 UTC. Post-resize: 295G usable, 39% full (108G used / 176G free). PostgreSQL ran throughout; no downtime.
- **Python venv** at `/app/syb/tradesuite/venv`, activated by `source /app/syb/tradesuite/sourceme.sh`. `TLHOME=/app/syb/tradesuite/tradelens`.
- **Test database** `tradelens_test` is alongside `tradelens` on the same PG instance; conftest.py force-overrides auth env-vars during pytest runs.
- **Pre-existing untracked file `/tmp/migrate_pooled_db.py`** from the previous session is still on disk per the previous checkpoint's verification list. Do NOT use it — it failed on 4 of 5 B-2 files due to per-file pattern variation. This session's migration logic was rebuilt from scratch with proper state-machine handling.
- **Active task: none.** Last two tasks closed at 14:35 (AUD-0008 task → c4cffeb3) and ~16:31 UTC (AUD-0002 mdsync scope-note task → 775124e3).
- **Uncommitted state:** 2 files modified + 6 files untracked, ALL belong to a parallel session's tick-archive refactor + Obsidian symlink + breach-research markdowns. Do not commit them.

## Objective

The user's surface ask in this session was twofold: ship the AUD-0008 PooledDB → get_db_connection migration to completion (B-2 through B-7), and operationalize the AUD-0002 env-flag flip after the previous session shipped the code. The underlying motivation:

- **AUD-0008 closeout** removes the last of the legacy hybrid `PooledDB` wrapper. After this session, FastAPI handlers exclusively use `with get_db_connection() as conn:` (pool-borrowed), and standalone scripts/daemons use `PostgresDB` (direct psycopg2). This eliminates the AUD-0001 re-introduction risk: the canonical with-block always returns the connection to the pool on exception, while the manual close-in-finally pattern repeatedly leaked.
- **AUD-0002 operationalization** is needed because retry/throttle/breaker code shipping behind a default-off env-flag does NOTHING in production until an operator opts in. The user wanted the retry side flipped now (Phase A-1+A-2+A-3) with the circuit breaker (A-4) deferred per design A.5 risk #3 ("ship dark, soak retry-rate logs first").

Scope boundaries: **IN scope** for this session: B-2..B-7 file migrations, fence-test additions, ~30 patch-test rewrites where existing tests patched `module.PooledDB`, AUDIT_TRACKER row updates per phase, the operational env-flag flip on both hosts, and the filesystem resize. **OUT of scope**: rerouting `mdsync.fetcher` through `bybit_client` (discovered as a real scope gap during post-flip log inspection — documented but not addressed); fixing the parallel-session commit `0992a6f0`'s misleading message (user explicitly waved off); flipping the circuit breaker flag (deferred to Day 7-14).

## Narrative: how we got here

The session opened with `/clear` followed by `/t-checkpoint-load`. The most-recent checkpoint at the time was `20260430-094733-140fa7f4-aud-0002-fully-shipped-4-commits-aud-000.md` (saved 2h before this session by a previous claude — session UUID `140fa7f4-...`, distinct from this session's `def3f248-...`). That checkpoint's verification listed staleness warnings: HEAD had moved from `c6086f59` to `a726eb24` due to 3 unrelated breach-event commits, and the active task `20260430-085648-aud-0002-0008-bybit-db` was already closed. The work itself (AUD-0002 fully shipped, AUD-0008 B-1 spike) was intact.

Off the load, the checkpoint's "Next steps" said to wait for the user to pick option 1/2/3 on the B-2..B-7 remainder. The user picked option 1 ("continue grinding") and I started a new task `20260430-115500-aud-0008-b2-pooled-db`.

I worked through B-2 (4 files: templates.py, alerts.py, push.py, screenshots.py — 18 PooledDB sites). The migration script was rebuilt for this session using proper state-machine handling: the previous session had tried a regex-only approach (`/tmp/migrate_pooled_db.py`) that failed on 4 of 5 files. My approach: walk lines with a tokenize-aware filter to skip multi-line string interiors (this caught a real bug — without the tokenize filter I would have re-indented the HTML f-string inside `_render_screenshot_view`, corrupting every line of the rendered output by adding 4 leading spaces). Committed as `354d3d84`.

Mid-B-3 work, a **parallel-session commit collision** happened. I had staged the B-3 files (correlation, vwap, vwap_orders, order_sets, suspend) and run `pytest`. Before I ran `git commit`, another claude session (running breach-decision retrain code) ran `git commit` and swept my staged files into ITS commit (`0992a6f0`, message `feat(breach-decision): retrain B7 — bridge breach_event into decision_log`). The user's verdict (11:23 UTC): *"if there's no corruption then I don't care … it's not a problem if both are committed in the same commit"*. So we did not fix the misleading message — but I saved the lesson to memory at `feedback_no_cosmetic_git_rewrites.md`.

B-4 (notes, journal, guards, spot, trade_alerts — 36 sites) and B-5 (ideas, batch_ideas, ai_feedback, open_orders, trades — 43 sites) shipped as `17cbc97b` and `10faa907`. B-5 required ~8 test files updating where they patched `module.PooledDB` — most tests had a `_make_db` or `_FakePooledDB` helper that I converted to a context-manager-mocking shape, and most call sites changed `patch.object(oo, "PooledDB", ...)` → `patch.object(oo, "get_db_connection", ...)`. The trickiest one was `test_aud0217_batch_ideas_overwrite_transaction.py` which had a `_PatchedPooledDB(real_pooled_db)` subclass pattern; I rewrote 5 tests to use a `@contextmanager` wrapper around `get_db_connection()` instead.

B-6 (`services/ai_snapshot.py`, `services/push_sender.py`, `services/pushover_sender.py`, plus the discovered-late `lib/tradelens/discord/idea_creator_base.py`) split per design D.5: ai_snapshot got `get_db_connection` (FastAPI-only caller), the senders got `PostgresDB` (mixed daemon callers that don't init the pool), idea_creator_base got `PostgresDB` (used by `bin/telegram_signals.py` and the Discord parser). Committed as `85437c29`. B-7 deleted the `PooledDB` class itself from `pg_pool.py` (76 lines), updated the docstring, dropped one PooledDB-specific test in `test_pg_pool.py`, and updated 2 source-shape regression tests in `test_aud0030_db_pool_shim_deleted.py` and `test_pool_getconn_autocommit_invariant.py`. Committed as `c4cffeb3`. Final BE gate: 2989 passed, 4 skipped.

After AUD-0008 closed, the user pivoted to operational work. At 11:31: *"when should we flip the AUD-0002 env-flags?"* I gave a phased recommendation (retry flag now, circuit breaker Day 7-14). At 11:45 the user demanded proof for my "10:35 UTC restart" claim — that came from stale checkpoint text, the actual api PID was different. I showed `ps -o lstart` evidence and current `/proc/$pid/environ` (no flags set), then proceeded with the flip. Edited `/app/syb/.tradelens.secrets` on rocky-8gb to add `export TRADELENS_BYBIT_RETRY_ENABLED='true'` (with a comment block explaining the design). `tl restart api` succeeded at 13:46:27 UTC (PID 2769091); env-flag verified in `/proc/.../environ`; `/api/v1/health` returned `{"status":"ok",...}`. Then via SSH I made the same change on rocky2 and `tl restart mdsync_pg` (PID 360723).

At 11:50 the user asked for the filesystem resize. `/db/data01` is `/dev/sdb`, ext4, NO partition table, NO LVM. Block device already 300G (Hetzner-grown), filesystem still 148G. `sudo resize2fs /dev/sdb` (online, with PostgreSQL writing throughout) took seconds. New size: 295G usable. The 5G shortfall vs 300G nominal is the default 5% reserved-blocks ratio applied only to the original 150G of blocks (not the new 150G).

Then the user asked me to verify the retry flag was working (11:55) and again later (14:21). The first sweep showed 0 retry events on both hosts — expected for a calm window. The second sweep was more interesting: rocky2 had logged 37 "Too many visits. Exceeded the API Rate Limit." errors in 2.5 hours, clustered at minute boundaries (14:00, 13:30, 13:00...). I expected the retry flag to be soaking these up, but the retry-event count was still 0. **Investigation revealed mdsync.fetcher uses its own httpx.Client and bypasses bybit_client entirely.** The retry/throttle/breaker code I shipped only wraps `bybit_client._request` — it doesn't touch mdsync's HTTP path. So the rocky2 flag flip was technically a no-op.

The user picked option 1 on my follow-up question (leave mdsync's existing rate limiter alone — it tolerates the errors at the application level, the next cycle re-fetches missed candles) and asked me to roll back the rocky2 flag. I edited `/app/syb/.tradelens.secrets` on rocky2 via `sed` (lines 136-152) to delete the AUD-0002 export block and replace it with an explanatory comment, then `tl restart mdsync_pg`. New PID 373262/373266; `TRADELENS_BYBIT_*` count in env is 0.

The user then asked me to add a scope-gap note to AUDIT_TRACKER. I auto-tracked this as task `20260430-163139-aud-0002-mdsync-scope-note`, edited the AUD-0002 row to append a paragraph explaining the bypass, committed as `775124e3`, closed the task.

After that, the session became read-only: a series of `/history` skill invocations testing different argument forms (--all, show N, --help, --full, --expand, --expand K), one `/sessionid` invocation, `/exit` (which I acknowledged but didn't act on since I'd already closed both tasks). Plus one `/t-done` invocation that found nothing to commit. Plus this `/t-checkpoint`.

## Work done so far

1. **Loaded previous checkpoint via `/t-checkpoint-load`** at session start (10:00 UTC). The checkpoint at `tradelens/docs/80-claude-checkpoints/20260430-094733-140fa7f4-aud-0002-fully-shipped-4-commits-aud-000.md` was read in full (478 lines). Its Decisions and Rejected approaches sections informed the rest of the session.

2. **Started task `20260430-115500-aud-0008-b2-pooled-db`** (10:55 UTC) for the B-2..B-7 closeout work.

3. **Migrated B-2** (templates.py 5 sites, alerts.py 8 sites, push.py 3 sites, screenshots.py 2 sites — 18 total). Committed as `354d3d84`. Migration script handled Pattern A/B/P, with tokenize-aware multi-line-string skipping. Fence test extended from 1 to 5 entries.

4. **Migrated B-3** (correlation.py 1 site, vwap.py 8 sites, vwap_orders.py 5 sites, order_sets.py 4 sites, suspend.py 7 sites — 25 total). Migration script extended for: Pattern A blank-lines between db = PooledDB and try, Pattern P with `db = None` outside try + `if db: db.close()` finally guard, mixed finally blocks with other cleanups (`if bybit:` / `if lock:` — surgical removal of just the db-cleanup lines). Updated `tests/integration/test_aud0218_suspend_intra_lock_transaction.py` to patch `get_db_connection` (returning a context manager) instead of `PooledDB` (12 patch.object call sites). **Committed as part of `0992a6f0`** by a parallel session collision (see Surprises).

5. **Migrated B-4** (notes.py 6 sites, journal.py 18 sites at 5312 LOC — biggest, guards.py 5 sites, spot.py 1 site, trade_alerts.py 6 sites — 36 total). Migration regex relaxed to accept `PooledDB(...)` with optional logger arg (one journal.py site had `PooledDB(config.database)` without the logger). Updated 3 AUD-0140 tests (cancel_pending_atomic, force_open_atomic, cancel_seed_atomic) to patch get_db_connection. Committed as `17cbc97b`. Fence test extended to 15 entries.

6. **Migrated B-5** (ideas.py 23 sites — most in any file, batch_ideas.py 3 sites, ai_feedback.py 3 sites, open_orders.py 9 sites at 5562 LOC, trades.py 5 sites — 43 total; cumulative 116). Updated 8 test files: test_aud0217_batch_ideas_overwrite_transaction.py (5 tests rewritten — replaced `_PatchedPooledDB(real_pooled_db)` subclass pattern with `@contextmanager` wrapper, added lazy `init_db_pool(test_db_config)` since these tests don't go through FastAPI lifespan), test_aud0078_option_b_inline_insert.py (added `__enter__`/`__exit__` to `_FakePooledDB`), test_aud0078_bg_refresh.py (same shape), test_amend_order_noop_rejection.py + test_amend_order_single_bybit_client.py + test_amend_order_aud0080_ticker_validation.py (12 monkeypatches updated, `_make_pooled_db` helper now returns CM-wrapping MagicMock), test_open_orders_aud0084_aud0102_error_sanitization.py (3 monkeypatches), test_aud0081_applock_mutations.py (sentinel string check changed). Committed as `10faa907`. Fence test extended to 20 entries.

7. **Migrated B-6** per design D.5 split: ai_snapshot.py (4 sites) → get_db_connection because only api/ai_feedback.py uses it (FastAPI-only); push_sender.py (4 sites) and pushover_sender.py (2 sites) → `PostgresDB` because mixed FastAPI + daemon callers (alert_engine.py, cancel_orphaned_orders.py) don't init the global pool; idea_creator_base.py (1 site) → `PostgresDB` because telegram_signals.py and the Discord parser are daemons. Updated 2 source-shape regression tests in test_aud0245_0250_0253_0256_0260_signal_ingest.py to assert PostgresDB instead of PooledDB. Stale comments cleaned in vwap.py (8 × 3-line `AUD-0267: PooledDB's fallback path...` blocks) and batch_ideas.py (2 PooledDB mentions); idea_creator_base.py docstring updated. Committed as `85437c29`. Fence test extended to 21 entries.

8. **B-7: deleted PooledDB class** (76 LOC) from `lib/tradelens/core/pg_pool.py`. Updated module docstring to drop the PooledDB line and add a pointer to `pg_db.PostgresDB` for standalone callers. Dropped `PooledDB` from imports of `tests/unit/test_pg_pool.py` and deleted `test_pooled_db_close_logs_putconn_failure` (1 test for the now-dead class). Renamed `test_aud0030_db_pool_shim_deleted.py::test_pg_pool_still_exports_pooled_db_and_helpers` → `test_pg_pool_still_exports_helpers`; surviving helpers list no longer includes PooledDB; added a `not hasattr(_pgp, 'PooledDB')` assertion. Removed `pg_pool.py::PooledDB.connect` entry from `test_pool_getconn_autocommit_invariant.py` ALLOWLIST. Final gate: 2989 passed, 4 skipped. Committed as `c4cffeb3`. AUDIT_TRACKER row for AUD-0008 flipped to `Resolved`.

9. **Closed task** `20260430-115500-aud-0008-b2-pooled-db` via `/t-done` — terminal commit `c4cffeb3`. Context written to `~/.claude/tasks/context/20260430-115500-aud-0008-b2-pooled-db.md`.

10. **Saved memory** `feedback_no_cosmetic_git_rewrites.md` and indexed in `MEMORY.md` after the user's correction (11:23 UTC). Plan file at `/app/syb/.claude/plans/re-outstanding-hygiene-issue-hidden-crane.md` documents the same lesson from the planning angle.

11. **Verified rocky-8gb api state pre-flip**: api PID at start was 2731641 (started 13:25:05 UTC during this session), zero `TRADELENS_BYBIT_*` env vars set, `/api/v1/health` returning ok. This addressed the user's challenge to my stale "10:35 UTC" claim.

12. **Edited `/app/syb/.tradelens.secrets` on rocky-8gb** to append an AUD-0002 comment block + `export TRADELENS_BYBIT_RETRY_ENABLED='true'` (commented PARKED line for the breaker flag). File permissions 600 preserved.

13. **`tl restart api` on rocky-8gb** at 13:46:27 UTC. New PID 2769091. Env-flag verified in `/proc/2769091/environ`. Health endpoint returned ok. No startup errors in api.log.

14. **SSH'd to rocky2 and added the same export** to its `/app/syb/.tradelens.secrets`, then `tl restart mdsync_pg` at 13:47:42 UTC. New PID 360723. Env-flag verified.

15. **Ran `sudo resize2fs /dev/sdb`** at ~11:51 UTC. ext4 grew online from 148G → 295G. PostgreSQL ran throughout (`/api/v1/health` continued to return ok, postgres process count unchanged). Block count: 39,321,600 → 78,643,200 (4KB blocks, doubled).

16. **Sweep #1 of retry logs** at 11:55 UTC: 0 retry events on both hosts, 0 errors on rocky-8gb api. rocky2 had pre-existing "Symbol Is Invalid" errors that pre-dated the flip — application-level errors that bypass retry by design.

17. **Sweep #2 of retry logs** at ~14:21 UTC: 0 retry events on both hosts. rocky2 had logged 37 "Too many visits. Exceeded the API Rate Limit." errors in 2.5h clustered at minute boundaries.

18. **Discovered mdsync.fetcher scope gap**: `lib/tradelens/mdsync/fetcher.py:16` imports `httpx`, line 73 has the comment *"IP is shared with ~50 other Bybit clients via bybit_client.py with no coordination"*, line 190 instantiates `httpx.Client`, line 263 does `self.client.get(url, params=params)`. mdsync.fetcher does NOT route through `bybit_client._request`, so the AUD-0002 retry/throttle/breaker code never engages on rocky2. mdsync_service.py's only tradelens import is `from tradelens.core.logging import get_logger`. None of my B-2..B-7 commits touched any mdsync file.

19. **Rolled back rocky2 retry flag**: SSH'd to rocky2, used sed to delete lines 136-152 of `/app/syb/.tradelens.secrets` (the AUD-0002 block I'd added), appended a replacement comment block explaining why mdsync_pg doesn't get the flag. `tl restart mdsync_pg`. New PID 373262/373266. Env-flag count = 0.

20. **Started task `20260430-163139-aud-0002-mdsync-scope-note`** (16:31 UTC) and edited the AUD-0002 row in `tradelens/AUDIT_TRACKER.md` to append a "Scope note (2026-04-30, post-flip soak)" paragraph explaining the bypass and listing follow-up options (route mdsync through bybit_client OR port retry into fetcher.py). Committed as `775124e3`. Closed task. Context written to `~/.claude/tasks/context/20260430-163139-aud-0002-mdsync-scope-note.md`.

21. **Two `/t-done` invocations afterward** found no new uncommitted work and showed task history.

22. **Multiple `/history` skill invocations** testing argument variants. No code changes from these.

23. **One `/sessionid` skill invocation** (after the `/sessionid` command became available mid-session via a system-reminder). Output: this session's UUID `def3f248-ba94-452a-872b-b46e229bc0f4`.

## Decisions made (and why)

1. **Decision:** Continue with B-2..B-7 grinding in this session (option 1 of three the previous checkpoint had laid out).
   **Proposed by:** User explicitly: *"option 1 — continue grinding"*.
   **Rationale:** User's call. The previous checkpoint had estimated 15-20 hours of manual per-file work for the full B-2..B-7 remainder; this session ended up shipping all of it in one sitting using a more robust migration script.
   **Alternatives considered:** Option 2 (schedule autonomous agent across multiple days), option 3 (stop and resume manually later). Both rejected by the user's explicit pick.
   **Revisit if:** N/A — already executed.

2. **Decision:** Do NOT propose a `git rebase -i` or `git reset --soft` to fix the parallel-session commit `0992a6f0`'s misleading message.
   **Proposed by:** User: *"if there's no corruption then I don't care … it's not a problem if both are committed in the same commit"*.
   **Rationale:** Code is correct, only the commit message under-describes the diff. User does not value git-log aesthetics absent corruption. History rewrites carry collision risk against parallel sessions.
   **Alternatives considered:** (a) `rebase -i 0992a6f0~1` with `reword` to expand the message — rejected per user; (b) `rebase -i ... edit` to split the commit into two — same; (c) follow-up note in AUDIT_TRACKER pointing at 0992a6f0 — rejected as unnecessary; (d) `git notes` — rejected (most tooling ignores notes); (e) leave it — chosen.
   **Revisit if:** Never. Memory rule saved at `feedback_no_cosmetic_git_rewrites.md`.
   **Affects:** Future sessions inspecting `git log --grep=AUD-0008` will not find the B-3 commit by message; the AUDIT_TRACKER body explicitly names the B-3 file list which serves as the canonical reference.

3. **Decision:** Flip `TRADELENS_BYBIT_RETRY_ENABLED='true'` on rocky-8gb api now (2026-04-30); park `TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED` for ~Day 7-14.
   **Proposed by:** Claude (per AUD-0002 design A.5 risk #3); User confirmed by saying *"flip TRADELENS_BYBIT_RETRY_ENABLED=true and run the relevant steps"*.
   **Rationale:** Design A.4 says the breaker has the highest risk class (mistuning causes cascade failures) and should ship dark for 1-2 weeks while retry-rate logs are observed. Retry alone is lower risk (additive on transient failures, doesn't open-circuit traffic).
   **Alternatives considered:** Flip both at once (rejected per design); flip retry on a single instance first as a canary (rejected — mdsync would still benefit from retry on minute-boundary 429s, so deploy to both hosts together... which turned out to be wrong — see Decision 5 below).
   **Revisit if:** Day 7-14 retry-rate logs show healthy distribution (low rate, dominated by 429/transient causes, no application-error contamination), then flip the breaker.

4. **Decision:** Resize ext4 online via `sudo resize2fs /dev/sdb` with PostgreSQL running.
   **Proposed by:** Claude after read-only investigation; User implicitly approved by asking the question.
   **Rationale:** ext4 supports online grow with `has_journal` + active journal. /dev/sdb is the whole block device (no partition, no LVM), so no `growpart` or `pvresize` needed. The risk is zero — only block group descriptors at the new end of the FS are written; existing data is untouched.
   **Alternatives considered:** Take PG offline first (rejected — overkill for ext4 online grow); use xfs_growfs (N/A — filesystem is ext4, not XFS); resize via fdisk + growpart (N/A — no partition table).
   **Revisit if:** N/A — done. New size 295G usable, 39% full.

5. **Decision:** Roll back the rocky2 retry flag after discovering mdsync.fetcher bypasses bybit_client.
   **Proposed by:** Claude as one of three options (leave it / open follow-up audit / quick-win RPS bump); User picked option 1 *"yes roll back the rocky2 flag flip since it's a no-op there"*.
   **Rationale:** Setting the flag on rocky2 was technically harmless but misleading — it suggested AUD-0002 was protecting mdsync when in fact it wasn't. Removing the flag and replacing it with an explanatory comment block is more honest and prevents a future operator from miscalibrating their mental model.
   **Alternatives considered:** Leave the flag set as a no-op; open a new audit to route mdsync through bybit_client; quick-win RPS reduction. User chose rollback + audit-tracker scope note.
   **Revisit if:** mdsync's rate-limit hit rate becomes operationally problematic — then a new audit to either route mdsync through bybit_client or port retry into fetcher.py.
   **Affects:** rocky2's `/app/syb/.tradelens.secrets` no longer has the export; the comment block lives at lines 136-148ish in that file; mdsync_pg PID 373262 has zero `TRADELENS_BYBIT_*` env vars.

6. **Decision:** Document the mdsync.fetcher scope gap in the AUD-0002 audit-tracker row rather than as a separate audit.
   **Proposed by:** Claude.
   **Rationale:** It's not a regression or bug — it's a scope boundary that wasn't made explicit in the AUD-0002 design (which only inventoried bybit_client.py). The AUDIT_TRACKER body is the canonical place for this kind of "post-soak operational learning" and a future operator/Claude looking at AUD-0002 will see it there.
   **Alternatives considered:** Open a new AUD-XXXX row dedicated to mdsync retry coverage; leave it undocumented (since the work didn't break anything); inline it into the convergence design doc. Chose AUDIT_TRACKER row append.
   **Revisit if:** Operator decides to route mdsync through bybit_client — then the scope-note paragraph would be replaced with a "fixed in AUD-XXXX" reference.
   **Affects:** `tradelens/AUDIT_TRACKER.md` AUD-0002 row, committed as `775124e3`.

7. **Decision:** Use `PostgresDB` (not `get_db_connection`) for `idea_creator_base.py`, `push_sender.py`, `pushover_sender.py`.
   **Proposed by:** Claude per design D.5.
   **Rationale:** These services have mixed callers — some FastAPI handlers (which init the pool) and some daemons (which don't). `PostgresDB` works in both contexts because it opens a direct psycopg2 connection regardless. The cost (per-call connect/disconnect overhead) is negligible for these notification senders that fire at most a few times a minute.
   **Alternatives considered:** Use `get_db_connection` (would fail in daemons that don't init the pool); split each service into two call paths (per design D.5 alternative — rejected as over-engineering for the call volume).
   **Revisit if:** A future audit decides to enforce `get_db_connection` everywhere and migrate daemons to init the pool. Not currently planned.
   **Affects:** B-6 commit `85437c29`; the fence test does NOT include push_sender/pushover_sender/idea_creator_base because they don't go through `get_db_connection`.

## Rejected approaches (and why)

1. **Approach:** `git reset --soft HEAD~5` (or HEAD~6) to unwind the parallel-session commit `0992a6f0` and re-commit B-3 cleanly.
   **Who proposed it:** Claude initially; User explicitly rejected.
   **Why rejected:** User's verdict: *"if there's no corruption then I don't care … And why are you asking me questions about whether you can do a force push or not just do what you always do"*. Plus the arithmetic was wrong — `HEAD~5` would put HEAD at `0992a6f0` itself (preserving the bad commit), not before it. To unwind past it would need `HEAD~6`. Either way, rewrites all 5+ commits since.
   **Would we reconsider if:** Never. Memory rule saved at `feedback_no_cosmetic_git_rewrites.md`.

2. **Approach:** `git rebase -i 0992a6f0~1` with `reword` to expand the misleading commit message in place.
   **Who proposed it:** Claude as a less-invasive alternative.
   **Why rejected:** Same rationale as #1 — user does not value git-log aesthetics; rewriting 5+ commit SHAs touches parallel-session work in flight.

3. **Approach:** Add a "scope note" commit at HEAD that points at `0992a6f0` from the AUDIT_TRACKER explaining the discrepancy (no history rewrite).
   **Who proposed it:** Claude as the no-history-rewrite alternative.
   **Why rejected:** User implicitly rejected by saying it's not a problem at all. The AUDIT_TRACKER body already names B-3 as shipped, with the file list, so future grep-by-AUD-ID still finds the work via the tracker row.

4. **Approach:** `git notes add 0992a6f0 -m "..."` attaching a clarification note.
   **Who proposed it:** Claude.
   **Why rejected:** Most tooling/PR UIs ignore git notes; adds complexity for marginal benefit.

5. **Approach:** Migrate `mdsync.fetcher` to use `bybit_client` so AUD-0002 protection extends to it.
   **Who proposed it:** Claude as one of three follow-up options.
   **Why rejected:** User picked option 1 (leave it) — *"mdsync's pre-existing rate limiter is doing its job; the 37 errors/2.5h are tolerable"*. The architectural change is non-trivial (mdsync intentionally uses its own client per the AUD-0274 comment about IP-budget independence) and the operational pain isn't there yet.
   **Would we reconsider if:** mdsync's rate-limit hit rate grows by an order of magnitude OR a Bybit IP ban becomes a real risk.

6. **Approach:** Port the AUD-0002 retry/throttle/breaker logic into `mdsync/fetcher.py` directly (parallel implementation, not refactor).
   **Who proposed it:** Claude as alternative to #5.
   **Why rejected:** Same reason — user wants to leave it.

7. **Approach:** Bump rocky2's `market_data.tuning.rate_limit_rps` down from 20 → 15 to give Bybit more headroom on minute boundaries (quick win).
   **Who proposed it:** Claude as the third follow-up option.
   **Why rejected:** User picked option 1 (leave it).

8. **Approach:** Use the brittle regex-only `/tmp/migrate_pooled_db.py` from the previous session for B-2..B-5 with `--unsafe` mode.
   **Who proposed it:** Implicitly available from the previous session.
   **Why rejected:** Per the previous checkpoint's Decision 10, that script failed on 4 of 5 B-2 files due to per-file pattern variation. This session built a proper state-machine + tokenize-aware migrator instead.
   **Would we reconsider if:** Building a more robust AST-based migration tool — but that's not warranted now since AUD-0008 is closed.

## Files touched or about to touch

The B-2..B-7 file lists are exhaustively documented in the relevant commit bodies (`354d3d84`, `17cbc97b`, `10faa907`, `85437c29`, `c4cffeb3`) and in the AUDIT_TRACKER row body. Below are the files this session touched OUTSIDE those commits, plus the few files referenced by Open threads.

1. `tradelens/AUDIT_TRACKER.md` (modified, committed in `775124e3`)
   - **Status:** committed.
   - **What's there:** Master audit tracker (~628 lines).
   - **What we changed:** AUD-0008 row status → `Resolved`; body extended with B-2 through B-7 paragraphs across the AUD-0008 commits. AUD-0002 row body extended with **"Scope note (2026-04-30, post-flip soak): AUD-0002 retry/throttle/breaker only wraps `bybit_client._request`. The mdsync candle fetcher (`lib/tradelens/mdsync/fetcher.py`) opens its own `httpx.Client` and bypasses this code path…"** (full paragraph — see commit `775124e3`).
   - **Cross-refs:** Decision 6, Open thread 5.

2. `/app/syb/.tradelens.secrets` (modified on BOTH rocky-8gb and rocky2; NOT in repo, secrets file)
   - **Status:** rocky-8gb has `export TRADELENS_BYBIT_RETRY_ENABLED='true'` active; circuit-breaker line commented out. rocky2 has the AUD-0002 block REPLACED with an explanatory comment (no exports).
   - **What's there:** Operator secrets sourced by `sourceme.sh`.
   - **What we changed:** Added/edited the AUD-0002 block. On rocky-8gb the block ends at the last secrets-file entry (around line 152 system-local). On rocky2 the block is purely informational now.
   - **Cross-refs:** Decisions 3, 5; Open thread 4 (circuit breaker flip).

3. `tradelens/lib/tradelens/mdsync/fetcher.py` (read-only this session)
   - **Status:** read-only; informed Decision 5 + 6.
   - **What's there:** mdsync's standalone Bybit candle fetcher. Line 16 `import httpx`, line 73 explanatory comment about IP-budget independence, line 190 `self.client = httpx.Client(timeout=timeout)`, line 263 `response = self.client.get(url, params=params)`.
   - **What we changed:** nothing.
   - **Why it matters:** This file is THE reason rocky2 doesn't benefit from AUD-0002. Future operators/Claudes looking at AUD-0002 should land here.
   - **Cross-refs:** Decisions 5, 6; AUDIT_TRACKER scope note.

4. `tradelens/lib/tradelens/services/mdsync_service.py` (read-only this session)
   - **Status:** read-only; verified mdsync_service.py imports nothing from any AUD-0008 migrated module.
   - **What's there:** Background scheduler/coordinator for mdsync_pg. Only tradelens import is `from tradelens.core.logging import get_logger`.
   - **Why it matters:** Confirmed mdsync is fully independent of bybit_client. Reinforces Decision 5.

5. `tradelens/bin/mdsync_pg.py` (read-only this session)
   - **Status:** read-only.
   - **What's there:** Daemon entrypoint. Line 174 and 206 do `psycopg2.connect(...)` directly — the daemon doesn't init the global pool.
   - **Why it matters:** Reinforces that mdsync is independent of both AUD-0008 (PG-side) and AUD-0002 (Bybit-side).

6. `~/.claude/projects/-app-syb-tradesuite/memory/feedback_no_cosmetic_git_rewrites.md` (created this session)
   - **Status:** committed (within the global memory dir, not the repo).
   - **What's there:** Memory rule documenting the user's correction (11:23 UTC).
   - **Cross-refs:** Decision 2; Rejected approaches 1-4.

7. `~/.claude/projects/-app-syb-tradesuite/memory/MEMORY.md` (modified to index #6)
   - **Status:** committed.
   - **What's there:** Top-level index of memory rules.
   - **What we changed:** Added entry under section "Don't pitch git-history rewrites for cosmetic message issues" linking to feedback_no_cosmetic_git_rewrites.md.

8. `/app/syb/.claude/plans/re-outstanding-hygiene-issue-hidden-crane.md` (created this session)
   - **Status:** plan file (outside repo).
   - **What's there:** The Plan-mode plan I wrote to capture the "fix the misleading commit message" decision tree, before the user told me to drop it. Final state: "no action — not a real problem".
   - **Why it matters:** Future archaeologists wondering why this lesson is in memory can read this for the full reasoning chain.

9. `~/.claude/tasks/context/20260430-115500-aud-0008-b2-pooled-db.md` (created this session)
   - **Status:** task context written when the AUD-0008 task closed.
   - **What's there:** Per-commit summary table, follow-up notes, soak monitoring grep commands.

10. `~/.claude/tasks/context/20260430-163139-aud-0002-mdsync-scope-note.md` (created this session)
    - **Status:** task context written when the AUD-0002 mdsync-scope-note task closed.
    - **What's there:** Summary, evidence, follow-up options.

11. `tradelens/docs/80-claude-checkpoints/20260430-094733-140fa7f4-aud-0002-fully-shipped-4-commits-aud-000.md` (read-only this session)
    - **Status:** read-only; loaded at session start via `/t-checkpoint-load`.
    - **What's there:** The previous session's checkpoint. 478 lines.
    - **Why it matters:** Source of truth for the AUD-0002 + AUD-0008 B-1 work that preceded this session.

## Open threads

1. **Thread:** AUD-0002 retry-flag soak on rocky-8gb api.
   **State:** Active since 13:46:27 UTC 2026-04-30. Zero retry events fired in the ~1.5h I was monitoring. Expected: handful of events per day on minute boundaries with `cause=429` or `cause=503` dominated.
   **Context needed to resume:** `grep -E "bybit\.(retry|rate_limit_throttle)" /app/syb/tradesuite/tradelens/logs/api.log | tail -50` on rocky-8gb. Look at distribution of `cause=` values; count events per hour; check for any `circuit_open` events (should be 0 since the breaker flag is parked).
   **Expected resolution:** After 7-14 days of healthy distribution, flip `TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED='true'` on rocky-8gb only.

2. **Thread:** mdsync.fetcher scope gap follow-up.
   **State:** Documented in AUDIT_TRACKER but not addressed. 37 "Too many visits" errors per 2.5h on rocky2 currently tolerated by mdsync's app-level retry (next cycle re-fetches missed candles).
   **Context needed to resume:** Re-grep mdsync_pg.log for "Too many visits" rate over a longer window; if hit rate grows 10x or Bybit ban risk emerges, open a new audit.
   **Expected resolution:** Operator decision required — either route mdsync through bybit_client (architectural refactor) or port retry/throttle into fetcher.py (parallel implementation).

3. **Thread:** Filesystem resize follow-up — reserved-blocks ratio on `/dev/sdb`.
   **State:** Default 5% reserved-blocks ratio applied only to original 150G of blocks; new 150G of growth wasn't given the same reservation, so usable space appears as ~295G of 300G. User said *"that's fine"* (11:52 UTC) — no action needed.
   **Context needed to resume:** N/A.
   **Expected resolution:** Already resolved.

4. **Thread:** Circuit-breaker flag flip on rocky-8gb.
   **State:** Parked. Comment in `/app/syb/.tradelens.secrets` says `# export TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED='true'  # PARKED — flip ~Day 7-14`.
   **Context needed to resume:** After thread #1 is healthy for a week, flip this flag and `tl restart api`.

5. **Thread:** Parallel-session uncommitted work in working tree.
   **State:** Modified `bin/refresh-tick-archive`, `bin/server/refresh_tick_archive.py`, `lib/tradelens/api/services.py`; new `tests/integration/test_refresh_tick_archive_widening.py`. None of these are mine. Plus the same Obsidian symlink + breach-research markdowns from prior sessions. HEAD has also moved to `95842190` (`fix(api): Resolve postgres log path via pg_current_logfile()`) which isn't mine either.
   **Context needed to resume:** Don't touch unless explicitly asked. The parallel session may commit these themselves.

6. **Thread:** /history skill iterations.
   **State:** Multiple invocations this session refined the script (--all → --full → --expand → --expand K, plus session detection via `/tmp/claude-session-$PPID.id` instead of ppid-walking). The command-message bodies in this session's transcript embed the latest version.
   **Context needed to resume:** N/A — the skill is stable now per the user's last invocation. /history --help showed the final usage page.

## Surprises / gotchas

1. **Finding:** A parallel claude session ran `git commit` while my B-3 files were staged in the index, sweeping them into the parallel session's commit (`0992a6f0`, message `feat(breach-decision): retrain B7 — bridge breach_event into decision_log`).
   **How we discovered it:** I tried to verify B-3 work was committed, ran `git log --oneline`, and saw my staged files in `git show 0992a6f0 --stat` alongside the parallel session's content. Reflog confirmed: `HEAD@{0}: commit: feat(breach-decision)…` was made after my B-2 commit (`354d3d84`).
   **Time cost:** ~10 minutes investigating before the user clarified there was no problem.
   **Implication:** Other claude sessions running in this cwd will commit anything in the index when they `git commit`. Do not stage long-lived changes; commit immediately after staging. The B-4 onwards I made sure to `git commit` immediately after `git add`.
   **Where it's documented:** `feedback_no_cosmetic_git_rewrites.md` and AUDIT_TRACKER B-3 row note.

2. **Finding:** mdsync.fetcher does NOT use bybit_client.
   **How we discovered it:** Post-flip log inspection at 14:21 UTC. Saw 37 "Too many visits" errors on rocky2 mdsync_pg with 0 retry events, which would have been impossible if retry was engaging. Grepped fetcher.py for `import` lines: line 16 `import httpx`, no `bybit_client` import. Line 73 has the historical comment explaining why.
   **Time cost:** ~10 minutes once I noticed the impossible-no-retries-but-yes-rate-limit-errors signature.
   **Implication:** AUD-0002 protection is api-only. mdsync's rate-limit hits are tolerated at the application level.
   **Where it's documented:** AUDIT_TRACKER scope note in commit `775124e3`.

3. **Finding:** `ps -o lstart` reports system-local (CEST = UTC+2) but api logs use UTC `Z` suffix.
   **How we discovered it:** When the user challenged my "10:35 UTC" claim, I ran `ps -o lstart= -p $api_pid` and got `Thu Apr 30 13:25:05 2026`. Initially confused myself by treating it as UTC; cross-checked with `/api/v1/health` which returned `2026-04-30T11:25:...Z` and saw the +2h offset.
   **Time cost:** ~3 minutes of confusion.
   **Implication:** Always cross-check `ps lstart` against an explicit UTC source (the api's /health endpoint or `date -u`) when correlating with logs.
   **Where it's documented:** Nowhere yet — could be added to a memory rule on timestamp consistency.

4. **Finding:** The autorestart wrapper at `bin/lib/autorestart.sh` re-spawns uvicorn AND inherits env from `~/.tradelens.secrets` via `sourceme.sh`, so env-flag flips persist across crash-restarts. But signal-driven restarts (from `tl restart api` or pkill-style kills) rebuild the wrapper too, so the env at THAT moment matters.
   **How we discovered it:** When I checked api state at the second sweep, the PID had moved (2769091 → 2813497) but the env-flag was still set, because between flips the wrapper had restarted from `~/.tradelens.secrets` (which still had the flag).
   **Time cost:** ~5 minutes to trace the autorestart cycles in `api_restart.log`.
   **Implication:** When rolling back a flag, you MUST edit the secrets file AND `tl restart` — just changing the env on the running process is futile.
   **Where it's documented:** Inline in this checkpoint; could be added to a memory rule.

5. **Finding:** mdsync_service.py only imports `tradelens.core.logging`.
   **How we discovered it:** `grep -E "^(from |import )" lib/tradelens/services/mdsync_service.py` returned 5 lines; only one was a tradelens import.
   **Time cost:** 10 seconds.
   **Implication:** mdsync is genuinely independent of the rest of tradelens at the import level — it's a self-contained daemon. Future changes to api/services modules don't need to consider mdsync as a caller.
   **Where it's documented:** Nowhere — could be added to a memory rule about mdsync's independence.

6. **Finding:** ext4 reserved-blocks ratio applies only to the original blocks, not new growth.
   **How we discovered it:** `df -h /db/data01` showed 295G after `resize2fs` despite block device being 300G; `tune2fs -l /dev/sdb` showed `Reserved block count: 1682936` × 4KB = ~6.4G reserved.
   **Time cost:** None — explained immediately to the user.
   **Implication:** If we ever want to recover the ~5G reservation gap, `tune2fs -m 1 /dev/sdb` (or 0) lowers the reservation. User said "that's fine" so we didn't.

## Commands that mattered

1. **Command:** `cat /proc/$(pgrep -f 'uvicorn.*tradelens.main' | head -1)/environ | tr '\0' '\n' | grep TRADELENS_BYBIT`
   **Output (relevant portion, post-flip):**
   ```
   TRADELENS_BYBIT_RETRY_ENABLED=true
   ```
   **What we inferred:** Env-flag was successfully loaded into the new uvicorn process after `tl restart api`.

2. **Command:** `sudo resize2fs /dev/sdb`
   **Output:**
   ```
   resize2fs 1.45.6 (20-Mar-2020)
   Filesystem at /dev/sdb is mounted on /db/data01; on-line resizing required
   old_desc_blocks = 19, new_desc_blocks = 38
   The filesystem on /dev/sdb is now 78643200 (4k) blocks long.
   ```
   **What we inferred:** Online resize succeeded, block count exactly doubled (39,321,600 → 78,643,200), no journal corruption.

3. **Command:** `awk '$1 >= "2026-04-30T11:47:42Z"' /app/syb/tradesuite/tradelens/logs/mdsync_pg.log | grep "Too many visits" | awk '{print substr($1,1,16)}' | uniq -c | tail -10` (run via SSH on rocky2)
   **Output:**
   ```
         5 2026-04-30T12:00
         1 2026-04-30T12:15
         2 2026-04-30T12:30
         8 2026-04-30T13:00
         5 2026-04-30T13:30
         2 2026-04-30T13:45
        14 2026-04-30T14:00
   ```
   **What we inferred:** Rate-limit errors cluster at minute boundaries (Bybit's per-minute quota windows). 14 hits in the 14:00 boundary alone. Drove Decision 5 + 6.

4. **Command:** `grep -E "^(from |import )" lib/tradelens/services/mdsync_service.py`
   **Output:**
   ```
   import gc
   import os
   import threading
   from typing import Dict, Any, Optional
   from tradelens.core.logging import get_logger
   ```
   **What we inferred:** mdsync_service has no dependency on api/* or services/* modules I migrated. Reinforces independence.

5. **Command:** `for sha in 354d3d84 0992a6f0 17cbc97b 10faa907 85437c29 c4cffeb3; do git show --stat $sha | grep -i mdsync || echo "(no mdsync files)"; done`
   **Output:** All 6 returned `(no mdsync files)`.
   **What we inferred:** None of my AUD-0008 commits touched mdsync. Combined with the import audit, confirms mdsync needs no pull or restart for AUD-0008 work.

6. **Command:** `/app/syb/tradesuite/scripts/check-tests.sh` (full test gate)
   **Output:** `2989 passed, 4 skipped, 25 warnings in 127.36s`
   **What we inferred:** All B-2..B-7 work plus the 30+ test rewrites pass. Was 2861 at session start; net +128 (mostly fence test parametrizations: 4 tests × 21 files = 84, plus the existing test rewrites).

## Schema / API / data facts worth preserving

- **Bybit's "Too many visits. Exceeded the API Rate Limit." error returns HTTP 200 with retCode != 0** (typically retCode 10006 or similar), not HTTP 429. This is significant because the AUD-0002 retry path explicitly excludes retCode != 0 from triggering retries (per design A.5). So mdsync's rate-limit hits would NOT be retried by AUD-0002 even if it were on the bybit_client path.
- **mdsync.fetcher's RPS limit** is sourced from `etc/config.yml::market_data.tuning.rate_limit_rps` with default 5 RPS. rocky2's local config override sets it to 20 RPS (per `project_rocky2_mdsync_host.md` memory). rocky-8gb keeps it at 5 because its IP is shared with ~50 other Bybit clients.
- **`/dev/sdb`** is a single ext4 filesystem mounted at `/db/data01`, NO partition table, NO LVM. Hetzner's volume resize grew the block device transparently; only the ext4 layer needed `resize2fs`.
- **PostgreSQL on rocky-8gb** has its data dir at `/db/data01/pgdata`, identifiable via `lsof +D /db/data01` showing `postgres … cwd DIR 8,16 4096 2097153 /db/data01/pgdata`.
- **api log timestamps** use UTC `Z` suffix (e.g., `2026-04-30T11:46:39.538518+00:00Z`), but `ps -o lstart` and `tl restart` log lines in `api_restart.log` use system-local time (CEST = UTC+2 currently). The 2-hour offset has bitten me once this session.

## Next steps

1. **No immediate action.** Both tasks (`20260430-115500-aud-0008-b2-pooled-db` and `20260430-163139-aud-0002-mdsync-scope-note`) are closed. Working tree is clean of my work.

2. **(Independent of any user prompt)** AUD-0002 retry-flag soak on rocky-8gb api. Periodically run:
   ```bash
   grep -E 'bybit\.(retry|rate_limit_throttle|circuit_open)' /app/syb/tradesuite/tradelens/logs/api.log | wc -l
   grep 'bybit.retry' /app/syb/tradesuite/tradelens/logs/api.log | grep -oE 'cause=[a-zA-Z0-9_]+' | sort | uniq -c
   ```
   Expect low rate, dominated by 429/transient causes.

3. **(After ~Day 7-14 if soak is healthy)** Flip `TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED='true'` on rocky-8gb only:
   ```bash
   sed -i 's|^# export TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED.*|export TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED='"'"'true'"'"'|' /app/syb/.tradelens.secrets
   tl restart api
   # verify in /proc/$(pgrep -f 'uvicorn.*tradelens')/environ
   ```
   Watch for `bybit.circuit_open` events — if any during normal operation (no upstream Bybit incident), the threshold is too aggressive, roll back.

4. **If/when the user asks about mdsync rate-limit issues** (Open thread #2), present the two follow-up options (route through bybit_client OR port retry into fetcher.py) and let them choose.

5. **If the user asks for a fresh task**, run `claude-task new "$(date +%Y%m%d-%H%M%S)-<slug>" "<summary>"` to start tracking and proceed normally.

## Verification checklist for the next session

- [ ] git HEAD is at `95842190` (or further along on master). Run `cd /app/syb/tradesuite && git rev-parse --short HEAD`.
- [ ] AUDIT_TRACKER row for AUD-0008 reads `Resolved` (not partial). Run `grep "^| AUD-0008 " tradelens/AUDIT_TRACKER.md | awk -F'|' '{print $5}'`.
- [ ] AUDIT_TRACKER row for AUD-0002 reads `Resolved` and includes the scope-note paragraph. Run `grep "Scope note (2026-04-30, post-flip soak)" tradelens/AUDIT_TRACKER.md | wc -l` should be `1`.
- [ ] `lib/tradelens/core/pg_pool.py` has zero `class PooledDB` definition. Run `grep -c "^class PooledDB" tradelens/lib/tradelens/core/pg_pool.py` should be `0`.
- [ ] rocky-8gb api process has `TRADELENS_BYBIT_RETRY_ENABLED=true` in env. Run:
  ```bash
  cat /proc/$(pgrep -f 'uvicorn.*tradelens.main' | head -1)/environ | tr '\0' '\n' | grep TRADELENS_BYBIT
  ```
- [ ] rocky-8gb api process has NO `TRADELENS_BYBIT_CIRCUIT_BREAKER_ENABLED` in env (still parked). Same command, expect only the retry line.
- [ ] rocky2 mdsync_pg has NO `TRADELENS_BYBIT_*` in env (rolled back). Run via SSH:
  ```bash
  ssh rocky2 'cat /proc/$(pgrep -f "python3.*mdsync_pg.py" | head -1)/environ | tr "\0" "\n" | grep TRADELENS_BYBIT'
  ```
  Expect no output.
- [ ] `/db/data01` ext4 size is ~295G usable. Run `df -h /db/data01`.
- [ ] No active claude-task. Run `claude-task current`. Expect empty output.
- [ ] Both task context files exist: `~/.claude/tasks/context/20260430-115500-aud-0008-b2-pooled-db.md` and `~/.claude/tasks/context/20260430-163139-aud-0002-mdsync-scope-note.md`.
- [ ] Memory rule `feedback_no_cosmetic_git_rewrites.md` is present and indexed. Run `ls /app/syb/.claude/projects/-app-syb-tradesuite/memory/feedback_no_cosmetic_git_rewrites.md && grep "no_cosmetic_git_rewrites" /app/syb/.claude/projects/-app-syb-tradesuite/memory/MEMORY.md`.
