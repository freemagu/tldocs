# Take Profit (TP) Order Guide

This guide explains how to structure take-profit orders for Bybit linear perpetuals.

## Long Position Take Profit

When you have a **long position** (bought ETHUSDT), you take profit by **selling**.

### Example: TP1 for Long ETHUSDT Position

```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Sell",           // Sell to close long position
  "orderType": "Limit",     // Limit order at specific price
  "qty": "0.05",            // Amount to close
  "price": "5000.0",        // TP price level
  "timeInForce": "GTC",     // Good Till Cancel
  "reduceOnly": true,       // Only close position, don't open new
  "positionIdx": 1          // Long position index
}
```

**Key Points:**
- `side: "Sell"` - Sell to close long position
- `positionIdx: 1` - Long positions use index 1
- `reduceOnly: true` - Safety flag to prevent opening short position
- `orderType: "Limit"` - Order waits at specific price

### Usage

```bash
# Dry-run
./bin/bybit_json_executor.py --dry-run examples/tp1_long_ethusdt.json

# Execute
./bin/bybit_json_executor.py examples/tp1_long_ethusdt.json
```

## Short Position Take Profit

When you have a **short position** (sold ETHUSDT), you take profit by **buying**.

### Example: TP1 for Short ETHUSDT Position

```json
{
  "category": "linear",
  "symbol": "ETHUSDT",
  "side": "Buy",            // Buy to close short position
  "orderType": "Limit",     // Limit order at specific price
  "qty": "0.05",            // Amount to close
  "price": "2500.0",        // TP price level
  "timeInForce": "GTC",     // Good Till Cancel
  "reduceOnly": true,       // Only close position, don't open new
  "positionIdx": 2          // Short position index
}
```

**Key Points:**
- `side: "Buy"` - Buy to close short position
- `positionIdx: 2` - Short positions use index 2
- `reduceOnly: true` - Safety flag to prevent opening long position
- `orderType: "Limit"` - Order waits at specific price

### Usage

```bash
# Dry-run
./bin/bybit_json_executor.py --dry-run examples/tp1_short_ethusdt.json

# Execute
./bin/bybit_json_executor.py examples/tp1_short_ethusdt.json
```

## Parameter Reference

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `category` | string | Product type | `"linear"` for USDT perpetuals |
| `symbol` | string | Trading pair | `"ETHUSDT"`, `"BTCUSDT"` |
| `side` | string | Order side | `"Buy"` or `"Sell"` |
| `orderType` | string | Order type | `"Limit"` or `"Market"` |
| `qty` | string | Order quantity | `"0.05"` (5% of 1 ETH) |

### Limit Order Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `price` | string | Limit price | `"5000.0"` |
| `timeInForce` | string | Time in force | `"GTC"`, `"IOC"`, `"FOK"` |

### Position Management

| Field | Type | Description | Values |
|-------|------|-------------|--------|
| `positionIdx` | int | Position index | `1` = long, `2` = short, `0` = one-way |
| `reduceOnly` | bool | Only close position | `true` (recommended for TP) |

### Time In Force Options

| Value | Description | Use Case |
|-------|-------------|----------|
| `GTC` | Good Till Cancel | Default - order stays until filled or canceled |
| `IOC` | Immediate Or Cancel | Fill immediately, cancel unfilled portion |
| `FOK` | Fill Or Kill | Fill entire order immediately or cancel all |

## Multiple Take Profit Levels

You can place multiple TP orders at different price levels:

### Example: TP1, TP2, TP3 for Long Position

```json
[
  {
    "category": "linear",
    "symbol": "ETHUSDT",
    "side": "Sell",
    "orderType": "Limit",
    "qty": "0.02",
    "price": "4500.0",
    "timeInForce": "GTC",
    "reduceOnly": true,
    "positionIdx": 1
  },
  {
    "category": "linear",
    "symbol": "ETHUSDT",
    "side": "Sell",
    "orderType": "Limit",
    "qty": "0.02",
    "price": "5000.0",
    "timeInForce": "GTC",
    "reduceOnly": true,
    "positionIdx": 1
  },
  {
    "category": "linear",
    "symbol": "ETHUSDT",
    "side": "Sell",
    "orderType": "Limit",
    "qty": "0.01",
    "price": "5500.0",
    "timeInForce": "GTC",
    "reduceOnly": true,
    "positionIdx": 1
  }
]
```

Save to `multiple_tp.json` and execute:

```bash
./bin/bybit_json_executor.py --dry-run multiple_tp.json
```

## Position Index Reference

Bybit uses hedge mode by default for linear perpetuals:

| Position Type | positionIdx | Side to Open | Side to Close (TP) |
|---------------|-------------|--------------|-------------------|
| Long | 1 | Buy | Sell |
| Short | 2 | Sell | Buy |
| One-way mode | 0 | Buy/Sell | Opposite side |

**Important:** TradeLens uses hedge mode (`positionIdx: 1` for long, `2` for short).

## Quick Reference

### Long Position TP
```json
{
  "side": "Sell",        // ← Sell to take profit
  "positionIdx": 1       // ← Long position
}
```

### Short Position TP
```json
{
  "side": "Buy",         // ← Buy to take profit
  "positionIdx": 2       // ← Short position
}
```

## Common Mistakes

❌ **Wrong:** Using `"side": "Buy"` for long position TP
```json
{
  "side": "Buy",         // WRONG! This opens more long
  "positionIdx": 1
}
```

✅ **Correct:** Using `"side": "Sell"` for long position TP
```json
{
  "side": "Sell",        // Correct - closes long position
  "positionIdx": 1
}
```

---

❌ **Wrong:** Using wrong position index
```json
{
  "side": "Sell",
  "positionIdx": 2       // WRONG! This is for short positions
}
```

✅ **Correct:** Using correct position index
```json
{
  "side": "Sell",
  "positionIdx": 1       // Correct - long position
}
```

---

❌ **Wrong:** Not using `reduceOnly`
```json
{
  "side": "Sell",
  "reduceOnly": false    // WRONG! Could open short if long closes
}
```

✅ **Correct:** Using `reduceOnly: true`
```json
{
  "side": "Sell",
  "reduceOnly": true     // Correct - only closes position
}
```

## Testing

Always test with dry-run first:

```bash
# 1. Dry-run to validate JSON
./bin/bybit_json_executor.py --dry-run your_tp.json

# 2. Execute on testnet
./bin/bybit_json_executor.py your_tp.json

# 3. Verify on Bybit UI
# Check that TP orders appear correctly
```

## Related Documentation

- `SOLUTION.md` - Stop-loss solution (qty="0")
- `USAGE.md` - JSON executor usage guide
- `README.md` - Test results and configurations

## Bybit API Reference

- [Create Order](https://bybit-exchange.github.io/docs/v5/order/create-order)
- [Position Index](https://bybit-exchange.github.io/docs/v5/position/position-idx)
- [Reduce Only](https://bybit-exchange.github.io/docs/v5/order/order-type#reduce-only)
