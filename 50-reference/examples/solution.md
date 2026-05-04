# Stop-Loss Solution: Close Entire Position

## Problem
When scaling into a position (adding more contracts after initial entry), the stop-loss order with a fixed quantity would only close the original quantity, not the entire position.

**Example:**
- Initial position: 0.05 ETH with stop-loss
- Manually added: 0.05 ETH (total position: 0.10 ETH)
- Stop-loss triggered: Only closed 0.05 ETH (left 0.05 ETH open)

## Solution
Use `qty: "0"` with `closeOnTrigger: true` in the stop-loss order parameters.

### Working Configuration

```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Sell",
  "orderType": "Market",
  "qty": "0",
  "triggerPrice": "3000.0",
  "triggerDirection": 2,
  "orderFilter": "StopOrder",
  "positionIdx": 1,
  "reduceOnly": true,
  "closeOnTrigger": true
}
```

**Key Parameters:**
- `qty: "0"` - Special value that means "close entire position"
- `closeOnTrigger: true` - Required to make qty="0" work
- `reduceOnly: true` - Safety flag to prevent opening new positions
- `orderFilter: "StopOrder"` - Identifies this as a stop-loss order

## Testing Results

### Configuration Tested

| Configuration | Result | Notes |
|---------------|--------|-------|
| Fixed qty + closeOnTrigger | ❌ Failed | Only closes specified qty |
| **qty="0" + closeOnTrigger** | **✅ Success** | **Closes entire position** |

### Test Process
1. Created test JSON files with different configurations
2. Used `bybit_json_executor.py` to test on Bybit testnet
3. Placed initial 0.05 ETH position
4. Manually scaled position by adding more contracts
5. Triggered stop-loss by adjusting price
6. Observed that `qty="0"` configuration closed **entire position**

## Implementation

### Files Modified

1. **`/app/syb/tradesuite/tradelens/lib/tradelens/api/trades.py`**
   - Updated `submit_trade()` function (line ~433)
   - Updated `preview_bybit_orders()` function (line ~596)
   - Changed from `"qty": str(preview_response['computed_qty'])` to `"qty": "0"`

### Code Changes

**Before:**
```python
sl_params = {
    "qty": str(preview_response['computed_qty']),  # Fixed quantity
    "closeOnTrigger": True
}
```

**After:**
```python
sl_params = {
    "qty": "0",  # qty="0" + closeOnTrigger closes entire position
    "closeOnTrigger": True
}
```

## Backend Restart Required

After making the code changes, restart the TradeLens backend:

```bash
cd /app/syb/tradesuite/tradelens
pkill -f "uvicorn tradelens.main:app"
./bin/start_trade_dashboard.sh
```

Or start manually:
```bash
cd /app/syb/tradesuite/tradelens
source /app/syb/tradesuite/sourceme.sh
uvicorn tradelens.main:app --host 0.0.0.0 --port 8088 --log-level info
```

## Verification

### 1. Test in Smart Trade UI

1. Open Smart Trade interface: http://localhost:3000/smart-trade
2. Create a new trade with stop-loss
3. Click "View Bybit JSON"
4. Verify stop-loss order shows `"qty": "0"`
5. Submit the trade
6. Check Bybit to confirm stop-loss order is placed

### 2. Test JSON Preview

```bash
curl -X POST http://localhost:8088/trades/preview-bybit-orders \
  -H "Content-Type: application/json" \
  -d '{"preview_id": "your_preview_id"}'
```

Look for stop-loss order with:
```json
{
  "leg_type": "stop",
  "params": {
    "qty": "0",
    "closeOnTrigger": true,
    ...
  }
}
```

### 3. Test on Bybit

1. Place a small test trade with stop-loss
2. Manually scale into the position (add more contracts)
3. Wait for stop-loss to trigger (or adjust price to trigger it)
4. Verify **entire position** is closed, not just original quantity

## Why This Works

According to Bybit's API behavior (discovered through testing):
- `qty: "0"` is a special value interpreted as "close entire position"
- `closeOnTrigger: true` enables this special behavior
- The combination works for conditional orders (stop-loss/take-profit)
- The order dynamically adjusts to the current position size when triggered

## Alternative Approaches (Not Needed)

These alternatives were considered but not needed since `qty="0"` works:

1. **Position-level Stop-Loss** (`/v5/position/trading-stop`)
   - More complex to manage
   - Requires updating when position size changes
   - Not tested since qty="0" works

2. **Omitting qty parameter entirely**
   - Not tested - might fail validation

3. **Removing reduceOnly flag**
   - Not tested - could be unsafe

## Related Tools

### Bybit JSON Executor Script
Created `/app/syb/tradesuite/tradelens/bin/bybit_json_executor.py` for testing:

```bash
# Test configurations
./bin/bybit_json_executor.py --dry-run examples/stop_loss_zero_qty.json

# Execute on testnet
./bin/bybit_json_executor.py examples/stop_loss_zero_qty.json

# Execute on production
./bin/bybit_json_executor.py --env prod examples/stop_loss_zero_qty.json
```

This tool was instrumental in discovering the `qty="0"` solution.

## Documentation

See also:
- `examples/README.md` - Test results and available configurations
- `examples/USAGE.md` - Detailed usage guide for JSON executor
- `examples/stop_loss_zero_qty.json` - Working configuration example

## Date
Solution confirmed: 2025-10-13

## Status
✅ **SOLVED** - Implemented and tested successfully
