# Checkpoint: planning-only session — scoped 4 deferred items (AUD-0078 sync sites, AUD-0272 broader, Bucket C, T3 queue); no code shipped this turn; awaiting user picks before any further dispatch

**Saved:** 2026-04-26 14:30:41 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ c462004a
**Session:** b5e7e9b7-4811-4d16-8906-645809c3a262
**Active task:** 20260426-aud-deferred-and-planning

## Handover Statement

You are picking up a planning-only audit session. The conversation has just produced a comprehensive 4-part scope document covering: (1) the two intentionally-synchronous call sites that AUD-0078 deferred, (2) the broader concurrency-model follow-up for AUD-0272 (the partial-Resolved item), (3) the still-Confirmed Bucket C items (money-moving / schema, 13 of 14 still open after AUD-0211 shipped earlier), and (4) the Bucket F / T3 architectural queue (26 still-Confirmed items, ~6 planning sessions worth). The plan was produced by 4 parallel read-only sub-agents and synthesised in the last assistant turn. **No code was changed this turn. No file on disk was created either** — the consolidated plan exists only in the conversation, NOT in any committed doc. The user's next decision drives whether the plan persists.

The single most important piece of state right now: **the user has NOT picked anything yet**. The closing turn ended with four explicit decisions waiting on the user (1. AUD-0039 a/b/c choice — unblocks Bucket C Tier 3; 2. AUD-0078 Option B vs C; 3. AUD-0272 sequence E→A approval; 4. confirm Tier 1 Bucket C ship order). Do NOT dispatch any sub-agent or worktree until the user answers at least one of these. Do NOT auto-commit the plan to disk; the user was asked at the end of the turn whether to persist it as `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-followup-planning.md` and they have not yet replied.

Read these in order to fully understand what's loaded: (1) **this checkpoint's "Plan deliverable" section** — has the full consolidated 4-part plan inline; (2) `docs/30-fixes-and-audits/audits/audit-autofix/decisions-pending.md` for Bucket C / F sources of truth on user-recommended options; (3) `tradelens/AUDIT_TRACKER.md` for current Status of any specific AUD ID before acting; (4) the just-shipped commits between `9530011d` (AUD-0119) and `850ff3c3` (AUD-0272) for the proven BackgroundTasks + isolated-worktree patterns the next batch will mirror.

Known landmines: (a) HEAD has moved from `850ff3c3` (where my last batch ended) to `c462004a` (current) — six parallel-session Level-B commits landed during this turn including a refactor `2ceefdc7 refactor(breach-decision): rename level_b / Layer B subsystem to breach_decision` and a fix `3d68f177 test: codebase-wide ThreadedConnectionPool .getconn() autocommit invariant`. None of those touch my domain but **always re-baseline `git rev-parse HEAD` before creating any worktree**. (b) The user has consistently rejected pausing for permission MID-batch ("Do not pause for permission between items unless a stop condition is hit") but has consistently REQUIRED permission BETWEEN batches. (c) `sourceme.sh`'s `PYTHONPATH` points at the MAIN checkout's `lib/`, so any pytest run in a worktree must override `PYTHONPATH=<worktree>/lib:.:$PYTHONPATH` or it silently exercises the wrong code. (d) FastAPI rejects `Optional[BackgroundTasks]` at module-import time — use `background_tasks: BackgroundTasks = None` (default-None preserves internal Python callers).

What NOT to do: do NOT re-investigate any of the 4 areas — the sub-agent reports are exhaustive and recent. Do NOT propose AUD-0078 Option D (defer everything including the lineage UPDATE) — it requires an FE contract change and was explicitly noted as breaking. Do NOT propose AUD-0272 Option C (asyncpg rewrite) — T3-sized, AUD-0274's module-level lock would also need to switch to asyncio.Lock. Do NOT touch Level-B / breach_decision paths (they are the parallel session's domain). Do NOT bundle unrelated AUDs into one commit. Do NOT proceed past Tier 1 Bucket C without the AUD-0039 pick.

The exact next action the user is expected to take: **answer one or more of the four pending decisions in the closing turn**. The most cost-effective single answer is the AUD-0039 (a/b/c) pick because it unblocks AUD-0231 + AUD-0282 in Bucket C with zero code cost. If the user instead says "just go with all your recommendations," dispatch in this order with single-AUD isolated worktrees: AUD-0078 Option B → AUD-0272 profile + per-thread → AUD-0271 → AUD-0088 → AUD-0121 → AUD-0158 → AUD-0244 → AUD-0222 → AUD-0217+0218 cluster → schema tier (AUD-0228 mig 080 / AUD-0229 mig 081 / AUD-0280 mig 082). If they say "schedule the T3 work first," start session 1 (AUD-0353 + AUD-0354 — security; the AUD-0353 git filter-repo is "you-only" and needs a runbook produced, NOT executed by Claude).

## Session context

### User's stated goal (verbatim where possible)

The session has a layered goal arc spanning multiple turns. The original opening was the prior `/clear` + `/t-checkpoint-load` (loaded `20260426-091109Z.md`). After that the user said `"go with AUD-0119"`, which shipped the first commit of the session.

Then the user authorized a controlled batch with hard rules (in their own words): *"Continue with the approved large batch, but apply these hard controls. Do not pause for permission between items unless a stop condition is hit."* They then enumerated 10 hard controls covering worktree isolation, single-AUD commits, AUDIT_TRACKER one-row-per-commit, no-staging-of-{checkpoint files, .claude, chat.txt.gz, Level-B}, full pytest every 3 cherry-picks, and explicit skip-don't-mark-Resolved on scope expansion.

Mid-batch, the user added: *"For the large audit batch, you may use sub-agents, but only with isolation controls"* — listing the worktree path convention `../tradelens-aud-XXXX` and branch convention `audit/AUD-XXXX-short-name`, plus the "one AUD or one tightly-coupled AUD pair only" rule.

After the controlled batch shipped 8/9 items (AUD-0243 was correctly skipped as scope-incompatible with option a), the user said: *"confirmation AUD-0078 tracker row says 4/6 sites shipped, 2 deferred; then do AUD-0243 option B as a focused item, and do reserves AUD-0298 + AUD-0272."* That ran a 3-item follow-on batch which all shipped clean.

Then the user said: *"start a task focussed on AUD-0078 remaining 2 deferred sites; AUD-0272 broader concurrency-model follow-up; Bucket C items needing explicit sign-off; T3 planning items."* That is the current task. The user explicitly framed it as planning, not coding ("focussed on" = scope, not ship).

The arc: maximum-throughput XL push (prior session) → controlled isolated batch (this session, 8 ships) → narrow follow-on (3 ships) → planning consolidation (this turn). The user is now in "decide what to authorise next" mode, NOT "ship more code now" mode.

### User preferences and corrections established this session

(All carried forward from prior session checkpoints + new items added this session.)

- **No autonomous mid-batch dispatch unless user said so.** Reaffirmed by every batch's opening message. The default between batches is wait-for-go.
- **Within an authorised batch, do NOT pause between items unless a stop condition fires.** The user explicitly contrasted this with mid-batch pauses being "wasteful."
- **One sub-agent per AUD item.** The cross-session staging contention from the prior XL session's parallel dispatch is now a known anti-pattern. Acceptable parallelism: read-only sub-agents in the main checkout, OR coding sub-agents in isolated worktrees (still one AUD per agent).
- **Worktree path / branch convention:** `../tradelens-aud-XXXX` for the path, `audit/AUD-XXXX-short-name` for the branch.
- **Cherry-pick into master one at a time, serial.** Targeted tests after every cherry-pick; full pytest after every 3.
- **Skip-not-Resolve on scope expansion.** When AUD-0243 option (a) BackgroundTasks turned out to be incompatible with the synchronous downstream consumers, the user wanted that flagged as "skipped — needs separate decision," not silently adapted.
- **Working tree boundaries** (still in force): do NOT touch `bin/level-b-*`, `bin/show/show_level_b_*`, `lib/tradelens/level_b/`, `bin/server/level_mind_*`, `lib/tradelens/services/level_guard.py`, `lib/tradelens/services/level_mind_core.py`, `etc/config.yml` Level-B sections, `etc/schema.md`, `migrations/077_*` / `migrations/079_*`, `swing_research/`, `swing_levels/`, or anything matching the Level-B pattern. **Note:** the parallel session has now renamed `level_b` → `breach_decision` (commit `2ceefdc7`), so that boundary now extends to `breach_decision_*` paths.
- **No `git add -A`. Use explicit paths only.** This rule is enforced in every sub-agent prompt I write.
- **Test gate is strict.** `scripts/check-tests.sh` runs full pytest. Exemption categories must be stated: `docs-only`, `config-only`, `typo-fix`, `dead-code-removal`, `revert`, `frontend-styling`, `generated-file`. Use `# tests: exempt — <category>` in the commit body.
- **No staging of `.claude/`, `docs/chat.txt.gz`, lingering `docs/80-claude-checkpoints/...md` files, the `docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` symlink, or any untracked Level-B / breach-decision file.** This rule has held across all 12 ships of the session.
- **Always use `tl restart <service>`, never manual kill/scripts** (memory-stored from earlier sessions, reaffirmed during the service-restart sequence at the end of the controlled batch). Exception: orphan processes that `tl` no longer knows about (after a service rename) — those need direct `kill` since `tl` can't reach them. We did this for PIDs 831120 + 831194 after the parallel session renamed level-b-* → breach-decision-*.

### Working environment

- **HEAD:** `c462004a fix(trade-lineage): propagate lineage_id so all legs of one trade share an anchor` — committed by the parallel session AFTER my follow-on batch closed. HEAD has moved 6 commits during this planning turn.
- **Pytest:** last verified at `850ff3c3` end-of-batch was 1381 passed, 4 skipped, 0 failures. Has not been re-run at `c462004a`. The 6 parallel-session commits since then include test additions (`3d68f177 test: codebase-wide ThreadedConnectionPool .getconn() autocommit invariant`) so the count has likely increased.
- **Active claude-task:** `20260426-aud-deferred-and-planning` summary "Scope deferred items: AUD-0078 sync sites, AUD-0272 broader, Bucket C, T3 planning". Started this turn. Has produced no commit yet (planning only).
- **Services:** all 15 RUNNING after the deep health check earlier in the session. PIDs current at end of restart: dashboard 914095, api 914017, pipeline 913418, mdsync_pg 914257, alert-engine 913508, vwap-engine 913560, vwap-series 913608, level-guard 913656, level-mind 913711, breach-decision-label-backfill 913777, breach-decision-outcome-backfill 913843, correlation-engine 913881, telegram-signals 914322, monitor 914407, postgresql 1003. These PIDs may have been restarted since by the parallel session's `c462004a` work — re-verify with `./bin/tl status` before any service-related action.
- **Git status (verbatim, this turn):**
  ```
  ?? ../.claude/agents/
  ?? ../.claude/checkpoints/
  ?? .claude/
  ?? .codex
  ?? docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md
  ?? docs/80-claude-checkpoints/20260426-091109-a9025389-idle-post-t-done-aud-0375-shipped-reconc.md
  ```
  All untracked, none mine, all pre-existing or system. The `.codex` entry is new this session but not from my work.
- **No worktrees currently open.** All 9 worktrees from the controlled batch + 3 from the follow-on batch were created and removed cleanly.
- **No background processes from me.** All sub-agents this turn were synchronous read-only.
- **Disk concern from health check:** `/dev/sda1` was at 90% (7.8 GB free of 75 GB). I offered to delete `pipeline_daemon.log.1` (873 MB) + `level_guard_daemon.log.1` (160 MB) to reclaim ~1 GB but the user did not respond. **Still pending.** Likely safe to delete since they are rotated archives.
- **vwap-series-worker** was climbing in RSS during the health check (2.2 GB → 3.7 GB at 86.7% CPU). Was not re-checked. Worth a glance at `tl monitor report` if it bites.

## Objective

The user asked for a focused task to scope four areas of remaining work. The task is **planning, not implementation**: produce options, blast radius, prerequisites, and a recommended next-action sequence for each area, so the user can authorise the next batch with full context. No code changes were expected in this turn. The deliverable is the consolidated 4-part plan that closed the turn.

In scope this turn: investigate via read-only sub-agents the current state of each of the four areas; produce per-area option matrices with risk/effort/blast-radius/dependencies; recommend a ship-next per area; surface the user-decisions-needed (sign-off prompts) so they can be answered in one go; identify cross-cutting dependencies (especially Bucket C ↔ T3 ↔ already-shipped patterns).

Out of scope this turn: any code change; any worktree creation; any commit; touching the AUDIT_TRACKER beyond reading it. The next turn (post-checkpoint) will likely move into either coding-batch dispatch or T3 session 1 prep, depending on which decision(s) the user answers.

## Narrative: how we got here

The session started with `/t-checkpoint-load` of `20260426-091109Z.md` after a `/clear`. That checkpoint described the prior session's XL audit-autofix push, the AUD-0375 ship, and the recommendation to ship AUD-0119 next. The user said "go with AUD-0119," I produced an Option A vs Option B proposal, the user picked Option B with detailed constraints, and the first commit of this session shipped as `9530011d`.

The user then said "Continue with the approved large batch, but apply these hard controls" with the 10-rule list. I produced a slate of 9 items in two batches (Batch 1: AUD-0357, 0101+0103, 0106, 0274, 0266; Batch 2: 0254, 0094, 0078, 0243). The user said "go." The controlled batch dispatched serially, one isolated worktree per AUD, with cherry-pick + targeted-test + full-pytest-every-3 cadence. 8 of 9 items shipped clean. AUD-0243 hit a real stop condition — option (a) BackgroundTasks would race with `discord/parser.py:148-160` (GPT vision routing) and `discord/idea_creator.py:661-670` (snapshot DB writes) which both consume the downloaded local file path SYNCHRONOUSLY in the same request. The sub-agent stopped without committing; I marked it skipped, ran a final pytest gate (1329 passed), produced the batch report, the user invoked `/t-done`, that task closed at commit `768c0dc2`.

The user's next message confirmed the AUD-0078 tracker text ("4/6 sites shipped, 2 deferred") and asked me to ship AUD-0243 option B (thread-pool parallelism — the second option the audit row had offered, never proposed by Claude as default), plus reserves AUD-0298 and AUD-0272. I started a new task `20260426-aud-followup-243-298-272`. AUD-0243 option B shipped as `c4403cc7` — `concurrent.futures.ThreadPoolExecutor` over per-message attachments, `min(10, len(image_atts))` workers, `executor.map` for clean attachment-dict identity. AUD-0298 shipped as `03082183` — added `BybitClient.get_tickers(category)` method, threaded into `alert_engine._poll_cycle` mirroring the AUD-0299 `conn=None` parameter pattern. AUD-0272 shipped as `850ff3c3` with status `Resolved (partial)` — sub-agent discovered most of the literal→config move had ALREADY shipped under AUD-0283 (commit `8f7abdfa`), so the actual remaining contribution was operator-typo validation (positive-int + bool-rejection + fall-back-to-default with warning log). The broader "batch upsert OR per-thread connections" recommendation is explicitly NOT addressed by that commit and is flagged as future work.

The user invoked `/t-done` and the follow-on task closed.

After that, the user asked me to restart and health-check all services. They originally referenced PIDs 831120 + 831194 by their old (pre-rename) names `level-b-label-backfill` / `level-b-outcome-backfill`, but `tl` only knows them as `breach-decision-label-backfill` / `breach-decision-outcome-backfill` after the parallel session's rename in commit `2ceefdc7` (which landed AFTER my checkpoint and during this session). `tl restart` reported "is not running" because the renamed services were considered fresh, but `pgrep -af "level.b.*backfill"` confirmed the OLD processes were still alive as orphans (PPID=1, ~2h23m elapsed). I sent SIGTERM to PIDs 831120 + 831194 (the autorestart wrappers); their children (831124 + 831198) propagated cleanly; all 4 orphan PIDs were gone after a single signal. `tl restart all` then brought all 13 daemons up clean (postgresql had stayed hot). Health check showed 0 errors since restart, API/dashboard/PG all reachable, all daemons emitting recent activity post-restart. Yellow flags: 90% disk usage (7.8 GB free), `vwap-series-worker` climbing memory, `monitor` daemon's process pattern doesn't match `mdsync_pg` (cosmetic), `pipeline_daemon.log.1` is 873 MB unrotated.

Then the user said "start a task focussed on" the four areas. I started the current task and dispatched 4 parallel read-only sub-agents (AUD-0078 deferred sites; AUD-0272 broader concurrency; Bucket C inventory; T3 inventory). All 4 reported back. I synthesised into the consolidated plan that closed the previous turn.

The closing turn ended with 4 explicit decisions outstanding:
1. AUD-0039 (a/b/c) pick — unblocks Bucket C Tier 3.
2. AUD-0078 Option B vs Option C.
3. AUD-0272 Profile (E) → Per-thread (A) sequence approval.
4. Tier 1 Bucket C ship order confirmation.

## Plan deliverable (the 4-part synthesis from sub-agents)

### Part 1 — AUD-0078 deferred sites

**Where they are at HEAD:**
- `lib/tradelens/api/open_orders.py:3003-3022` (`convert_to_limit`) — followed by `UPDATE order_leg_live SET lineage_id, leg_type WHERE exchange_order_id = new`. The lineage UPDATE requires the row inserted by the subprocess refresh. Has explicit `# AUD-0078: this call site is INTENTIONALLY synchronous` comment.
- `lib/tradelens/api/open_orders.py:4288-4310` (`create_order`) — followed by `SELECT id FROM order_leg_live WHERE exchange_order_id = new`, then leg_type UPDATE + VWAP linkage chain. Same pattern.

**Options analysis:**
- **A. Status quo:** keep sync, accept 15s worst-case. Risk: low. Effort: 0h.
- **B. Inline INSERT + BG full refresh:** insert minimal row from Bybit response payload immediately after `bybit.create_order()`, then run lineage UPDATE synchronously, then `background_tasks.add_task(refresh_order_data, ...)` for full state catchup. Risk: medium. Effort: 3-5h. Duplicates classification logic.
- **C. Make `refresh_order_leg_live.py` importable:** extract `OrderClassifier` + `upsert_legs_to_db` to `lib/tradelens/services/order_leg_refresh.py`; in-process call from handler; subprocess kept for cron use. Risk: med-high. Effort: 8-12h. Eliminates duplication, eliminates subprocess overhead. Larger refactor.
- **D. Defer everything (incl lineage UPDATE):** chains everything into BG tasks, response returns "pending" leg_id. Requires FE contract change. **Rejected.**
- **E. Postgres trigger + LISTEN/NOTIFY:** auto-populate via trigger. Schema change, race-safe is hard. **Rejected.**

**Recommend Option B as ship-next** (lowest blast, no schema, no FE; the duplication is bounded — only 2 sites). If duplication maintenance becomes painful, plan Option C as a follow-up T3-flavored refactor.

**Latent test gap:** `tests/integration/test_aud0078_bg_refresh.py` only validates SOURCE-TEXT shape (regex scan for `# AUD-0078: this call site is INTENTIONALLY synchronous`), NOT runtime behaviour. Option B's commit should add unit tests that mock `bybit.create_order()` + `refresh_order_data()` and assert the lineage UPDATE happens before the response.

### Part 2 — AUD-0272 broader concurrency

**Current state:**
- 10 fetch worker threads (config-driven from AUD-0272 partial ship + AUD-0283).
- ONE PG connection for upserts — funneled through `self._store` in `runner.py:151`.
- `lib/tradelens/candle_pg/store_pg.py:89-205` does per-candle UPDATE/INSERT in a loop, no batching, no `executemany`, no `COPY`.
- `etc/config.yml`: `database.pool_max: 10`.
- AUD-0274 shared rate limiter: module-level `threading.Lock`, lives in `fetcher.py` post-AUD-0274 ship.

**Estimated bottleneck:** at 10 workers, fetch ~2s wall, upsert ~0.5s. Fetch is rate-limit-bound (~5 RPS); upsert is I/O-bound on single conn. They don't scale together. At 50 workers, upsert dominates.

**Options:**
- **A. Per-thread connections** (recommend): each worker acquires from pool. Bump `pool_max: 10 → 20`. Risk: medium. Effort: 2-3d. AUD-0274 unaffected.
- **B. Batch queue + COPY/multi-row INSERT:** workers feed shared queue; flusher drains in batches. Risk: low. Effort: 3-4d. Adds queue semantics.
- **C. Async PG (asyncpg):** T3-sized rewrite. Risk: high. Effort: 2-3w. AUD-0274's lock would need switching to asyncio.Lock. **Rejected as too large.**
- **D. Hybrid (A + B):** per-deployment knob. Effort: 4-5d. Coordination complexity.
- **E. Profile first** (recommend): validate upsert IS the bottleneck before structural changes. Risk: low. Effort: 0.5d.

**Recommend E → A.** Profile to confirm (instrument `_update_live_candles` with timing logs), then per-thread connections + pool bump.

**AUD-0271 cross-cut:** AUD-0271 (Bucket C — candle ingest `ON CONFLICT` rewrite, money-adjacent) overlaps with this. If AUD-0271 ships first it'll likely add the batch upsert primitives Option B would need. Sequence them.

### Part 3 — Bucket C (13 still Confirmed)

AUD-0211 is already Resolved (shipped 2026-04-25 in batch 1). The remaining 13:

**Tier 1 — No schema, no FE:**
| AUD | What | Files |
|---|---|---|
| 0271 | Candle-ingest `ON CONFLICT DO UPDATE` batch | candle_pg/store_pg.py |
| 0088 | Drop float `round(..., 10)` final in pricing | open_orders.py |
| 0121 | SL-move-inside-lock | trades.py |
| 0158 | Unify two fees-to-USD helpers | refresh_trade_journal.py |
| 0244 | Single `BEGIN..COMMIT` around Discord idea-create cascade | discord/idea_creator.py |
| 0222 | Subprocess refresh in suspend → in-process | suspend.py (~lines 969, 1788) |

**Tier 2 — Schema migrations:**
| AUD | Migration | What |
|---|---|---|
| 0228 | 080 | Add explicit `idea_id` FK on idea→intent→journal linkage |
| 0229 | 081 | State enum column on suspend |
| 0280 | 082 | `vwap_config.slots_json` opaque blob → typed columns |

All migrations must be idempotent per AUD-0357 forward-only-policy (committed `a8541535` this session).

**Tier 3 — Blocked on AUD-0039 pick (Bucket B architectural):**
- AUD-0231 — orderLinkId on resume recreate
- AUD-0282 — orderLinkId on `vwap_order_engine.amend_order`

**Tier 4 — Cluster:** AUD-0217 + AUD-0218 already approved as Bucket E.

**Recommended ship order:** `0271 → 0088 → 0121 → 0158 → 0244 → 0222 → 0217+0218 → 0228 (mig 080) → 0229 (mig 081) → 0280 (mig 082) → 0231+0282 (after AUD-0039)`.

**Sign-off prompts pending user answer:**
1. AUD-0088 — confirm "drop the final `round(..., 10)`"? (CLAUDE.md Decimal policy says yes.)
2. AUD-0121 — confirm SL-inside-lock + hedge-mode integration test required?
3. AUD-0158 — golden-file test against ~20 known prod trades?
4. AUD-0222 — `BackgroundTasks` (mirror AUD-0119) or threading?
5. AUD-0244 — `BEGIN..COMMIT` per Discord message or per batch?
6. AUD-0228 + 0229 — backfill strategy: timestamp+symbol+side fuzzy join, or one-time manual reconciliation?
7. **AUD-0039 — UNBLOCKS TIER 3.** Pick (a) auto-generate at adapter boundary, (b) caller-supplied, or (c) keep optional + helper. Recommended: (a).

### Part 4 — Bucket F / T3 (26 still Confirmed)

**6-session plan over ~6 weeks:**

1. **AUD-0353 + 0354** — Bybit key rotation + filter-repo + secret hygiene. Critical/Security. AUD-0353 is "you-only" (destructive git ops); Claude prepares the runbook only.
2. **AUD-0361** — CI/CD + pre-commit. Foundation; gates every subsequent ship.
3. **AUD-0332** — vitest bootstrap. Unblocks ~30 frontend T2/T3 items.
4. **AUD-0002 + 0008** — retry policy/orderLinkId + DB lifecycle convergence. AUD-0002 unblocks Bucket C Tier 3 (0039/0082/0231/0282).
5. **AUD-0114 + 0115** — trades.py architecture. Money-moving path cleanup.
6. **AUD-0155 + 0170 + 0171** — pipeline state machine + classifier decomp + writer/reader split. Largest chunk.

**Quick-wins (single-AUD ship, not full sessions):**
- AUD-0325 — `gcTime: Infinity` literal one-line frontend fix (`frontend/web/src/main.tsx`)
- AUD-0058 phase-1 — split `initial_risk_calculator.py` AFTER vitest lands; file is recently refactored with good test coverage
- AUD-0169 phase-1 — additive unit tests for `sessionize_legs` and pipeline mocks
- AUD-0202 — docs-only latency-budget write-up

**Stay parked:**
- AUD-0240 (Discord self-botting — product decision)
- AUD-0259 (already Resolved, dup of 0240)
- AUD-0260 (defer until AUD-0354 secret-hygiene design lands)
- Tail items: 0224, 0277, 0312-0321, 0345-0349, 0352, 0360

**T3 ↔ Bucket C dependencies:**
- AUD-0002 hard-prereqs Bucket C 0039 / 0082 / 0231 / 0282.
- AUD-0008 supports AUD-0114/0115 (trades.py rework).
- AUD-0361 gates everything regardless of bucket.

## Decisions made (and why)

1. **Decision:** Use 4 parallel read-only sub-agents (1 per area) to produce the plan.
   **Proposed by:** Claude.
   **Rationale:** The 4 areas are non-overlapping in code (open_orders.py vs runner.py vs many-Bucket-C-files vs T3-tracker-rows). Read-only sub-agents are explicitly authorised by the user's earlier rule ("Read-only sub-agents may run in the main working tree"). Parallelism cuts wall-time ~4× and protects the orchestrator's context window from the 4 separate investigation reads.
   **Alternatives considered:** Serial sub-agents (rejected — 4× the wall time); orchestrator does it directly (rejected — would consume orchestrator context with 4 separate large reads).
   **Revisit if:** future planning task touches overlapping files where parallel reads could conflict.
   **Affects:** the entire plan deliverable; the synthesis quality depends on the 4 sub-agent reports.

2. **Decision:** Synthesise inline as the closing turn's response; do NOT auto-write the plan to disk.
   **Proposed by:** Claude.
   **Rationale:** The user asked to "start a task focussed on" — that scopes the work but doesn't authorise a doc commit. The plan is a decision-driver, not a deliverable artifact (yet). Asked the user at end of turn whether to persist. Avoids creating uncommitted dirty state in `docs/...` that would need to be cleaned up if the user redirects.
   **Alternatives considered:** Auto-write to `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-followup-planning.md` and stage (rejected — unauthorised file creation); produce only an inline response, no offer to persist (rejected — the plan IS valuable enough to survive session boundaries if the user wants).
   **Revisit if:** user says "yes save it" or "no don't bother."
   **Affects:** the plan currently exists ONLY in this conversation + this checkpoint. If `/clear` happens before the user authorises a doc, this checkpoint's "Plan deliverable" section is the sole record.

3. **Decision (carried forward):** Default to ≤1 coding sub-agent per AUD item; isolated worktree per item.
   **Proposed by:** user (consistent rule across all 3 batches this session).
   **Rationale:** parallel coding sub-agents in the same working tree caused staging-area races in the prior XL session. Isolated worktrees + serial cherry-pick eliminates the race completely.
   **Alternatives considered:** parallel coding sub-agents with worktree isolation (allowed but not used so far this session); serial single-checkout dispatch (allowed but worktree pattern preferred).
   **Revisit if:** user explicitly authorises parallel coding with worktree isolation for a specific multi-AUD batch.

4. **Decision (carried forward):** AUD-0078 deferred 2 of 6 sites with explicit comments.
   **Proposed by:** Claude (in AUD-0078 sub-agent during the controlled batch).
   **Rationale:** the response payload at those sites depends on the row being inserted; deferring would race the subsequent UPDATE/SELECT.
   **Alternatives considered:** force all 6 to BG (rejected — would break the response contract); skip AUD-0078 entirely (rejected — 4 of 6 are safe, partial ship is a clear win).
   **Revisit if:** Option B or C lands (this session's plan) — both eliminate the deferral.
   **Affects:** the AUD-0078 followup plan above.

5. **Decision (carried forward):** AUD-0272 shipped as `Resolved (partial)`, NOT full Resolved.
   **Proposed by:** sub-agent during the follow-on batch.
   **Rationale:** the audit row had two halves (config extraction + concurrency-model rewrite); only the first half landed. Marking full Resolved would understate the remaining work.
   **Alternatives considered:** mark Resolved and silently leave the broader fix for a future audit row (rejected — would lose the load-bearing context); open a NEW audit row for the broader fix (rejected — current row already documents both halves; cleaner to keep them together).
   **Revisit if:** the broader option (E→A from this turn's plan) ships.

6. **Decision:** AUD-0039 (a) is the recommended pick that the user should confirm.
   **Proposed by:** Claude (synthesised from sub-agent reports + decisions-pending.md's `(a) Auto-generate {trade_id}-{leg_kind}-{ts} at adapter boundary + require. *Recommended.*`).
   **Rationale:** option (a) is the user's own pre-recorded recommendation in decisions-pending.md, and it's the single-source-of-truth pattern that all of AUD-0082 / 0231 / 0282 can build on without further policy choice.
   **Alternatives considered:** (b) caller-supplied (rejected — caller errors propagate everywhere); (c) keep optional + helper (rejected — doesn't enforce the invariant).
   **Revisit if:** user picks (b) or (c) for any reason — would change the implementation shape of AUD-0231 + 0282.

## Rejected approaches (and why)

1. **Approach:** AUD-0078 Option D — defer the lineage UPDATE itself to BackgroundTasks, return a "pending" leg_id in the response.
   **Who proposed it:** sub-agent (option-matrix exhaustiveness).
   **Why rejected:** requires FE contract change. The frontend would need to handle pending-state for newly-placed orders; many trade workflows depend on immediate leg_id. High blast radius for a perf optimization.
   **Would we reconsider if:** FE were rewriting the order-placement flow anyway (T3 territory).

2. **Approach:** AUD-0078 Option E — Postgres trigger that auto-populates lineage_id when the new row appears.
   **Who proposed it:** sub-agent (exhaustiveness).
   **Why rejected:** schema change; race-safe trigger logic is hard (trigger could fire on a row before refresh has set the lineage); adds a trigger layer that's harder to debug than Python code.
   **Would we reconsider if:** Postgres triggers were already established as a project pattern (they are not).

3. **Approach:** AUD-0272 Option C — async PG (asyncpg) rewrite.
   **Who proposed it:** sub-agent.
   **Why rejected:** T3-sized (2-3 weeks). AUD-0274's `threading.Lock` would also need to switch to `asyncio.Lock`. Breaking change for any sync caller of `MDSyncRunnerPG`. Effort:reward ratio is bad given Option A solves the immediate bottleneck for ~2-3 days of work.
   **Would we reconsider if:** the entire mdsync subsystem were being rewritten for cloud-native scaling (not on roadmap).

4. **Approach:** Bundle multiple Bucket C items into a single commit.
   **Who proposed it:** never explicitly proposed, but the temptation exists for the schema tier (AUD-0228 / 0229 / 0280).
   **Why rejected:** the user's hard rule is "one commit per AUD item" except for tightly-coupled pairs. The schema items are independent — no shared migration, no cross-table backfill. Each gets its own commit.
   **Would we reconsider if:** user explicitly requests bundling for a specific cluster.

5. **Approach:** Auto-write the consolidated plan to `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-followup-planning.md` without asking.
   **Who proposed it:** Claude (briefly considered).
   **Why rejected:** user has been explicit about not staging unrelated docs. The plan is decision-input, not a committed deliverable. Asking is cheaper than reverting an unwanted file.
   **Would we reconsider if:** user says "yes save it."

6. **Approach (carried forward from prior session):** parallel coding sub-agents in the same working tree.
   **Why rejected:** caused staging-area races in the XL session; recovered via revert + re-commit.
   **Would we reconsider if:** worktree isolation is used (which the current pattern does — and parallel coding sub-agents would still be allowed under that model, but the user has consistently chosen serial dispatch for clarity).

## Files touched or about to touch

1. `/app/syb/tradesuite/.claude/checkpoints/20260426-143041Z.md`
   - **Status:** edited-saved (this checkpoint).
   - **What's there:** this snapshot.
   - **Why it matters:** primary working-state record after `/clear`.
   - **Cross-refs:** Handover Statement points future readers here first.

2. `/app/syb/tradesuite/tradelens/docs/80-claude-checkpoints/<dated-archive>.md`
   - **Status:** about-to-stage (will be copied + `git add` at end of this flow).
   - **What's there:** copy of #1.
   - **Why it matters:** Obsidian-vault visibility of the checkpoint trail.

3. `/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md`
   - **Status:** read-only this turn.
   - **What's there:** 215 fully Resolved (214 Resolved + 1 Resolved-partial AUD-0272), 155 Confirmed.
   - **Why it matters:** source-of-truth before any next action.

4. `/app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/decisions-pending.md`
   - **Status:** read-only this turn.
   - **What's there:** Bucket A/B/C/D/E/F/G classification of all open audit items; user's pre-recorded recommended options.
   - **Why it matters:** sub-agents trusted this for "user-recommended option" lookups; the orchestrator should also trust it before any dispatch.

5. `/app/syb/tradesuite/tradelens/lib/tradelens/api/open_orders.py`
   - **Status:** read-only this turn (not edited since AUD-0078 ship at `c7157c2e` cherry-picked into `768c0dc2`).
   - **What's there:** the 6 BackgroundTasks-eligible call sites (4 moved to BG, 2 sync). Lines 3003 + 4288 still have `# AUD-0078: this call site is INTENTIONALLY synchronous` markers.
   - **Why it matters:** primary surface for AUD-0078 followup (Option B inline INSERT) and AUD-0094-style preview functions.
   - **Cross-refs:** AUD-0078 deferred sites plan (Part 1 above).

6. `/app/syb/tradesuite/tradelens/lib/tradelens/mdsync/runner.py`
   - **Status:** read-only this turn (last edited in `850ff3c3` AUD-0272 partial ship — added `_load_runner_tuning` validation).
   - **What's there:** `_main_loop`, `_update_live_candles` with the 10-worker fetch + serial single-conn upsert pattern. Lines 726-739 fetch loop, 741-756 upsert loop.
   - **Why it matters:** the surface for AUD-0272 broader (Option E profile + Option A per-thread).
   - **Cross-refs:** AUD-0272 broader plan (Part 2).

7. `/app/syb/tradesuite/tradelens/lib/tradelens/candle_pg/store_pg.py`
   - **Status:** read-only this turn.
   - **What's there:** `upsert_candles` at lines 89-205 with per-candle UPDATE/INSERT loop. No batching, no `executemany`, no `COPY`.
   - **Why it matters:** the actual upsert layer. Both AUD-0272 Option A (per-thread connections accept `pool` instead of `conn`) and AUD-0271 (Bucket C — `ON CONFLICT DO UPDATE` rewrite) would touch it.

8. `/app/syb/tradesuite/tradelens/etc/config.yml`
   - **Status:** read-only this turn.
   - **What's there:** `database.pool_max: 10`. Already has `market_data.tuning.{main_loop_workers, live_loop_interval_seconds}` from AUD-0283.
   - **Why it matters:** AUD-0272 Option A needs `pool_max` bumped to 20.
   - **Cross-refs:** Decision #6 in AUD-0272 plan; decisions-pending.md.

## Open threads

1. **Thread:** user has not answered any of the 4 closing decisions.
   **State:** awaiting input.
   **Context to resume:** end of last turn's output (the "What I'd ask you next" block).
   **Expected resolution:** 1-4 picks from the user.

2. **Thread:** consolidated plan exists only in conversation + this checkpoint.
   **State:** unstaged, uncommitted, no doc on disk.
   **Context to resume:** "Plan deliverable" section in this checkpoint has the full content.
   **Expected resolution:** user says "save it" → write to `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-followup-planning.md` with a docs-only commit; or user says "no" → discard.

3. **Thread:** disk at 90% (`/dev/sda1` 7.8 GB free of 75 GB).
   **State:** I offered to delete `pipeline_daemon.log.1` (873 MB) + `level_guard_daemon.log.1` (160 MB) → ~1 GB reclaim. User did not respond.
   **Context to resume:** the health check section earlier in conversation.
   **Expected resolution:** user says "yes delete them" or implements logrotate.

4. **Thread:** `vwap-series-worker` was climbing in RSS (2.2 GB → 3.7 GB) at 86.7% CPU during health check.
   **State:** not re-checked.
   **Context to resume:** `./bin/tl monitor report | grep vwap-series-worker`.
   **Expected resolution:** if RSS stabilises < 5 GB, fine. If still climbing, AUD-tier candidate.

5. **Thread:** AUD-0039 architectural pick gates all of Bucket C Tier 3 + impacts T3 session 4 (AUD-0002 dependency).
   **State:** awaiting user.
   **Context to resume:** decisions-pending.md lines ~175-178 for the (a)/(b)/(c) options.
   **Expected resolution:** user picks one of (a)/(b)/(c).

6. **Thread:** `monitor` daemon's process pattern doesn't match `mdsync_pg` (cosmetic).
   **State:** not actioned.
   **Context to resume:** `bin/monitor` (or its renamed location) — `_PYTHON_PATTERNS` registry. Possibly already addressed by AUD-0348 unification.
   **Expected resolution:** could open a small follow-up AUD if it bites operationally.

7. **Thread:** `pipeline_daemon.log.1` (873 MB) is unrotated archive from a previous session — logrotate may have stalled.
   **State:** mentioned in health check.
   **Expected resolution:** delete OR fix logrotate config.

8. **Thread:** AUD-0078 Option B if approved — needs unit tests that mock `bybit.create_order()` + `refresh_order_data()` to lock in inline-INSERT contract (existing test file is source-text-only).
   **State:** not yet authorised.
   **Expected resolution:** part of the Option B ship.

## Surprises / gotchas

1. **Finding:** `level_b` was renamed to `breach_decision` by the parallel session in commit `2ceefdc7` during this session's lifetime.
   **How discovered:** when the user asked me to restart "level-b-label-backfill" services, `tl restart level-b-label-backfill` returned `Unknown service: level-b-label-backfill`. Available services list showed `breach-decision-label-backfill` instead.
   **Time cost:** ~30s (one extra `tl` invocation).
   **Implication:** the working-tree boundaries rule extends to `breach_decision_*` paths now, not just `level_b_*`.

2. **Finding:** orphan `level-b-label-backfill` and `level-b-outcome-backfill` processes (PIDs 831120 + 831194) were still alive ~2h23m after the rename, because the rename detached them from `tl`'s tracking.
   **How discovered:** `pgrep -af "level.b.*backfill"` showed wrappers + Python children still running.
   **Time cost:** ~5s.
   **Implication:** when a service is renamed in `tl`, the OLD process is left running — operator must SIGTERM the old wrapper PID directly (children propagate). Worth noting in CLAUDE.md or runbook somewhere.

3. **Finding (carried forward):** `sourceme.sh` exports `PYTHONPATH` pointing at the MAIN checkout's `lib/`, NOT the current working directory.
   **How discovered:** AUD-0078 sub-agent in the controlled batch. AUD-0243-option-B sub-agent in the follow-on batch was warned in advance and worked correctly.
   **Implication:** every worktree-based pytest run MUST override PYTHONPATH or it silently exercises the main checkout's old code.

4. **Finding (carried forward):** FastAPI rejects `Optional[BackgroundTasks]` at module import time with `FastAPIError: Invalid args for response field`.
   **Implication:** use `background_tasks: BackgroundTasks = None` (no Optional wrapper).

5. **Finding:** AUD-0272's audit row described BOTH a config-extraction concern AND a concurrency-model concern, but BY THE TIME the AUD-0272 sub-agent investigated, the config-extraction half had already shipped under AUD-0283 (commit `8f7abdfa`). The sub-agent's actual contribution was operator-typo validation only.
   **How discovered:** sub-agent grepped for the constants in the live code and found them already in `etc/config.yml` under `market_data.tuning`.
   **Implication:** before dispatching any future audit-fix sub-agent, grep the live code first to confirm the audit row's premise still holds. The Resolved status of audits like AUD-0086 / 0246 / 0292 / 0299 was also discovered during sub-agent pre-edit checks.

6. **Finding:** AUD-0243's option (a) BackgroundTasks was incompatible with downstream consumers because the local image path is consumed SYNCHRONOUSLY in the same request by `discord/parser.py:148-160` (vision routing) + `discord/idea_creator.py:661-670` (snapshot DB writes).
   **How discovered:** AUD-0243 sub-agent in the controlled batch traced the call graph through 5 files.
   **Implication:** for any "move sync work to BG" audit, the sub-agent MUST trace the post-call dependencies BEFORE proposing the fix. The user accepted the "skipped — needs separate decision" outcome and later authorised option B.

7. **Finding:** the audit row for AUD-0078 cites 6 call sites at line numbers 771, 1445, 1726, 2081, 2511, 3741 — but the actual current locations are 824, 1614, 1907, 2312, 2927, 4203 (drift of 50-500 lines per site).
   **How discovered:** AUD-0078 sub-agent grepped for the function name.
   **Implication:** trust function names, not audit-row line numbers.

## Commands that mattered

1. **Command:** `git rev-parse --short HEAD`
   **Output:** `c462004a` (start of this turn's checkpoint generation; was `850ff3c3` at end of follow-on batch).
   **Inferred:** parallel session shipped 6 commits during this planning turn; need to re-baseline before any worktree creation.

2. **Command:** `git log --oneline 850ff3c3..HEAD`
   **Output:**
   ```
   c462004a fix(trade-lineage): propagate lineage_id so all legs of one trade share an anchor
   3d68f177 test: codebase-wide ThreadedConnectionPool .getconn() autocommit invariant
   3da2fdcf fix(level-mind): worker pool-conn writes silently rolled back since AUD-0291
   05bee9d5 fix(tl): widen Service column to fit renamed breach-decision-* names
   2ceefdc7 refactor(breach-decision): rename level_b / Layer B subsystem to breach_decision
   d7eef05d feat(level-b): B6 — websocket tick sidecar + orchestrator tick_source seam
   ```
   **Inferred:** the rename `2ceefdc7` is the one that detached the orphan PIDs. The `c462004a` lineage_id propagation commit is potentially relevant to the AUD-0078 deferred sites (both reference `lineage_id` UPDATE flow) — worth a glance during AUD-0078 Option B implementation to check if the post-call code has shifted.

3. **Command:** `grep -E "^\| AUD-0078 " AUDIT_TRACKER.md` (during user's AUD-0078 confirmation request).
   **Output:** the full AUD-0078 row with explicit "moved the post-mutation refresh into FastAPI BackgroundTasks at the four call sites" + "Two call sites were INTENTIONALLY left synchronous because the response immediately reads / updates the row that `refresh_order_data` is responsible for inserting."
   **Inferred:** confirmed the 4/6 + 2-deferred shape exactly as the user described.

4. **Command:** `pgrep -af "level.b.*backfill"`
   **Output:** showed PIDs 831120, 831124, 831194, 831198 (orphans) + 902266, 902270, 902331, 902335 (newly started under breach-decision-* names).
   **Inferred:** old level-b orphans were still alive in parallel with the new breach-decision-* — duplicate work hitting the same DB tables. SIGTERM to wrappers cleaned them up.

5. **Command:** the 4 parallel sub-agent dispatches (Agent calls in the previous turn).
   **Output:** 4 markdown reports of ~600-1200 words each, covering AUD-0078 / AUD-0272 / Bucket C / T3.
   **Inferred:** the consolidated plan in the closing turn was a synthesis of all 4. Sub-agent quality was high (cited file paths + line numbers; flagged stale audit row premises; quoted code blocks).

## Schema / API / data facts worth preserving

- **Fact:** highest migration number currently is `079` (used by Level-B's `079_level_b_decision_log_rename_outcome.sql`). **Evidence:** the AUD-0357 sub-agent read the migrations directory; later confirmed by Bucket C planning. **Why it matters:** AUD-0228 → 080, AUD-0229 → 081, AUD-0280 → 082 if those Bucket C items ship in that order. Sub-agents must verify migration number at dispatch time, not from this checkpoint, because the parallel session may add more migrations.

- **Fact:** Bybit V5 has NO native multi-symbol batch endpoint. Only single-symbol (`?symbol=X`) or full-list-per-category (`symbol=` omitted). **Evidence:** AUD-0298 sub-agent confirmed by reading the existing `get_ticker` implementation and Bybit V5 docs. **Why it matters:** the AUD-0298 ship used Python-side dict lookup over a per-category full list. Any future "batch" Bybit operation needs to confirm endpoint shape first.

- **Fact:** AUD-0211 is already Resolved (shipped 2026-04-25 in batch 1, `e50d5894`). The Bucket C planning sub-agent caught this. **Evidence:** `grep -E "^\| AUD-0211 " AUDIT_TRACKER.md` returns Status `Resolved`. **Why it matters:** decisions-pending.md still LISTS AUD-0211 in the Bucket C section (line 502). Always trust AUDIT_TRACKER over decisions-pending for current status.

- **Fact:** the AUDIT_TRACKER row format is pipe-separated with field 6 (1-indexed if you count empty $1 from leading `|`) being Status. **Evidence:** consistent across all `awk -F'|' '{print $6}'` queries this session. **Why it matters:** sub-agents and orchestrator regularly grep the tracker; field-position consistency is load-bearing.

- **Fact:** `etc/config.yml` already has `market_data.tuning.{main_loop_workers, live_loop_interval_seconds}` from AUD-0283 (commit `8f7abdfa`). NOT under `mdsync:` namespace. **Why it matters:** AUD-0272 Option A pool_max bump is the only `etc/config.yml` change needed; the polling constants are already there.

## Next steps

1. **Wait for the user's reply to the 4 closing decisions.**

2. **If user picks AUD-0039 (recommended (a)):** unblocks Bucket C Tier 3 (AUD-0231 + 0282). Update decisions-pending.md to reflect the pick OR ship those two items in a single batch with the proven isolated-worktree pattern. Migration: AUD-0039 may also be a code change in the BybitClient adapter (auto-generate orderLinkId at the boundary) — read its tracker row for scope.

3. **If user picks AUD-0078 Option B:** dispatch a single sub-agent in worktree `../tradelens-aud-0078-deferred`, branch `audit/AUD-0078-followup-deferred-sites`. Scope: 2 call sites in `lib/tradelens/api/open_orders.py` (lines 3003 + 4288); inline INSERT into `order_leg_live` from Bybit response payload, then sync lineage UPDATE, then `background_tasks.add_task(refresh_order_data, ...)`. Tests must mock the subprocess and assert the lineage UPDATE happens before the response.

4. **If user picks AUD-0272 sequence (E → A):** dispatch two sequential sub-agents (or one that does both in order). E first: instrument `_update_live_candles` with timing logs, ship as a small commit, run for ~24h to gather wall-time data. Then A: per-thread connections + `pool_max: 10 → 20` config bump.

5. **If user authorises Tier 1 Bucket C ship order:** dispatch in order: AUD-0271 → 0088 → 0121 → 0158 → 0244 → 0222. Each in own worktree. Targeted tests after each cherry-pick. Full pytest after every 3.

6. **If user authorises T3 session 1 (AUD-0353 + 0354):** PREPARE THE RUNBOOK — do NOT execute. AUD-0353 is "you-only" because it requires `git filter-repo` + force-push. Produce a markdown doc at `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0353-runbook.md` with: pre-flight checklist (current key in production?), step-by-step for filter-repo, force-push verification commands, post-flight checklist (rotated key works?). User executes destructive steps; Claude does not.

7. **If user says "save the plan to disk":** write `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-followup-planning.md` with the full Plan deliverable from this checkpoint. Single-file commit, `# tests: exempt — docs-only`. Title: `docs(audit-autofix): planning — AUD-0078 sync sites + AUD-0272 broader + Bucket C + T3 queue`.

8. **If user runs `/clear` before authorising anything:** the next session must `/t-checkpoint-load` THIS file (`20260426-143041Z.md`) first. The Plan deliverable section is load-bearing.

## Verification checklist for the next session

1. `git rev-parse --short HEAD` — expect `c462004a` or later. If significantly past `c462004a`, re-baseline by reading `git log --oneline c462004a..HEAD` and confirming no audit-autofix commit landed in your domain.
2. `git status --short` — expect untracked items only (`.claude/`, `../.claude/agents/`, `../.claude/checkpoints/`, `.codex`, `docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` symlink, `docs/80-claude-checkpoints/20260426-091109-...md`). NO unstaged tracked-file modifications. If anything else, surface to user.
3. `claude-task current` — expect `20260426-aud-deferred-and-planning` (active) OR another task ID if user has moved on. If "(no active task)", confirm with user before assuming the planning task closed.
4. `grep -E "^\| AUD-0078 " AUDIT_TRACKER.md` — expect Status `Resolved` with the 4-shipped-2-deferred narrative still present.
5. `grep -E "^\| AUD-0272 " AUDIT_TRACKER.md` — expect Status `Resolved (partial)`.
6. `grep -E "^\| AUD-0211 " AUDIT_TRACKER.md` — expect Status `Resolved` (NOT in Tier 1 of any new dispatch).
7. `ls /app/syb/tradesuite/tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-followup-planning.md` — expect "No such file or directory" UNLESS user authorised the doc save.
8. `./bin/tl status` — expect 15/15 RUNNING. If any STOPPED, that's a separate operational issue; do NOT auto-restart without user direction.
9. The 4 closing decisions (AUD-0039 / AUD-0078 B vs C / AUD-0272 E→A approval / Tier 1 Bucket C order) — none should have moved unless the user explicitly answered them in a message after this checkpoint was written.
10. `df -h /app/syb` — disk should still be at ~90%. The "delete log archives" question (`pipeline_daemon.log.1` 873 MB + `level_guard_daemon.log.1` 160 MB) is still pending.
