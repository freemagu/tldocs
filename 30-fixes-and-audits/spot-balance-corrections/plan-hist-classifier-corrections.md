# Plan: Make Historical Classifier Aware of Spot Balance Corrections

## Problem Statement

The historical order classifier (`refresh_order_leg_hist.py`) builds position state chronologically from orders only. It doesn't know about `spot_balance_corrections`, which represent pre-existing holdings or adjustments outside the order import window.

This causes misclassification when:
1. A correction adds a starting position (e.g., +2 ETH)
2. Historical orders show sells that appear to exceed buys
3. The classifier sees negative position and misclassifies sell orders as "entry" (short) instead of "tp" (take profit)

**Example**: ETHUSDT had a correction of +1.99928 ETH from July 2025. When processing a Nov 2025 sell, the classifier saw a negative position (because it didn't know about the correction) and classified the sell as `entry` instead of `tp`.

## Solution Overview

Inject spot_balance_corrections into the historical position tracking stream at their `effective_time`. This ensures the classifier sees the correct position state when classifying orders.

## Implementation Steps

### Step 1: Add correction fetching function to refresh_order_leg_hist.py

Create a lightweight function to fetch spot_balance_corrections (simpler than the TradeLeg-based version in refresh_trade_journal.py).

```python
def fetch_spot_corrections_for_position_tracking(
    conn,
    account_name: str,
    symbol: Optional[str] = None,
    since: Optional[datetime] = None
) -> List[Dict[str, Any]]:
    """
    Fetch spot balance corrections for position tracking during historical classification.

    Returns lightweight dicts (not TradeLeg objects) with:
    - symbol
    - effective_time (as milliseconds for sorting with orders)
    - qty_delta (signed)
    - price_for_pnl (optional, for WAEP if include_in_waep)
    - include_in_waep
    """
    where_clauses = [f"account_id = '{account_name}'"]

    if symbol:
        where_clauses.append(f"symbol = '{symbol}'")
    if since:
        where_clauses.append(f"effective_time >= '{since.strftime('%Y-%m-%d %H:%M:%S')}'")

    sql = f"""
    SELECT symbol, effective_time, qty_delta, price_for_pnl, include_in_waep
    FROM spot_balance_correction
    WHERE {' AND '.join(where_clauses)}
    ORDER BY effective_time
    """

    cursor = conn.cursor()
    cursor.execute(sql)
    rows = cursor.fetchall()
    cursor.close()

    corrections = []
    for row in rows:
        effective_time = row[1]
        # Convert datetime to milliseconds for consistent sorting with orders
        effective_time_ms = int(effective_time.timestamp() * 1000)

        corrections.append({
            'type': 'correction',
            'symbol': row[0],
            'effective_time': effective_time,
            'effective_time_ms': effective_time_ms,
            'qty_delta': Decimal(str(row[2])) if row[2] else Decimal('0'),
            'price': Decimal(str(row[3])) if row[3] else None,
            'include_in_waep': bool(row[4])
        })

    return corrections
```

**Location**: Add near line 230 in `refresh_order_leg_hist.py` (after `get_last_position_state`)

### Step 2: Merge corrections into the order stream

Before the main processing loop, merge corrections with orders and sort chronologically.

```python
# After fetching all orders (around line 1283), add:

# Fetch spot balance corrections for position tracking
spot_corrections = fetch_spot_corrections_for_position_tracking(
    conn,
    account_name=account_name,
    symbol=args.symbol,
    since=since_date if lookback_days else None
)
logger.info(f"Loaded {len(spot_corrections)} spot balance corrections for position tracking")

# Create unified event stream: orders + corrections
# Orders use (category, order_dict), corrections use ('correction', correction_dict)
all_events = []

for category, order in all_orders:
    order_time_ms = int(order.get('updatedTime', order.get('createdTime', 0)))
    all_events.append({
        'type': 'order',
        'time_ms': order_time_ms,
        'category': category,
        'data': order
    })

for correction in spot_corrections:
    all_events.append({
        'type': 'correction',
        'time_ms': correction['effective_time_ms'],
        'category': 'spot',
        'data': correction
    })

# Sort by timestamp
all_events.sort(key=lambda x: x['time_ms'])
logger.info(f"Processing {len(all_events)} events ({len(all_orders)} orders + {len(spot_corrections)} corrections)")
```

### Step 3: Handle correction events in the main loop

Modify the main processing loop to handle both orders and corrections.

```python
for event in all_events:
    if event['type'] == 'correction':
        # Apply correction to historical position tracking
        correction = event['data']
        symbol = correction['symbol']
        pos_key = (symbol, 'spot')  # Corrections are always spot

        qty_delta = correction['qty_delta']
        price = correction['price']
        include_in_waep = correction['include_in_waep']

        # Get or create position state
        current_position = historical_positions.get(pos_key)

        if current_position is None:
            # Create new position from correction
            if qty_delta > 0:
                new_position = PositionState(
                    side='long',
                    size=abs(qty_delta),
                    waep=price if include_in_waep and price else Decimal('0'),
                    exit_qty_sum=Decimal('0'),
                    exit_notional_sum=Decimal('0')
                )
            else:
                # Negative correction without existing position - unusual but handle it
                new_position = None
        else:
            # Apply correction to existing position
            new_size = current_position.size + qty_delta

            if new_size <= Decimal('0.000001'):
                # Position closed by correction
                new_position = None
            else:
                # Update WAEP if include_in_waep
                if include_in_waep and price and qty_delta > 0:
                    # Weighted average: (old_size * old_waep + new_qty * new_price) / new_size
                    old_notional = current_position.size * current_position.waep
                    new_notional = abs(qty_delta) * price
                    new_waep = (old_notional + new_notional) / new_size
                else:
                    new_waep = current_position.waep

                new_position = PositionState(
                    side='long',  # Spot is always long
                    size=new_size,
                    waep=new_waep,
                    exit_qty_sum=current_position.exit_qty_sum,
                    exit_notional_sum=current_position.exit_notional_sum
                )

        # Update tracking
        if new_position:
            historical_positions[pos_key] = new_position
            classifier.positions_map[symbol] = {
                'side': new_position.side,
                'size': new_position.size,
                'entryPrice': new_position.waep
            }
            logger.debug(f"Applied correction for {symbol}: qty_delta={qty_delta:+.8f}, new_size={new_position.size}")
        else:
            if pos_key in historical_positions:
                del historical_positions[pos_key]
            if symbol in classifier.positions_map:
                del classifier.positions_map[symbol]
            logger.debug(f"Applied correction for {symbol}: qty_delta={qty_delta:+.8f}, position closed")

        continue  # Don't create a leg record for corrections

    # Existing order processing logic continues here...
    category = event['category']
    order = event['data']
    symbol = order.get('symbol')
    # ... rest of existing logic
```

### Step 4: Update the main loop structure

The existing loop iterates over `all_orders`. Change it to iterate over `all_events`:

**Before:**
```python
for category, order in all_orders:
    symbol = order.get('symbol')
    ...
```

**After:**
```python
for event in all_events:
    if event['type'] == 'correction':
        # Handle correction (Step 3 code)
        continue

    # Handle order
    category = event['category']
    order = event['data']
    symbol = order.get('symbol')
    ...
```

## File Changes Summary

| File | Changes |
|------|---------|
| `bin/pipeline/refresh_order_leg_hist.py` | Add `fetch_spot_corrections_for_position_tracking()`, modify main loop |

## Testing Plan

1. **Unit test**: Create test case with known corrections and orders
   - Correction: +2.0 ETH @ July 1
   - Buy: +0.5 ETH @ Oct 1
   - Sell: -2.5 ETH @ Oct 15
   - Expected: Sell should be classified as 'tp' (closing long), not 'entry'

2. **Integration test**: Run with ETHUSDT
   ```bash
   ./bin/pipeline/refresh_order_leg_hist.py --symbol ETHUSDT --category spot --reload --debug
   ```
   - Verify correction is loaded
   - Verify position state is correct before each order classification
   - Verify all sells are classified as 'tp' (not 'entry')

3. **Full pipeline test**:
   ```bash
   ./bin/pipeline/run_pipeline.sh --symbol ETHUSDT --category spot --purge --account bybit_main --days 0
   ```
   - Verify trade journal shows correct status (CLOSED)
   - Verify no misclassified legs

## Edge Cases to Handle

1. **Correction before any orders**: Position starts from correction
2. **Negative correction**: Reduces existing position (e.g., sold outside TradeLens)
3. **Multiple corrections for same symbol**: Apply in chronological order
4. **Correction closes position entirely**: Clear position state
5. **Correction with include_in_waep=0**: Adjust size but not WAEP

## Rollback Plan

The enhancement is additive - it only affects position tracking during classification. If issues arise:
1. Remove the correction fetching and merging code
2. The classifier will revert to order-only position tracking
3. Existing leg_type immutability will preserve correct classifications

## Future Considerations

1. **Inverse/Linear corrections**: Currently only spot corrections exist. If needed for futures, extend the correction table and logic.

2. **Performance**: For large accounts with many corrections, consider caching or batch processing.

3. **Audit logging**: Consider logging when a correction affects classification outcome.
