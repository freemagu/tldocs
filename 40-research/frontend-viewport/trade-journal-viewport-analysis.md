# Trade Journal Chart Viewport Analysis

**Date**: 2025-12-03
**Component**: `frontend/web/src/components/journal/trade-journal-chart.tsx`
**Status**: Analysis only (no code changes)

---

## 1. Problem Description

### Current Bug

On the trade journal execution chart, the viewport exhibits problematic behavior where **the last candle is snapped hard against the right edge of the chart** with no visible margin or "breathing room" to the right.

### When It Occurs

1. **Initial Load**: When a trade journal row is first expanded and the chart renders with candle data, the chart's `fitContent()` call positions the viewport such that the rightmost candle touches the right edge of the visible area.

2. **Timeframe Changes**: When the user changes the interval (e.g., from 15m to 1h), the viewport resets via `fitContent()` and again places the last candle flush against the right edge.

3. **Lookback/Forward Setting Changes**: When `lookbackCandles` or `maxForwardCandles` values are adjusted, the candle range changes, triggering `hasUserInteractedRef = false` and a subsequent `fitContent()` call that snaps to the right edge.

### Visual Impact

"Snapped to the right edge" means:
- The last (most recent) candle in the dataset is positioned at the rightmost pixel of the chart viewport
- There is no empty space or margin between the last candle and the chart's right boundary
- The current price line extends directly to the edge
- This feels cramped and makes it difficult to see the current candle clearly or anticipate price movement

---

## 2. Code Locations Inspected

### Primary Files

| File | Purpose in Viewport Behavior |
|------|------------------------------|
| `frontend/web/src/components/journal/trade-journal-chart.tsx` | **Main chart component**. Contains all viewport tracking refs, detection of interval/range changes, `fitContent()` calls, and `setVisibleLogicalRange()` calls. |
| `frontend/web/src/components/journal/trade-journal-expanded-row.tsx` | **Parent component**. Manages `interval`, `lookbackCandles`, `maxForwardCandles` state. Passes these as props along with `candles` array from polling query. Does NOT directly manipulate viewport. |

### Supporting Files

| File | Relevance |
|------|-----------|
| `frontend/web/src/lib/timezone.ts` | Provides `toUnixTimestamp()` used for timestamp conversion when building WAEP/order levels. Not directly involved in viewport logic. |
| `frontend/web/src/lib/use-polling.ts` | Wraps React Query with 5-second polling interval. Causes periodic data refreshes that trigger the data-update `useEffect`. |
| `frontend/web/src/components/journal/secondary-chart-panel.tsx` | Contains TradingView/Velo iframes. No shared viewport state with the main chart. |

---

## 3. Current Decision Logic

### 3.1 State Variables (Refs)

The component uses four refs to track viewport state:

```
hasUserInteractedRef: boolean (default: false)
  - Tracks whether user has panned/zoomed since chart creation
  - Set to true when visible range changes AND isFirstDataLoadRef is false
  - Reset to false on: interval change, candle range change, Reset View button

isFirstDataLoadRef: boolean (default: true)
  - Tracks whether this is the first data load
  - Set to false after the first fitContent() is scheduled
  - Used to prevent marking the initial fitContent() as user interaction

lastIntervalRef: string
  - Tracks the previous interval value
  - Used to detect interval/timeframe changes

lastCandleRangeRef: { first: number, last: number } | null
  - Tracks first and last candle timestamps
  - Used to detect when candle range changes significantly (> 1 candle duration)
```

### 3.2 Pseudocode of Current Viewport Effect

```
ON_DATA_UPDATE(candles, legs, interval, showOrderLevels, showWaepWaxp, legVisibility):

  # Phase 1: Detect changes
  intervalChanged = (lastIntervalRef !== interval)
  IF intervalChanged:
    lastIntervalRef = interval
    hasUserInteractedRef = false
    lastCandleRangeRef = null

  candleRangeChanged = false
  IF candles.length > 0:
    currentRange = { first: candles[0].time, last: candles[last].time }
    IF lastCandleRangeRef exists:
      candleDuration = getCandleDurationSeconds(interval)
      firstChanged = |currentRange.first - prevRange.first| > candleDuration
      lastChanged = |currentRange.last - prevRange.last| > candleDuration
      IF firstChanged OR lastChanged:
        candleRangeChanged = true
        hasUserInteractedRef = false
    lastCandleRangeRef = currentRange

  # Phase 2: Capture current viewport (only if user has interacted and no reset needed)
  savedLogicalRange = null
  IF hasUserInteractedRef AND NOT intervalChanged AND NOT candleRangeChanged:
    savedLogicalRange = chart.timeScale().getVisibleLogicalRange()

  # Phase 3: Update all chart data (candles, WAEP, WAXP, markers, order levels)
  ... [data update code] ...

  # Phase 4: Viewport restoration/fitting
  IF savedLogicalRange AND hasUserInteractedRef:
    # BRANCH A: Restore user's viewport
    chart.timeScale().setVisibleLogicalRange(savedLogicalRange)

  ELSE IF isFirstDataLoadRef OR intervalChanged OR candleRangeChanged:
    # BRANCH B: First load or settings changed - fitContent with RAF
    isInitial = isFirstDataLoadRef
    requestAnimationFrame(() => {
      IF isInitial:
        # Double RAF for initial load
        requestAnimationFrame(() => {
          chart.timeScale().fitContent()
        })
      ELSE:
        chart.timeScale().fitContent()
    })
    isFirstDataLoadRef = false

  ELSE IF NOT hasUserInteractedRef:
    # BRANCH C: Fallback - user hasn't interacted, fitContent
    requestAnimationFrame(() => {
      chart.timeScale().fitContent()
    })

  # BRANCH D (implicit): hasUserInteractedRef is true but savedLogicalRange is null
  # This shouldn't happen but would result in no viewport change
```

### 3.3 Decision Tree (Bullet Points)

**On each data update (useEffect dependency change):**

1. **Detect interval change?**
   - YES → Reset `hasUserInteractedRef = false`, `lastCandleRangeRef = null`

2. **Detect candle range change (> 1 candle difference)?**
   - YES → Reset `hasUserInteractedRef = false`, set `candleRangeChanged = true`

3. **Should we capture savedLogicalRange?**
   - Only if ALL of:
     - `hasUserInteractedRef === true`
     - `intervalChanged === false`
     - `candleRangeChanged === false`
   - If captured, save current `getVisibleLogicalRange()`

4. **[Data update happens here]**

5. **Viewport decision:**
   - **IF** `savedLogicalRange` exists **AND** `hasUserInteractedRef`:
     - → Restore via `setVisibleLogicalRange(savedLogicalRange)`
   - **ELSE IF** `isFirstDataLoadRef` **OR** `intervalChanged` **OR** `candleRangeChanged`:
     - → Schedule `fitContent()` via RAF (double RAF if initial)
     - → Set `isFirstDataLoadRef = false`
   - **ELSE IF** `!hasUserInteractedRef`:
     - → Schedule `fitContent()` via RAF (fallback)
   - **ELSE**:
     - → No viewport change (implicit, shouldn't normally reach)

### 3.4 User Interaction Detection

Located in the chart initialization `useEffect` (first one):

```javascript
const handleVisibleRangeChange = () => {
  if (!isFirstDataLoadRef.current) {
    hasUserInteractedRef.current = true
  }
}
chart.timeScale().subscribeVisibleLogicalRangeChange(handleVisibleRangeChange)
```

**Key point**: The `fitContent()` call itself triggers this subscription, but the guard `!isFirstDataLoadRef.current` is supposed to prevent marking it as user interaction. However, `isFirstDataLoadRef` is set to `false` **before** the RAF-deferred `fitContent()` executes, creating a race condition.

### 3.5 Reset View Button

```javascript
const handleResetView = () => {
  chart.timeScale().fitContent()
  hasUserInteractedRef.current = false
}
```

---

## 4. Hypotheses for Root Cause

### Hypothesis 1: `fitContent()` Has No Right Margin

**Evidence**: Lightweight Charts' `fitContent()` method fits all data points into the visible area with minimal padding. It does not add a configurable right-hand margin by default.

**Result**: When `fitContent()` is called, the last candle's right edge aligns precisely with the chart's right boundary.

**Code location**: Every call to `chart.timeScale().fitContent()` in the viewport decision branches (lines ~847-880).

### Hypothesis 2: RAF Timing Creates Race with Interaction Detection

**Evidence**: The code sets `isFirstDataLoadRef.current = false` (line ~870) **before** the `requestAnimationFrame` callback executes `fitContent()`. This means:

1. `isFirstDataLoadRef = true` initially
2. Data arrives, code schedules RAF with `isInitial = true`
3. Code immediately sets `isFirstDataLoadRef = false`
4. RAF executes, calls `fitContent()`
5. `fitContent()` triggers `subscribeVisibleLogicalRangeChange` handler
6. Handler checks `!isFirstDataLoadRef.current` → this is now `true` (since we set it to `false`)
7. Handler sets `hasUserInteractedRef = true` erroneously

**Result**: After initial load, the system incorrectly thinks the user has interacted, which may affect subsequent data refreshes.

**Code location**:
- Line ~870: `isFirstDataLoadRef.current = false`
- Lines ~854-868: RAF scheduling
- Lines ~529-535: Interaction detection handler

### Hypothesis 3: No Distinction Between "Auto-fit" and "User-initiated" Range Changes

**Evidence**: The `subscribeVisibleLogicalRangeChange` handler fires for ALL viewport changes, including:
- User pan/zoom (should mark as interacted)
- `fitContent()` calls (should NOT mark as interacted)
- `setVisibleLogicalRange()` calls (should NOT mark as interacted)

The only guard is `!isFirstDataLoadRef.current`, which doesn't cover subsequent auto-fits on interval/range change.

**Result**: After an interval change triggers `fitContent()`, the system may incorrectly mark `hasUserInteractedRef = true`, preventing future auto-fits.

**Code location**: Lines ~529-535 (handleVisibleRangeChange).

### Hypothesis 4: Candle Data Includes Extension Points

**Evidence**: The code adds 50 "extension" candles to `fillsData` (lines ~777-788) for order level line visibility. These invisible extension points extend the chart's logical time range.

**Result**: When `fitContent()` is called, it fits the entire range including extensions, potentially affecting the apparent position of the last real candle.

**Code location**: Lines ~777-788 (invisible time extension points).

### Hypothesis 5: Double RAF May Not Solve Timing on All Browsers/Loads

**Evidence**: Double `requestAnimationFrame` is used only for initial load (`isInitial`). This is a timing heuristic that may not be reliable across all scenarios.

**Result**: `fitContent()` may execute before the chart has fully rendered, leading to incorrect viewport calculation.

**Code location**: Lines ~856-863 (double RAF for initial load).

---

## 5. Proposed Fix Strategy (Plan Only)

### Guiding Principles

1. **User interaction is sacred**: Once the user has panned or zoomed, never auto-fit again unless they explicitly click "Reset View"
2. **Auto-fit is controlled**: Only run auto-fit before any user interaction occurs
3. **Right margin is required**: After any auto-fit, add breathing room so the last candle isn't flush against the right edge
4. **Minimize timing hacks**: Avoid RAF unless strictly necessary; prefer synchronous approaches where possible

### Implementation Steps

#### Step 1: Create a Dedicated Auto-Fit Helper

Create a helper function that:
1. Calls `fitContent()` to fit all data
2. Then adjusts the visible range to add a right margin (e.g., shift the right boundary by 5-10 candles worth of space)

**Pseudo-implementation**:
```
function fitWithRightMargin(chart, marginBars = 5):
  chart.timeScale().fitContent()
  range = chart.timeScale().getVisibleLogicalRange()
  if range:
    chart.timeScale().setVisibleLogicalRange({
      from: range.from,
      to: range.to + marginBars
    })
```

#### Step 2: Prevent Auto-Fit from Triggering Interaction Detection

Add a ref to track "programmatic viewport change in progress":
```
isProgrammaticViewportChangeRef = useRef(false)
```

In the interaction handler:
```
if (!isFirstDataLoadRef.current && !isProgrammaticViewportChangeRef.current):
  hasUserInteractedRef.current = true
```

Set this ref to `true` before calling `fitContent()` or `setVisibleLogicalRange()`, and reset it after a microtask/RAF.

#### Step 3: Simplify the Viewport Decision Branches

Restructure the viewport logic to be clearer:

```
# After data update:

IF hasUserInteractedRef:
  # User has panned/zoomed - restore their viewport exactly
  IF savedLogicalRange:
    setVisibleLogicalRange(savedLogicalRange)
  # Else: no saved range (shouldn't happen), do nothing

ELSE:
  # User has NOT interacted yet - always auto-fit with margin
  scheduleAutoFitWithMargin()
```

This eliminates the separate branches for `isFirstDataLoadRef`, `intervalChanged`, `candleRangeChanged` because they all result in the same action (auto-fit) when the user hasn't interacted.

#### Step 4: Remove hasUserInteractedRef Reset on Interval/Range Change

Currently, changing interval or candle range resets `hasUserInteractedRef = false`, which forces an auto-fit. This overrides the user's preference to keep their custom viewport.

**Change**: Do NOT reset `hasUserInteractedRef` on interval/range change. If the user has interacted:
- Restore their logical range (which may be off-screen for the new data, but that's their choice)
- OR: Provide a "smart" restoration that maps the old viewport to the new one proportionally

**Alternative**: Keep the reset but make it opt-in via a setting, or only reset on "major" changes (like going from 1m to 1D).

#### Step 5: Handle Empty Candles Gracefully

Add an early return when `candles.length === 0` BEFORE attempting any viewport logic. This is already present but verify it covers all edge cases.

#### Step 6: Remove Double RAF

If Step 2 (programmatic viewport change flag) is implemented correctly, double RAF should be unnecessary. The single RAF (or even synchronous call after `setData`) should suffice.

If timing issues persist, consider using `chart.applyOptions({ autoSize: true })` and waiting for a resize event, or using `chart.timeScale().scrollToPosition(0, false)` after `fitContent()`.

#### Step 7: Add rightOffset to timeScale Options (Optional)

Lightweight Charts supports `rightOffset` in timeScale options, which adds empty space to the right of the last bar:

```javascript
createChart(container, {
  timeScale: {
    rightOffset: 10,  // 10 bars of space to the right
    ...
  }
})
```

This could be set during chart creation and would apply automatically without needing post-fit adjustments.

**Caveat**: `rightOffset` affects the chart at all times, not just during auto-fit. This may or may not be desirable.

---

## 6. Risk / Regression Notes

### Tightly Coupled Areas

| Area | Risk |
|------|------|
| **WAEP/WAXP Lines** | These extend to `waepWaxpExtendedTime` which is 50 candles beyond the last real candle. If viewport logic changes how extensions are handled, these lines might be clipped or not visible. |
| **Order Level Lines** | Same as WAEP/WAXP - they use `extendedEndTime` for unfilled orders. Changes to viewport or extension logic could affect visibility. |
| **Fill Markers** | Markers are attached to `fillsSeriesRef` which has invisible extension points. Viewport changes shouldn't affect marker visibility, but verify. |
| **Secondary Chart Panel** | No direct coupling - TradingView/Velo iframes are independent. However, if viewport logic affects query keys or data flow, there could be indirect effects. |
| **Reset View Button** | Currently calls `fitContent()` and resets `hasUserInteractedRef`. If auto-fit behavior changes, this button should use the same new helper. |
| **Polling Data Refresh** | Every 5 seconds, `candleData` may change (new candle arrives). The viewport logic must handle this without disrupting the user's view. Currently, `savedLogicalRange` handles this, but verify with the new logic. |
| **Snapshot Screenshot** | `chart.takeScreenshot()` captures the current viewport. Changes to viewport logic don't affect this directly, but ensure the user sees what they expect before capturing. |

### Testing Scenarios

1. **Initial load**: Expand a trade row → chart should show all data with right margin
2. **Polling update**: Wait 5+ seconds → chart viewport should NOT change
3. **User pan/zoom**: Pan the chart → subsequent polling should preserve the custom viewport
4. **Interval change (before interaction)**: Change from 15m to 1h → chart should auto-fit with right margin
5. **Interval change (after interaction)**: Pan, then change interval → decide: should it auto-fit or preserve?
6. **Lookback change**: Change lookback from 200 to 500 → chart should auto-fit with right margin
7. **Reset View button**: After panning, click reset → chart should auto-fit with right margin
8. **Empty candles**: Load a trade with no candle data yet → no errors, graceful handling
9. **WAEP/WAXP visibility**: Toggle checkbox → viewport should NOT change
10. **Order levels visibility**: Toggle checkbox → viewport should NOT change

---

## Summary

The root cause is that `fitContent()` has no right margin, and the interaction detection/reset logic has race conditions and unclear branching. The fix should:

1. Add a right margin after auto-fit
2. Use a flag to prevent auto-fit from being detected as user interaction
3. Simplify the decision logic to two clear branches: "user has interacted" vs "user has not interacted"
4. Decide whether interval/range changes should override user interaction (recommend: no, or make it configurable)

**No code changes have been made. This document is analysis only.**
