# Conditional Take Profit Orders - Implementation Guide

## Overview

This guide explains the **conditional take-profit (TP) order** feature that automatically stages TP orders whenever you place a limit entry or DCA order.

### What Are Conditional TP Orders?

Conditional TP orders are TP orders that are **staged immediately** but only **trigger when the entry price is reached**. This allows you to set up your entire trade structure (entry + TPs) in one go, even if the entry hasn't filled yet.

### Why Use Conditional TPs?

- **Set-and-forget**: Configure your entire trade upfront
- **No manual intervention**: TPs activate automatically when entry fills
- **Works for all limit entries**: Initial entry AND all DCA levels
- **Multiple TP levels**: Support for 0-N take profit levels per entry

---

## How It Works

### Flow Diagram

```
1. User places LIMIT entry order (e.g., Buy ETH at $3500)
   ↓
2. System places the entry order on Bybit
   ↓
3. System generates conditional TP orders:
   - TP1: Sell at $4000 (triggers when price hits $3500)
   - TP2: Sell at $4500 (triggers when price hits $3500)
   ↓
4. All orders are staged on Bybit
   ↓
5. When price reaches $3500:
   - Entry order fills
   - TP orders become active
   ↓
6. When price reaches $4000:
   - TP1 fills (closes part of position)
   ↓
7. When price reaches $4500:
   - TP2 fills (closes rest of position)
```

### Technical Implementation

When you submit a trade with:
- **Entry type**: `limit`
- **Entry price**: `3500`
- **Quantity**: `0.1 ETH`
- **TP levels**: `[{price: 4000, size_pct: 50}, {price: 4500, size_pct: 50}]`

The system creates:

**1. Entry Order:**
```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Buy",
  "orderType": "Limit",
  "qty": "0.1",
  "price": "3500"
}
```

**2. Conditional TP1:**
```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Sell",
  "orderType": "Limit",
  "qty": "0.05",
  "price": "4000",
  "triggerPrice": "3500",  // Triggers when entry fills
  "triggerDirection": 1,    // Rising (for Buy entry)
  "reduceOnly": true
}
```

**3. Conditional TP2:**
```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Sell",
  "orderType": "Limit",
  "qty": "0.05",
  "price": "4500",
  "triggerPrice": "3500",  // Triggers when entry fills
  "triggerDirection": 1,
  "reduceOnly": true
}
```

---

## API Behavior

### For LINEAR (Perpetuals)

**Entry Order Side** | **TP Order Side** | **triggerDirection** | **positionIdx** | **orderFilter**
---|---|---|---|---
Buy (long) | Sell | 1 (rising) | 1 | *omitted*
Sell (short) | Buy | 2 (falling) | 2 | *omitted*

**Example - LONG position:**
```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Sell",           // Opposite of entry
  "triggerPrice": "3500",   // Entry price
  "triggerDirection": 1,    // Rising (for Buy entry)
  "positionIdx": 1,         // Long position
  "reduceOnly": true
}
```

### For SPOT

**Entry Order Side** | **TP Order Side** | **triggerDirection** | **positionIdx** | **orderFilter**
---|---|---|---|---
Buy | Sell | 1 (rising) | *omitted* | `tpslOrder`
Sell | Buy | 2 (falling) | *omitted* | `tpslOrder`

**Example - SPOT Buy:**
```json
{
  "category": "spot",
  "symbol": "XRPUSDT",
  "side": "Sell",              // Opposite of entry
  "triggerPrice": "2.60",      // Entry price
  "triggerDirection": 1,       // Rising (for Buy entry)
  "orderFilter": "tpslOrder",  // Required for spot
  "reduceOnly": true
}
```

---

## Usage Examples

### Example 1: Simple Long with 2 TPs

**Scenario:** Buy ETH at $3500, take profit at $4000 (50%) and $4500 (50%)

**API Request:**
```json
{
  "symbol": "ETHUSDT",
  "side": "long",
  "entry_type": "limit",
  "limit_price": 3500,
  "position_qty": 0.1,
  "stop_loss": 3200,
  "take_profits": [
    {"mode": "price", "value": 4000, "size_pct": 50},
    {"mode": "price", "value": 4500, "size_pct": 50}
  ]
}
```

**Orders Created:**
1. Buy 0.1 ETH at $3500 (entry)
2. Sell 0.05 ETH at $4000 (TP1, triggers at $3500)
3. Sell 0.05 ETH at $4500 (TP2, triggers at $3500)
4. Stop-loss order at $3200

### Example 2: Long with Entry + 2 DCAs + TPs

**Scenario:**
- Entry: Buy 0.03 ETH at $3500
- DCA1: Buy 0.03 ETH at $3400
- DCA2: Buy 0.04 ETH at $3300
- TPs: $4000 (50%), $4500 (50%)

**API Request:**
```json
{
  "symbol": "ETHUSDT",
  "side": "long",
  "entry_type": "limit",
  "limit_price": 3500,
  "position_qty": 0.1,
  "dca_levels": [3400, 3300],
  "entry_pct": 30,
  "dca1_pct": 30,
  "dca2_pct": 40,
  "stop_loss": 3200,
  "take_profits": [
    {"mode": "price", "value": 4000, "size_pct": 50},
    {"mode": "price", "value": 4500, "size_pct": 50}
  ]
}
```

**Orders Created:**
1. **Entry:** Buy 0.03 ETH at $3500
   - Conditional TP1: Sell 0.015 ETH at $4000 (triggers at $3500)
   - Conditional TP2: Sell 0.015 ETH at $4500 (triggers at $3500)

2. **DCA1:** Buy 0.03 ETH at $3400
   - Conditional TP1: Sell 0.015 ETH at $4000 (triggers at $3400)
   - Conditional TP2: Sell 0.015 ETH at $4500 (triggers at $3400)

3. **DCA2:** Buy 0.04 ETH at $3300
   - Conditional TP1: Sell 0.02 ETH at $4000 (triggers at $3300)
   - Conditional TP2: Sell 0.02 ETH at $4500 (triggers at $3300)

4. **Stop-Loss:** qty="0" at $3200 (closes entire position)

**Total:** 10 orders (3 entries + 6 conditional TPs + 1 SL)

### Example 3: SHORT with TPs

**Scenario:** Sell ETH at $3500, take profit at $3200 (100%)

**API Request:**
```json
{
  "symbol": "ETHUSDT",
  "side": "short",
  "entry_type": "limit",
  "limit_price": 3500,
  "position_qty": 0.1,
  "stop_loss": 3700,
  "take_profits": [
    {"mode": "price", "value": 3200, "size_pct": 100}
  ]
}
```

**Orders Created:**
1. Sell 0.1 ETH at $3500 (entry)
2. Buy 0.1 ETH at $3200 (TP1, triggers at $3500)
3. Stop-loss at $3700

---

## Testing

### Unit Tests

Run the test suite:

```bash
cd /app/syb/tradesuite/tradelens
./bin/test_conditional_tp.py
```

**Tests include:**
- ✅ Linear SHORT position TPs
- ✅ Spot SELL entry TPs
- ✅ Linear LONG position TPs
- ✅ Empty TP levels (returns empty list)
- ✅ Leg wrapper function
- ✅ Market entries (no conditional TPs)

### Manual Testing with JSON Executor

**Test 1: Linear conditional TP**
```bash
./bin/bybit_json_executor.py --dry-run examples/conditional_tp_test_linear.json
```

**Test 2: Spot conditional TP**
```bash
./bin/bybit_json_executor.py --dry-run examples/conditional_tp_test_spot.json
```

### Integration Testing

1. **Open Smart Trade UI**: http://localhost:3000/smart-trade
2. **Create a limit entry trade** with TP levels
3. **Click "View Bybit JSON"**
4. **Verify conditional TP orders** appear in the JSON preview
5. **Submit the trade** (use testnet first!)
6. **Check Bybit UI** to confirm all orders are staged

---

## Important Notes

### ✅ Supported

- **Limit entries** (initial or DCA)
- **Multiple TP levels** (0-N per entry)
- **Linear perpetuals** (USDT, Inverse)
- **Spot** trading
- **Both long and short** positions
- **Flexible TP percentages** (any distribution)

### ❌ Not Supported

- **Market entries**: Conditional TPs only work with limit entries
  - For market entries, use regular (immediate) TP orders instead
- **TP orders on TP legs**: TPs don't trigger on other TPs

### Trigger Behavior

**For LONG (Buy entry):**
- `triggerDirection: 1` (rising)
- TPs activate when price rises TO entry price
- TPs execute when price rises TO TP price

**For SHORT (Sell entry):**
- `triggerDirection: 2` (falling)
- TPs activate when price falls TO entry price
- TPs execute when price falls TO TP price

### Quantity Calculation

TP quantity is calculated as:
```
tp_qty = entry_qty * (tp_size_pct / 100)
```

Example:
- Entry: 0.1 ETH
- TP1: 50% → 0.05 ETH
- TP2: 50% → 0.05 ETH

---

## Troubleshooting

### "Conditional TPs not appearing in preview"

**Check:**
1. Is entry type `limit`? (Market entries don't get conditional TPs)
2. Are TP levels configured in the preview request?
3. Is the backend running? Check logs: `tail -f /tmp/tradelens_backend.log`

### "TP orders not triggering on Bybit"

**Check:**
1. Did the entry order fill?
2. Is the entry price actually reached?
3. Check Bybit order history for conditional orders
4. Verify `triggerPrice` matches entry price

### "Invalid triggerDirection error"

**Check:**
- Long entry (Buy): must use `triggerDirection: 1`
- Short entry (Sell): must use `triggerDirection: 2`

### "Missing orderFilter error" (Spot only)

Spot orders require `orderFilter: "tpslOrder"`. Verify the code sets this for spot category.

---

## API Reference

### Function: `generate_conditional_tp_orders()`

**Location:** `/app/syb/tradesuite/tradelens/lib/tradelens/services/conditional_orders.py`

**Purpose:** Generate conditional TP orders for a limit entry

**Parameters:**
- `category` (str): `'linear'` or `'spot'`
- `symbol` (str): Trading symbol (e.g., `'ETHUSDT'`)
- `entry_side` (str): `'Buy'` or `'Sell'`
- `entry_price` (float): Entry order price
- `entry_qty` (float): Entry order quantity
- `tp_levels` (List[Dict]): List of TP level dicts with `price` and `size_pct`
- `position_idx` (Optional[int]): Position index (required for linear, omitted for spot)

**Returns:** List[Dict[str, Any]] - List of conditional TP order parameter dicts

**Example:**
```python
from tradelens.services.conditional_orders import generate_conditional_tp_orders

tps = generate_conditional_tp_orders(
    category='linear',
    symbol='ETHUSDT',
    entry_side='Buy',
    entry_price=3500.0,
    entry_qty=0.1,
    tp_levels=[
        {'price': 4000, 'size_pct': 50.0},
        {'price': 4500, 'size_pct': 50.0}
    ],
    position_idx=1
)

# Returns:
# [
#   {"category": "linear", "symbol": "ETHUSDT", "side": "Sell", ...},
#   {"category": "linear", "symbol": "ETHUSDT", "side": "Sell", ...}
# ]
```

### Function: `generate_conditional_tp_orders_for_leg()`

**Location:** Same as above

**Purpose:** Convenience wrapper that extracts parameters from a leg dict

**Parameters:**
- `category` (str): Market category
- `symbol` (str): Trading symbol
- `leg` (Dict): Order leg dict with `order_kind`, `price`, `qty`, `kind`
- `trade_side` (str): `'long'` or `'short'`
- `tp_levels` (List[Dict]): TP level dicts
- `position_idx` (Optional[int]): Position index

**Returns:** List[Dict[str, Any]] - Same as above (empty if not a limit order)

---

## Implementation Details

### Where Conditional TPs Are Created

**1. In `submit_trade()` (trades.py:390-450)**

After placing each limit entry/DCA order:
```python
if leg['kind'] in ['entry', 'dca'] and leg['order_kind'] == 'limit':
    conditional_tps = generate_conditional_tp_orders_for_leg(...)
    for ctp in conditional_tps:
        bybit._request("POST", "/v5/order/create", ctp)
```

**2. In `preview_bybit_orders()` (trades.py:644-665)**

When previewing Bybit JSON:
```python
if leg['kind'] in ['entry', 'dca'] and leg['order_kind'] == 'limit':
    conditional_tps = generate_conditional_tp_orders_for_leg(...)
    for ctp in conditional_tps:
        bybit_orders.append({
            'leg_type': 'conditional_tp',
            'params': ctp
        })
```

### Database Records

Conditional TP orders are recorded in the audit trail with:
- `leg_type: 'conditional_tp'`
- `order_kind: 'limit'`
- Full Bybit order ID

---

## Related Documentation

- `SOLUTION.md` - Stop-loss qty="0" solution
- `TP_GUIDE.md` - Regular take-profit order guide
- `USAGE.md` - Bybit JSON executor usage

---

**Last Updated:** 2025-10-13
**Status:** ✅ Implemented and tested
**Version:** 1.0.0
