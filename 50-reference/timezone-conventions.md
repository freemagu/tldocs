# TradeLens Timezone Analysis Report

**Generated:** 2026-01-31
**Status:** Investigation Complete
**Author:** Claude Code Analysis

---

## Executive Summary

The TradeLens codebase has **inconsistent timezone handling** across different layers:

| Layer | Current Behavior | Expected |
|-------|-----------------|----------|
| Database `CURRENT_TIMESTAMP` | UTC (correct) | UTC |
| Exchange timestamps | UTC (correct) | UTC |
| Python `datetime.utcnow()` | Naive UTC | Should be timezone-aware |
| Python `datetime.now(timezone.utc)` | Aware UTC (correct) | UTC |
| API responses | UTC with 'Z' suffix (correct) | UTC |
| Log files | Mixed (some UTC, some local) | Should be UTC |

**Risk Level:** Medium - Can cause 1-2 hour discrepancies when comparing timestamps across different sources.

---

## 1. Database Server Timezone

### Current Configuration

PostgreSQL connections are configured with `SET timezone TO 'UTC'`:

```sql
-- All timestamps are UTC
SELECT CURRENT_TIMESTAMP;  -- Returns UTC time
```

All `TIMESTAMPTZ` columns store and return UTC values.

### Impact on Tables

All tables using `DEFAULT CURRENT_TIMESTAMP` now store **UTC time**:

| Table | Columns Using CURRENT_TIMESTAMP |
|-------|------------------------|
| `accounts` | `created_at`, `updated_at` |
| `trade_journal` | `created_at`, `updated_at` |
| `trade_idea` | `created_at`, `updated_at` |
| `trade_intent` | `created_at`, `updated_at` |
| `trade_alert` | `created_at`, `updated_at` |
| `tag_definition` | `created_at`, `updated_at` |
| `push_subscription` | `created_at`, `updated_at` |
| `spot_balance_correction` | `created_at` |
| `smart_trades` | `created_at`, `updated_at` |
| `smarttrade_templates` | `created_at`, `updated_at` |
| `vwap_config` | `created_at`, `updated_at` |
| `pending_position_context` | `created_at`, `updated_at` |
| ... and more |

---

## 2. Column Types and Their Timezone Semantics

### 2.1 TIMESTAMPTZ Columns (UTC)

PostgreSQL `TIMESTAMPTZ` columns populated via `CURRENT_TIMESTAMP`:

```sql
-- Example: trade_journal table
created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP  -- Stores UTC time
updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP  -- Stores UTC time
```

All connections use `SET timezone TO 'UTC'`, so timestamps are consistently UTC.

### 2.2 BIGDATETIME Columns (UTC)

High-precision timestamps from exchange APIs:

| Table | Column | Source | Timezone |
|-------|--------|--------|----------|
| `order_leg_live` | `exchange_created_at` | Bybit `createdTime` | UTC |
| `order_leg_live` | `exchange_updated_at` | Bybit `updatedTime` | UTC |
| `order_leg_live` | `exchange_filled_at` | Bybit `updatedTime` | UTC |
| `order_leg_hist` | `exchange_created_at` | Bybit `createdTime` | UTC |
| `order_leg_hist` | `exchange_updated_at` | Bybit `updatedTime` | UTC |
| `order_leg_hist` | `exchange_filled_at` | Bybit `updatedTime` | UTC |
| `order_leg_event` | `exchange_created_at` | Bybit `createdTime` | UTC |
| `order_leg_event` | `exchange_updated_at` | Bybit `updatedTime` | UTC |
| `order_leg_event` | `exchange_filled_at` | Bybit `updatedTime` | UTC |
| `market_candle` | `open_time` | Exchange candle time | UTC |
| `spot_position_live` | `last_fill_time` | Exchange fill time | UTC |
| `tradelens_app_lock` | `acquired_at`, `heartbeat_at`, `expires_at` | App-generated | UTC |

### 2.3 Mixed Usage Within Same Table

**Example: `order_leg_live`**

| Column | Type | Timezone | Source |
|--------|------|----------|--------|
| `exchange_created_at` | BIGDATETIME | UTC | Bybit API |
| `exchange_updated_at` | BIGDATETIME | UTC | Bybit API |
| `updated_at` | DATETIME | UTC | Python `datetime.utcnow()` |

This table is correct - all timestamps are UTC. But the naming convention (`exchange_*` vs plain) indicates source, not timezone.

---

## 3. Python Code Timezone Patterns

### 3.1 Correct Pattern: `datetime.now(timezone.utc)`

Files using timezone-aware UTC:

| File | Line(s) | Usage |
|------|---------|-------|
| `bin/server/level_guard_daemon.py` | 337, 544, 578 | Breach detection, reclaim time |
| `lib/tradelens/services/level_guard.py` | 190 | State machine timing |
| `bin/pipeline/refresh_trade_journal.py` | 2663 | Trade age calculation |
| `lib/tradelens/api/ideas.py` | 1112, 1409, 1726 | API response timestamps |
| `telegram_signals.py` | 594 | Idea day calculation |
| `tests/unit/test_level_guard.py` | 14 occurrences | Test fixtures |

### 3.2 Acceptable Pattern: `datetime.utcnow()`

Files using naive UTC (correct value, but no tzinfo):

| File | Usage Count | Purpose |
|------|-------------|---------|
| `bin/pipeline/refresh_spot_positions.py` | 3 | Position sync timestamps |
| `bin/pipeline/refresh_order_leg_live.py` | Multiple | Order sync timestamps |
| `bin/pipeline/refresh_order_leg_hist.py` | ~25 | Historical order processing |
| `lib/tradelens/services/stops.py` | 1 | Stop order updates |
| `lib/tradelens/locking/app_lock.py` | 6 | Lock expiry tracking |
| `lib/tradelens/api/health.py` | 15+ | Health check responses |
| `lib/tradelens/core/logging.py` | 1 | Structured log timestamps |
| `bin/tools/lockctl.py` | 2 | Lock management |
| `bin/engine/alert_engine.py` | 2 | Alert processing |

### 3.3 Problematic Pattern: `datetime.now()` (Local Time)

Files using local time (may be intentional for display, but risky):

| File | Usage | Risk |
|------|-------|------|
| `bin/tools/dump_schema.py` | Schema generation timestamp | Low - documentation only |
| `bin/tools/reverse_engineer_databases.py` | DDL generation timestamp | Low - documentation only |

### 3.4 Exchange Timestamp Conversion

**Critical Pattern for Bybit API:**

```python
# CORRECT - Uses utcfromtimestamp for UTC result
exchange_created_at = datetime.utcfromtimestamp(int(created_time_ms) / 1000)

# WRONG - Uses fromtimestamp which returns LOCAL time
exchange_created_at = datetime.fromtimestamp(int(created_time_ms) / 1000)  # DON'T USE
```

Files with correct conversion:
- `bin/pipeline/refresh_order_leg_live.py:402-425` (with explicit warning comments)
- `bin/pipeline/refresh_order_leg_hist.py:793-804`
- `lib/tradelens/services/portfolio.py:339`

---

## 4. Logging Timestamp Patterns

### 4.1 Structured Logs (UTC)

**File:** `lib/tradelens/core/logging.py:29`

```python
'timestamp': datetime.utcnow().isoformat() + 'Z'
```

Output: `"timestamp": "2026-01-31T13:24:00.123456Z"`

### 4.2 Monitor Daemon (UTC)

**File:** `bin/monitor` (shell script)

```bash
local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

### 4.3 Other Daemons (Local Time)

**Files:** `bin/server/level_guard_daemon.py`, `bin/server/pipeline_daemon.py`, `bin/mdsync.py`

```python
formatter = logging.Formatter(
    '%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'  # No timezone, uses local time
)
```

These logs show **local CET time** with no timezone indicator.

---

## 5. Specific Discrepancies Found

### 5.1 Comparing Exchange vs Application Timestamps

**Scenario:** Query to find orders placed in the last hour

```sql
-- With PostgreSQL and SET timezone TO 'UTC', all timestamps are consistent:
SELECT * FROM order_leg_hist
WHERE exchange_created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'
-- No timezone offset adjustment needed
```

### 5.2 Trade Journal Opened/Closed Times

**Table:** `trade_journal`

| Column | Source | Timezone |
|--------|--------|----------|
| `opened_at` | First fill's `exchange_filled_at` | UTC |
| `closed_at` | Last fill's `exchange_filled_at` | UTC |
| `created_at` | `CURRENT_TIMESTAMP` | UTC |
| `updated_at` | `CURRENT_TIMESTAMP` | UTC |

**Note:** After PostgreSQL migration, both `created_at` and `opened_at` are now UTC, resolving the previous timezone mismatch.

### 5.3 Trade Ideas vs Trade Journal

**Scenario:** User creates a trade idea, then executes it

| Event | Column | Timezone |
|-------|--------|----------|
| Idea created | `trade_idea.created_at` | UTC (CURRENT_TIMESTAMP) |
| Trade executed | `trade_journal.opened_at` | UTC (from exchange) |

**Problem:** If idea was created at 10:00 CET and executed immediately, the timestamps show:
- `trade_idea.created_at` = 10:00 (CET)
- `trade_journal.opened_at` = 09:00 (UTC)

This looks like the trade opened BEFORE the idea was created!

### 5.4 Alert Firing Times

**Table:** `fired_alert`

| Column | Source | Timezone |
|--------|--------|----------|
| `fired_at` | Python `datetime.now(timezone.utc)` or similar | UTC |
| `created_at` | `CURRENT_TIMESTAMP` | UTC |

**Note:** After PostgreSQL migration, both columns are now UTC. The previous 1-hour discrepancy no longer exists.

---

## 6. Historical Fixes (Migration Evidence)

### Migration 012: Fix Created_At Timezone

**File:** `migrations/012_fix_created_at_timezone.sql`

```sql
-- Problem: order_leg_live.created_at was storing CET instead of UTC
-- Root cause: Python used fromtimestamp() instead of utcfromtimestamp()
-- Fix: Subtract 1 hour from all existing timestamps

UPDATE order_leg_live
SET created_at = DATEADD(hour, -1, created_at)
WHERE created_at IS NOT NULL;
```

This confirms the issue has occurred before and was patched.

### Migration 013: Rename Timestamps

**File:** `migrations/013_rename_timestamps_to_exchange_prefix.sql`

Renamed columns to clarify source:
- `created_at` -> `exchange_created_at` (from Bybit)
- `filled_at` -> `exchange_filled_at` (from Bybit)
- Added `exchange_updated_at`

---

## 7. Issues This Causes

### 7.1 Incorrect Time-Based Queries

Any query comparing `datetime` columns (CET) with `bigdatetime` columns (UTC) will be off by 1-2 hours.

### 7.2 Confusing User-Facing Timestamps

When displaying both application timestamps (`created_at`) and exchange timestamps (`exchange_filled_at`), they appear inconsistent.

### 7.3 Analytics and Reporting Errors

P&L calculations that use time-based grouping (daily, hourly) may bucket trades incorrectly.

### 7.4 Log Correlation Difficulty

Correlating structured logs (UTC) with daemon logs (local) requires mental timezone conversion.

### 7.5 DST Transition Bugs

During DST transitions (last Sunday of March/October), the offset changes:
- CET (UTC+1) -> CEST (UTC+2) in March
- CEST (UTC+2) -> CET (UTC+1) in October

Queries that assume a fixed 1-hour offset will be wrong for 6 months of the year.

---

## 8. Proposed Solution

### 8.1 Short-Term: Document Current Behavior

1. Add a `TIMEZONE_CONVENTIONS.md` file to the repo (this file)
2. Document which columns are UTC vs CET
3. Add comments to SQL queries that cross timezone boundaries

### 8.2 Medium-Term: Standardize Python Code

1. Replace all `datetime.utcnow()` with `datetime.now(timezone.utc)`
2. Add type hints requiring `datetime` with `tzinfo`
3. Create utility function:

```python
# lib/tradelens/utils/time.py
from datetime import datetime, timezone

def utc_now() -> datetime:
    """Return current UTC time with timezone info."""
    return datetime.now(timezone.utc)

def to_db_string(dt: datetime) -> str:
    """Format datetime for PostgreSQL, ensuring UTC."""
    if dt.tzinfo is None:
        raise ValueError("Naive datetime not allowed - must be timezone-aware")
    utc_dt = dt.astimezone(timezone.utc)
    return utc_dt.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
```

### 8.3 Long-Term: Fix Database Defaults

**Option A: Application-Side Fix**

Stop using `DEFAULT CURRENT_TIMESTAMP` and always provide explicit UTC timestamps from Python:

```python
# Provide explicit UTC timestamps from Python
sql = f"""
INSERT INTO trade_idea (symbol, status, created_at, updated_at)
VALUES ('{symbol}', 'draft', '{utc_now_string()}', '{utc_now_string()}')
"""
```

**Option B: Database-Side Fix** (Completed)

All PostgreSQL connections use `SET timezone TO 'UTC'`, so `CURRENT_TIMESTAMP` always returns UTC. No workaround needed.

**Option C: Migrate Existing Data** (Completed)

Data migration to PostgreSQL was completed in March 2026.

### 8.4 Recommended Approach

1. **Immediate:** Document current behavior (this report)
2. **Week 1-2:** Standardize Python code to use `datetime.now(timezone.utc)`
3. **Week 3-4:** Audit all SQL queries for timezone assumptions
4. **Future:** Evaluate whether to migrate database defaults (significant effort)

---

## 9. Files Requiring Changes (If Approved)

### Python Files (Medium Priority)

| File | Changes Needed |
|------|----------------|
| `bin/pipeline/refresh_spot_positions.py` | Replace `utcnow()` with `now(timezone.utc)` |
| `lib/tradelens/services/stops.py` | Replace `utcnow()` with `now(timezone.utc)` |
| `lib/tradelens/locking/app_lock.py` | Replace `utcnow()` with `now(timezone.utc)` |
| `lib/tradelens/api/health.py` | Replace `utcnow()` with `now(timezone.utc)` |
| `bin/tools/lockctl.py` | Replace `utcnow()` with `now(timezone.utc)` |
| `bin/engine/alert_engine.py` | Replace `utcnow()` with `now(timezone.utc)` |

### Logging Configuration (Low Priority)

| File | Changes Needed |
|------|----------------|
| `bin/server/level_guard_daemon.py` | Add UTC indicator to log format |
| `bin/server/pipeline_daemon.py` | Add UTC indicator to log format |
| `bin/mdsync.py` | Add UTC indicator to log format |

### Documentation (High Priority)

| File | Action |
|------|--------|
| `etc/schema.md` | Add timezone column to schema documentation |
| `CLAUDE.md` | Add timezone conventions section |

---

## 10. Verification Steps

After any changes:

1. **Check Python imports:**
   ```bash
   grep -r "from datetime import" --include="*.py" | grep -v timezone
   ```

2. **Verify no `fromtimestamp()` usage:**
   ```bash
   grep -r "fromtimestamp" --include="*.py" | grep -v utcfromtimestamp
   ```

3. **Test timestamp generation:**
   ```python
   from datetime import datetime, timezone
   print(f"UTC: {datetime.now(timezone.utc)}")
   print(f"Local: {datetime.now()}")
   # Should show 1-hour difference in CET
   ```

4. **Query database comparison:**
   ```sql
   SELECT
       CURRENT_TIMESTAMP as server_utc,
       (SELECT MAX(exchange_created_at) FROM order_leg_hist) as exchange_utc
   ```

---

## Appendix A: Complete File Reference

### Files That Previously Used `getdate()` in SQL (Historical)

> **Note**: After the PostgreSQL migration (March 2026),
> all `getdate()` calls were replaced with `CURRENT_TIMESTAMP`.

```
migrations/007_multi_account_support.sql
migrations/018_spot_balance_correction.sql
migrations/024_add_tag_definition.sql
migrations/035_push_subscription.sql
telegram_signals.py (lines 509, 644-645, 671-672)
bin/engine/alert_engine.py (line 485)
```

### Files Using `datetime.utcnow()`

```
lib/tradelens/services/data_status.py:25
lib/tradelens/services/stops.py:91
lib/tradelens/locking/app_lock.py (6 occurrences)
lib/tradelens/api/health.py (15+ occurrences)
lib/tradelens/core/logging.py:29
bin/pipeline/refresh_spot_positions.py (3 occurrences)
bin/pipeline/refresh_order_leg_live.py (multiple)
bin/pipeline/refresh_order_leg_hist.py (~25 occurrences)
bin/tools/lockctl.py (2 occurrences)
bin/engine/alert_engine.py (2 occurrences)
```

### Files Using `datetime.now(timezone.utc)`

```
bin/server/level_guard_daemon.py (lines 337, 544, 578)
lib/tradelens/services/level_guard.py:190
bin/pipeline/refresh_trade_journal.py:2663
lib/tradelens/api/ideas.py (lines 1112, 1409, 1726)
telegram_signals.py:594
tests/unit/test_level_guard.py (14 occurrences)
```
