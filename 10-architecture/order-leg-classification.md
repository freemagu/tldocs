# Order Leg Classification Logic

> See also: [[breach-decision-glossary]] (stop and guard terminology), [[level-guard]] (guard lifecycle)

This document describes how TradeLens classifies Bybit orders into trade legs for analytics and journal tracking.

## Overview

The `OrderClassifier` class in `bin/pipeline/refresh_order_leg_live.py` classifies each order into:

- **Position Side**: `long` or `short`
- **Leg Type**: `entry`, `dca`, `tp`, `stop`, `close_loss` (live-classifier output set; the full system also uses `tl`, `be`, `trailing_*`, `seed`, `auto_trailing_be`, and the `suspend_exit` / `resume_*` family — see [Leg Types](#leg-types) below)
- **Order Kind**: `market`, `limit`, `conditional`

## Leg Types

Leg types are produced by two distinct paths:

- **Live/historical classifier** (`bin/pipeline/refresh_order_leg_live.py`,
  `bin/pipeline/refresh_order_leg_hist.py`) classifies fills observed on
  the exchange.
- **Order-creation classifier** (`lib/tradelens/api/open_orders.py`
  `determine_leg_type()` at line ~3640) labels close orders as they are
  *placed* via the API — produces the wider `tp/tl/be` and `trailing_*`
  families.

### Close-side family structure

The close-side leg types fall into two families that differ only in *order
behaviour*; within each family, the suffix is determined purely by *fill or
trigger price relative to WAEP* against a small breakeven threshold
(`get_breakeven_threshold()`, default 0.05%).

- **Non-trailing family — `tp` / `be` / `tl`** — non-conditional market or
  limit close, OR conditional-with-pending-limit-on-book. A market close
  of part or all of a position lands here.
- **Trailing family — `trailing_tp` / `trailing_be` / `trailing_tl`** —
  conditional close orders that fire market-like on trigger (conditional-
  market, or conditional-limit whose limit price would fill immediately on
  trigger), AND that are not claiming the primary-stop role. Despite the
  name, "trailing" here is **not** Bybit's trailing-stop feature — it's a
  TradeLens label for "fires market-like on trigger, isn't *the* stop."
- **`stop` overrides both families** when a close order is conditional +
  covers the entire position + the trade has no other stop. Only one
  `stop` per trade by construction.

### Full leg-type reference

| Leg type | Meaning | Exchange order types | Notes |
|---|---|---|---|
| `entry` | Initial position entry — first fill that opens the position from flat. | limit, market | Produced when no position exists and the order is opening (not reduce-only). Spot buys, futures buys (long), futures sells (short). |
| `dca` | Dollar-cost average / add — fill in the same direction as an existing position, increasing size. | limit, market | Produced when position exists and fill is same-direction (buy on long, sell on short) and not reduce-only. WAEP recalculates after each `dca`. |
| `seed` | Pre-existing position seeded into a TradeLens trade — quantity that existed on the exchange before the trade was tracked. | market | Produced by `lib/tradelens/api/trades.py:1597, 1609, 1621, 2793` when reconciling a trade with on-exchange position qty that predates the trade record. Treated as an entry-side leg: `SOURCE_LEG_TYPES = {entry, dca, seed}` (`order_sets.py:553`); included in entry counts (`refresh_trade_journal.py:605, 1386`). |
| `tp` / `be` / `tl` (alias `close_loss`) | **Non-trailing close family — same order behaviour, suffix differs only by fill price vs WAEP.** Produced by any non-conditional market or limit close, OR any conditional close whose limit price would NOT fill immediately on trigger (sits as a pending limit on the book). A market-close-now of part or all of a position lands here.<br><br>• `tp` (take profit) — price favourable vs WAEP, beyond the breakeven threshold (>WAEP for long, <WAEP for short).<br>• `tl` (take loss) — price unfavourable vs WAEP, beyond the breakeven threshold (<WAEP for long, >WAEP for short).<br>• `be` (take break-even) — price within ±`breakeven_threshold` of WAEP.<br><br>`close_loss` is the historical-pipeline alias of `tl` — semantically identical, produced by a different code path (`bin/pipeline/refresh_order_leg_hist.py:2019` for sub-leg loss exits). | limit, conditional-limit, market | Threshold from `get_breakeven_threshold()` (`open_orders.py:3624`, default 0.05%). Family-membership constants: `_PROFIT_SIDE_LEG_TYPES = {tp, be, trailing_tp, trailing_be}`, `_LOSS_SIDE_LEG_TYPES = {stop, tl, trailing_tl}` (`open_orders.py:4044-4045`). `close_loss` treated like `tl` for WAEP/exit accounting (`waep_tracker.py:249`, `refresh_trade_journal.py:606`). |
| `trailing_tp` / `trailing_be` / `trailing_tl` | **Trailing close family — same order behaviour, suffix differs only by trigger price vs WAEP.** Produced by conditional close orders that fire market-like on trigger, AND that are not claiming the primary-stop role (either partial qty, or the trade already has another `stop`).<br><br>• `trailing_tp` (trailing take profit, TTP) — trigger favourable vs WAEP beyond threshold.<br>• `trailing_tl` (trailing take loss, TTL) — trigger unfavourable vs WAEP beyond threshold.<br>• `trailing_be` (trailing take break-even, TBE) — trigger within ±threshold of WAEP. | conditional-market | Same threshold and family-membership constants as the non-trailing family. "Trailing" is a TradeLens label, NOT Bybit's trailing-stop feature. |
| `stop` | Primary stop loss — auto-claimed when a close order is conditional + covers the entire position + the trade has no other stop. | conditional-market | Claimed by `determine_leg_type` ahead of the trailing/non-trailing branches (`open_orders.py:3707-3726`). Only one `stop` per trade by construction. Member of `_LOSS_SIDE_LEG_TYPES`. **Safety-invariant role:** an unguarded `stop` is the unconditional safety net every guarded conditional-market close requires — see [breach-decision-glossary.md](breach-decision-glossary.md) (Protective hard stop invariant) and `open_orders.has_unguarded_hard_stop`. |
| `auto_trailing_be` | Auto-armed break-even guard leg — synthetic `order_leg_live` row inserted mid-trade by the breakeven-trigger auto-armer when TP1 fires. Sits *alongside* the original hard stop (doesn't replace it) at WAEP. | conditional-market | Produced ONLY by `bin/pipeline/refresh_order_leg_live.py:1961, 1994` (Path C of `_check_breakeven_trigger`) when the trade has `idea_spec.breakeven_trigger.use_level_guard=true` — i.e. the smart-trade-form "Move SL to B/E after TP1" toggle with the default "Use Level Guard for B/E stop" sub-checkbox enabled. Same conditional-market-on-trigger behaviour as `trailing_be`; only the "armed by whom" differs (auto-armer mid-trade vs user at trade creation). Renamed from `tbe` 2026-04-29 (AUD-0381 resolved). |
| `suspend_exit` | Suspend pipeline exit — synthetic exit when a trade is suspended via the suspend/resume flow, realising P&L on the suspended portion. | market | Tagged from Bybit `orderLinkId` prefix `SUSP-` in `refresh_order_leg_hist.py:951`. Treated as an exit by sessionisation (`refresh_trade_journal.py:558`) and by `EXIT_LEG_TYPES` (`initial_risk_calculator.py:55`). |
| `resume_entry` | Suspend pipeline resume — structural-qty portion of a `RESM-`-tagged fill that re-establishes the position at the previously suspended size. | market | Produced by `refresh_order_leg_hist.py` from `structural_target_qty` in `trade_suspend_snapshot`. NOT counted as an entry for WAEP (preserves pre-suspend WAEP). |
| `resume_add` | Suspend pipeline resume delta — extra qty on a `RESM-` fill beyond the structural target, treated as a real entry that affects WAEP. | market | Created when filled qty > structural resume qty. Sessionisation treats it as an entry alongside `entry`/`dca`/`seed` (`refresh_trade_journal.py:605`). |
| `resume_reduce` | Suspend pipeline resume delta — qty deficit on a `RESM-` fill below the structural target, treated as a real exit that affects WAXP. | market | Created when filled qty < structural resume qty. Treated as an exit by sessionisation (`refresh_trade_journal.py:606`) and by `EXIT_LEG_TYPES`. |

## Order Kinds

| Order Kind | Description | Bybit Order Types |
|------------|-------------|-------------------|
| `market` | Immediate execution | `orderType='Market'` |
| `limit` | Execute at specific price | `orderType='Limit'` |
| `conditional` | Triggered by price condition | Has `triggerPrice` or `stopOrderType` |

## Classification Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    classify_order()                              │
│                                                                  │
│  1. Extract order fields: side, type, price, trigger, etc.      │
│  2. Fetch mark_price for symbol                                 │
│  3. Check if position exists for symbol                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
           ▼                           ▼
┌──────────────────────┐    ┌──────────────────────┐
│ Position EXISTS      │    │ NO Position          │
│                      │    │                      │
│ _classify_with_      │    │ _classify_without_   │
│ position()           │    │ position()           │
└──────────┬───────────┘    └──────────┬───────────┘
           │                           │
           ▼                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Return (side, leg_type, order_kind)           │
└──────────────────────────────────────────────────────────────────┘
```

## Classification WITH Position

When a position exists, classification uses the position's entry price as reference.

### Priority Order

1. **stopOrderType field** (if present)
2. **Trigger price** (conditional orders)
3. **Order type** (limit/market)
4. **Fallback**

### Decision Tree

```
Has stopOrderType?
├── TakeProfit → (pos_side, 'tp', 'conditional')
└── StopLoss/Stop → Validate with entry price:
    ├── LONG + SELL:
    │   ├── classification_price < entry → 'stop'
    │   └── classification_price >= entry → 'tp'
    └── SHORT + BUY:
        ├── classification_price > entry → 'stop'
        └── classification_price <= entry → 'tp'

Has triggerPrice (no stopOrderType)?
├── LONG + SELL:
│   ├── classification_price < entry → 'stop'
│   └── classification_price >= entry → 'tp'
└── SHORT + BUY:
    ├── classification_price > entry → 'stop'
    └── classification_price <= entry → 'tp'

Limit order?
├── reduce_only=true → 'tp'
└── reduce_only=false:
    ├── Same direction as position → 'dca'
    └── Opposite direction → 'tp'

Market order?
├── reduce_only=true → 'tp'
└── reduce_only=false:
    ├── Same direction as position → 'dca'
    └── Opposite direction → 'tp'
```

### Same vs Opposite Direction

| Position | Order Side | Direction | Classification |
|----------|------------|-----------|----------------|
| LONG | buy | Same | dca |
| LONG | sell | Opposite | tp |
| SHORT | sell | Same | dca |
| SHORT | buy | Opposite | tp |

## Classification WITHOUT Position

When no position exists (historical orders, orphaned orders), classification infers position side from order characteristics.

### Decision Tree

```
Has stopOrderType?
├── sell order → side='long' (was long, selling to close)
├── buy order → side='short' (was short, buying to close)
├── TakeProfit → 'tp'
└── StopLoss/Stop → 'stop'

Has triggerPrice?
├── trigger < mark_price → side='long'
├── trigger >= mark_price → side='short'
├── closeOnTrigger=true → 'stop'
└── closeOnTrigger=false → 'entry'

Limit order?
├── reduce_only=true → infer side from order_side, 'tp'
└── reduce_only=false:
    ├── buy → ('long', 'entry')
    └── sell → ('short', 'entry')

Market order?
├── reduce_only=true:
│   ├── sell → ('long', 'tp')
│   └── buy → ('short', 'tp')
├── SPOT category:
│   ├── buy → ('long', 'entry')
│   └── sell → ('long', 'stop')  # Spot can't short!
└── FUTURES:
    ├── buy → ('long', 'entry')
    └── sell → ('short', 'entry')
```

## Conditional Orders: Trigger vs Limit Price

**CRITICAL:** Conditional orders have TWO prices:

| Field | Purpose | Example |
|-------|---------|---------|
| `triggerPrice` | When order activates | 27.55 (DCA level) |
| `price` (limit) | Actual execution price | 30.57 (TP level) |

### Classification Price Selection

For TP/SL determination, use the **execution price** (determines P&L), not trigger:

```python
classification_price = price if price and price > 0 else trigger_price
```

### Example: Conditional TP Triggered at DCA Level

**Scenario:**
- LONG position @ 27.98 entry
- Conditional SELL order:
  - `triggerPrice`: 27.55 (activates when DCA fills)
  - `price`: 30.57 (actual sell price)

**Classification:**
- `classification_price` = 30.57 (use limit price)
- 30.57 > 27.98 (entry) → **TP** (profit)

**Bug (if using trigger_price):**
- 27.55 < 27.98 (entry) → **STOP** (wrong!)

## Validation Rules

The `_validate_classification()` method enforces these rules:

| Position | Action | reduce_only | Valid leg_types |
|----------|--------|-------------|-----------------|
| LONG | buy | false | entry, dca |
| LONG | sell | true | tp, stop |
| SHORT | sell | false | entry, dca |
| SHORT | buy | true | tp, stop |

Violations raise `AssertionError` to catch classification bugs early.

## Bybit API Fields Reference

| Field | Description | Values |
|-------|-------------|--------|
| `side` | Order direction | "Buy", "Sell" |
| `orderType` | Execution type | "Market", "Limit" |
| `stopOrderType` | Stop order type | "TakeProfit", "StopLoss", "Stop", "" |
| `triggerPrice` | Conditional trigger | Price string or "0" |
| `reduceOnly` | Position-reducing | true/false |
| `closeOnTrigger` | Close position on trigger | true/false |
| `price` | Limit price | Price string |
| `avgPrice` | Filled price | Price string (filled orders) |

### stopOrderType Quirk

Bybit returns `stopOrderType='Stop'` for BOTH:
- Actual stop-loss orders
- Conditional TP orders with triggers

**Solution:** Validate using entry price comparison, not just `stopOrderType`.

## Testing Classification

Use `--explain` flag to see detailed classification reasoning:

```bash
./bin/pipeline/refresh_order_leg_live.py --explain --symbol BTCUSDT
```

Output shows:
- Input fields (category, order_side, order_type, etc.)
- Decision path (which branch was taken)
- Result (pos_side, leg_type, order_kind)

## Historical Bug Fixes

| Commit | Date | Issue |
|--------|------|-------|
| `7fdbcd8` | Nov 13 | Initial implementation |
| `a42a4f7` | Nov 19 | BUY on LONG misclassified as TP - fixed to use order action |
| `f7020a4` | Nov 22 | `stopOrderType='Stop'` unreliable - added price>trigger validation |
| `8bd122b` | Nov 25 | Historical limits used current mark_price - fixed to use order_side |
| `8726a30` | Dec 1 | Used mark_price for comparison - fixed to use position.entryPrice |
| (Dec 9)   | Dec 9 | Used trigger_price for conditional TPs - fixed to use limit price |
| (this fix)| 2026-04-29 | Removed `sl` leg-type alias — never written by any pipeline (zero rows in `order_leg_*`); standardised consumers on `stop`. |

## Code Locations

| Function | File | Line | Purpose |
|----------|------|------|---------|
| `_classify_with_position()` | refresh_order_leg_live.py | ~660 | Classification when position exists |
| `_classify_without_position()` | refresh_order_leg_live.py | ~853 | Classification when no position |
| `_validate_classification()` | refresh_order_leg_live.py | ~789 | Validation of classification |
| `_print_classification_explanation()` | refresh_order_leg_live.py | ~463 | --explain output |

## Edge Cases

### 1. Conditional TP with DCA-level Trigger

**Use case:** Place a TP that activates when DCA fills (trigger at DCA price, limit at TP price).

**Classification:** Use limit price (30.57), not trigger price (27.55).

### 2. Orphaned Orders (Position Closed)

Orders remain open after position is closed (manual close, liquidation).

**Classification:** Falls to `_classify_without_position()`, infers side from order characteristics.

### 3. Spot Trading

Spot cannot short. All sells on spot are classified as closing a long position.

**Classification:** Spot sell → `('long', 'stop', 'market')`

### 4. Historical Orders with Changed Mark Price

Mark price changes over time. Historical orders can't use current mark_price.

**Classification:** Use `order_side` for direction, not price vs mark_price.

---

**Last Updated:** 2026-04-29
**Maintainer:** Development Team
**Related:** ../CLAUDE.md, archive/implementation-history/WAEP_IMPLEMENTATION.md
