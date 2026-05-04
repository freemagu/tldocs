# Spot Balance Corrections

## Overview

Spot Balance Corrections provide a way to adjust position quantities when historical order data is incomplete. This commonly occurs when:

- **Pre-TradeLens holdings** weren't imported (you held assets before the system was set up)
- **Orders fall outside the lookback window** (the system only imports X days of history)
- **External transfers/deposits** weren't recorded as trades

Without corrections, the trade journal may show positions as "OPEN" with negative running quantities, which is mathematically impossible for real trades.

## Problem Example

Consider ETHUSDT where the database shows:
- Total bought (net): 1.80819 ETH
- Total sold: 2.5088 ETH
- Running qty: -0.70058 ETH

The negative quantity means more ETH was sold than bought according to the database. In reality, you had ~0.7 ETH before TradeLens started tracking. Without a correction, the trade journal cannot properly close this position.

## Solution

Insert a correction row that represents the missing historical inventory:

```sql
INSERT INTO spot_balance_correction
    (account_id, symbol, effective_time, qty_delta, include_in_waep, reason, created_by)
VALUES
    ('bybit-main', 'ETHUSDT', '2024-03-26 21:17:25', 0.70058, 0,
     'Manual bootstrap for legacy spot holdings', 'fix_spot_balance.py')
```

The correction is applied at `effective_time` (just before the first recorded order), adding the missing quantity to the running total. When the trade journal sessionizes legs, it includes these synthetic "correction legs" in position calculations.

## Database Schema

### Table: spot_balance_correction

| Column | Type | Description |
|--------|------|-------------|
| correction_id | BIGINT IDENTITY | Primary key |
| account_id | VARCHAR(64) | Account name (e.g., 'bybit-main') |
| symbol | VARCHAR(32) | Trading pair (e.g., 'ETHUSDT') |
| effective_time | DATETIME | When this correction applies |
| qty_delta | NUMERIC(38,18) | Signed quantity (+ve = buy, -ve = sell) |
| price_for_pnl | NUMERIC(38,18) | Optional price for PnL calculation |
| include_in_waep | TINYINT | 0 = qty only, 1 = include in WAEP |
| reason | VARCHAR(255) | Human-readable explanation |
| created_at | DATETIME | When correction was created |
| created_by | VARCHAR(64) | Who/what created it |

## Using the Maintenance Script

### Basic Usage

```bash
# Preview what would happen (dry-run)
./bin/pipeline/fix_spot_balance.py \
    --account bybit-main \
    --symbol ETHUSDT \
    --missing-qty 0.70058 \
    --dry-run

# Apply the correction
./bin/pipeline/fix_spot_balance.py \
    --account bybit-main \
    --symbol ETHUSDT \
    --missing-qty 0.70058
```

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--account` | Yes | Account name from accounts.yml |
| `--symbol` | Yes | Symbol to correct (e.g., ETHUSDT) |
| `--missing-qty` | Yes | Quantity delta (+ve = buy adjustment) |
| `--effective-time` | No | When correction applies (default: 1s before earliest order) |
| `--include-in-waep` | No | Include in WAEP calculation (default: false) |
| `--price-for-pnl` | No | Price for PnL/WAEP (only with --include-in-waep) |
| `--reason` | No | Custom reason text |
| `--dry-run` | No | Preview without making changes |

### After Inserting a Correction

1. **Refresh the trade journal:**
   ```bash
   ./bin/pipeline/refresh_trade_journal.py --symbol ETHUSDT --reload
   ```

2. **Verify the fix:**
   ```bash
   ./bin/journal --symbol ETHUSDT
   ```

   The trade should now show as CLOSED with correct dates.

## How Corrections Work

### Position Calculation Flow

```
order_leg_hist          spot_balance_correction
     │                           │
     ▼                           ▼
 [real legs]               [correction legs]
     │                           │
     └─────────┬─────────────────┘
               │
               ▼
      Combined + sorted by time
               │
               ▼
      Sessionization algorithm
               │
               ▼
      running_qty tracks position
               │
               ▼
      Position closes when qty ≈ 0
```

### Correction Leg Properties

When processed, a correction becomes a synthetic leg with:
- `leg_type = 'correction'`
- `action = 'buy'` (if qty_delta >= 0) or `'sell'` (if qty_delta < 0)
- `qty = abs(qty_delta)`
- `net_qty = qty_delta` (signed, for position calculation)
- `include_in_waep` controls whether it affects WAEP/cost tracking

### WAEP Behavior

By default, corrections have `include_in_waep = 0`, meaning:
- The correction adjusts running quantity
- Entry cost and WAEP are **not** affected
- PnL calculation uses only the recorded (non-correction) trades

This is usually the right choice because:
1. The correction represents pre-history inventory
2. You don't know the exact entry price for old holdings
3. Distorting WAEP would make tracked period PnL inaccurate

If you **do** know the cost basis:
```bash
./bin/pipeline/fix_spot_balance.py \
    --account bybit-main \
    --symbol ETHUSDT \
    --missing-qty 0.70058 \
    --include-in-waep \
    --price-for-pnl 3500.00
```

## Best Practices

### 1. Always use --dry-run first

Review the impact before making changes:
```bash
./bin/pipeline/fix_spot_balance.py --account myaccount --symbol ETHUSDT --missing-qty 0.5 --dry-run
```

### 2. Document your corrections

Use meaningful `--reason` values:
```bash
--reason "Pre-TradeLens holdings from 2023 wallet transfer"
```

### 3. One correction per issue

Don't combine multiple problems into one correction. Create separate corrections with distinct reasons.

### 4. Verify after applying

Always run the trade journal refresh and check results:
```bash
./bin/pipeline/refresh_trade_journal.py --symbol ETHUSDT --reload
./bin/journal --symbol ETHUSDT
```

### 5. Keep corrections minimal

Only correct what's needed to make the data accurate. Don't over-correct.

## Troubleshooting

### Position still shows OPEN after correction

1. Check correction was inserted:
   ```sql
   SELECT * FROM spot_balance_correction WHERE symbol = 'ETHUSDT'
   ```

2. Verify effective_time is before first order:
   ```sql
   SELECT MIN(exchange_filled_at) FROM order_leg_hist
   WHERE symbol = 'ETHUSDT' AND category = 'spot'
   ```

3. Re-run trade journal refresh with --reload:
   ```bash
   ./bin/pipeline/refresh_trade_journal.py --symbol ETHUSDT --reload
   ```

### Multiple corrections needed

You can insert multiple corrections for the same symbol. They're all summed together when calculating running quantity.

### Removing a correction

If you made a mistake, you can delete the correction:
```sql
DELETE FROM spot_balance_correction WHERE correction_id = 123
```

Then re-run the trade journal refresh.

## SQL Reference

### View all corrections
```sql
SELECT * FROM spot_balance_correction ORDER BY created_at DESC
```

### Check running qty after corrections
```sql
-- Raw hist qty
SELECT
    SUM(CASE WHEN action = 'buy' THEN COALESCE(net_qty, qty) ELSE 0 END) as bought,
    SUM(CASE WHEN action = 'sell' THEN qty ELSE 0 END) as sold
FROM order_leg_hist
WHERE symbol = 'ETHUSDT' AND category = 'spot' AND status = 'filled'

-- Corrections
SELECT SUM(qty_delta) as total_correction
FROM spot_balance_correction
WHERE symbol = 'ETHUSDT' AND account_id = 'bybit-main'
```

### Delete all corrections for a symbol
```sql
DELETE FROM spot_balance_correction
WHERE account_id = 'bybit-main' AND symbol = 'ETHUSDT'
```
