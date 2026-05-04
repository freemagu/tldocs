# Audit autofix triage — pilot: chunks 1 & 2

**Generated:** 2026-04-23
**Scope:** AUD-0001 through AUD-0077 (77 findings)
**Purpose:** Classify into T1 (autofix) / T2 (human-review) / T3 (architectural) / T4 (closed).
**Process:** User reviews this file. On approval, Step 2 executes T1 items autonomously.

## Counts

| Tier | Count | Meaning |
|---|---|---|
| **T1** | 14 | Ready for autonomous fix |
| **T2** | 22 | Needs a one-page proposal, then user decides |
| **T3** | 9 | Architectural — parked for dedicated tasks |
| **T4** | 32 | Already Resolved / Works-as-intended / duplicate of a Resolved item |
| **Total** | 77 | |

Of the 45 "live" items (T1+T2+T3), T1 covers about 31% — consistent with the
overall tracker shape where the majority of findings need at least a design
decision. That's exactly the point of partitioning.

---

## T1 — Autonomous fix queue (14)

Executed in this order. Each gets pre-test, fix, regression test, post-test,
commit. Grouped by file so same-file work shares a worktree.

### lib/tradelens/core/pg_pool.py (high-scrutiny — every request touches it)
- **AUD-0001** Critical/Bug — `get_db_connection` context manager leaks
  connection on non-`InterfaceError` exceptions. Fix: swap `else:` for a
  `finally:` with a `close_it` flag. **Extra test scrutiny:** add a
  regression unit test that raises e.g. `ValueError` inside the `with` block
  and asserts the connection is returned to the pool.
- **AUD-0013** Major/Reliability — `putconn` failures swallowed; change to
  WARNING log. Single-file, purely additive. *Batched with AUD-0001.*

### lib/tradelens/core/pg_pool.py, DSN layer
- **AUD-0009** Major/Performance — Move `SET timezone TO 'UTC'` from per-
  acquire `_prepare_connection` into the DSN `options='-c timezone=UTC'`.
  `test_pg_dsn.py` already exercises DSN construction, extend it.

### lib/tradelens/adapters/bybit_client.py
- **AUD-0014** Major/Reliability — `close_all_bybit_clients` holds module
  lock across `await`; snapshot dict, clear under lock, close outside.
- **AUD-0015** Major/Reliability — Unbounded cursor loops in
  `get_open_orders`, `get_positions`, `get_instrument_info`. Cap at 50 +
  break on `cursor == prev_cursor`. Purely additive defensive guard.
- **AUD-0025** Minor/Cleanup — Standardise `get_klines` default limit to
  match `get_klines_batched`'s 1000. Search for callers using the default
  first to confirm none relies on 200. If any do, demote to T2.
- **AUD-0027** Minor/Cleanup — Replace `print()` debug dump with a
  dedicated `tradelens.adapters.bybit.wire` DEBUG logger. Behaviour-visible
  only with env var + log config, no change to production.
- **AUD-0040** Major/Duplication — Extract `_sign(method, params, ts,
  recv_window)` helper; call from both GET and POST branches. Pure
  refactor, covered by existing `test_bybit_mock_pattern.py`.
- **AUD-0041** Info/Duplication — Delete `bin/levelguard_cli.py`; keep
  `bin/tools/levelguard_cli.py`. md5 verified identical
  (`ea045b20198390ff22f3cd5127136c0c`); AUD-0186 flags the bin/ copy as
  using a broken path-resolution block, so delete that one. Also update
  any docs/shortcuts that reference the deleted path (grep first).

### lib/tradelens/core/config.py
- **AUD-0032** Minor/Dead Code — Delete `AppConfig.snapshots` legacy alias.
  Verified: zero `.snapshots` references in `lib/` or `bin/`.
- **AUD-0033** Minor/Dead Code — Delete `market_candle_db: str = "pg"`
  field. Verified: only one reference exists — a comment in
  `bin/pipeline/refresh_trade_journal.py:148` — and it's stale, no branch
  guards remain.

### lib/tradelens/utils/initial_risk_calculator.py
- **AUD-0052** Major/Performance — Add `LIMIT 1` to fetchone queries
  following `ORDER BY ... DESC` at the sites the tracker lists (lines 348,
  385, 498, 529, 1437, 1505, 1701). Mechanical; no math change. Covered by
  existing integration tests; add one `test_*_limit_pushed_down` unit
  test over the generated SQL for regression.

### lib/tradelens/services/sizing.py
- **AUD-0061** Minor/Dead Code — Drop unused `symbol` parameter from
  `calculate_position_size` and `calculate_quantity_sizing`, OR rename to
  `_symbol` if any caller still passes it positionally. Will grep call
  sites before deciding between drop / rename. Existing `test_sizing.py`
  covers behaviour.

### lib/tradelens/utils/waep_tracker.py
- **AUD-0065** Minor/Cleanup — Replace 14-line `if not isinstance...`
  block in `PositionState.__post_init__` with a validator loop over the
  Decimal-typed fields. Pure refactor; `test_waep_tracker.py` covers it.

---

## T2 — One-page proposal queue (22)

These need a human call. For each, I'll produce a short proposal and wait.

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0006** | Critical/Bug | Already flagged Deferred; changes `place_conditional_order` public signature — clashes with in-flight level_guard work per tracker note |
| **AUD-0010** | Major/Arch | Making `BybitClient.__init__` private changes 15+ call sites; factory pattern decision |
| **AUD-0011** | Major/Reliability | New httpx Timeout / Limits / retries config — behaviour change across every call |
| **AUD-0012** | Major/Reliability | `AccountContext` fail-fast vs lazy-reload vs keep-current — three viable answers |
| **AUD-0017** | Minor/Suspicious | Remove `periodic_gc` — may be load-bearing; needs memory profile first |
| **AUD-0021** | Minor/Cleanup | Wrap `load_config` in factory — changes module-import semantics across the project |
| **AUD-0024** | Minor/Cleanup | Drop `AccountContext.__new__` singleton — subtle init-order change |
| **AUD-0028** | Minor/Suspicious | Refuse unknown account names at construction — changes failure mode |
| **AUD-0029** | Minor/Cleanup | Pick one error convention — cross-method behaviour change |
| **AUD-0031** | Minor/Dead Code | `_fallback_warned` warn→raise — changes failure mode for standalone scripts |
| **AUD-0034** | Minor/Dead Code | Delete `BybitClient.close` — tracker note flags 20+ callers; no longer "dead code removal" |
| **AUD-0037** | Major/Arch | Split YAML-load from DB-sync in AccountContext — import-order change |
| **AUD-0039** | Major/Reliability | Require orderLinkId on every placement — prerequisite for AUD-0002 |
| **AUD-0048** | Major/Duplication | Extract `_build_legs` helper — money-moving sizing code, high risk without battery of tests |
| **AUD-0050** | Major/Performance | Batch-fetch events — performance fix but complex; needs real-DB integration test |
| **AUD-0051** | Major/Performance | Similar N+1 batching |
| **AUD-0053** | Major/Bug | 4-tuple → dataclass in WAEPTracker — changes internal API across many call sites |
| **AUD-0054** | Major/Bug | Parameterise full-close tolerance by `qty_step` — money-moving math |
| **AUD-0056** | Major/Bug | Rename/replace `profit_pct` — UI-visible |
| **AUD-0059** | Major/Performance | Inject shared reader handle — changes API signature |
| **AUD-0062** | Minor/Cleanup | Sort TPs by price — UI output order change |
| **AUD-0077** | Major/Arch | Accept Decimal at sizing boundary — API signature change |

---

## T3 — Architectural / deferred (9)

No attempt in this workstream. Each becomes a dedicated task.

| ID | Severity | Why T3 |
|---|---|---|
| **AUD-0002** | Critical/Reliability | Full retry / backoff / circuit-breaker / rate-limit policy |
| **AUD-0008** | Major/Arch | Delete `PooledDB` + `db_pool.py` shim + migrate 30+ API files |
| **AUD-0016** | Major/Config | Pydantic nested models with `extra='forbid'` — cross-cutting refactor |
| **AUD-0030** | Minor/Dead Code | Actually depends on AUD-0008 landing first |
| **AUD-0035** | Major/Arch | Same DB-connection lifecycle as AUD-0008 |
| **AUD-0036** | Major/Arch | Move trading policy out of `bybit_client.py` — big refactor |
| **AUD-0038** | Major/Arch | Same as AUD-0016 |
| **AUD-0058** | Major/Arch | Split 1,781-line `initial_risk_calculator.py` |
| **AUD-0076** | Major/Test Gap | Depends on AUD-0058 |

---

## T4 — Closed already (32)

Resolved / Works-as-intended / duplicated by a Resolved item:
AUD-0003, 0004, 0005, 0007, 0018, 0019, 0020, 0022, 0023, 0026,
0042, 0043, 0044 (WAI), 0045, 0046, 0047, 0049, 0055, 0057, 0060,
0063, 0064, 0066, 0067, 0068, 0069, 0070, 0071, 0072,
0073 (duplicate — allow-list fix landed as part of AUD-0042),
0074, 0075 (WAI).

---

## Execution plan for Step 2

Order of T1 work (groups findings by file to share worktrees):

1. **pg_pool.py batch** (AUD-0001, 0009, 0013) — load-bearing, do first, extra test coverage
2. **bybit_client.py batch** (AUD-0014, 0015, 0025, 0027, 0040) — share worktree
3. **config.py dead-alias batch** (AUD-0032, 0033) — trivial, verify nothing downstream broke
4. **bin/ duplicate** (AUD-0041) — single-file deletion
5. **initial_risk_calculator.py LIMIT 1 sweep** (AUD-0052)
6. **sizing.py dead arg** (AUD-0061)
7. **waep_tracker.py validator loop** (AUD-0065)

Seven batches, 14 findings. Estimated 7 commits (one per batch, since
batches are file-scoped).

## Review checklist for you

Before I start Step 2, please eyeball:

- [ ] Any T1 item that should be T2? (Most likely candidates for pushback:
      AUD-0025 if get_klines callers rely on the 200 default; AUD-0027 if
      wire logs go somewhere that parses them.)
- [ ] Any T2 item that should be T1 because the risk I flagged is imaginary?
- [ ] Any T3 item you'd rather tackle now as T2?
- [ ] Ordering — is there a file you'd rather I start on or avoid?

Reply "go" to kick off Step 2 on the T1 batch, or name the IDs you want
moved between tiers.
