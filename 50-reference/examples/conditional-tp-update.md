# Conditional TP Orders - Update: Market Entry Support

## Summary

Fixed the issue where **market entries did not create TP orders**. Now the system correctly handles both market and limit entries:

- **Market entries** → Create **regular (immediate) TP orders**
- **Limit entries/DCAs** → Create **conditional TP orders** (trigger when entry fills)

## What Changed

### Before (Broken)
- ❌ Market entry: No TPs created
- ✅ Limit entry: Conditional TPs created
- ✅ DCAs: Conditional TPs created

### After (Fixed)
- ✅ Market entry: **Regular TPs created immediately**
- ✅ Limit entry: Conditional TPs created
- ✅ DCAs: Conditional TPs created

## Implementation Details

### Market Entry Behavior

When you place a **market entry order**, the system now:

1. Places the market entry order
2. **Immediately places regular TP limit orders** (not conditional)
3. Places the stop-loss order

**Example:**
```json
{
  "symbol": "ETHUSDT",
  "side": "long",
  "entry_type": "market",  // ← Market entry
  "position_qty": 0.1,
  "stop_loss": 3200,
  "take_profits": [
    {"mode": "price", "value": 4000, "size_pct": 50},
    {"mode": "price", "value": 4500, "size_pct": 50}
  ]
}
```

**Orders Created:**
1. **Market Entry:** Buy 0.1 ETH at market price
2. **TP1 (Regular):** Sell 0.05 ETH at $4000 (immediate limit order)
3. **TP2 (Regular):** Sell 0.05 ETH at $4500 (immediate limit order)
4. **Stop-Loss:** qty="0" at $3200

### Limit Entry Behavior (Unchanged)

Limit entries still create conditional TPs:

**Example:**
```json
{
  "symbol": "ETHUSDT",
  "side": "long",
  "entry_type": "limit",  // ← Limit entry
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
1. **Limit Entry:** Buy 0.1 ETH at $3500
2. **Conditional TP1:** Sell 0.05 ETH at $4000 (triggers when price hits $3500)
3. **Conditional TP2:** Sell 0.05 ETH at $4500 (triggers when price hits $3500)
4. **Stop-Loss:** qty="0" at $3200

## Code Changes

### File: `/app/syb/tradesuite/tradelens/lib/tradelens/api/trades.py`

**1. In `submit_trade()` (lines 394-465):**

Added logic after placing each entry order:

```python
# Place TP orders based on entry type
if leg['kind'] == 'entry' and leg['order_kind'] == 'market':
    # For MARKET entry, place regular TP orders immediately
    tp_levels_for_leg = preview_response.get('take_profit_levels', [])
    if tp_levels_for_leg:
        tp_side = 'Sell' if preview_response['side'] == 'long' else 'Buy'

        for tp_level in tp_levels_for_leg:
            tp_price = tp_level.get('price')
            size_pct = tp_level.get('size_pct', 100.0)
            tp_qty = float(leg['qty']) * (size_pct / 100.0)

            # Place regular TP limit order
            tp_response = bybit.place_order(
                category=category,
                symbol=preview_response['symbol'].upper(),
                side=tp_side,
                order_type='Limit',
                qty=str(tp_qty),
                price=str(tp_price),
                reduce_only=True,
                position_idx=position_idx
            )

elif leg['kind'] in ['entry', 'dca'] and leg['order_kind'] == 'limit':
    # For LIMIT entries/DCAs, place conditional TP orders
    # (existing conditional TP logic...)
```

**2. In `preview_bybit_orders()` (lines 724-757):**

Added similar logic for JSON preview:

```python
if leg['kind'] == 'entry' and leg['order_kind'] == 'market':
    # For MARKET entry, add regular TP orders
    tp_levels_for_leg = preview_response.get('take_profit_levels', [])
    if tp_levels_for_leg:
        tp_side = 'Sell' if preview_response['side'] == 'long' else 'Buy'

        for tp_level in tp_levels_for_leg:
            tp_price = tp_level.get('price')
            size_pct = tp_level.get('size_pct', 100.0)
            tp_qty = float(leg['qty']) * (size_pct / 100.0)

            # Build regular TP order params
            tp_params = bybit.build_order_params(...)

            bybit_orders.append({
                'leg_type': 'tp',
                'order_kind': 'limit',
                'params': tp_params,
                'note': f"Regular TP for market entry at {tp_price}"
            })

elif leg['kind'] in ['entry', 'dca'] and leg['order_kind'] == 'limit':
    # For LIMIT entries/DCAs, add conditional TP orders
    # (existing conditional TP logic...)
```

## Testing

### Test 1: Market Entry with TPs

**Setup:**
1. Open Smart Trade UI: http://localhost:3000/smart-trade
2. Select **Market** entry type
3. Add TP levels
4. Click "View Bybit JSON"

**Expected Result:**
You should see:
- 1 market entry order
- N regular TP orders (one per TP level)
- 1 stop-loss order

**JSON Preview:**
```json
{
  "orders": [
    {
      "leg_type": "entry",
      "params": {
        "side": "Buy",
        "orderType": "Market",
        "qty": "0.1"
      }
    },
    {
      "leg_type": "tp",
      "params": {
        "side": "Sell",
        "orderType": "Limit",
        "qty": "0.05",
        "price": "4000",
        "reduceOnly": true
      },
      "note": "Regular TP for market entry at 4000"
    },
    {
      "leg_type": "tp",
      "params": {
        "side": "Sell",
        "orderType": "Limit",
        "qty": "0.05",
        "price": "4500",
        "reduceOnly": true
      },
      "note": "Regular TP for market entry at 4500"
    },
    {
      "leg_type": "stop",
      "params": {
        "qty": "0",
        "triggerPrice": "3200",
        "closeOnTrigger": true
      }
    }
  ]
}
```

### Test 2: Limit Entry with TPs

**Setup:**
1. Open Smart Trade UI
2. Select **Limit** entry type
3. Set entry price
4. Add TP levels
5. Click "View Bybit JSON"

**Expected Result:**
You should see:
- 1 limit entry order
- N conditional TP orders (with triggerPrice = entry price)
- 1 stop-loss order

**JSON Preview:**
```json
{
  "orders": [
    {
      "leg_type": "entry",
      "params": {
        "side": "Buy",
        "orderType": "Limit",
        "qty": "0.1",
        "price": "3500"
      }
    },
    {
      "leg_type": "conditional_tp",
      "params": {
        "side": "Sell",
        "orderType": "Limit",
        "qty": "0.05",
        "price": "4000",
        "triggerPrice": "3500",  // ← Triggers at entry price
        "triggerDirection": 1,
        "reduceOnly": true
      },
      "note": "Triggers when entry price 3500 is hit"
    },
    // ... more conditional TPs
  ]
}
```

## Comparison

### Market Entry

| Aspect | Value |
|--------|-------|
| Entry order type | Market |
| TP order type | Regular limit |
| TP trigger | Immediate (no trigger) |
| Use case | Immediate execution, TPs active right away |

**Order Sequence:**
```
1. Market entry fills immediately
2. TPs are already active (regular limit orders)
3. When price reaches TP level → TP fills
```

### Limit Entry

| Aspect | Value |
|--------|-------|
| Entry order type | Limit |
| TP order type | Conditional limit |
| TP trigger | Entry price |
| Use case | Staged entry, TPs activate when entry fills |

**Order Sequence:**
```
1. Limit entry waits at entry price
2. Conditional TPs are staged (inactive)
3. When price reaches entry → entry fills, TPs activate
4. When price reaches TP level → TP fills
```

## Verification

### Check in Smart Trade UI

1. **Market entry test:**
   - Create market entry with 2 TPs
   - Submit
   - Check Bybit: Should see 2 regular TP orders immediately

2. **Limit entry test:**
   - Create limit entry with 2 TPs
   - Submit
   - Check Bybit: Should see 2 conditional TP orders (inactive until entry fills)

### Check in Bybit UI

**Market entry TPs:**
- Order type: **Limit**
- Trigger: **None** (regular order)
- Status: **Active** immediately

**Limit entry TPs:**
- Order type: **Limit**
- Trigger: **Yes** (conditional order with triggerPrice)
- Status: **Inactive** (until entry price is hit)

## Benefits

✅ **Market entries now work correctly** - TPs are placed immediately
✅ **Limit entries unchanged** - Still use conditional TPs
✅ **Consistent behavior** - Both entry types now create TPs
✅ **No manual intervention** - All orders placed automatically

## Backend Status

✅ Backend running on port 8088
✅ All changes deployed
✅ Ready for testing

---

**Date:** 2025-10-13
**Status:** ✅ Fixed and deployed
**Version:** 1.1.0
