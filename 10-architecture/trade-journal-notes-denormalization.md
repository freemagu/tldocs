# Trade Journal Notes Denormalization

## Overview

The `trade_journal_notes` table has been enhanced with denormalized columns from `trade_journal` to support efficient querying and data reconstruction after purging/reloading.

## Purpose

The primary use case is to enable:
1. **Purging and reloading trade_journal data** - When trade_journal rows are deleted and regenerated, the denormalized columns allow re-mapping trade_ids to notes/tags
2. **Faster filtering** - Query notes/tags by symbol, account, etc. without joining to trade_journal
3. **Simpler queries** - Access trade metadata directly from notes table

## Schema Changes

### New Columns in `trade_journal_notes`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `account_id` | INT | YES | Account ID (from trade_journal) |
| `symbol` | VARCHAR(32) | YES | Trading symbol (from trade_journal) |
| `category` | VARCHAR(16) | YES | Category: linear/inverse/spot (from trade_journal) |
| `side` | VARCHAR(10) | YES | Trade side: long/short (from trade_journal) |
| `opened_at` | DATETIME | YES | Trade open timestamp (from trade_journal) |

### New Indexes

- `idx_tjn_account_symbol` - Composite index on (account_id, symbol) for fast filtering
- `idx_tjn_opened_at` - Index on opened_at for time-based queries

## Usage

### Querying Notes by Symbol

```sql
-- Find all notes for BTCUSDT trades (no join required)
SELECT id, trade_id, event_type, content, opened_at
FROM trade_journal_notes
WHERE symbol = 'BTCUSDT'
ORDER BY opened_at DESC
```

### Remapping After Trade Journal Reload

When trade_journal is purged and reloaded, the trade_id values will change. To remap:

```sql
-- Update trade_journal_notes.trade_id after reloading trade_journal
UPDATE trade_journal_notes
SET trade_id = tj.trade_id
FROM trade_journal_notes tjn
JOIN trade_journal tj ON
    tjn.account_id = tj.account_id
    AND tjn.symbol = tj.symbol
    AND tjn.category = tj.category
    AND tjn.side = tj.side
    AND tjn.opened_at = tj.opened_at
WHERE tjn.trade_id IS NULL
   OR tjn.trade_id <> tj.trade_id
```

## API Behavior

When creating notes or tags via the API endpoint `POST /journal/{trade_id}/notes`, the following columns are automatically populated:

1. Fetch trade metadata from `trade_journal`
2. Populate denormalized columns in the INSERT statement
3. Return the created note/tag with new ID

Example API call:

```bash
curl -X POST "http://localhost:8088/journal/500000000000355/notes" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "note",
    "content": "This is a test note"
  }'
```

The inserted row will have:
- `trade_id` = 500000000000355
- `account_id`, `symbol`, `category`, `side`, `opened_at` - automatically populated from trade_journal

## Maintenance

### Backfilling Existing Rows

If the denormalized columns are NULL for existing rows, run:

```bash
python3 bin/setup/patch_trade_journal_notes.py
```

This script will:
1. Find rows where any denormalized column is NULL
2. Update them from the corresponding trade_journal row
3. Report statistics on rows updated

### Migration

The migration script is located at:
- `migrations/015_add_denorm_columns_to_journal_notes.sql`

To apply manually:

```bash
sqsh -S $DSQUERY -U $SybAdminUser -P $SybAdminPwd
USE tradelens
go

ALTER TABLE trade_journal_notes ADD account_id INT NULL
go
ALTER TABLE trade_journal_notes ADD symbol VARCHAR(32) NULL
go
ALTER TABLE trade_journal_notes ADD category VARCHAR(16) NULL
go
ALTER TABLE trade_journal_notes ADD side VARCHAR(10) NULL
go
ALTER TABLE trade_journal_notes ADD opened_at DATETIME NULL
go

CREATE INDEX idx_tjn_account_symbol ON trade_journal_notes(account_id, symbol)
go
CREATE INDEX idx_tjn_opened_at ON trade_journal_notes(opened_at)
go
```

## Implementation Details

### Database Schema

The columns are nullable to support:
- Legacy rows created before this migration
- Notes created before a trade_id is assigned (edge case)

### API Implementation

Modified file: `lib/tradelens/api/journal.py`

The `create_note_or_tag()` endpoint now:
1. Queries trade_journal for all 5 denormalized columns
2. Includes them in the INSERT statement
3. No additional round-trips or separate UPDATE needed

### Performance Considerations

**Benefits:**
- Faster queries when filtering by symbol/account (no join)
- Enables efficient re-mapping after data reload
- Minimal storage overhead (~50 bytes per row)

**Trade-offs:**
- Slightly larger INSERT statements
- Denormalized data requires consistency management

**Index Performance:**
- `idx_tjn_account_symbol` - Covers most common query patterns
- `idx_tjn_opened_at` - Enables time-range filtering

## Future Enhancements

Potential improvements:
1. Add composite index on (symbol, opened_at) for symbol-based time queries
2. Add NOT NULL constraints after all rows are backfilled
3. Consider adding foreign key to trade_journal.trade_id (may impact purge/reload)

## Migration History

| Date | Migration | Description |
|------|-----------|-------------|
| 2025-11-23 | 015_add_denorm_columns_to_journal_notes.sql | Added account_id, symbol, category, side, opened_at columns and indexes |

## Related Files

- Migration: `migrations/015_add_denorm_columns_to_journal_notes.sql`
- Patch script: `bin/setup/patch_trade_journal_notes.py`
- Setup script: `bin/setup/setup_database.py` (updated table definition)
- API endpoint: `lib/tradelens/api/journal.py` (updated INSERT logic)

---

**Last Updated**: 2025-11-23
**Maintained By**: Development Team
