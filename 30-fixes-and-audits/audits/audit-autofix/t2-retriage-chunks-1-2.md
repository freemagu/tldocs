# T2 re-triage — chunks 1-2

**Generated:** 2026-04-24
**Scope:** 22 T2 items from the pilot triage (AUD-0001–AUD-0077)
**Purpose:** Split into T2a (auto-execute-safe) / T2b (design-required) under the user's "aggressive autonomous execution where safe" waiver.

## Pre-check: items already Resolved

AUD-0050, AUD-0051, AUD-0062 are marked `Resolved` in `AUDIT_TRACKER.md` (fixed 2026-04-23 with regression tests). They are dropped from this re-triage; nothing to execute.

## Counts

| Tier | Count |
|---|---|
| T2a — auto-execute | 8 |
| T2b — design-required | 11 |
| Resolved (excluded) | 3 |
| **Total in original T2** | **22** |

---

## T2a — auto-execute queue (8)

Grouped by file. Ordering keeps same-file batches adjacent so a sub-agent can reuse a worktree.

### lib/tradelens/core/config.py — 1

- **AUD-0021 — Minor/Cleanup — Wrap `load_config` in factory**
  - **Exact fix:** Rename module-level `config = load_config()` invocation into a lazily-memoised `get_config()` (idempotent); keep `config` as a `__getattr__`-backed lazy proxy or simply leave the module-level call in place *and add* `get_config()` as a first-class factory for tests to call.
  - **Grep verification:** 100 files `from tradelens.core.config import …` (mostly `config`/`AppConfig`). Pure-additive helper that does NOT touch the module-level `config` symbol has zero behavioural blast radius. This converts the item into "additive helper + no change to existing callers."
  - **Regression test:** `tests/unit/test_config.py::test_get_config_is_memoised` — two calls return the *same* `AppConfig` instance; after `_cached_config = None` reset, a new instance is returned.
  - **Caveat:** if the sub-agent tries to remove the module-level `config` call (eager load), demote to T2b. The T2a form is strictly "add `get_config()`; leave `config` alone."

### lib/tradelens/adapters/bybit_client.py — 2

- **AUD-0028 — Minor/Suspicious — Refuse unknown account names at `get_bybit_client`**
  - **Exact fix:** In `get_bybit_client(account_name)`, before inserting into `_client_cache`, check `account_name in AccountContext().list_account_names()`; raise `ValueError(f"Unknown account: {account_name}")` otherwise. The tracker lists "only ~3 accounts today" and the audit text calls the defence "document invariant; refuse unknown names at construction" — that's mechanical.
  - **Grep verification:** `BybitClient(account_name=…)` call sites all pass resolved names from `resolve_account_name()` / `account_name_resolved`; no user-input path feeds this directly. So raising on unknown is strictly a fail-fast guard, not a behaviour change for existing callers.
  - **Regression test:** `tests/unit/test_bybit_client.py::test_get_bybit_client_rejects_unknown_account` — assert `ValueError` for `account_name="nonexistent"`.
  - **Caveat:** "Needs verification" status upstream. I'm classifying this as T2a because the fix is fail-fast + the invariant is already documented in the tracker.

- **AUD-0029 — Minor/Cleanup — Standardise error convention (raise, not Optional-return)**
  - **Exact fix:** Change `get_available_balance` from `-> Optional[float]: return None` on failure to `-> float: raise`. Two callers (`api/trades.py:845`, `api/suspend.py:1484`); both already operate in try-blocks that catch exceptions. Add try/except at the two call sites to log-and-skip if they want soft failure.
  - **Grep verification:** `get_available_balance` has exactly 2 external callers. Small blast radius; both callers are in money-moving paths (`api/trades.py`, `api/suspend.py`). **HOLD-BACK CONSIDERED** but the fix is additive-safe if wrapped in try/except at both sites (behaviour: exception → log warning → proceed with `balance=None`).
  - **Regression test:** Mock `cursor.execute` to raise; assert `get_available_balance()` propagates the exception; assert `api/trades.py` call site catches it and continues.
  - **Flagged for user:** see "Held back" section — I'd prefer user confirmation because it touches money code, even though it's a mechanical refactor.

### lib/tradelens/core/account_context.py — 1

- **AUD-0024 — Minor/Cleanup — Drop `AccountContext.__new__` singleton trick**
  - **Exact fix:** Convert `class AccountContext` from `__new__`-based singleton to a module-level `_instance: Optional[AccountContext] = None` pattern behind `get_account_context()` (which already exists at line 372). Make `__init__` a normal init; remove class-level `_instance`/`_initialized` attrs.
  - **Grep verification:** Only public entry is `get_account_context()` (line 372); external callers go through it. `AccountContext()` is also called directly from `bybit_client.py:155` in an error message and `account_context.py:374` inside `get_account_context()`. The direct construction at line 374 is the one place that needs to change.
  - **Regression test:** `tests/unit/test_account_context.py::test_get_account_context_returns_singleton` + `test_reset_creates_fresh_instance` (add a `_reset_for_tests()` helper).
  - **Caveat:** Must land AFTER AUD-0012 OR coordinate; both touch the same class. I'd sequence AUD-0024 first (pure refactor, no failure-mode change), then AUD-0012 (which IS a failure-mode decision → T2b).

### lib/tradelens/utils/waep_tracker.py — 1

- **AUD-0054 — Major/Bug — Parameterise full-close tolerance by `qty_step`**
  - **Exact fix:** Replace the three `Decimal('0.000001')` constants (lines 398, 449, 514) with `tolerance = (qty_step or Decimal('0.000001')) / 2`. Plumb `qty_step` into `apply_leg` via the `leg` dict (it's already in `InstrumentMeta` context at all three call sites in `refresh_order_leg_*.py`).
  - **Grep verification:** 48 `apply_leg(` call sites. The `leg: Dict[str, Any]` signature doesn't need to change — we just add an optional `qty_step` key. Callers that don't pass it fall back to the current `0.000001` constant, preserving today's behaviour exactly.
  - **Regression test:** `tests/unit/test_waep_tracker.py::test_full_close_tolerance_scales_with_qty_step_doge` (tiny-qty-step like 0.1 — ensures dust ≥ 0.05 closes the position) + `test_full_close_tolerance_uses_default_when_qty_step_missing` (regression that today's behaviour is preserved).
  - **Flagged for user:** see "Held back" — this is money-path math. I'm tentatively classifying T2a because the fix is a pure superset (default = today's constant); user may still want to review.

### lib/tradelens/utils/initial_risk_calculator.py — 1

- **AUD-0059 — Major/Performance — Inject shared candle reader handle**
  - **Exact fix:** Add optional `reader: Optional[CandleReader] = None` param to the two public entries at lines ~770 and ~1261. When `None`, construct-and-close as today (100% backwards compatible); when supplied, use the shared handle and do NOT close.
  - **Grep verification:** Two open-close sites: `initial_risk_calculator.py:909` and `:1432` (matches tracker claim of "lines 770-778, 1261-1272" which are the outer function entries). Callers today always pass `conn` only, so `reader=None` default preserves behaviour.
  - **Regression test:** `tests/unit/test_initial_risk_calculator.py::test_reader_injection_reuses_handle` — mock `get_candle_reader`; call twice with injected reader; assert `close()` not called; assert `get_candle_reader` called once.
  - **Flagged for user:** this changes a public function signature additively. The audit says "changes API signature" — but since the new param has a default value, no caller needs to change. T2a-safe by the "no new signature with >2 external callers" rule.

### lib/tradelens/core/pg_pool.py — 1

- **AUD-0031 — Minor/Dead Code — `_fallback_warned` warn→raise**
  - **Exact fix:** Replace the warn+degrade block in `PooledDB.__init__` (lines 199-221) with a raise when `pg_pool` is not initialised AND `PooledDB` is constructed. Today's "silent fallback" is a misuse vector.
  - **Grep verification:** `PooledDB` is used ~30+ times across `api/*.py` — but always *inside* request handlers where pg_pool IS initialised. Standalone scripts go through `PostgresDB` instead. So raising on init-less construction should not hit any legitimate call site.
  - **Regression test:** `tests/unit/test_pg_pool.py::test_pooled_db_raises_when_pool_not_initialized` — patch `pg_pool._pool = None`; construct `PooledDB`; assert raises.
  - **Flagged for user:** status is "Suspicious" upstream. Classifying T2a because (a) the audit already says "standalone fallback inside FastAPI context indicates misuse", (b) raising is the audit's own recommended fix, (c) integration tests will immediately catch any legitimate use we missed.

### lib/tradelens/services/sizing.py — 1

- **AUD-0048 — Major/Duplication — Extract `_build_legs()` helper**
  - **Exact fix:** Factor the leg-construction logic shared between `calculate_position_size` (sizing.py:226-416) and `calculate_quantity_sizing` (sizing.py:591-775) into a private `_build_legs(side, entry_price, dca_levels, entry_pct, dca*_pct, total_qty, instrument_meta)`. Both public functions reduce to (a) compute `total_qty`, (b) call `_build_legs`, (c) return.
  - **Grep verification:** `calculate_position_size` has 3 callers (`api/trades.py` 672/696/720), `calculate_quantity_sizing` has 1 caller (`api/trades.py:638`). Public signatures stay unchanged. Internal helper is mechanical refactor.
  - **Regression test:** `tests/unit/test_sizing.py::test_build_legs_parity_with_calculate_position_size` — table of inputs (long entry-only; long with 2 DCAs; short with 4 DCAs; limit with entry_pct=0 all-in-DCA). Call both old and new paths, assert identical `SizingResult`.
  - **Flagged for user:** see "Held back" — money-moving code. Classifying T2a because (a) it's pure refactor (byte-for-byte identical outputs), (b) parity test is trivial to write, (c) existing `test_sizing.py` covers the end-to-end behaviour.

---

## T2b — design-required queue (11)

| AUD-ID | Severity | Reasonable answers | My recommendation |
|---|---|---|---|
| **AUD-0006** | Critical/Bug | (a) Make `trigger_direction` + `reduce_only` required (breaking — requires sweep of 4 call sites including `services/stops.py`, `open_orders.py:1635`, `:3731`, `bin/tools/resubmit_rejected_tps.py`); (b) Add runtime assertion + deprecation warning for defaults; (c) Keep as-is, document invariant only. Also coordination needed with in-flight `level_guard_daemon` work per tracker Deferred note. | (a) full sweep — but ONLY after user confirms level_guard coordination is clear. Money-path critical. |
| **AUD-0010** | Major/Arch | (a) Make `__init__` private, force all callers through `get_bybit_client` (40+ call sites to update); (b) add lint rule, document invariant, leave code. | (a) but it's a big sweep across `api/` — user should confirm the churn budget. |
| **AUD-0011** | Major/Reliability | (a) `httpx.Timeout(connect=5, read=15, write=10, pool=5)` as the audit suggests; (b) more conservative `connect=10, read=30`; (c) make them config-driven. Every Bybit call gets faster failures and retries — behavioural change across *all* exchange interaction. | (a) with a one-week canary on the demo account. Too load-bearing to auto-execute. |
| **AUD-0012** | Major/Reliability | (a) Fail-fast (raise at `__init__` if DB down); (b) Lazy-reload on cache miss; (c) Background retry task. All three are reasonable; (a) is cleanest but breaks local dev when Postgres is down. | (b) lazy-reload on cache miss — least disruptive, matches resilience goals. But user should pick. |
| **AUD-0017** | Minor/Suspicious | (a) Delete `periodic_gc`; (b) keep but add tracemalloc instrumentation; (c) leave alone. Status is "Needs verification" — the tracker explicitly says "profile with tracemalloc" before removing. Removing without profile risks re-introducing whatever leak it was masking. | (b) — instrument first, delete later in a separate commit. T2b because "needs verification" is its own gate. |
| **AUD-0034** | Minor/Dead Code | (a) Delete `BybitClient.close` + sweep 20 `bybit.close()` callers in `api/`; (b) keep `.close()` as a documented no-op with a warning comment. Tracker note explicitly says "Promoted out of 'easy' bucket" because of the 20+ callers — already ACKs this is no longer mechanical. | (b) add a docstring explaining why it's a no-op. (a) is a 20-file sweep that belongs in its own ticket. |
| **AUD-0037** | Major/Arch | (a) Split YAML-load from DB-sync, call DB-sync from FastAPI lifespan; (b) Lazy DB-sync on first access; (c) Keep but wrap DB-sync in try/except. (a) is cleanest but adds lifespan dependency. | (a), but this depends on the same DB lifecycle story as AUD-0008 (T3). Should land as part of that arc. |
| **AUD-0039** | Major/Arch | (a) Auto-generate `orderLinkId` (UUID or `{trade_id}-{leg_kind}-{ts}`) + require it; (b) Require but caller-supplied; (c) Keep optional but add `cancel_by_order_link_id` helper. Prerequisite to AUD-0002 (T3 retry policy). | (a) auto-generate with structured prefix, require at public boundary. But this is the foundation for all retry logic — product decision. |
| **AUD-0053** | Major/Bug | (a) Full `@dataclass ApplyLegResult` swap — 48 `apply_leg(` call sites use positional unpacking today, ALL need to change; (b) Add `NamedTuple` with field names (positional-compatible); (c) Leave alone. | (b) `NamedTuple` — backwards-compatible positional + field access. (a) is correct but a big sweep. User picks. |
| **AUD-0056** | Major/Bug | (a) Replace `profit_pct` with `rr_ratio` (frontend needs 3 updates: `types.ts`, `trade-preview-panel.tsx`, `journal-entry-generator.ts`); (b) Rename field to `profit_pct_of_waep` with a doc comment; (c) Add parallel `rr_ratio` field and deprecate `profit_pct`. | (c) add parallel, deprecate — avoids UI break. But UI-visible change — user must approve the semantic. |
| **AUD-0077** | Major/Arch | (a) Accept `Decimal` at public sizing boundary (requires pydantic `Decimal` in DTOs + API layer work); (b) Accept strings + parse internally; (c) Keep floats, document precision loss. | (a), but this cascades into the DTO layer — cross-cutting refactor that belongs with AUD-0016 (T3). |

---

## Execution plan

Sub-agent batches in the T2a queue, grouped by file. Within each batch, commit separately by AUD-ID so a revert is surgical.

1. **config.py singleton batch** — AUD-0021 (additive `get_config()` factory).
2. **bybit_client.py batch** — AUD-0028 (reject unknown accounts) then AUD-0029 (standardise error convention; 2 call-site updates).
3. **account_context.py batch** — AUD-0024 (drop `__new__` singleton).
4. **pg_pool.py batch** — AUD-0031 (`_fallback_warned` warn→raise).
5. **waep_tracker.py batch** — AUD-0054 (parameterise full-close tolerance).
6. **initial_risk_calculator.py batch** — AUD-0059 (optional shared reader handle).
7. **sizing.py batch** — AUD-0048 (extract `_build_legs`; parity test required).

Seven batches, eight fixes, estimated seven commits.

## Held-back items (user may disagree)

Three of my T2a picks carry risk that deserves explicit user call-out. User may want to demote any of these to T2b:

1. **AUD-0029** (standardise `get_available_balance` to raise) — touches money-moving call sites in `api/trades.py` and `api/suspend.py`. Mechanically safe (2 callers, both already in try-blocks), but the convention change ripples through error handling. **Demote to T2b if user wants to review error-handling strategy first.**

2. **AUD-0054** (qty_step-scaled full-close tolerance) — WAEP math used to build every trade journal row. Fix preserves default behaviour exactly (fallback to today's `0.000001`), but the math is load-bearing. **Demote to T2b if user wants to test against real position data first.**

3. **AUD-0048** (extract `_build_legs` from sizing) — money-moving sizing code that places real orders. Pure refactor, trivially verifiable, but Memory/CLAUDE.md says "rounding/sizing is sensitive." **Demote to T2b if user wants full battery of integration tests first.**

## Items I'd promote from T2b to T2a if user accepts interpretation

1. **AUD-0034** — if user accepts "leave `bybit.close()` as documented no-op, don't sweep 20 callers," then it becomes a 1-line docstring change (T2a). The audit's "delete" intent becomes "document intent" — strictly additive.

2. **AUD-0053** — if user accepts `NamedTuple` rather than `@dataclass`, field names become available *without* breaking any of the 48 positional-unpacking call sites. Pure refactor (T2a). Full `@dataclass` forces a 48-site sweep (T2b).

3. **AUD-0056** — if user accepts "parallel `rr_ratio` field, keep `profit_pct` for back-compat", no UI break; it becomes additive (T2a). Removing `profit_pct` outright is the T2b interpretation.
