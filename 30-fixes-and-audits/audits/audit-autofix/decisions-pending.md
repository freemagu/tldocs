---
status: pending-user-decisions
source-files:
  - "[[t2-retriage-chunks-1-2]]"
  - "[[t2-retriage-chunks-3-5]]"
  - "[[t2-retriage-chunks-6-14]]"
tracker: "[[AUDIT_TRACKER]]"
generated: 2026-04-24
head-sha: 3907494a
---

# Audit-autofix — pending decisions

**Tracker state:** 178 Resolved / 190 Confirmed / 9 Suspicious (48% done, HEAD `ddb00ddb`).

## Follow-ups requiring user attention (added 2026-04-25)

Tick to dispatch / address. These all surfaced from sub-agent reports during the 2026-04-25 batches and would otherwise get lost in the commit history.

### One-shot (do once)

- [ ] **`chat_exporter/.env` cleanup** — file was untracked (contains `DISCORD_TOKEN`); the parent `chat_exporter/` directory was deleted by AUD-0263. The `.env` lingers on disk. Just `rm /app/syb/tradesuite/tradelens/chat_exporter/.env` (and the empty parent dir if Git doesn't auto-clear it). Manual; no commit needed.

### New audit-tracker entries to open (separate ticket bodies needed)

- [ ] **Latent bug in `_set_guard_failed`** (level_guard_daemon.py) — calls `GuardStateData(state=GuardState.CANCELLED)` without required `config` arg → raises `TypeError` swallowed by surrounding `try/except`. The function does NOT delete the leg, so the broken update is operationally meaningful (daemon expects `guard_state_json` to mark CANCELLED so it skips on next cycle). Found by AUD-0211 sub-agent. **Open a new tracker ID** when ticked; either fix the constructor call (pass a stub config) or audit whether the cycle-skip works via some other path.

- [ ] **94 prod orphan filled legs** (from AUD-0177 verification) — `order_leg_hist` rows with `status='filled'` and no matching `trade_leg_map.hist_leg_id`. Oldest 2025-10-14, newest 2026-04-13. Distribution: 29 entry, 29 tp, 12 seed, 10 suspend_exit, 6 close_loss, 3 stop, etc. Diagnostic fires every pipeline run (~15s cadence, 187 lines/13h observed) — signal-rot risk if a new sessionization bug appears. **Open as T3** (sessionization investigation): join each orphan to its symbol's nearest trade session, classify root cause (manual orders vs sessionization vs position_idx mismatch), then either fix sessionization or add an "expected orphan" filter.

### Re-classify bucket-A items already ticked

- [ ] **AUD-0140 → bucket C** — verification confirmed 3 of 4 state-transition endpoints in `journal.py` are NO-TXN-money-path (`cancel_seeded_trade`, `cancel_pending_trade`, `force_open_trade`). Each places real Bybit orders interleaved with multi-table DB writes; mid-stream crash leaves DB inconsistent with exchange state. The endpoint `activate_seeded_trade` is single-write — no wrap needed.
  - Recommended approach: wrap DB-only blocks in `with conn.transaction()`; keep Bybit calls outside the txn (they're not rollbackable); compensating-log pattern (write a pre-action `trade_journal_notes` row BEFORE Bybit calls so a crash leaves an audit breadcrumb).

- [ ] **AUD-0118 wider refactor** — original cluster wrap blocked because `batch_ideas.py` cascade helpers (`create_note_for_entity`, `attach_tag_to_entity`, `_save_ai_conversation_to_idea`) open their own `PooledDB` connections — separate sessions that autocommit independently of the main cursor's transaction. Wrapping just the cursor block gives a half-fix that still leaks split-state. **Needs `conn=` parameter threaded through helpers** — multi-call-site refactor. Estimated ~1-2 days. Move to **bucket F (T3)**.

- [ ] **AUD-0150 wider refactor** — `archive_disappeared_order` interleaves DB writes with Bybit HTTP calls (`bybit.get_order_history()` at L1482, `bybit.amend_order()` via `_check_breakeven_trigger` at L1614). Wrapping in transaction would hold a DB transaction across HTTP — anti-pattern. **Needs split into fetch-phase + DB-write-phase** before wrap. Move to **bucket F (T3)**.

### Methodology notes (for next session)

- **Cross-session contention** showed up twice during parallel sub-agent dispatch (AUD-0017↔AUD-0288 and AUD-0263↔AUD-0206). Each accidentally swept the other's staged work into its commit; recovered via revert + re-commit. Cause: index state leaks when two sub-agents stage and commit concurrently in the same working tree. **Mitigation for next time**: serial dispatch when sub-agents touch any overlapping module/test files; or pre-stage each into a separate worktree if running in parallel.

---

## Shipped 2026-04-25 batches

### Batch 1 (24 commits, AUD-IDs 0006/0034/0053/0090/0097/0108/0109/0123/0128/0129/0134/0138/0143/0147/0148/0149/0152/0153/0157/0161/0178/0179/0195/0210/0211/0235/0265/0289/0295/0305/0306/0348/0362)

24 commits; pytest 952 passed, 4 skipped (was 791 → +161 tests across the batch). All commits on `master`, no force-pushes.

| AUD | Commit | Summary |
|---|---|---|
| 0123/0134/0143 | `e49a383c` | tracker-only WAI / won't-fix flips |
| 0147 | `70257555` | parameterise upsert_legs_to_db SQL |
| 0148 | `3db64c15` + `09689e54` | parameterise upsert_trade_journal + detect_seeded_trade_promotions |
| 0149/0157 | `59547b6a` (prior) | parameterise fetch_order_legs (already shipped — verified) |
| 0152+0153 | `9c3ee241` | is-not-None for zero/empty in upsert_trade_journal |
| 0179 | `c7bcf428` | regression test + tracker flip (helper landed in 59547b6a) |
| 0090 | `6f4cb141` | single BybitClient at amend-handler top |
| 0108 | `a55f9bfb` | extract CTE for duplicated open_orders query |
| 0109 | `1125a62d` | reject no-op amends with HTTP 400 (user-visible) |
| 0128 | `d13e0649` | extract leverage helper to services/leverage.py |
| 0129 | `50288659` | named-placeholder dict for dynamic WHERE in journal.py |
| 0097 | `5614a8ed` | fixed-column INSERT/UPDATE in _upsert_vwap_link |
| 0138 | `3c2943e5` | lint guard for ALL_SORTABLE_FIELDS / JournalListItem drift |
| 0178 | `66fb0c6e` | diff-based upsert replacing DELETE+INSERT |
| 0195 | `06b3755a` | rename pending_request_uuid → subscription_request_uuid (migration 076) |
| 0210 | `d3f0b37a` | allowlist /guards/config response |
| 0211 | `e50d5894` | wrap partial-cancel cleanup in single transaction (money-moving) |
| 0235 | `a55876bb` | normalise status to lowercase 'new' on suspend path |
| 0265 | `25e3133f` | shared cached parser config |
| 0289 | `f8a8657c` | reconcile stale tick_archive 'ingesting' state |
| 0295 | `d835be79` | add status/run subcommands to bin/api + bin/dashboard |
| 0305 | `b196c6f7` | configurable force-kill timeout |
| 0306 | `1b53a5f5` | surface lease-refresh as operational metric |
| 0348 | `a6b3ceee` | unify _PYTHON_PATTERNS into SERVICES registry |
| 0006 (a) | `1a7f0b4d` | trigger_direction + reduce_only required (4 sites) |
| 0034 (b) | `fa88cc86` | document BybitClient.close as no-op |
| 0053 (b) | `9585f1d3` | apply_leg returns NamedTuple |
| 0161 | `958e67c7` | delete now-dead _validate_and_escape_order_id |
| 0362 | `be338f7d` | operator runbook for setup scripts |

**Side-effects worth flagging:**
- AUD-0148 had to be extended (`09689e54`) — the original commit missed `detect_seeded_trade_promotions`'s f-string `IN ()` clause. Found because AUD-0161 couldn't ship until that site was parameterised.
- AUD-0211 sub-agent found a latent bug in `_set_guard_failed` in `level_guard_daemon.py` — calls `GuardStateData(state=GuardState.CANCELLED)` without the required `config` arg, raising TypeError that's swallowed by the surrounding `try/except`. Out of scope for AUD-0211 but worth a follow-up audit ticket. *(See follow-up section above.)*
- AUD-0348 unification fixed three live regressions silently — `level-mind`, `correlation-engine`, `telegram-signals` were missing from `_PYTHON_PATTERNS`, so system-monitor had been reporting metrics for the bash autorestart wrapper instead of the Python worker.
- AUD-0006 (a) found that 1 of 4 call sites (spot stop-loss in `services/stops.py:244`) was actually relying on the dangerous `reduce_only=False` default. Other 3 sites were already passing both kwargs.

### Batch 2 (13 commits, AUD-IDs 0017/0031/0073/0084/0102/0140/0142/0145/0156/0162/0163/0177/0206/0223/0263/0288/0344)

13 commits; pytest **996 passed, 4 skipped** (+44 tests). Includes 2 clusters + 5 WAI-flips + 5 deletes + 2 small fixes.

| AUD | Commit | Summary |
|---|---|---|
| 0162 | `b31f1220` | wrap `purge_existing_data` DELETEs in single transaction |
| 0163 | `2b1ad973` | wrap `upsert_trade_journal` cascade in single transaction |
| 0118 / 0150 | `2de808bb` | partial-stop notes — wider refactor needed (see follow-ups) |
| 0084 + 0102 | `49c4c06c` | sanitise Bybit/internal error leaks with correlation IDs (18 sites) |
| 0031/0073/0142/0156/0177 | `aad1f0f9` | tracker-only WAI flips after read-only verification |
| 0017 | `0ffe289c` | remove cargo-cult `periodic_gc` loop (was belt-and-braces beside the actual pooling fix) |
| 0288 | `c3407112` | remove dead `CandleCopyRunner` (248 LOC) |
| 0223 | `cdd2bcae` | remove dead `vwap_config_raw` read in suspend resume |
| 0206 | `91cf63be` | remove dead `WAITING_MIND` v1 legacy state (5 files) |
| 0145 | `93c2110d` | extract canonical `ACTIVE_TRADE_STATUSES` constant |
| 0344 | `4b0dd467` | DuckDB `?` params + path-traversal guard in `tick_loader` |
| 0263 | `d7b9130b` | remove legacy DiscordChatExporter path (792 LOC + chat_exporter binary) |

**Side-effects worth flagging:**
- AUD-0118/0150 split into wider-refactor follow-ups (see "Follow-ups" section above).
- AUD-0140 verification reclassified 3 of 4 endpoints into bucket C — see follow-up.
- AUD-0177 found 94 prod orphan filled legs — see follow-up.
- 13 verifications dispatched in parallel (read-only); cross-session contention with concurrent commits on `main.py` and `level_guard_daemon.py` required two revert + re-commit cycles to land cleanly.

---

Items below are the non-Resolved findings that the re-triage classified as **T2b (design-required)** or flagged as **Suspicious (needs investigation)** — grouped by the shape of action you take. Tick the checkboxes on items you want shipped; for pick-one items, tick exactly one option. Leave untouched anything you want to park. Save the file and tell me which bucket you've ticked and I'll dispatch sub-agents the same way as the last batch (sub-agent per item, tests-before-fix, serial).

**How the buckets work:**
- **A — Quick-yes** → one checkbox per item; canonical answer is clear and scope is small.
- **B — Pick-one** → each item has 2-3 choices; tick one.
- **C — Money-moving / schema** → canonical answer is clear but blast radius warrants an explicit sign-off.
- **D — Verify first (Suspicious)** → I need to investigate before we can decide. Tick to authorise a read-only investigation sub-agent.
- **E — Clusters** → multi-item refactors bundled into one work item; tick the cluster header.
- **F — T3 architectural** → multi-day work, not for autonomous execution. Tick to **schedule a planning session** (I'll scope + design, not ship code).

Unticked items are simply deferred; they don't go stale.

---

## Bucket A — Quick-yes (narrow scope, clear canonical answer)

Tick one box per item. I'll batch 5–10 at a time via sub-agents.

### Parked / blocked (still ticked but NOT shipped this batch — re-tick to revisit)

- [ ] **AUD-0176** (Minor/Cleanup) — merge 3 classifier maps into typed dataclass in pipeline. Depends on AUD-0170 (T3) decomposition first — park unless T3 pre-work.
- [ ] **AUD-0233** (Minor/Cleanup) — hand-rolled rollback cleanup. Depends on AUD-0217 (txn cluster) landing first.
- [ ] **AUD-0275** (Major/Cleanup) — `QUICK_TIMEFRAME_CONFIG` vs `TIMEFRAME_CONFIG` in mdsync. **Needs decision** — not subset (lookbacks differ 30d vs 365d). Move to pick-one (B).
- [ ] **AUD-0280** (Major/Cleanup) — `vwap_config.slots_json` opaque blob → typed columns. **Schema change** — move to bucket C.
- [ ] **AUD-0303** (Major/Cleanup) — single-file cleanup (worker). Pull context before shipping.
- [ ] **AUD-0322-0324** (Minor/Cleanup, 3 items) — frontend-styling cleanup. **BLOCKED on AUD-0332 vitest setup** (bucket F).
- [ ] **AUD-0338-0340** (Minor/Cleanup, 3 items) — similar — grep for scope before executing.

---

## Bucket B — Pick-one (two or more reasonable answers)

Tick exactly one `(a) / (b) / (c)` per item. I'll execute once ticked.

### Chunks 1–2

~~**AUD-0006** (Critical/Bug) — `trigger_direction` + `reduce_only` default semantics. Money-path.~~ — _shipped 1a7f0b4d (option a)_

**AUD-0010** (Major/Arch) — private `BybitClient.__init__`.
- [ ] (a) Force all callers through `get_bybit_client` (40+ site sweep).
- [ ] (b) Add lint rule + document invariant; leave code. *Recommended — smaller churn.*

**AUD-0011** (Major/Reliability) — HTTP timeout config for Bybit client.
- [ ] (a) `httpx.Timeout(connect=5, read=15, write=10, pool=5)` — audit's recommendation. *Recommended with 1-week canary on demo.*
- [ ] (b) Conservative `connect=10, read=30`.
- [ ] (c) Config-driven (new YAML section).

**AUD-0012** (Major/Reliability) — `AccountContext` lifecycle when DB is down.
- [ ] (a) Fail-fast (raise at `__init__`).
- [ ] (b) Lazy-reload on cache miss. *Recommended — least disruptive.*
- [ ] (c) Background retry task.

~~**AUD-0034** (Minor/Dead Code) — `BybitClient.close()` method.~~ — _shipped fa88cc86 (option b)_

**AUD-0037** (Major/Arch) — YAML-load + DB-sync coupling in `AccountContext`.
- [ ] (a) Split load from sync; call sync from FastAPI lifespan. *Recommended but deps on AUD-0008 (T3).*
- [ ] (b) Lazy DB-sync on first access.
- [ ] (c) Keep but wrap DB-sync in try/except.

**AUD-0039** (Major/Arch) — `orderLinkId` policy. Prerequisite for retry policy (AUD-0002, T3).
- [ ] (a) Auto-generate `{trade_id}-{leg_kind}-{ts}` at adapter boundary + require. *Recommended.*
- [ ] (b) Require but caller-supplied.
- [ ] (c) Keep optional + add `cancel_by_order_link_id` helper.

~~**AUD-0053** (Major/Bug) — `apply_leg` return shape.~~ — _shipped 9585f1d3 (option b)_

**AUD-0056** (Major/Bug) — `profit_pct` vs `rr_ratio` naming in trades.
- [ ] (a) Replace `profit_pct` with `rr_ratio` (frontend needs 3 type updates). Clean, but UI-visible break.
- [ ] (b) Rename field to `profit_pct_of_waep` with doc comment. Mildly misleading → accurate.
- [ ] (c) Add parallel `rr_ratio` field, deprecate `profit_pct`. *Recommended — no UI break.*

**AUD-0077** (Major/Arch) — Decimal at sizing boundary. Cascades into DTO layer.
- [ ] (a) Accept `Decimal` at public boundary — pydantic Decimal DTOs + API work. *Recommended but belongs with AUD-0016 (T3).*
- [ ] (b) Accept strings + parse internally.
- [ ] (c) Keep floats, document precision loss. *Close-as-WAI.*

### Chunks 3–5 (open_orders.py + trades/journal + pipeline)

**AUD-0078** (Critical/Perf) — spot-execution enrichment is sync on 6 call sites, blocks request.
- [ ] (a) In-process (no change from today).
- [ ] (b) FastAPI `BackgroundTasks`. *Recommended — lowest blast radius.*
- [ ] (c) External queue.

**AUD-0079** (Critical/Perf) — cancel_all is N sequential API calls.
- [ ] (a) Add `cancel_batch` to BybitClient adapter. *Recommended — big UX win.*
- [ ] (b) Keep serial but drop per-order refresh.
- [ ] (c) SDK swap.

**AUD-0080** (Critical/Bug) — pre-placement ticker validation on amend.
- [ ] (a) Refuse on ticker failure. *Recommended — safety-first.*
- [ ] (b) Explicit `i_accept_the_risk` override.
- [ ] (c) Require amend-side-of-current-price in request.

**AUD-0081** (Critical/Reliability) — double-submit protection.
- [ ] (a) `AppLock` per-leg alone.
- [ ] (b) Bybit `orderLinkId` idempotency alone.
- [ ] (c) Both — they solve orthogonal races (double-click ≠ retry). *Recommended.*

**AUD-0082** (Critical/Reliability) — `orderLinkId` generation site. Depends on **AUD-0039** choice.
- [ ] (a) Adapter. *Recommended — single source.*
- [ ] (b) Router.
- [ ] (c) Passed by caller.

**AUD-0084** (Critical/Security) — verbose error details leak Bybit state.
- [ ] (a) Generic detail + correlation ID (grep logs). *Recommended.*
- [ ] (b) Classify-and-sanitize per error type.
- [ ] (c) Keep verbose in dev, sanitize in prod.

**AUD-0086** (Major/Perf) — instrument-info cache.
- [ ] (a) TTL ~5min. *Recommended — matches Bybit update cadence.*
- [ ] (b) Preload-at-startup.
- [ ] (c) LRU.

**AUD-0087** (Major/Arch) — `get_tick_size` accepts bybit client through.
- [ ] (a) Pass `bybit` through explicitly. *Recommended — simplest.*
- [ ] (b) Factory-take.
- [ ] (c) Module-level cache keyed by account.

**AUD-0088** (Major/Bug) — Decimal pipeline in pricing math.
- [ ] (a) Drop the float `round(..., 10)` final. *Recommended — matches CLAUDE.md rounding memory.*
- [ ] (b) Keep as belt-and-suspenders.

**AUD-0089 + AUD-0122** (Major/Bug, bundled) — `leg_type` passed through inference helpers across `open_orders.py` + `trades.py`.
- [ ] (a) Add `side` / `leg_type` inputs to inference helper. 6+ callers. *Recommended.*
- [ ] (b) Pass full `Leg` object.

**AUD-0091** (Major/Bug) — stop-like policy in amend classification.
- [ ] (a) Expand explicit "stop-like" set.
- [ ] (b) Per-leg-type policy.
- [ ] (c) Treat qty≥position as stop regardless of type. *Recommended — risk-semantic.*

**AUD-0092** (Major/Bug) — `auto_relabel` behaviour.
- [ ] (a) Require explicit `leg_type`. *Recommended — surfaces intent.*
- [ ] (b) Keep auto-relabel but log.
- [ ] (c) Deprecate auto-relabel over 2 releases.

**AUD-0094** (Major/Bug) — `preview_order` vs `preview_amend_order` divergence.
- [ ] (a) Port `preview_amend_order` to match `preview_order` (newer path). *Recommended.*
- [ ] (b) Port the other direction.

**AUD-0095** (Major/Arch) — close-entire vs close-qty signature on suspend.
- [ ] (a) `close_entire: bool` flag. *Recommended — explicit intent.*
- [ ] (b) `qty: Optional[Decimal] = None`.

**AUD-0098** (Major/Reliability) — local DB as primary-writer for orders. **Depends on AUD-0078 outcome.** Defer until AUD-0078 ships.

**AUD-0101 + AUD-0103** (Minor/Bug, bundled) — Decimal comparison instead of float+tolerance in `_price_decimals`.
- [ ] (a) Decimal. *Recommended — matches CLAUDE.md rounding policy.*
- [ ] (b) Keep float with tolerance.

**AUD-0102** (Minor/Security) — same-class as AUD-0084 (4 sites in amend paths). **Tick AUD-0084 (a) to auto-bundle.**

**AUD-0105** (Minor/Bug) — pre-placement ticker check before amend. Ticking AUD-0080 (a) auto-bundles this for consistency.
- [ ] (a) Add it.
- [ ] (b) Skip.

**AUD-0106** (Minor/Reliability) — unknown qty-step behaviour.
- [ ] (a) Raise. *Recommended — sized-at-wrong-precision is worse than a clean 4xx.*
- [ ] (b) Keep fallback + WARN.

**AUD-0111** (Critical/Arch) — preview→submit cache.
- [ ] (a) Redis with TTL.
- [ ] (b) Atomic preview+submit (no external cache). *Recommended — no new dep.*
- [ ] (c) DB-backed cache.

**AUD-0112** (Critical/Security) — preview→submit identity binding. Identity model doesn't exist today.
- [ ] (a) Bind preview to account-only. *Recommended stop-gap — covers 99%.*
- [ ] (b) Build identity model.
- [ ] (c) Ship as-is with audit log.

**AUD-0113 + AUD-0127** (Critical/Security+Arch, bundled) — preview/submit dispatch. Merge → one code path.
- [ ] (a) Merge into single submit_trade path. *Recommended.*
- [ ] (b) Keep split, whitelist fields on each.

**AUD-0117** (Critical/Perf) — AI batch synchronous, blocks request.
- [ ] (a) Async endpoint (polling). *Recommended — no new infra.*
- [ ] (b) WebSocket push.

**AUD-0119** (Major/Perf) — trade-event writes synchronous. Coordinates with **AUD-0078**.
- [ ] (a) `BackgroundTasks`. *Recommended — same pattern as AUD-0078.*
- [ ] (b) Message queue.

**AUD-0120** (Major/Perf) — journal row-grows-forever.
- [ ] (a) Row-grows-forever (today).
- [ ] (b) Event-typed new row per exec. *Recommended — matches event-log semantics.*

**AUD-0121** (Major/Bug) — SL move inside lock vs after.
- [ ] (a) Inside lock. *Recommended — prevents stop-less window.*
- [ ] (b) After lock release.

**AUD-0124** (Major/Perf) — batched IN vs LATERAL JOIN for per-symbol metrics.
- [ ] (a) Batched `IN (...)`. *Recommended — simpler, same perf.*
- [ ] (b) LATERAL JOIN.

**AUD-0125** (Major/Perf) — market data aggregation.
- [ ] (a) LATERAL JOIN (live). *Recommended — no staleness.*
- [ ] (b) Materialized view refreshed on 5m candle.

**AUD-0131** (Minor/Cleanup) — evict-on-submit in preview cache. **Moot after AUD-0111 (b) atomic preview+submit.** Tick AUD-0111 (b) to auto-resolve.

**AUD-0137** (Minor/Cleanup) — split `JournalListItem` into two DTOs.
- [ ] (a) Do the split — FE coordination needed (optional fields stay optional at type level).
- [ ] (b) Skip.

**AUD-0145** (Minor/Cleanup) — `pending_entry` in conflict check — **bug or design?** Needs audit. Move to bucket D (verify first).

### Chunk 7 (ideas/suspend/batch)

**AUD-0212** (Critical/Bug) — `POST /stops` endpoint currently broken (BybitClient needs account_name).
- [ ] (a) Fix it — add account_name resolution.
- [ ] (b) Delete the endpoint (confirmed unused).

**AUD-0214** (Critical/Arch) — route suspend/resume through typed adapters. **Money-moving non-additive** — move to bucket C if you prefer explicit sign-off.
- [ ] (a) Route through typed adapters. *Recommended — coordinates with AUD-0006, 0036.*
- [ ] (b) Leave.

**AUD-0215** (Critical/Reliability) — resume marks trade open despite per-order failures.
- [ ] (a) Fail resume if any per-order op fails.
- [ ] (b) Keep current "best-effort" but log errors loudly. *Recommended for now; fail-hard later.*

**AUD-0216 / AUD-0201** (Critical/Perf + Major/Arch, cross-cutting) — async endpoints with sync DB calls.
- [ ] (a) Wrap sync DB calls in `asyncio.to_thread`. *Recommended as stop-gap.*
- [ ] (b) Full async-DB rewrite (`asyncpg`). T3-sized.
- [ ] (c) Keep sync.

**AUD-0219** (Major/Perf) — ideas list LIMIT/OFFSET. API contract change.
- [ ] (a) Add `?limit=` / `?offset=`. *Recommended.*
- [ ] (b) Cursor-based pagination.

**AUD-0220** (Major/Perf) — concurrent Bybit fetches in ideas market data. New concurrency pattern.
- [ ] (a) `asyncio.gather`. *Recommended.*
- [ ] (b) Keep sequential.

**AUD-0221 + AUD-0230** (Major/Perf+Arch, bundled) — batch AI → async job with polling endpoint. New API surface.
- [ ] (a) Background job + `/batch-ai/status/{job_id}`. *Recommended.*
- [ ] (b) Keep synchronous.

**AUD-0222** (Major/Perf) — `subprocess.Popen` refresh in suspend. **Money-adjacent.** Move to bucket C.

**AUD-0225** (Major/Reliability) — async handler holds cursor across awaits. Race semantics.
- [ ] (a) Close-cursor-before-await pattern. *Recommended.*
- [ ] (b) Per-request cursor context manager.

**AUD-0227** (Major/Security) — user→account authorization missing on many endpoints.
- [ ] (a) Middleware-level check on every protected endpoint. *Recommended.*
- [ ] (b) Per-endpoint inline check.

**AUD-0228 + AUD-0229** (Major/Arch, bundled) — idea→intent→journal schema linkage + state machine in code not data. **Schema change.** Move to bucket C.
- [ ] (a) Add explicit `idea_id` FK + state enum column.
- [ ] (b) Keep as-is, document invariants.

**AUD-0231** (Major/Reliability) — `orderLinkId` on resume. Money-moving additive-ish. Depends on **AUD-0039** choice.

### Chunk 8 (Discord/Telegram)

**AUD-0240** (Critical/Security) — self-botting architecture. **Product decision.**
- [ ] (a) Plan migration to Discord webhooks (deprecates extension). Separate planning session needed.
- [ ] (b) Accept current model; continue Phase 2 of AUD-0241 (HMAC).
- [ ] (c) Keep as-is.

**AUD-0243** (Critical/Perf) — sync image downloads during ingest. Blocks request.
- [ ] (a) `BackgroundTasks` + failure-retry. *Recommended.*
- [ ] (b) Queue.

**AUD-0244** (Critical/Reliability) — transaction around Discord idea-create cascade. **Money-adjacent.** Move to bucket C.
- [ ] (a) Single `BEGIN..COMMIT` around the insert chain. *Recommended.*
- [ ] (b) Keep per-statement.

**AUD-0245 + AUD-0253** (Critical/Arch + Major/Perf, bundled) — Discord handler uses env-var DB conn instead of pool; fresh IdeaCreator per request.
- [ ] (a) Propagate pool through handler + use singleton IdeaCreator. *Recommended.*
- [ ] (b) Keep env-var + fresh creator.

**AUD-0246** (Major/Security) — auth before body parse in Discord ingest (FastAPI middleware ordering).
- [ ] (a) Move auth before body parse. *Recommended — security win.*
- [ ] (b) Keep post-parse.

**AUD-0247** (Major/Security) — state-file load-modify-save race.
- [ ] (a) `flock`.
- [ ] (b) Move state to DB. *Recommended — unifies concurrency model.*

**AUD-0248 + AUD-0249** (Major/Security, bundled) — HTTPS enforcement on `backend_url` + extension `host_permissions` model.
- [ ] (a) Require HTTPS + tighten `host_permissions`. *Recommended.*
- [ ] (b) Keep.

**AUD-0250** (Major/Arch) — 80% overlapping `IdeaCreator` for Discord/Telegram. Large refactor. Depends on AUD-0242 (done).
- [ ] (a) Unify via shared base class. *Recommended — multi-file refactor but now unblocked.*
- [ ] (b) Keep separate.

**AUD-0254** (Major/Cleanup) — duplicate pre/post handler logic (~200 LOC).
- [ ] (a) Extract shared helper. *Recommended.*
- [ ] (b) Keep duplicate.

**AUD-0266** (Minor/Security) — `/discord-ingest/health` auth.
- [ ] (a) Require auth. *Recommended — matches other ingest endpoints.*
- [ ] (b) Public (matches convention for health checks).

### Chunk 9 (market data)

**AUD-0270** (Critical/Arch) — inline DDL `ensure_schema`. Callers must be updated.
- [ ] (a) Move DDL to migration; callers assume table exists. *Recommended.*
- [ ] (b) Keep inline.

**AUD-0271** (Critical/Perf) — per-row UPDATE/INSERT → `ON CONFLICT` batch for candle ingest. **Money-adjacent** (wrong candles mislead analytics). Move to bucket C.
- [ ] (a) `ON CONFLICT DO UPDATE` batch. *Recommended.*
- [ ] (b) Keep per-row.

**AUD-0274** (Major/Reliability) — per-instance vs shared rate limiter.
- [ ] (a) Module-level singleton. *Recommended.*
- [ ] (b) Instance.

**AUD-0282** (Major/Cleanup) — `vwap_order_engine.amend_order` missing `orderLinkId`. Money-moving. Depends on **AUD-0039**. Move to bucket C once 0039 picked.

**AUD-0283** (Major/Config) — hardcoded magic constants in market-data config surface.
- [ ] (a) Move to `config.yml`. *Recommended.*
- [ ] (b) Keep hardcoded.

### Chunk 10 (workers)

**AUD-0268 + AUD-0269** (Critical/Arch, bundled) — worker lifecycle policies. **Two architectural calls.**
- [ ] (a) Worker-per-process with graceful SIGTERM. *Recommended.*
- [ ] (b) Threadpool.
- [ ] (c) Subprocess pool.

**AUD-0272** (Critical/Perf) — worker polling interval.
- [ ] (a) Config-driven. *Recommended.*
- [ ] (b) Hardcoded as today.

**AUD-0276 + AUD-0278 + AUD-0279** (Major/Arch, bundled) — worker module organization. Coordinate cross-file refactor.
- [ ] (a) Do the refactor as one PR.
- [ ] (b) Park — T3 candidate.

**AUD-0281** (Major/Reliability) — worker lease renewal on long jobs.
- [ ] (a) Background lease-refresh task. *Recommended.*
- [ ] (b) Inline renewal at job checkpoints.

**AUD-0292** (Critical/Reliability) — unbounded `pkill -9` in `tl`.
- [ ] (a) Bounded retry with graceful-then-force escalation. *Recommended.*
- [ ] (b) Keep.

**AUD-0293** (Critical/Security) — `pkill -f` path qualification. Cross-file PID-file plumbing across 12 wrappers.
- [ ] (a) Switch all 12 wrappers to PID files. *Recommended — big win, mechanical.*
- [ ] (b) Leave (cross-contamination risk accepted).

**AUD-0298** (Major/Perf) — batch `get_tickers` across symbols.
- [ ] (a) Add new batched client method. *Recommended.*
- [ ] (b) Keep sequential.

**AUD-0299** (Major/Perf) — cycle-scoped DB connection for alert_engine helpers.
- [ ] (a) Pass connection through. *Recommended — signature change.*
- [ ] (b) Keep per-call open.

**AUD-0300** (Major/Perf) — subprocess → in-process pipeline. Signature + entry-point refactor. Large.
- [ ] (a) Consolidate. *Recommended but sizeable.*
- [ ] (b) Park.

### Chunk 13–14 (peripheral/ops)

**AUD-0301 + AUD-0302** (Major/Arch, bundled) — architectural patterns in peripheral. Require user context.

**AUD-0304** (Major/Reliability) — peripheral reliability. Needs me to pull context.

**AUD-0334** (Major/Reliability) — similar pattern.

**AUD-0341 + AUD-0343** (Critical/Perf, bundled) — `trader_scorecard` and related — N+1 → window functions.
- [ ] (a) Rewrite with window functions + indexes. *Recommended — UI-load-bearing.*
- [ ] (b) Keep N+1 with cache layer.

**AUD-0342** (Critical/Perf) — part of above cluster. Tick (a) above to bundle.

**AUD-0350** (Major/Reliability) — similar.

**AUD-0357** (Critical/Bug) — migration idempotency sweep. Convention decision.
- [ ] (a) Retrofit all existing migrations with `IF NOT EXISTS` guards. Large diff but mechanical.
- [ ] (b) Forward-only policy (future migrations idempotent; old ones left alone). *Recommended — don't touch shipped migrations.*

**AUD-0360** (Major/Arch) — peripheral module organization.

---

## Bucket C — Money-moving / schema / explicit sign-off

Same execute-shape as A, but I'll ask you a second time before dispatching because these carry real blast radius. Tick to pre-approve.

- [ ] **AUD-0088** — float→Decimal final-rounding in pricing math. *Covered in bucket B as pick-one; tick here for additional money-moving sign-off.*
- [ ] **AUD-0121** — SL-move-inside-lock (bucket B) with hedge-mode integration test.
- [ ] **AUD-0158** (Major/Dup) — unified fees-to-USD helper. Golden-file test vs known trades required. Money-moving.
- [ ] **AUD-0211** — transaction around partial-cancel cleanup.
- [ ] **AUD-0217 / AUD-0218** (Critical/Reliability, txn cluster) — transactions around ideas overwrite and inside AppLock. **Bundled as part of the transaction cluster (bucket E).** Tick the cluster to approve these.
- [ ] **AUD-0222** — subprocess refresh in suspend; money-adjacent.
- [ ] **AUD-0228** — schema change for idea→intent→journal linkage. Backfill plan required. Migration 076.
- [ ] **AUD-0229** — state enum column (schema change). Migration 077.
- [ ] **AUD-0231** — `orderLinkId` on resume (money-moving additive).
- [ ] **AUD-0244** — single-transaction Discord idea-create cascade.
- [ ] **AUD-0271** — candle-ingest `ON CONFLICT` rewrite. Wrong candles mislead all analytics.
- [ ] **AUD-0280** — `vwap_config.slots_json` → typed columns (schema). Migration 078.
- [ ] **AUD-0282** — `vwap_order_engine.amend_order` `orderLinkId` (money-moving). Dep AUD-0039.

---

## Bucket D — Verify first (Suspicious / Needs-verification)

Tick to authorise a read-only investigation sub-agent. I'll report back with a bucket-A/B/C classification and a proposed fix (no code ships without a follow-up tick).

All 13 items previously in this bucket were verified + actioned in the 2026-04-25 batch 2 (see Shipped section above). Bucket is currently empty — re-add items here when new Suspicious entries arrive.

~~AUD-0017, 0031, 0073, 0140, 0142, 0145, 0156, 0177, 0206, 0223, 0263, 0288, 0344~~ — all closed.

---

## Bucket E — Clusters (bundle as one refactor)

Each cluster ships as a single multi-commit refactor with pre-test/post-test gates. Tick the cluster to approve the whole thing.

### ~~f-string SQL cluster — `upsert_legs_to_db` + friends~~ — _shipped (4 commits: 70257555, 3db64c15, 09689e54; AUD-0149/0157 already in 59547b6a)_
  - Unlocked AUD-0161 which shipped in `958e67c7`.

### ~~Transaction cluster — writers that should be atomic~~ — _partial-ship 2026-04-25_
  - **AUD-0162 + 0163 shipped** (`b31f1220`, `2b1ad973`).
  - **AUD-0118 + 0150 carried forward to bucket F (T3)** — wider refactor needed; see "Follow-ups requiring user attention" near the top.

### Error-sanitization cluster
- [ ] **Cluster: AUD-0084 + AUD-0102** (Critical+Minor Security) — generic-error+correlation-ID sanitization across 12 sites (open_orders amend paths).

### Enum sweep — legacy patterns
- [ ] **Cluster: AUD-0029 standardisation sweep** — `get_available_balance` raise-on-fail (touches `api/trades.py:845`, `api/suspend.py:1484`). 2 call-sites, money-path. ~~Single commit. Bundled here because re-triage flagged it for explicit sign-off.~~ **NOTE: AUD-0029 already Resolved per AUDIT_TRACKER (verified 2026-04-25 — fix landed earlier under a different commit). Cluster is a no-op; can be removed.**

---

## Bucket F — T3 architectural (schedule a planning session)

These are multi-day refactors. **Not for autonomous execution.** Tick to schedule a 1–2 hour planning session where I'll produce a design doc + phased execution plan, not ship code.

### High-leverage (unlocks downstream)

- [ ] **AUD-0332** (Major/Test Gap) — **wire up vitest**. Unlocks ~30 frontend T2/T3 items (all currently blocked on "no FE test harness"). Estimated: 1 session to bootstrap, then per-component tests can roll in.
- [ ] **AUD-0361** (Major/Reliability) — CI/CD + pre-commit infrastructure (pytest gate + type-check).
- [ ] **AUD-0358** (Major/Test Gap) — lift test coverage from 4.4% to target. Requires prioritised coverage plan.
- [ ] **AUD-0353** (Critical/Security) — **rotate Bybit keys + filter-repo secret history.** Destructive git operation — **you-only.** I'll prepare a runbook.
- [ ] **AUD-0354** (Critical/Security) — second half of secret-hygiene work (dependency audit).

### Large file splits

- [ ] **AUD-0058** (Major/Arch) — split `lib/tradelens/utils/initial_risk_calculator.py` (1,781 LOC).
- [ ] **AUD-0192** (Major/Arch) — split `level_guard_daemon.py` (1,582 LOC).
- [ ] **AUD-0308 + 0310** (Critical/Arch) — split frontend files (6,731 + 3,647 LOC).
- [ ] **AUD-0314** (Major/Arch) — split `api.ts` (3,192 LOC) + OpenAPI codegen integration.
- [ ] **AUD-0311** (Critical/Arch) — related large-file split.

### Architectural refactors (design-heavy)

- [ ] **AUD-0002** (Critical/Reliability) — retry-policy on POST without `orderLinkId`. Foundation for AUD-0039/0082/0231.
- [ ] **AUD-0008** (Major/Arch) — DB lifecycle across FastAPI lifespan.
- [ ] **AUD-0016** (Major/Config) — Decimal at DTO boundary (cascades across API).
- [ ] **AUD-0035 + 0036 + 0038** (Major/Arch) — adapter-layer restructuring.
- [ ] **AUD-0093 + 0096** (Major/Arch) — open_orders architecture decisions.
- [ ] **AUD-0114 + 0115 + 0126** (Critical/Arch) — trades.py top-level architecture.
- [ ] **AUD-0116** (Critical/Perf) — trades.py performance.
- [ ] **AUD-0168** (Major/Arch) — shared `_lib/` across 3 pipeline scripts.
- [ ] **AUD-0169** (Major/Test Gap) — unit tests for pipeline scripts.
- [ ] **AUD-0170** (Major/Arch) — `OrderClassifier` decomposition.
- [ ] **AUD-0171** (Major/Arch) — writer/reader split.
- [ ] **AUD-0155** (Major/Arch) — formal state machine for pipeline states.
- [ ] **AUD-0166** (Major/Reliability) — coordinate with AUD-0154.
- [ ] **AUD-0197 + 0198** (Arch) — `guard_state_json` → typed columns (schema).
- [ ] **AUD-0183** (Critical/Reliability) — atomic suspend via transaction OR reconciler sweeper.

### Tail (lower-leverage architectural items)

- [ ] **AUD-0199** (Test Gap), **AUD-0202** (Arch), **AUD-0224** (Cleanup), **AUD-0256** (Perf), **AUD-0258** (Test Gap), **AUD-0259** (Arch), **AUD-0260** (Dup), **AUD-0277** (Test Gap), **AUD-0289** (Reliability), **AUD-0312-0321** (chunk 12 frontend items), **AUD-0325-0337** (various chunks 12/13), **AUD-0345-0349** (peripheral Arch/Dup), **AUD-0352** (Arch), **AUD-0360** (Arch).
- Tick to schedule a triage-specific planning session that classifies these individually.

---

## Bucket G — Close-as-won't-fix / close-as-WAI

Tick to flip tracker Status → Resolved with a "won't-fix" or "WAI" note (no code change).

- [ ] **AUD-0017** (Suspicious) — `periodic_gc`. Close as WAI if tracemalloc confirms no leak (move to D first).
- [ ] **AUD-0075** — already Works-as-intended per tracker.
- [ ] **AUD-0123** (Minor/Cleanup) — `_negate_str` Unicode. Close-as-won't-fix per re-triage (see bucket A).
- [ ] **AUD-0134** (Minor/Dup) — journal live-first-fallback. Close-as-WAI (see bucket A).
- [ ] **AUD-0143** (Minor/Cleanup) — default sort. Close-as-WAI (see bucket A).
- [ ] **AUD-0177** (Suspicious) — `diagnose_orphan_legs` already has logging. Close after D verification.

---

## Unclassified (not in any re-triage file)

These tracker items are still `Confirmed` but weren't covered by the three re-triage files — they came from later audit chunks (11, 12, frontend) or from post-pilot work. Listing for awareness; not triaged yet.

Critical:
- AUD-0268, 0269, 0270, 0271, 0272, 0325, 0326, 0327, 0328, 0329, 0341, 0343

Major:
- AUD-0199, 0202, 0224, 0256, 0258, 0259, 0260, 0275 (halted T2a), 0276, 0277, 0278, 0279, 0281, 0294, 0301, 0302, 0303, 0304, 0313, 0315, 0316, 0317, 0318, 0319, 0320, 0321, 0330, 0331, 0333, 0334, 0335, 0336, 0337, 0345, 0346, 0347, 0349, 0350

Minor:
- AUD-0030, 0073, 0322, 0323, 0324, 0338, 0339, 0340, 0352

- [ ] Tick to run a re-triage sub-agent over these unclassified items and produce a chunks-11-12 / tail appendix to this doc.

---

## Summary counts

| Bucket | Items | Action shape |
|---|---|---|
| **A** Quick-yes | ~40 | tick → I batch-execute |
| **B** Pick-one | ~45 choices across ~45 items | pick (a)/(b)/(c) per item → I execute chosen |
| **C** Money/schema | ~15 | tick → I double-confirm then execute |
| **D** Verify first | 13 | tick → I dispatch read-only investigation |
| **E** Clusters | 4 | tick → multi-commit cluster refactor |
| **F** T3 architectural | ~25 | tick → planning session, NOT code ship |
| **G** Close-as-WAI | 6 | tick → tracker flip only |
| **Unclassified** | ~58 | tick the single box to re-triage them |
| **Total still open** | 222 Confirmed + 15 Suspicious = 237 |

**If you want a fast "authorise everything sensible" signal:** ticking all of A + the recommended choice in each B item + the f-string and transaction clusters in E would move the tracker from 35% → ~70% resolved over a 2–3 day autonomous run. That would leave just the T3 architectural work + the genuinely product-level decisions (AUD-0240 self-botting, AUD-0077 Decimal DTOs, etc.) for later.

---

## How to tell me which items to execute

Any of these work:
1. **Edit this file**: tick the checkboxes you want, save, and tell me "start from decisions-pending.md".
2. **Reply inline**: "Start with A, pick (a) for every B, skip C+D+E+F for now."
3. **Pick specific IDs**: "AUD-0084, 0111, 0124, and the f-string cluster — go."

I'll re-read this file, expand the items you've ticked into a plan, propose the first batch slate for confirmation, then dispatch the same sub-agent-per-item serial pattern used for AUD-0241/0165/0136+0144/0213/0242.
