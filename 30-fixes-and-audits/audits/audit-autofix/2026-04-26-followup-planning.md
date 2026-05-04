---
status: planning
generated: 2026-04-26
head-sha: c462004a
tracker: "[[AUDIT_TRACKER]]"
related:
  - "[[decisions-pending]]"
session-context: ".claude/checkpoints/20260426-143041Z.md"
---

# Audit-autofix follow-up planning — 2026-04-26

Consolidated scope for four areas of remaining work, produced from four parallel read-only sub-agent investigations on **2026-04-26** at HEAD `c462004a`. **No code changed in this planning pass.** This doc is decision input for the next batch dispatch.

**Tracker state at production time:** 215 fully Resolved (214 Resolved + 1 Resolved-partial AUD-0272), 155 Confirmed.

---

## 1 · AUD-0078 — resolve the 2 deferred sync sites

AUD-0078 was partially shipped at commit `768c0dc2`. Four of six call sites of `refresh_order_data` moved to FastAPI BackgroundTasks; **two were intentionally left synchronous** because the response immediately reads/updates the row that `refresh_order_data` is responsible for inserting.

### Sites at HEAD

- `lib/tradelens/api/open_orders.py:3003-3022` (`convert_to_limit`) — followed by `UPDATE order_leg_live SET lineage_id, leg_type WHERE exchange_order_id = new`
- `lib/tradelens/api/open_orders.py:4288-4310` (`create_order`) — followed by `SELECT id FROM order_leg_live WHERE exchange_order_id = new`, then leg_type UPDATE + VWAP linkage chain

Both have explicit `# AUD-0078: this call site is INTENTIONALLY synchronous` comments.

### Options

| Option | Risk | Effort | Notes |
|---|---|---|---|
| A — Status quo | Low | 0h | Accept ~10–15s worst-case handler block. Baseline. |
| **B — Inline INSERT + BG full refresh** ⭐ | Med | 3–5h | Insert minimal `order_leg_live` row from Bybit response payload, run lineage UPDATE synchronously, then `background_tasks.add_task(refresh_order_data, ...)`. No schema, no FE. Duplicates classification logic. |
| C — Importable refresh library | Med-High | 8–12h | Extract `OrderClassifier` + `upsert_legs_to_db` to `lib/tradelens/services/order_leg_refresh.py`; in-process call from handler; subprocess kept for cron. Eliminates duplication. |
| D — Defer everything (incl. lineage UPDATE) | High | 6–8h | Response returns "pending" leg_id. Requires FE contract change. **Rejected.** |
| E — Postgres trigger + LISTEN/NOTIFY | High | 5–7h | Schema change; race-safe is hard. **Rejected.** |

### Recommendation

**Ship Option B as the next AUD-0078 follow-up.** Lowest blast radius (no schema, no FE; only 2 sites). If duplication maintenance becomes painful, escalate to Option C as a planned T3-flavored refactor.

### Latent test gap

`tests/integration/test_aud0078_bg_refresh.py` only validates source-text shape (regex scan for the `# AUD-0078: ... INTENTIONALLY synchronous` markers), NOT runtime behaviour. The Option B commit must add unit tests that mock `bybit.create_order()` + `refresh_order_data()` and assert the lineage UPDATE happens before the response.

---

## 2 · AUD-0272 — broader concurrency model

AUD-0272 shipped at `850ff3c3` as `Resolved (partial)`. The audit row's broader recommendation — "**batch upsert OR per-thread connections**" — for `lib/tradelens/mdsync/runner.py`'s "parallel fetch + serial upsert on single PG conn" issue is explicitly NOT addressed and remains open.

### Current state

- 10 fetch worker threads (config-driven via `market_data.tuning.main_loop_workers`, validated via AUD-0272 partial ship)
- ONE Postgres connection for upserts — funneled through `self._store` in `runner.py:151`
- `lib/tradelens/candle_pg/store_pg.py:89-205` does per-candle UPDATE/INSERT in a loop (no batching, no `executemany`, no `COPY`)
- `etc/config.yml`: `database.pool_max: 10`
- AUD-0274 shared rate limiter is module-level `threading.Lock` (per-process, not affected by per-thread connections)

### Bottleneck shape (estimated)

At 10 workers: fetch ~2s wall-time (rate-limit bound at ~5 RPS), upsert ~0.5s (serial, I/O bound). At 50 workers: fetch stays ~2s (still rate-limited), upsert balloons to ~2.5s. Upsert dominates as workers scale.

### Options

| Option | Risk | Effort | Notes |
|---|---|---|---|
| **E — Profile first** ⭐ | Low | 0.5d | Validate upsert IS the bottleneck before structural changes. Instrument `_update_live_candles` with timing logs. |
| **A — Per-thread connections** ⭐ | Med | 2–3d | Each worker acquires from pool. Bump `pool_max: 10 → 20`. AUD-0274 unaffected. |
| B — Batch queue + COPY/multi-row INSERT | Low | 3–4d | Workers feed shared queue; flusher drains in batches. Single connection, bulk-shaped. Adds queue semantics. |
| C — Async PG (asyncpg) | High | 2–3w | T3-sized rewrite. AUD-0274's lock would need to switch to `asyncio.Lock`. **Rejected.** |
| D — Hybrid (A + B) | Med | 4–5d | Per-deployment knob. Coordination complexity. |

### Recommendation

**Ship E → A.** Profile to validate (0.5d), then per-thread connections + pool bump (2–3d). Smallest viable first commit:

1. Refactor `store_pg.py` to acquire connections from pool (lazy)
2. Update `runner.py` to pass `pool` object instead of single conn
3. Increase `pool_max: 10 → 20` in `etc/config.yml`
4. Add timing instrumentation to `_update_live_candles`

### Cross-cut

**AUD-0271** (Bucket C — candle-ingest `ON CONFLICT DO UPDATE` rewrite, money-adjacent) overlaps with this. If AUD-0271 ships first, it will likely add the batch upsert primitives Option B would need. Sequence them: AUD-0271 first, then AUD-0272-broader Option A.

---

## 3 · Bucket C — money-moving / schema (13 still Confirmed)

AUD-0211 already Resolved (shipped 2026-04-25 in batch 1, commit `e50d5894`). The remaining 13 are listed below.

### Tier 1 — No schema, no FE

| AUD | What | Files |
|---|---|---|
| **0271** | Candle-ingest `ON CONFLICT DO UPDATE` batch | `candle_pg/store_pg.py` |
| **0088** | Drop float `round(..., 10)` final in pricing math | `open_orders.py` |
| **0121** | SL-move-inside-lock | `trades.py` |
| **0158** | Unify two fees-to-USD helpers | `refresh_trade_journal.py` |
| **0244** | Single `BEGIN..COMMIT` around Discord idea-create cascade | `discord/idea_creator.py` |
| **0222** | Subprocess refresh in suspend → in-process | `suspend.py` (~lines 969, 1788) |

Each ships in its own isolated worktree per the proven pattern.

### Tier 2 — Schema migrations

All idempotent per AUD-0357 forward-only-policy (commit `a8541535`, see `migrations/076`, `079` as house-style examples).

| AUD | Migration | What |
|---|---|---|
| **0228** | **080** | Add explicit `idea_id` FK on idea→intent→journal linkage |
| **0229** | **081** | State enum column on suspend (idea_state machine) |
| **0280** | **082** | `vwap_config.slots_json` opaque blob → typed columns |

Migration numbers must be re-verified at dispatch time — the parallel session may add migrations between batches.

### Tier 3 — Blocked on AUD-0039

- **AUD-0231** — orderLinkId on resume recreate
- **AUD-0282** — orderLinkId on `vwap_order_engine.amend_order`

Both need the AUD-0039 (a)/(b)/(c) pick to land first.

### Tier 4 — Cluster

**AUD-0217 + AUD-0218** — Transaction cluster (ideas overwrite + AppLock-internal). Already approved as a Bucket E cluster; ship as 1–2 commits.

### Recommended ship order

`0271 → 0088 → 0121 → 0158 → 0244 → 0222 → 0217+0218 → 0228 (mig 080) → 0229 (mig 081) → 0280 (mig 082) → 0231+0282 (after AUD-0039)`

### Sign-off prompts (open questions)

1. **AUD-0088** — confirm "drop the final `round(..., 10)` float rounding entirely"? (CLAUDE.md Decimal policy says yes.)
2. **AUD-0121** — confirm SL-inside-lock + hedge-mode integration test required?
3. **AUD-0158** — golden-file test against ~20 known prod trades?
4. **AUD-0222** — `BackgroundTasks` (mirror AUD-0119) or threading?
5. **AUD-0244** — `BEGIN..COMMIT` per Discord message or per batch?
6. **AUD-0228 + 0229** — backfill strategy: timestamp+symbol+side fuzzy join, or one-time manual reconciliation?
7. **AUD-0039 — UNBLOCKS TIER 3.** Pick:
   - (a) Auto-generate `{trade_id}-{leg_kind}-{ts}` at adapter boundary + require. **Recommended.**
   - (b) Caller-supplied (errors propagate).
   - (c) Keep optional + `cancel_by_order_link_id` helper.

---

## 4 · Bucket F / T3 — architectural planning queue

26 items still Confirmed (AUD-0259 / AUD-0289 already Resolved). Six planning sessions over ~6 weeks recommended.

### Recommended session order

| Session | Items | Why |
|---|---|---|
| **1** | **AUD-0353 + 0354** — Bybit key rotation + git history filter-repo + secret hygiene | Critical/Security; AUD-0353 is "you-only" (destructive git ops); blocks deployment confidence. Claude prepares runbook only. |
| **2** | **AUD-0361** — CI/CD + pre-commit infrastructure | Foundation; gates every subsequent code ship. |
| **3** | **AUD-0332** — vitest bootstrap | Unblocks ~30 frontend T2/T3 items (AUD-0322-0324, 0338-0340, 0308, 0310, 0311, 0314 Phase 2). |
| **4** | **AUD-0002 + 0008** — retry policy/orderLinkId + DB lifecycle convergence | AUD-0002 unblocks Bucket C Tier 3 (0039/0082/0231/0282); AUD-0008 enables clean trades.py rework. |
| **5** | **AUD-0114 + 0115** — trades.py architecture | Money-moving path cleanup. Compensating-cancel contract. |
| **6** | **AUD-0155 + 0170 + 0171** — pipeline state machine + classifier decomp + writer/reader split | Largest architectural chunk. Depends on test coverage from session 3. |

### Quick-wins (single-AUD ship, not full sessions)

- **AUD-0325** — `gcTime: Infinity` literal one-line frontend fix (`frontend/web/src/main.tsx`)
- **AUD-0058 phase-1** — split `initial_risk_calculator.py` AFTER vitest lands (file is recently refactored with good test coverage from AUD-0059, 0052, 0050/0051, 0042, 0071/0072/0074)
- **AUD-0169 phase-1** — additive unit tests for `sessionize_legs` and pipeline mocks; can run in parallel with session 6 planning
- **AUD-0202** — docs-only latency-budget write-up

### Stay parked

- **AUD-0240** — Discord self-botting; product decision, not engineering
- **AUD-0259** — already Resolved (duplicate of 0240)
- **AUD-0260** — defer until AUD-0354 secret-hygiene design lands
- **Tail items** — AUD-0224, 0277, 0312-0321, 0345-0349, 0352, 0360. Defer until foundation lands.

### T3 ↔ Bucket C dependencies

- **AUD-0002** is hard-prereq for Bucket C 0039 / 0082 / 0231 / 0282 — ship in session 4 BEFORE Bucket C Tier 3.
- **AUD-0008** consolidation supports AUD-0114/0115 (Bucket C-flavored trades.py rework).
- **AUD-0361** gates everything regardless of bucket.

### Post-shipped patterns enabling T3 work

- **AUD-0078 / AUD-0119 / AUD-0375** (BackgroundTasks pattern) — applies to AUD-0093 (REFRESH_SCRIPT in-process call) and AUD-0171 (pipeline writer/reader split).
- **AUD-0289** (stale-tick reconciler) — working precedent for async reconciliation sweepers; applies to AUD-0183 (atomic suspend or reconciler sweeper).
- **AUD-0058** can ship Phase 1 incrementally after AUD-0332 (vitest) lands; the file has stabilised through 5+ recent refactors.

---

## Decisions needed from user

In rough priority order (cheapest unblock first):

1. **AUD-0039 (a/b/c) pick** — single architectural decision; unblocks Bucket C Tier 3 (AUD-0231 + 0282). Recommended option (a). Cheapest decision, biggest unblock.
2. **AUD-0078 Option B vs Option C** — confirm Option B (inline INSERT) for next ship, or escalate to C (importable library) for the larger refactor.
3. **AUD-0272 sequence E → A approval** — profile first then per-thread connections + pool bump.
4. **Tier 1 Bucket C ship order confirmation** — `0271 → 0088 → 0121 → 0158 → 0244 → 0222`.
5. **T3 session 1 dispatch (AUD-0353 + 0354)** — Claude prepares runbook for AUD-0353 (key rotation + filter-repo); user executes destructive git operations.

---

## Source

This doc was produced by 4 parallel read-only sub-agent investigations dispatched on 2026-04-26 at HEAD `c462004a`, then synthesised. See `.claude/checkpoints/20260426-143041Z.md` for the full session context, narrative, decisions, rejected approaches, surprises, and verification checklist.
