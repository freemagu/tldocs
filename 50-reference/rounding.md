# Price & Quantity Rounding — Canonical Reference

**Status:** Authoritative. If a rounding pattern in the codebase disagrees with this doc, the pattern is wrong.

**Last verified:** 2026-04-22

---

## TL;DR — The Rule

> **Every price and quantity that is written to the database or submitted to the exchange MUST pass through one of the five canonical rounding functions listed below.**
>
> Never ad-hoc `.quantize()`. Never Python `round()` on a price or qty. Never `f"{x:.Nf}"`. Never `str(x).rstrip('0').rstrip('.')`. If the existing functions don't cover a case, **fix the existing function** — do not invent a new one.

Symbol precision in this system is driven by two per-instrument values fetched from Bybit:

- **`tick_size`** — minimum price increment (e.g. `0.01`, `0.5`, `0.00001`)
- **`qty_step`** — minimum quantity increment (e.g. `0.001`, `0.01`, `1`)

All rounding decisions ultimately reduce to "round this value to a multiple of the step."

---

## Decision Table — Which function do I use?

| Context | Input type | Use this function | File |
|---|---|---|---|
| Submitting **qty** to Bybit API (need a string) | `float` or `Decimal` | `round_qty_to_step(qty, qty_step)` | `lib/tradelens/api/open_orders.py:2900` |
| Submitting **price** (limit / trigger) to Bybit API | `Decimal` | `round_to_tick(price, tick_size)` | `lib/tradelens/api/open_orders.py:2959` |
| Computing a leg **price** inside the sizing engine | `Decimal` | `round_price(price, tick_size)` | `lib/tradelens/services/sizing.py:229` |
| Computing a leg **qty** inside the sizing engine | `Decimal` | `round_qty(qty, qty_step)` | `lib/tradelens/services/sizing.py:234` |
| Generic step rounding where you need `ROUND_UP` | `Decimal` | `round_to_step(value, step, "up")` | `lib/tradelens/services/sizing.py:208` |

Rule of thumb: **if the rounded value is about to cross a process boundary** (DB write, HTTP request to Bybit), use the open_orders.py pair — they are guaranteed to produce fixed-point string output with no scientific notation. **If the value is staying in the Decimal pipeline** (sizing math, WAEP calculation), the sizing.py family is fine.

---

## The Five Canonical Functions

### 1. `round_to_step(value, step, direction="down")` — the base utility

**File:** `lib/tradelens/services/sizing.py:208`

```python
def round_to_step(value: Decimal, step: Decimal, direction: str = "down") -> Decimal:
    if step == 0:
        return value
    if direction == "down":
        return (value // step) * step
    else:
        # ROUND_UP via quantize; see AUD-0049 for why the previous
        # epsilon-based implementation was replaced (failed for step < 1e-10).
        return (value / step).to_integral_value(rounding=ROUND_UP) * step
```

- **Input:** `Decimal`, `Decimal`, `"down" | "up"` (default `"down"`)
- **Output:** `Decimal`
- **Method:** integer floor-division (`//`) on Decimal for "down"; `to_integral_value(ROUND_UP)` for "up" (canonical Decimal semantics, no magic constant).
- **Edge cases:** `step == 0` → returns `value` unchanged (divide-by-zero guard).
- **Used by:** `round_price`, `round_qty`, and any caller that explicitly needs `ROUND_UP` semantics (rare — min-notional top-up in `sizing.py` uses `.quantize(qty_step, rounding=ROUND_UP)` inline for that one case).

### 2. `round_price(price, tick_size)` — sizing-pipeline prices

**File:** `lib/tradelens/services/sizing.py:229`

```python
def round_price(price: Decimal, tick_size: Decimal) -> Decimal:
    """Round price to tick size"""
    return round_to_step(price, tick_size, "down")
```

- **Input:** `Decimal`, `Decimal`
- **Output:** `Decimal`
- **Direction:** always rounds **down** (conservative for entries; same for TPs).
- **Call sites:** leg price in `calculate_position_size`, `calculate_quantity_sizing`, TP price in `calculate_take_profit_levels`.

### 3. `round_qty(qty, qty_step)` — sizing-pipeline quantities

**File:** `lib/tradelens/services/sizing.py:234`

```python
def round_qty(qty: Decimal, qty_step: Decimal) -> Decimal:
    """Round quantity to quantity step"""
    return round_to_step(qty, qty_step, "down")
```

- **Input:** `Decimal`, `Decimal`
- **Output:** `Decimal`
- **Direction:** always rounds **down** — never overshoot available funds / requested size.
- **Call sites:** total qty and per-leg qty in `calculate_position_size` / `calculate_quantity_sizing`.

### 4. `round_qty_to_step(qty, qty_step)` — exchange API quantities

**File:** `lib/tradelens/api/open_orders.py:2900`

```python
def round_qty_to_step(qty: float, qty_step: Decimal) -> str:
    qty_decimal = Decimal(str(qty))
    rounded = (qty_decimal / qty_step).to_integral_value(rounding='ROUND_DOWN') * qty_step
    # Quantize to qty_step precision to ensure fixed-point str() (prevents scientific notation)
    return str(rounded.quantize(qty_step))
```

- **Input:** `float` (accepts float by design — many upstream numbers are floats from the API layer), `Decimal`
- **Output:** **`str`** (fixed-point, no scientific notation, ready to send to Bybit)
- **Method:** float → Decimal via `str()` (to avoid float-precision artifacts) → divide by `qty_step` → `ROUND_DOWN` to integral → multiply back → `.quantize(qty_step)` so `str()` cannot emit `E+...`.
- **Direction:** always rounds **down**.
- **Why different from `round_qty`:** Bybit wants a fixed-point string; `Decimal` multiplication can internally switch to scientific notation (`Decimal('3.0652E+5')`). The final `.quantize(qty_step)` forces the exponent so `str()` produces `306520`, not `3.0652E+5`.

### 5. `round_to_tick(price, tick_size)` — exchange API prices

**File:** `lib/tradelens/api/open_orders.py:2959`

```python
def round_to_tick(price: Decimal, tick_size: Decimal) -> Decimal:
    if tick_size <= 0:
        return price
    rounded = (price / tick_size).quantize(Decimal('1')) * tick_size
    # Quantize to tick_size precision to ensure fixed-point str() (prevents scientific notation)
    return rounded.quantize(tick_size)
```

- **Input:** `Decimal`, `Decimal`
- **Output:** `Decimal` with exponent locked to `tick_size` — calling `str()` on the result gives fixed-point notation.
- **Method:** divide, `.quantize(Decimal('1'))` (ROUND_HALF_EVEN — Python Decimal default), multiply back, final `.quantize(tick_size)`.
- **Direction:** ROUND_HALF_EVEN (banker's rounding) — may round up or down depending on the nearest tick. This differs from `round_price` (always down). Intentional: exchange-side prices are typically rounded to the nearest tick, not floored.
- **Edge case:** `tick_size <= 0` → returns `price` unchanged.

---

## Why two families exist — don't "simplify"

There are two coexisting styles on purpose:

| Family | Where | Method | Returns | Direction | Sci-notation guard |
|---|---|---|---|---|---|
| **A — sizing pipeline** | `services/sizing.py` | Integer floor-division (`//`) | `Decimal` | Always `ROUND_DOWN` | No (not needed — stays in Decimal space) |
| **B — exchange I/O** | `api/open_orders.py` | `.quantize(Decimal('1'))` / `.to_integral_value()` | `str` (qty) or `Decimal` with locked exponent (price) | `ROUND_DOWN` (qty) / `ROUND_HALF_EVEN` (price) | **Yes** — final `.quantize(step)` |

**Do not merge them.** The sizing-pipeline family feeds into downstream math (WAEP, profit scenarios, min-notional checks) where extra precision is wanted. The exchange-I/O family produces strings for the Bybit API where any whiff of scientific notation (`E+05`) is a rejected order.

---

## Where `tick_size` and `qty_step` come from

**Single source of truth:** Bybit's `get_instrument_info()` API. There is **no DB cache** — each call fetches fresh from the exchange.

| Helper | File | Reads | Fallback |
|---|---|---|---|
| `get_tick_size(account, category, symbol)` | `lib/tradelens/api/open_orders.py:2932` | `info['priceFilter']['tickSize']` | `Decimal('0.01')` |
| `get_qty_step(bybit, category, symbol)` | `lib/tradelens/api/open_orders.py:2881` | `info['lotSizeFilter']['qtyStep']` or `basePrecision` (spot) | `Decimal('0.0001')` |

Both get bundled into `InstrumentMeta` (`lib/tradelens/services/sizing.py:131`) by:

- `get_instrument_metadata()` in `lib/tradelens/api/trades.py:365`
- `get_instrument_meta()` in `lib/tradelens/services/suspend_service.py:62`

`InstrumentMeta` is what you pass to `calculate_position_size()` / `calculate_quantity_sizing()`. It also carries `min_qty`, `min_notional`, `contract_size` (inverse), and `max_order_qty`.

---

## DO / DON'T

### ✅ DO

```python
from tradelens.api.open_orders import round_to_tick, round_qty_to_step

# API submission:
price_str = str(round_to_tick(Decimal(str(price)), tick_size))
qty_str   = round_qty_to_step(qty, qty_step)   # already a str

# Sizing:
from tradelens.services.sizing import round_price, round_qty
leg_price = round_price(raw_price, instrument_meta.tick_size)
leg_qty   = round_qty(raw_qty, instrument_meta.qty_step)
```

### ❌ DON'T

All of these have appeared in the codebase and are **wrong** — they silently bypass the canonical rounding:

```python
# Ad-hoc quantize bypassing the canonical fn:
rounded = (qty / qty_step).quantize(Decimal('1'), rounding='ROUND_DOWN') * qty_step

# Python float round() on a price:
price = round(raw_price, 8)

# f-string formatting as the "rounder":
price_str = f"{float(rounded):.{dp}f}"

# String-strip zeros to "clean up":
s = format(rounded, 'f').rstrip('0').rstrip('.')

# Regex-strip sci-notation:
s = re.sub(r'\.?0+$', '', str(rounded))

# Ad-hoc E+ cleanup:
s = str(rounded).replace('E+', '...')
```

All of these treat **symptoms** (scientific notation, trailing zeros) instead of the cause (not using `.quantize(step)`). The canonical functions already handle this correctly.

### Never invent a new rounding helper

If the existing functions don't cover a case, fix them. The codebase must have **one** set of rounding functions. Wrapper helpers, per-module utilities, and "just-this-once" inline rounding are prohibited.

---

## Scope: what this rule does and does not cover

The rule applies to **prices and quantities** — values that get multiplied by `tick_size` or `qty_step` and ultimately submitted to the exchange or persisted to a price/qty column.

It does **not** apply to:

- **Percentages** (distance_pct, slippage_pct, etc.) — no instrument-specific step exists. `round(pct, 4)` for display / storage precision is fine.
- **Dedup / set-identity rounding** of values that are not submitted anywhere — e.g. `round(price, 10)` used only as a `set()` key for grouping.

If you're unsure whether a value is a "price" or "qty" in this sense: ask "does this number end up in a Bybit API call or in an `order_leg_*` / `trade_*` price/qty column?" If yes, use a canonical function.

## Known violations — cleanup candidates

As of 2026-04-22, the per-qty-step/per-tick-size violations have been migrated. The remaining items below are boundary cases that do not strictly violate the rule but are worth tracking.

- `lib/tradelens/api/order_sets.py:1020` — `round(t['price'], 10)` used only as a `set()` key for grouping exits. Not submitted to the exchange, not stored. Per the scope carve-out above, this is acceptable; flagged here only as a reminder that upstream should ideally hand us Decimals already.

---

## Testing & invariants

Existing tests live in `tests/unit/test_sizing.py` (covers Family A — `round_to_step`, `round_price`, `round_qty`). Family B (`round_to_tick`, `round_qty_to_step`) currently has no direct unit tests — add them if you touch these functions.

Invariants worth asserting:

- `'E' not in str(round_to_tick(price, tick_size))` for any finite price.
- `round_qty_to_step(qty, qty_step)` returns a string containing only digits and at most one `.`.
- `round_to_step(v, step, "down") <= v` and `round_to_step(v, step, "up") >= v` for `v >= 0`.
- `round_price(p, tick) % tick == 0` (the result is a clean multiple of the step).

---

## Cross-references

- Memory rule (global): `NEVER Do Ad-Hoc String Manipulation on Decimals` — this doc is its repo-level expansion.
- `etc/schema.md` — DB columns that store prices/qtys and therefore require these functions upstream (`waep_after_leg`, `breach_price`, `execute_price`, `atr_value`, `order_leg_*.price`, `order_leg_*.qty`, etc.).
