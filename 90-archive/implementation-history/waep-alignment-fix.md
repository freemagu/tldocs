# WAEP Line Alignment Fix

## Problem Summary

The WAEP (Weighted Average Entry Price) line was showing visual gaps between candles and causing strange spacing on the chart. This occurred because leg timestamps (e.g., 10:06:29, 10:07:12) were not aligned to candle boundaries (10:06:00, 10:07:00), causing Lightweight Charts to expand the time scale and insert virtual points.

## Solution

Implemented **time snapping** to align all WAEP line points to the same candle grid as the candlestick data.

### Changes Made

1. **Added utility functions** (`trade-journal-chart.tsx`):
   - `getCandleDurationSeconds(interval)`: Converts timeframe string to duration in seconds
     - '1' → 60s (1 minute)
     - '5' → 300s (5 minutes)
     - '15' → 900s (15 minutes)
     - '60' → 3600s (60 minutes)
     - 'D' → 86400s (1 day)

   - `snapToCandle(timestamp, candleDuration)`: Snaps a timestamp to candle boundary
     - Formula: `Math.floor(timestamp / candleDuration) * candleDuration`
     - Example: For 1m candles (60s), timestamp 10:06:29 → 10:06:00

2. **Updated WAEP line building logic**:
   - Each leg's `filled_at` timestamp is now snapped to the current timeframe's candle boundary
   - Multiple legs in the same candle bucket are deduplicated (last WAEP value wins)
   - WAEP data is sorted chronologically before being passed to the chart
   - Added comprehensive debug logging to verify snapping behavior

3. **Fixed useEffect dependencies**:
   - Added `interval` to the dependency array
   - This ensures WAEP line is recalculated when timeframe changes
   - Previously: `[candles, legs]`
   - Now: `[candles, legs, interval]`

4. **Kept markers at precise times**:
   - Leg markers (ENTRY, DCA, TP, SL) remain at exact `filled_at` timestamps
   - This is intentional - markers can be "off-grid" to show intra-candle position
   - Only series data (candles, WAEP, stop lines) must use the same time grid

## Example Behavior

### Before Fix
```
ENTRY filled at 10:06:29 → WAEP point at 10:06:29
DCA filled at 10:07:12   → WAEP point at 10:07:12
Candles at:              → 10:06:00, 10:07:00, 10:08:00, ...

Result: Chart shows gaps because 10:06:29 and 10:07:12 don't align with candle grid
```

### After Fix (1m timeframe)
```
ENTRY filled at 10:06:29 → Snapped to 10:06:00 → WAEP point at 10:06:00
DCA filled at 10:07:12   → Snapped to 10:07:00 → WAEP point at 10:07:00
Candles at:              → 10:06:00, 10:07:00, 10:08:00, ...

Result: WAEP line aligns perfectly with candle grid, no gaps
```

### After Fix (5m timeframe)
```
ENTRY filled at 10:06:29 → Snapped to 10:05:00 → WAEP point at 10:05:00
DCA filled at 10:07:12   → Snapped to 10:05:00 → WAEP point at 10:05:00 (overwrites ENTRY)
Candles at:              → 10:05:00, 10:10:00, 10:15:00, ...

Result: Both legs fall in same 5m candle, DCA WAEP value is used
```

## Testing

### Manual Testing Steps

1. **Open Trade Journal**:
   ```bash
   cd /app/syb/tradesuite/tradelens/frontend/web
   npm run dev
   # Navigate to Trade Journal page
   ```

2. **Select a trade with multiple legs** (preferably ENTRY + DCA on SOLUSDT):
   - Example: ENTRY at 10:06:29, DCA at 10:07:12

3. **Test 1m timeframe**:
   - Select "1m" timeframe
   - Open browser console (F12)
   - Look for debug logs:
     ```
     Leg 1 (entry): filled_at=2025-01-20T10:06:29Z -> snapped to 2025-01-20T10:06:00Z
     Leg 2 (dca): filled_at=2025-01-20T10:07:12Z -> snapped to 2025-01-20T10:07:00Z
     WAEP data: 2 points (snapped to 1 timeframe, 60s buckets)
     ```
   - Verify: WAEP line aligns with candle boundaries, no gaps

4. **Test 5m timeframe**:
   - Select "5m" timeframe
   - Check console logs show snapping to 5m boundaries
   - Verify: If both legs fall in same 5m candle, only 1 WAEP point is shown

5. **Test timeframe switching**:
   - Switch between 1m, 5m, 15m, 60m, 1D
   - Verify: WAEP line recalculates each time (due to `interval` dependency)
   - Verify: No gaps appear on any timeframe

6. **Visual verification**:
   - WAEP line should appear as a smooth line without gaps
   - Candles should be evenly spaced (no stretched spacing)
   - Markers (ENTRY, DCA, etc.) can appear within candles (this is correct)

### Console Logging

The implementation includes debug logging:

```javascript
console.log(`WAEP data: ${waepData.length} points (snapped to ${interval} timeframe, ${candleDuration}s buckets)`)
console.log('First WAEP point:', waepData[0])
console.log('Last WAEP point:', waepData[waepData.length - 1])
console.log(`Leg 1 (entry): filled_at=... -> snapped to ...`)
```

These logs help verify:
- Correct number of WAEP points after deduplication
- Proper snapping behavior for each leg
- Time alignment with candle grid

## Code Quality

### Comments Added

Clear documentation explaining the fix:

```typescript
// IMPORTANT:
// WAEP line points must be aligned to the same time buckets as the candle series.
// We snap each leg.filled_at to the candle timeframe (e.g. 1m = 60s) to avoid
// Lightweight Charts creating "gaps" and stretched spacing on the time scale.
```

### Clean Implementation

- **Centralized logic**: Single `getCandleDurationSeconds()` function for all timeframes
- **Efficient deduplication**: Using `Map` to automatically handle multiple legs in same candle
- **Reusable utilities**: Functions can be extracted to a separate module if needed elsewhere
- **No backend changes**: All changes are front-end only, backend WAEP logic unchanged

## Files Modified

1. `/app/syb/tradesuite/tradelens/frontend/web/src/components/journal/trade-journal-chart.tsx`
   - Added `getCandleDurationSeconds()` function
   - Added `snapToCandle()` function
   - Refactored WAEP line building logic
   - Fixed useEffect dependencies
   - Added debug logging

## Known Limitations

1. **Step visual**:
   - Lightweight Charts doesn't have a built-in "step line" type
   - WAEP line connects bucket points directly (linear interpolation)
   - This is acceptable - the key requirement is alignment, not perfect step rendering

2. **Daily timeframe edge cases**:
   - Daily candles use 86400s buckets (UTC-based)
   - May not align perfectly with timezone-specific days
   - This is a Lightweight Charts limitation, not specific to this fix

## Future Improvements

1. **Extract utilities to separate file**:
   - Create `lib/chart-utils.ts` for `getCandleDurationSeconds` and `snapToCandle`
   - Reuse across multiple chart components if needed

2. **Step line approximation**:
   - Could add intermediate points to create true step effect
   - E.g., for each WAEP change, add point at (nextTime - 1, previousValue)

3. **Remove debug logging**:
   - Once thoroughly tested in production, reduce console logging verbosity

## References

- **Lightweight Charts Time Scale**: https://tradingview.github.io/lightweight-charts/docs/api/interfaces/TimeScaleOptions
- **Series Data Requirements**: All series on the same chart must use consistent time values
- **Backend WAEP Logic**: `lib/tradelens/utils/waep_tracker.py` (unchanged)
