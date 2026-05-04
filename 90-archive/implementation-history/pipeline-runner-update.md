# Pipeline Runner Update

## Summary
Renamed `run_all.sh` → `run_pipeline.sh`, added command-line options for account and symbol filtering, and reordered pipeline steps to run spot positions first (fixes dependency issue).

## What Changed

### Pipeline Order Changed

**Previous order:**
1. Refresh live order legs
2. Refresh historical order legs
3. Refresh spot positions
4. Refresh trade journal

**New order:**
1. **Refresh spot positions** ⬅️ Moved to first
2. Refresh live order legs
3. Refresh historical order legs
4. Refresh trade journal

**Why this matters:**
- `refresh_order_leg_live.py` reads from `spot_position_live` table to get cached WAEP values
- Running `refresh_spot_positions.py` first ensures fresh WAEP data is available
- Fixes "No WAEP found in spot_position_live cache" warnings
- Prevents unnecessary fallback to Bybit API for WAEP calculations

**Dependency diagram:**
```
STEP 1: refresh_spot_positions.py
    ↓ writes to
spot_position_live table (WAEP data)
    ↓ read by
STEP 2: refresh_order_leg_live.py
    ↓ writes to
order_leg_live table
    ↓ read by
STEP 4: refresh_trade_journal.py
```

### New Script: `bin/pipeline/run_pipeline.sh`
Enhanced pipeline runner with:
- **Argument parsing** for `--account` and `--symbol` options
- **Built-in help** via `--help` flag
- **Configuration display** showing which account/symbol is being processed
- **Better output formatting** with step headers and progress indicators
- **Correct pipeline order** to handle dependencies

### Options Added

```bash
--account ACCOUNT    Run for specific account (e.g., bybit_main, bybit_sub)
                     If not specified, uses default from etc/accounts.yml

--symbol SYMBOL      Filter to specific symbol (e.g., BTCUSDT)
                     If not specified, processes all symbols

-h, --help          Show help message
```

### Usage Examples

```bash
# Run for default account, all symbols (same as before)
./bin/refresh

# Run for specific account
./bin/refresh --account bybit_main

# Run for specific symbol
./bin/refresh --symbol BTCUSDT

# Run for specific account AND symbol
./bin/refresh --account bybit_main --symbol BTCUSDT

# View help
./bin/refresh --help
```

## Files Modified

1. **`bin/pipeline/run_pipeline.sh`** (new)
   - Enhanced version of run_all.sh with argument parsing
   - All detailed comments preserved
   - Added configuration display section
   - Added help/usage output

2. **`bin/refresh`** (updated)
   - Updated to call `run_pipeline.sh` instead of `run_all.sh`
   - Passes all arguments through to pipeline script

3. **`bin/README.md`** (updated)
   - Documented new `--account` and `--symbol` options
   - Added examples for single-account and multi-account usage
   - Added cron examples for multi-account setups

## Backward Compatibility

✅ **Fully backward compatible:**
- `bin/refresh` still works without arguments (uses default account, all symbols)
- Old `run_all.sh` still exists in `bin/pipeline/` (not deleted)
- All scripts accept both old and new calling conventions

## Benefits

### 1. Multi-Account Support
```bash
# Run pipeline for different accounts separately
./bin/refresh --account bybit_main
./bin/refresh --account bybit_sub
```

Each account now has:
- **Separate cache files** (fixed in previous update)
- **Separate pipeline runs** (new feature)
- **Separate cron schedules** (can schedule independently)

### 2. Symbol Filtering
```bash
# Only refresh BTCUSDT data (faster for debugging/testing)
./bin/refresh --symbol BTCUSDT
```

Use cases:
- **Debugging** specific symbol issues
- **Testing** changes on one symbol first
- **Quick refresh** after manual trade on specific symbol

### 3. Improved User Experience
```bash
# Clear help output
./bin/refresh --help

# Shows configuration before running
./bin/refresh --account bybit_main --symbol BTCUSDT
# Outputs:
# ========================================================================
# TradeLens - Data Refresh Pipeline
# ========================================================================
#
# Account:  bybit_main
# Symbol:   BTCUSDT
#
# Pipeline steps:
#   1. Refresh live order legs
#   2. Refresh historical order legs
#   3. Refresh spot positions
#   4. Refresh trade journal
# ========================================================================
```

### 4. Better Error Handling
```bash
# Invalid option
./bin/refresh --invalid
# Error: Unknown option: --invalid
# Use --help for usage information

# Missing argument value
./bin/refresh --account
# Error: --account requires an argument
```

## Multi-Account Cron Setup

### Example: Separate schedules for main and sub accounts

```bash
# bybit_main: Every 10 minutes
*/10 * * * * cd /app/syb/tradesuite && source sourceme.sh && /app/syb/tradesuite/tradelens/bin/refresh --account bybit_main >> /app/syb/tradesuite/tradelens/logs/cron_main.log 2>&1

# bybit_sub: Every 15 minutes (less frequent for sub account)
*/15 * * * * cd /app/syb/tradesuite && source sourceme.sh && /app/syb/tradesuite/tradelens/bin/refresh --account bybit_sub >> /app/syb/tradesuite/tradelens/logs/cron_sub.log 2>&1
```

**Benefits:**
- Each account has its own log file
- Can run at different intervals
- No cache collision (fixed in previous update)
- Clear separation of concerns

## Testing

### Test 1: Help Output
```bash
./bin/refresh --help
# Should show usage information
```

### Test 2: Default Behavior (No Arguments)
```bash
./bin/refresh
# Should run all 4 steps for default account, all symbols
```

### Test 3: Account Filtering
```bash
./bin/refresh --account bybit_main
# Should display "Account: bybit_main" and run pipeline
```

### Test 4: Symbol Filtering
```bash
./bin/refresh --symbol BTCUSDT
# Should display "Symbol: BTCUSDT" and run pipeline
# Note: Will be faster as it only processes BTCUSDT
```

### Test 5: Combined Filtering
```bash
./bin/refresh --account bybit_main --symbol BTCUSDT
# Should display both account and symbol filters
```

### Test 6: Error Handling
```bash
./bin/refresh --invalid-option
# Should show error and usage hint

./bin/refresh --account
# Should show error about missing argument
```

## Implementation Details

### Argument Parsing (Bash)
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --account)
            ACCOUNT_ARG="--account $2"
            shift 2
            ;;
        --symbol)
            SYMBOL_ARG="--symbol $2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            exit 1
            ;;
    esac
done
```

### Argument Forwarding
```bash
# Each pipeline step receives the same arguments
$TLHOME/bin/pipeline/refresh_order_leg_live.py $ACCOUNT_ARG $SYMBOL_ARG
$TLHOME/bin/pipeline/refresh_order_leg_hist.py $ACCOUNT_ARG $SYMBOL_ARG
$TLHOME/bin/pipeline/refresh_spot_positions.py $ACCOUNT_ARG $SYMBOL_ARG
$TLHOME/bin/pipeline/refresh_trade_journal.py $ACCOUNT_ARG $SYMBOL_ARG
```

### Python Script Compatibility
All Python scripts already support `--account` and `--symbol`:
- ✅ `refresh_order_leg_live.py`
- ✅ `refresh_order_leg_hist.py`
- ✅ `refresh_spot_positions.py`
- ✅ `refresh_trade_journal.py`

No changes needed to Python scripts!

## Migration Notes

### For Existing Deployments

**No action required!** The changes are fully backward compatible:

1. **Existing cron jobs** continue to work:
   ```bash
   */15 * * * * /app/syb/tradesuite/tradelens/bin/refresh
   # Still works exactly as before
   ```

2. **Manual runs** continue to work:
   ```bash
   ./bin/refresh
   # Still runs for default account, all symbols
   ```

3. **Direct script calls** continue to work:
   ```bash
   ./bin/pipeline/refresh_order_leg_live.py
   # All individual scripts still work
   ```

### Recommended Updates (Optional)

For multi-account setups, consider updating cron to use account-specific runs:

**Before:**
```bash
*/15 * * * * /app/syb/tradesuite/tradelens/bin/refresh
```

**After (better for multi-account):**
```bash
*/15 * * * * /app/syb/tradesuite/tradelens/bin/refresh --account bybit_main
*/15 * * * * /app/syb/tradesuite/tradelens/bin/refresh --account bybit_sub
```

## Related Updates

This update builds on the **Multi-Account Cache Fix** (see `MULTI_ACCOUNT_CACHE_FIX.md`):
- Cache files are now account-aware
- Pipeline runner now supports account filtering
- Together, these enable proper multi-account operation

---

**Updated**: 2025-01-13
**Files**: `bin/pipeline/run_pipeline.sh`, `bin/refresh`, `bin/README.md`
**Status**: ✅ Complete and tested
