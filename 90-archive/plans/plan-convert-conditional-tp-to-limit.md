# Plan: Convert Conditional TP to Limit Order

## Overview

Add functionality to convert a **TP Conditional→Market** order into a regular **Limit** order, preserving the price history on charts as a continuous line via a `lineage_id` linking mechanism.

**Scope:**
- Only TP orders that are **conditional→market** (has `trigger_price`, `order_kind='Conditional'`, and places a Market order when triggered)
- **Out of scope:** Conditional→Limit orders (used for DCA purposes)

**User interaction:** One-click convert (no confirmation dialog)

---

## Part 1: Schema Changes

### 1.1 Add `lineage_id` Column

Add `lineage_id` to both `order_leg_live` and `order_leg_hist` tables.

```sql
-- Migration: 009_add_lineage_id.sql

-- Add lineage_id to order_leg_live
ALTER TABLE order_leg_live ADD lineage_id VARCHAR(64) NULL;

-- Add lineage_id to order_leg_hist
ALTER TABLE order_leg_hist ADD lineage_id VARCHAR(64) NULL;

-- Backfill: existing orders get lineage_id = exchange_order_id
UPDATE order_leg_live SET lineage_id = exchange_order_id WHERE lineage_id IS NULL;
UPDATE order_leg_hist SET lineage_id = exchange_order_id WHERE lineage_id IS NULL;

-- Index for efficient lookups
CREATE INDEX idx_order_leg_live_lineage ON order_leg_live(lineage_id);
CREATE INDEX idx_order_leg_hist_lineage ON order_leg_hist(lineage_id);
```

### 1.2 Update `setup_database.py`

Add `lineage_id VARCHAR(64) NULL` to both table definitions in `setup_database.py`.

**Files to modify:**
- `bin/setup/setup_database.py` - Add column to table definitions + indexes

---

## Part 2: Backend Changes

### 2.1 New API Endpoint

**Endpoint:** `POST /api/orders/{exchange_order_id}/convert-to-limit`

**Location:** `lib/tradelens/api/orders.py` (new file) or add to `open_orders.py`

**Request:** Empty body (all info derived from the order)

**Response:**
```json
{
  "success": true,
  "old_order_id": "abc123",
  "new_order_id": "xyz789",
  "lineage_id": "abc123",
  "price": "91000",
  "message": "Converted to limit order at 91000"
}
```

**Error Response:**
```json
{
  "success": false,
  "message": "Order is not a conditional TP order"
}
```

### 2.2 Conversion Logic

```python
async def convert_conditional_tp_to_limit(exchange_order_id: str, account_id: int):
    """
    Convert a conditional TP (market) order to a regular limit order.

    Steps:
    1. Fetch order from order_leg_live
    2. Validate: must be leg_type='TP', order_kind='Conditional', has trigger_price
    3. Validate: must NOT have a limit price (conditional→market, not conditional→limit)
    4. Create new limit order on Bybit at trigger_price
    5. If success: Cancel old conditional order on Bybit
    6. If cancel fails: Attempt to cancel new order (rollback)
    7. Update lineage_id on new order to match old order's lineage_id
    8. Add CONVERTED event to order_leg_event for audit trail
    """
```

### 2.3 Validation Rules

An order is eligible for conversion if ALL of these are true:

| Field | Condition |
|-------|-----------|
| `leg_type` | = 'TP' (case-insensitive) |
| `order_kind` | = 'Conditional' |
| `trigger_price` | IS NOT NULL |
| `price` | IS NULL (conditional→market, not conditional→limit) |
| `status` | IN ('New', 'Untriggered') - still active |

### 2.4 Create-Then-Cancel Order of Operations

To minimize risk of being left without TP protection:

```
1. Fetch order details from order_leg_live
2. Validate eligibility
3. Get current lineage_id (or use exchange_order_id if NULL)
4. CREATE new limit order on Bybit
   - category: same
   - symbol: same
   - side: same
   - qty: same
   - price: trigger_price (the TP level becomes the limit price)
   - reduceOnly: true
   - positionIdx: same
   - timeInForce: GTC
5. If create FAILS → return error, old order still active
6. If create SUCCESS → CANCEL old conditional order
7. If cancel FAILS → attempt to cancel new order (rollback), return error
8. Update new order in order_leg_live:
   - SET lineage_id = (old order's lineage_id)
   - SET leg_type = 'TP' (preserve the leg type)
9. Add event to order_leg_event with event_type = 'CONVERTED'
10. Return success with new order details
```

### 2.5 New Event Type: CONVERTED

Add `CONVERTED` to the event types in `order_leg_event_tracker.py`:

```python
# Event types
# CREATED, AMENDED, FILLED, CANCELLED, CONVERTED
```

The CONVERTED event captures:
- The old order's final state before conversion
- Links to the new order via `lineage_id`
- Stored in `order_leg_event` with `event_type = 'CONVERTED'`

**Files to modify:**
- `lib/tradelens/api/orders.py` (new) or `open_orders.py` - Add endpoint
- `lib/tradelens/utils/order_leg_event_tracker.py` - Add CONVERTED event type
- `lib/tradelens/adapters/bybit_client.py` - Verify `place_order` and `cancel_order` methods exist

---

## Part 3: Chart/Query Changes

### 3.1 Update `fetch_price_history_for_legs()`

**Current behavior:** Groups events by `exchange_order_id`

**New behavior:** Groups events by `lineage_id`

**Location:** `lib/tradelens/api/journal.py`

```python
def fetch_price_history_for_legs(cursor, lineage_ids: List[str], account_id: int) -> Dict[str, List[Dict]]:
    """
    Batch fetch price history events for legs from order_leg_event table.

    Changed: Now groups by lineage_id instead of exchange_order_id.
    This allows converted orders to show continuous price history.
    """
    # Query joins order_leg_event with order_leg_live/hist to get lineage_id
    # Groups results by lineage_id
```

**SQL Change:**

```sql
-- Before: GROUP BY exchange_order_id
-- After: Join to get lineage_id and group by that

SELECT
    COALESCE(oll.lineage_id, ole.exchange_order_id) as lineage_id,
    CASE WHEN ole.event_type = 'CREATED'
         THEN ole.exchange_created_at
         ELSE ole.exchange_updated_at
    END as event_time,
    ole.price,
    ole.trigger_price,
    ole.event_type
FROM order_leg_event ole
LEFT JOIN order_leg_live oll ON ole.exchange_order_id = oll.exchange_order_id
LEFT JOIN order_leg_hist olh ON ole.exchange_order_id = olh.exchange_order_id
WHERE ole.account_id = ?
  AND COALESCE(oll.lineage_id, olh.lineage_id, ole.exchange_order_id) IN (...)
ORDER BY lineage_id,
         CASE WHEN ole.event_type = 'CREATED'
              THEN ole.exchange_created_at
              ELSE ole.exchange_updated_at
         END
```

### 3.2 Update Leg Fetching

When fetching legs for the journal, also return `lineage_id` and use it for price history lookup.

**Files to modify:**
- `lib/tradelens/api/journal.py` - Update `fetch_price_history_for_legs()` and leg queries

---

## Part 4: Frontend Changes

### 4.1 Make Actions Column Sticky (Right Side)

**Location:** `frontend/web/src/components/journal/order-legs-table.tsx`

Update the Actions column header and cells to be sticky on the right:

```tsx
// Header
<th className="px-3 py-2 text-center text-xs font-medium text-gray-400 uppercase tracking-wider sticky right-0 bg-dark-tertiary z-10 shadow-[-4px_0_6px_-2px_rgba(0,0,0,0.3)]">
  Actions
</th>

// Cell
<td className="px-3 py-2 text-center sticky right-0 bg-dark-secondary z-10 shadow-[-4px_0_6px_-2px_rgba(0,0,0,0.3)]">
  ...
</td>

// Cell on hover row - need to match hover background
<td className="px-3 py-2 text-center sticky right-0 bg-dark-secondary group-hover:bg-dark-tertiary z-10 shadow-[-4px_0_6px_-2px_rgba(0,0,0,0.3)]">
```

Also add `group` class to `<tr>` for hover state:
```tsx
<tr key={leg.id} className="group hover:bg-dark-tertiary transition-colors">
```

### 4.2 Add "Convert to Limit" Icon Button

**Icon:** `ArrowRightLeft` from lucide-react (represents conversion/swap)

**Location:** In the Actions column, next to Edit and Cancel buttons

**Eligibility check (client-side):**
```typescript
/**
 * Check if a TP conditional→market order can be converted to a limit order
 */
function canConvertToLimit(leg: TradeLegDetail): boolean {
  // Must be a TP order
  if (leg.leg_type?.toLowerCase() !== 'tp') return false
  // Must be conditional
  if (leg.order_kind?.toLowerCase() !== 'conditional') return false
  // Must have trigger_price (conditional trigger)
  if (!leg.trigger_price) return false
  // Must NOT have price (conditional→market, not conditional→limit)
  if (leg.price) return false
  // Must be in open status
  const status = leg.status?.toLowerCase() || ''
  return status === 'new' || status === 'untriggered'
}
```

**Button markup:**
```tsx
{canConvertToLimit(leg) && onConvertToLimitClick && (
  <button
    onClick={() => onConvertToLimitClick(leg)}
    disabled={convertingLegId === leg.id}
    className="p-1.5 hover:bg-gray-700 rounded transition-colors disabled:opacity-50"
    title="Convert to limit order (saves taker fees)"
  >
    {convertingLegId === leg.id ? (
      <Loader2 className="w-4 h-4 text-gray-400 animate-spin" />
    ) : (
      <ArrowRightLeft className="w-4 h-4 text-gray-400 hover:text-green-400" />
    )}
  </button>
)}
```

**Icon placement order:** Edit | Convert | Cancel

### 4.3 Component Props Update

Add new props to `OrderLegsTableProps`:

```typescript
interface OrderLegsTableProps {
  legs: TradeLegDetail[]
  legVisibility: LegVisibility
  onLegVisibilityChange: (legId: number, visible: boolean) => void
  onAmendClick?: (leg: TradeLegDetail) => void
  onCancelClick?: (leg: TradeLegDetail) => void
  cancellingLegId?: number | null
  onConvertToLimitClick?: (leg: TradeLegDetail) => void  // NEW
  convertingLegId?: number | null                        // NEW
  onAddOrderClick?: () => void
  tradeStatus?: 'open' | 'closed'
}
```

### 4.4 API Call

**Location:** `frontend/web/src/lib/api.ts`

```typescript
export async function convertOrderToLimit(exchangeOrderId: string): Promise<{
  success: boolean
  old_order_id?: string
  new_order_id?: string
  lineage_id?: string
  price?: string
  message: string
}> {
  const response = await fetch(`${API_BASE}/orders/${exchangeOrderId}/convert-to-limit`, {
    method: 'POST',
  })
  return response.json()
}
```

### 4.5 Parent Component Integration

**Location:** `trade-journal-expanded-row.tsx` or wherever `OrderLegsTable` is used

```typescript
const [convertingLegId, setConvertingLegId] = useState<number | null>(null)

const handleConvertToLimit = async (leg: TradeLegDetail) => {
  if (!leg.exchange_order_id) return
  setConvertingLegId(leg.id)
  try {
    const result = await convertOrderToLimit(leg.exchange_order_id)
    if (result.success) {
      toast.success(result.message)
      // Refresh legs data
      refetchLegs()
    } else {
      toast.error(result.message)
    }
  } catch (error) {
    toast.error('Failed to convert order')
  } finally {
    setConvertingLegId(null)
  }
}
```

### 4.6 UI Behavior

- **One-click:** No confirmation dialog
- **Loading state:** Shows spinner on the convert button while API call in progress
- **Success:** Toast message, refresh legs table
- **Error:** Toast error message
- **Tooltip:** "Convert to limit order (saves taker fees)"

**Files to modify:**
- `frontend/web/src/components/journal/order-legs-table.tsx` - Add icon, sticky column
- `frontend/web/src/lib/api.ts` - Add API function
- `frontend/web/src/components/journal/trade-journal-expanded-row.tsx` - Wire up handler

---

## Part 5: Pipeline Changes

### 5.1 Update `refresh_order_leg_live.py`

When inserting new orders, set `lineage_id = exchange_order_id` by default.

```python
# When inserting a new order
lineage_id = exchange_order_id  # Default: order is its own lineage root
```

### 5.2 Update `refresh_order_leg_hist.py`

Same logic: when archiving orders, preserve the `lineage_id`.

**Files to modify:**
- `bin/pipeline/refresh_order_leg_live.py` - Set default lineage_id
- `bin/pipeline/refresh_order_leg_hist.py` - Preserve lineage_id when archiving

---

## Implementation Order

1. **Schema & Migration** (Part 1)
   - Create migration file
   - Update setup_database.py
   - Run migration

2. **Pipeline Updates** (Part 5)
   - Update refresh scripts to set lineage_id on new orders
   - Backfill existing data

3. **Backend API** (Part 2)
   - Add convert endpoint
   - Add CONVERTED event type

4. **Chart/Query Updates** (Part 3)
   - Update fetch_price_history_for_legs to use lineage_id

5. **Frontend** (Part 4)
   - Add Convert to Limit button
   - Wire up API call

6. **Testing**
   - Create a conditional TP order
   - Amend price a few times
   - Convert to limit
   - Amend price again
   - Verify chart shows continuous line

---

## File Summary

| File | Change |
|------|--------|
| `migrations/009_add_lineage_id.sql` | NEW - Schema migration |
| `bin/setup/setup_database.py` | Add lineage_id column + indexes |
| `bin/pipeline/refresh_order_leg_live.py` | Set default lineage_id |
| `bin/pipeline/refresh_order_leg_hist.py` | Preserve lineage_id |
| `lib/tradelens/api/orders.py` | NEW - Convert endpoint (or add to open_orders.py) |
| `lib/tradelens/utils/order_leg_event_tracker.py` | Add CONVERTED event type |
| `lib/tradelens/api/journal.py` | Update price history query to use lineage_id |
| `frontend/.../order-legs-table.tsx` | Add convert icon, make Actions column sticky right |
| `frontend/.../trade-journal-expanded-row.tsx` | Wire up convert handler |
| `frontend/.../api.ts` | Add convertOrderToLimit function |

---

## Edge Cases

1. **Order filled between create and cancel**
   - New limit order created, old conditional triggers simultaneously
   - Result: Both orders may partially fill
   - Mitigation: Rare edge case, user should check positions

2. **Network failure during conversion**
   - Create succeeds, cancel fails
   - Backend attempts to cancel new order as rollback
   - If rollback fails: Return error with both order IDs for manual cleanup

3. **Order already cancelled/filled**
   - Validation step checks status is 'New' or 'Untriggered'
   - Returns error if order is in terminal state

4. **Multiple conversions of same lineage**
   - Supported: Each conversion inherits the same lineage_id
   - Chart shows continuous history across all conversions

---

## Questions Resolved

- **Option A or B?** → B (lineage_id)
- **Which orders?** → Only TP + conditional→market
- **Confirmation?** → One-click (no dialog)
