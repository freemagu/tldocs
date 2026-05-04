# Trade Journal Subsystem

**Version:** 1.0
**Date:** 2025-10-18
**Status:** Production Ready

## Overview

The Trade Journal subsystem provides unified tracking and analysis for ALL trades in TradeLens, including both SmartTrade UI submissions and manual trades placed directly via Bybit. It aggregates order legs from `order_leg_hist` into coherent trade sessions, calculating entry/exit prices, PnL, and maintaining full lineage back to individual order executions.

### Key Features

- **Unified Trade Tracking**: Single source of truth for all trades (SmartTrade + manual)
- **Session-Based Aggregation**: Groups order legs into logical trade sessions using position tracking
- **Accurate WAEP Calculation**: Weighted Average Entry/Exit Prices for multi-leg entries/exits
- **Realized PnL Tracking**: Computed per session with proper long/short handling
- **Full Audit Trail**: `trade_leg_map` links every journal entry back to source order legs
- **Event-Sourced Journaling**: `trade_journal_notes` supports timestamped notes and tags
- **Idempotent Operations**: Safe to re-run aggregation scripts without duplicates

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Order Execution (Bybit)                          │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
                 refresh_order_leg_hist.py
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     order_leg_hist                                  │
│  (Classified historical orders: entry, dca, tp, stop)               │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
                 refresh_trade_journal.py
                  (Sessionization Algorithm)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     trade_journal                                   │
│  (Aggregated sessions: opened_at, closed_at, entry_waep, PnL)      │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ├──► trade_leg_map (lineage to order legs)
                         │
                         └──► trade_journal_notes (event-sourced notes)
```

### Schema Design

#### Table: `smart_trades`
Replaces `trade_intent` naming. Stores metadata for trades submitted via SmartTrade UI.

```sql
CREATE TABLE smart_trades (
    smart_trade_id NUMERIC(18,0) IDENTITY PRIMARY KEY,
    symbol         VARCHAR(32) NOT NULL,
    side           VARCHAR(10) NOT NULL,       -- 'long' / 'short'
    category       VARCHAR(16) NULL,           -- 'linear' / 'inverse' / 'spot'
    created_at     DATETIME NOT NULL,
    updated_at     DATETIME NOT NULL
);
```

**Note:** The legacy `trade_intent` table is NOT dropped to preserve historical data.

#### Table: `trade_journal`
Master record for ALL trades (SmartTrade + manual). Aggregated from `order_leg_hist`.

```sql
CREATE TABLE trade_journal (
    trade_id      NUMERIC(18,0) IDENTITY PRIMARY KEY,
    symbol        VARCHAR(32) NOT NULL,
    category      VARCHAR(16) NULL,            -- 'linear' / 'inverse' / 'spot'
    side          VARCHAR(10) NOT NULL,        -- 'long' / 'short'
    opened_at     DATETIME NULL,               -- First entry timestamp
    closed_at     DATETIME NULL,               -- Last exit timestamp (NULL if open)
    entry_price   NUMERIC(38,10) NULL,         -- WAEP for entries/DCAs
    exit_price    NUMERIC(38,10) NULL,         -- WAEP for exits (TP/SL)
    qty           NUMERIC(38,10) NULL,         -- Total entered quantity
    realized_pnl  NUMERIC(38,10) NULL,         -- In quote currency (USDT)
    status        VARCHAR(20) NOT NULL,        -- 'open' / 'closed'
    smart_trade_id NUMERIC(18,0) NULL,         -- Optional FK to smart_trades
    created_at    DATETIME NOT NULL,
    updated_at    DATETIME NOT NULL
);
```

**Indexes:**
- `idx_trade_journal_symbol_status` - Fast filtering by symbol + status
- `idx_trade_journal_opened` - Time-series queries
- `idx_trade_journal_smart_trade_id` - Link to SmartTrade submissions

#### Table: `trade_journal_notes`
Event-sourced notes/tags for journaling (timestamped).

```sql
CREATE TABLE trade_journal_notes (
    id             NUMERIC(18,0) IDENTITY PRIMARY KEY,
    trade_id       NUMERIC(18,0) NULL,         -- Later linked when known
    smart_trade_id NUMERIC(18,0) NULL,         -- Present for SmartTrade notes
    event_type     VARCHAR(16) NOT NULL,       -- 'note' or 'tag'
    content        VARCHAR(1024) NOT NULL,
    created_at     DATETIME NOT NULL,
    updated_at     DATETIME NOT NULL
);
```

**Usage:**
- Notes added at SmartTrade submission have `smart_trade_id` set, `trade_id` NULL
- `refresh_trade_journal.py` backfills `trade_id` when session is created
- Enables planning notes to attach to live trades

**Indexes:**
- `idx_tjn_trade_id` - Lookup notes for a trade
- `idx_tjn_smart_trade_id` - Backfill queries
- `idx_tjn_created_at` - Time-series analysis

#### Table: `trade_leg_map`
Relational glue mapping `trade_journal.trade_id` ↔ `order_leg_hist.id`.

```sql
CREATE TABLE trade_leg_map (
    trade_id NUMERIC(18,0) NOT NULL,
    leg_id   NUMERIC(18,0) NOT NULL,           -- FK to order_leg_hist(id)
    PRIMARY KEY (trade_id, leg_id)
);
```

**Purpose:**
- Reconstruct full trade details from aggregated journal entries
- Audit trail for PnL calculations
- Supports drill-down from session → individual fills

**Indexes:**
- `idx_trade_leg_map_trade` - Get all legs for a trade
- `idx_trade_leg_map_leg` - Find which trade a leg belongs to

## Sessionization Algorithm

The core logic in `refresh_trade_journal.py` uses **rolling position tracking** to group order legs into coherent trade sessions.

### Algorithm Steps

1. **Load Candidate Legs**
   - Fetch filled orders from `order_leg_hist` within lookback window
   - Filter by symbol, category, time range as specified

2. **Normalize Direction**
   - **Spot**: Always `long` (no shorts)
   - **Futures (linear/inverse)**: Infer from `leg_type` + `side`
     - `entry`/`dca` + `Buy` → `long`
     - `entry`/`dca` + `Sell` → `short`
     - `tp`/`stop` + `Sell` → closing `long`
     - `tp`/`stop` + `Buy` → closing `short`

3. **Rolling Position Model**
   - Group legs by `(symbol, side, category)` streams
   - Track `running_position_qty` starting at 0
   - **Entry/DCA**: Increase qty (`long`: +, `short`: -)
   - **Exit (TP/SL)**: Reduce qty (`long`: -, `short`: +)

4. **Session Boundaries**
   - **Session starts**: `running_qty` transitions from 0 to non-zero (first entry)
   - **Session ends**: `running_qty` returns to 0 (fully closed)
   - **Partial exits**: Keep session open (status = `open`)

5. **Calculations**
   - **opened_at**: Timestamp of first leg in session
   - **closed_at**: Timestamp when qty returns to 0 (NULL if open)
   - **entry_price**: `sum(qty * price) / sum(qty)` for entry/DCA legs
   - **exit_price**: `sum(qty * price) / sum(qty)` for exit legs
   - **qty**: `abs(total_entry_qty)` (invariant: sum of entered quantity)
   - **realized_pnl**:
     - **Long**: `(exit_waep - entry_waep) * exit_qty`
     - **Short**: `(entry_waep - exit_waep) * exit_qty`

6. **Upsert & Mapping**
   - Upsert `trade_journal` (match on symbol + opened_at)
   - Delete old `trade_leg_map` entries for this `trade_id`
   - Insert new mappings for all legs in session

7. **Notes Backfill**
   - For sessions with `smart_trade_id`:
     - Update `trade_journal_notes` rows where:
       - `smart_trade_id` matches
       - `trade_id IS NULL`
       - `created_at` within ±5 minutes of `opened_at`

### Edge Cases

- **Reversals**: If position flips from long to short without passing through zero, close the long session at the crossing leg, start new short session.
- **Cancelled Orders**: Excluded from position tracking (status != 'filled').
- **Missing `filled_at`**: Use `created_at` as fallback; log warning.
- **Spot Cannot Short**: Enforce `side='long'` on spot entries; exits reduce qty only.

## Scripts

### `bin/refresh_trade_journal.py`

**Purpose:** Aggregate filled order legs into trade journal sessions.

**Usage:**
```bash
# Default: aggregate last 60 days (from config: journal_lookback_days)
python3 bin/refresh_trade_journal.py

# Custom lookback window
python3 bin/refresh_trade_journal.py --days 90

# Filter by symbol
python3 bin/refresh_trade_journal.py --symbol BTCUSDT

# Filter by category
python3 bin/refresh_trade_journal.py --category linear

# Filter by timestamp
python3 bin/refresh_trade_journal.py --since '2025-10-01 00:00:00'

# Dry-run (compute but don't write)
python3 bin/refresh_trade_journal.py --dry-run --debug

# Rebuild a specific trade_id
python3 bin/refresh_trade_journal.py --rebuild-trade 1234
```

**CLI Arguments:**
- `--days N`: Lookback window in days (default: from config)
- `--symbol SYMBOL`: Filter to specific symbol (e.g., BTCUSDT)
- `--category CAT`: Filter to category (linear|inverse|spot)
- `--since TIMESTAMP`: Process legs filled after this UTC timestamp
- `--rebuild-trade ID`: Delete and recreate a specific trade_id
- `--dry-run`: Compute sessions but don't write to DB
- `--debug`: Enable verbose logging

**Output:**
- JSON summary in dry-run mode
- Statistics: legs scanned, sessions created, mappings upserted
- Sample table of first 10 sessions

**Return Codes:**
- `0`: Success
- `1`: Error (exception or keyboard interrupt)

**Performance:**
- Uses indexes on `order_leg_hist(symbol, category, filled_at)`
- Batch DB writes (no per-row commits)
- Typical runtime: ~0.2s for 60 legs / 17 sessions

### `bin/setup_database.py`

**Updates:** Now includes the four new Trade Journal tables in schema creation and verification.

**Usage:**
```bash
# Create all tables (idempotent)
python3 bin/setup_database.py

# Verify schema only (no writes)
python3 bin/setup_database.py --verify-only

# Recreate all tables (WARNING: deletes data!)
python3 bin/setup_database.py --recreate
```

### Migration: `migrations/003_trade_journal_subsystem.sql`

**Run once** to create the four new tables and indexes.

```bash
# Using psql
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -f migrations/003_trade_journal_subsystem.sql

# Or using run_migration.py
python3 bin/run_migration.py 003_trade_journal_subsystem.sql
```

**Idempotent:** Safe to re-run. Uses `IF NOT EXISTS` checks.

## Configuration

**File:** `etc/config.yml`

```yaml
# Trade Journal Configuration
journal_lookback_days: 60        # Default lookback window for aggregation
```

**Environment Variables:**
- `TSHOME`: TraderSuite home (set by `sourceme.sh`)
- `TLHOME`: TradeLens home (set by `sourceme.sh`)

## Operations Guide

### Initial Setup

1. **Run Migration:**
   ```bash
   cd /app/syb/tradesuite/tradelens
   psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -f migrations/003_trade_journal_subsystem.sql
   ```

2. **Verify Schema:**
   ```bash
   python3 bin/setup_database.py --verify-only
   ```

3. **Populate Historical Orders:**
   ```bash
   python3 bin/refresh_order_leg_hist.py --days 60
   ```

4. **Aggregate into Journal:**
   ```bash
   python3 bin/refresh_trade_journal.py --days 60
   ```

### Daily Operations

**Recommended cron job:**
```bash
# Refresh order history (every hour)
0 * * * * cd /app/syb/tradesuite/tradelens && \
          source /app/syb/tradesuite/sourceme.sh && \
          python3 bin/refresh_order_leg_hist.py --days 1 >> logs/refresh_order_leg_hist.log 2>&1

# Aggregate trade journal (every 6 hours)
0 */6 * * * cd /app/syb/tradesuite/tradelens && \
            source /app/syb/tradesuite/sourceme.sh && \
            python3 bin/refresh_trade_journal.py --days 7 >> logs/refresh_trade_journal.log 2>&1
```

### Troubleshooting

#### No Sessions Created

**Symptom:**
```
⚠  No filled order legs found in the specified window
```

**Solution:**
1. Run `refresh_order_leg_hist.py` first to populate `order_leg_hist`
2. Check lookback window (default: 60 days)
3. Verify Bybit API connectivity

#### PnL Calculations Look Wrong

**Symptom:** `realized_pnl` doesn't match expectations

**Debugging Steps:**
1. Use `--dry-run --debug` to see detailed calculations
2. Check `entry_price` and `exit_price` (WAEP computed correctly?)
3. Verify `side` (long vs short) is correct
4. Inspect `trade_leg_map` to see which legs were included
5. Run `--rebuild-trade ID` to recompute

#### Trade Split Incorrectly

**Symptom:** Single trade appears as multiple sessions or vice versa

**Causes:**
- Reversal without passing through zero (e.g., flip from long to short)
- Gap in `filled_at` timestamps causing session break

**Solution:**
1. Review `order_leg_hist` timestamps for gaps
2. Check leg classification (entry vs exit)
3. May need to adjust normalization logic in `normalize_side()`

#### Notes Not Backfilled

**Symptom:** `trade_journal_notes.trade_id` remains NULL

**Checks:**
1. Does note have `smart_trade_id` set?
2. Was note `created_at` within ±5 minutes of `opened_at`?
3. Run `refresh_trade_journal.py` again to retry backfill

### Rebuilding a Single Trade

If a specific trade's data is incorrect:

```bash
# 1. Delete the trade
python3 bin/refresh_trade_journal.py --rebuild-trade 1234

# 2. Recreate it (filter to reduce noise)
python3 bin/refresh_trade_journal.py --symbol BTCUSDT --days 30
```

This will:
- Delete `trade_journal` row for `trade_id=1234`
- Delete all `trade_leg_map` entries for that trade
- Re-run sessionization to recreate from scratch

## API Integration

### Query Examples

**Get Open Trades:**
```sql
SELECT trade_id, symbol, side, opened_at, entry_price, qty, realized_pnl
FROM trade_journal
WHERE status = 'open'
ORDER BY opened_at DESC
```

**Get Closed Trades with PnL:**
```sql
SELECT trade_id, symbol, side, category,
       opened_at, closed_at,
       entry_price, exit_price, qty, realized_pnl
FROM trade_journal
WHERE status = 'closed'
  AND closed_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY closed_at DESC
```

**Drill Down to Order Legs:**
```sql
SELECT j.trade_id, j.symbol, j.side, j.status,
       l.leg_type, l.order_kind, l.price, l.qty, l.filled_at
FROM trade_journal j
JOIN trade_leg_map m ON j.trade_id = m.trade_id
JOIN order_leg_hist l ON m.hist_leg_id = l.id
WHERE j.trade_id = 1234
ORDER BY l.filled_at
```

**Get Notes for a Trade:**
```sql
SELECT n.event_type, n.content, n.created_at
FROM trade_journal_notes n
WHERE n.trade_id = 1234
ORDER BY n.created_at
```

## Testing

### Smoke Tests

**Test 1: Dry-Run (No DB Writes)**
```bash
python3 bin/refresh_trade_journal.py --dry-run --days 7 --debug
# Expected: JSON output, no DB changes
```

**Test 2: Single Symbol Aggregation**
```bash
python3 bin/refresh_trade_journal.py --symbol BTCUSDT --days 7
# Expected: Only BTCUSDT sessions created
```

**Test 3: Rebuild Trade**
```bash
# Get a trade_id
trade_id=$(psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -t -c \
  "SELECT trade_id FROM trade_journal LIMIT 1")

# Rebuild it
python3 bin/refresh_trade_journal.py --rebuild-trade $trade_id
python3 bin/refresh_trade_journal.py --days 7
# Expected: Trade recreated with same data
```

**Test 4: Verify Idempotency**
```bash
# Run twice, count should not change
python3 bin/refresh_trade_journal.py --days 7
count1=$(psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -t -c \
  "SELECT COUNT(*) FROM trade_journal")

python3 bin/refresh_trade_journal.py --days 7
count2=$(psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -t -c \
  "SELECT COUNT(*) FROM trade_journal")

# Expected: count1 == count2
```

## Future Enhancements

### Phase 1 (Completed)
- [x] Schema design and migration
- [x] Sessionization algorithm implementation
- [x] WAEP and PnL calculations
- [x] `trade_leg_map` maintenance
- [x] Dry-run and debug modes
- [x] CLI with flexible filters

### Phase 2 (Planned)
- [ ] SmartTrade UI integration (populate `smart_trade_id` on submission)
- [ ] Notes/tags collection in SmartTrade UI
- [ ] REST API endpoints for journal queries
- [ ] WebSocket updates for live session changes

### Phase 3 (Future)
- [ ] Advanced analytics (Sharpe ratio, max drawdown)
- [ ] Performance dashboards
- [ ] Export to CSV/Excel
- [ ] Trade replay/visualization

## References

- **Parent Doc**: `/app/syb/tradesuite/CLAUDE.md` (TraderSuite overview)
- **TradeLens Doc**: `/app/syb/tradesuite/tradelens/CLAUDE.md` (TradeLens context)
- **Migration**: `/app/syb/tradesuite/tradelens/migrations/003_trade_journal_subsystem.sql`
- **Script**: `/app/syb/tradesuite/tradelens/bin/refresh_trade_journal.py`
- **Config**: `/app/syb/tradesuite/tradelens/etc/config.yml`

---

**Maintained By:** Development Team
**Last Updated:** 2025-10-18
**Status:** Production Ready
