---
status: design-ready-for-implementation
generated: 2026-04-26
authors: claude-orchestrator-via-subagent
audit-ids:
  - AUD-0155 (formal state machine for leg_type reclassification)
  - AUD-0170 (OrderClassifier decomposition)
  - AUD-0171 (writer/reader split — pick one writer)
tier: T3
related:
  - AUD-0078 already-shipped Option B (inline INSERT pattern that depends on the classifier)
  - AUD-0098 (race windows mentioned in 0171)
  - AUD-0001 (DB pool slot leak — same pipeline area)
---

# AUD-0155 + AUD-0170 + AUD-0171 — pipeline state machine, classifier decomposition, writer/reader split

> **Documentation only.** Three tightly-coupled architecture items that together
> constitute the LARGEST T3 design pass: a formal state machine for the
> `leg_type` IMMUTABLE invariant + its three exceptions (AUD-0155), a
> decomposition of the `OrderClassifier` god-object (AUD-0170), and a
> writer/reader split for the `order_leg_live` / `order_leg_hist` tables that
> closes the AUD-0098 race windows (AUD-0171). Each phase below is a separate
> future commit and requires the operator's go-ahead before it lands.
>
> The ordering is load-bearing: **AUD-0155 first** (FSM is the smallest unit
> of risk reduction; standalone module + unit tests; can land without
> touching the writer/reader split). **AUD-0170 next** (decomposition lands
> the FSM into the larger class — the FSM gives 0170 a clean state-touch
> point to plug into). **AUD-0171 last** (biggest blast radius — flips
> writer semantics; needs both the FSM and the decomposed classifier in
> place so the reconciler-shaped pipeline has tractable invariants).

## 0. The audit rows

```
| AUD-0155 | 5 | Major | Architecture | Confirmed | bin/pipeline/refresh_order_leg_live.py |
"leg_type IMMUTABLE" invariant + 3 exceptions
Invariant doc followed by three-way reclassification logic (seeded→entry,
entry→seed, stop↔tp) with overlapping boolean flags.
Classification bugs will live here; hard to reason about.
Formal state machine.
refresh_order_leg_live.py:2156-2216.

| AUD-0170 | 5 | Major | Architecture | Confirmed | bin/pipeline/refresh_order_leg_live.py |
`OrderClassifier` god-object
Holds 6+ state maps + Bybit client + WAEPTracker; every method reaches into it.
Untestable in isolation.
Decompose into caches + rules classes.
refresh_order_leg_live.py:49-60.

| AUD-0171 | 5 | Major | Architecture | Confirmed | bin/pipeline/ |
writer/reader split broken
Pipeline is supposed to be sole writer but API also writes, then spawns pipeline
as subprocess to sync.
Race windows (AUD-0098); double-writes; subprocess cost.
Pick one writer; the other becomes reconciler.
cross-chunk.
```

T3 / Bucket F. **Money-moving path proximity.** The classifier sits between the
Bybit fetch and the database write, so every classification change ships with
integration tests, and every commit must pass full pytest. Estimated 2–3 weeks
of effort across multiple sessions.

---

## 0.1 Status-quo verification (2026-04-26 against worktree at `4a960136`)

`bin/pipeline/refresh_order_leg_live.py` is **2792 lines** total.

| Subject | Cluster claim | Verified |
|---|---|---|
| `OrderClassifier` class start | line 49–60 | **lines 50–62** (drift ~1–2 lines; class spans through ~line 1352) |
| AUD-0155 reclassification block | lines 2156–2216 | **lines 2219–2279** (drift ~60 lines forward; located by content `# DESIGN INVARIANT: Order intent (leg_type) is IMMUTABLE`) |
| Sister IMMUTABLE comment for archive path | not in cluster | **line 1562** (`_archive_from_live_snapshot` has the *same* invariant doc but only handles 1 implicit transition — preserve old `leg_type` over inferred. AUD-0155 must cover BOTH sites.) |
| `leg_type` domain values | not in cluster | `seed`, `entry`, `dca`, `tp`, `stop` (verified by `grep -n "leg_type =\|leg_type ='"` — the textual states; `closed` / `cancelled` are tracked on the `status` column, not `leg_type`) |

**Key finding from verification (open question 1, partially answered):** The
"3 exceptions" claim is incomplete. The reclassification block at lines
2230–2279 contains **3 explicit exceptions** (the `allow_reclassify_*` flags),
but `_classify_single_order` itself contains **3 additional implicit
reclassifications** at the *first-classification* step (not preservation):

1. **Line 659–665**: synthetic-position `dca` → `entry` when price matches
   `pending_context.expected_entry` within 0.01% tolerance.
2. **Line 676–679**: any `leg_type` → `seed` when the order_id is in
   `self.seed_orders` (this fires BEFORE the `seeded_entry_orders` check, so a
   seed order will short-circuit the dca→entry path).
3. **Line 684–688**: `dca` → `entry` when the order_id is in
   `self.seeded_entry_orders` (the *primary* limit entry of a seeded trade).
4. **Line 696–709**: trigger-price-vs-action heuristic for conditional orders
   that lack `stopOrderType` — this writes `tp` or `stop` but is gated by
   `not stop_order_type` (so it's a fallback, not an override).

So the cluster's 3-exceptions number refers to the *preservation* path
(`old_snapshot.leg_type` exists → which transitions does the new classification
override). The *first-classification* path also has implicit transitions, and
the FSM must cover both. **Both sites currently invoke the same flat boolean
matrix; the FSM gives them a single source of truth.**

Sister site at `_archive_from_live_snapshot` (line 1562) handles archive-path
classification. It uses *only* the IMMUTABLE rule with no exceptions — when an
order disappears from Bybit's live list and we copy it to `order_leg_hist`, the
new classifier output is **always** discarded in favour of the preserved
`leg_type`. The FSM must treat archive-on-disappear as a distinct transition
context: it allows nothing.

---

## 1. AUD-0155 — formal state machine for `leg_type` reclassification

### 1.1 Status quo (lines 2219–2279)

```python
# DESIGN INVARIANT: Order intent (leg_type) is IMMUTABLE once classified.
# Price movement NEVER changes intent. A stop moved to breakeven is still a stop.
# Price-based classification is inference-only and first-sighting-only.
#
# EXCEPTIONS for seeded trades:
# 1. Seeded trade entry orders: 'dca' -> 'entry' (limit order that defines intended entry)
# 2. Seed orders: 'entry' -> 'seed' (market order that establishes initial position)
if old_snapshot.get('leg_type'):
    original_leg_type = leg.get('leg_type')        # newly inferred
    preserved_leg_type = old_snapshot['leg_type']  # last persisted
    # ... 3 boolean flags ...
    is_seeded_entry_order   = (...)
    allow_reclassify_to_entry = (...)
    is_seed_order           = (...)
    allow_reclassify_to_seed  = (...)
    allow_reclassify_stop_tp  = (...)
    if   allow_reclassify_stop_tp:    # keep new
    elif allow_reclassify_to_entry:   # keep new
    elif allow_reclassify_to_seed:    # keep new
    elif original_leg_type != preserved_leg_type:
        leg['leg_type'] = preserved_leg_type      # override with preserved
```

The three explicit transitions in this block, restated as an FSM:

| From (preserved) | To (inferred) | Guard | Source |
|---|---|---|---|
| `dca` | `entry` | `exchange_order_id ∈ classifier.seeded_entry_orders` | seeded-trade primary limit |
| `tp`  | `entry` | `exchange_order_id ∈ classifier.seeded_entry_orders` | seeded-trade primary limit (misclassified at first sighting because seed fill price ≠ intended entry) |
| `entry` | `seed` | `exchange_order_id ∈ classifier.seed_orders` | seed market order |
| `stop` | `tp` | `pending_context_map[symbol].expected_entry` is set AND `preserved_leg_type ∈ {stop,tp}` AND `inferred_leg_type ∈ {stop,tp}` AND they differ | seeded-trade pending-context correction |
| `tp` | `stop` | (same guard) | seeded-trade pending-context correction |
| any | any (= preserved) | none of the above | IMMUTABLE fallback (override inferred with preserved) |

### 1.2 Design — formal state machine

#### States

The `leg_type` domain (verified against `bin/pipeline/refresh_order_leg_live.py`
+ `etc/schema.md`):

```
seed | entry | dca | tp | stop
```

Closed/cancelled states are tracked on `status`, not `leg_type` — out of scope
for this FSM. The FSM operates on `leg_type` reclassification only.

#### Transition contexts

Three orthogonal classification contexts trigger transitions, each with
different rules:

1. **`first-sighting`** (no `old_snapshot` exists) — classifier infers from
   raw order + position + pending context. Implicit transitions inside the
   single classification call (see status-quo finding §0.1: `dca→entry`,
   `*→seed`, `dca→entry` again for seeded entry, conditional trigger heuristic).
   FSM: every initial classification is allowed.

2. **`reclassification`** (`old_snapshot.leg_type` exists, order still on Bybit)
   — classifier infers a new `leg_type`; FSM decides whether to keep the new
   one or revert to preserved. This is the AUD-0155 block at line 2219.

3. **`archive-on-disappear`** (`old_snapshot.leg_type` exists, order is no
   longer on Bybit, copying to `order_leg_hist`) — classifier infers from
   stale data. FSM: ALWAYS prefer preserved (sister site at line 1562).

#### Transition table (reclassification context)

ALLOWED transitions, evaluated in priority order:

| # | From | To | Guard predicate | Result |
|---|---|---|---|---|
| 1 | `stop` | `tp`  | `stop_tp_correction(symbol, pending_context_map)` | keep inferred |
| 2 | `tp`  | `stop` | `stop_tp_correction(symbol, pending_context_map)` | keep inferred |
| 3 | `dca` | `entry` | `is_seeded_entry_order(exchange_order_id, seeded_entry_orders)` | keep inferred |
| 4 | `tp`  | `entry` | `is_seeded_entry_order(exchange_order_id, seeded_entry_orders)` | keep inferred |
| 5 | `entry` | `seed` | `is_seed_order(exchange_order_id, seed_orders)` | keep inferred |
| 6 | `X` | `X` | always | keep (no-op) |
| 7 | `X` | `Y` | none of 1–5 match | revert to `X` (preserved) |

Every other (from, to) pair is IMMUTABLE. There are no "forbidden" pairs in the
sense of "raise an exception" — the IMMUTABLE rule (#7) silently reverts. This
is deliberate: classifier inference is heuristic and we don't want one
misclassification on a single fetch to crash the pipeline. But each #7 revert
**must** log a structured event so the audit trail is preserved.

#### Transition table (archive-on-disappear context)

ALLOWED transitions: only #6 (no-op). Every classifier output for a vanishing
order is discarded in favour of the preserved `leg_type`. (This matches today's
`_archive_from_live_snapshot` line 1565–1570 behaviour.)

#### Guards — encapsulated predicates

The boolean guards from the status quo become named predicates with explicit
inputs:

```python
def stop_tp_correction(
    symbol: str,
    pending_context_map: Dict[str, dict],
    preserved: str,
    inferred: str,
) -> bool:
    """True iff we have an authoritative expected_entry for this symbol AND
    the inferred classification would flip stop↔tp at the same price level."""
    ctx = pending_context_map.get(symbol.upper())
    return (
        ctx is not None
        and ctx.get('expected_entry') is not None
        and preserved in ('stop', 'tp')
        and inferred  in ('stop', 'tp')
        and preserved != inferred
    )

def is_seeded_entry_order(
    exchange_order_id: str,
    seeded_entry_orders: Dict[str, str],
) -> bool:
    return exchange_order_id in seeded_entry_orders

def is_seed_order(
    exchange_order_id: str,
    seed_orders: Dict[str, dict],
) -> bool:
    return exchange_order_id in seed_orders
```

The guards take their state-map dependencies as **explicit arguments**. This is
important for AUD-0170 — the FSM must NOT reach into `OrderClassifier`
directly, because that ties the FSM lifecycle to the classifier's god-object
state.

#### Implementation choice

Two options considered:

- **Option A — class-based FSM with a transition table** (e.g.
  `transitions` library, or hand-rolled `@dataclass` with `_transitions: Dict[(str,str), Guard]`).
  Higher ceremony; better introspection (state diagram emit, runtime validation);
  comparatively heavy for 5 valid transitions.
- **Option B — pure function `transition(preserved, inferred, ctx) -> str`**
  with the transition table as a module-level dict-of-tuple-keys.
  Tiny surface; trivial to unit-test; matches the existing imperative shape.

**Decision: Option B.** Simpler, smaller LOC delta, easier to audit. We can
always upgrade to Option A later if the transition count grows past ~10.

API sketch (for the design — actual implementation in Phase 1):

```python
# lib/tradelens/pipeline/leg_type_fsm.py
from dataclasses import dataclass
from typing import Optional, Literal, Dict

LegType = Literal['seed', 'entry', 'dca', 'tp', 'stop']
Context = Literal['first-sighting', 'reclassification', 'archive-on-disappear']

@dataclass(frozen=True)
class TransitionInputs:
    preserved: Optional[LegType]      # None on first-sighting
    inferred: LegType
    context: Context
    exchange_order_id: str
    symbol: str
    seeded_entry_orders: Dict[str, str]
    seed_orders: Dict[str, dict]
    pending_context_map: Dict[str, dict]

@dataclass(frozen=True)
class TransitionResult:
    final: LegType
    reason: str            # human-readable, used for log/event line
    rule_id: str           # 'rule-1-stop-tp' / 'rule-7-immutable-revert' / ...

def decide_leg_type(inp: TransitionInputs) -> TransitionResult: ...
```

Every reclassification call site replaces its inline boolean matrix with one
`decide_leg_type(...)` call. The result's `rule_id` is logged on every
transition (allowed or reverted), giving a per-order audit trail that today's
code lacks.

### 1.3 Phased plan — AUD-0155

| Phase | Scope | Tests | Effort |
|---|---|---|---|
| **A-1** | Write `lib/tradelens/pipeline/leg_type_fsm.py` standalone — module + docstrings + transition table + `decide_leg_type` function. NO call-site changes. | New `tests/unit/test_leg_type_fsm.py` — ~20 cases covering each rule + the IMMUTABLE fallback + edge cases (None preserved on first-sighting; missing pending_context; seeded order with both seed and seeded_entry membership). | 1 day |
| **A-2** | Wire FSM into the `reclassification` site at line 2219 (`upsert_legs_to_db`). Original boolean matrix is REPLACED — the FSM is now the single source of truth for that block. Sister site at `_archive_from_live_snapshot` line 1562 also wired (with `context='archive-on-disappear'`). NO behaviour change — the FSM's transition table mirrors the existing flags. | Augment `tests/integration/test_refresh_order_leg_live.py` — add cases that exercise each of rules 1–5 end-to-end against `tradelens_test`. | 1–2 days |
| **A-3** | Once Phase 2 is stable (≥1 week of green pytest + zero pipeline alerts), wire FSM into the `first-sighting` site (lines 657–688 — the implicit transitions in `_classify_single_order`). This is the bigger payoff: today those transitions live as inline `leg_type = '...'` reassignments scattered across 30 lines; replace with a single `decide_leg_type(..., context='first-sighting')` call. | Same integration tests; add unit tests for the new first-sighting rules. | 1–2 days |
| **A-4** | Operator-only: review per-order audit-trail logs from production (1 week of pipeline runs) to confirm no surprise transitions are firing. If clean, delete the `# EXCEPTIONS for seeded trades` block comment in favour of pointing at the FSM's transition table. | Log review; no test changes. | 0.5 days (operator-led) |

**Risk:** every phase is on the hot pipeline path. Full pytest gate every commit;
the integration suite must pass before merge.

---

## 2. AUD-0170 — `OrderClassifier` decomposition

### 2.1 Status quo (lines 50–62)

```python
class OrderClassifier:
    def __init__(self, bybit_client: BybitClient, explain: bool = False):
        self.bybit = bybit_client
        self.positions_map = {}           # (symbol, category) → {side, size, entryPrice}
        self.pending_context_map = {}     # symbol → {side, expected_entry, trade_idea_id}
        self.seeded_entry_orders = {}     # exchange_order_id → symbol
        self.seed_orders = {}             # exchange_order_id → {symbol, position_idx}
        self.smart_order_positions = {}   # exchange_order_id → position_idx
        self.mark_prices = {}             # symbol → Decimal
        self.waep_tracker = WAEPTracker() # WAEP calculation helper
        self.explain = explain
```

That's **7 state maps** + a Bybit client + a WAEPTracker + an explain flag — the
cluster's "6+" undercount.

#### Methods + state touch (verified by reading lines 50–1352)

| Method | Line | State touched |
|---|---|---|
| `__init__` | 53 | initialises all 7 maps |
| `fetch_context` | 64 | mutates `positions_map`, `pending_context_map`, `seeded_entry_orders`, `seed_orders`, `smart_order_positions`, `mark_prices`; calls `bybit` |
| `_load_pending_contexts` | 169 | mutates `pending_context_map` |
| `_load_seeded_trades` | 208 | mutates `seeded_entry_orders` |
| `_load_seed_orders` | 255 | mutates `seed_orders`, `smart_order_positions` |
| `classify_orders` | 302 | reads `bybit`; calls `_classify_single_order` |
| `_classify_single_order` | 526 | reads `positions_map`, `pending_context_map`, `seeded_entry_orders`, `seed_orders`, `mark_prices`; calls `_classify_with_position`, `_classify_without_position`, `_validate_classification`, `_calculate_waep_after_leg` |
| `_print_classification_explanation` | 775 | reads explain; pure logging |
| `_classify_with_position` | 974 | pure-ish; reads no `self` state besides `explain` |
| `_validate_classification` | 1115 | pure (asserts only) |
| `_classify_without_position` | 1180 | pure-ish; reads no `self` state besides `explain` |
| `_calculate_waep_after_leg` | 1300 | reads `waep_tracker`, `positions_map` |

#### External dependencies

- `BybitClient` — only used in `fetch_context` (REST orders fetch) and
  `classify_orders` (REST orders fetch).
- `WAEPTracker` — only used in `_calculate_waep_after_leg`. Verified
  largely-stateless: `apply_leg(...)` takes a position dict, returns
  `ApplyLegResult`; the tracker holds no per-order accumulator state. (Open
  question 2 answered: WAEPTracker is safe to extract because the position
  state lives in the caller, not the tracker.)
- `get_combined_portfolio` (from `services.portfolio`) — used inside
  `fetch_context` to populate `positions_map`.

### 2.2 Design — caches + rules + thin orchestrator

The decomposition splits today's god-object into three layers:

#### Layer 1 — Caches (data containers, no logic)

```
lib/tradelens/pipeline/caches/
    __init__.py
    position_cache.py        # PositionCache - wraps positions_map + mark_prices
    pending_context_cache.py # PendingContextCache - wraps pending_context_map
    seeded_orders_cache.py   # SeededOrdersCache - wraps seeded_entry_orders
                             #   + seed_orders + smart_order_positions
```

Each cache is a `@dataclass` with explicit `load_from_db(conn, account_id)` and
`load_from_bybit(bybit_client, ...)` methods, NO classification logic. Trivial
to construct in tests with hand-rolled fixtures.

#### Layer 2 — Rules classes (pure logic, no state)

```
lib/tradelens/pipeline/rules/
    __init__.py
    leg_type_classifier.py   # decides initial leg_type given order + caches
    leg_type_fsm.py          # the AUD-0155 transition function (Phase A-1)
    waep_classifier.py       # thin wrapper over WAEPTracker.apply_leg
    lineage_resolver.py      # decides lineage_id given order + caches +
                             #   sibling-leg lookup
```

Each rules class is **stateless**: every method takes the caches and the order
as arguments and returns a classification. Unit-testable in isolation with
fake caches.

`leg_type_classifier.py` absorbs today's `_classify_single_order`,
`_classify_with_position`, `_classify_without_position`,
`_validate_classification` (which is already pure). The position-resolution
branching (Case A / B / C in lines 633–672) becomes a private helper.

#### Layer 3 — Thin orchestrator

```
lib/tradelens/pipeline/order_classifier.py
class OrderClassifier:
    """Wires caches + rules. No business logic."""
    def __init__(self, bybit, position_cache, pending_cache, seeded_cache,
                 leg_classifier, waep_classifier, lineage_resolver,
                 explain=False): ...

    def fetch_context(self, conn, account_id, ...): ...   # delegates to caches
    def classify_orders(self, ...): ...                   # delegates to rules
```

Everything that's currently `self.foo` becomes either a dependency injected by
the constructor or an explicit cache lookup. Replaces today's god-object 1:1
at every call site (`bin/pipeline/refresh_order_leg_live.py:main` and
`bin/pipeline/refresh_order_leg_hist.py:main`), so the public API is unchanged.

#### Why this shape

- **Testability** — today, `_classify_single_order` requires constructing an
  `OrderClassifier` with a real Bybit client + 7 maps populated. After
  decomposition, you instantiate `LegTypeClassifier()` (no arguments — pure)
  and pass dict caches in.
- **Locality** — bug reports about misclassifications will say "rule-3
  fired but should have been rule-5" instead of "look at the 60-line
  boolean matrix." This is what AUD-0155 was setting up.
- **No perf regression** — same data, same path, same number of dict
  lookups; the cost is one extra call frame per classification.

### 2.3 Phased plan — AUD-0170

| Phase | Scope | Tests | Effort |
|---|---|---|---|
| **B-1** | Extract caches as `@dataclass` containers, additive only. Original `OrderClassifier` keeps its 7 maps but DELEGATES to the cache classes (e.g. `self.positions_map = self._position_cache.positions_map`). No behaviour change. | New `tests/unit/test_position_cache.py`, etc. | 1 day |
| **B-2** | Extract `LegTypeClassifier` rules class (most complex — 3 sub-methods + the `_classify_single_order` orchestration). `OrderClassifier._classify_single_order` becomes a one-line delegate. **AUD-0155 Phase A-3 must already be merged** (the FSM must exist before this phase folds first-sighting transitions into the rules class). | Existing integration tests + new `tests/unit/test_leg_type_classifier.py` (with fake caches). | 2 days |
| **B-3** | Extract `WAEPClassifier` (trivial — wraps `WAEPTracker.apply_leg`). | New unit test. | 0.5 days |
| **B-4** | Extract `LineageResolver` (medium — touches `lineage_id` derivation; must coordinate with `derive_lineage_id` from `services.trade_lineage`). | New unit test + integration check on `repair_trade_lineage.py` integration. | 1 day |
| **B-5** | Replace the original `OrderClassifier` with the thin orchestrator shape. The 7 maps become read-only properties that delegate to caches (kept for backward compat with `upsert_legs_to_db` which still references `classifier.seeded_entry_orders` etc. at line 2234). | Full integration suite. | 1 day |
| **B-6** | Delete the read-only properties from B-5 once `upsert_legs_to_db` is updated to take the caches directly (pre-req for AUD-0171 Phase D). | Full integration suite. | 0.5 days |

**Risk note:** the classifier is on the hot pipeline path. Each phase ships
behind a full pytest gate AND a 24-hour soak in production with the previous
shape running side-by-side (one canary account first; ramp after).

**Open question 2 — WAEPTracker:** verified during status-quo review that
`WAEPTracker` does NOT hold mutable per-order state (the position dataclass is
passed in/out of `apply_leg`). So Phase B-3 is genuinely trivial. **Resolved.**

---

## 3. AUD-0171 — writer/reader split, pick one writer

### 3.1 Status quo

The pipeline is **supposed** to be the sole writer to `order_leg_live` /
`order_leg_hist`. In reality, there are six write sites today (verified by
`grep -rn "INSERT INTO order_leg_live\|UPDATE order_leg_live"
lib/tradelens bin/`):

| Site | File | Lines | Role |
|---|---|---|---|
| Pipeline (intended sole writer) | `bin/pipeline/refresh_order_leg_live.py` | 1528, 1868, 1983, 2041, 2334, 2441, 2482 | Authoritative classify+upsert from Bybit |
| Pipeline historical | `bin/pipeline/refresh_order_leg_hist.py` | 1185, 1278, 1344 | Authoritative archive from `getOrderHistory` |
| API — open_orders.py | `lib/tradelens/api/open_orders.py` | 1549, 1899, 2200, 2406, 3022, 3057 | AUD-0078 inline INSERTs (`convert_to_limit`, `create_order`); guarded-amend UPDATE; VWAP price-stamp UPDATE |
| API — journal.py | `lib/tradelens/api/journal.py` | 5088, 5170 | UPDATE (likely manual edit / breakeven sync) |
| Engine — VWAP | `bin/engine/vwap_order_engine.py` | 560–603 | Engine-driven UPDATEs to `price`, `trigger_price`, `guard_state_json` |
| Daemon — level guard | `bin/server/level_guard_daemon.py` | 355, 382 | UPDATE `guard_state_json`; INSERT into `order_leg_hist` on close |
| Tools — levelguard CLI | `bin/tools/levelguard_cli.py` | 262 | INSERT (one-shot tool) |
| Tools — repair lineage | `bin/tools/repair_trade_lineage.py` | 197 | UPDATE (one-shot repair) |

Today the API-after-Bybit-success pattern is: API performs Bybit call → API
INSERT (AUD-0078 Option B inline) → API schedules `refresh_order_data` via
`BackgroundTasks` (AUD-0222 mostly migrated this from `subprocess.Popen` —
verified at `open_orders.py` lines 835, 916, 1659–1660, 2373, 3068–3076,
4558–4560). The pipeline runs ~10–15s later and UPSERTs the same row,
classifier-authoritative.

The race window AUD-0098 names: between the API's exchange-success and the
pipeline's reconcile, Bybit read-after-write lag means the pipeline can briefly
read stale state (e.g. price not yet propagated). The "stamp price into
`order_leg_live`" hack at `open_orders.py:2391–2412` exists to compensate for
this — the API patches the local row with the known-correct VWAP price so the
pipeline's later UPSERT doesn't overwrite with stale Bybit data. This is a
compensation that only works if the timing aligns; if the BackgroundTasks
refresh races a competing manual `tl refresh`, the stale Bybit read can win.

### 3.2 Design — pick ONE writer

#### Option 1 — API is the sole writer; pipeline becomes a reconciler

Closer to the current shape after AUD-0078 Option B's inline INSERTs. Every
state-changing API endpoint owns its DB write (already true for create / convert
/ guarded-amend / VWAP-stamp). The pipeline shrinks to a reconciliation role:

- It still fetches Bybit and classifies, but it never INSERTs. It only UPDATEs
  rows the API has already inserted (catching late fills, qty drift, status
  transitions, classifier corrections). Idempotent `ON CONFLICT DO UPDATE`.
- For orders the API can't know about (e.g. exchange-side liquidation,
  conditional-order auto-creation by Bybit when SL/TP triggers), the pipeline
  is permitted to INSERT — but only under a strict "row absent for ≥30s after
  Bybit timestamp" guard so it can't race a brand-new API insert.

#### Option 2 — Pipeline is the sole writer; API issues request messages

API performs Bybit call → API enqueues a request message (DB row in a queue
table) → pipeline (or a dedicated worker) processes the message synchronously
(blocks until DB write happens) → API returns "pending" or waits for
confirmation.

Async / event-sourced. Cleaner conceptual model but a much bigger lift —
requires a queue table, a worker, retry semantics, dead-letter handling, and
a synchronous API path that waits for the worker to ack.

#### Recommended: Option 1

- Smaller delta: AUD-0078 Option B already moved create/convert to inline
  INSERTs; only ~3 more endpoints to convert (guarded-amend, VWAP-stamp,
  journal.py UPDATEs are all already inline-write-shaped).
- Closer to current operator mental model: "API places order → API updates DB
  → pipeline reconciles."
- AUD-0098's stamp-price hack stops being a hack: it becomes the canonical
  pattern (API is authoritative for what it just did; pipeline can only
  *correct*, never *overwrite*).

**Open question 3 — operator confirmation needed:** does the operator agree
with Option 1? If not, the writer/reader split is materially different. Default
assumption: Option 1 unless overruled.

### 3.3 Race-window analysis (AUD-0098 specifics)

Three race scenarios in today's code:

1. **API insert + concurrent pipeline upsert** — API places order, inline
   INSERTs row R, schedules BG refresh. Operator runs `tl refresh-order-data`
   manually in the same second. Both pipeline runs see Bybit (which may not
   yet have the new order), don't find it, do nothing. R remains. SAFE
   today; safe under Option 1.

2. **API insert + pipeline overwrite** — API places order, inline INSERTs
   R with `price=100`. Pipeline runs at T+12s; Bybit returns the order with
   `price=100` (correct). Pipeline UPSERTs R with classifier-authoritative
   `leg_type` / `lineage_id`. UNSAFE if pipeline misclassifies (because R's
   `leg_type` came from the API which used trade-spec context, while the
   pipeline only sees Bybit fields). Today's mitigation: AUD-0155 IMMUTABLE
   rule preserves the API-set leg_type. **Under Option 1: pipeline never
   overwrites `leg_type` (it's always preserved or transitioned via the
   FSM)** — same outcome but explicit.

3. **API VWAP price-stamp + pipeline overwrite (AUD-0098 specific)** —
   VWAP order at amend time: API computes the VWAP-shifted price `P_local`,
   sends to Bybit, stamps `P_local` into R locally. Bybit's read-after-write
   lag returns the OLD price for ~5–30s. Pipeline runs in this window, fetches
   Bybit, gets old price, UPSERTs R with old price. R now has stale price.
   Today's mitigation: explicit hack that stamps the price post-Bybit-success
   (line 2391). **Under Option 1: the pipeline must NEVER overwrite a price
   that the API has stamped within the last 60s**, OR the pipeline ignores
   `price` updates from Bybit if they predate the local `updated_at` (i.e. the
   pipeline only writes `price` when it's strictly newer than the existing
   row's `updated_at`). The latter is cleaner: an `exchange_updated_at` /
   `local_updated_at` split solves the race deterministically.

#### Idempotency contract under Option 1

Pipeline UPSERT clause:

```sql
INSERT INTO order_leg_live (...) VALUES (...)
ON CONFLICT (exchange_order_id) DO UPDATE
SET status      = EXCLUDED.status,            -- always trust Bybit for status
    qty         = EXCLUDED.qty,               -- always trust Bybit for qty
    price       = CASE WHEN EXCLUDED.exchange_updated_at > order_leg_live.exchange_updated_at
                       THEN EXCLUDED.price
                       ELSE order_leg_live.price END,
    leg_type    = order_leg_live.leg_type,    -- API-authoritative (FSM-gated)
    lineage_id  = COALESCE(order_leg_live.lineage_id, EXCLUDED.lineage_id),
    waep_after_leg = EXCLUDED.waep_after_leg, -- pipeline computes; safe to overwrite
    updated_at  = CURRENT_TIMESTAMP;
```

The price-conditional CASE is the AUD-0098 fix. The `leg_type` preservation is
the AUD-0155 fix. Together they make the pipeline genuinely idempotent.

### 3.4 Phased plan — AUD-0171

| Phase | Scope | Tests | Effort |
|---|---|---|---|
| **C-1** | Audit every direct write to `order_leg_live` / `order_leg_hist` / `trade_journal` etc. across `lib/` + `bin/`. Produce a CSV inventory annotating each: which path, what columns it writes, whether it's inline-after-Bybit (Option 1 keeper) or speculative-pre-Bybit (Option 1 needs to remove). | None (audit-only). | 1 day |
| **C-2** | For every API write path that ISN'T inline-INSERT-after-Bybit-success, decide: (a) convert to inline, (b) remove and let pipeline handle, (c) special case (e.g. journal.py UPDATEs may be operator-initiated and don't fit the pattern). Document the per-site decision in C-1's CSV. | None (decision doc). | 0.5 days |
| **C-3** | Implement Phase C-2 decisions. The `journal.py` UPDATE paths in particular need careful review — they touch `guard_state_json` and `exit_action` which are runtime state, not user-set fields. | Integration tests for each affected endpoint. | 2–3 days |
| **C-4** | Make the pipeline reconciler-shaped: rewrite the `upsert_legs_to_db` function (line 2142) to use the Option-1 idempotency contract from §3.3 — never overwrite `leg_type` (delegate to FSM); never overwrite `price` if `exchange_updated_at` is older than the existing row. Adds the `exchange_updated_at` / `local_updated_at` split if not already present (verify via `etc/schema.md`). | Augment `tests/integration/test_refresh_order_leg_live.py` — add cases for stale-Bybit-price, late-fill detection, classifier-correction. | 2 days |
| **C-5** | Audit pipeline INSERT paths (lines 1868, 2441) for the "row absent for ≥30s" guard. Add a CTE that filters `INSERT` to rows where there's no recent API write of the same `exchange_order_id`. | Integration test for "API places + pipeline races" scenario. | 1 day |
| **C-6** | Kill the `subprocess.Popen` from API pattern entirely. AUD-0222 already moved most of these to `BackgroundTasks` (`refresh_order_data` calls in `open_orders.py`); finish migrating `services.py:424` and `trades.py:224`. Verify no `subprocess.Popen.*refresh` remains. | Integration test confirming no subprocess spawn during create/convert/amend/cancel. | 1 day |
| **C-7** | Operator-facing: document the new "API is sole writer" invariant in `tradelens/CLAUDE.md` so future contributors don't add new pipeline INSERT paths by reflex. | None. | 0.5 days |

**Open question 4 — locking:** does the pipeline lock rows during reconciliation?
Today it does NOT (no `SELECT ... FOR UPDATE`). Under Option 1, the pipeline's
UPDATEs are conditional (the price CASE in §3.3); a missed update is fine
(next pipeline run will retry). So lock-free is acceptable. **Resolved as
lock-free** — confirm with operator.

---

## 4. Cross-cutting

### 4.1 Why the ordering matters

```
AUD-0155 (FSM)
      ↓ standalone module + unit tests; no class changes
AUD-0170 (Decomposition)
      ↓ FSM is a clean state-touch point; rules classes plug it in
AUD-0171 (Writer split)
      ↓ FSM + decomposed classifier give the pipeline tractable invariants
        for "never overwrite leg_type" and "never overwrite price unless newer"
```

If we do AUD-0171 first: the pipeline's idempotency contract has to encode
the leg_type rules inline (replicating today's boolean matrix). Then AUD-0155
arrives and we have to update both the FSM and the contract. Worse if AUD-0170
arrives last: the contract code has to be re-routed through the new caches.

If we do AUD-0170 first: the FSM doesn't yet exist, so the rules class
absorbs today's boolean matrix. Then AUD-0155 lands and we have to refactor
the rules class. Wasteful.

The chosen order minimises rework: each phase builds the next phase's
prerequisite.

### 4.2 Risk-bounded interaction

- AUD-0170 has perf regression risk (extra call frames). AUD-0171 reduces this
  risk by ensuring the classifier runs ONLY during reconciliation (not on
  every API write). So AUD-0171's change in *when* the classifier runs caps
  AUD-0170's blast radius.
- AUD-0155 has correctness risk (FSM disagreement with original boolean
  matrix). Phase A-2's "FSM mirrors existing flags" requirement bounds this:
  the integration tests must match production telemetry for ≥1 week before
  Phase A-3 lands.
- AUD-0171 has the largest blast radius (writer semantics change). Mitigation:
  Phase C-1's audit-only inventory must complete and be operator-reviewed
  before any code changes ship.

### 4.3 Total estimated effort

| Cluster | Phases | Effort |
|---|---|---|
| AUD-0155 | A-1 .. A-4 | 3.5–5 days |
| AUD-0170 | B-1 .. B-6 | 6 days |
| AUD-0171 | C-1 .. C-7 | 8–9.5 days |
| **Total** | **17 phases** | **17.5–20.5 days** (≈ 3–4 calendar weeks at one phase per session, with soak between phases) |

### 4.4 Money-moving path proximity

All three audits touch the order-write hot path. Every commit:

- Full `pytest` green (run + show output).
- Integration tests mandatory — no exemption category fits (this is not docs,
  config, typo, dead-code, revert, frontend-styling, or generated-file).
- Each phase ships behind operator go-ahead.
- Phases that change runtime behaviour (A-2, A-3, B-2, B-5, C-3, C-4, C-5,
  C-6) require ≥24h production soak on a canary account before ramping.

---

## 5. Open questions (recap + resolution status)

1. **AUD-0155 — are the 3 exceptions truly the only transitions today?**
   Partially — the cluster's "3 exceptions" refers to the *reclassification*
   block (lines 2230–2279). The *first-classification* path (lines 657–688)
   has 3 additional implicit transitions (`dca→entry` via pending_context;
   `*→seed`; `dca→entry` via seeded_entry_orders) plus a fallback heuristic
   for conditional orders without `stopOrderType` (lines 696–709). The FSM
   must cover both contexts. **Documented in §0.1; the FSM design covers
   both.**

2. **AUD-0170 — does WAEPTracker hold mutable state across orders?**
   No — verified by reading `lib/tradelens/utils/waep_tracker.py`. The
   position dataclass is passed in/out of `apply_leg`; no per-order
   accumulator state. Phase B-3 is genuinely trivial. **Resolved.**

3. **AUD-0171 — Option 1 or Option 2?**
   Recommended Option 1 (API is sole writer; pipeline reconciles). Closer to
   current state after AUD-0078 Option B; smaller delta; AUD-0098 hack
   becomes the canonical pattern. **Pending operator confirmation before
   Phase C-1 ships.**

4. **AUD-0171 — must reconciliation be lock-free?**
   Yes (default). The pipeline's UPDATEs become conditional under §3.3's
   contract; a missed UPDATE is recoverable on the next pipeline tick. So no
   `FOR UPDATE` needed. **Resolved as lock-free; confirm with operator.**

---

## 6. PARK / surprises

- **AUD-0155 surprise:** the cluster's audit row understates the transition
  count. The FSM design has been widened to cover both
  `first-sighting` and `reclassification` contexts (and a third
  `archive-on-disappear` context for the sister site at line 1562 that the
  cluster did not mention). The Phase A-3 work item handles the wider scope.
- **AUD-0170 mostly clean:** WAEPTracker is stateless enough to extract
  trivially. The 7-state-map count (cluster said 6+) doesn't change the
  decomposition shape — three caches absorb all 7 maps.
- **AUD-0171 inventory is wider than the cluster suggests:** 8 distinct
  write sites today, not just "API + pipeline." Phase C-1 inventory must
  enumerate all of them before any conversion ships. The tools (levelguard
  CLI, repair_trade_lineage) are out-of-band one-shot scripts and don't
  change the writer-split conclusion, but they need to be documented as
  exceptions to the "API is sole writer" rule.
