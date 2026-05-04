---
status: design-ready-for-implementation
generated: 2026-04-26
authors: claude-orchestrator-via-subagent
audit-ids:
  - AUD-0002 (Bybit retry / backoff / rate-limit / circuit-breaker)
  - AUD-0008 (DB-access pattern convergence)
tier: T3
unblocks:
  - AUD-0114 + AUD-0115 (trades.py architecture rework)
  - Bucket C Tier 3 (full orderLinkId-keyed retry pipeline)
related:
  - AUD-0039 (already-shipped orderLinkId at adapter boundary)
  - AUD-0001 (DB pool slot leak, root cause)
---

# AUD-0002 + AUD-0008 — Convergence Design + Phased Plan

> **Documentation only.** This document describes WHAT will ship in each phase
> and WHY. The actual retry / circuit-breaker code in `bybit_client.py` and
> the `PooledDB` → `get_db_connection` migration sweep across `lib/tradelens/api/`
> are deliberately NOT in this commit. Each phase below is a separate future
> commit, pinned for the operator's go-ahead before it lands.

## 0. The audit rows

```
| AUD-0002 | 1 | Critical | Reliability | Confirmed | lib/tradelens/adapters/bybit_client.py | `_request` (and all order/read methods) |
No retry, backoff, rate-limit, or circuit-breaker handling on the sole exchange client. |
Any 429/5xx surfaces as immediate failure; pipeline bursts can trip bans; POSTs without orderLinkId can't be safely retried anywhere upstream. |
Add retry policy for GETs and for POSTs with orderLinkId only; honour `X-Bapi-Limit-Reset-Timestamp`; add circuit breaker. |
Grep: 0 hits for `retry|backoff|rate.limit|429|sleep` in bybit_client.py. |

| AUD-0008 | 1 | Major | Architecture | Confirmed | lib/tradelens/core/ (pg_pool, pg_db, db_pool) | `PooledDB`, `PostgresDB`, `get_db_connection`, shim |
Three overlapping DB-access patterns; API mostly uses the manual-close variant. |
Every handler does manual connect/close; one forgotten close leaks a pool slot (see AUD-0001). |
Delete `PooledDB` and the `db_pool.py` shim; migrate API to `get_db_connection`; keep one direct helper for scripts. |
30+ API files import `PooledDB`; `db_pool.py` self-documents as back-compat shim. |
```

These are paired in the orchestrator's roadmap as a "convergence" cluster:
**AUD-0002 converges retry / rate-limit / circuit policy** (one canonical
shape for every Bybit call); **AUD-0008 converges DB-access patterns** (one
canonical shape for every PG handler). Bucket F (Reliability + Architecture),
Tier T3.

---

## Part A — AUD-0002: Bybit retry / backoff / rate-limit / circuit-breaker

### A.1 Status quo (verified 2026-04-26 against worktree at `22aa1be5`)

`lib/tradelens/adapters/bybit_client.py` (1523 lines):

| Concern | State |
|---|---|
| `_request` definition | `bybit_client.py:339-464` |
| Retry on transient failure | **None.** `httpx.HTTPStatusError` and bare `Exception` both re-raise immediately as `ExchangeError`. |
| Backoff on 429 | **None.** No `time.sleep` anywhere in the file. |
| Rate-limit awareness | **None.** Bybit returns `X-Bapi-Limit-Reset-Timestamp` plus per-endpoint counters in headers; the client reads `response.json()` and discards the headers. |
| Circuit breaker | **None.** No tracking of recent failure rate; every call hits the network unconditionally. |
| Verification command | `grep -niE "retry|backoff|rate.?limit|429|sleep|circuit" lib/tradelens/adapters/bybit_client.py` → **0 hits** (all matches in current code are unrelated string fragments e.g. variable names with "rate" inside). |

POST endpoints that DO carry an orderLinkId today (AUD-0039 shipped; the
adapter boundary always emits an `orderLinkId` for these):

- `place_order` (`bybit_client.py:1001`) — auto-generated via
  `_generate_order_link_id(trade_id, leg_kind)` if caller doesn't pass one
  (`bybit_client.py:1045-1048`).
- `cancel_by_order_link_id` (`bybit_client.py:1322-1355`) — already shipped
  with a docstring referencing **"Required for safe POST retries (AUD-0002):
  when a place_order call times out, the caller knows the orderLinkId it
  generated/passed and can cancel without first reading back the
  exchange-assigned orderId."**

POST endpoints that do NOT carry an orderLinkId today:

- `cancel_order` (`bybit_client.py:1297`) — uses `orderId` only.
- `set_trading_stop` (`bybit_client.py:1153`) — position-level, no order
  identity.
- `amend_order` (`bybit_client.py:1388`) — uses `orderId` only.
- `set_leverage` (`bybit_client.py:727`) — position-level config.
- `clear_position_take_profit` (`bybit_client.py:1357`) — position-level.

### A.2 Net effect today

A 429 mid-pipeline kills the entire refresh batch. A transient 5xx burst
(Bybit periodically degrades during API maintenance) does the same.
Pipeline retry pressure is **upstream of the adapter**, which means callers
either silently swallow the error (data-quality drift) or re-issue without
deduping (double-place risk on `place_order`).

The ALREADY-SHIPPED AUD-0039 orderLinkId enforcement at the adapter boundary
is the prerequisite that makes safe POST retry possible at all — Bybit
dedupes by orderLinkId, so a retried `place_order` with the same orderLinkId
is idempotent on Bybit's side.

### A.3 Design

#### A.3.1 Retry classification

Three classes, dispatched inside `_request` based on `(method, has_order_link_id)`:

| Class | Methods affected | Retry on | Max attempts | Backoff |
|---|---|---|---|---|
| **GET — read-only** | All `GET` calls (balances, positions, klines, executions, orders, etc) | 429, 5xx (500/502/503/504), `httpx.TimeoutException`, `httpx.NetworkError` | 3 | 1s → 2s → 4s, capped by `X-Bapi-Limit-Reset-Timestamp` |
| **POST — idempotent (orderLinkId present)** | `place_order` (AUD-0039 always emits one), `cancel_by_order_link_id` (caller-supplied) | Same as GET | 3 | Same as GET |
| **POST — NOT idempotent** | `cancel_order` (orderId only), `amend_order`, `set_trading_stop`, `set_leverage`, `clear_position_take_profit` | **NEVER retry.** Surface immediately. | 1 | n/a |

Cancel-by-orderId is intentionally non-retryable because Bybit's cancel
endpoint is idempotent on the orderId axis (a second cancel of an
already-cancelled order returns a deterministic error code), but the caller
typically does not have a way to distinguish "first cancel failed
mid-flight" from "second cancel saw cancelled-state" without an extra read.
That distinction is callable by upstream retry orchestration — keep the
adapter conservative.

#### A.3.2 Rate-limit handling

Bybit V5 returns four headers on every successful response:

- `X-Bapi-Limit` — endpoint's per-window quota.
- `X-Bapi-Limit-Status` — quota remaining in the current window.
- `X-Bapi-Limit-Reset-Timestamp` — UNIX-ms when the window resets.
- (varies) — per-account-tier weighting on certain endpoints.

Adapter changes:

1. **Read** `X-Bapi-Limit-Status` and `X-Bapi-Limit-Reset-Timestamp` on every
   response (success path only — error responses may not include them).
2. **Maintain** a per-endpoint sliding window counter keyed by
   `endpoint_path`. The counter is purely advisory — Bybit is the source of
   truth — but it lets the adapter pre-emptively pause when the local view
   says the next request would breach.
3. **On 429**, sleep until `X-Bapi-Limit-Reset-Timestamp` (clamped to the
   retry's max backoff so a misconfigured server clock doesn't park the
   adapter for 30 seconds), then retry per A.3.1.
4. **Pre-emptive throttle**: when `X-Bapi-Limit-Status / X-Bapi-Limit < 0.1`
   (i.e. < 10% quota left), the next call waits until the reset timestamp
   before firing. This is the cheap path that prevents 429 from happening
   in the first place.

Per-endpoint vs global budget — Bybit's quota is per-endpoint-class
(`/v5/order/*`, `/v5/position/*`, `/v5/market/*` each have separate quotas),
so the counter MUST be keyed per-endpoint. A single global budget is wrong
and would over-throttle market-data calls when only `/v5/order/*` is hot.

#### A.3.3 Circuit breaker

Three states per endpoint: **closed** (normal), **open** (fail fast), **half-open** (canary).

Transitions:

- **closed → open**: `5xx_count / total_count > 0.5` over a rolling
  60-second window AND `total_count >= 5` (don't open on 1-of-1 noise).
  When opening, the adapter raises `ExchangeError("circuit open: …")`
  immediately on subsequent calls — no network round-trip — for 30 seconds.
- **open → half-open**: after the 30-second cooldown, the next call is
  allowed through as a canary. If it succeeds, → closed. If it fails (5xx
  or timeout), the cooldown extends with multiplicative backoff (30s, 60s,
  120s, capped at 5 min) and the breaker stays open.
- **half-open → closed**: on the canary's success.

Counters per `endpoint_path`. State stored on the `BybitClient` instance
(per-account, since each account owns its own client) under a `threading.Lock`
so concurrent worker threads can't race on transitions.

Critical safety note: the breaker MUST NOT open on application errors
(retCode != 0 from Bybit's V5 envelope — those are e.g. "insufficient
balance", "leverage not modified"). Only HTTP-layer 5xx and network errors
count. Otherwise a wave of "insufficient balance" errors would open the
breaker and lock out legitimate calls.

#### A.3.4 Layering

The three concerns layer top-down inside `_request`:

```
_request(method, endpoint, params)
    │
    ├── 1. Circuit breaker check (fail fast if open) ──┐
    │                                                  │
    ├── 2. Pre-emptive rate-limit throttle             │
    │                                                  │
    ├── 3. Retry loop (max 3 / max 1 per A.3.1):       │
    │       │                                          │
    │       ├── HTTP call ─────────────────────────────┤
    │       │                                          │
    │       ├── Update rate-limit counter from headers │
    │       │                                          │
    │       ├── Update circuit-breaker state machine ──┘
    │       │
    │       ├── On 429/5xx/timeout & retryable: sleep + continue
    │       │
    │       └── On retCode != 0: raise (NOT counted against breaker)
    │
    └── return result
```

### A.4 Phased plan — AUD-0002

Each phase is one commit with tests, pinned for operator go-ahead.

| Phase | Scope | Estimate | Risk |
|---|---|---|---|
| **A-1** | GET-only retries + exponential backoff. No rate-limit math, no circuit breaker, no POST changes. | 8h impl + 4h tests | LOW — read-only, can't double-spend. |
| **A-2** | Honour `X-Bapi-Limit-Reset-Timestamp` on 429; add per-endpoint sliding-window counter; pre-emptive throttle when < 10% quota. | 12h impl + 4h tests | MED — clock-skew edge cases at minute boundaries; tests must use `freezegun` to pin time. |
| **A-3** | POST retry guarded by `orderLinkId` presence. Strict allowlist (`place_order`, `cancel_by_order_link_id`); explicit denylist for the orderId-keyed methods. | 8h impl + 8h tests | MED-HIGH — a regression here is "duplicate place_order" which costs real money. Tests MUST cover the negative cases (no orderLinkId → no retry). |
| **A-4** | Circuit breaker per A.3.3. State machine + threading lock + cooldown backoff. | 12h impl + 8h tests | HIGH — mis-tuned threshold causes cascade failures. Roll out behind a config flag (`bybit.circuit_breaker.enabled = false` by default for first 1-2 weeks). |

**Order matters** — A-1 ships first because it's the lowest-risk and gives
the test infrastructure (httpx mock with retry simulation) that A-2..A-4
will all reuse.

### A.5 Risks — AUD-0002

1. **Retries mask transient bugs.** A flapping race condition in upstream
   code would have surfaced as an `ExchangeError`; with retries, it surfaces
   as "the second call worked" and the bug stays hidden. Mitigation: emit
   a structured WARNING log on every retry (count + endpoint + cause), plus
   a Prometheus-friendly counter so retry rate is observable.
2. **Rate-limit math edge cases at minute boundaries.** When the reset
   timestamp is 50ms in the future and the adapter sleeps 1s, the next
   window has 950ms of "free" requests that the local counter will
   under-estimate. Mitigation: trust Bybit's headers as the source of
   truth, treat the local counter as advisory.
3. **Circuit breaker cascade.** If multiple endpoints share a common
   upstream failure (e.g. Bybit-wide outage), all breakers open
   simultaneously and the adapter goes silent. That's the correct
   behaviour, but downstream callers must be ready to handle "circuit
   open" gracefully (degraded UI, not a 500). Mitigation: ship A-4 behind
   the config flag; add an explicit `is_healthy()` method on the client
   that callers can poll.
4. **Per-account isolation.** Each `BybitClient` instance has its own
   counters and breaker state. That's intentional (one account hitting its
   limit must not throttle the others), but means the rate-limit
   tracking does NOT detect cross-account quota issues. Bybit's per-IP
   limits are separate from per-account limits; the latter is what we
   track.

---

## Part B — AUD-0008: DB-access pattern convergence

### B.1 Status quo (verified 2026-04-26 against worktree at `22aa1be5`)

Three modules in `lib/tradelens/core/`:

| Module | Lines | Public API | Purpose |
|---|---|---|---|
| `pg_pool.py` | 276 | `init_db_pool`, `get_pool`, `close_db_pool`, `get_db_connection` (context manager), `PooledDB`, `PoolExhaustedError` | The real implementation. ThreadedConnectionPool wrapper. |
| `pg_db.py` | 99 | `PostgresDB` (class) | Direct psycopg2 connection for standalone scripts (no pool). Test seam at AUD-0184 lets tests inject a fixture connection. |
| `db_pool.py` | 29 | Re-exports from `pg_pool` | **Self-documented back-compat shim** — file header says "All new code should import from tradelens.core.pg_pool directly." |

`PooledDB` is defined at `pg_pool.py:200-275`. It tries the global pool
first; if `get_pool()` returns `None` (standalone mode), it falls back to a
direct psycopg2 connection. It exposes `connect()` / `close()` —
deliberately mimicking the old Sybase `PostgresDB` interface for
zero-friction migration in March 2026.

### B.2 Call-site inventory (verbatim from grep, 2026-04-26)

```
$ grep -rn "PooledDB" lib/ bin/ | wc -l
181

$ grep -rln "PooledDB" lib/ bin/ | wc -l
25

$ grep -rln "from tradelens.core.db_pool|from tradelens.core import db_pool" lib/ bin/ | wc -l
30
```

**25 unique files import `PooledDB`** (181 total references including
instantiations, conn=db.connect() lines, and db.close() calls):

`lib/tradelens/api/`: ai_feedback.py, alerts.py, batch_ideas.py,
correlation.py, guards.py, ideas.py, journal.py, notes.py, open_orders.py,
order_sets.py, push.py, screenshots.py, spot.py, stops.py, suspend.py,
tags.py, templates.py, trades.py, vwap.py, vwap_orders.py — **20 files**.

`lib/tradelens/services/`: ai_snapshot.py, push_sender.py,
pushover_sender.py — **3 files**.

`lib/tradelens/core/`: db_pool.py (re-exports), pg_pool.py (defines) — **2 files**.

**30 unique files import from `db_pool` shim** — same set as above plus
five more that import only `get_db_connection` from the shim path
(accounts.py, equity.py, health.py, inbox.py, liquidation.py, portfolio.py,
positions.py — these never instantiate `PooledDB` so they migrate by
changing the import line only). This is the figure the audit row called
"30+ API files".

### B.3 The canonical pattern (existing, already used by some handlers)

```python
from tradelens.core.pg_pool import get_db_connection

def some_handler(...):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT ...")
        result = cursor.fetchall()
        cursor.close()
        return result
```

Reasons this is canonical:

1. **`finally` block in the context manager guarantees `putconn`** even on
   exception — AUD-0001 fixed exactly that bug, and every `PooledDB`
   site is a re-introduction risk for the same pattern.
2. **Discards broken connections** — the context manager catches
   `psycopg2.InterfaceError` and tells the pool to close-rather-than-reuse
   that connection (`pg_pool.py:182-185, 193`). `PooledDB.close()` does
   not, so a broken connection silently rejoins the pool to fail again on
   the next handler.
3. **One pattern is simpler than three.** The current `PooledDB` exists
   purely as a March-2026 migration aid; its job is done.

### B.4 The standalone-script pattern (kept)

For pipeline / daemon scripts running outside FastAPI, where no global pool
exists, `PostgresDB` (in `pg_db.py`) is the right shape: direct psycopg2
connection, owns it, closes it. **Keep this.** It also has the AUD-0184
test seam (inject an external connection that the wrapper does NOT close)
that the rollback-based test fixtures rely on.

### B.5 Phased plan — AUD-0008

Each phase is one or more commits with tests. Migration phases run **batches
of 5 API files** so the diff size per commit stays reviewable.

| Phase | Scope | Estimate | Risk |
|---|---|---|---|
| **B-1** | Audit doc (this file) + spike on one tractable API file (suggest `tags.py` — small surface, low traffic) to validate the migration recipe end-to-end. | 4h impl + 2h tests | LOW |
| **B-2** | Migrate API batch 1 (5 files): tags.py (already migrated in B-1), templates.py, alerts.py, push.py, screenshots.py. | 6h | LOW — all small. |
| **B-3** | Migrate API batch 2 (5 files): correlation.py, vwap.py, vwap_orders.py, order_sets.py, suspend.py. | 8h | MED — some hold connections across helper-function calls. |
| **B-4** | Migrate API batch 3 (5 files): notes.py, journal.py, guards.py, stops.py, spot.py. | 8h | MED |
| **B-5** | Migrate API batch 4 (5 files): ideas.py, batch_ideas.py, ai_feedback.py, open_orders.py, trades.py. | 12h | HIGH — `trades.py` is the AUD-0114/0115 target and is the most complex; do it last so the converged pattern is well-rehearsed. |
| **B-6** | Migrate the three `services/` files: ai_snapshot.py, push_sender.py, pushover_sender.py. Decide per-file: API-context callers → `get_db_connection`; standalone-context callers → `PostgresDB`. | 4h | MED |
| **B-7** | Delete `PooledDB` class from `pg_pool.py:200-275`; delete `db_pool.py`; rewrite `pg_pool.py` module docstring to drop the `PooledDB` line; update CLAUDE.md to remove all `PooledDB` references. | 2h | LOW (after the migration is complete) |

**After each batch**: run the full test suite (`pytest -m "not integration"`
+ targeted integration tests), boot the API locally, smoke-test the
migrated endpoints in the dashboard. Don't proceed to the next batch
until the previous one is green.

### B.6 Migration recipe (the substitution)

The mechanical edit per call site:

```python
# BEFORE
db = PooledDB(config.database, logger)
conn = db.connect()
try:
    cursor = conn.cursor()
    cursor.execute("SELECT ...")
    result = cursor.fetchall()
    cursor.close()
    return result
finally:
    db.close()

# AFTER
with get_db_connection() as conn:
    cursor = conn.cursor()
    cursor.execute("SELECT ...")
    result = cursor.fetchall()
    cursor.close()
    return result
```

Most sites are this clean. The complicated cases:

- **Connections held across function calls.** Some handlers pass `conn`
  to a helper (e.g. `list_trade_intents(conn, ...)` in trades.py:3219).
  These migrate trivially — the helper still takes a `conn`, the
  context-manager just narrows the lifetime. No semantic change.
- **Multiple sequential statements with no transaction boundary** —
  autocommit is set on the pooled connection (`pg_pool.py:48`), so the
  semantic is identical: each statement commits independently. Migration
  is mechanical.
- **Explicit transactions** — anything calling `conn.commit()` or wrapping
  in `BEGIN/COMMIT` needs review. Search: `grep -n "BEGIN\|conn.commit" lib/tradelens/api/*.py` per batch before migrating, flag each occurrence in the batch's commit.

### B.7 Risks — AUD-0008

1. **Lifetime narrowing breaks intentional long-held connections.** If any
   handler holds a connection across a slow operation (HTTP call, file IO,
   long compute), narrowing the lifetime to the `with` block is fine and
   in fact desirable (it returns the slot to the pool sooner). But if the
   handler relies on session-level state (e.g. a SAVEPOINT, a cursor
   created on the same connection that's used later), the migration
   breaks it. Mitigation: per-batch grep for `SAVEPOINT`, `set_session`,
   `set_isolation_level` before migrating.
2. **Test rollback fixtures.** Tests that use `test_db_conn` /
   `test_db_cursor` (from `tests/conftest.py`) inject a connection into
   `PostgresDB` via the AUD-0184 test seam — that path is preserved
   (we keep `PostgresDB`). Tests that mock `PooledDB` directly will need
   updating to mock `get_db_connection`. Per-batch search:
   `grep -rn "PooledDB" tests/`.
3. **Mid-migration churn.** Ongoing PRs touching API files during the
   B-2..B-5 sweep will conflict. Mitigation: batch the migration days
   when no other API work is queued; rebase aggressively.
4. **Forgotten import lines.** After B-7 deletes `PooledDB` and `db_pool`,
   any unmigrated import will fail at import time. CI must run a smoke
   import of every module. Add to AUD-0361's pre-commit work:
   `python -c "import tradelens.api.<each>"`.

---

## Part C — Cross-cutting

### C.1 Order of work

**B BEFORE A**, if convenient. Reasoning:

- AUD-0008's deliverable is a migration sweep — mostly mechanical, low risk
  per phase, easy to roll out incrementally.
- AUD-0002's tests are easier to write against the converged DB pattern
  (test fixtures already use `PostgresDB`, the kept module).
- AUD-0008 unblocks AUD-0114/0115 (trades.py rework) which is independent
  of AUD-0002.

But the order is not strict — A-1 (GET retries) is small and self-contained
and could ship in parallel with B-2..B-3.

### C.2 Test infrastructure dependencies

- AUD-0002 needs `httpx` mock with retry simulation. `respx` is already a
  dev dependency (`pyproject.toml`), so no new infra needed.
- AUD-0002 A-2 needs time control (`freezegun`) for rate-limit reset
  tests. NOT currently a dep — add to `pyproject.toml [project.optional-dependencies].dev`
  in phase A-2's commit.
- AUD-0008 reuses the existing `test_db_conn` / `test_db_cursor` fixtures.
  No new infra.

### C.3 Observability

Both audits should emit structured logs that downstream tooling (existing
`logs/` directory or future Prom exporter) can scrape:

- AUD-0002: `bybit.retry`, `bybit.rate_limit_throttle`, `bybit.circuit_open`,
  `bybit.circuit_close` events with endpoint, attempt, cause.
- AUD-0008: `db.pool_acquire_blocked` (already exists at WARNING level)
  unchanged.

### C.4 Rollback plan

- AUD-0002: each phase is gated by config flag (`bybit.retry.enabled`,
  `bybit.circuit_breaker.enabled`); flipping to `false` disables the new
  behaviour without rolling back the code.
- AUD-0008: per-batch revert is a single `git revert` of that batch's
  commit; the back-compat shim (`db_pool.py`) stays in place until B-7,
  so any partial-migration revert leaves the codebase in a working state.

---

## D. Open questions worth escalating

1. **AUD-0002, per-endpoint vs global rate-limit budget** — the design picks
   per-endpoint (matching Bybit's actual quota structure). Confirm this is
   the operator's preference; the alternative (single global budget) is
   simpler but over-throttles market-data calls when only `/v5/order/*` is
   hot.
2. **AUD-0002, circuit-breaker initial threshold** — the design picks 50% /
   60s / min 5 requests as a permissive starting point. Aggressive
   alternatives (20% / 30s / min 3 requests) would open the breaker
   sooner but risk false positives during routine Bybit hiccups.
3. **AUD-0002, A-3 POST retry rollout strategy** — should the first
   production rollout limit POST retries to `place_order` only (the
   highest-value retry case) and add `cancel_by_order_link_id` in a
   follow-up? Or ship both at once?
4. **AUD-0008, batch boundaries** — the proposed 5-file batches are by
   alphabetical groupings, not by traffic-volume or business-criticality.
   If the operator prefers risk-weighted batches (lowest-traffic first),
   the batch list re-orders.
5. **AUD-0008, services/ batch (B-6)** — `push_sender.py` and
   `pushover_sender.py` are sometimes invoked from API context,
   sometimes from standalone scripts. Decide: split each into two
   call-paths, or always use `PostgresDB` (paying the no-pool cost in
   API context), or always use `get_db_connection` (failing in
   standalone context)?

---

## E. References

- `lib/tradelens/adapters/bybit_client.py:339-464` — `_request` method
  that gets the retry/circuit/rate-limit wrapper.
- `lib/tradelens/adapters/bybit_client.py:1322-1355` — `cancel_by_order_link_id`,
  already-shipped POST-retry-safety primitive (AUD-0039).
- `lib/tradelens/core/pg_pool.py:156-198` — `get_db_connection` context
  manager (the canonical pattern).
- `lib/tradelens/core/pg_pool.py:200-275` — `PooledDB` class (to delete in B-7).
- `lib/tradelens/core/pg_db.py:26-99` — `PostgresDB` class (to keep).
- `lib/tradelens/core/db_pool.py` — back-compat shim (to delete in B-7).
- AUDIT_TRACKER.md — cluster classification (T3 / Bucket F).
- `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0361-cicd-design.md`
  — the pre-commit + CI infra that will run the new test files.

---

**End of document.** Implementation phases are separate commits, pinned for
operator go-ahead.
