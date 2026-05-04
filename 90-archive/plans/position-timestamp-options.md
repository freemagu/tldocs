# Position Timestamp Options

**Problem**: Bybit's position API returns `createdTime: "0"` for some positions (e.g., BTCUSDT), making it impossible to determine when the position was opened. The `updatedTime` field only shows the last modification time, not the position creation time.

**Current Situation**:
- BTCUSDT position opened "a few hours ago" (per user)
- `createdTime`: "0" (unavailable from Bybit)
- `updatedTime`: "1760659200015" (Oct 17 00:00) - last update, not open time
- Shows "N/A" for open time in portfolio viewer

---

## Option 1: Accept Limitation (Show N/A)

### Description
Simply accept that some positions don't have creation timestamps available from Bybit and display "N/A" for those positions.

### Implementation
- No code changes needed (current behavior)
- Already implemented

### Pros
✅ Simple, no additional complexity
✅ No extra API calls
✅ No performance impact

### Cons
❌ User doesn't know when position was opened
❌ Can't calculate accurate position duration
❌ Incomplete portfolio information

### Recommendation
**Not recommended** - Users need position open times for risk management and performance tracking.

---

## Option 2: Track Position Creation in Our Database

### Description
When we first detect a new position in our system, record the timestamp in a database table. Use this recorded timestamp for positions where Bybit's `createdTime` is unavailable.

### Implementation

#### Database Schema
```sql
CREATE TABLE position_timestamps (
    id              INT IDENTITY PRIMARY KEY,
    symbol          VARCHAR(50) NOT NULL,
    side            VARCHAR(10) NOT NULL,  -- 'Buy' or 'Sell'
    category        VARCHAR(20) NOT NULL,  -- 'linear', 'inverse', 'spot'
    first_seen_at   DATETIME NOT NULL,
    last_seen_at    DATETIME NOT NULL,
    status          VARCHAR(10) DEFAULT 'open',  -- 'open' or 'closed'
    UNIQUE (symbol, side, category, status)
)
```

#### Code Changes
In `portfolio.py`, add tracking logic:

```python
def track_position_first_seen(conn: Any, positions: List[Dict[str, Any]]) -> None:
    """
    Track when positions are first seen in our system.
    Update last_seen_at for existing positions.
    """
    cursor = conn.cursor()

    for pos in positions:
        symbol = pos['symbol']
        side = pos['side']
        kind = pos['kind']
        category = 'linear' if kind == 'futures_linear_usdt' else 'inverse' if kind == 'futures_inverse' else 'spot'

        # Check if we've seen this position before
        cursor.execute("""
            SELECT first_seen_at FROM position_timestamps
            WHERE symbol = %s AND side = %s AND category = %s AND status = 'open'
        """, (symbol, side, category))

        row = cursor.fetchone()

        if row:
            # Update last_seen_at
            cursor.execute("""
                UPDATE position_timestamps
                SET last_seen_at = getdate()
                WHERE symbol = %s AND side = %s AND category = %s AND status = 'open'
            """, (symbol, side, category))
        else:
            # First time seeing this position - record it
            cursor.execute("""
                INSERT INTO position_timestamps
                (symbol, side, category, first_seen_at, last_seen_at)
                VALUES (%s, %s, %s, getdate(), getdate())
            """, (symbol, side, category))

    conn.commit()

def get_position_timestamp_from_db(conn: Any, symbol: str, side: str, category: str) -> Optional[str]:
    """Get position first_seen timestamp from database"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT first_seen_at FROM position_timestamps
        WHERE symbol = %s AND side = %s AND category = %s AND status = 'open'
    """, (symbol, side, category))

    row = cursor.fetchone()
    if row and row[0]:
        return row[0].isoformat()
    return None
```

In `track_position_lifecycle()`:
```python
# First, track all positions
track_position_first_seen(conn, positions)

# Then enrich with timestamps
for position in positions:
    if not position.get('created_at_bybit'):
        # Fallback to database timestamp
        category = 'linear' if position['kind'] == 'futures_linear_usdt' else 'inverse'
        db_timestamp = get_position_timestamp_from_db(
            conn, position['symbol'], position['side'], category
        )
        position['created_at'] = db_timestamp
```

### Pros
✅ Simple to implement
✅ No additional external API calls
✅ Fast lookups (local database)
✅ Works for all future positions

### Cons
❌ **Only works for NEW positions** - won't help with existing BTCUSDT position
❌ Timestamp is "first time we saw it", not "when Bybit opened it"
❌ If our monitoring has downtime, we miss the actual open time
❌ Not accurate if position existed before we started tracking
❌ Adds database maintenance burden

### Recommendation
**Not recommended for this use case** - Won't solve the current BTCUSDT problem since the position already exists. Only helps with future positions, and timestamp accuracy depends on our monitoring uptime.

---

## Option 3: Use Order/Trade Execution History (RECOMMENDED)

### Description
Query Bybit's execution history API to find the first trade execution that opened the current position. Use the `execTime` from that trade as the position open time.

### API Endpoint
Bybit V5 API: `GET /v5/execution/list`

**Documentation**: https://bybit-exchange.github.io/docs/v5/order/execution

### How It Works

#### 1. API Response Format
Each execution record includes:
```json
{
  "symbol": "BTCUSDT",
  "execId": "7e8b7e6d-4c8e-5a7b-9e6f-3d4c5b6a7e8f",
  "execTime": "1729123456789",  // ← Execution timestamp in milliseconds
  "execPrice": "108500.50",
  "execQty": "0.1",
  "side": "Buy",
  "orderId": "abc123...",
  "orderType": "Market",
  "isMaker": false,
  "execFee": "10.85"
}
```

#### 2. Request Parameters
```
category      (required)  "linear", "inverse", "spot"
symbol        (optional)  "BTCUSDT"
startTime     (optional)  Start timestamp in milliseconds
endTime       (optional)  End timestamp in milliseconds
limit         (optional)  1-100, default 50
cursor        (optional)  For pagination
```

**Time Range Rules**:
- Neither provided: Returns 7 days of data by default
- Only startTime: Returns startTime to startTime+7 days
- Only endTime: Returns endTime-7 days to endTime
- Both provided: Maximum 7-day range

#### 3. Implementation

**Step A: No changes needed to `bybit_client.py`**

The existing `get_execution_list()` method (line 397-423) is already sufficient:

```python
def get_execution_list(
    self,
    category: str,
    symbol: Optional[str] = None,
    order_id: Optional[str] = None,
    limit: int = 50
) -> List[Dict[str, Any]]:
```

By default, when no time parameters are specified, Bybit returns the last 7 days of executions, which is sufficient for finding when a position was opened.

**Why no time parameters needed:**
- Default 7-day window covers most position ages
- We don't know the position open time (that's what we're finding!)
- For positions older than 7 days with `createdTime="0"`, execution history won't be available anyway
- YAGNI: Don't add complexity we don't need

**Step B: Add Helper Function in `portfolio.py`**

```python
def get_position_open_time_from_executions(
    bybit: BybitClient,
    symbol: str,
    side: str,
    category: str
) -> Optional[str]:
    """
    Find when the current position was opened by querying execution history.

    Strategy:
    1. Query recent executions for this symbol (last 7 days)
    2. Filter executions matching position side (Buy for Long, Sell for Short)
    3. Sort by execTime ascending (oldest first)
    4. Return the execTime of the first matching execution

    Args:
        bybit: Bybit client instance
        symbol: Trading symbol (e.g., "BTCUSDT")
        side: Position side ('Buy' or 'Sell')
        category: Product category ('linear', 'inverse')

    Returns:
        ISO datetime string of position open time, or None if not found
    """
    try:
        # Query executions for this symbol (default: last 7 days)
        executions = bybit.get_execution_list(
            category=category,
            symbol=symbol,
            limit=100  # Get enough results to find opening trade
        )

        if not executions:
            logger.warning(f"No execution history found for {symbol}")
            return None

        # Filter by matching side
        # For Long position (Buy side): look for Buy executions
        # For Short position (Sell side): look for Sell executions
        position_side = side.capitalize()  # Normalize to 'Buy' or 'Sell'

        matching_executions = [
            e for e in executions
            if e.get('side') == position_side
        ]

        if not matching_executions:
            logger.warning(f"No {position_side} executions found for {symbol}")
            return None

        # Sort by execTime ascending (oldest first)
        matching_executions.sort(key=lambda e: int(e.get('execTime', 0)))

        # The first execution opened the position
        first_execution = matching_executions[0]
        exec_time_ms = first_execution.get('execTime')

        if exec_time_ms:
            # Convert milliseconds to ISO datetime
            from datetime import datetime
            exec_time = datetime.utcfromtimestamp(int(exec_time_ms) / 1000).isoformat()
            logger.info(f"Found position open time from execution history: {symbol} {position_side} opened at {exec_time}")
            return exec_time

        return None

    except Exception as e:
        logger.error(f"Failed to get position open time from executions for {symbol}: {e}")
        return None
```

**Step C: Update `track_position_lifecycle()` in `portfolio.py`**

Around line 1220, update the futures position handling:

```python
for position in positions:
    if position['kind'] in ['futures_linear_usdt', 'futures_inverse']:
        created_at_bybit = position.get('created_at_bybit')

        # If createdTime is unavailable, query execution history
        if not created_at_bybit:
            logger.debug(f"createdTime unavailable for {position['symbol']}, querying execution history...")
            category = 'linear' if position['kind'] == 'futures_linear_usdt' else 'inverse'
            created_at_bybit = get_position_open_time_from_executions(
                bybit,
                position['symbol'],
                position['side'],
                category
            )

        position['created_at'] = created_at_bybit

    # ... rest of logic for spot positions
```

**Step D: Pass Bybit Client to `track_position_lifecycle()`**

Currently the function signature is:
```python
def track_position_lifecycle(conn: Any, positions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
```

Update to:
```python
def track_position_lifecycle(
    conn: Any,
    positions: List[Dict[str, Any]],
    bybit: Optional[BybitClient] = None  # NEW parameter
) -> List[Dict[str, Any]]:
```

And update the call site in `get_combined_portfolio()` (around line 1119):

```python
# Enrich positions with created_at timestamps
positions = track_position_lifecycle(conn, positions, bybit)  # Pass bybit client
```

### Example Flow for BTCUSDT

**Current State**:
- Position: BTCUSDT Long, size 0.423
- `createdTime`: "0" (unavailable)
- Open time: "N/A"

**With Execution History**:
1. Detect `createdTime == "0"`
2. Call: `bybit.get_execution_list(category="linear", symbol="BTCUSDT", limit=100)`
3. Get response with Buy executions:
   ```json
   [
     {"execTime": "1729084500000", "side": "Buy", "execQty": "0.2", ...},
     {"execTime": "1729098900000", "side": "Buy", "execQty": "0.123", ...},
     {"execTime": "1729112300000", "side": "Buy", "execQty": "0.1", ...}
   ]
   ```
4. Sort by `execTime` ascending → first is `"1729084500000"`
5. Convert: `datetime.utcfromtimestamp(1729084500)` → `"2025-10-16T14:15:00"`
6. Display: **Open Time: Oct 16 14:15** ✅

### Pros
✅ **Accurate timestamps**: Uses actual trade execution times from Bybit
✅ **Always available**: Execution history always has timestamps
✅ **Works for existing positions**: Solves current BTCUSDT problem
✅ **Minimal code changes**: Leverage existing `get_execution_list()` method
✅ **Historical data**: Can query up to 7 days back (enough for most positions)
✅ **Handles DCA entries**: First execution = true position open time

### Cons
⚠️ **Additional API call**: One extra request per position with missing `createdTime`
⚠️ **7-day limitation**: If position is older than 7 days AND has no `createdTime`, we can't find it
⚠️ **Performance**: Adds latency when fetching portfolio (mitigated by only calling when needed)
⚠️ **Rate limits**: Need to be mindful of Bybit API rate limits

### Mitigation Strategies

**For 7-day limitation**:
- Cache the discovered timestamp in database after first lookup
- Only positions older than 7 days with `createdTime="0"` will remain unknown
- These are rare edge cases

**For performance**:
- Only query execution history when `createdTime` is unavailable
- Most positions have valid `createdTime`, so minimal impact
- Consider caching results in database for subsequent calls

**For rate limits**:
- Bybit allows 120 requests/second for authenticated endpoints
- Typical portfolio has 5-10 positions, only 1-2 might need execution lookup
- Well within rate limits

### Recommendation
**✅ RECOMMENDED** - This is the best solution because:
1. **Solves the immediate problem**: Will find BTCUSDT's actual open time
2. **Uses authoritative data**: Bybit's execution records are the source of truth
3. **Works retroactively**: Finds open time for positions that already exist
4. **Minimal complexity**: Leverages existing API client infrastructure
5. **Good user experience**: Provides accurate timestamps for risk management

---

## Option 4: Hybrid Approach (Database Cache + Execution History)

### Description
Combine Options 2 and 3:
1. Use execution history to find accurate open time (like Option 3)
2. Cache the result in database to avoid repeated API calls (like Option 2)

### Implementation

Add `cached_open_time` column to existing tables or create cache table:

```sql
CREATE TABLE position_open_time_cache (
    symbol      VARCHAR(50) NOT NULL,
    side        VARCHAR(10) NOT NULL,
    category    VARCHAR(20) NOT NULL,
    open_time   DATETIME NOT NULL,
    cached_at   DATETIME DEFAULT getdate(),
    PRIMARY KEY (symbol, side, category)
)
```

Logic:
```python
def get_position_open_time_cached(
    conn: Any,
    bybit: BybitClient,
    symbol: str,
    side: str,
    category: str
) -> Optional[str]:
    """
    Get position open time with caching.
    1. Check cache first
    2. If not cached, query execution history
    3. Cache the result
    """
    # Check cache
    cursor = conn.cursor()
    cursor.execute("""
        SELECT open_time FROM position_open_time_cache
        WHERE symbol = %s AND side = %s AND category = %s
    """, (symbol, side, category))

    row = cursor.fetchone()
    if row and row[0]:
        logger.debug(f"Using cached open time for {symbol}")
        return row[0].isoformat()

    # Not cached - query execution history
    open_time_str = get_position_open_time_from_executions(bybit, symbol, side, category)

    if open_time_str:
        # Cache it
        from datetime import datetime
        open_time_dt = datetime.fromisoformat(open_time_str)
        cursor.execute("""
            INSERT INTO position_open_time_cache
            (symbol, side, category, open_time)
            VALUES (%s, %s, %s, %s)
        """, (symbol, side, category, open_time_dt))
        conn.commit()

    return open_time_str
```

### Pros
✅ All benefits of Option 3 (accurate, works for existing positions)
✅ Performance optimization (no repeated API calls)
✅ Resilient to Bybit API issues (uses cache if available)

### Cons
⚠️ Added complexity (database + API)
⚠️ Cache invalidation needed (if position closed and reopened)
⚠️ More code to maintain

### Recommendation
**Consider for production** - If performance becomes an issue with Option 3, this is a good enhancement. Start with Option 3, add caching later if needed.

---

## Final Recommendation

**Implement Option 3: Use Order/Trade Execution History**

### Reasons:
1. ✅ Solves the immediate BTCUSDT timestamp problem
2. ✅ Uses accurate, authoritative data from Bybit
3. ✅ Works for all existing and future positions
4. ✅ Minimal code changes (enhance existing method)
5. ✅ No database schema changes required
6. ✅ Good balance of accuracy vs complexity

### Next Steps:
1. Enhance `get_execution_list()` in `bybit_client.py` to support `start_time`/`end_time`
2. Add `get_position_open_time_from_executions()` helper in `portfolio.py`
3. Update `track_position_lifecycle()` to use execution history as fallback
4. Pass `bybit` client to `track_position_lifecycle()`
5. Test with BTCUSDT to verify correct open time is retrieved

### Future Enhancement:
If performance becomes an issue (many positions with missing `createdTime`), implement Option 4 (add database caching) as an optimization layer.

---

**Document Version**: 1.0
**Last Updated**: 2025-10-17
**Status**: Proposed - Pending User Approval
