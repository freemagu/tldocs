# Phase 1: Timestamp Refactoring - Implementation Summary

> **Historical Note**: This document describes work performed when TradeLens used Sybase ASE.
> TradeLens was migrated to PostgreSQL in March 2026. The column renames described here
> are still in effect, but Sybase-specific commands (sqsh, sp_rename, etc.) no longer apply.

**Date**: 2025-11-23
**Status**: Implementation Complete - Ready for Testing

## Overview

Successfully refactored `order_leg_live` and `order_leg_hist` tables to use `exchange_*` prefix for all Bybit-sourced timestamps, added `exchange_updated_at` to both tables, and added `trigger_price` to `order_leg_hist`.

## Changes Made

### 1. Database Schema Changes

**Migration File**: `/app/syb/tradesuite/tradelens/migrations/013_rename_timestamps_to_exchange_prefix.sql`

**order_leg_live:**
- Renamed: `created_at` → `exchange_created_at` (BIGDATETIME)
- Added: `exchange_updated_at` (BIGDATETIME NULL)
- Unchanged: `updated_at` (DATETIME NOT NULL) - Local TradeLens timestamp

**order_leg_hist:**
- Renamed: `created_at` → `exchange_created_at` (BIGDATETIME)
- Renamed: `filled_at` → `exchange_filled_at` (BIGDATETIME)
- Added: `exchange_updated_at` (BIGDATETIME NULL)
- Added: `trigger_price` (NUMERIC(18,6) NULL)

**Index Changes:**
- Dropped: `idx_order_leg_hist_filled_at`
- Created: `idx_order_leg_hist_exchange_filled_at`

### 2. Python Code Updates

**File**: `bin/setup/setup_database.py`
- Updated table definitions for new installations
- Updated index definitions

**File**: `bin/pipeline/refresh_order_leg_live.py`
- Extract Bybit `updatedTime` field
- Map to `exchange_created_at`, `exchange_updated_at` in leg dictionary
- Update INSERT statement with new columns
- Update UPDATE statement with new columns

**File**: `bin/pipeline/refresh_order_leg_hist.py`
- Extract Bybit `updatedTime` field
- Add `trigger_price` extraction from order JSON
- Map to `exchange_created_at`, `exchange_filled_at`, `exchange_updated_at`
- Update INSERT/UPDATE statements with new columns
- Update `get_last_order_time()` query to use new column names
- Update cache update logic to use new column names
- Update display output to use `exchange_filled_at`

**File**: `bin/show/show_trade_journal.py`
- Update `TradeLeg` class to use `exchange_created_at`, `exchange_filled_at`
- Update SQL query to SELECT new column names
- Update row parsing to match new column order
- Now retrieves `trigger_price` from `order_leg_hist` (previously unavailable)

**File**: `bin/show/show_portfolio.py`
- No changes required (doesn't query order_leg tables)

**File**: `bin/show/show_order_hist_perp.py`
- No changes required (doesn't reference these columns)

### 3. Naming Convention

After this refactoring:

**Columns prefixed with `exchange_`**: Sourced directly from Bybit API
- `exchange_created_at` = Bybit `createdTime`
- `exchange_updated_at` = Bybit `updatedTime`
- `exchange_filled_at` = Bybit fill timestamp

**Bare `updated_at`** (order_leg_live only): LOCAL TradeLens timestamp
- Updated by Python refresh script when row is modified
- Represents "when TradeLens last touched this row"

## Files Modified

### New Files
1. `/app/syb/tradesuite/tradelens/migrations/013_rename_timestamps_to_exchange_prefix.sql`
2. `/app/syb/tradesuite/tradelens/dev/active/phase1-rename-timestamps-exchange-prefix/*` (dev docs)

### Modified Files
1. `/app/syb/tradesuite/tradelens/bin/setup/setup_database.py`
2. `/app/syb/tradesuite/tradelens/bin/pipeline/refresh_order_leg_live.py`
3. `/app/syb/tradesuite/tradelens/bin/pipeline/refresh_order_leg_hist.py`
4. `/app/syb/tradesuite/tradelens/bin/show/show_trade_journal.py`

## Testing Checklist

### Pre-Migration
- [ ] Backup current database (recommended)
- [ ] Note current row counts in order_leg_live and order_leg_hist
- [ ] Verify PostgreSQL connection works

### Run Migration
```bash
cd /app/syb/tradesuite/tradelens
source ../sourceme.sh

# Run migration via psql
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -f migrations/013_rename_timestamps_to_exchange_prefix.sql
```

### Verify Schema Changes
```bash
# Check table columns via psql
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -c "\d order_leg_live"
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -c "\d order_leg_hist"
```

```sql
-- Verify data preserved
SELECT COUNT(*) FROM order_leg_live;
SELECT COUNT(*) FROM order_leg_hist;
```

### Test Refresh Scripts
```bash
# Test live orders refresh
./bin/pipeline/refresh_order_leg_live.py --debug

# Test historical orders refresh (limited scope)
./bin/pipeline/refresh_order_leg_hist.py --symbol BTCUSDT --days 1 --debug
```

### Verify Data Population
```sql
-- Check that new columns are being populated
SELECT
    exchange_order_id,
    exchange_created_at,
    exchange_updated_at,
    updated_at
FROM order_leg_live
ORDER BY id DESC
LIMIT 5;

SELECT
    exchange_order_id,
    exchange_created_at,
    exchange_filled_at,
    exchange_updated_at,
    trigger_price
FROM order_leg_hist
ORDER BY id DESC
LIMIT 5;
```

### Test Display Scripts
```bash
# Test trade journal display
./bin/journal --symbol BTCUSDT

# Test portfolio display
./bin/portfolio
```

### Final Verification
```bash
# Check for any remaining references to old column names
grep -r "FROM order_leg_live" bin/ lib/ | grep -E "created_at[^_]|filled_at"
grep -r "FROM order_leg_hist" bin/ lib/ | grep -E "created_at[^_]|filled_at"
```

## Success Criteria

- [x] Migration SQL created and includes verification
- [x] All Python code updated to use new column names
- [x] Display scripts updated
- [ ] Migration runs without errors
- [ ] All refresh scripts run without errors
- [ ] New columns are populated correctly
- [ ] Display scripts work without errors
- [ ] No references to old column names remain (except in other tables)

## Rollback Plan

If issues occur, the migration can be rolled back:

```sql
-- Rollback order_leg_live
ALTER TABLE order_leg_live RENAME COLUMN exchange_created_at TO created_at;
ALTER TABLE order_leg_live DROP COLUMN exchange_updated_at;

-- Rollback order_leg_hist
ALTER TABLE order_leg_hist RENAME COLUMN exchange_created_at TO created_at;
ALTER TABLE order_leg_hist RENAME COLUMN exchange_filled_at TO filled_at;
ALTER TABLE order_leg_hist DROP COLUMN exchange_updated_at;
ALTER TABLE order_leg_hist DROP COLUMN trigger_price;

-- Recreate old index
DROP INDEX idx_order_leg_hist_exchange_filled_at;
CREATE INDEX idx_order_leg_hist_filled_at ON order_leg_hist(filled_at);
```

**Note**: After rollback, you must also revert the Python code changes.

## Next Steps (Out of Scope for Phase 1)

Phase 2 will introduce:
- Event-sourcing architecture
- New `order_leg_event` table
- Historical event reconstruction
- More granular order state tracking

## Notes

- This refactoring is backward-incompatible for queries
- All code paths that query these tables have been updated
- The `updated_at` column in `order_leg_live` retains its original meaning (local timestamp)
- Migration uses `ALTER TABLE RENAME COLUMN` which preserves data without copying
- New columns start as NULL and will be populated going forward

## References

- User Requirement: Phase 1 timestamp refactoring specification
- Dev Docs: `/app/syb/tradesuite/tradelens/dev/active/phase1-rename-timestamps-exchange-prefix/`
- Migration SQL: `migrations/013_rename_timestamps_to_exchange_prefix.sql`
