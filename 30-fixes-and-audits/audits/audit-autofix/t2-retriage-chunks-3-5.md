# T2 re-triage — chunks 3-5
**Generated:** 2026-04-24
**Scope:** 66 T2 items from `triage_chunks_3-5.md`
**Source:** `/app/syb/tradesuite/tradelens/research/audit_autofix/triage_chunks_3-5.md`
**Tracker:** `/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md`

## Counts

| Bucket | Count |
|---|---|
| **T2a** (auto-execute-safe) | 7 |
| **T2b** (design-required) | 59 |
| **Total** | 66 |

Low T2a ratio is by design for chunks 3-5. The money-moving critical paths dominate
(`api/open_orders.py`, `api/trades.py`, pipeline writers). Most T2 items either:
- Sit in the primary-writer order/submission path (>50% of chunk 3-4 items);
- Belong to one of two explicit coupled clusters the user asked us to skip:
  - **f-string-SQL cluster:** AUD-0147 / 0148 / 0149 / 0157 / 0160 / 0174 (six items skipped outright);
  - **Transaction cluster:** AUD-0118 / 0150 / 0162 / 0163 (four items skipped outright).
- Or are architectural refactors dressed as T2 (`split …`, "unify submit paths", "state machine").

The 7 T2a items are strictly additive (logging, dead-code removal, or trivial parameterization
outside the money-moving path) with canonical answers and no user-visible change.

---

## T2a — auto-execute queue (7)

Grouped by file. Each entry: AUD-ID, severity, exact fix, regression-test shape,
verification notes.

### `lib/tradelens/api/open_orders.py`

#### AUD-0099 — Minor / Cleanup — remove dead `missing_trade` linkage branch

**Exact fix:** Delete the two lines at `open_orders.py:506-507`:

```python
if linkage_lower == 'missing_trade' and 'MISSING_TRADE' not in flags:
    continue
```

Then remove `missing_trade` from the Query() `description` string at line 330 so the
OpenAPI doc/Swagger no longer advertises it.

**Why T2a, not T2b:** The audit phrased "Remove or wire up flag" as two choices. I verified
the flag cannot be wired up to the current data model without inventing a new semantic:
`compute_health_flags` (lines 238-285) has no branch that would emit `MISSING_TRADE` —
every absent-trade is already covered by `UNLINKED` (line 275) or `CLOSED_TRADE` (line 277).
"Remove" is the honest answer. Frontend has the value in a TypeScript literal union
(`frontend/web/src/lib/api.ts:1601`) but **no UI component actually issues `linkage=missing_trade`**
(grep-verified — only type union, no call site). Removing the type literal in api.ts is a
companion frontend-styling-exempt edit.

**Regression test:** `tests/unit/test_open_orders_linkage_filter.py` — parameterize over
`linkage in ('linked','unlinked','missing_trade','closed_trade')`, hit endpoint, assert
400 for unknown values (including the now-removed `missing_trade`). Covers: "regression
would be accidentally re-adding the branch".

**Verification notes:** Grep-verified `MISSING_TRADE` appears in open_orders.py in exactly
ONE place — the now-to-be-removed filter check at line 506. `compute_health_flags` is at
line 238-285 and never appends `MISSING_TRADE`. Frontend uses `missing_trade` in the
TypeScript literal union only; no UI callers — verified via recursive grep.

---

### `lib/tradelens/api/journal.py`

#### AUD-0135 — Minor / Cleanup — public connection accessor on PgCandleReader

**Exact fix:** Add a public property on `PgCandleReader` in
`lib/tradelens/candle_reader/pg_reader.py`:

```python
@property
def conn(self):
    """Public read-only accessor for the underlying psycopg2 connection."""
    return self._conn
```

Change `conn = reader._conn` at `journal.py:1171` to `conn = reader.conn`.

**Why T2a:** Zero external callers of `reader._conn` outside `journal.py:1171` (grep-verified).
The underscore crosses a module boundary but the fix is additive — a new property and
one rename. Behavior-identical. `PgCandleReader.__init__` already holds the connection
(`self._conn = conn` at line 29) and the connection is used internally (lines 81, 119,
160, 188, 230, 258).

**Regression test:** `tests/unit/test_pg_reader_conn_accessor.py` — instantiate PgCandleReader
with a sentinel connection, assert `reader.conn is sentinel`, assert the `.conn` property
does not release/close.

**Verification notes:** Single external caller (`journal.py:1171`). No setter needed — reader
is treated as read-only for its `_conn` field elsewhere in the codebase. No thread-safety
implication since we're not exposing anything the caller couldn't already reach by
accident with `_conn`.

---

### `bin/pipeline/refresh_order_leg_live.py`

None. Every remaining `refresh_order_leg_live.py` T2 item touches `upsert_legs_to_db` or
the stale-cleanup block which both sit inside the AUD-0147 refactor boundary or the
AUD-0165 archive-all-on-empty hazard. Leaving all to T2b.

---

### `bin/pipeline/refresh_trade_journal.py`

#### AUD-0161 — Major / Dead Code — delete `_validate_and_escape_order_id` helper

**Status caveat:** Today this helper has exactly 1 live caller at line 2687. The helper
is only needed because the surrounding code interpolates the order_id into an f-string
SQL. Technically AUD-0161 is **deleteable only AFTER AUD-0148 lands** and parameterizes
that one call site. **This is why I'm flagging it in T2a with a sequencing note** — it is
safe-to-delete the moment AUD-0148 lands, and the verification is purely mechanical:
"grep shows zero callers → delete".

**Exact fix (to be queued, not executed now):** Once AUD-0148 lands, delete the helper
(lines 2477-2504) and verify via `grep -rn _validate_and_escape_order_id` that no
references remain.

**Why T2a (deferred execution):** After AUD-0148 the fix is literally "grep-verify zero
callers and remove 27 lines." No design remains. I'm listing it here so the execution
sub-agent can queue it immediately after the cluster-commit that lands AUD-0148, rather
than re-triaging.

**Regression test:** Post-removal, grep assertion in `tests/unit/test_no_dead_helpers.py`
(can piggyback on existing patterns) that `_validate_and_escape_order_id` does not exist
in refresh_trade_journal.py.

**Verification notes:** Grep shows exactly one caller at line 2687 today. Adding
parameterization to that single call site removes the caller → helper becomes dead.

---

### Low-risk additive logging (narrow-interpretation fixes)

#### AUD-0164 — Major / Reliability — surface R-metric-failure flag (narrow interpretation)

**Exact fix:** In `process_sessions` at line 2897-2904 of `refresh_trade_journal.py`:
on the existing silent-fallback path, add a `logger.warning(...)` with the session key
(symbol, side, opened_at) + exception. DO NOT change control flow. DO NOT fail the pipeline.

**Why T2a (narrow):** The audit asks "Fail loudly OR surface flag." Failing loudly changes
the pipeline error surface (T2b design question — same class AUD-0043 handled). But
"surface flag" can mean "log a warning" which is strictly additive and a zero-risk subset.
If the user later decides on hard-fail or a `partial_metrics` DB column, the warning
persists as belt-and-suspenders.

**Regression test:** `tests/unit/test_refresh_trade_journal_metric_warn.py` — stub
`calculate_initial_risk` to raise, assert process_sessions logs a WARNING and the session
is still persisted (behavior unchanged). Matches pattern from pilot chunks (AUD-0052-style
logging tests).

**Verification notes:** `refresh_trade_journal.py:2897-2904` currently has a bare `except`
with a `pass`. Adding `logger.warning(...)` inside the same block is purely additive.

---

### Mechanical same-class parameterization

#### AUD-0160 — Major / Security — `symbols_in` → `%s` tuple in `reconcile_spot_sessions_with_exchange`

**Wait** — this is in the f-string-SQL cluster. Per the user's constraint, AUD-0160 goes to
T2b as part of the cluster. **Moved to T2b.**

Skip here.

---

### `bin/pipeline/refresh_trade_journal.py` — suspicious-verified diagnostic

#### AUD-0177 — Minor / Suspicious — `diagnose_orphan_legs` (narrow interpretation)

**Note:** Already partially addressed. `diagnose_orphan_legs` at line 3053-3143 already
calls `logger.info` (line 3106) / `logger.warning` (line 3126) / `logger.debug` (line
3135-3137). The proposed "narrow T1 add a DEBUG summary log" from the original triage
is vacuous — it's already there.

**Honest call:** Demote to T2b. The real fix is the structural sessionization work.
A DEBUG log that already exists is not worth a commit.

**Moved to T2b.**

---

### Final T2a count: 4 net (AUD-0099, AUD-0135, AUD-0161 deferred, AUD-0164 narrow)

Note: I had tentatively counted 7 earlier, but on verification:
- AUD-0160 is in the skip cluster (f-string SQL) → T2b
- AUD-0177's "narrow interpretation" is vacuous (already done) → T2b
- AUD-0146 (markdown formatter out of router) — dithered; single caller, but moves code
  to a new module. Triage rule "no public API signature change with >2 external callers"
  lets this through (callers inside same file). **Added as T2a below.**

Revised final T2a count: **5**.

Adding:

#### AUD-0146 — Minor / Cleanup — move `generate_execution_result_note` to `services/note_formatters.py`

**Exact fix:** Create new module `lib/tradelens/services/note_formatters.py` with
`generate_execution_result_note` copied verbatim. In `trades.py`, replace the function
definition (lines 57-98) with a one-line import: `from tradelens.services.note_formatters
import generate_execution_result_note`.

**Why T2a:** Grep-verified exactly 1 caller (`trades.py:128`). Move is behavior-identical,
no signature change, no schema change. Creates a new file (OK — services/ pattern
established). No test drift.

**Regression test:** Existing test `tests/unit/test_trades_limit.py` covers the caller.
Add `tests/unit/test_note_formatters.py` snapshot test: pass a sample `order_legs` list,
assert the returned markdown matches the existing format verbatim.

**Verification notes:** Caller: `trades.py:128`. No external callers anywhere in the
codebase. `services/` directory exists with sibling modules (`portfolio.py`, `sizing.py`,
`leverage.py` per CLAUDE.md, `idea_attachments.py`, etc.).

---

## T2a final list (5 items)

| AUD-ID | File | Severity | Risk | Notes |
|---|---|---|---|---|
| AUD-0099 | api/open_orders.py | Minor/Cleanup | Low | Delete dead branch + Query description + frontend TS literal |
| AUD-0135 | candle_reader/pg_reader.py + api/journal.py | Minor/Cleanup | Low | Public `.conn` property, one external caller |
| AUD-0146 | api/trades.py → services/note_formatters.py | Minor/Cleanup | Low | Move formatter out of router (1 caller) |
| AUD-0161 | pipeline/refresh_trade_journal.py | Major/Dead Code | **Deferred** | Execute ONLY after AUD-0148 lands |
| AUD-0164 | pipeline/refresh_trade_journal.py | Major/Reliability | Low | Add `logger.warning` on silent R-metric failure (narrow interpretation; NO control-flow change) |

---

## T2b — design-required (61)

### api/open_orders.py (chunk 3) — 22 items

| AUD-ID | Severity | Two+ reasonable answers | Recommendation |
|---|---|---|---|
| **AUD-0078** | Critical/Perf | (a) In-process call; (b) FastAPI `BackgroundTasks`; (c) external queue. Different blast radii. 6 call sites. | **Pick (b) BackgroundTasks first** — lowest blast radius, preserves current process-isolation semantics, trivially reversible. Pairs well with AUD-0119. |
| **AUD-0079** | Critical/Perf | (a) Add `cancel_batch` to BybitClient adapter; (b) keep serial but drop per-order refresh; (c) SDK swap. | **(a)** Batch endpoint — huge user-facing perf win. Adapter extension is bounded. |
| **AUD-0080** | Critical/Bug | (a) Refuse on ticker failure; (b) explicit `i_accept_the_risk` override; (c) require amend-side-of-current-price in request. | **(a) refuse** — Bybit unreliability is exactly when the safety check matters. User can retry. |
| **AUD-0081** | Critical/Reliability | (a) Add `AppLock` per-leg; (b) Bybit `orderLinkId` idempotency alone; (c) both. | **(c) both** — they solve orthogonal races (double-click ≠ retry). |
| **AUD-0082** | Critical/Reliability | (a) Auto-gen at adapter; (b) at router; (c) passed by caller. Blocked on AUD-0002 (chunk-1 T3). | **(a) adapter** — single source; blocked-on note acknowledged. |
| **AUD-0083** | Critical/Reliability | (a) Transaction wrap; (b) reorder insert-first. Both needed. | **Both.** Keep as single T2b proposal. |
| **AUD-0084** | Critical/Security | (a) Generic detail + correlation ID; (b) classify-and-sanitize per error type; (c) keep verbose in dev, sanitize in prod. 8 sites. | **(a)** — generic + correlation ID. Ops grep the log by correlation ID. |
| **AUD-0086** | Major/Perf | (a) TTL cache; (b) preload-at-startup; (c) LRU. | **(a) TTL ~5min** — matches Bybit instrument-update cadence. |
| **AUD-0087** | Major/Arch | (a) Pass `bybit` through; (b) make `get_tick_size` take a client factory; (c) module-level cache keyed by account. 11 callers. | **(a)** — simplest, most local reasoning. |
| **AUD-0088** | Major/Bug | Full Decimal pipeline. Only Q: keep `round(..., 10)` final-rounding or not? | **Drop the float `round`** — Decimal-only. Money-moving, needs careful test. |
| **AUD-0089** | Major/Bug | (a) Add `side` / `leg_type` inputs; (b) pass full `Leg`. 6+ callers. | **(a)** — minimal new args; coordinates with AUD-0122 (same refactor across files). |
| **AUD-0090** | Major/Cleanup | Single BybitClient at handler top vs per-sub-call. | **Single top** — 4 amend paths. |
| **AUD-0091** | Major/Bug | (a) Expand "stop-like" set; (b) per-leg-type policy; (c) treat qty≥position as stop regardless of type. | **(c)** — matches risk semantics, not syntactic type. |
| **AUD-0092** | Major/Bug | (a) Require explicit leg_type; (b) keep auto-relabel but log; (c) deprecate auto-relabel over 2 releases. | **(a) require explicit** — surfaces caller intent. |
| **AUD-0094** | Major/Bug | Unify via helper. Only Q: which of the two current behaviors is correct? | **Decide on `preview_order` semantics as canonical** (grep shows it's the newer path); port `preview_amend_order` to match. |
| **AUD-0095** | Major/Arch | (a) `close_entire: bool` flag; (b) `qty: Optional[Decimal] = None`. | **(a)** — explicit intent. |
| **AUD-0097** | Major/Cleanup | Fixed-column INSERT vs current dynamic SET. | **Fixed columns** — simpler, no literal-SQL mixing. |
| **AUD-0098** | Major/Reliability | "Local DB primary writer" — depends on AUD-0078 outcome. | **Defer** — blocked on AUD-0078 decision. |
| **AUD-0100** | Minor/Cleanup | `reduce_only` VARCHAR(5) → BOOLEAN migration — **schema change**, affects 3 tables. | **Defer** — schema change with migration, not T2a. |
| **AUD-0101** | Minor/Bug | `_price_decimals` via Decimal or keep float+scientific workaround. | **Decimal** — matches codebase-wide policy (per `CLAUDE.md` MEMORY). 2 sites. |
| **AUD-0102** | Minor/Security | Same-class as AUD-0084; 4 sites in open_orders.py amend paths. | **Bundle with AUD-0084 — one sanitization policy.** |
| **AUD-0103** | Minor/Bug | Decimal compare vs keep float with tolerance. | **Decimal** — per CLAUDE.md policy. |
| **AUD-0105** | Minor/Bug | Add pre-placement ticker check = new 4xx. User-facing failure mode. | **Add it** — matches AUD-0080 policy consistency. |
| **AUD-0106** | Minor/Reliability | Raise-on-unknown vs keep fallback + warn. Hot-path behavior change. | **Raise** — sized-at-wrong-precision bugs are worse than a clean 4xx. |
| **AUD-0108** | Minor/Dup | Extract view vs CTE vs copy-paste. | **CTE in same file first** — view coupling to schema migration is heavier. |
| **AUD-0109** | Minor/Cleanup | Tighten no-op amend to 400. User-visible contract change. | **Tighten** — silent no-op is a bug shape. |

### api/trades.py + api/journal.py (chunk 4) — 21 items

| AUD-ID | Severity | Two+ reasonable answers | Recommendation |
|---|---|---|---|
| **AUD-0111** | Critical/Arch | (a) Redis TTL; (b) atomic preview+submit; (c) DB-backed cache. | **(b) atomic preview+submit** — avoids Redis dependency entirely, simplest. |
| **AUD-0112** | Critical/Security | Identity model doesn't exist today. (a) Bind preview to account-only; (b) build identity model; (c) ship as-is with audit log. | **(a) bind to account-only** as stop-gap — covers 99% of attack. |
| **AUD-0113** | Critical/Security | (a) Whitelist fields; (b) merge with submit_trade. | **Merge with submit_trade** (= AUD-0127) — one policy, one code path. |
| **AUD-0115** | Critical/Arch | Route all placements through typed adapter helpers. | **Do it** — coordinates with AUD-0006/AUD-0036. |
| **AUD-0117** | Critical/Perf | (a) Async; (b) WebSocket push. | **(a) async** — keeps control flow linear; WS adds infra. |
| **AUD-0118** | Major/Reliability | Transaction cluster (AUD-0118/0150/0162/0163) **— skip per user constraint**. | **Cluster T3.** |
| **AUD-0119** | Major/Perf | (a) `BackgroundTasks`; (b) message queue. | **(a)** — coordinates with AUD-0078. |
| **AUD-0120** | Major/Perf | Row-grows-forever vs event-typed new row per exec. | **Event-typed new row** — matches journal-as-event-log semantics. |
| **AUD-0121** | Major/Bug | Move SL to post-entry step. Only Q: keep SL inside lock or release lock? | **Inside lock** — prevents window where position exists without stop. |
| **AUD-0122** | Major/Dup | Same refactor as AUD-0089 — one shared helper. | **Bundle with AUD-0089.** |
| **AUD-0123** | Major/Cleanup | Tuple-key vs keep `_negate_str`. UX drift risk. | **Keep `_negate_str`** — behavior is correct; readability burden does not justify subtle ordering-drift risk. (CLOSE as won't-fix? — reviewer call.) |
| **AUD-0124** | Major/Perf | Batched `IN (...)` vs single LATERAL join. | **Batched IN** — simpler, same perf. |
| **AUD-0125** | Major/Perf | (a) LATERAL JOIN; (b) materialized view refreshed on 5m candle. | **(a) LATERAL** — no staleness. |
| **AUD-0127** | Major/Arch | Same as AUD-0113 — merge submits. | **Bundle with AUD-0113.** |
| **AUD-0128** | Major/Arch | Move to `services/leverage.py`. | **Do it** — 2 callers; clean extraction. |
| **AUD-0129** | Major/Cleanup | Query builder lib vs named-placeholder dict. | **Named-placeholder dict** — no new dep. |
| **AUD-0131** | Minor/Cleanup | Evict on submit vs TTL. | **Moot after AUD-0111 (atomic preview+submit).** |
| **AUD-0134** | Minor/Dup | UNION vs keep live-first-fallback. | **Keep live-first-fallback** — semantics are load-bearing (live price wins). UNION changes order. |
| **AUD-0136** | Minor/Cleanup | `NoteEventType` enum — touches 10+ files (grep-verified). | **Do it, but as single commit** — mechanical once agreed. (Could be T2a if we treat SQL-literal find-and-replace as safe.) |
| **AUD-0137** | Minor/Cleanup | Split `JournalListItem`. API response shape change. | **Do it, but coordinate with frontend** — optional fields stay optional at type level. |
| **AUD-0138** | Minor/Cleanup | Generate from schema vs keep manual + lint. | **Keep manual + add lint** — schema inflection is heavy. |
| **AUD-0140** | Minor/Suspicious | Tracker "Needs verification". | **Verify first** — per-endpoint audit. |
| **AUD-0142** | Minor/Suspicious | Tracker "Needs verification". | **Verify first** — money-moving on submit. |
| **AUD-0143** | Minor/Cleanup | UX-visible default sort drift. | **Keep current default** (no change) — users are accustomed. |
| **AUD-0144** | Minor/Cleanup | Duplicate of AUD-0136 from journal-side. | **Bundle with AUD-0136.** |
| **AUD-0145** | Minor/Cleanup | "pending_entry" in conflict check — bug or design? | **Audit first** — tracker flagged it as a bug-shape question. |

### bin/pipeline/ (chunk 5) — 18 items

| AUD-ID | Severity | Two+ reasonable answers | Recommendation |
|---|---|---|---|
| **AUD-0147** | Critical/Security | Full parameterization of `upsert_legs_to_db`. **Cluster.** | **Cluster commit** — 0147+0148+0149+0157+0160+0174 as single refactor. |
| **AUD-0148** | Critical/Security | Same cluster. | **Cluster.** |
| **AUD-0149** | Critical/Security | `.replace()`-based SQL mutation — rewrite WHERE with %s. | **Cluster.** |
| **AUD-0150** | Critical/Reliability | Transaction cluster. | **Cluster T3 or bundle with AUD-0147 rewrite.** |
| **AUD-0152** | Critical/Bug | `is not None` vs truthy. Schema semantics change (UI "N/A" → "$0.00"). | **`is not None`** — audit is right; "0 is valid data" is the honest semantic. User-visible UI change is positive. |
| **AUD-0153** | Critical/Bug | Same class as AUD-0152 for `category`. | **Bundle with AUD-0152.** |
| **AUD-0154** | Major/Perf | `INSERT ... ON CONFLICT DO UPDATE` batch vs keep per-leg. | **ON CONFLICT batch** — primary-writer perf win. Heavy rewrite. |
| **AUD-0155** | Major/Arch | Formal state machine vs keep 3 exceptions. | **Keep + document** — state machine refactor is structural; 3 exceptions are enumerable. |
| **AUD-0156** | Major/Suspicious | Tracker "Needs verification". | **Verify first** — thread safety of `httpx.Client` across executors confirmed via tests. |
| **AUD-0157** | Major/Security | Cluster. | **Cluster.** |
| **AUD-0158** | Major/Dup | Unified fees-to-USD helper. Money-moving. | **Do it but carefully** — golden-file test against known trades first. |
| **AUD-0160** | Major/Security | Cluster. | **Cluster.** |
| **AUD-0161** | Major/Dead Code | **Listed in T2a (deferred).** | — |
| **AUD-0162** | Major/Reliability | Transaction cluster. | **Cluster.** |
| **AUD-0163** | Major/Reliability | Transaction cluster. | **Cluster.** |
| **AUD-0164** | Major/Reliability | **Listed in T2a (narrow).** | — |
| **AUD-0165** | Major/Reliability | "1=1 wipes everything" bug. (a) Distinguish empty-vs-failed with a sentinel; (b) refuse to delete when fetch returned empty + zero count; (c) require positive-confirmation. | **(a) sentinel** — Bybit returns explicit "ok empty" vs fetch-failed; distinguish these. |
| **AUD-0166** | Major/Reliability | Batch archive. Primary-writer structural change. | **Coordinate with AUD-0154 rewrite.** |
| **AUD-0167** | Major/Perf | Pool vs persistent daemon. | **Pool first** (lower blast radius). Daemon if pool insufficient. |
| **AUD-0168** | Major/Arch | Shared `_lib/` across 3 pipeline scripts. 3-file refactor. | **Promote to T3.** |
| **AUD-0169** | Major/Test Gap | Unit tests for pipeline scripts. | **Sizeable task** — test-creation, structural, T3-shape. |
| **AUD-0170** | Major/Arch | `OrderClassifier` decomposition — 6+ state maps. | **Promote to T3.** |
| **AUD-0171** | Major/Arch | Writer/reader split. Cross-chunk. | **Promote to T3.** |
| **AUD-0174** | Minor/Security | Cluster. | **Cluster.** |
| **AUD-0176** | Minor/Cleanup | Merge 3 overlapping classifier maps into typed dataclass. | **Do it** — post-T3 decomposition (AUD-0170). |
| **AUD-0177** | Minor/Suspicious | Already logging; structural fix is T3. | **T3.** |
| **AUD-0178** | Minor/Cleanup | Diff-based upsert vs DELETE+INSERT. FK-cascade implication. | **Diff-based** — subscribers see less churn. Mild rework. |
| **AUD-0179** | Minor/Cleanup | Explicit PRIORITY precedence + assertion. Changes silent-drop → loud-fail. | **Assertion** — surface inconsistencies. |

---

## Execution plan — T2a batches grouped by file

### Batch A: `api/open_orders.py` (1 finding)

1. **AUD-0099** — Remove dead `missing_trade` branch (lines 506-507 + line 330
   description) + companion frontend TS-literal edit (`frontend-styling` exempt).

   Baseline test: existing `tests/unit/test_open_orders_helpers.py`.
   New test: `tests/unit/test_open_orders_linkage_filter.py` — parameterize over
   remaining valid linkage values; unknown values (including `missing_trade`) return 400.
   Commit: `cleanup(api/open_orders): AUD-0099 — remove dead missing_trade linkage branch`.

### Batch B: `candle_reader/pg_reader.py` + `api/journal.py` (1 finding)

2. **AUD-0135** — Add public `.conn` property + rename `_conn` access at journal.py:1171.

   Baseline test: `tests/unit/test_pg_reader_conn_accessor.py` (new).
   Commit: `cleanup(candle_reader): AUD-0135 — public conn accessor on PgCandleReader`.

### Batch C: `api/trades.py` → `services/note_formatters.py` (1 finding)

3. **AUD-0146** — Move `generate_execution_result_note` to new module, one-line import.

   Baseline test: existing `tests/unit/test_trades_limit.py` (still passes).
   New test: `tests/unit/test_note_formatters.py` — snapshot test on sample input.
   Commit: `refactor(services): AUD-0146 — extract note_formatters from api/trades`.

### Batch D: `pipeline/refresh_trade_journal.py` narrow log (1 finding)

4. **AUD-0164** — Add `logger.warning` on silent R-metric failure (no control-flow change).

   Baseline test: `tests/unit/test_refresh_trade_journal_metric_warn.py` (new) — stub
   calc to raise, assert WARNING logged and session persists.
   Commit: `cleanup(pipeline): AUD-0164 — surface R-metric failure via warning`.

### Batch E: Post-cluster dead-code removal (1 finding, deferred)

5. **AUD-0161** — DEFERRED. Execute ONLY after AUD-0148 cluster commit has landed.
   Grep-verify zero callers, delete `_validate_and_escape_order_id` helper (lines
   2477-2504).

   Commit: `cleanup(pipeline): AUD-0161 — remove dead _validate_and_escape_order_id`.

### Sequencing note

Batches A/B/C/D are independent and can land in parallel (separate files). Batch E is
gated on the independent T2b AUD-0148 cluster commit.

Total T2a commits: **5**. Estimated commit work: low (< 100 LOC diff each except E).

---

## Borderline and cross-chunk dependencies

### Borderline (grep confirmed; held at T2b)

- **AUD-0123** — `_negate_str` Unicode flip. Refactor is behavior-equivalent but risks
  subtle sort drift users have memorized. Triage said "T2 (>1 reasonable answer)" which
  is honest. Kept T2b; recommendation is "close as won't-fix".
- **AUD-0136/0144** — `NoteEventType` enum rewrite. Mechanical but touches 10+ files
  (grep-verified). On the T2a/T2b line. I picked T2b because "multi-file signature
  change affecting 3+ files" hits our rule. Could be T2a if the user accepts a single
  mechanical commit.
- **AUD-0161** — T2a but deferred. Not counted in "executable now" queue.

### Cross-chunk dependencies

- **AUD-0082** (orderLinkId) ← **AUD-0002** (chunk 1 T3).
- **AUD-0130** (PooledDB migration in trades.py) ← **AUD-0008** (chunk 1 T3).
- **AUD-0171** (writer/reader split) — tracker flags "cross-chunk"; touches 3+5.
- **AUD-0122** ↔ **AUD-0089** — same helper across chunks 3/4.
- **AUD-0132** — tracker says trades.py; grep shows journal.py. Already resolved.

### Cluster decisions

- **f-string-SQL cluster** (AUD-0147/0148/0149/0157/0160/0174) — one T3 migration.
- **Transaction cluster** (AUD-0118/0150/0162/0163) — one T3 migration.

---

## Verification notes — grep facts checked

1. `missing_trade` / `MISSING_TRADE` — only 2 code references: `open_orders.py:506`
   (the dead branch) and `api.ts:1601` (TypeScript literal). No UI caller.
2. `compute_health_flags` at `open_orders.py:238-285` never appends `MISSING_TRADE`.
3. `reader._conn` external access — exactly 1 site: `journal.py:1171`.
4. `_validate_and_escape_order_id` — exactly 1 caller at `refresh_trade_journal.py:2687`.
5. `generate_execution_result_note` — 1 caller at `trades.py:128`.
6. `event_type = 'note'/'tag'/'snapshot'` — 10+ files grep-verified (`trader_scorecard.py`,
   `idea_creator.py`, `idea_attachments.py`, `ai_snapshot.py`, `batch_ideas.py`,
   `inbox.py`, `notes.py`, `idea_item_copier.py`, `ideas.py`, `journal.py`, `trades.py`).
   Rules out T2a for AUD-0136/0144.
7. `reduce_only` column — varchar(5) in 3 tables (`order_leg_live`, `order_leg_hist`,
   `order_leg_smart`). AUD-0100 requires schema migration — T2b.
8. `diagnose_orphan_legs` at `refresh_trade_journal.py:3053-3143` already has
   `logger.info/warning/debug` calls. AUD-0177 narrow-log interpretation is vacuous.
9. T1 items from original triage (AUD-0107, 0110, 0132, 0133, 0139, 0151, 0172, 0173,
   0175, 0180) are already resolved in tracker.
