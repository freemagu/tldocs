# Design Spec: Add Order to Existing Trade

## Overview

Add capability to create new orders (TP, DCA, Stop, etc.) for open trades directly from the Trade Journal details page.

## Order Type Taxonomy

### Order Types

| Type | Purpose | Direction | Reduce Only |
|------|---------|-----------|-------------|
| **Open** | Add to position | Same as trade | No |
| **Close** | Reduce position | Opposite of trade | Yes |

### Order Kinds

| Kind | Execution | Fields Required |
|------|-----------|-----------------|
| **Market** | Immediate | Quantity only |
| **Limit** | At price | Limit Price, Quantity |
| **Conditional** | Trigger → Market | Trigger Price, Quantity |

**Note**: Conditional orders execute as market when triggered (no conditional limit support in this version).

---

## Auto-Labeling Logic

### For Open Orders
| Condition | Label |
|-----------|-------|
| First filled order on trade | **Entry** |
| Subsequent filled orders | **DCA** |

### For Close Orders (Non-Conditional)
| Price vs WAEP | Label |
|---------------|-------|
| Price > WAEP + threshold (long) | **TP** (Take Profit) |
| Price < WAEP - threshold (long) | **TL** (Take Loss) |
| Price within ±threshold of WAEP | **BE** (Breakeven) |

*(Inverted for short positions)*

### For Close Orders (Conditional)

```
Conditional Close Order
    │
    ├─ Qty = Entire Position?
    │   │
    │   ├─ YES → Existing stop on trade?
    │   │         │
    │   │         ├─ NO  → "Stop"
    │   │         │
    │   │         └─ YES → Trailing TP/TL/BE (based on trigger vs WAEP)
    │   │
    │   └─ NO (partial) → Trailing TP/TL/BE (based on trigger vs WAEP)
```

| Trigger vs WAEP | Label |
|-----------------|-------|
| Trigger > WAEP + threshold (long) | **Trailing TP** |
| Trigger < WAEP - threshold (long) | **Trailing TL** |
| Trigger within ±threshold of WAEP | **Trailing BE** |

**Note**: A Stop can be above or below WAEP. The "Stop" label indicates it's a full-position exit trigger, not whether it's profitable.

**Config**: Breakeven threshold (0.05%) stored in `etc/config.yml`

---

## Panel Design

### Trigger: Single "Add Order" Button

```
┌─────────────────────────────────────────────────────────────┐
│  Order Legs Table                                           │
├─────────────────────────────────────────────────────────────┤
│  Side   Type        Kind         Price    Trigger   Qty     │
│  Buy    Entry       Market       45000    -         0.5     │
│  Sell   TP          Limit        48000    -         0.25    │
│  Buy    DCA         Limit        43000    -         0.25    │
├─────────────────────────────────────────────────────────────┤
│  [+ Add Order]                                              │
└─────────────────────────────────────────────────────────────┘
```

### Panel Layout

```
┌──────────────────────────────────────────────────────────────┐
│  Add Order                                              [×]  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Order Type                                                  │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  ○ Open                    ● Close                   │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Order Kind                                                  │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  ○ Market      ○ Limit      ● Conditional            │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Limit Price                              ← Only for Limit   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  [52000.00                                      ]    │    │
│  │  Current: $51,234                                    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Trigger Price                       ← Only for Conditional  │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  [50500.00                                      ]    │    │
│  │  Current: $51,234   WAEP: $45,200                    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Quantity                                                    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Mode: [Close Entire Position  ▼]                    │    │
│  │  Value: [    ] ← Hidden when Entire                  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌─ Preview ────────────────────────────────────────────┐    │
│  │  Action: SELL @ trigger $50,500 → Market             │    │
│  │  Label:  Stop (+11.7% from WAEP)                     │    │
│  │  Qty:    Entire position (0.5 BTC)                   │    │
│  │                                                      │    │
│  │  Est. profit: +$2,650 USD                            │    │
│  │  Position after: 0 BTC (closed)                      │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  [Cancel]                                   [Place Order]    │
└──────────────────────────────────────────────────────────────┘
```

---

## Field Visibility Matrix

| Field | Open | Close |
|-------|------|-------|
| Order Kind | Market, Limit, Conditional | Market, Limit, Conditional |
| Limit Price | If Limit | If Limit |
| Trigger Price | If Conditional | If Conditional |
| Quantity Mode | All modes except "Close Entire" | All modes |
| Quantity Value | If mode ≠ Entire | If mode ≠ Entire |

---

## Quantity Modes

| Mode | Description | Sends to Bybit |
|------|-------------|----------------|
| **Close Entire Position** | Close 100% (any remaining) | `qty: "0"` |
| **% of Remaining** | Percentage of current position | Calculated qty |
| **% of Peak** | Percentage of max position size | Calculated qty |
| **Absolute** | Exact quantity | User-specified qty |

**Note**: "Close Entire Position" only available for Close orders.

---

## Database: leg_type Values

| leg_type | When Applied |
|----------|--------------|
| `entry` | First Open order filled on trade |
| `dca` | Subsequent Open orders filled |
| `tp` | Close at profit (price > WAEP + threshold) |
| `tl` | Close at loss (price < WAEP - threshold) |
| `be` | Close at breakeven (within threshold) |
| `stop` | Conditional close of entire position (no existing stop) |
| `trailing_tp` | Conditional partial close, trigger in profit zone |
| `trailing_tl` | Conditional partial close, trigger in loss zone |
| `trailing_be` | Conditional partial close, trigger near WAEP |

---

## API Design

### Endpoint: `POST /open-orders/create`

**Request:**
```python
class CreateOrderRequest(BaseModel):
    trade_id: int                    # Link to trade_journal
    order_type: str                  # 'open' or 'close'
    order_kind: str                  # 'market', 'limit', 'conditional'
    price: Optional[str]             # For limit orders (limit price)
    trigger_price: Optional[str]     # For conditional orders
    qty_mode: str                    # 'entire', 'pct_remaining', 'pct_peak', 'absolute'
    qty_value: Optional[str]         # Required unless qty_mode='entire'
    account_name: Optional[str]
```

**Response:**
```python
class CreateOrderResponse(BaseModel):
    success: bool
    message: str
    order_id: Optional[str]          # Exchange order ID
    leg_id: Optional[int]            # Internal DB ID
    leg_type: str                    # Auto-determined label
```

### Endpoint: `POST /open-orders/preview`

Same request, returns preview without submitting:

```python
class PreviewOrderResponse(BaseModel):
    calculated_qty: str              # Actual qty (or "0" for entire)
    side: str                        # 'Buy' or 'Sell'
    leg_type: str                    # Auto-determined label
    estimated_pnl_usd: Optional[str] # For close orders
    pnl_percent: Optional[str]       # % from WAEP
    new_waep: Optional[str]          # For open orders
    position_after: str              # Position size after fill
    bybit_params: dict               # Raw params for Bybit
```

---

## Backend Implementation Flow

```
1. Validate trade_id exists and is OPEN
2. Get trade details: symbol, side, category, position_size, waep
3. Determine order side:
   - Open: same as trade (Long→Buy, Short→Sell)
   - Close: opposite of trade (Long→Sell, Short→Buy)
4. Calculate quantity:
   - entire: qty = "0"
   - pct_remaining: qty = position_size * (value/100)
   - pct_peak: qty = peak_position * (value/100)
   - absolute: qty = value
5. Determine leg_type based on:
   - For conditional + entire + no existing stop → "stop"
   - Otherwise use price/trigger vs WAEP logic
6. Build Bybit params:
   - Market: place_order(orderType="Market", qty=qty)
   - Limit: place_order(orderType="Limit", price=price, qty=qty)
   - Conditional: place_order(orderType="Market", triggerPrice=trigger,
                              triggerDirection=calc_direction)
7. Submit to Bybit
8. On success:
   - Insert into order_leg_live with calculated leg_type
   - Insert into trade_leg_map
   - Trigger refresh
9. Return response with leg_type
```

---

## Conditional Order: Trigger Direction

For Bybit conditional orders:

```python
def calc_trigger_direction(current_price, trigger_price):
    if current_price > trigger_price:
        return "1"  # Trigger when price falls to trigger
    else:
        return "2"  # Trigger when price rises to trigger
```

---

## Config Addition

**etc/config.yml:**
```yaml
trading:
  breakeven_threshold_pct: 0.05  # ±0.05% of WAEP = breakeven
```

---

## Validation Rules

### Open Orders
- Quantity must be > 0 (no "entire" mode for opens)

### Close Orders
- Quantity cannot exceed remaining position (unless "entire")
- For conditional: trigger must be reachable from current price

### All Orders
- Trade must be OPEN status
- Account must have access to trade's account

---

## Detection of Existing Stop

Check `order_leg_live` for the trade:
```sql
SELECT COUNT(*) FROM order_leg_live oll
JOIN trade_leg_map tlm ON oll.id = tlm.hist_leg_id
WHERE tlm.trade_id = @trade_id
  AND oll.leg_type = 'stop'
  AND oll.status IN ('new', 'untriggered')
```

If count > 0, a stop already exists → use Trailing TP/TL/BE labeling even for entire position.

---

## Preview Examples

### Example 1: Stop (Conditional Close Entire)

**Setup**: Long BTCUSDT, WAEP $45,200, position 0.5 BTC, current price $51,234, no existing stop

**User Input**:
- Order Type: Close
- Order Kind: Conditional
- Trigger Price: $50,500
- Quantity: Close Entire Position

**Preview**:
```
Action: SELL @ trigger $50,500 → Market
Label:  Stop (+11.7% from WAEP)
Qty:    Entire position (0.5 BTC)

Est. profit: +$2,650 USD
Position after: 0 BTC (closed)
```

### Example 2: DCA (Limit Open)

**Setup**: Long BTCUSDT, WAEP $45,200, position 0.5 BTC, current price $44,000

**User Input**:
- Order Type: Open
- Order Kind: Limit
- Limit Price: $43,000
- Quantity: 50% of Peak

**Preview**:
```
Action: BUY 0.25 BTC @ $43,000 (Limit)
Label:  DCA

Current WAEP: $45,200 (0.5 BTC)
New WAEP:     $44,467 (-1.62%)
Position after: 0.75 BTC
```

### Example 3: Take Loss (Market Close)

**Setup**: Long BTCUSDT, WAEP $45,200, position 0.5 BTC, current price $42,000

**User Input**:
- Order Type: Close
- Order Kind: Market
- Quantity: 25% of Remaining

**Preview**:
```
Action: SELL 0.125 BTC @ Market (~$42,000)
Label:  TL (-7.1% from WAEP)

Est. loss: -$400 USD
Position after: 0.375 BTC
```

### Example 4: Trailing TP (Conditional Partial Close)

**Setup**: Long BTCUSDT, WAEP $45,200, position 0.5 BTC, current price $51,234

**User Input**:
- Order Type: Close
- Order Kind: Conditional
- Trigger Price: $50,500
- Quantity: 25% of Remaining

**Preview**:
```
Action: SELL 0.125 BTC @ trigger $50,500 → Market
Label:  Trailing TP (+11.7% from WAEP)

Est. profit: +$662.50 USD
Position after: 0.375 BTC
```

---

## Implementation Phases

### Phase 1: Backend API
- Add `breakeven_threshold_pct` to config
- Create `/open-orders/create` endpoint
- Create `/open-orders/preview` endpoint
- Implement leg_type auto-labeling logic
- Implement existing stop detection

### Phase 2: Frontend Panel
- Create `AddOrderPanel` component (floating panel)
- Add "Add Order" button to OrderLegsTable
- Implement field visibility logic
- Implement quantity mode selector
- Connect to preview API for live updates

### Phase 3: Integration
- Chart preview overlay for new order
- Refresh after order creation
- Error handling and validation messages

---

**Created**: 2026-01-16
**Status**: Approved for implementation
