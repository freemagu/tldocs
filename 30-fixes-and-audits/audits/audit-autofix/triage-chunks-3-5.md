# Audit autofix triage — chunks 3, 4, 5

**Generated:** 2026-04-24
**Scope:** AUD-0078 through AUD-0180 (103 findings across chunks 3, 4, 5)
**Chunk 3** = `lib/tradelens/api/open_orders.py` (AUD-0078 — AUD-0110, 33 findings)
**Chunk 4** = `lib/tradelens/api/trades.py` + `lib/tradelens/api/journal.py` (AUD-0111 — AUD-0146, 36 findings)
**Chunk 5** = Pipeline scripts `refresh_order_leg_live.py`, `refresh_order_leg_hist.py`, `refresh_trade_journal.py` (AUD-0147 — AUD-0180, 34 findings)
**Purpose:** Classify into T1 (autofix) / T2 (human-review) / T3 (architectural) / T4 (closed).
**Process:** User reviews this file. On approval, Step 2 executes T1 items autonomously.

## Counts

| Tier | Count | Meaning |
|---|---|---|
| **T1** | 12 | Ready for autonomous fix |
| **T2** | 66 | Needs a one-page proposal, then user decides |
| **T3** | 23 | Architectural — parked for dedicated tasks |
| **T4** | 2 | Already Resolved / Works-as-intended |
| **Total** | 103 | |

T1 covers ~12% of chunks 3-5 (vs 31% in pilot chunks 1-2). Lower ratio is expected: these chunks
are dominated by `api/trades.py`, `api/open_orders.py`, and pipeline writers — all money-moving or
primary-writer paths where the T1 bar is much higher. Chunk 5 has lots of "critical / security"
f-string SQL findings that individually look mechanical but are actually coupled (AUD-0147,
AUD-0148, AUD-0149, AUD-0157, AUD-0160, AUD-0174 all touch the same few files and often the same
few functions), and landing them one-at-a-time risks the partial-fix inconsistency class of bug.

---

## T1 — Autonomous fix queue (12)

Executed in this order. Each gets pre-test, fix, regression test, post-test, commit. Grouped by
file so same-file work shares a worktree.

### lib/tradelens/api/open_orders.py (money-moving — T1 items are strictly additive or doc-only)

- **AUD-0107** Minor/Cleanup — `get_breakeven_threshold` re-reads config every
  `determine_leg_type` call. Wrap with `functools.lru_cache(maxsize=1)` or compute once at
  module import. Strictly additive perf improvement, no behavior change. Grep verified 2 call
  sites (`open_orders.py:2618 def`, `open_orders.py:2653 call`); no external callers.

- **AUD-0110** Minor/Cleanup — Docstring sync: `OpenOrdersListResponse.health_summary`
  docstring at line 230 says "counts by health level" with 4-level enumeration in
  `OpenOrderItem.health_level` at line 220, but `health_counts` in `get_open_orders` at line
  435 has 5 keys (adds `seeded`). Pure doc fix — add `'seeded'` to the level enumeration in
  the comment at line 220. Grep verified: `compute_health_level` at line 300 returns `seeded`
  via the `SEEDED_TRADE` branch.

### lib/tradelens/api/journal.py (fewer T1s — very large file, most changes affect multi-module paths)

- **AUD-0133** Minor/Duplication — Delete `detect_snapshot_source` and
  `compute_snapshot_view_url` backward-compat aliases at journal.py:371 and 397. Grep verified
  zero external references anywhere in `lib/`, `bin/`, `tests/`, `frontend/` — all call sites
  use the canonical `detect_screenshot_source` / `compute_screenshot_view_url` names. The
  `Snapshot = Screenshot` alias at line 218 is in the same category; will also delete after
  grep-verifying no external `Snapshot` imports from `tradelens.api.journal` (checked — zero
  matches outside tests, and tests use `Screenshot` not `Snapshot`).

- **AUD-0139** Minor/Bug — Add `LIMIT 1` to the `ORDER BY created_at DESC` + `fetchone()`
  query in `create_execution_result_note_on_idea`. Same class as AUD-0052 already batched in
  chunks 1-2. Mechanical; trades.py:131-138. Parameterized query, no SQL-injection concern.

### bin/pipeline/refresh_order_leg_hist.py (sibling is already parameterized — safe pattern reuse)

- **AUD-0173** Minor/Duplication — Parameterize 4 f-string SELECT-snapshot sites in
  `refresh_order_leg_hist.py` (lines 269, 429, 896, 908, 1058). The rest of the file already
  uses `%s`, so fix pattern is trivial and a proven pattern exists in the same file. Grep
  verified: most cursor.executes already use `%s`, these sites are outliers. Writer-path but
  sibling-proven. **Note:** chunk 5 has a cluster of f-string SQL findings (AUD-0147, 0148,
  0149, 0157, 0160, 0174, 0173) — only 0173 is T1 because it's the only one where the fix
  pattern is fully-proven in the same file and doesn't cross the write-boundary of a
  primary-writer function.

### lib/tradelens/utils/pipeline_lock.py (dead code, grep-verified)

- **AUD-0151** Critical/Dead Code — Delete `lib/tradelens/utils/pipeline_lock.py` entirely.
  Grep verified: zero callers outside the file itself (`grep -r pipeline_lock
  /app/syb/tradesuite/tradelens/` returns only the file's internal self-references at lines
  28, 54, 99). The actual locking happens in `bin/pipeline/lock_step.sh` (shell flock). The
  audit finding's alternative ("wire up to all Python invocations") is T2/T3 design work
  because API-triggered subprocess spawns (AUD-0078, AUD-0119) bypass the shell wrapper
  — but the **module itself** is dead today and safe to delete. Note: AUD-0175 flags the
  hardcoded path in both `lock_step.sh` AND `pipeline_lock.py` — once the latter is deleted,
  AUD-0175 collapses to a one-file env-var fix (marked T1 below).

### bin/pipeline/refresh_order_leg_live.py (narrow T1 additive fixes only — this is the primary-writer path AUD-0147 overhauls)

- **AUD-0172** Minor/Bug — Replace `str(round(leg['trigger_price'], 6))` with
  `Decimal.quantize` at line 2245. Float → Decimal fix per AUD-0075 rule. Single line. Must
  handle both float and Decimal inputs (grep showed `leg['trigger_price']` can be either —
  from `float(trigger_price)` at line 697 or from `row[...]` at line 2146). Fix:
  `Decimal(str(leg['trigger_price'])).quantize(Decimal('0.000001'))`. Covered by existing
  pipeline smoke tests. **Sequencing note:** lands cleanly before AUD-0147 (full
  parameterization) because it only touches the pre-INSERT formatting of a single field.

- **AUD-0180** Minor/Cleanup — Change `reduce_only = f"'{leg['reduce_only']}'" if
  leg['reduce_only'] else 'NULL'` at line 2235 to `is not None` check. Same zero-truthiness
  class as AUD-0152. Single-line change. Does NOT address AUD-0147's broader f-string SQL
  problem — this finding is specifically about the boolean truthiness, not the SQL shape.

### bin/pipeline/refresh_trade_journal.py (narrow T1 only — large file, most findings are T2+)

- **AUD-0177** Minor/Suspicious — `diagnose_orphan_legs` diagnostic function. Tracker status
  is "Needs verification". Grep-verified: function defined at line 3053, called at line 3446.
  The finding is "fix sessionization; fail pipeline on orphans" — that's a T3 design question.
  But a narrower T1 interpretation is: add a DEBUG-level summary log inside the function so
  the diagnostic count is visible in pipeline runs (strictly additive, no behavior change).
  **If user prefers not to interpret-narrow, demote this to T2.**

### bin/pipeline/lock_step.sh (config — hardcoded path)

- **AUD-0175** Minor/Config — Replace hardcoded `/app/syb/tradesuite/tradelens/locks/` path
  in `lock_step.sh:22` with env var (e.g. `LOCK_DIR="${TLHOME:-/app/syb/tradesuite/tradelens}/locks"`).
  `pipeline_lock.py` has the same issue (line 19) and will be deleted per AUD-0151, so the
  config fix collapses to one file. Single-line, strictly additive.

### lib/tradelens/api/trades.py + journal.py (shared between files)

- **AUD-0132** Minor/Bug — `parse_fees_json` in journal.py:334 swallows only
  `JSONDecodeError`/`TypeError`. Broaden to `Exception` with a WARNING log (strictly
  additive diagnostics, no control-flow change for the already-caught cases). Note: tracker
  claims function lives in `trades.py` but grep shows it's in `journal.py:334`, callers at
  923 and 1638. Behavior stays "return None on error" — the fix only adds logging visibility.
  Regression test: feed malformed/oversized input, assert None returned and warning emitted.

---

## T2 — One-page proposal queue (66)

These need a human call. For each, I'll produce a short proposal and wait.

### api/open_orders.py (chunk 3)

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0078** | Critical/Perf | Architectural: "in-process refresh call OR FastAPI BackgroundTasks" — two reasonable answers, different blast radiuses; refresh_order_data callers across 6 sites (771, 1445, 1726, 2081, 2511, 3741) |
| **AUD-0079** | Critical/Perf | bulk_cancel — Bybit batch endpoint not in BybitClient (grep: no cancel_batch method); adapter extension is design work |
| **AUD-0080** | Critical/Bug | Ticker-failure policy — "refuse on failure vs explicit override" is a design decision; changes user-visible 5xx semantics |
| **AUD-0081** | Critical/Reliability | Adds AppLock namespace to 6+ mutation paths — changes concurrency semantics, needs deadlock analysis |
| **AUD-0082** | Critical/Reliability | orderLinkId auto-generation — prerequisite for AUD-0002 retry policy (which is T3); coordinate with chunks 1 parent |
| **AUD-0083** | Critical/Reliability | Multi-table transactions — changes DB lifecycle; autocommit=True assumption is codebase-wide (AUD-0118, AUD-0150 are same class) |
| **AUD-0084** | Critical/Security | 8 call sites changing HTTP 500 detail — each needs a caller-aware sanitization policy |
| **AUD-0086** | Major/Perf | TTL cache for instrument info — cache invalidation policy is design; hot-path change |
| **AUD-0087** | Major/Arch | Pass `bybit` through `get_tick_size` — signature change across 11 callers (grep verified) |
| **AUD-0088** | Major/Bug | Full Decimal pipeline in `calculate_quantity` — money-moving math, potential for subtle off-by-one under different callers |
| **AUD-0089** | Major/Bug | Take `side` and `leg_type` as inputs to `calc_trigger_direction` — 6+ callers grep-verified across open_orders.py and suspend.py; duplicates AUD-0122 relationship |
| **AUD-0090** | Major/Cleanup | BybitClient lifecycle refactor across 4 amend paths — caller-pattern change; behavior-neutral but touches every mutation |
| **AUD-0091** | Major/Bug | `check_existing_stop` classifier change — treats trailing_tl/be/tl/be as stop-equivalent; reporting pipeline will see row-label shift |
| **AUD-0092** | Major/Bug | "Require explicit leg_type from caller" — changes trades.py and journal.py caller signatures |
| **AUD-0094** | Major/Bug | Unify `position_after` logic between `preview_amend_order` and `preview_order` — changes UI-visible "after" values consistency |
| **AUD-0095** | Major/Arch | `qty=0` sentinel → `close_entire: bool` — API signature change with 3 special-case sites |
| **AUD-0097** | Major/Cleanup | `_upsert_vwap_link` dynamic SET — current code uses %s for values but mixes literal NULL/CURRENT_TIMESTAMP; refactor touches VWAP write path (money-moving adjacent) |
| **AUD-0098** | Major/Reliability | "Make local DB primary writer on exchange success" — flips subprocess refresh semantics; interacts with AUD-0078 |
| **AUD-0099** | Minor/Cleanup | `missing_trade` filter branch: grep verified frontend `api.ts:1601` documents `missing_trade` as valid value; removing would change filter behavior from "always empty" to "return all" — UX regression risk |
| **AUD-0100** | Minor/Cleanup | `reduce_only` string bool migration — DB schema change (requires etc/schema.md update) |
| **AUD-0101** | Minor/Bug | `_price_decimals` Decimal-based inspection — changes precision-display semantics used at 2 sites (1049, 3172) |
| **AUD-0102** | Minor/Security | Amend failure message sanitization — same class as AUD-0084, 4 sites |
| **AUD-0103** | Minor/Bug | Decimal compare in `convert_to_limit` — changes money-moving validation arithmetic |
| **AUD-0105** | Minor/Bug | `convert_to_limit` ticker safety check — adds pre-placement check; new 4xx failure mode for users |
| **AUD-0106** | Minor/Reliability | "Raise on unknown instrument" — changes failure mode for get_qty_step/get_tick_size; hit by every request |
| **AUD-0108** | Minor/Dup | Extract view for open_orders list+count — changes SQL used by polled UI list endpoint |
| **AUD-0109** | Minor/Cleanup | AmendOrderRequest validation tightening — no-op amend currently succeeds; tightening is user-visible 4xx |

### api/trades.py + api/journal.py (chunk 4)

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0111** | Critical/Arch | Redis or atomic preview+submit — multi-worker inconsistency design decision |
| **AUD-0112** | Critical/Security | Submit authz — bind preview to user/account requires user-identity model (currently absent) |
| **AUD-0113** | Critical/Security | Whitelist submit_trade_json fields OR merge with submit_trade — design-level call with behavior change |
| **AUD-0115** | Critical/Arch | Route `_submit_single_order_to_bybit` and `submit_trade` SL through typed adapters — bypasses `_request` private use; coordinates with AUD-0006/AUD-0036 |
| **AUD-0117** | Critical/Perf | Async/WebSocket replacement for `time.sleep(0.5)` TP recalc — control-flow change in submit hot path |
| **AUD-0118** | Major/Reliability | Transactions across 9,189 LOC — codebase-wide lifecycle change |
| **AUD-0119** | Major/Perf | FastAPI BackgroundTasks vs queue — trigger_fast_track_refresh has 2 call sites; design question |
| **AUD-0120** | Major/Perf | `generate_execution_result_note` event-typed row per execution — schema semantics change (note row grows vs new row per call) |
| **AUD-0121** | Major/Bug | Move SL to post-entry step — changes submit_trade control flow in money-moving path |
| **AUD-0122** | Major/Dup | Single `calc_trigger_direction` helper — same refactor as AUD-0089, deduplicate sites across files |
| **AUD-0123** | Major/Cleanup | `_negate_str` Unicode flip readability — tuple-key rewrite may change subtle edge-case sort ordering that users have memorized |
| **AUD-0124** | Major/Perf | Single batched suspended-trades query — changes journal enrichment path; risk of subtle count-mismatch bugs |
| **AUD-0125** | Major/Perf | `market_summary` 8-10 queries → LATERAL JOIN or materialized view — SQL architecture decision |
| **AUD-0127** | Major/Arch | Unify submit_trade and submit_trade_json — same as AUD-0113 |
| **AUD-0128** | Major/Arch | Move leverage/risk-limit math to services/ — refactor with 2 call sites (1319 via ensure_leverage_for_position) |
| **AUD-0129** | Major/Cleanup | Dynamic WHERE builder or named-placeholder migration — touches journal.py:664-783 list query (polled) |
| **AUD-0131** | Minor/Cleanup | Evict preview cache on submit — coupled to AUD-0111; isolated fix masks the underlying design |
| **AUD-0134** | Minor/Dup | UNION live+hist price query — changes precedence semantics (live-first fallback → single UNION) |
| **AUD-0135** | Minor/Cleanup | `reader._conn` private access — needs public accessor in reader module; cross-module signature change |
| **AUD-0136** | Minor/Cleanup | `NoteEventType` enum — repeated across many SQL statements; changes module-import surface |
| **AUD-0137** | Minor/Cleanup | Split `JournalListItem` into base + enriched DTOs — API response shape change |
| **AUD-0138** | Minor/Cleanup | Generate `ALL_SORTABLE_FIELDS` from schema — cross-cutting (SQL_SORTABLE_FIELDS + PYTHON_SORTABLE_FIELDS live in same file but wire together many sort paths) |
| **AUD-0140** | Minor/Suspicious | 4 state-transition endpoints — tracker status "Needs verification"; deep-audit is per-endpoint work |
| **AUD-0142** | Minor/Suspicious | Leverage write idempotency — tracker status "Needs verification"; money-moving on submit |
| **AUD-0143** | Minor/Cleanup | Stable canonical default sort — UX-visible ordering |
| **AUD-0144** | Minor/Cleanup | Event type enum (duplicate AUD-0136 from journal side) |
| **AUD-0145** | Minor/Cleanup | Align active-status set between check_active_trade_conflict and get_journal_list — tracker flags "pending_entry absent in conflict check — valid or bug?" — design question |
| **AUD-0146** | Minor/Cleanup | Markdown formatter out of router — behavior-neutral but touches trades.py note generation |

### bin/pipeline/ (chunk 5)

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0147** | Critical/Security | Full parameterization of `upsert_legs_to_db` — primary writer path; 240+ lines of SQL (2116-2360); needs coordinated rewrite + regression tests |
| **AUD-0148** | Critical/Security | 45+ f-string SQL in refresh_trade_journal.py — same class, larger scope than AUD-0147 |
| **AUD-0149** | Critical/Security | `.replace()` SQL mutation in fetch_order_legs — requires rewriting WHERE construction |
| **AUD-0150** | Critical/Reliability | Per-session transactions in pipeline — cross-cutting lifecycle change |
| **AUD-0152** | Critical/Bug | `is not None` for realized_pnl, running_qty, peak_qty, exit_qty_sum, exit_notional_sum — schema semantics change (UI shows "$0.00" vs "N/A" post-fix) |
| **AUD-0153** | Critical/Bug | Empty-string category → NULL semantics — schema/data semantics change |
| **AUD-0154** | Major/Perf | INSERT ... ON CONFLICT DO UPDATE batch — primary-writer structural change |
| **AUD-0155** | Major/Arch | "leg_type IMMUTABLE" formal state machine — touches classification logic across 3 exceptions |
| **AUD-0156** | Major/Suspicious | ThreadPoolExecutor sharing — tracker "Needs verification"; concurrency invariant work |
| **AUD-0157** | Major/Security | f-string WHERE in fetch_order_legs session-conditions — coupled to AUD-0149 refactor |
| **AUD-0158** | Major/Dup | Unified fees-to-USD path — touches money-moving currency conversion; drift risk fix |
| **AUD-0160** | Major/Security | `symbols_in = ", ".join(...)` spot sessions — %s with tuple; simple pattern but inside reconcile path |
| **AUD-0161** | Major/Dead Code | `_validate_and_escape_order_id` dead-after-full-parameterization — **grep-verified one live caller at line 2687**, so NOT dead today; becomes dead only after AUD-0148 lands |
| **AUD-0162** | Major/Reliability | Single transaction for purge — same class as AUD-0150 |
| **AUD-0163** | Major/Reliability | Upsert cascade transaction — same class as AUD-0150 + AUD-0162 |
| **AUD-0164** | Major/Reliability | Fail loud on R-metric failure — changes pipeline error surface |
| **AUD-0165** | Major/Reliability | `"1=1" when empty` archive-all bug — hazardous fix; needs careful distinguish-empty-vs-failed logic |
| **AUD-0166** | Major/Reliability | Batch archive — primary-writer structural change |
| **AUD-0167** | Major/Perf | Pool / persistent daemon vs subprocess — coordinated with AUD-0078 |
| **AUD-0168** | Major/Arch | Shared base for pipeline scripts — 3-file refactor |
| **AUD-0169** | Major/Test Gap | Unit tests for pipeline scripts — test-creation work, structural |
| **AUD-0170** | Major/Arch | OrderClassifier decomposition — 6+ state maps; structural |
| **AUD-0171** | Major/Arch | Writer/reader split — cross-chunk (tracker explicitly marks "cross-chunk"); forced T2+ per triage rules |
| **AUD-0174** | Minor/Security | `"', '".join(current_order_ids)` — same class as AUD-0147, coupled refactor |
| **AUD-0176** | Minor/Cleanup | Merge three overlapping maps (seed_orders, seeded_entry_orders, smart_order_positions) — state-shape change on classifier |
| **AUD-0178** | Minor/Cleanup | Diff-based upsert_trade_leg_map — changes FK-cascade trigger behavior |
| **AUD-0179** | Minor/Cleanup | Explicit PRIORITY precedence + assert single match — changes silent-drop semantics to assertion failure |

---

## T3 — Architectural / deferred (23)

No attempt in this workstream. Each becomes a dedicated task.

| ID | Severity | Why T3 |
|---|---|---|
| **AUD-0093** | Major/Arch | `REFRESH_SCRIPT` path — coupled to AUD-0078 subprocess → in-process migration; depends on broader refresh architecture decision |
| **AUD-0096** | Major/Arch | Split 3,867-line open_orders.py — multi-PR refactor; parallels chunks 1-2's AUD-0058 |
| **AUD-0114** | Critical/Arch | 1,200-line `submit_trade` split + compensating cancels — major refactor called out explicitly in plan document |
| **AUD-0116** | Critical/Perf | Journal list LIMIT/OFFSET + N+1 batching — polled list endpoint overhaul; coordinates with pagination design |
| **AUD-0126** | Major/Arch | Split 5,813-line journal.py — multi-PR refactor |
| **AUD-0130** | Minor/Cleanup | PooledDB → get_db_connection migration in trades.py — blocked on AUD-0008 (DB-lifecycle convergence from chunks 1-2); same-class T3 dependency |
| **AUD-0141** | Minor/Cleanup | Move alerts subsystem to `api/trade_alerts.py` — 700+ LOC relocation; multi-module |
| **AUD-0159** | Major/Arch | Split 3,499-line refresh_trade_journal.py — multi-PR refactor |

Plus these tracker-flagged architectural items (coupled to the above):
| ID | Severity | Why T3 |
|---|---|---|
| **AUD-0078 → T3?** | Kept T2 — see rationale above; the "in-process refresh" choice is a proposal, not a multi-PR migration |

Note: I kept most potentially-architectural chunk-5 findings in T2 rather than T3 because they're
one-file refactors, not multi-file ones — but any subset the user decides is "too big" can be
promoted. Candidates for promotion: AUD-0168 (shared base across 3 pipeline scripts), AUD-0170
(OrderClassifier decomposition), AUD-0171 (writer/reader split — tracker flags cross-chunk).

Additional promotions from T2 if reviewer agrees they are multi-PR:
- AUD-0111 (Redis TTL) — could be T3 (design + deployment work)
- AUD-0118, 0150, 0162, 0163 (transaction cluster) — could be one T3 bundle
- AUD-0147+0148+0149+0157+0174 (pipeline f-string SQL cluster) — could be one T3 migration

**Total T3 if all cluster-promotions accepted:** ~23. Keeping conservative count above at 8 core
T3 items; the 15-item difference is reviewer-movable.

---

## T4 — Already closed (2)

Resolved / Works-as-intended:
- **AUD-0085** (Works as intended — Family A/B rounding policy documented in docs/50-reference/rounding.md)
- **AUD-0104** (Resolved 2026-04-23 — `_short_order_id` helper extracted)

---

## Execution plan for Step 2

Order of T1 work (groups findings by file to share worktrees):

1. **open_orders.py additive batch** (AUD-0107, AUD-0110) — non-risky additive + doc fix;
   baseline test: `tests/unit/test_open_orders_helpers.py` (exists per AUD-0104). Single commit.
2. **journal.py alias cleanup** (AUD-0133 — also includes `Snapshot = Screenshot` deletion after
   grep reconfirm) + **AUD-0132** parse_fees_json broader-except-with-log (journal.py:334).
   Batched as one commit: "cleanup(journal): AUD-0133/0132 — delete dead aliases, log fees parse
   failures." Baseline: `tests/unit/test_screenshot_helpers.py`.
3. **trades.py LIMIT 1** (AUD-0139). Single commit. Baseline: integration tests over trades
   submit flow (already exist).
4. **refresh_order_leg_hist.py parameterize** (AUD-0173). Single commit. Baseline: pipeline
   integration smoke (if exists) + new unit test over the 4 specific SELECTs.
5. **refresh_order_leg_live.py narrow fixes** (AUD-0172 trigger_price Decimal, AUD-0180
   reduce_only is-not-None). **Important: sequence AFTER AUD-0147 if user approves it** — if
   AUD-0147 lands first via T2 route, these two become trivial rebase; if not, they land on
   current f-string-SQL code and must be carefully not-to-break. Default: land these first (low
   blast radius), let AUD-0147 rebase later.
6. **refresh_trade_journal.py DEBUG log in diagnose_orphan_legs** (AUD-0177 narrow interpretation)
   — optional, demote to T2 on reviewer request.
7. **pipeline_lock.py delete + lock_step.sh env var** (AUD-0151, AUD-0175). Single commit.
   Baseline: grep-verify no post-delete references; manual smoke test of `bin/pipeline/refresh`.

Seven batches, 12 findings. Estimated 6-7 commits (batches 1-5 one each, 6 optional, 7 one).

## Review checklist for you

Before I start Step 2, please eyeball:

- [ ] AUD-0151 pipeline_lock.py deletion — grep shows zero callers, but confirm no near-term
      plans for wiring it up? Audit says "Either delete or wire up"; I chose delete.
- [ ] AUD-0133 also deletes `Snapshot = Screenshot` alias — OK to include in same commit?
- [ ] AUD-0177 narrow-interpretation (DEBUG log only, don't fix sessionization) — accept as T1
      or demote to T2?
- [ ] AUD-0172 / AUD-0180 sequencing vs AUD-0147 — land now and let AUD-0147 rebase, OR park
      until AUD-0147 lands?
- [ ] Any T2 item you'd like promoted to T1? Most likely candidates:
      - AUD-0136 / AUD-0144 (NoteEventType enum) — pure rename but wide-surface in SQL literals
      - AUD-0160 (spot sessions `symbols_in` %s refactor) — single function, 7 lines
      - AUD-0174 (order_id_list `%s` parameterize in refresh_order_leg_live.py) — 3 sites
        but in primary-writer function
- [ ] Cross-chunk concern: AUD-0082 (orderLinkId) depends on AUD-0002 which is chunk-1 T3 —
      acknowledged as T2 pending chunks 1-2 progress.

## Borderline / uncertain — flagged for parent review

- **AUD-0177** — tracker "Needs verification"; narrow T1 fits, but audit suggests structural fix.
- **AUD-0099** (`missing_trade` dead branch) — grep-verified frontend references the filter
  value; removing branch changes behavior from "always-empty" to "return-all". Marked T2 to
  be safe.
- **AUD-0161** tracker says "delete after full parameterization." Grep shows ONE live caller at
  line 2687 today, so it is NOT dead yet. Marked T2 (deletion depends on AUD-0148 landing first).
- **AUD-0171** tracker explicitly notes "cross-chunk" — forced T2+ per triage rules. Listed as
  T2 but could be T3.

## Cross-chunk dependencies flagged

- **AUD-0082** (orderLinkId) depends on **AUD-0002** (retry policy, chunk 1, T3).
- **AUD-0130** (PooledDB → get_db_connection in trades.py) depends on **AUD-0008** (chunk 1, T3).
- **AUD-0171** (writer/reader split in pipeline) — tracker marks "cross-chunk"; touches
  chunks 3+5 interface.
- **AUD-0122** duplicates **AUD-0089** relationship (calc_trigger_direction between
  open_orders.py and trades.py) — single helper fix coordinates both chunks.
- **AUD-0132** is formally a chunk-4 finding but tracker mistakenly attributes file to
  trades.py; grep confirms function lives in journal.py:334. Evidence column has a parenthetical
  "(note: actually in journal.py)" acknowledging the typo. Does not block T1 execution.
