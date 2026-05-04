# WAEP Per-Leg Tracking Implementation

## Overview

This document summarizes the implementation of WAEP (Weighted Average Entry Price) per-leg tracking in TradeLens.

## Motivation

Track WAEP evolution over the life of a position to:
- Enable precise trade analytics
- Support chart overlays showing how average entry price changes
- Provide historical WAEP data for backtesting and analysis

## What Was Implemented

### 1. Database Schema Changes

**Migration**: `migrations/008_add_waep_after_leg.sql`

Added `waep_after_leg NUMERIC(38,10) NULL` column to both:
- `order_leg_live` (for open/pending orders)
- `order_leg_hist` (for filled/historical orders)

**Bootstrap**: Updated `bin/setup/setup_database.py` to include the new column in both table definitions.

### 2. WAEP Calculation Helper

**Module**: `lib/tradelens/utils/waep_tracker.py`

Core components:
- `PositionState`: Dataclass representing position state (side, size, WAEP, realized PnL)
- `WAEPTracker`: Applies legs to position and calculates WAEP after each leg

Key features:
- Reuses existing WAEP calculation logic
- Handles entry/DCA (WAEP update), reduce/TP/SL (WAEP unchanged), full close
- Supports long/short positions and spot trading
- Correctly handles pending/cancelled orders (no WAEP)

### 3. Live Orders Pipeline Integration

**File**: `bin/pipeline/refresh_order_leg_live.py`

Changes:
- Added `WAEPTracker` instance to `OrderClassifier`
- New method `_calculate_waep_after_leg()` to compute WAEP for each classified leg
- Updated `upsert_legs_to_db()` to include `waep_after_leg` in INSERT/UPDATE statements
- Position state built from current portfolio via `get_combined_portfolio()`

### 4. Historical Orders Pipeline Integration

**File**: `bin/pipeline/refresh_order_leg_hist.py`

Changes:
- Imported `WAEPTracker` and `PositionState`
- Created `WAEPTracker` instance in main processing loop
- Updated chronological processing to maintain `PositionState` alongside existing position tracking
- Applied WAEP calculation to each leg as it's processed
- Updated `upsert_hist_legs_to_db()` to include `waep_after_leg` in parameterized queries

### 5. Tests

**File**: `tests/unit/test_waep_tracker.py`

Comprehensive test coverage for:
- ✅ Long DCA scenario (entry + DCA → correct weighted average)
- ✅ Partial close scenario (WAEP remains unchanged)
- ✅ Full close scenario (WAEP stored from closed position)
- ✅ Pending order (no WAEP, NULL)
- ✅ Cancelled order (no WAEP, NULL)
- ✅ Short entry and cover
- ✅ Spot trading (always long, no shorting)

### 6. Documentation

**File**: `CLAUDE.md`

Added comprehensive "WAEP Per-Leg Tracking" section covering:
- Overview and motivation
- Database schema
- Semantics and behavior by leg type
- Implementation details
- Examples (DCA, partial close, full close)
- Usage in analytics (SQL query examples)
- Test coverage

## Usage

### Running Tests

```bash
cd /app/syb/tradesuite/tradelens
source /app/syb/tradesuite/sourceme.sh
pytest tests/unit/test_waep_tracker.py -v
```

### Applying Migration

For existing databases:

```bash
cd /app/syb/tradesuite/tradelens
source /app/syb/tradesuite/sourceme.sh

# Run migration
sqsh -S $DSQUERY -U $SybAdminUser -P $SybAdminPwd -D tradelens -i migrations/008_add_waep_after_leg.sql
```

For fresh installs, the column is automatically created via `setup_database.py`.

### Refreshing Data

After migration, run the pipelines to populate `waep_after_leg`:

```bash
# Refresh live orders (current open positions)
./bin/pipeline/refresh_order_leg_live.py

# Refresh historical orders (filled orders)
./bin/pipeline/refresh_order_leg_hist.py

# Or run full refresh
./bin/refresh
```

### Querying WAEP Data

```sql
-- Get WAEP evolution for a specific symbol
SELECT filled_at, symbol, leg_type, price, qty, waep_after_leg
FROM order_leg_hist
WHERE symbol = 'BTCUSDT'
  AND waep_after_leg IS NOT NULL
ORDER BY filled_at

-- Chart WAEP step function
SELECT filled_at, waep_after_leg
FROM order_leg_hist
WHERE symbol = 'BTCUSDT'
  AND waep_after_leg IS NOT NULL
ORDER BY filled_at
```

## Semantics Summary

| Leg Type | Position Change | WAEP Behavior |
|----------|----------------|---------------|
| Entry/DCA | Increases position | Calculated via weighted average |
| Reduce/TP/SL | Decreases position | WAEP unchanged |
| Full Close | Position → 0 | WAEP of closed position stored |
| Pending/Cancelled | No change | NULL (no position effect) |

### WAEP Formula

For entry/DCA legs:
```
new_waep = (old_qty * old_waep + new_qty * new_price) / (old_qty + new_qty)
```

For reduce legs:
```
new_waep = old_waep  (unchanged)
```

## Backwards Compatibility

- **No backfill required**: Old rows have `waep_after_leg = NULL`
- **No breaking changes**: Existing queries continue to work
- **Additive only**: New column is nullable and optional

## Files Changed

1. `migrations/008_add_waep_after_leg.sql` (new)
2. `lib/tradelens/utils/waep_tracker.py` (new)
3. `tests/unit/test_waep_tracker.py` (new)
4. `bin/setup/setup_database.py` (modified - added column to CREATE TABLE)
5. `bin/pipeline/refresh_order_leg_live.py` (modified - WAEP calculation + DB ops)
6. `bin/pipeline/refresh_order_leg_hist.py` (modified - WAEP calculation + DB ops)
7. `CLAUDE.md` (modified - added WAEP documentation section)

## Future Enhancements

Potential improvements for future consideration:
- Chart overlays showing WAEP evolution with price action
- PnL calculation using WAEP for each exit leg
- WAEP-based stop loss and take profit analytics
- Backfill script for historical data (if needed)

---

**Implementation Date**: 2025-11-19
**Status**: Complete and tested
**Breaking Changes**: None
