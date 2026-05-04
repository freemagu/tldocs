---
status: design
generated: 2026-04-27
authors: claude-orchestrator-via-subagent
audit-id: AUD-0202
type: latency-budget
related:
  - AUD-0078 (already-shipped BackgroundTasks pattern for refresh_order_data)
  - AUD-0119 / AUD-0375 / AUD-0222 (BackgroundTasks pattern progressively rolled out)
  - AUD-0271 (already-shipped batch ON CONFLICT for candle upsert)
  - AUD-0272 (mdsync fetch vs upsert profiling — soak data pending)
---

# AUD-0202 — Latency Budget for User-Facing Flows

## Why this doc exists

The April 2026 rolling audit flagged AUD-0202 as a quick-win: TradeLens has
no documented latency yardstick. Past performance work (AUD-0078, AUD-0271)
shipped against gut-feel "this feels slow" baselines. Without a published
budget, future engineers tuning a hot path have no way to tell whether a
700ms median is fine or a regression.

This doc provides the yardstick. The numbers are **targets** (P95, with
median expected at roughly half), not measured baselines — see Section 6
"Known unknowns". The first follow-up to this doc should be adding latency
instrumentation so the budget becomes verifiable.

## 1. User-facing flows + their latency targets

The flows below are derived from the FastAPI route surface
(`tradelens/lib/tradelens/api/`). Each is bucketed by whether a human is
actively waiting on the response.

### Money-moving, user-blocking (user staring at button)

| # | Flow | Handler | Target P95 |
|---|---|---|---|
| 1 | Order placement | `POST /open-orders/create` → `open_orders.py:create_order` (line 3847) | **300 ms** |
| 2 | Order amend | `POST /open-orders/amend` → `open_orders.py:amend_order` (line 1225) | **300 ms** |
| 3 | Order cancel | `POST /open-orders/cancel` → `open_orders.py:cancel_order` (line 689) | **300 ms** |
| 4 | Convert to limit | `POST /open-orders/convert-to-limit` → `open_orders.py:convert_to_limit` (line 2669) | **500 ms** |
| 5 | Trade submit (multi-leg) | `POST /trades/submit` → `trades.py:submit_trade` (line 1261) | **2000 ms** |
| 6 | Suspend / resume / close | `POST /journal/{id}/suspend|resume|close` → `suspend.py` (lines 529 / 645 / 1882) | **1000 ms** |

### Read-only, user-perceived

| # | Flow | Handler | Target P95 |
|---|---|---|---|
| 7 | Portfolio snapshot | `GET /portfolio` → `portfolio.py` (line 17) | **500 ms** |
| 8 | Trade journal page load | `GET /journal` → `journal.py:list_journal` (line 632) | **800 ms** |
| 9 | Candle reads for charts | `GET /journal/{id}/candles/db-closed` + `/candles/live` → `journal.py` (lines 2358, 2552); also `ideas.py` (lines 3619, 3795); `guards.py:884` | **200 ms** |

### Async / not user-facing

| # | Flow | Handler | Target |
|---|---|---|---|
| 10 | Discord ingestion (per message) | `POST /discord-ingest` → `discord_ingest.py` | 2000 ms wall-time |
| 11 | mdsync live-loop cycle | `lib/tradelens/mdsync/runner.py` | 10 s (configured via `market_data.tuning.live_loop_interval_seconds`) |

### Reasoning per target

- **Order placement / amend / cancel — 300 ms.** The user is staring at the
  button. Anything beyond ~300 ms feels broken. The Bybit POST round-trip
  is observed at ~100-200 ms typical; that leaves ~100 ms for our code
  (validation, decimal-safe rounding, inline INSERT, response
  serialisation). The AUD-0078 BackgroundTasks pattern is what makes this
  achievable — without it, the refresh subprocess would dominate.
- **Convert to limit — 500 ms.** Same critical path as cancel + create,
  plus the AUD-0078 Option B inline INSERT (`open_orders.py:3014, 4364`).
  Slightly looser budget because the user understands "convert" is two
  things.
- **Trade submit (multi-leg) — 2000 ms.** Multi-leg sequence places legs
  serially against Bybit. With 4 legs at ~200 ms each = ~800 ms minimum
  for Bybit alone. The 2 s cap leaves room for SL placement (`_place_stop_loss_for_intent` at line 1040), rollback edge cases (`_rollback_placed_entries` at 1177), and DB
  writes. AUD-0114/0115 will refactor `submit_trade` and may shrink this.
- **Suspend / resume / close — 1000 ms.** Money-moving, but the user has
  wound up to the action via the journal UI. They tolerate a brief spinner.
  Bulk variants (`bulk-close`, `bulk-suspend`, `bulk-resume`) are out of
  scope for this budget — they get measured per-item.
- **Portfolio snapshot — 500 ms.** Auto-refresh poll on the dashboard.
  Anything over 1 s degrades the perception of "live".
- **Trade journal page load — 800 ms.** Main tab; the response is
  paginated (`journal.py:list_journal`) and amenable to progressive
  rendering, so a higher cap is acceptable.
- **Candle reads — 200 ms.** Chart pan/zoom triggers these. Users expect
  instant response. Reads come from `market_candle` (PostgreSQL) via
  `lib/tradelens/candle_reader/pg_reader.py`; bytes are local, so 200 ms
  is generous.
- **Discord ingestion — 2000 ms.** End-to-end normaliser → GPT parse →
  DB write. The user (Discord author) does not directly observe this; the
  budget exists so the queue does not back up.
- **mdsync — 10 s.** Per AUD-0272 step E config
  (`etc/config.yml` line 174 region; runner at `lib/tradelens/mdsync/runner.py:884`). The AUD-0272-PROFILE log line is the
  measurement vehicle.

## 2. Component breakdown — order placement critical path

Where does the 300 ms budget for `create_order` go? This is the canonical
breakdown. Numbers are estimates; instrumentation (Section 4) will replace
them with measurements.

```
create_order P95 budget: 300 ms
├── Request validation + auth                         5 ms
├── Decimal-safe price/qty rounding (AUD-0088)        5 ms
├── instrument-info cache hit (AUD-0086)              1 ms
│   (cache miss → Bybit GET                          ~200 ms, rare)
├── BybitClient.place_order POST round-trip       100-200 ms  ← dominant
├── Inline INSERT order_leg_live (AUD-0078 Option B) 10 ms
├── Lineage UPDATE (lineage_id propagation)           5 ms
├── leg_type / VWAP linkage chain                    10 ms
├── BackgroundTasks scheduling (AUD-0078)            <1 ms
├── Response serialisation                            5 ms
└── Headroom                                        ~50 ms
                                                  ────────
                                            total ≈ 250 ms
```

**The dominant cost is the Bybit POST.** Everything we control adds up to
roughly 50 ms at P95, and the headroom absorbs jitter on the Bybit leg.
This is why AUD-0078's deferral of `refresh_order_data` to a
`BackgroundTasks` callback was the highest-leverage perf win in the
project to date — the alternative (subprocess refresh inline) added
seconds.

The same shape (Bybit-RTT-dominated) applies to amend, cancel, and
convert-to-limit. For trade submit, multiply the Bybit RTT by the leg
count — Section 1's 2 s budget is built on that observation.

## 3. Current vs target — where we are today

These are the flows where current behaviour is known to land relative
to the budget. Survey-level only; numbers come from operator observation
and AUDIT_TRACKER notes, not systematic measurement.

### Believed in-budget (no AUD pending)

- **Order placement, amend, cancel.** Post-AUD-0078, the BackgroundTasks
  pattern keeps the synchronous path at Bybit-RTT + ~50 ms. No operator
  complaints since the rollout.
- **Convert to limit.** Pre-AUD-0078 this was up to 15 s due to the
  inline subprocess refresh. After AUD-0078 Option B
  (`open_orders.py:3014`), it sits inside the 500 ms budget.
- **Candle reads (DB-closed path).** AUD-0271 shipped batch
  `ON CONFLICT` for candle upsert, but reads were never the bottleneck
  for this endpoint — PostgreSQL with the candle reader pool is fast
  enough that the budget is met by margin.

### Known to exceed budget (AUD pending)

- **mdsync live-loop cycle.** The whole point of AUD-0272 is the
  premise "upsert dominates". Step E added the AUD-0272-PROFILE
  instrumentation; step A (per-thread connections + pool_max bump) is
  parked pending soak data. Until step A ships, the 10 s live-loop
  target is not consistently hit on busy cycles. See
  `2026-04-26-aud-0272-profiling-soak-operator-note.md`.
- **Trade submit (multi-leg).** AUD-0114/0115 (the trades.py
  architecture refactor) is in design. Current behaviour can spike
  beyond 2 s when SL placement contends with entry placement. Will
  re-baseline after that work lands.
- **Bulk-cancel / bulk-close / bulk-suspend / bulk-resume.** Out of
  this budget by design (per-item budget applies). A separate budget
  for batch operations is a future doc.

## 4. Tools for measuring

The measurement story today is thin. Listed in increasing rigour:

1. **Browser DevTools Network panel.** End-to-end frontend perception.
   Free; captures real user experience. Useful for "does it feel slow?"
   triage, not for P95 baselines.
2. **AUD-0272-PROFILE log lines.** The pattern proven for mdsync —
   structured INFO logs with `time.perf_counter()` deltas, gated on a
   config flag so production overhead is one bool check when off. See
   `lib/tradelens/mdsync/runner.py:884`. This is the model to copy for
   the FastAPI request-latency middleware.
3. **pytest-benchmark for pure functions.** Decimal rounding, WAEP
   tracker, leg-classification logic — anything with no I/O can be
   benchmarked deterministically. Already viable; just not yet wired up.
4. **FastAPI request-latency middleware (NOT YET BUILT).**
   `lib/tradelens/main.py` currently has only the CORS middleware (line
   86). A latency middleware would emit one structured log line per
   request with route, method, status, and elapsed_ms. With a flag
   matching the AUD-0272-PROFILE pattern, it could ship dark and be
   enabled per-soak.

## 5. Roadmap — when to revisit

- **Quarterly cadence.** Re-run the budget against actual P95s once the
  middleware (Section 4 item 4) exists. Anything drifting >2× over
  budget opens an AUD.
- **After AUD-0272 step A.** Re-baseline mdsync. The 10 s target may be
  tightenable once per-thread connections land.
- **After AUD-0114/0115.** Re-baseline `trades.py:submit_trade`. The 2 s
  target may shrink once the architecture refactor lands.
- **After AUD-0002.** Retry policy may add tail latency on flaky
  network. Verify the existing budgets still hold with retries enabled,
  or split into "no-retry P95" and "with-retry P99".

## 6. Known unknowns

- **No systematic P95 instrumentation today.** This budget is a
  target, not a measured baseline. The first follow-up to this doc
  should be adding the FastAPI latency middleware described in
  Section 4 so the budget can be verified rather than assumed.
- **Bybit's published API SLAs vary by region.** The 100-200 ms
  RTT figure is from operator observation, not a Bybit contract.
  Re-validate per region when running soak data.
- **No frontend-side timing.** The budget covers backend response
  time only. Time-to-interactive on the React side is not in scope
  here. Browser DevTools Network panel covers it for now.
- **Cache-miss tail latency for instrument-info.** AUD-0086 cached
  instrument metadata, but the first-hit-per-symbol path still does a
  Bybit GET. The 300 ms order-placement budget assumes a cache hit;
  cold-start order placements may exceed it briefly.
