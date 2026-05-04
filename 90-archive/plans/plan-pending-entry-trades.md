# Design: Pending Entry Trades in Trade Journal

## Problem Statement

When a trade is submitted with a **limit entry**, the entry order may take time to fill (or never fill). Currently:
- Trade journal records are only created by the pipeline when orders fill
- Orders for pending limit entries appear as "orphaned" in the Open Orders tab
- Users have no visibility into pending trades awaiting entry

## Solution

Create `trade_journal` records **immediately** on limit entry submission with `status='pending_entry'`. The existing pipeline will:
1. Match orders to this trade via symbol/account/side (existing logic)
2. Update the record when entry fills (status → 'open', populate entry_price, qty, etc.)

---

## Status Lifecycle

```
┌─────────────────┐    Entry Fills    ┌──────────┐    Position Closed    ┌──────────┐
│  pending_entry  │ ───────────────► │   open   │ ───────────────────► │  closed  │
└─────────────────┘                   └──────────┘                       └──────────┘
        │                                                                      ▲
        │              User Cancels / Orders Cancelled                         │
        └──────────────────────────────────────────────────────────────────────┘
                                  (closed with no fills)
```

| Status | Meaning | Position Exists? |
|--------|---------|------------------|
| `pending_entry` | Limit entry submitted, awaiting fill | No |
| `open` | Entry filled, position active | Yes |
| `closed` | Position fully closed | No |

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Entry price for pending | NULL | Only show actual fill price, not planned |
| Qty for pending | NULL | Only show actual filled qty |
| Same symbol conflict | Block ALL submissions if open/pending trade exists on symbol | Prevent confusion; we don't support multiple concurrent trades on same symbol |
| Cancel mechanism | Manual + auto-detect | Flexibility: user can cancel explicitly, or system detects cancelled orders |

---

## Data Model

### trade_journal columns at creation (pending_entry)

| Column | Value at Creation | Updated When Fills |
|--------|-------------------|---------------------|
| `trade_id` | AUTO (identity) | — |
| `account_id` | From submission | — |
| `symbol` | From submission | — |
| `side` | From submission (long/short) | — |
| `category` | From submission (linear/spot) | — |
| `position_idx` | From submission | — |
| `status` | `'pending_entry'` | → `'open'` |
| `trade_intent_id` | From submission | — |
| `trade_idea_id` | From submission (if linked) | — |
| `created_at` | NOW | — |
| `updated_at` | NOW | Updated on changes |
| `opened_at` | NULL | First fill timestamp |
| `entry_price` | NULL | Actual WAEP from fills |
| `qty` | NULL | Actual filled qty |
| `stop_loss` | From submission (if provided) | — |
| `take_profit` | From submission (if provided) | — |
| `closed_at` | NULL | Set when cancelled or closed |

---

## Implementation Plan

### Phase 1: Core Changes

#### 1.1 Trade Submission - Conflict Check & Pending Entry Journal

**File:** `lib/tradelens/api/trades.py`

**Changes:**
1. Add validation: Block ALL submissions if open/pending_entry trade exists for same symbol/account
2. After placing limit entry orders, create trade_journal with status='pending_entry'
3. Return the new trade_id in the response

**New functions:**
```python
def check_active_trade_conflict(cursor, account_id: int, symbol: str) -> Optional[dict]:
    """
    Check if an active trade (open or pending_entry) already exists for this symbol.
    Returns the conflicting trade info if found, None otherwise.

    NOTE: This applies to ALL trade submissions (market and limit), not just limit entries.
    We do not support multiple concurrent trades on the same symbol.
    """
    sql = f"""
    SELECT trade_id, status, side FROM trade_journal
    WHERE account_id = {account_id}
      AND symbol = {escape_sql(symbol)}
      AND status IN ('open', 'pending_entry')
    """
    cursor.execute(sql)
    row = cursor.fetchone()
    if row:
        return {'trade_id': row[0], 'status': row[1], 'side': row[2]}
    return None

def create_pending_entry_journal(
    cursor,
    account_id: int,
    symbol: str,
    side: str,
    category: str,
    position_idx: int,
    trade_intent_id: int,
    trade_idea_id: Optional[int],
    stop_loss: Optional[float],
    take_profit: Optional[float],
) -> int:
    """Create trade_journal record for limit entry awaiting fill."""
    sql = f"""
    INSERT INTO trade_journal (
        account_id, symbol, side, category, position_idx,
        status, trade_intent_id, trade_idea_id,
        stop_loss, take_profit,
        created_at, updated_at
    ) VALUES (
        {account_id}, {escape_sql(symbol)}, {escape_sql(side)},
        {escape_sql(category)}, {position_idx},
        'pending_entry', {trade_intent_id}, {trade_idea_id or 'NULL'},
        {stop_loss or 'NULL'}, {take_profit or 'NULL'},
        getdate(), getdate()
    )
    """
    cursor.execute(sql)

    # Get the new trade_id
    cursor.execute("SELECT @@identity")
    return int(cursor.fetchone()[0])
```

**Integration in submit_trade():**
```python
# EARLY in submit_trade(), BEFORE placing any orders:

# Check for conflicting active trade (applies to ALL submissions)
conflict = check_active_trade_conflict(cursor, account_id, symbol)
if conflict:
    status_msg = "an open" if conflict['status'] == 'open' else "a pending entry"
    raise HTTPException(
        status_code=400,
        detail=f"Cannot submit trade: {status_msg} trade already exists for {symbol} "
               f"(trade_id={conflict['trade_id']}, {conflict['side']}). "
               f"Close or cancel it first."
    )

# ... proceed with order placement ...

# AFTER orders placed successfully (only for limit entries):
if entry_type == 'limit':
    # Create pending entry journal
    trade_id = create_pending_entry_journal(
        cursor=cursor,
        account_id=account_id,
        symbol=symbol,
        side=side,
        category=category,
        position_idx=position_idx,
        trade_intent_id=trade_intent_id,
        trade_idea_id=trade_idea_id,
        stop_loss=stop_loss,
        take_profit=take_profit_price,
    )
```

#### 1.2 Pipeline - Handle pending_entry → open Transition

**File:** `bin/pipeline/refresh_trade_journal.py`

**Changes:**
1. Before creating a new trade_journal, check for existing pending_entry
2. If found, UPDATE instead of INSERT
3. Populate opened_at, entry_price, qty from actual fills

**Modified logic in process_symbol_legs():**
```python
def process_symbol_legs(cursor, account_id, symbol, side, legs):
    """Process filled legs for a symbol/side - create or update trade_journal."""

    # Check for existing pending_entry
    cursor.execute(f"""
        SELECT trade_id, status, trade_intent_id
        FROM trade_journal
        WHERE account_id = {account_id}
          AND symbol = {escape_sql(symbol)}
          AND side = {escape_sql(side)}
          AND status = 'pending_entry'
    """)
    pending = cursor.fetchone()

    if pending:
        # Update existing pending_entry → open
        trade_id = pending[0]
        first_fill = min(leg['filled_at'] for leg in legs if leg['leg_type'] == 'entry')
        waep = calculate_waep(legs)
        total_qty = sum(leg['qty'] for leg in legs if leg['leg_type'] == 'entry')

        cursor.execute(f"""
            UPDATE trade_journal SET
                status = 'open',
                opened_at = {escape_sql(first_fill)},
                entry_price = {waep},
                qty = {total_qty},
                updated_at = getdate()
            WHERE trade_id = {trade_id}
        """)
        return trade_id
    else:
        # No pending_entry - create new (existing behavior for market entries)
        return create_new_trade_journal(cursor, account_id, symbol, side, legs)
```

#### 1.3 Orphan Detection - Recognize pending_entry as Valid

**File:** `lib/tradelens/api/open_orders.py`

**Changes:**
1. Update JOIN to include pending_entry status
2. Add PENDING_ENTRY health flag
3. Add 'pending' health level

**SQL change (around line 270):**
```sql
-- Change this:
AND tj_open.status = 'open'

-- To this:
AND tj_open.status IN ('open', 'pending_entry')
```

**Health flags (around line 165):**
```python
def compute_health_flags(order: dict) -> tuple[list[str], str]:
    flags = []
    trade_status = order.get('trade_status')

    if trade_status == 'pending_entry':
        flags.append('PENDING_ENTRY')
        return flags, 'pending'  # New health level

    if trade_status is None:
        flags.append('UNLINKED')
    elif trade_status == 'closed':
        flags.append('CLOSED_TRADE')

    # ... rest of existing logic
```

**Response model update (dto.py or open_orders.py):**
```python
# Add 'pending' to health_level options
health_level: Literal['healthy', 'pending', 'warning', 'critical']
```

---

### Phase 2: Cancel Mechanism

#### 2.1 Manual Cancel Endpoint

**File:** `lib/tradelens/api/trades.py`

**New endpoint:**
```python
@router.post("/trades/{trade_id}/cancel")
async def cancel_pending_trade(trade_id: int, cancel_orders: bool = True):
    """
    Cancel a pending_entry trade.

    Args:
        trade_id: The trade to cancel
        cancel_orders: If True, also cancel associated orders on exchange
    """
    # Verify trade exists and is pending_entry
    trade = get_trade_by_id(trade_id)
    if not trade:
        raise HTTPException(404, "Trade not found")
    if trade['status'] != 'pending_entry':
        raise HTTPException(400, f"Trade is {trade['status']}, not pending_entry")

    # Optionally cancel orders on exchange
    if cancel_orders:
        cancel_orders_for_trade(trade_id)

    # Update trade status
    cursor.execute(f"""
        UPDATE trade_journal SET
            status = 'closed',
            closed_at = getdate(),
            updated_at = getdate()
        WHERE trade_id = {trade_id}
    """)

    return {"success": True, "message": f"Trade {trade_id} cancelled"}
```

#### 2.2 Auto-Detect Cancelled Orders

**File:** `bin/pipeline/refresh_trade_journal.py` (or new cleanup script)

**Logic:**
```python
def detect_abandoned_pending_entries(cursor):
    """
    Find pending_entry trades where all entry orders have been cancelled.
    Auto-close these trades.
    """
    cursor.execute("""
        SELECT tj.trade_id, tj.symbol, tj.account_id
        FROM trade_journal tj
        WHERE tj.status = 'pending_entry'
          AND NOT EXISTS (
              -- No live entry orders for this trade
              SELECT 1 FROM order_leg_live oll
              WHERE oll.symbol = tj.symbol
                AND oll.account_id = tj.account_id
                AND oll.pos_side = tj.side
                AND oll.leg_type = 'entry'
          )
          AND NOT EXISTS (
              -- No filled entry orders either
              SELECT 1 FROM order_leg_hist olh
              WHERE olh.symbol = tj.symbol
                AND olh.account_id = tj.account_id
                AND olh.pos_side = tj.side
                AND olh.leg_type = 'entry'
                AND olh.filled_at > tj.created_at
          )
    """)

    abandoned = cursor.fetchall()
    for trade_id, symbol, account_id in abandoned:
        logger.info(f"Auto-closing abandoned pending_entry: trade_id={trade_id} {symbol}")
        cursor.execute(f"""
            UPDATE trade_journal SET
                status = 'closed',
                closed_at = getdate(),
                updated_at = getdate()
            WHERE trade_id = {trade_id}
        """)
```

---

### Phase 3: Display Updates

#### 3.1 Trade Journal CLI

**File:** `bin/show/show_trade_journal.py`

**Changes:**
- Include pending_entry trades in display
- Show distinct formatting for pending status

```python
STATUS_DISPLAY = {
    'open': ('OPEN', 'green'),
    'pending_entry': ('PENDING', 'yellow'),  # Or 'AWAITING ENTRY'
    'closed': ('CLOSED', 'dim'),
}
```

#### 3.2 Trade Journal API

**File:** `lib/tradelens/api/journal.py` (or wherever journal endpoint is)

**Changes:**
- Include pending_entry trades by default (or add filter param)
- Return status field for frontend to display appropriately

#### 3.3 Frontend

**Files:** Various frontend components

**Changes:**
- Trade Journal view: Show pending_entry trades with visual distinction
- Open Orders tab: Show "Pending Entry" badge instead of "Orphaned" for linked orders
- Add "Cancel Pending Trade" action button for pending_entry trades

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Entry partially fills | Status → 'open', qty = partial; remaining order still linked |
| Entry never fills, user cancels | Manual cancel closes trade |
| Entry orders expire/cancelled | Auto-detect closes trade |
| Submit any trade while open/pending exists on symbol | Blocked with error (applies to ALL submissions) |
| Market entry (not limit) | Existing behavior - pipeline creates journal; conflict check still applies |
| Pending entry with no orders placed (error during submission) | Rollback - don't create journal if order placement fails |
| User tries to submit opposite side on same symbol | Blocked - no concurrent trades on same symbol regardless of side |

---

## Testing Checklist

- [ ] Submit limit entry → trade_journal created with status='pending_entry'
- [ ] Entry fills → status transitions to 'open', entry_price/qty populated
- [ ] Partial fill → status='open', qty=partial amount
- [ ] Open Orders shows linked orders as 'pending' not 'orphaned'
- [ ] Submit any trade on same symbol while open → blocked with error
- [ ] Submit any trade on same symbol while pending_entry → blocked with error
- [ ] Submit opposite side on same symbol → blocked with error (no hedge mode support)
- [ ] Cancel pending trade manually → status='closed', orders cancelled
- [ ] Orders cancelled externally → auto-detect closes trade
- [ ] Trade journal CLI shows pending trades distinctly
- [ ] Frontend shows pending trades appropriately
- [ ] Market entry still works (no pending journal created, but conflict check applies)

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/tradelens/api/trades.py` | Add conflict check, create_pending_entry_journal(), cancel endpoint |
| `bin/pipeline/refresh_trade_journal.py` | Handle pending_entry → open transition, auto-detect abandoned |
| `lib/tradelens/api/open_orders.py` | Treat pending_entry as valid (not orphan), add PENDING_ENTRY flag |
| `lib/tradelens/models/dto.py` | Add 'pending' health level |
| `bin/show/show_trade_journal.py` | Display pending_entry status |
| `frontend/web/src/...` | UI updates for pending entry display |

---

## Migration

No schema changes required - `status` is already a VARCHAR column that accepts any string value.

However, consider:
1. Check if any existing trades have status values that conflict
2. Add index on `(account_id, symbol, side, status)` for efficient conflict checking

```sql
-- Optional: Add index for conflict check performance
CREATE INDEX idx_trade_journal_pending_check
ON trade_journal (account_id, symbol, side, status)
```

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Store planned entry_price for pending? | No - leave NULL until filled |
| Allow multiple trades on same symbol? | No - block ALL submissions if open/pending_entry exists on symbol (regardless of side) |
| How to cancel pending trades? | Both manual option and auto-detect |
