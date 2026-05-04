# Checkpoint: Plan-mode active for 3-day audit-fix campaign — Day 1 Step 1 in progress (3 detached commits being inspected); 11 stale worktrees pending cleanup; tightened execution rules approved by user; NO dispatch has fired yet

**Saved:** 2026-04-27 18:11:47 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ 8023bfc0
**Session:** 0e91dacd-d21c-40a3-be52-f82d52bdbc97
**Active task:** (no active task — last `/t-done` closed `20260427-aud-tranche-option1` at commit `5f514d88`)

## Handover Statement

You are picking up a **plan-mode-active** session at the very beginning of a 3-day high-throughput audit-fix campaign. The user has approved the campaign architecture and a set of tightened execution rules; I have already written the campaign plan to `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md` and that file is the canonical source of truth for the campaign's structure. **Read it first, in full, before doing anything else.** Then read this checkpoint's "Tightened execution rules" section (the user's verbatim amendments to the plan, sent in their last full message), the "Detached commits triage" section (the partial work I started inspecting before the checkpoint), and the "Stale worktrees" section (which lists the 11 leftover worktrees that need to be cleaned up).

The single most important piece of state right now: **NO sub-agents have been successfully dispatched yet in this Wave 1**. The user rejected my prior 12-agent dispatch because the agent-to-file mapping had 3 agents on `open_orders.py`, 2 on `trades.py`, and several on shared frontend files (`lib/api.ts`, `main.tsx`, `trade-journal-chart.tsx`, etc.) — that would cause cherry-pick conflicts on overlapping lines. The CORRECTED plan (one agent per file or per-disjoint-file-cluster) is approved and written down. **Three of the rejected agents had already committed before the rejection landed**: `9173c3f2` (AUD-0010 bybit_client.py), `688cbdaf` (AUD-0326 frontend ErrorBoundary), `5966d3b4` (AUD-0317/0321/0336 frontend api/lib + vite). I started inspecting their diffs (the inspection output is captured in this checkpoint's "Detached commits triage" section). The user interrupted me to checkpoint before I made any cherry-pick / discard decision.

What to read FIRST, in order: (1) `/app/syb/.checkpoint-of-context-checkpoints` does NOT exist — read THIS file you are looking at; (2) `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md` (the campaign plan); (3) this checkpoint's "Tightened execution rules" section for the user's verbatim amendments; (4) this checkpoint's "Detached commits triage" section for the inspection work I had already done on commits `9173c3f2`, `688cbdaf`, `5966d3b4`; (5) `tradelens/AUDIT_TRACKER.md` — but only spot-check rows, do NOT scan all 380. Plan mode is still active at the time of this checkpoint write — you may need to call `ExitPlanMode` after re-reading + producing the Wave 1 pre-dispatch table to get the user's go-ahead. The user's last interaction was to interrupt and checkpoint; they did NOT yet approve the Wave 1 pre-dispatch table.

Known landmines: (a) The Agent-tool runtime creates worktrees BEFORE the dispatch is "approved" by the user-permission system — even rejected dispatches leave locked worktrees behind. There are currently 11 stale worktrees under `/app/syb/tradesuite/.claude/worktrees/agent-*` that need cleanup before Wave 1. (b) The parallel session has uncommitted WIP in the main repo at `lib/tradelens/services/sizing.py` and `lib/tradelens/utils/state_manager.py` (see git status output) — these collide with what I had planned for Wave 1 Agent 6 (services+utils cluster). The new "Parallel WIP rule" requires checking dirty files BEFORE every wave; **this collision must be handled before Wave 1 dispatches**. (c) The `/t-checkpoint` slash command was invoked while plan-mode was active. Plan mode forbids non-plan-file edits; the checkpoint file write is the user's explicit slash-command override. After this checkpoint, the user plans to `/clear` and `/t-checkpoint-load` — so the next session reading this MUST recognise plan mode is technically still in effect according to the system reminder, but the user wants Wave 1 to fire after the pre-dispatch table is reviewed. (d) The campaign plan file lives at `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md` — that is OUTSIDE the tradelens repo, NOT inside it. Don't try to git-track it.

What NOT to do: do NOT re-dispatch the original 12-agent wave with file collisions (the user already rejected it). Do NOT cherry-pick the 3 detached commits without first reading this checkpoint's "Detached commits triage" section + the user's tightened rules — the user said "Inspect each commit first, decide per-commit", so you must show your inspection work and decision rationale before cherry-picking. Do NOT write to AUDIT_TRACKER.md from any sub-agent — this is now a hard rule (the orchestrator owns AUDIT_TRACKER.md, batched per wave). Do NOT exceed 6 coding agents OR 20 AUD IDs per wave (whichever limit hits first — user's tightened rule). Do NOT skip the full-pytest gate after each wave (user explicitly tightened to "every wave" not "end of day"). Do NOT touch any file currently dirty from a parallel session (`sizing.py`, `state_manager.py` at this moment; re-check before every wave). Do NOT include T3 design-ready items in this campaign (user explicitly excluded them).

The exact next action the user is expecting: **finish Day 1 Step 1**. That means: (1) finish reading the diffs of the 3 detached commits — I had only read 9173c3f2 and 688cbdaf in detail and started 5966d3b4; (2) decide per-commit whether to cherry-pick or discard, with rationale; (3) execute the decision (cherry-pick what's keep-able, leave the rest); (4) clean up all 11 stale worktrees; (5) produce the Wave 1 pre-dispatch table per the user's "Pre-dispatch wave table" tightened rule (agent ID, files owned, AUD IDs, severity mix, test plan, reason files are disjoint, parallel-WIP-collision check). Then STOP and wait for the user to approve the Wave 1 table (the tightened-rules message says "proceed automatically unless the wave violates these rules", but the user has just interrupted twice — once for plan mode, once for checkpoint — so they clearly want the pre-dispatch table reviewed before Wave 1 fires).

## User note

> *(The user invoked `/t-checkpoint` without a free-form note. Their last actual instruction to me, before invoking checkpoint, was: "please wait - I want to compact the conversation before you continue - i will use t-checkpoint followed by clear followed by t-checkpoint-load")*

## Session context

### User's stated goal (verbatim where possible)

The session opened earlier today with a `/t-done` from the prior tranche (AUD-0039(b)-env-hook + AUD-0282 + AUD-0231-conditional + AUD-0332-P1 + AUD-0325 + AUD-0202 + 4 P1 follow-ups), which closed at commit `5f514d88`. The user then asked: *"how many fixes are there left to do?"*

I reported 148 of 380 audit rows still open. The user replied with the campaign-defining message:

> "The pace of remediating these fixes is far too slow. I have been working on this for 1 week and we are not even 40% complete. I need you to be much more ambitious and do much larger batches of work unattended. I need all of these fixes finished in 3 days"

The 3-day target is the campaign's defining constraint. The user repeatedly emphasized **safety + ambition simultaneously**, not throughput at any cost.

After my first dispatch failed (I tried to fire 12 parallel agents in one message, with file collisions), the user pushed back twice:

> "what about file overlap?"
> "I need you to prevent multiple agents writing to the same files if there is a risk of corruption"

That established the one-agent-per-file rule.

When I later asked about AUDIT_TRACKER coordination, the user said:

> "what about the agents already running?"
> "also I need you to serialise the updates to AUDIT_TRACKER. maybe each agent writes to its own copy of audit tracker then you merge the changes at the end. And you mentioned worktrees, is that a safe way to do it then? does that prevent the issue with agents writing to the same files if they already use separate work trees. Lets discuss all this and agree a plan before you do any work"

That triggered plan mode and the architectural discussion. The user answered three AskUserQuestion choices:
1. AUDIT_TRACKER strategy → **Orchestrator writes (current pattern, batched per wave)**
2. The 3 already-shipped detached commits → **Inspect each commit first, decide per-commit**
3. T3 design-ready items → **Exclude entirely from 3-day budget**

After I wrote the plan file, the user rejected my `ExitPlanMode` call and sent the **tightened execution rules** (10-point list, reproduced verbatim in the next section).

### Tightened execution rules (verbatim from user, the operating contract for the campaign)

> Core approvals:
> - Use safe parallel dispatch.
> - Use one agent per file or tightly related file-cluster.
> - Do not allow two agents in the same wave to touch the same source file.
> - AUDIT_TRACKER.md is orchestrator-only.
> - Agents must not stage or edit AUDIT_TRACKER.md.
> - Orchestrator writes one consolidated tracker commit per wave.
> - Use isolated worktrees.
> - Cherry-pick agent commits serially.
>
> Amendments to the plan:
>
> 1. Full pytest cadence
> Do not wait until the end of the day for full pytest.
> Run full pytest after every wave.
> If a wave is very small, under 5 AUDs, a targeted sweep is enough, but any wave with 5+ AUDs or any money/schema/backend API changes must get full pytest before the next wave starts.
>
> 2. Wave size cap
> Cap each wave at:
> - maximum 6 coding agents, OR
> - maximum 20 AUD IDs,
> whichever limit is hit first.
>
> Do not run 8-10 agents in one wave unless the file scopes are tiny and completely independent.
>
> 3. Agent commit scope
> One agent may handle multiple AUDs only when they are:
> - in the same source file or tightly coupled files,
> - thematically related,
> - testable with one coherent targeted test suite.
>
> Do not pack unrelated AUDs into one agent just to increase throughput.
>
> 4. Throughput target
> The target is not "close 127 at any cost".
> The target is:
> - ship every safe item,
> - park every unsafe or unclear item quickly,
> - keep master green,
> - keep TradeLens restartable at all times.
>
> 5. Frontend rule
> Frontend work may proceed only after verifying the Vitest setup is actually working on master.
> For frontend waves, run:
> - npm test
> - npm run build
> - npm run lint
> after the wave.
> If any frontend shared file is touched by more than one candidate item, group those items into one agent or park them.
>
> 6. Schema/migration rule
> Schema migrations are allowed only if:
> - migration number is verified at dispatch time,
> - migration is forward-only and idempotent,
> - backfill does not guess ambiguous data,
> - rollback or safe parked state is documented.
> Run migration-specific tests and full pytest before moving to the next wave.
>
> 7. Money-path rule
> Money-path items can be worked on if already approved, but must use stronger testing:
> - targeted tests,
> - relevant integration tests,
> - full pytest before the next wave.
> If tests show any order-placement correctness risk, park the item and continue.
>
> 8. Parallel WIP rule
> Before every wave, run git status --short and identify dirty files.
> No agent may touch any file currently dirty from a parallel session.
> If a candidate needs a dirty file, park it for later.
>
> 9. Pre-dispatch wave table
> Before each wave, produce the table:
> - agent ID
> - files owned
> - AUD IDs
> - severity mix
> - test plan
> - reason files are disjoint
> Then proceed automatically unless the wave violates these rules.
>
> 10. Failure handling
> If an item expands, fails locally, or becomes ambiguous:
> - park that item,
> - clean its worktree,
> - record the reason,
> - continue the wave if the rest of the wave is unaffected.
>
> Hard stop only for:
> - master cannot be restored cleanly,
> - destructive git/history operation,
> - live secret rotation,
> - repeated test failure across 3 unrelated items,
> - data corruption risk,
> - money-loss/order-placement correctness risk,
> - accidental inclusion of unrelated Level-B, .claude, checkpoint, chat export, or parallel WIP files.
>
> Start with Day 1 Step 1:
> - inspect the 3 detached commits,
> - decide cherry-pick or discard,
> - clean stale worktrees,
> - then produce Wave 1 pre-dispatch table before firing agents.

### User preferences and corrections established this session

(All carried forward, plus new this session.)

- **One agent per file rule.** The user's verbatim correction: "I need you to prevent multiple agents writing to the same files if there is a risk of corruption". This applies even within worktrees — worktrees prevent concurrent-write corruption, but cherry-pick conflicts on the same file still cause issues. So one-agent-per-file is the rule.
- **Discuss-before-doing.** "Lets discuss all this and agree a plan before you do any work" — triggered plan mode. Carries forward as: ask for explicit approval before any large new architectural pattern.
- **Wave cap is 6 agents OR 20 AUD IDs.** Hard cap.
- **Full pytest after EVERY wave** (not end of day) for waves of 5+ AUDs or money/schema/backend changes. This was a user-imposed tightening of my original plan which had said "end of day pytest".
- **Park aggressively.** "If an item expands, fails locally, or becomes ambiguous: park that item, clean its worktree, record the reason, continue the wave if the rest of the wave is unaffected." The throughput target is NOT "close 127 at any cost" — it is "ship every safe item, park every unsafe or unclear item quickly".
- **Parallel WIP files are off-limits per-wave.** Run `git status --short` before each wave; any dirty tracked file is off-limits for that wave's agents. Re-check at every wave boundary.
- **AUDIT_TRACKER is orchestrator-only.** Agents never edit it. Orchestrator does ONE consolidated tracker commit per wave.
- **No T3 design implementations in this 3-day budget.** Excluded explicitly: AUD-0361 P2+, AUD-0332 P2+, AUD-0002 retry, AUD-0008 DB convergence, AUD-0114, AUD-0115, AUD-0155, AUD-0170, AUD-0171.
- **No live secret rotation, no destructive git history rewrite, no force-push.** Hard stop conditions.

### Working environment

- **Master HEAD:** `8023bfc0` (`fix(mdsync): live loop self-finalizes recent candles (limit 2 → 4)`).
- **Master moved during this session.** Started at `5f514d88` (my last campaign tracker commit). Parallel session shipped `00566ccf` (`fix(level-mind): worker pool conn missing UTC option — leases born expired`) and `8023bfc0` since.
- **Plan file:** `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md` — written, but `ExitPlanMode` was rejected. Plan mode is still active.
- **Active task:** none (`claude-task current` returned empty). Last task `20260427-aud-tranche-option1` was closed by `/t-done` at `5f514d88`.
- **Pre-existing dirty tree (parallel-session WIP at the time of this checkpoint):**
  - `lib/tradelens/services/sizing.py` (modified)
  - `lib/tradelens/utils/state_manager.py` (modified)
  - Plus the usual untracked: `.claude/`, `.codex`, AUDIT_TRACKER symlink, 2 checkpoint MDs in `docs/80-claude-checkpoints/`.
- **Pre-existing services:** the parallel session's mdsync work has committed; their old uncommitted-WIP from yesterday's dirty tree (`bin/mdsync_pg.py`, `lib/tradelens/mdsync/runner.py`, etc.) is now committed/clean. The remaining dirty files are NEW WIP, NOT yesterday's leftovers.
- **Stale worktrees:** 11 of them under `/app/syb/tradesuite/.claude/worktrees/agent-*`. Most based on master `8023bfc0` with parallel-session-WIP inherited; 3 have detached-HEAD commits (the ones I need to triage). Full list with HEADs in the "Stale worktrees" section below.
- **No background processes I started.** All sub-agents from the rejected dispatch never ran (or ran to commit-step then died).

## Objective

The user wants 148 open audit items closed in 3 days, with the explicit constraint that the work is **safe** (master stays green, TradeLens stays restartable at all times, no money-path correctness regressions, no destructive ops). The "in this conversation" objective is narrower: **execute Day 1 Step 1** of the campaign plan. That means inspecting the 3 detached commits already on disk, deciding per-commit whether to cherry-pick, cleaning up the 11 stale worktrees, and then producing the Wave 1 pre-dispatch table per the user's tightened "Pre-dispatch wave table" rule.

The campaign's broader scope (3 days) is OUT of this conversation — it is the multi-session arc this conversation kicks off. Day 1 has roughly 2 waves (Wave 1 backend ~6 agents/~20 AUDs, Wave 2 frontend ~6 agents/~30 AUDs) plus the triage step and full-pytest gates between waves.

Out of scope for this conversation: T3 design implementations, AUD-0353/0354 runbook execution, AUD-0218 product decision. All explicitly excluded by the user.

## Narrative: how we got here

The session opened with the post-`/t-done` reflection — the user asked how many fixes were left, I reported 148 open, and the user immediately set the 3-day target and asked for ambition. I responded with three options (Adapter unblock + frontend bootstrap; Bucket C cleanup tail; T3 foundation start) and the user picked Option 1. We shipped that 6-AUD tranche cleanly (1 code, 5 docs) plus 4 follow-ups discovered by AUD-0332 P1's vitest bootstrap. Total 10 AUDs in 12 commits. That ran cleanly and ended with `/t-done` at `5f514d88`.

The user then asked the headline question: "how many fixes are there left to do?" and I reported 148/380. Their response was the campaign-defining message: "I need all of these fixes finished in 3 days". I tried to be helpful by acknowledging 12 items physically can't fit (T3 + user-only + parked) and proposing a 12-agent dispatch immediately. I dispatched 12 parallel agents in one tool message. The user rejected ALL 12.

The user's correction was the critical pivot of the session: "what about file overlap? I need you to prevent multiple agents writing to the same files if there is a risk of corruption". This was a legitimate correctness concern. My 12-agent plan had: 3 agents on `open_orders.py` (split into clusters of 4, 5, 4 AUDs each), 2 on `trades.py`, multiple on shared frontend components like `lib/api.ts` and `main.tsx` and `trade-journal-chart.tsx`. Worktrees give each agent a clean working copy, but cherry-picking the second agent's commit into master would conflict on overlapping lines from agent 1's commit. I proposed the corrected one-agent-per-file plan.

I checked what state the rejected dispatch had left behind. Three of the 12 agents had reached the commit step before the user-permission rejection landed: `9173c3f2` (AUD-0010), `688cbdaf` (AUD-0326 — note: parked AUD-0308/0309/0310/0311), `5966d3b4` (AUD-0317/0321/0336). Eight other agents had locked but empty worktrees. I gathered evidence for the user.

The user then said: "what about the agents already running?" — concerned about the leftover state. After my analysis they said: "also I need you to serialise the updates to AUDIT_TRACKER. ... Lets discuss all this and agree a plan before you do any work". This triggered plan mode.

In plan mode I asked three architecture questions via `AskUserQuestion`:
1. AUDIT_TRACKER strategy (orchestrator writes vs per-agent staging vs each-agent-edits-own-copy) → user picked **orchestrator writes, batched per wave**.
2. The 3 detached commits → user picked **Inspect each commit first, decide per-commit** (NOT my recommended "cherry-pick all 3 + clean up").
3. T3 design items → user picked **Exclude entirely from 3-day budget**.

I wrote the plan file. I called `ExitPlanMode`. **The user rejected `ExitPlanMode`.** Instead they sent the 10-point tightened-rules message reproduced verbatim above, ending with "Start with Day 1 Step 1: inspect the 3 detached commits, decide cherry-pick or discard, clean stale worktrees, then produce Wave 1 pre-dispatch table before firing agents."

I started Day 1 Step 1: I read commit `9173c3f2` (AUD-0010) — clean addition of `BybitClient.from_cache` classmethod + DeprecationWarning on direct construction. I read commit `688cbdaf` (AUD-0326) — clean ErrorBoundary addition with the per-route reset + 7 vitest tests. I started reading `5966d3b4` (AUD-0317/0321/0336) — saw the api.ts changes (typed `ApiError` class with structured FastAPI validation array) and started reading the rest. The user interrupted me with "please wait - I want to compact the conversation before you continue - i will use t-checkpoint followed by clear followed by t-checkpoint-load".

That is the current state. I have NOT cherry-picked anything. I have NOT cleaned the worktrees. I have NOT produced the Wave 1 table. The next session needs to finish Day 1 Step 1.

## Work done so far

1. **Inspected commit `9173c3f2`** (AUD-0010 bybit_client.py). Verified via `git show --stat 9173c3f2` and `git show 9173c3f2 -- 'tradelens/lib/tradelens/adapters/bybit_client.py'`. The diff shows: addition of `BybitClient.from_cache(account_name, print_json=False)` classmethod that delegates to `get_bybit_client(account_name, print_json)`; addition of `DeprecationWarning` emission inside the existing `__init__` when `_use_cache=True` (the legacy path that aliases `self.__dict__` to the cached singleton, which silently surprised callers who thought they had a fresh instance); a new test file at `tests/unit/test_aud0010_bybit_direct_construction_deprecation.py` with `_reset_bybit_cache` autouse fixture + `test_aud0010_direct_construction_emits_deprecation_warning` and other tests (file is 120 lines). Diff stat: 2 files changed, 159 insertions, 5 deletions. **Conclusion: this commit looks clean and ship-able. No file collision with anything else in the rejected dispatch.** Recommendation pending user review: cherry-pick.

2. **Inspected commit `688cbdaf`** (AUD-0326 frontend ErrorBoundary). Diff stat: 3 files changed, 344 insertions, 20 deletions. Files: `tradelens/frontend/web/src/app.tsx` (+61, -20), `tradelens/frontend/web/src/components/__tests__/error-boundary.test.tsx` (+164, new), `tradelens/frontend/web/src/components/error-boundary.tsx` (+139, new). Commit message states the parked items: AUD-0308, AUD-0309, AUD-0310, AUD-0311 (all multi-day refactors of large files: 6,731 LOC trade-journal-chart.tsx; 44-useState smart-trade-form.tsx; 3,647 LOC trade-journal.tsx; React Query migration). The commit ships only AUD-0326 (top-level + per-route ErrorBoundary, 7 new vitest tests). **Conclusion: clean isolated work, no shared-file collision.** Recommendation pending user review: cherry-pick. The parked AUDs (0308/0309/0310/0311) need to be re-handled in a future wave per their parked-reasons.

3. **Started inspecting commit `5966d3b4`** (AUD-0317 + AUD-0321 + AUD-0336). Diff stat: 2 files changed, 105 insertions, 51 deletions. Files: `tradelens/frontend/web/src/lib/api.ts` (+105, -51), `tradelens/frontend/web/vite.config.ts` (+11, -...). The commit message lists parked items: AUD-0312 (zero auth headers — depends on AUD-0227 user/auth epic), AUD-0314 (3,192 LOC api.ts split — multi-file architectural refactor), AUD-0315 (chart memoisation), AUD-0316 (eslint-disable suppressions), AUD-0318 (server-paginated filters), AUD-0319 (debounce-commit field wrappers), AUD-0323 (STATUS_COLUMN_OPTIONS shared via OpenAPI), AUD-0324 (~150 console.* calls), AUD-0330 (12,700 LOC mega-components), AUD-0340 (build-time marker types). Visible diff portion shows: addition of `ApiError` class + `ApiValidationError` interface + `flattenValidation()` helper inside the response interceptor — preserves FastAPI's structured validation payload while keeping `err.message` populated for legacy callers. **Inspection partially done; I had NOT yet read the vite.config.ts changes nor verified the test file location/coverage.** Recommendation pending: needs full inspection completion before decision.

4. **Verified the 11 stale worktrees and their HEAD-states.** Ran `git worktree list` and `for w in /app/syb/tradesuite/.claude/worktrees/agent-*; do ...; done` to inspect each. 8 are based on master `8023bfc0` with parallel-session-WIP inherited (1-6 modified files each, all in mdsync/stores/etc — not the agents' actual edits, just the inherited-at-creation-time state of the parallel session's working tree). 3 are on detached HEADs containing the commits inspected above (`9173c3f2`, `688cbdaf`, `5966d3b4`). All 11 are LOCKED.

5. **Wrote the campaign plan** at `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md`. Sections: Context, Architecture (4 rules), 3-day budget breakdown (136 achievable / 12 out of budget), Day-by-day plan, Dispatch artefact per wave, Verification per wave, Critical files, Out-of-budget items. Plan file is ~210 lines.

6. **Established session memory in this conversation** (not committed to memory store): the AUDIT_TRACKER row format is pipe-separated with status as field 6; the highest existing AUD ID is 0376 (so AUD-0377-0380 ship next AUD assignments — already used in earlier today's tranche); the parallel session's WIP files at this moment are `lib/tradelens/services/sizing.py` and `lib/tradelens/utils/state_manager.py`.

## Decisions made (and why)

1. **Decision:** Use one agent per file (or per-disjoint-file-cluster within a single agent) for the campaign.
   **Proposed by:** Jointly — user raised the file-overlap concern; Claude formalised the rule.
   **Rationale:** Worktrees give each agent a clean working tree (no concurrent-write corruption), but they share the git object database. When two agents both modify the same file in their worktrees, cherry-picking the second one onto master AFTER the first has been cherry-picked produces a content conflict on overlapping lines. The conflict has to be resolved manually, which is risky for money-path code and impossible to do in batch. One-agent-per-file eliminates this entirely.
   **Alternatives considered:**
     - Multiple agents per file with serialized cherry-pick + rebase between them (rejected — adds round-trips and rebase failures are common).
     - Manual conflict resolution (rejected — defeats throughput goal and is unsafe for money-path code).
     - File locking via filesystem mechanisms (rejected — adds infrastructure for no benefit).
   **Revisit if:** A specific file has so many AUDs that a single agent commit would be unmanageable. Even then the right answer is to split AUDs into separate-WAVE dispatches, not parallel-WAVE-dispatches against the same file.
   **Affects:** Every wave's dispatch shape. The Wave 1 plan in the campaign-plan-file already follows this rule (Agent 1 owns open_orders.py with all 13 of its AUDs, etc.).

2. **Decision:** AUDIT_TRACKER is orchestrator-only. Sub-agents do NOT touch it. Orchestrator writes ONE consolidated tracker commit per wave.
   **Proposed by:** Jointly — user raised concern about agent-edit serialization; Claude listed three options; user picked the simplest.
   **Rationale:** AUDIT_TRACKER.md is a single shared file. Concurrent edits would corrupt it even with worktrees (agents would each have their own copy in their worktree, but cherry-picking would conflict on the same row). The simplest safe pattern is to never let agents touch it: agents include the proposed tracker-row text in their final report, orchestrator writes all of a wave's row updates into one tracker commit after cherry-picking.
   **Alternatives considered:**
     - Per-agent staging file (`tradelens/_tracker_updates/<agent-id>.md`) merged at wave-end — rejected for added complexity; orchestrator-writes is simpler.
     - Each agent edits its own AUDIT_TRACKER copy — rejected for merge complexity if two agents touch the same row (can't happen if one-agent-per-file is followed, but better to remove the risk class entirely).
   **Revisit if:** Orchestrator-author-from-agent-report loses important context. So far this hasn't happened.
   **Affects:** Every wave's closing step.

3. **Decision:** Cap waves at 6 coding agents OR 20 AUD IDs (whichever hits first).
   **Proposed by:** User (tightened-rules amendment 2).
   **Rationale:** Larger waves increase the surface for cross-cutting failure modes (an unrelated test breakage during full-pytest could mask which agent caused it; a single bad commit can stall the whole wave's cherry-pick chain). 6 agents is small enough to triage individually if needed; 20 AUDs caps the size of the post-wave tracker commit.
   **Alternatives considered:**
     - 12 agents (my original) — rejected by user, too large.
     - 8-10 agents (compromise) — rejected by user unless file scopes are tiny and completely independent.
   **Revisit if:** A wave has many tiny single-AUD agents and the cap feels artificial. Even then, prefer multiple smaller waves.
   **Affects:** Wave 1 and onwards. The plan's Wave 1 had 8 backend agents — needs trimming to 6 OR splitting into Wave 1A and Wave 1B.

4. **Decision:** Run full pytest after every wave (5+ AUDs) or every wave touching money/schema/backend, NOT just end of day.
   **Proposed by:** User (tightened-rules amendment 1).
   **Rationale:** Catching regressions per-wave isolates the cause; per-day pytest could let a regression chain across 30+ commits before discovery.
   **Alternatives considered:**
     - End-of-day pytest (my original plan) — user explicitly tightened.
     - Targeted-sweep-only — allowed only for waves under 5 AUDs that don't touch money/schema/backend.
   **Revisit if:** Full pytest takes >5 minutes per wave and is dominating throughput. So far it's been ~70-90s.
   **Affects:** Inter-wave gating. The plan's verification section needs updating to reflect this.

5. **Decision:** Park-aggressively rather than fix-aggressively when an AUD hits friction.
   **Proposed by:** User (tightened-rules amendment 4 + 10).
   **Rationale:** "The target is not 'close 127 at any cost'." Heroic recovery on a half-done fix risks destabilising master. A parked AUD with a clear note can be picked up later by a focused session.
   **Alternatives considered:**
     - Heroic-recovery via inline orchestrator fixes (rejected — adds inconsistency with one-agent-per-file rule).
   **Revisit if:** Park rate gets high enough to threaten the 3-day target. Even then, the right response is to slow down and inspect parking patterns, not to push harder.
   **Affects:** Every agent's prompt explicitly authorises parking.

6. **Decision:** Exclude the 9 T3 design-ready items from the 3-day budget.
   **Proposed by:** User (AskUserQuestion answer 3).
   **Rationale:** Each T3 item is 1-3 weeks of careful implementation per its design doc. Forcing them into batch mode would either ship unsafe partial work or burn 2-4h per item in dispatch-then-park churn.
   **Alternatives considered:**
     - Phase 1 only of each (my second-best option) — rejected.
     - Stretch-goal inclusion — rejected.
   **Revisit if:** All other 136 items finish before Day 3. Unlikely given pace.
   **Affects:** Wave plans never include AUD-0361 P2+, AUD-0332 P2+, AUD-0002, AUD-0008, AUD-0114, AUD-0115, AUD-0155, AUD-0170, AUD-0171.

7. **Decision (tentative, awaiting user execution):** Inspect each of the 3 detached commits before deciding cherry-pick vs discard.
   **Proposed by:** User (AskUserQuestion answer 2).
   **Rationale:** User wanted explicit verification rather than blanket cherry-pick. Pre-emptively cherry-picking commits made under the OLD plan (with file-collision risk) before reviewing them is the kind of speed-over-safety move the user is protecting against.
   **Alternatives considered:**
     - Cherry-pick all 3 (my recommended option, rejected).
     - Discard all 3 (rejected).
   **Revisit if:** The inspections are clean and the work is salvageable — proceed with cherry-pick. The inspection is partially done (commits 1 and 2 read; commit 3 partially read).
   **Affects:** Day 1 Step 1.

## Rejected approaches (and why)

1. **Approach:** Dispatch 12 parallel agents in one wave, with multiple agents on the same file (open_orders.py × 3, trades.py × 2, frontend shared components × several).
   **Who proposed it:** Claude (in the message immediately following the user's "I need all of these fixes finished in 3 days" request).
   **Why rejected:** The user pushed back with "what about file overlap? I need you to prevent multiple agents writing to the same files if there is a risk of corruption". Even with worktrees, cherry-picking commits that modify overlapping lines in the same file produces conflicts. Three agents had committed by the time the rejection landed; the other 9 had locked-but-empty worktrees.
   **Would we reconsider if:** Never. The one-agent-per-file rule is now a hard architectural rule.

2. **Approach:** Cherry-pick the 3 detached commits without inspection (orchestrator's recommended option in the AskUserQuestion question 2).
   **Who proposed it:** Claude.
   **Why rejected:** User picked "Inspect each commit first, decide per-commit". User wants explicit verification rather than blanket cherry-pick.
   **Would we reconsider if:** Inspections show all 3 are clean — that's the path forward; but the inspection step is mandatory.

3. **Approach:** End-of-day full-pytest cadence (my original plan).
   **Who proposed it:** Claude.
   **Why rejected:** User tightened to "Run full pytest after every wave" for 5+ AUD waves.
   **Would we reconsider if:** Full pytest takes too long per wave. Currently ~70-90s. Acceptable.

4. **Approach:** 8-12 agents per wave for max throughput.
   **Who proposed it:** Claude.
   **Why rejected:** User capped at 6 agents OR 20 AUD IDs. Larger waves were judged as too risky.
   **Would we reconsider if:** Tiny independent file scopes only — the cap allows up to 10 in that narrow case. None of the planned Wave 1 fits that exception.

5. **Approach:** Include T3 design implementations (Phase 1 only or stretch-goal) in the 3-day budget.
   **Who proposed it:** Claude (AskUserQuestion options 2 and 3).
   **Why rejected:** User picked "Exclude entirely". T3 work needs dedicated sessions, not batched throughput.
   **Would we reconsider if:** All non-T3 items finish before Day 3 ends. Unlikely.

6. **Approach:** Each agent edits its own copy of AUDIT_TRACKER.md in worktree, orchestrator extracts row diffs.
   **Who proposed it:** Claude (AskUserQuestion option 3 for tracker strategy).
   **Why rejected:** User picked "Orchestrator writes (current pattern)". Simpler, no merge logic.
   **Would we reconsider if:** Orchestrator authorship is losing important agent-derived context. Hasn't happened.

7. **Approach:** Per-agent tracker-row staging file (`_tracker_updates/<agent-id>.md`).
   **Who proposed it:** Claude (AskUserQuestion option 2 for tracker strategy).
   **Why rejected:** User picked option 1 (orchestrator writes). Simpler.
   **Would we reconsider if:** Orchestrator-write becomes a bottleneck.

8. **Approach:** Auto-proceed Wave 1 immediately after the user's "Start with Day 1 Step 1" message.
   **Who would have proposed it:** Claude.
   **Why rejected (preventatively):** The user's tightened-rules message ends with "produce Wave 1 pre-dispatch table before firing agents". Then they immediately interrupted twice (once for plan-mode discussion, once for `/t-checkpoint`). The pre-dispatch table is now a clear gate before Wave 1 fires.

## Files touched or about to touch

1. `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md`
   - **Status:** edited-saved (the campaign plan). NOT in the tradelens git repo (lives in a separate `~/.claude` plans tree).
   - **What's there:** ~210 lines covering Context, Architecture (4 rules), 3-day budget, Day-by-day plan, Dispatch artefact, Verification, Critical files, Out-of-budget items.
   - **Why it matters:** Canonical campaign plan. Read this first.
   - **Cross-refs:** Decisions 1-6 are all written down here; the Handover Statement points to it as priority-read.

2. `/app/syb/tradesuite/.claude/checkpoints/20260427-181147Z.md`
   - **Status:** edited-saved (this checkpoint).
   - **What's there:** This file.
   - **Why it matters:** Primary working-state record after `/clear`.

3. `/app/syb/tradesuite/.claude/worktrees/agent-a635fe81c315dcce8/`
   - **Status:** locked stale worktree, HEAD=`9173c3f2` (AUD-0010).
   - **What's there:** A complete copy of the tradelens repo at the AUD-0010 commit.
   - **Why it matters:** Source of the AUD-0010 commit. Cleanup needed after triage decision.

4. `/app/syb/tradesuite/.claude/worktrees/agent-a5b181a6d0af8b680/`
   - **Status:** locked stale worktree, HEAD=`688cbdaf` (AUD-0326 frontend ErrorBoundary).
   - **What's there:** Repo at the AUD-0326 commit.
   - **Why it matters:** Source of the AUD-0326 commit.

5. `/app/syb/tradesuite/.claude/worktrees/agent-adada7a8e7f16f37a/`
   - **Status:** locked stale worktree, HEAD=`5966d3b4` (AUD-0317/0321/0336).
   - **What's there:** Repo at that commit.
   - **Why it matters:** Source of the multi-AUD frontend api/lib commit.

6. The 8 other stale worktrees (agent-a08b3b52c2573ff27, a364dce44b1f4bb43, a4ea7068c7d953296, a8046d87976e802d9, aaddb7b845e61aeb4, ac138d6ac1d2de2ca, ac4b5b31f18522d07, aeb9b05d1bc7e8e74)
   - **Status:** locked stale worktrees, HEAD=`8023bfc0`, no useful commits (rejected agents that didn't reach commit-step).
   - **What's there:** Inherited parallel-session-WIP modifications (1-6 files each, all unrelated to the AUDs they were supposed to address).
   - **Why it matters:** Need cleanup before Wave 1.

7. `tradelens/AUDIT_TRACKER.md`
   - **Status:** read-only this conversation.
   - **What's there:** 380 audit rows; ~228 Resolved, 128 Confirmed, plus partials/parked/etc. The header at line 1 is `# TradeLens Audit Tracker`; it includes a footer `*End of tracker*` at line 446-ish. Field 6 of the pipe-separated row format is Status.
   - **Why it matters:** Source of truth. Orchestrator updates per wave.

8. `tradelens/lib/tradelens/services/sizing.py` AND `tradelens/lib/tradelens/utils/state_manager.py`
   - **Status:** PARALLEL-SESSION DIRTY (modified, uncommitted, not mine). DO NOT TOUCH in Wave 1.
   - **What's there:** Unknown — parallel session's WIP. Per the user's tightened "Parallel WIP rule": no agent may touch any file currently dirty.
   - **Why it matters:** This collides with what my plan called "Agent 6: services+utils cluster" (AUD-0056 + 0058 + 0077 + 0247). AUD-0056 + 0077 are in `sizing.py`, AUD-0247 is in `state_manager.py`. **All 3 must be parked from Wave 1.** Only AUD-0058 (`utils/initial_risk_calculator.py`) is safe in that bucket. Re-bucket Wave 1 accordingly.

## Open threads

1. **Thread:** Inspection of commit `5966d3b4` is incomplete.
   **State:** Read api.ts changes; have NOT read vite.config.ts changes nor verified test coverage.
   **Context to resume:** `git show 5966d3b4 -- 'tradelens/frontend/web/vite.config.ts'` and `git show 5966d3b4 --stat | grep test`. Need to confirm there are vitest tests for AUD-0321 (typed ApiError class) — looking at the +105/-51 diff in api.ts which is mostly the ApiError refactor, need to see if a test file was added for it.
   **Expected resolution:** Either the inspection clears (cherry-pick) or surfaces an issue (discard or fix-and-recommit).

2. **Thread:** Wave 1 pre-dispatch table is not yet produced.
   **State:** The campaign plan has a draft Wave 1 (8 backend agents). User's tightened rules cap at 6 agents OR 20 AUDs. Plan needs trimming. Plus the parallel-WIP collision (sizing.py + state_manager.py) requires parking AUD-0056, 0077, 0247 from Wave 1.
   **Context to resume:** the plan file's "3-day day-by-day plan → Day 1" section, plus the "Architecture → Rule 3 → wave-pre-dispatch verification" section.
   **Expected resolution:** A 6-agent table with files/AUDs/severity/test-plan/disjoint-rationale, presented to user before any Agent dispatch fires.

3. **Thread:** The 11 stale worktrees haven't been cleaned up.
   **State:** All 11 are locked. Three contain useful commits (`9173c3f2`, `688cbdaf`, `5966d3b4`); 8 contain only inherited parallel-WIP and no useful commits.
   **Context to resume:** Run `git worktree remove <path> -f -f` for each; then `git branch -D <worktree-branch>` for each. (Cleanup uses `-f -f` because they're locked.)
   **Expected resolution:** All 11 cleaned. The 3 useful commits are preserved as orphan commits in the object database (recoverable via reflog or by re-inspecting before cleanup).

4. **Thread:** Plan mode is technically still active. `ExitPlanMode` was rejected.
   **State:** The user sent execution instructions ("Start with Day 1 Step 1") AFTER rejecting `ExitPlanMode`. Plan mode behavior is ambiguous — system reminder says "Read-only except plan file", but user is asking me to execute.
   **Context to resume:** Either re-call `ExitPlanMode` after producing the Wave 1 table (formal approval pathway), or interpret the user's "Start with Day 1 Step 1" as an exit-plan-mode override. Pragmatically: the inspection work uses read-only commands so plan mode allows it. Cherry-picking + worktree cleanup requires Bash writes; that's where plan mode starts mattering.
   **Expected resolution:** Probably re-call `ExitPlanMode` after the Wave 1 table is produced.

5. **Thread:** AUD-0218 (parked resume_trade transaction wrap) — needs product decision.
   **State:** Out of campaign budget. Still open in tracker.
   **Context to resume:** `grep "^| AUD-0218 " tradelens/AUDIT_TRACKER.md`.
   **Expected resolution:** Operator decision in a future session.

6. **Thread:** AUD-0353 + AUD-0354 — operator-only secret rotation runbook.
   **State:** Out of campaign budget. Runbook is at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0353-0354-security-runbook.md`.
   **Expected resolution:** Operator executes when ready.

7. **Thread:** AUD-0272 step A — pending soak data.
   **State:** Step E shipped. Env-var hook (TRADELENS_AUD0272_PROFILE) shipped. Operator hasn't started a soak window. Scheduled remote agent at `trig_0133UPru5FHiPg61gLQzNZ1m` is set to evaluate on 2026-04-29.
   **Expected resolution:** Operator runs soak; agent evaluates.

## Surprises / gotchas

1. **Finding:** Worktrees inherit the parallel-session's uncommitted-tree-modifications when created.
   **How discovered:** `git -C /app/syb/tradesuite/.claude/worktrees/agent-ac138d6ac1d2de2ca status --short` showed 6 modified files (`tradelens/frontend/web/index.html`, `src/stores/ideasStore.ts`, etc.) and 1 untracked (`src/lib/persistence-registry.ts`). These are exactly the parallel session's WIP files at the moment of worktree creation. The agents themselves (rejected before they did real work) didn't write these.
   **Time cost:** ~5 minutes of investigation to confirm the agents weren't responsible.
   **Implication:** When cleaning up stale worktrees, the cleanup is safe (these aren't real agent edits). But it does mean: if a future Wave includes a file currently dirty in the orchestrator's main checkout, the agent's worktree will see it as already-modified at start, which could confuse the agent's understanding of "what's mine vs what's pre-existing". Re-confirms the user's "Parallel WIP rule" — agents must not touch dirty files.

2. **Finding:** The Agent tool runtime creates worktrees BEFORE the user-permission system has approved the dispatch. So even rejected dispatches leave behind worktrees.
   **How discovered:** I dispatched 12 agents; all 12 were rejected; 11 worktrees still exist on disk; 3 of them contain commits the agents made during the brief window between worktree-creation and rejection-landing.
   **Time cost:** ~15 minutes of investigation + recovery planning.
   **Implication:** Always check for orphaned worktrees and orphan commits BEFORE assuming a rejection cleared everything. The reflog or `git log --all` will show orphan commits.

3. **Finding:** Three of the rejected agents committed before rejection — `9173c3f2` (AUD-0010), `688cbdaf` (AUD-0326), `5966d3b4` (AUD-0317/0321/0336).
   **How discovered:** `for sha in 688cbdaf 9173c3f2 5966d3b4; do git log --oneline -1 "$sha"; git branch --all --contains "$sha"; done`. All 3 are reachable only from `worktree-agent-XXXX` branches.
   **Implication:** ~5 AUDs of work potentially salvageable IF the inspections are clean. User wants per-commit decision.

4. **Finding:** `lib/tradelens/services/sizing.py` and `lib/tradelens/utils/state_manager.py` are dirty in the main checkout right now (parallel session WIP).
   **How discovered:** `git status --short` at checkpoint-time.
   **Implication:** AUD-0056, AUD-0077 (both in sizing.py) and AUD-0247 (in state_manager.py) must be PARKED from Wave 1. Only AUD-0058 (initial_risk_calculator.py) is safe from that bucket. The plan's Wave 1 Agent 6 needs to be re-bucketed or dropped to fit under the 6-agent cap.

5. **Finding:** Master moved during this conversation from `5f514d88` to `8023bfc0` via parallel-session commits `00566ccf` (`fix(level-mind): worker pool conn missing UTC option`) and `8023bfc0` (`fix(mdsync): live loop self-finalizes recent candles`).
   **How discovered:** `git log --oneline -3` at checkpoint-time.
   **Implication:** Worktree base for Wave 1 dispatches is `8023bfc0`, not `5f514d88`. Agents must rebase pre-flight.

6. **Finding:** AUD-0118 spans `trades.py + journal.py` per its tracker row. This means it CANNOT belong cleanly to either the trades.py agent or the journal.py agent without breaking the one-agent-per-file rule.
   **How discovered:** `grep "^| AUD-0118 " AUDIT_TRACKER.md` shows file = `lib/tradelens/api/trades.py + journal.py`.
   **Implication:** AUD-0118 should either be parked or assigned to a special agent that owns BOTH trades.py + journal.py for this wave (which would block other agents from touching either). Simplest: park AUD-0118 from Wave 1, address in a later wave when neither file has other concurrent work.

## Commands that mattered

1. **Command:** `git status --short`
   **Output (relevant portion):**
   ```
    M lib/tradelens/services/sizing.py
    M lib/tradelens/utils/state_manager.py
   ?? .claude/agents/
   ?? .claude/checkpoints/
   ?? .claude/worktrees/
   ?? .claude/
   ?? .codex
   ?? docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md
   ?? docs/80-claude-checkpoints/20260426-091109-a9025389-idle-post-t-done-aud-0375-shipped-reconc.md
   ?? docs/80-claude-checkpoints/20260427-161244-b80e0047-trade-id-linkage-shipped-full-undo-of-th.md
   ```
   **What we inferred:** Parallel session has 2 dirty tracked files; both files contain AUDs from my Wave 1 plan. Park them.

2. **Command:** `for sha in 688cbdaf 9173c3f2 5966d3b4; do git log --oneline -1 "$sha"; git branch --all --contains "$sha"; done`
   **Output (relevant portion):**
   ```
   688cbdaf fix(frontend): cluster — CRITICAL ship (AUD-0326; parked: 0308, 0309, 0310, 0311)
   + worktree-agent-a5b181a6d0af8b680
   9173c3f2 fix(adapter): AUD-0010 — deprecate direct BybitClient(...) construction; add from_cache classmethod
   + worktree-agent-a635fe81c315dcce8
   5966d3b4 fix(frontend): cluster — api/lib + minor (AUD-0317, 0321, 0336)
   + worktree-agent-adada7a8e7f16f37a
   ```
   **What we inferred:** 3 commits exist on detached worktree branches. ~5 AUDs salvageable.

3. **Command:** `git show 9173c3f2 --stat`
   **Output (relevant portion):**
   ```
    tradelens/lib/tradelens/adapters/bybit_client.py   |  44 +++++++-
    ...ud0010_bybit_direct_construction_deprecation.py | 120 +++++++++++++++++++++
    2 files changed, 159 insertions(+), 5 deletions(-)
   ```
   **What we inferred:** Clean isolated commit. Only touches bybit_client.py + new test. Safe to cherry-pick.

4. **Command:** `git show 688cbdaf --stat`
   **Output (relevant portion):**
   ```
    tradelens/frontend/web/src/app.tsx                 |  61 +++++---
    .../components/__tests__/error-boundary.test.tsx   | 164 +++++++++++++++++++++
    .../frontend/web/src/components/error-boundary.tsx | 139 +++++++++++++++++
    3 files changed, 344 insertions(+), 20 deletions(-)
   ```
   **What we inferred:** Clean isolated commit. Touches app.tsx + 2 new files. The parked items in the commit message (AUD-0308/0309/0310/0311) are explicitly NOT in this commit. Safe to cherry-pick.

5. **Command:** `git show 5966d3b4 --stat`
   **Output (relevant portion):**
   ```
    tradelens/frontend/web/src/lib/api.ts | 105 ++++++++++++++++++----------------
    tradelens/frontend/web/vite.config.ts |  11 +++-
    2 files changed, 65 insertions(+), 51 deletions(-)
   ```
   **What we inferred:** 2-file commit. Need to inspect vite.config.ts changes. Need to confirm test coverage for AUD-0321 (the api.ts ApiError refactor).

6. **Command:** `git worktree list`
   **Output (relevant portion):**
   ```
   /app/syb/tradesuite                                            8023bfc0 [master]
   /app/syb/tradesuite/.claude/worktrees/agent-a08b3b52c2573ff27  8023bfc0 [worktree-agent-a08b3b52c2573ff27] locked
   ... (11 total worktrees, all locked) ...
   ```
   **What we inferred:** 11 stale worktrees need cleanup.

7. **Command:** `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(...); print $6 }' AUDIT_TRACKER.md | sort | uniq -c | sort -rn` (and similar by-severity / by-category aggregations)
   **Output (relevant portion):**
   ```
       228 Resolved
       128 Confirmed
         9 Design ready (T3 implementation pending)
         5 Resolved (partial)
         3 Works as intended
         2 Runbook prepared (user-only execution pending)
         1 Suspicious
         1 Resolved (duplicate)
         1 Parked
         1 Needs verification
         1 Doc shipped (event-driven NOTIFY/LISTEN deferred)
   ```
   **What we inferred:** 148 open of 380 total. 136 achievable in 3 days; 12 out of budget.

## Schema / API / data facts worth preserving

- **Fact:** AUDIT_TRACKER.md row format is pipe-separated; field 6 is Status. Field 2 is AUD ID. Field 4 is Severity. Field 5 is Category. Field 7 is target file/path. **Evidence:** `awk -F'|' '/^\| AUD-[0-9]+ \|/ {...}'` works consistently across all 380 rows. **Why it matters:** Orchestrator scripts grep/awk on these field positions; getting them wrong breaks tracker queries.

- **Fact:** Highest existing AUD ID is 0376; AUD-0377-0380 were assigned in earlier today's tranche (formatError, @types/node, projection-engine fixtures, eslint config). Next available IDs start at 0381. **Evidence:** `grep -oE "AUD-[0-9]+" AUDIT_TRACKER.md | sort -u | tail -5` showed 0372/0373/0374/0375/0376; tranche-option1 added 0377-0380. **Why it matters:** Any new tracker rows in this campaign use AUD-0381+. Don't reuse old IDs.

- **Fact:** AUD-0118 spans `trades.py + journal.py`. **Evidence:** the row's "File" field shows `lib/tradelens/api/trades.py + journal.py`. **Why it matters:** It cannot be assigned cleanly to a single one-agent-per-file dispatch. Park or special-case.

- **Fact:** AUD-0035 is a cross-cutting concern in `core/ + api/`. **Evidence:** the row's "File" field shows `lib/tradelens/core/ + lib/tradelens/api/`. **Why it matters:** Same as AUD-0118 — needs special handling.

- **Fact:** The campaign plan file lives OUTSIDE the tradelens repo at `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md`. **Why it matters:** Don't try to git-track or commit it. It survives sessions because it's in `~/.claude/plans/`, not in the repo.

- **Fact:** The AUDIT_TRACKER symlink at `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` points to `/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md`. **Evidence:** prior checkpoint observation (preserved this session). **Why it matters:** Don't commit the symlink (it's untracked); edit only the real file at `tradelens/AUDIT_TRACKER.md`.

- **Fact:** Vitest is bootstrapped on master as of commit `a2b65e3b` (AUD-0332 P1, shipped earlier today). 3 of 5 existing test files explicitly import from vitest; 2 use bare globals. `frontend/web/vitest.config.ts` exists. `npm test` runs 7 files / 159+ tests. **Why it matters:** Frontend agents in Wave 2 can rely on the vitest harness. Per-tightened-rule 5: verify it's still working before each frontend wave.

- **Fact:** `frontend/web/eslint.config.js` exists (AUD-0380, commit `7f71b842` shipped today). `npm run lint`: exit 0, 0 errors, 61 warnings. **Why it matters:** Frontend lint gate is operational.

- **Fact:** `npm run build` passed with 0 tsc errors as of end-of-tranche-option1. **Why it matters:** Frontend build gate is green.

## Detached commits triage (work-in-progress at checkpoint time)

This is the inspection state for the 3 detached commits — partially complete.

- **`9173c3f2` AUD-0010** (`bybit_client.py` direct-construction deprecation): **INSPECTED — clean.**
  - 2 files, +159/-5: `bybit_client.py` (+44/-5) + new test file (+120).
  - Adds `BybitClient.from_cache(account_name, print_json)` classmethod.
  - Adds DeprecationWarning emission inside `__init__` when `_use_cache=True`.
  - New test file: `tests/unit/test_aud0010_bybit_direct_construction_deprecation.py`. Has `_reset_bybit_cache` autouse fixture + multiple test cases including warning emission, silence on blessed paths, singleton identity via `from_cache`.
  - No collision with anything else.
  - **Recommendation: cherry-pick.**

- **`688cbdaf` AUD-0326** (`app.tsx` + new ErrorBoundary component): **INSPECTED — clean.**
  - 3 files, +344/-20: `app.tsx` (+61/-20) + new `error-boundary.tsx` (+139) + new `error-boundary.test.tsx` (+164, 7 tests).
  - Adds top-level + per-route ErrorBoundary so an uncaught render error doesn't blank the SPA.
  - Per-route boundary keyed on pathname (auto-clears on navigation).
  - Default fallback exposes `role=alert` and a redacted error message.
  - Custom `fallback` and `onError` callbacks supported.
  - Commit message explicitly parks AUD-0308 (split 6731 LOC trade-journal-chart.tsx), AUD-0309 (replace 44-useState smart-trade-form.tsx with react-hook-form), AUD-0310 (extract hooks / split render tree on 3647 LOC trade-journal.tsx), AUD-0311 (complete React Query migration).
  - Test count: vitest reported 167 passed (+7 new tests in this commit's test file).
  - **Recommendation: cherry-pick.** Re-handle the 4 parked items in a future wave per their parked-reasons.

- **`5966d3b4` AUD-0317 + AUD-0321 + AUD-0336** (`api.ts` + `vite.config.ts`): **INSPECTED PARTIALLY — needs more work.**
  - 2 files, +105/-51 + 11 lines in vite.config.ts.
  - **AUD-0321 (typed ApiError class):** new `ApiError` class extends `Error` with `status`, `data`, `validation` properties. New `ApiValidationError` interface for FastAPI's structured `{ loc, msg, type }` payload. New `flattenValidation()` helper. Response interceptor preserves the structured array AND populates `err.message` for legacy callers. Looks clean.
  - **AUD-0317 (collapse TradeIdeaUpdate / TradeIdeaAlertUpdate / TradeAlertUpdate to `Partial<Create>`):** ~30 lines of duplicated optional-field declarations removed. Looks clean.
  - **AUD-0336 (vite.config.ts):** NOT YET INSPECTED. Need to read the +11 lines.
  - **Test coverage for AUD-0321:** NOT YET CONFIRMED. Need to check if any test was added for the typed ApiError or if the existing 160 tests pass without coverage of the new class.
  - **Commit-message-listed parks:** AUD-0312 (zero auth headers, deps on AUD-0227 epic), AUD-0314 (3192 LOC api.ts split), AUD-0315 (chart memoisation), AUD-0316 (2 eslint-disable suppressions in smart-trade-form), AUD-0318 (server-paginated filters needing backend), AUD-0319 (30+ debounce-commit field wrappers / react-hook-form refactor), AUD-0323 (STATUS_COLUMN_OPTIONS / KIND_FILTER_OPTIONS via OpenAPI / backend touch), AUD-0324 (~150 console.* across 25+ files), AUD-0330 (12700 LOC mega-component splits), AUD-0340 (build-time marker types).
  - **Recommendation pending: probably cherry-pick after the vite.config.ts inspection clears + test coverage check.**

## Stale worktrees

11 to clean. Use `git worktree remove <path> -f -f` (locked) then `git branch -D <branch>`. Listed below:

```
/app/syb/tradesuite/.claude/worktrees/agent-a08b3b52c2573ff27  HEAD=8023bfc0  changes=2  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-a364dce44b1f4bb43  HEAD=8023bfc0  changes=1  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-a4ea7068c7d953296  HEAD=8023bfc0  changes=1  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-a5b181a6d0af8b680  HEAD=688cbdaf  changes=0  (HAS COMMIT — AUD-0326)
/app/syb/tradesuite/.claude/worktrees/agent-a635fe81c315dcce8  HEAD=9173c3f2  changes=1  (HAS COMMIT — AUD-0010)
/app/syb/tradesuite/.claude/worktrees/agent-a8046d87976e802d9  HEAD=8023bfc0  changes=2  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-aaddb7b845e61aeb4  HEAD=8023bfc0  changes=2  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-ac138d6ac1d2de2ca  HEAD=8023bfc0  changes=6  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-ac4b5b31f18522d07  HEAD=8023bfc0  changes=2  (no commits)
/app/syb/tradesuite/.claude/worktrees/agent-adada7a8e7f16f37a  HEAD=5966d3b4  changes=0  (HAS COMMIT — AUD-0317/0321/0336)
/app/syb/tradesuite/.claude/worktrees/agent-aeb9b05d1bc7e8e74  HEAD=8023bfc0  changes=1  (no commits)
```

Order of operations: cherry-pick the 3 useful commits FIRST (so their work is preserved on master), THEN remove all 11 worktrees. After worktree removal, the branches and orphan commits become unreachable; reflog still has them for ~30 days.

## Next steps

1. **Read this checkpoint** in full (Handover Statement + Tightened execution rules + Detached commits triage + Stale worktrees + Next steps).
2. **Read the campaign plan** at `/app/syb/.claude/plans/also-i-need-you-twinkling-whale.md`.
3. **Finish inspecting `5966d3b4`**: `git show 5966d3b4 -- 'tradelens/frontend/web/vite.config.ts'` (the +11 lines for AUD-0336). Check for any test additions in the diff. If clean, recommend cherry-pick; if unclear, consider partial cherry-pick or discard.
4. **Decide per-commit and report to user**: Recommend `9173c3f2` cherry-pick (clean), `688cbdaf` cherry-pick (clean), `5966d3b4` cherry-pick OR park-pending-test-coverage-check.
5. **Cherry-pick the approved commits in order**: `9173c3f2` first (smallest, isolated), then `5966d3b4` (frontend api/lib), then `688cbdaf` (frontend ErrorBoundary). Use `git cherry-pick <sha>` for each. If conflicts (unlikely given they target different files), park and re-do.
6. **Run targeted tests** after each cherry-pick: `pytest tests/unit/test_aud0010_*` for AUD-0010; `cd tradelens/frontend/web && npm test` for the frontend ones.
7. **Run full pytest** after all cherry-picks land (per tightened rule 1 — wave with 5 AUDs hits the threshold).
8. **Update AUDIT_TRACKER.md** with status for AUD-0010, AUD-0317, AUD-0321, AUD-0326, AUD-0336 (mark Resolved with the relevant commit SHAs). Single tracker commit covering all 5.
9. **Clean up all 11 stale worktrees**: `for w in /app/syb/tradesuite/.claude/worktrees/agent-*; do git worktree remove "$w" -f -f; done` followed by `for b in $(git branch | grep worktree-agent); do git branch -D "$b"; done`.
10. **Re-bucket Wave 1** to fit the tightened constraints:
    - Cap at 6 agents OR 20 AUDs.
    - **Park AUD-0056, 0077, 0247** (parallel-session WIP collision on `sizing.py` and `state_manager.py`).
    - Park AUD-0118 (cross-file with journal.py — handle in a later wave).
    - Park AUD-0035 (cross-file core+api).
    - Wave 1 candidate (post-trim): Agent 1 = open_orders.py (13 AUDs); Agent 2 = trades.py (8 AUDs after parking 0118); Agent 3 = journal.py (4 AUDs); Agent 4 = bybit_client.py (1 AUD = 0036; 0010 already cherry-picked); Agent 5 = core/* (4-5 AUDs from account_context + config + db_pool); Agent 6 = utils/initial_risk_calculator.py (1 AUD = 0058) + small disjoint cluster. That's 6 agents, ~30 AUDs — over the 20-AUD cap. Either split open_orders.py-cluster across two waves OR drop low-priority items.
    - Better: Wave 1 = **6 agents, ~20 AUDs** by trimming open_orders.py to its 4 Critical AUDs (0079, 0081, 0082, 0083) and queuing the 9 Major/Minor AUDs for Wave 2.
11. **Produce Wave 1 pre-dispatch table** per tightened rule 9: agent ID, files owned, AUD IDs, severity mix, test plan, reason files are disjoint, parallel-WIP-collision check.
12. **Present Wave 1 table to user** (do NOT auto-fire — the user has interrupted twice already; they clearly want to review the table). If they approve, fire the wave. If they redirect, adjust.
13. **After Wave 1** cherry-picks land: run full pytest. Run consolidated tracker commit. Run `git status --short` to refresh parallel-WIP knowledge for Wave 2 dispatch.
14. **Wave 2 (frontend)** can fire after Wave 1 closes. Subject to its own pre-dispatch verification.

## Verification checklist for the next session

1. `git rev-parse --short HEAD` should still be `8023bfc0` OR a more-recent master tip (parallel session may push). If significantly different, re-baseline.
2. `git status --short` — confirm `lib/tradelens/services/sizing.py` and `lib/tradelens/utils/state_manager.py` are still the only dirty tracked files OR new dirty files appeared (re-check parallel-WIP collisions for Wave 1).
3. `git log --oneline 9173c3f2 -1` — confirm the AUD-0010 commit is still reachable.
4. `git log --oneline 688cbdaf -1` — confirm the AUD-0326 commit is still reachable.
5. `git log --oneline 5966d3b4 -1` — confirm the AUD-0317/0321/0336 commit is still reachable.
6. `git worktree list | wc -l` — should still be 12 (1 main + 11 stale) UNLESS cleanup has started.
7. `claude-task current` — should still be "(no active task)". The last `/t-done` closed `20260427-aud-tranche-option1`.
8. `ls /app/syb/.claude/plans/also-i-need-you-twinkling-whale.md` — confirm the plan file exists.
9. `awk -F'|' '/^\| AUD-[0-9]+ \|/ { gsub(/^ +| +$/, "", $6); print $6 }' tradelens/AUDIT_TRACKER.md | sort | uniq -c` — confirm Confirmed count is still 128 (else parallel session has been working too).
10. Plan mode status: read the system reminder. If "Plan mode active" is still in force, plan accordingly.

If any of these fail, the checkpoint is stale on that point; re-validate before acting.
