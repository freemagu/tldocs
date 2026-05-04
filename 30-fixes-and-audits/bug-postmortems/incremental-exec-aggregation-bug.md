# Incremental Execution Aggregation Bug - Detailed Analysis

## Executive Summary

A bug in the `refresh_order_leg_hist.py` pipeline causes some spot orders to be recorded with incorrect quantities. When an order is filled via multiple executions that span a cache timestamp boundary, only partial executions are fetched, resulting in incorrect `qty` values in the `order_leg_hist` table. This causes downstream issues in trade journal calculations, showing trades as "open" when they're actually closed.

---

## 1. Symptom Discovery

### 1.1 User Report
User reported that a MAGICUSDT trade was showing as "Open" in the Trade Journal despite all MAGIC having been sold on the exchange.

### 1.2 Observed Data in Trade Journal UI

| Side | Status | Qty | Entry | rPnL |
|------|--------|-----|-------|------|
| long | **Open** | 16054.2300 | 0.14 | -251.86 |

The Order Legs table showed:

| Side | Type | Price | Qty | Pos Size | Status |
|------|------|-------|-----|----------|--------|
| buy | entry | 0.14 | 15000.0000 | 15000.0000 | filled |
| buy | dca | 0.13 | 1000.0000 | 16000.0000 | filled |
| sell | TL | 0.12 | 14985.0000 | 1015.0000 | filled |
| sell | TL | 0.11 | 499.5000 | 515.5000 | filled |
| sell | entry | 0.11 | **70.2300** | 70.2300 | filled |

**Problem**: The last sell shows only 70.23 MAGIC, but it should be 499.5 MAGIC.

---

## 2. Database Investigation

### 2.1 Tables Involved

| Table | Purpose |
|-------|---------|
| `order_leg_hist` | Historical order legs (filled orders) |
| `trade_journal` | Aggregated trade sessions |
| `spot_position_live` | Current spot positions from exchange |

### 2.2 order_leg_hist Schema (Relevant Columns)

```sql
CREATE TABLE order_leg_hist (
    id                    NUMERIC(18,0) IDENTITY,
    account_id            INT NOT NULL,
    symbol                VARCHAR(32) NOT NULL,
    action                VARCHAR(4) NOT NULL,      -- 'buy' or 'sell'
    exchange_order_id     VARCHAR(64) NOT NULL,     -- Bybit order ID
    leg_type              VARCHAR(16) NOT NULL,     -- 'entry', 'dca', 'close_loss', etc.
    order_kind            VARCHAR(16) NOT NULL,     -- 'limit', 'market'
    price                 NUMERIC(38,10),
    qty                   NUMERIC(38,10) NOT NULL,  -- ← THE PROBLEM COLUMN
    status                VARCHAR(32) NOT NULL,
    category              VARCHAR(16) NOT NULL,     -- 'spot', 'linear', 'inverse'
    exchange_created_at   BIGDATETIME,
    exchange_filled_at    BIGDATETIME,
    ...
)
```

### 2.3 Database Query - MAGICUSDT Orders

```sql
SELECT id, symbol, action, leg_type, exchange_order_id, price, qty,
       exchange_created_at, exchange_filled_at
FROM order_leg_hist
WHERE symbol = 'MAGICUSDT'
ORDER BY exchange_filled_at
```

**Results:**

| id | action | leg_type | exchange_order_id | qty | exchange_filled_at |
|----|--------|----------|-------------------|-----|-------------------|
| 500000000024624 | buy | entry | ... | 15000.00 | Oct 13 2025 9:57:20 |
| 500000000024702 | buy | dca | ... | 1000.00 | Oct 17 2025 8:20:05 |
| 500000000024811 | sell | close_loss | 2060660697263774208 | 14985.00 | Nov 03 2025 3:27:24 |
| 500000000024929 | sell | close_loss | **2093681087955081728** | **499.50** | Dec 08 2025 10:08:10 |
| 500000000024928 | sell | entry | **2093682913207130624** | **70.23** | Dec 08 2025 10:08:33 |

**Key Finding**: Order `2093682913207130624` shows `qty=70.23` but should be `499.50`.

### 2.4 Position Calculation

```
Total Bought:  15000 + 1000 = 16000 MAGIC
Total Sold:    14985 + 499.5 + 70.23 = 15554.73 MAGIC
Remaining:     16000 - 15554.73 = 445.27 MAGIC (INCORRECT)
```

**Actual remaining on exchange**: 0 MAGIC (verified via API)

---

## 3. Exchange API Investigation

### 3.1 Bybit Execution API Response

Queried Bybit `/v5/execution/list` for MAGICUSDT:

```json
{
  "list": [
    {
      "orderId": "2093682913207130624",
      "orderQty": "499.5",
      "execQty": "70.23",
      "execPrice": "0.1125",
      "execTime": "1765231713489",
      "leavesQty": "0"
    },
    {
      "orderId": "2093682913207130624",
      "orderQty": "499.5",
      "execQty": "111.77",
      "execPrice": "0.1125",
      "execTime": "1765231713485",
      "leavesQty": "70.23"
    },
    {
      "orderId": "2093682913207130624",
      "orderQty": "499.5",
      "execQty": "111.79",
      "execPrice": "0.1125",
      "execTime": "1765231713485",
      "leavesQty": "182"
    },
    {
      "orderId": "2093682913207130624",
      "orderQty": "499.5",
      "execQty": "111.79",
      "execPrice": "0.1125",
      "execTime": "1765231713485",
      "leavesQty": "293.79"
    },
    {
      "orderId": "2093682913207130624",
      "orderQty": "499.5",
      "execQty": "93.92",
      "execPrice": "0.1125",
      "execTime": "1765231713461",
      "leavesQty": "405.58"
    }
  ]
}
```

### 3.2 Execution Timeline

| execTime (ms) | execTime (UTC) | execQty | leavesQty | Cumulative |
|---------------|----------------|---------|-----------|------------|
| 1765231713461 | 22:08:33.461 | 93.92 | 405.58 | 93.92 |
| 1765231713485 | 22:08:33.485 | 111.79 | 293.79 | 205.71 |
| 1765231713485 | 22:08:33.485 | 111.79 | 182.00 | 317.50 |
| 1765231713485 | 22:08:33.485 | 111.77 | 70.23 | 429.27 |
| 1765231713489 | 22:08:33.489 | 70.23 | 0.00 | **499.50** |

**Key Finding**: Order was split into 5 executions within **28 milliseconds**.

### 3.3 Bybit Order History API Response

```json
{
  "orderId": "2093682913207130624",
  "qty": "499.50",
  "cumExecQty": "499.5",
  "leavesQty": "0",
  "orderStatus": "Filled"
}
```

The Order History API correctly shows `qty=499.50`, but this API has short retention (~7 days).

---

## 4. Code Analysis

### 4.1 File: `bin/pipeline/refresh_order_leg_hist.py`

#### 4.1.1 Incremental Loading Logic (Lines 146-209)

```python
def get_last_order_time(conn, symbol, category, account_id, account_name):
    """Get the most recent order timestamp for incremental loading."""

    # For global queries, use JSON cache file
    if not symbol:
        cache_timestamp = load_global_cache(category, account_name)
        if cache_timestamp:
            return cache_timestamp + 1  # ← Add 1ms to avoid refetch

    # For symbol-specific, query database
    sql = """
    SELECT MAX(
        CASE
            WHEN exchange_filled_at > exchange_created_at THEN exchange_filled_at
            ELSE exchange_created_at
        END
    ) as max_time
    FROM order_leg_hist
    WHERE symbol = ? AND category = ? AND account_id = ?
    """
    # Returns timestamp + 1ms
```

#### 4.1.2 Spot Execution Fetch (Lines 1137-1146)

```python
aggregated_spot_orders = fetch_spot_executions(
    bybit=bybit,
    symbol=args.symbol,
    start_time_ms=start_time_ms,  # ← FROM cache timestamp + 1ms
    end_time_ms=end_time_ms,
    limit=100,
    aggregate=True,  # ← Should aggregate executions by orderId
    debug=debug_enabled
)
```

### 4.2 File: `lib/tradelens/utils/execution_aggregator.py`

#### 4.2.1 Aggregation Logic (Lines 34-139)

```python
def aggregate_spot_executions(executions):
    """Aggregate spot executions by orderId."""

    # Group executions by orderId
    orders_map = defaultdict(list)
    for execution in executions:
        order_id = execution.get('orderId')
        orders_map[order_id].append(execution)

    aggregated = []
    for order_id, execs in orders_map.items():
        if len(execs) == 1:
            # Single execution - pass through
            single_exec = execs[0].copy()
            single_exec['_execution_count'] = 1
            aggregated.append(single_exec)
            continue

        # Multiple executions - aggregate
        execs_sorted = sorted(execs, key=lambda e: int(e.get('execTime', 0)))

        total_qty = Decimal('0')
        for exec_item in execs_sorted:
            qty = Decimal(str(exec_item.get('execQty', 0)))
            total_qty += qty  # ← Sum all execQty values

        # Use first execution as template
        first_exec = execs_sorted[0]
        aggregated_order = first_exec.copy()
        aggregated_order['execQty'] = str(total_qty)  # ← Store aggregated qty
        aggregated_order['execTime'] = first_exec.get('execTime')  # ← Use FIRST exec time
        aggregated_order['_execution_count'] = len(execs)

        aggregated.append(aggregated_order)

    return aggregated
```

### 4.3 File: `bin/pipeline/refresh_order_leg_hist.py`

#### 4.3.1 Execution to Order Conversion (Lines 473-511)

```python
def convert_execution_to_order_format(execution):
    """Convert a Bybit execution to order format."""
    return {
        'symbol': execution.get('symbol'),
        'orderId': execution.get('orderId'),
        'price': execution.get('execPrice'),
        'qty': execution.get('execQty'),  # ← Uses execQty (aggregated or single)
        'orderQty': execution.get('orderQty', execution.get('execQty')),
        'leavesQty': execution.get('leavesQty', '0'),
        'execQty': execution.get('execQty', '0'),
        'createdTime': execution.get('execTime'),  # ← Uses execTime
        '_execution_count': execution.get('_execution_count', 1),
        ...
    }
```

---

## 5. Root Cause Analysis

### 5.1 The Bug Scenario

**Timeline of events:**

1. **Dec 8, 22:08:10.915 UTC**: Order `2093681087955081728` fills (499.5 MAGIC @ 0.1111)
2. **Script runs**: Fetches this order, inserts into DB
3. **Cache updated**: `last_order_time_ms = 1765231690915` (22:08:10.915)

4. **Dec 8, 22:08:33.461-489 UTC**: Order `2093682913207130624` fills in 5 executions:
   - 22:08:33.461 - 93.92 MAGIC
   - 22:08:33.485 - 111.79 MAGIC
   - 22:08:33.485 - 111.79 MAGIC
   - 22:08:33.485 - 111.77 MAGIC
   - 22:08:33.489 - 70.23 MAGIC

5. **Script runs again**:
   - `start_time_ms = 1765231690916` (cache + 1ms)
   - Bybit API returns executions **after** this time
   - **All 5 executions should be returned** (they're all after 22:08:10.916)

6. **BUT**: Due to some timing issue (API latency, pagination, or race condition), only the **last execution** (70.23 at 22:08:33.489) is fetched

7. **Single execution = no aggregation**: The aggregator passes through single executions unchanged

8. **INSERT**: Record created with `qty=70.23`, `exchange_created_at=22:08:33.489`

### 5.2 Evidence Supporting This Theory

**Database internal IDs reveal insertion order:**

| id | exchange_order_id | qty | exchange_filled_at |
|----|-------------------|-----|-------------------|
| 500000000024928 | 2093682913207130624 | 70.23 | 22:08:33.489 |
| 500000000024929 | 2093681087955081728 | 499.50 | 22:08:10.915 |

**Critical observation**: Order 24928 was **inserted BEFORE** 24929, even though 24929 has an **earlier timestamp**.

This proves:
- Bybit API returned executions in **descending order** (newest first)
- Only the **last execution** (70.23 at ...489) was processed for order 24928
- If aggregation had worked, `exchange_created_at` would be **22:08:33.461** (first exec), not **22:08:33.489** (last exec)

### 5.3 Possible Causes

1. **API Pagination Issue**: Bybit API may have returned executions across multiple pages, and only the first page was processed

2. **Time Window Boundary**: The 7-day time window splitting in `fetch_executions()` may have cut off some executions

3. **Race Condition**: If the cache was updated mid-fetch, subsequent fetches might have a different `start_time_ms`

4. **Network/Timeout**: Some executions may have been lost due to network issues

### 5.4 Why Subsequent Runs Don't Fix It

Once a record exists in `order_leg_hist`:

1. `get_last_order_time()` returns `MAX(exchange_filled_at) + 1ms`
2. New fetches start **after** the existing record's timestamp
3. Older executions (that were missed) are **never re-fetched**
4. The UPDATE path uses whatever `qty` is in the current fetch (still wrong)

---

## 6. Impact Analysis

### 6.1 Affected Functionality

| Component | Impact |
|-----------|--------|
| `order_leg_hist.qty` | Incorrect quantities for affected orders |
| `trade_journal.status` | Trades incorrectly marked as "open" |
| `trade_journal.exit_qty_sum` | Incorrect exit totals |
| `trade_journal.realized_pnl` | Incorrect P&L calculations |
| Trade Journal UI | Misleading position information |
| Portfolio calculations | Position sizes may be wrong |

### 6.2 is_closed() Logic

```python
# trade_journal/refresh_trade_journal.py (Lines 351-374)
def is_closed(self) -> bool:
    """Check if position is fully closed (qty back to zero)."""
    if last_price and last_price > Decimal('0'):
        position_value = abs(self.running_qty) * last_price
        # Position is closed if remaining value < $1 USD
        is_closed = position_value < Decimal('1.0')
        return is_closed
```

For MAGICUSDT:
- Remaining qty: ~445 MAGIC (due to bug)
- Price: ~$0.11
- Value: ~$50 > $1
- Result: **incorrectly reports as "open"**

---

## 7. Recommendations

### 7.1 Immediate Fix: Re-fetch Affected Orders

```bash
# Re-fetch all MAGICUSDT spot orders
./bin/pipeline/refresh_order_leg_hist.py --symbol MAGICUSDT --category spot --reload

# Then refresh trade journal
./bin/pipeline/refresh_trade_journal.py --symbol MAGICUSDT
```

### 7.2 Code Fix Option A: Look-Back Buffer

**File**: `bin/pipeline/refresh_order_leg_hist.py`

**Change**: When calculating `start_time_ms`, subtract a buffer to catch split orders:

```python
def get_last_order_time(...):
    ...
    # Add buffer to catch split executions
    LOOKBACK_BUFFER_MS = 60000  # 60 seconds

    if timestamp_ms:
        # Look back 60 seconds to catch any split orders
        timestamp_ms = max(0, timestamp_ms - LOOKBACK_BUFFER_MS)

    return timestamp_ms
```

**Pros**: Simple, catches most edge cases
**Cons**: Re-fetches some data unnecessarily, may cause duplicate processing

### 7.3 Code Fix Option B: Use `orderQty` Instead of Summing `execQty`

**File**: `lib/tradelens/utils/execution_aggregator.py`

**Change**: Use the `orderQty` field from the execution API response:

```python
def aggregate_spot_executions(executions):
    ...
    for order_id, execs in orders_map.items():
        first_exec = execs_sorted[0]

        # Use orderQty from API instead of summing execQty
        order_qty = first_exec.get('orderQty')
        if order_qty:
            aggregated_order['execQty'] = str(order_qty)
        else:
            # Fallback to summing if orderQty not available
            total_qty = sum(Decimal(str(e.get('execQty', 0))) for e in execs_sorted)
            aggregated_order['execQty'] = str(total_qty)
```

**Pros**: Always correct if `orderQty` is present
**Cons**: Relies on Bybit always providing `orderQty`; doesn't work for partial fills

### 7.4 Code Fix Option C: Re-Aggregate on Update

**File**: `bin/pipeline/refresh_order_leg_hist.py`

**Change**: When updating an existing record, fetch ALL executions for that order:

```python
def upsert_historical_legs(legs, db, conn, account_id):
    for leg in legs:
        old_snapshot = get_existing_record(leg['exchange_order_id'])

        if old_snapshot:
            # Re-fetch all executions for this order
            all_executions = fetch_all_executions_for_order(
                order_id=leg['exchange_order_id'],
                category=leg['category']
            )

            # Re-aggregate
            if len(all_executions) > 1:
                aggregated = aggregate_spot_executions(all_executions)
                leg['qty'] = aggregated[0]['execQty']

        # Continue with upsert...
```

**Pros**: Self-healing, always gets correct data
**Cons**: Additional API calls, may hit rate limits

### 7.5 Code Fix Option D: Hybrid Approach (Recommended)

Combine options A and B:

1. **Use `orderQty`** when available (most reliable)
2. **Add look-back buffer** as safety net for edge cases
3. **Log warnings** when aggregated qty doesn't match `orderQty`

```python
# In aggregate_spot_executions():
order_qty = Decimal(str(first_exec.get('orderQty', 0)))
summed_qty = sum(Decimal(str(e.get('execQty', 0))) for e in execs_sorted)

if order_qty > 0:
    if summed_qty != order_qty:
        logger.warning(
            f"Qty mismatch for order {order_id}: "
            f"orderQty={order_qty}, summed={summed_qty}. "
            f"Using orderQty."
        )
    aggregated_order['execQty'] = str(order_qty)
else:
    aggregated_order['execQty'] = str(summed_qty)
```

---

## 8. Testing Recommendations

### 8.1 Unit Tests

```python
def test_aggregation_uses_order_qty():
    """Verify aggregation uses orderQty when available."""
    executions = [
        {'orderId': '123', 'execQty': '70.23', 'orderQty': '499.5', 'execTime': '1000'},
    ]
    result = aggregate_spot_executions(executions)
    assert result[0]['execQty'] == '499.5'

def test_aggregation_sums_correctly():
    """Verify aggregation sums multiple executions."""
    executions = [
        {'orderId': '123', 'execQty': '100', 'orderQty': '300', 'execTime': '1000'},
        {'orderId': '123', 'execQty': '100', 'orderQty': '300', 'execTime': '1001'},
        {'orderId': '123', 'execQty': '100', 'orderQty': '300', 'execTime': '1002'},
    ]
    result = aggregate_spot_executions(executions)
    assert result[0]['execQty'] == '300'  # Should match orderQty
```

### 8.2 Integration Tests

1. Create test order with multiple fills
2. Run pipeline with various `start_time_ms` values
3. Verify final `qty` matches exchange

---

## 9. Monitoring Recommendations

### 9.1 Add Validation Query

```sql
-- Find orders where DB qty doesn't match cumulative legs
SELECT
    olh.exchange_order_id,
    olh.symbol,
    olh.qty as db_qty,
    olh.exchange_filled_at
FROM order_leg_hist olh
WHERE olh.category = 'spot'
  AND olh.status = 'filled'
  -- Add check against known good data source
```

### 9.2 Add Logging

```python
# Log when single execution is processed (potential incomplete data)
if len(execs) == 1:
    logger.info(
        f"Single execution for order {order_id}: "
        f"execQty={execs[0].get('execQty')}, "
        f"orderQty={execs[0].get('orderQty')}"
    )
```

---

## 10. Appendix

### 10.1 Relevant Files

| File | Purpose |
|------|---------|
| `bin/pipeline/refresh_order_leg_hist.py` | Main pipeline script |
| `lib/tradelens/utils/execution_aggregator.py` | Execution aggregation logic |
| `lib/tradelens/utils/spot_execution_fetcher.py` | Bybit API fetching |
| `bin/pipeline/refresh_trade_journal.py` | Trade journal aggregation |

### 10.2 Cache File Location

```
/app/syb/tradesuite/tradelens/cache/global_order_hist_spot_bybit_main.json
```

Contents:
```json
{
  "account_name": "bybit_main",
  "last_order_time_ms": 1765555502142,
  "last_order_time_utc": "2025-12-12 16:05:02.142",
  "updated_at": "2025-12-12 16:05:54"
}
```

### 10.3 Bybit API Endpoints Used

| Endpoint | Purpose |
|----------|---------|
| `GET /v5/execution/list` | Fetch execution history |
| `GET /v5/order/history` | Fetch order history (short retention) |
| `GET /v5/account/wallet-balance` | Check current balances |

---

**Document Version**: 1.0
**Date**: 2025-12-14
**Author**: Claude Code Investigation
