# Multi-Account Cache Fix

## Problem (Before)
Cache files were **NOT** account-aware, causing conflicts when running the refresh pipeline for multiple accounts:

```
cache/
├── global_order_hist_linear.json     ← Shared by ALL accounts!
├── global_order_hist_inverse.json    ← Cache ping-pongs between accounts
└── global_order_hist_spot.json       ← Last account to run wins
```

**Issues:**
- Running for `bybit_main` creates cache with timestamp T1
- Running for `bybit_sub` overwrites cache with timestamp T2
- Next run for `bybit_main` uses T2 (wrong!) → skips/refetches data

## Solution (After)
Cache files now include the account name in the filename:

```
cache/
├── global_order_hist_linear_bybit_main.json      ← bybit_main account
├── global_order_hist_linear_bybit_sub.json       ← bybit_sub account
├── global_order_hist_inverse_bybit_main.json
├── global_order_hist_inverse_bybit_sub.json
├── global_order_hist_spot_bybit_main.json
└── global_order_hist_spot_bybit_sub.json
```

Each account now tracks its own incremental progress independently!

## Cache File Structure

Example: `cache/global_order_hist_linear_bybit_main.json`
```json
{
  "account_name": "bybit_main",
  "last_order_time_ms": 1705318200000,
  "last_order_time_utc": "2025-01-15 10:30:00.123",
  "updated_at": "2025-01-15 10:35:00"
}
```

**New field:** `account_name` is now stored in the cache for validation.

## Running Multi-Account Pipelines

### Sequential (Safe)
```bash
# Each account uses its own cache - no conflicts!
bin/pipeline/refresh_order_leg_hist.py --account bybit_main
bin/pipeline/refresh_order_leg_hist.py --account bybit_sub
```

### Parallel (Now Safe Too!)
```bash
# Can even run in parallel - separate cache files
bin/pipeline/refresh_order_leg_hist.py --account bybit_main &
bin/pipeline/refresh_order_leg_hist.py --account bybit_sub &
wait
```

### With Default Account
```bash
# Uses default account from etc/accounts.yml
bin/pipeline/refresh_order_leg_hist.py
# Creates: cache/global_order_hist_*_{default_account}.json
```

## Backward Compatibility

**Old cache files are ignored:**
- If you have `cache/global_order_hist_linear.json` (old format)
- New code looks for `cache/global_order_hist_linear_{account_name}.json`
- Old cache is not used → First run does full fetch
- New account-aware cache is created

**No data loss:** Database remains correct (was always account-aware via `account_id`).

## Code Changes

### Function Signatures Updated
```python
# Before
def get_cache_path(category: str) -> Path:
def load_global_cache(category: str) -> Optional[int]:
def save_global_cache(category: str, timestamp_ms: int, ...) -> None:

# After
def get_cache_path(category: str, account_name: str) -> Path:
def load_global_cache(category: str, account_name: str) -> Optional[int]:
def save_global_cache(category: str, account_name: str, timestamp_ms: int, ...) -> None:
```

### All Call Sites Updated
- `get_last_order_time()` now requires `account_name` parameter
- `get_order_history()` now passes `account_name` to cache functions
- `main()` resolves account name early and passes throughout

## Testing

### Test 1: Verify Separate Caches
```bash
# Run for bybit_main
./bin/pipeline/refresh_order_leg_hist.py --account bybit_main

# Check cache was created
ls -lh cache/global_order_hist_*_bybit_main.json

# Run for bybit_sub
./bin/pipeline/refresh_order_leg_hist.py --account bybit_sub

# Check separate cache was created
ls -lh cache/global_order_hist_*_bybit_sub.json

# Verify both exist and have different timestamps
cat cache/global_order_hist_linear_bybit_main.json
cat cache/global_order_hist_linear_bybit_sub.json
```

### Test 2: Verify Incremental Loading
```bash
# First run - full fetch
./bin/pipeline/refresh_order_leg_hist.py --account bybit_main --debug
# Look for: "No global cache found, will do full fetch"

# Second run - incremental
./bin/pipeline/refresh_order_leg_hist.py --account bybit_main --debug
# Look for: "Using global cache for linear/bybit_main: 2025-01-15..."
# Look for: "Using incremental loading: fetching orders since..."
```

### Test 3: Verify No Cross-Account Pollution
```bash
# Run for bybit_main (T1 = 10:00:00)
./bin/pipeline/refresh_order_leg_hist.py --account bybit_main

# Run for bybit_sub (T2 = 09:00:00, earlier than T1)
./bin/pipeline/refresh_order_leg_hist.py --account bybit_sub

# Run for bybit_main again - should still use T1, NOT T2!
./bin/pipeline/refresh_order_leg_hist.py --account bybit_main --debug
# Verify it uses bybit_main's cache, not bybit_sub's
```

## Migration Notes

**Existing deployments:**
1. Old cache files (`cache/global_order_hist_*.json`) can be deleted or ignored
2. First run after upgrade will do a full fetch (normal incremental loading recovery)
3. New account-aware caches will be created automatically
4. No data loss - database was always account-aware

**Cleanup (optional):**
```bash
# Remove old cache files (optional - they're ignored anyway)
cd /app/syb/tradesuite/tradelens
rm cache/global_order_hist_linear.json 2>/dev/null
rm cache/global_order_hist_inverse.json 2>/dev/null
rm cache/global_order_hist_spot.json 2>/dev/null
```

## Benefits

✅ **Correctness**: Each account tracks its own progress
✅ **Performance**: Incremental loading works correctly for all accounts
✅ **Parallelism**: Can run multiple accounts simultaneously
✅ **Clarity**: Cache filenames show which account they belong to
✅ **Debugging**: Easy to see per-account cache state

---

**Fixed**: 2025-01-13
**Files Modified**: `bin/pipeline/refresh_order_leg_hist.py`, `bin/pipeline/run_all.sh`
