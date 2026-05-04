---
status: design-ready-for-implementation
generated: 2026-04-26
authors: claude-orchestrator-via-subagent
audit-ids:
  - AUD-0114 (submit_trade decomposition + compensating cancels)
  - AUD-0115 (route placements through typed adapter helpers, not _request)
tier: T3
prerequisites:
  - AUD-0002 retry/circuit (design-ready, blocks A-3)
  - AUD-0039 orderLinkId at adapter (already shipped, commit 1a388ff5)
  - AUD-0121 SL post-entry rollback (already shipped, commit f4e571ce — partial pattern reuse)
related:
  - AUD-0218 suspend transaction (resume parked — same compensating-cancel issue)
  - AUD-0231 + AUD-0282 orderLinkId on amend (parked, needs adapter extension)
---

# AUD-0114 + AUD-0115 — `trades.py` decomposition + typed-adapter routing

> **Documentation only.** This document describes WHAT will ship in each phase
> and WHY. No code changes are in this commit. Each phase below is a separate
> future commit, pinned for the operator's go-ahead before it lands. The
> ordering is load-bearing: **AUD-0115 ships before AUD-0114**, because typed-
> adapter routing is a prerequisite for clean helper extraction (otherwise the
> extracted helpers inherit the "bypass adapter" anti-pattern).

## 0. The audit rows

```
| AUD-0114 | 4 | Critical | Architecture | Confirmed | lib/tradelens/api/trades.py | `submit_trade` |
1,200+ line single function; nested try/except inside for-loops; "partial"
success with no compensating cancels.
Any mid-stream Bybit failure leaves live orders + half-DB state; untestable
as a unit.
Extract per-leg-type helpers; add compensating cancel path; integration tests.
trades.py:1193-2428.

| AUD-0115 | 4 | Critical | Architecture | Confirmed | lib/tradelens/api/trades.py |
`_submit_single_order_to_bybit`, stop-loss in `submit_trade`
Both call `bybit._request` (private) directly, bypassing `place_conditional_order` /
`place_order`.
Adapter-level retry/orderLinkId/rate-limit improvements won't reach these paths.
Route all placements through typed adapter helpers.
trades.py:1573, 2813.
```

T3 / Bucket F. **Money-moving path.** Every phase requires extra-thorough
integration tests. The cluster is paired because the right ordering depends
on understanding both — the helpers from AUD-0114 should call typed-adapter
methods (post-AUD-0115), not raw `_request`.

---

## 0.1 Status-quo verification (2026-04-26 against worktree at `fdfcd95d`)

`lib/tradelens/api/trades.py` is **3746 lines** total.

| Subject | Cluster claim | Verified |
|---|---|---|
| `submit_trade` start line | 1193 | **1262** (drifted ~70 lines since cluster wrote) |
| `submit_trade` end line | 2428 | **2574** (last line before next `def preview_bybit_orders` at 2575) |
| `submit_trade` length | "1,200+ lines" | **1313 lines** — confirmed |
| `_submit_single_order_to_bybit` | line 1573 | **2917** — drifted; the cluster line numbers are stale, the function exists |
| Stop-loss in `submit_trade` raw `_request` call | line 2813 | **1119** (inside `_place_stop_loss_for_intent`, AUD-0121 helper) |

`bybit._request` direct call sites in `trades.py` (verified by grep):

| Line | Context | Endpoint | Notes |
|---|---|---|---|
| **1119** | `_place_stop_loss_for_intent` (AUD-0121 helper) | `POST /v5/order/create` | SL — `triggerDirection`, `orderFilter=StopOrder`, `closeOnTrigger=True` |
| **2049** | inside `submit_trade`, conditional-TP loop | `POST /v5/order/create` | Conditional TP — uses pre-built `ctp_for_exchange` dict |
| **2956** | `_submit_single_order_to_bybit` (used by `submit_trade_json` path) | `POST /v5/order/create` | Generic order create from sanitized params dict |
| **3318** | `check_hedge_position` | `GET /v5/position/list` | Read-only — hedge mode position check |
| **3480** | `cancel_pending_position` | `POST /v5/order/cancel` | Cancel orders for pending-position cleanup |

**Cluster wrote "trades.py:1573, 2813" — these line numbers are stale, but the
underlying claim ("two raw `_request` paths in trades.py: `_submit_single_order_to_bybit`
and the stop-loss in `submit_trade`") is correct in spirit. The reality is
that today there are FIVE raw `_request` sites in `trades.py` (3 POST creates,
1 GET, 1 POST cancel). All five must be migrated for the AUD-0115 invariant
to hold.**

`submit_trade` structure (verified — see Part B.1 below):

| Block | Lines | What it does |
|---|---|---|
| Setup / preview cache lookup / conflict check | 1262–1378 | Validation, account/position-mode detection |
| Trade-intent + idea status update | 1338–1374 | DB writes (no Bybit) |
| Leverage check | 1383–1408 | Bybit `set_leverage` (perp only) |
| Live ticker fetch | 1411–1412 | Bybit `get_ticker` |
| **Per-leg loop start** | 1437 | `for leg in preview_response['legs']:` |
| Seeded-trade entry split (seed market + entry limit) | 1463–1571 | Two `place_order` calls, both via typed helper already |
| Regular entry/DCA placement | 1575–~1670 | Single `place_order` call (typed helper) |
| Inline SL placement (when entry succeeded mid-loop) | scattered, before AUD-0121 | now lives in `_place_stop_loss_for_intent` and is called from a different gate |
| TP placement — market-entry path | 1687–~1850 | `place_order` typed; per-TP try/except |
| TP placement — limit-entry path | ~1850–~1900 | `place_order` typed; per-TP try/except |
| Conditional-TP placement | ~1900–2200 | **RAW `_request`** at 2049; per-CTP try/except |
| Per-leg `except ExchangeError` handler | ~2150–~2200 | Calls `_rollback_placed_entries` and re-raises |
| **Per-leg loop end** | ~2200 | |
| Post-loop SL fallback (AUD-0121) | 2210–2255 | Calls `_place_stop_loss_for_intent` if SL never placed |
| Status update + idea note + intent_spec annotation | 2257–~2350 | DB writes |
| `pending_vwap_links` flush + trade_journal copy | ~2350–2574 | DB writes + post-processing |

Already-extracted (AUD-0121, commit `f4e571ce`):

- `_place_stop_loss_for_intent(...)` at `trades.py:1040-1175`
- `_rollback_placed_entries(...)` at `trades.py:1177-1259`

The AUD-0121 work is **partial AUD-0114**: it extracted the SL placement into
its own helper and added a rollback path that cancels previously-placed entry
legs (entry/seed/dca) when a downstream entry leg's `place_order` raises. It
does NOT cover:

- TP rollback (placed TPs are not cancelled if a later TP or the SL fails)
- DCA rollback (technically covered as part of `placed_entry_orders`, but not
  separated as its own helper)
- Conditional-TP rollback (raw `_request`, no orderLinkId, can't be retried
  safely — also not in `placed_entry_orders`)
- The pattern as a unified `compensate(legs, original_error)` operation that
  the top-level orchestrator can invoke once at the end of any failure path

---

## Part A — AUD-0115: route all placements through typed adapter helpers

### A.1 Status quo

The adapter `lib/tradelens/adapters/bybit_client.py` already exposes typed
helpers for every Bybit endpoint that `trades.py` calls:

| Adapter helper | Bybit endpoint | Used for |
|---|---|---|
| `place_order(category, symbol, side, order_type, qty, price, ...)` | `POST /v5/order/create` (Limit / Market) | entry, DCA, regular TP, seed market |
| `place_conditional_order(category, symbol, side, order_type, qty, trigger_price, *, trigger_direction, reduce_only, ...)` | `POST /v5/order/create` with `triggerPrice` | SL, conditional TPs |
| `set_trading_stop(category, symbol, stop_loss=, take_profit=, position_idx=)` | `POST /v5/position/trading-stop` | position-level TP/SL (used in `clear_position_take_profit`) |
| `cancel_order(category, symbol, order_id)` | `POST /v5/order/cancel` | rollback, pending-position cleanup |
| `cancel_by_order_link_id(symbol, category, order_link_id)` | `POST /v5/order/cancel` | rollback fallback (when `orderId` unknown) |
| `get_positions(...)` | `GET /v5/position/list` | hedge-mode check |

**AUD-0039 was already shipped (commit `1a388ff5`)** so `place_order` and
`place_conditional_order` now generate / validate `orderLinkId` automatically
at the adapter boundary. Every order leaving the adapter has a populated,
deterministic `orderLinkId` — but **only on the typed paths**. The five raw
`_request` call sites in `trades.py` bypass this entirely:

- AUD-0039's auto-generation never fires
- The future AUD-0002 retry/orderLinkId/rate-limit/circuit-breaker logic
  (when it lands at the adapter boundary) won't reach these paths either
- Test seams that mock `place_order` / `place_conditional_order` don't
  intercept these — they have to mock `_request`, which is brittle and
  couples tests to private adapter internals

### A.2 Design

For each `bybit._request` call site, route through the equivalent typed
helper. If the typed helper lacks a feature the raw call uses, **extend the
typed helper** — never the call site.

Mapping table (`trades.py` only):

| Site | Current call | Replacement | Adapter changes needed |
|---|---|---|---|
| **1119** (SL in `_place_stop_loss_for_intent`) | `bybit._request("POST", "/v5/order/create", sl_params)` where `sl_params` carries `triggerPrice`, `triggerDirection=2/1`, `orderFilter=StopOrder`, `closeOnTrigger=True`, `reduceOnly=True` | `bybit.place_conditional_order(category, symbol, side, order_type='Market', qty, trigger_price, trigger_direction=…, reduce_only=True, order_filter='StopOrder', position_idx=…)` | **Add `close_on_trigger: bool = False`** parameter to `place_conditional_order`. Currently absent — SL needs it set to `True`. |
| **2049** (conditional TP) | `bybit._request("POST", "/v5/order/create", ctp_for_exchange)` where `ctp_for_exchange` is a pre-built dict possibly carrying `triggerPrice`, `triggerDirection`, `orderFilter`, plus possibly `price` (limit), `reduceOnly`, `positionIdx` | `bybit.place_conditional_order(...)` | Inspect the CTP dict-builder upstream (around line 1900–2030) and convert each field to a named parameter. May need to widen `place_conditional_order` to accept some optional flags currently unique to CTPs. |
| **2956** (`_submit_single_order_to_bybit`) | `bybit._request("POST", "/v5/order/create", sanitized_params)` — generic | Branch by presence of `triggerPrice` in `sanitized_params`: with → `place_conditional_order`; without → `place_order`. | None for the function itself; but `_submit_single_order_to_bybit` is fed by `submit_trade_json`'s JSON-edit path, which already lives outside the typed flow — its callers may need updating to pass typed args, not a raw dict. |
| **3318** (`check_hedge_position`) | `bybit._request("GET", "/v5/position/list", {category, symbol})` | `bybit.get_positions(category=category, symbol=symbol)` | None — `get_positions` already exists. |
| **3480** (`cancel_pending_position`) | `bybit._request("POST", "/v5/order/cancel", cancel_params)` where `cancel_params` includes `orderFilter` for stop orders | `bybit.cancel_order(category, symbol, order_id)` | **Add `order_filter: Optional[str] = None`** parameter to `cancel_order` — currently absent. Stop orders may need `orderFilter=StopOrder` to cancel cleanly. |

**Adapter changes summary (one helper at a time, each its own commit):**

1. Extend `place_conditional_order` signature with `close_on_trigger: bool = False`
2. Extend `cancel_order` signature with `order_filter: Optional[str] = None`
3. Audit `place_conditional_order`'s parameter coverage against the CTP dict-
   builder; widen if needed (e.g. add `time_in_force` if CTPs use IOC/FOK)
4. (Optional, after migration) consider promoting `_request` to `_request`
   private + a runtime guard that emits a logger warning when it's called
   directly from outside the adapter package, to catch regressions.

**Outside `trades.py`** — `bybit._request` direct call sites discovered by
grepping `lib/`:

| File:line | Endpoint | Notes |
|---|---|---|
| `lib/tradelens/services/suspend_service.py:305` | `POST /v5/order/cancel` | Suspend cancel — should route through `cancel_order` |
| `lib/tradelens/api/journal.py:3951` | `POST /v5/order/cancel` | Journal cleanup — `cancel_order` |
| `lib/tradelens/api/journal.py:4302` | `POST /v5/order/cancel` | Journal cleanup — `cancel_order` |
| `lib/tradelens/api/journal.py:4719` | `GET /v5/order/realtime` | Order detail read — needs an `get_order_realtime` typed helper (probably absent) |
| `lib/tradelens/api/journal.py:4772` | `POST /v5/order/cancel` | Journal cleanup — `cancel_order` |
| `lib/tradelens/api/journal.py:5015` | `POST /v5/order/cancel` | Journal cleanup — `cancel_order` |
| `lib/tradelens/api/journal.py:5213` | `POST /v5/order/create` | SL placement on journal-side path — `place_conditional_order` |

**The migration is bigger than just `trades.py`.** Eight additional sites
across `journal.py` and `suspend_service.py` carry the same defect. The cluster
named only `trades.py`, but a complete fix requires sweeping all of them so
that AUD-0002's retry / rate-limit logic — when it lands — actually applies
to every order placement and cancellation in the codebase.

### A.3 Phased plan — AUD-0115

Each phase is a separate commit. Money-moving path — every phase requires
mocked-adapter integration tests asserting both correct behaviour AND the
exact typed-helper signature being called (so a future regression that
reverts to `_request` fails the test).

| Phase | Scope | Estimated effort | Tests required |
|---|---|---|---|
| **A-0** | Inventory commit: produce mapping table from §A.2 as a docs-only addendum (this section is enough; no separate commit needed). | included | n/a |
| **A-1** | Extend `place_conditional_order` with `close_on_trigger`. Extend `cancel_order` with `order_filter`. Adapter unit tests assert the new params reach the request payload correctly. No call-site changes yet. | 4h | adapter unit tests |
| **A-2** | Migrate `_place_stop_loss_for_intent` (line 1119) — the AUD-0121 SL helper — to call `place_conditional_order(..., close_on_trigger=True, reduce_only=True, ...)` instead of `_request`. Verify SL still places with correct payload via VCR-style fixture or mocked adapter. | 4h | integration test for AUD-0121 helper, asserting `place_conditional_order` is called (not `_request`) |
| **A-3** | Migrate the conditional-TP `_request` site at line 2049 to `place_conditional_order`. Walk the CTP dict-builder upstream and convert it to named-arg construction. This is the messiest one — the CTP dict has accumulated fields over time. | 6–8h | integration test for each CTP code path (entry-triggered with tick offset, DCA-triggered, limit + market) |
| **A-4** | Migrate `_submit_single_order_to_bybit` (line 2956) — branch on presence of `triggerPrice` between `place_order` and `place_conditional_order`. Audit `submit_trade_json` (callers) to ensure JSON-edit input maps cleanly to typed args. | 6h | integration test for `submit_trade_json` covering both branches |
| **A-5** | Migrate `check_hedge_position` (line 3318) to `get_positions(...)` — read-only, low risk. | 1h | unit test |
| **A-6** | Migrate `cancel_pending_position` (line 3480) to `cancel_order(..., order_filter=...)`. | 2h | integration test for stop-order cancel path |
| **A-7** | Sweep `journal.py` (6 sites) + `suspend_service.py` (1 site). Add a typed `get_order_realtime` adapter helper if needed for journal:4719. | 8h (split into 2 commits if convenient) | integration tests covering each journal cancel/cleanup path |
| **A-8** | Verification commit: `grep -rn "bybit\._request\|bybit_client\._request" lib/ bin/` returns ZERO hits in `lib/tradelens/api/`, `lib/tradelens/services/`. The only allowed callers are inside `lib/tradelens/adapters/` and read-side helpers like `recent_trades_fetcher.py` (if any). Add a CI grep test that fails if a new direct caller appears. | 2h | CI grep guard test |

Total: 33–37 hours over 7 commits.

### A.4 Risks — AUD-0115

- **Stop-loss `closeOnTrigger=True` semantics.** The Bybit doc page changed in
  2024 — `closeOnTrigger` may behave subtly differently in one-way vs hedge
  mode. The current raw `_request` SL has been working in production; before
  switching to the typed path, a sandbox test of one-way + hedge + spot is
  required. If the typed helper subtly changes payload shape (e.g. always
  emits `reduceOnly` even when False), behaviour may drift.
- **CTP dict accumulation.** The `ctp_for_exchange` dict at line 2048 is
  built upstream from a chain of conditionals (entry-triggered TP, tick offset,
  VWAP-linked, etc.). Converting to named args is straightforward only if the
  dict's possible field set is enumerable — needs careful reading of
  `preview_response['legs']` schema.
- **AUD-0231 `orderLinkId` format.** AUD-0231 (parked) noted that the AUD-0039
  generator format isn't a perfect fit for amend operations and has a
  custom deterministic format running alongside. If AUD-0115 surfaces other
  format mismatches in CTP/TP, **do not invent new formats** — escalate to a
  cross-cutting AUD-0231 design instead.
- **`submit_trade_json` is a separate code path.** Migrating
  `_submit_single_order_to_bybit` only helps if `submit_trade_json` is also
  used in production. Verify usage (it appears to be a JSON-edit endpoint for
  power users) before investing — if it's effectively dead, we can defer A-4
  and document the gap.
- **Regressions in journal cancels.** The 6 cancel sites in `journal.py` are
  scattered through trade-close / partial-close flows. A migration error here
  could leave open orders on the exchange. Each cancel should be tested with
  an integration fixture that asserts the cancel was issued AND the local DB
  state was updated.

---

## Part B — AUD-0114: `submit_trade` decomposition + compensating cancels

> **Order constraint:** AUD-0114 ships AFTER AUD-0115 (Part A above). The
> extracted helpers will use typed-adapter calls. If we extract first and
> migrate later, every helper becomes a refactor target twice.

### B.1 Status quo — verified structure of `submit_trade`

`submit_trade` lives at `trades.py:1262-2574`. **1313 lines, single function.**
The function carries the entire happy-path-and-failure-recovery for trade
submission.

Verified shape (see structure table in §0.1):

1. **Setup phase** — preview lookup, conflict check, intent creation, idea
   status update (DB only, no Bybit). Lines 1262–1374.
2. **Pre-leg phase** — position-mode detection, leverage check, ticker fetch.
   Lines 1376–1412.
3. **Per-leg loop** — `for leg in preview_response['legs']:`. Lines 1437–~2200.
   Inside this loop:
    - Seeded-trade branch: split entry into seed market + entry limit (two
      `place_order` calls).
    - Regular entry/DCA branch: single `place_order` call.
    - TP placement branch: per-TP loop; one `place_order` per TP. Has its own
      nested `try/except ExchangeError` that records the failure and continues.
    - Conditional-TP branch: per-CTP loop; one **raw `_request`** per CTP
      (line 2049). Has its own nested `try/except ExchangeError`.
    - Per-leg `except ExchangeError` handler: calls `_rollback_placed_entries`
      and re-raises.
4. **Post-loop SL fallback** — AUD-0121 logic: if SL was never placed AND any
   entry/seed/dca succeeded, place SL now via `_place_stop_loss_for_intent`.
   Lines 2210–2255.
5. **Status / persistence phase** — compute `all_ok` / `seed_ok`; update intent
   status; flush VWAP links; copy idea items; create journal note. Lines
   2257–2574.

**Partial-success semantics (current behaviour):**

- Entry/seed/DCA `ExchangeError` → call `_rollback_placed_entries(...)` to
  cancel earlier entry-side orders, then **re-raise** to the top-level handler
  (which marks intent as `error`).
- TP `ExchangeError` (regular TP, line ~1820) → record the leg with status
  `error`, **continue the loop**, no rollback of placed TPs or the entry.
- CTP `ExchangeError` (line ~2122) → record with status `error`, **continue**,
  no rollback.
- SL `ExchangeError` (inside `_place_stop_loss_for_intent`) → record with
  status `error`, **return** to caller; caller continues.
- After loop: `all_ok = all(leg['status'] == 'submitted' ...)` decides whether
  intent is `submitted` or `error`/`partial`. **Live orders may remain on
  Bybit even when the response says `partial`.**

The audit's "partial success with no compensating cancels" complaint is
exactly right: the only compensating-cancel today is in the entry-side
`_rollback_placed_entries` (AUD-0121); TPs, CTPs, and SL all have either NO
rollback or only one-way rollback.

### B.2 Design

**Result type — `PlacedLeg` dataclass.**

```python
@dataclass
class PlacedLeg:
    leg_id: int                       # DB order_leg row id
    leg_type: str                     # 'entry' | 'seed' | 'dca' | 'tp' |
                                      # 'conditional_tp' | 'stop'
    order_kind: str                   # 'market' | 'limit'
    exchange_order_id: Optional[str]  # Bybit orderId (None on placement failure)
    order_link_id: Optional[str]      # AUD-0039 orderLinkId
    qty: Decimal
    price: Optional[Decimal]          # None for market
    trigger_price: Optional[Decimal]  # None for non-conditional
    status: str                       # 'submitted' | 'error'
    error: Optional[str] = None       # error text when status='error'
```

A dataclass (not Pydantic) — internal type, never serialised. Passed by
value between helpers and the orchestrator. The existing `order_legs` dict-
list in `submit_trade` maps cleanly: rename + type-annotate.

**Per-leg-type helpers — extraction targets.**

```python
def _submit_entry_legs(
    *, bybit, conn, ctx: SubmitContext,
    legs: List[Dict[str, Any]],
) -> List[PlacedLeg]:
    """Place all entry/seed/dca legs in order. Each placement appends to the
    returned list. Re-raises ExchangeError on the first failure WITH the
    list-so-far in the exception's `placed_legs` attribute, so the
    orchestrator can compensate.
    """

def _submit_take_profits(
    *, bybit, conn, ctx: SubmitContext,
    parent_entry: PlacedLeg, tp_levels: List[Dict[str, Any]],
) -> List[PlacedLeg]:
    """Place all regular TPs for a given parent entry. Records errors per-TP
    but does NOT raise — partial-TP failure is recoverable (re-issuable). The
    orchestrator decides whether to roll back the parent entry based on
    business rules.
    """

def _submit_conditional_tps(
    *, bybit, conn, ctx: SubmitContext,
    parent_entry: PlacedLeg, ctp_specs: List[Dict[str, Any]],
) -> List[PlacedLeg]:
    """Place all conditional TPs. Same per-CTP error-isolation as
    `_submit_take_profits` but uses `place_conditional_order` (post-AUD-0115)."""

def _submit_stop_loss(
    *, bybit, conn, ctx: SubmitContext,
    sl_price: Decimal,
) -> Optional[PlacedLeg]:
    """The AUD-0121 helper, renamed and aligned with the new dataclass.
    Returns None if `sl_price` is None or the prior entries all failed.
    Raises ExchangeError if SL placement raises — the orchestrator decides
    rollback policy."""

def _compensate(
    *, bybit, ctx: SubmitContext,
    placed_legs: List[PlacedLeg], original_error: Exception,
) -> List[Tuple[str, Exception]]:
    """Cancel every cancellable leg in `placed_legs`. Generalises
    `_rollback_placed_entries` to ALL leg types: entries, DCAs, TPs, CTPs,
    SL. Market legs that have already filled cancel-error and are logged
    LOUDLY but do not abort the rollback. Returns list of (identifier,
    cancel_error) for sites the operator may need to inspect.
    """
```

`SubmitContext` is a dataclass capturing the per-request invariants
(`category`, `symbol`, `account_id`, `account_name`, `trade_intent_id`,
`position_mode`, `qty_step`, `tick_size`, `current_entry_set`) so they
don't have to thread through every helper signature.

**Top-level orchestrator — new `submit_trade` shape.**

```python
def submit_trade(request, background_tasks):
    # ... setup phase: preview lookup, conflict check, intent creation
    ctx = _build_submit_context(...)

    placed: List[PlacedLeg] = []

    try:
        # Entry phase
        placed += _submit_entry_legs(bybit=bybit, conn=conn, ctx=ctx, legs=entry_legs)

        # SL phase (post-AUD-0121: SL goes BEFORE TPs to avoid 10-order quota)
        sl_leg = _submit_stop_loss(bybit=bybit, conn=conn, ctx=ctx, sl_price=ctx.sl_price)
        if sl_leg:
            placed.append(sl_leg)

        # TP phase
        for entry in [l for l in placed if l.leg_type in ('entry','seed','dca')]:
            placed += _submit_take_profits(bybit=bybit, conn=conn, ctx=ctx,
                                           parent_entry=entry, tp_levels=...)
            placed += _submit_conditional_tps(bybit=bybit, conn=conn, ctx=ctx,
                                              parent_entry=entry, ctp_specs=...)

    except ExchangeError as e:
        # Single, unified compensate path
        cancel_failures = _compensate(bybit=bybit, ctx=ctx,
                                       placed_legs=placed, original_error=e)
        # ... mark intent as error, surface to caller
        raise

    # ... persistence phase: status update, VWAP flush, journal note
```

**Why this shape:**

1. **Each helper has ONE responsibility.** Easier to test in isolation with a
   mocked adapter (the AUD-0121 test pattern generalises).
2. **The orchestrator decides rollback policy.** Helpers raise / record;
   `_compensate` is invoked exactly once. No rollback policy buried inside a
   leg-specific `except` block.
3. **`PlacedLeg` is the boundary.** DB state is written by the helper; the
   orchestrator aggregates and decides on success/failure status from the
   list. Easy to test ("given these placed legs, does the response say
   `submitted` or `partial`?").
4. **The AUD-0121 SL-fallback gating becomes explicit.** Today the post-loop
   SL fallback (lines 2227–2255) checks "did SL fire? did any entry succeed?"
   — in the new shape, the orchestrator just calls `_submit_stop_loss` after
   `_submit_entry_legs` and the gating is in one place.
5. **Compensating cancel for ALL leg types.** `_compensate` walks the
   `placed_legs` list and cancels every still-cancellable one regardless of
   leg_type. AUD-0218 (suspend transaction, parked) hit the same issue —
   `_compensate` should be reusable for that path too.

### B.3 Phased plan — AUD-0114

Each phase is a separate commit. Money-moving path. Each phase's commit
must include integration tests for the helper being extracted, with at least
the following scenarios:

- happy path
- mid-leg `ExchangeError` (was the prior leg cancelled?)
- already-filled market leg (cancel returns retCode != 0 — does `_compensate`
  log loudly and continue?)
- DB-write failure mid-helper (does the helper leave consistent state?)

| Phase | Scope | Effort | Tests |
|---|---|---|---|
| **B-0** | (pre-req) AUD-0115 must be at least Phase A-2 done — SL must use typed helper before SL helper is renamed. | — | — |
| **B-1** | Define `PlacedLeg` dataclass + `SubmitContext` dataclass + adapter glue. No behavioural change yet — just types. Add type annotations to existing `_place_stop_loss_for_intent` and `_rollback_placed_entries`. | 1 day | unit tests for dataclass round-trip |
| **B-2** | Extract `_submit_entry_legs`. Today the entry-loop body lives inline at trades.py:1437–~1670. Move it to a helper that returns `List[PlacedLeg]`. The seeded-trade split (1463–1571) becomes private to the helper. **Behaviour: identical.** Existing `_rollback_placed_entries` becomes the early version of `_compensate` — invoked from the helper's exception handler with the partial list. | 1–2 days | integration tests per entry path: market-only, limit-only, market+DCA, seeded-trade |
| **B-3** | Rename `_place_stop_loss_for_intent` → `_submit_stop_loss`. Adopt `PlacedLeg` return type. The post-loop SL fallback (lines 2210–2255) is deleted because the orchestrator now calls SL explicitly between entries and TPs. Verify the AUD-0121 invariant holds: SL is attempted whenever any entry leg reached Bybit. | 1 day | regression tests for the exact scenarios AUD-0121 was protecting against |
| **B-4** | Extract `_submit_take_profits` (regular TP loop, lines ~1687–~1900). Per-TP error isolation preserved (TP failures don't fail the trade, just mark the leg). | 1–2 days | per-TP tests covering market entry path, limit entry path |
| **B-5** | Extract `_submit_conditional_tps` (CTP loop, lines ~1900–2200). Depends on AUD-0115 Phase A-3 (typed `place_conditional_order`). Per-CTP error isolation preserved. | 1–2 days | per-CTP tests including entry-triggered with tick offset and VWAP-linked |
| **B-6** | Extract DCA explicitly. The DCA legs are already inside the entry loop today; the helper structure means "entry/seed/dca" all flow through `_submit_entry_legs`. Verify DCA-specific test coverage. (This phase may turn out to be just test-additions if the implementation is unchanged.) | 0.5 day | DCA-specific tests |
| **B-7** | Generalise `_rollback_placed_entries` → `_compensate(placed_legs, original_error)`. Walk every leg type. Wire the orchestrator to call `_compensate` from a single top-level `except ExchangeError` block. Delete the per-leg-type rollback duplications. | 2 days | integration tests for compensate covering: entry-only failure, entry+SL failure, entry+TP failure, all-types-placed-then-final-leg-fails |
| **B-8** | Top-level orchestrator rewrite: `submit_trade` body becomes ~150 lines (setup + helper sequence + persistence). The 1313-line beast is gone. Behaviour-equivalent — every existing test passes. | 1 day | full-pipeline integration test (covered by tests added in B-2..B-7) |
| **B-9** | Cleanup: remove dead variables (`stop_loss_placed`, `entry_failure_occurred`), simplify `placed_entry_orders` (now just `placed: List[PlacedLeg]`), inline trivial one-shot helpers if any. Add a top-of-file comment explaining the helper architecture. | 0.5 day | no new tests; existing suite must still pass |

Total: 9–12 working days over 9 commits. Each phase is independently
revertable and ships its own tests.

### B.4 Risks — AUD-0114

- **This is the money-moving path.** A bug here can leave a trader with a
  live position on Bybit that has no SL. Every phase requires sandbox
  validation against Bybit testnet before merging.
- **1313-line refactor without behaviour change is hard.** The function has
  evolved over many ad-hoc fixes (AUD-0121, breakeven trigger, VWAP links,
  conditional-TP tick offsets, seeded-trade splits). Some of those interact
  in subtle ways. Strategy: extract one helper per commit; integration test
  before merge; each commit independently revertable.
- **`pending_vwap_links` and `placed_tp_legs_for_reconcile`** — these list
  buffers thread through the loop and get flushed/used after the loop. The
  helpers must still populate them correctly. Likely they should become
  fields on `PlacedLeg` (e.g. `vwap_link: Optional[VwapLinkSpec]`) so the
  orchestrator can flush them after persistence in one pass.
- **Background-task scheduling for AUD-0375 TP reconciliation.** The market-
  entry path schedules a background task at line ~1700 that amends TPs once
  the actual fill is known. This must continue to work post-extraction —
  the orchestrator must collect the `placed_tp_legs_for_reconcile` payload
  from `_submit_take_profits` and schedule the task itself, not the helper.
- **The AUD-0121 pattern works for entries; verifying it generalises to
  TP/DCA needs careful case enumeration.** Specifically: a TP fill is
  irrelevant for cancellation safety (a filled TP just means the position
  closed — that's a good thing, not a leak). But a filled CTP that triggered
  a stop-out is irrelevant differently. `_compensate` needs leg-type-aware
  cancel logic; document it clearly.
- **Bybit's "10 conditional-orders per symbol" quota.** Today the AUD-0121
  comment at line 1063 explicitly notes that SL goes before CTPs to avoid
  this quota. The new orchestrator preserves this ordering — but if a future
  phase reorders for some reason, the quota issue silently re-emerges.
  **Add a structural test** that asserts the SL helper is called before the
  CTP helper in the orchestrator.

---

## Part C — Cross-cutting concerns

### C.1 Order of operations across the cluster

```
AUD-0039 (DONE) → AUD-0115 A-1..A-2 → AUD-0114 B-1..B-3
AUD-0002 A-3 (POST retry, design-ready) → AUD-0114 B-7 (compensate)
AUD-0115 A-3..A-4   →   AUD-0114 B-4..B-5
AUD-0115 A-5..A-7    (parallel, low risk)
AUD-0115 A-8 (verification)
AUD-0114 B-8..B-9 (orchestrator rewrite + cleanup)
```

The hard dependency:

- B-3 (SL helper rename) **must** wait for A-2 (SL via typed helper)
- B-5 (CTP extraction) **must** wait for A-3 (CTP via typed helper)
- B-7 (compensate) **benefits from** AUD-0002 A-3 (POST retry with orderLinkId)
  but does not strictly require it — `_compensate` can fall back to
  `cancel_by_order_link_id` if `cancel_order(orderId)` fails because the
  exchange-assigned orderId never came back. The AUD-0039 orderLinkId is
  already populated.

### C.2 Test infrastructure

The AUD-0121 test pattern (mock `bybit_client`, assert call ordering on the
mock, assert DB row state) generalises directly. Specifically:

- `tests/integration/test_trades_submit.py` should grow per-helper test files
  (`test_submit_entry_legs.py`, `test_submit_take_profits.py`, etc.) as each
  helper is extracted.
- The mock-adapter pattern: a `FakeBybitClient` that records every typed-
  helper call into a list; tests assert both the sequence of calls AND that
  no `_request` was called directly (catching AUD-0115 regressions).
- For `_compensate` testing: simulate "X legs placed, then leg N raises"
  and assert that exactly X cancellations were issued in reverse order.
- All tests use `test_db_conn` / `test_db_cursor` fixtures (transactional
  rollback) per the project's testing policy.

### C.3 Open questions

1. **`PlacedLeg` dataclass vs Pydantic model?** Recommend dataclass — internal
   type, never crosses a serialisation boundary. Existing code uses
   `Dict[str, Any]` everywhere; the dataclass is a strict improvement
   regardless of choice.
2. **Sync vs async rollback chain?** Existing `_rollback_placed_entries` is
   sync (a simple `for entry in placed_entries: bybit.cancel_order(...)`).
   Recommend keeping sync for `_compensate`. Async would help with concurrent
   cancels but adds complexity to a money-moving path; stick with sequential
   for now and revisit only if cancel latency becomes an issue.
3. **`bybit._request` call sites OUTSIDE `trades.py`?** **Yes — eight more,
   inventoried in §A.2. Migration is broader than the cluster row claims.**
   `journal.py` has 6 sites (5 cancels + 1 SL place + 1 read), and
   `suspend_service.py` has 1 site (cancel). All should be migrated as part
   of AUD-0115 Phase A-7, otherwise AUD-0002's retry policy never reaches
   them.
4. **Stop-loss API surface — `set_trading_stop` vs `place_conditional_order`?**
   The current SL placement at line 1119 uses `/v5/order/create` with
   `triggerPrice` + `orderFilter=StopOrder` — i.e., places a separate
   conditional order. The adapter ALSO has `set_trading_stop` which uses
   `/v5/position/trading-stop` to set a position-level SL. **These are
   different products on Bybit:** an order-level SL is a separately-placed
   conditional that lives in the order book (cancellable, amendable);
   a position-level SL is set on the position record. Today TradeLens uses
   the order-level approach exclusively for entry-side SLs and uses the
   position-level approach only for "clear take profit" cleanups. AUD-0115
   should NOT change this; the migration is from raw `_request` to typed
   `place_conditional_order` with the SAME endpoint. **No new
   `place_trading_stop` helper is needed** — `set_trading_stop` already
   exists for the position-level path.
5. **Should `submit_trade_json` (the JSON-edit endpoint) be deprecated?**
   Outside the scope of AUD-0114/0115, but flagged as worth confirming with
   the operator before investing significant effort in A-4.
6. **AUD-0218 reuse.** AUD-0218 (suspend transaction, parked) reportedly hit
   the "no compensating cancel" issue in the suspend/resume path. Once
   `_compensate` exists in §B.7, AUD-0218 should be re-triaged with
   `_compensate` in mind.

---

## Part D — Done criteria

For the cluster to be considered shipped:

- [ ] Every `bybit._request` call in `lib/tradelens/api/` and
  `lib/tradelens/services/` is replaced with a typed-adapter call. CI grep
  guard active.
- [ ] `submit_trade` is < 200 lines and contains only setup, helper
  invocations, and persistence. The leg placement logic lives in named
  helpers each ≤ 200 lines.
- [ ] `_compensate` exists; the orchestrator calls it from a single
  top-level `except ExchangeError` block. Every leg type cancels cleanly
  via this helper (or logs loudly when uncancellable).
- [ ] Every helper has its own integration test file with the four scenario
  groups in §B.3 (happy / mid-leg failure / already-filled-market /
  DB-write failure).
- [ ] Sandbox validation against Bybit testnet for: market entry, limit
  entry, seeded trade, DCA fan-out, market entry with conditional TPs,
  hedge-mode trade. All scenarios verified to leave consistent state on
  any single mid-cascade failure.
- [ ] AUDIT_TRACKER rows AUD-0114 and AUD-0115 marked DONE with commit
  pointers per phase.
