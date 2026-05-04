# Bybit JSON Executor - Usage Guide

The `bybit_json_executor.py` script allows you to test Bybit API requests directly from JSON files. This is particularly useful for experimenting with different order configurations (especially stop-loss orders) before implementing them in the main codebase.

## Quick Start

```bash
cd /app/syb/tradesuite/tradelens

# 1. Dry-run to preview (recommended first step)
./bin/bybit_json_executor.py --dry-run examples/stop_loss_closeOnTrigger.json

# 2. Execute on testnet
./bin/bybit_json_executor.py examples/stop_loss_closeOnTrigger.json

# 3. Execute on production (BE CAREFUL!)
./bin/bybit_json_executor.py --env prod examples/stop_loss_closeOnTrigger.json
```

## Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--dry-run` | Preview without executing | `--dry-run order.json` |
| `--env` | Override environment (testnet/prod) | `--env prod order.json` |
| `--endpoint` | Use custom API endpoint | `--endpoint /v5/position/trading-stop` |
| `--skip-validation` | Skip parameter validation | `--skip-validation custom.json` |
| `--no-color` | Disable colored output | `--no-color order.json` |

## JSON File Format

### Standard Order (Entry/DCA)

```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Buy",
  "orderType": "Limit",
  "qty": "0.1",
  "price": "3500.0",
  "timeInForce": "GTC",
  "positionIdx": 1
}
```

### Stop-Loss Order (Conditional Order)

```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Sell",
  "orderType": "Market",
  "qty": "0.05",
  "triggerPrice": "3000.0",
  "triggerDirection": 2,
  "orderFilter": "StopOrder",
  "positionIdx": 1,
  "reduceOnly": true,
  "closeOnTrigger": true
}
```

**Key Parameters:**
- `triggerPrice`: Price that triggers the stop-loss
- `triggerDirection`: `1` = rising to trigger, `2` = falling to trigger
- `orderFilter`: `"StopOrder"` for stop-loss orders
- `reduceOnly`: `true` to only reduce position
- `closeOnTrigger`: `true` to close entire position (supposedly)

### Position-Level Stop-Loss

Using the `/v5/position/trading-stop` endpoint:

```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "positionIdx": 1,
  "stopLoss": "3000.0"
}
```

**Execute with:**
```bash
./bin/bybit_json_executor.py --endpoint /v5/position/trading-stop examples/position_sl.json
```

## Testing Stop-Loss Configurations

### Problem: Stop-Loss Not Closing Entire Position

When you scale into a position (add more contracts), a stop-loss with fixed `qty` will only close the original quantity. We need to find the right configuration to close the entire position.

### Configurations to Test

Create different JSON files to test:

#### 1. Fixed Quantity + closeOnTrigger
**Status:** ❌ Tested - Does NOT work

```json
{
  "qty": "0.05",
  "closeOnTrigger": true,
  "reduceOnly": true
}
```

#### 2. No Quantity + closeOnTrigger
**Status:** ❓ Not tested yet

```json
{
  "closeOnTrigger": true,
  "reduceOnly": true
}
```

**Hypothesis:** Bybit might interpret missing `qty` + `closeOnTrigger` as "close entire position"

#### 3. Zero Quantity + closeOnTrigger
**Status:** ❓ Not tested yet

```json
{
  "qty": "0",
  "closeOnTrigger": true,
  "reduceOnly": true
}
```

#### 4. Position-Level Stop-Loss
**Status:** ❓ Not tested yet

Use `/v5/position/trading-stop` endpoint instead of conditional orders.

```bash
./bin/bybit_json_executor.py --endpoint /v5/position/trading-stop examples/position_sl.json
```

**Hypothesis:** Position-level SL might automatically adjust to the current position size.

#### 5. Without reduceOnly
**Status:** ❓ Not tested yet

```json
{
  "qty": "0.05",
  "closeOnTrigger": true
}
```

**Hypothesis:** Maybe `reduceOnly` conflicts with `closeOnTrigger`.

#### 6. Different orderFilter
**Status:** ❓ Not tested yet

```json
{
  "orderFilter": "tpslOrder",
  "closeOnTrigger": true
}
```

### Testing Workflow

1. **Create JSON file** with the configuration you want to test
2. **Dry-run first** to validate the JSON structure:
   ```bash
   ./bin/bybit_json_executor.py --dry-run test.json
   ```
3. **Execute on testnet** with a small position:
   ```bash
   ./bin/bybit_json_executor.py test.json
   ```
4. **Scale the position** manually on Bybit (add more contracts)
5. **Trigger the stop-loss** by adjusting price or waiting for market movement
6. **Observe behavior**:
   - Did it close the entire position?
   - Or only the original quantity?
7. **Document results** in `README.md` table
8. **Try next configuration** if it didn't work

## Advanced Usage

### Multiple Orders in One File

Execute multiple orders sequentially:

```json
[
  {
    "category": "linear",
    "symbol": "BTCUSDT",
    "side": "Buy",
    "orderType": "Market",
    "qty": "0.001"
  },
  {
    "category": "linear",
    "symbol": "ETHUSDT",
    "side": "Buy",
    "orderType": "Market",
    "qty": "0.01"
  }
]
```

### Read from stdin

```bash
cat order.json | ./bin/bybit_json_executor.py
```

Or inline:

```bash
echo '{"category":"linear","symbol":"BTCUSDT","side":"Buy","orderType":"Market","qty":"0.001"}' | ./bin/bybit_json_executor.py
```

### Skip Validation for Custom Tests

If you're testing parameters that don't pass validation:

```bash
./bin/bybit_json_executor.py --skip-validation --dry-run custom.json
```

## Output Interpretation

### Success Example

```
======================================================================
Executing Order
======================================================================

Request Parameters:
{
  "category": "linear",
  "symbol": "ETHUSDT",
  ...
}
✓ Order executed successfully!

Response:
{
  "orderId": "1234567890",
  "orderLinkId": "abc123"
}

Order ID: 1234567890
```

### Error Example

```
✗ Order execution failed: Bybit API error: insufficient balance

Response:
{
  "retCode": 10001,
  "retMsg": "insufficient balance"
}
```

## Safety Tips

1. **Always use --dry-run first** to preview what will be sent
2. **Test on testnet** before production
3. **Use small quantities** for testing
4. **Double-check the environment** (testnet vs prod)
5. **Verify credentials** are for the correct environment
6. **Don't test with real money** until you're confident

## Troubleshooting

### "Bybit API credentials not configured"

Set your API credentials:

```bash
export BYBIT_API_KEY='your_key'
export BYBIT_API_SECRET='your_secret'
```

Or add them to `/app/syb/tradesuite/tradelens/etc/config.yml`:

```yaml
bybit:
  api_key: "your_key"
  api_secret: "your_secret"
```

### "Validation errors"

Check that your JSON has all required fields:
- Order creation: `category`, `symbol`, `side`, `orderType`
- Position stop: `category`, `symbol`, `stopLoss` or `takeProfit`

Or use `--skip-validation` to bypass validation.

### "Failed to connect to database"

This script doesn't use the database - you can ignore any database connection warnings.

### Wrong environment (testnet vs prod)

Check the output header:
```
ℹ Environment: testnet
```

Override with `--env`:
```bash
./bin/bybit_json_executor.py --env prod order.json
```

## Next Steps

Once you find the correct stop-loss configuration:

1. **Document the working configuration** in `README.md`
2. **Update the main codebase** (`tradelens/lib/tradelens/api/trades.py`)
3. **Test in the Smart Trade interface**
4. **Verify on Bybit** that it works as expected
5. **Update this documentation** with the solution

## Reference

- **Bybit V5 API Docs**: https://bybit-exchange.github.io/docs/v5/intro
- **Order Creation**: https://bybit-exchange.github.io/docs/v5/order/create-order
- **Position Trading Stop**: https://bybit-exchange.github.io/docs/v5/position/trading-stop
- **Conditional Orders**: https://bybit-exchange.github.io/docs/v5/order/stop-order
