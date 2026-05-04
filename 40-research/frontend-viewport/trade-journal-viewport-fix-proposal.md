# Trade Journal Viewport Fix Proposal

**Date**: 2025-12-03
**Component**: `frontend/web/src/components/journal/trade-journal-chart.tsx`
**Status**: Proposal for review (no code changes applied)

---

## 1. Context

### The Bug

On the trade journal execution chart, the last candle is **snapped hard against the right edge** of the chart with no visible margin. This occurs on initial load when expanding a trade journal row, and again whenever the user changes the timeframe (interval) or adjusts the lookback/forward candle settings. The result is a cramped view where the most recent price action is flush against the chart boundary.

### Desired Behaviour

The chart should display with a **comfortable right-hand margin** (approximately 5-10 bars of empty space) after any auto-fit operation. Once the user has panned or zoomed the chart, the system should **never auto-fit again** on polling updates, timeframe changes, or range changes - the user's viewport is preserved until they explicitly click the "Reset View" button.

---

## 2. Behavioural Requirements

### Initial Load (before any user interaction)

- [ ] When a trade journal row is expanded, the chart should auto-fit to show all candles.
- [ ] After auto-fit, there should be a visible right-hand margin (~5 bars) so the last candle is not flush against the edge.
- [ ] The auto-fit operation itself must NOT mark `hasUserInteractedRef` as `true`.

### Polling Updates (every 5 seconds)

- [ ] If the user has NOT interacted: auto-fit with right margin (data may have changed).
- [ ] If the user HAS interacted: restore their saved logical range exactly; do not auto-fit.

### Interval / Timeframe Changes

- [ ] If the user has NOT interacted: auto-fit with right margin for the new timeframe's data.
- [ ] If the user HAS interacted: restore their saved logical range; do NOT reset interaction state; do NOT auto-fit.

### Lookback / Forward Range Changes

- [ ] If the user has NOT interacted: auto-fit with right margin for the new data range.
- [ ] If the user HAS interacted: restore their saved logical range; do NOT reset interaction state; do NOT auto-fit.

### Reset View Button

- [ ] Always performs auto-fit with right margin.
- [ ] Resets `hasUserInteractedRef` to `false` so subsequent polling updates will auto-fit.

### Visibility Toggles (WAEP/WAXP, Order Levels, Leg Checkboxes)

- [ ] These should NOT trigger any viewport change.
- [ ] The existing viewport (user's or auto-fit) should be preserved.

---

## 3. Implementation Plan

The fix modifies `trade-journal-chart.tsx` only. No new files are required.

### Step 1: Add `isProgrammaticViewportChangeRef`

Add a new ref to track when a viewport change is being made programmatically (by our code) versus by user interaction:

```typescript
const isProgrammaticViewportChangeRef = useRef(false)
```

### Step 2: Update Interaction Detection Handler

Modify `handleVisibleRangeChange` in the chart initialization `useEffect` to check the new ref:

```typescript
const handleVisibleRangeChange = () => {
  if (!isProgrammaticViewportChangeRef.current) {
    hasUserInteractedRef.current = true
  }
}
```

This replaces the old `!isFirstDataLoadRef.current` guard, which had timing issues.

### Step 3: Create `fitContentWithMargin` Helper

Add a helper function that:
1. Sets `isProgrammaticViewportChangeRef = true`
2. Calls `fitContent()`
3. Adjusts the visible range to add a right margin
4. Resets `isProgrammaticViewportChangeRef = false` after a microtask

```typescript
const fitContentWithMargin = (chart: IChartApi, marginBars = 5) => {
  isProgrammaticViewportChangeRef.current = true
  chart.timeScale().fitContent()
  const range = chart.timeScale().getVisibleLogicalRange()
  if (range) {
    chart.timeScale().setVisibleLogicalRange({
      from: range.from,
      to: range.to + marginBars,
    })
  }
  // Reset flag after current event loop to catch all triggered range change events
  requestAnimationFrame(() => {
    isProgrammaticViewportChangeRef.current = false
  })
}
```

### Step 4: Simplify Viewport Decision Logic

Replace the existing multi-branch viewport logic at the end of the data `useEffect` with a simple two-branch structure:

**Branch A: User has interacted**
- Restore `savedLogicalRange` if available
- Do NOT call `fitContentWithMargin`

**Branch B: User has NOT interacted**
- Call `fitContentWithMargin`

### Step 5: Remove `hasUserInteractedRef` Reset on Interval/Range Change

Currently, the code resets `hasUserInteractedRef = false` when interval or candle range changes. **Remove these resets** so that user interaction is preserved across all data changes.

The user's viewport preference should be respected until they click "Reset View".

### Step 6: Remove `isFirstDataLoadRef` and Double RAF

With the `isProgrammaticViewportChangeRef` guard in place, we no longer need:
- `isFirstDataLoadRef` (its only purpose was to guard interaction detection)
- Double `requestAnimationFrame` for initial load (the programmatic flag handles it)

### Step 7: Update `handleResetView`

Modify the Reset View button handler to use the new helper:

```typescript
const handleResetView = () => {
  if (chartRef.current) {
    fitContentWithMargin(chartRef.current)
    hasUserInteractedRef.current = false
  }
}
```

### Step 8: Simplify savedLogicalRange Capture

Remove the `intervalChanged` and `candleRangeChanged` guards from savedLogicalRange capture. Always capture if `hasUserInteractedRef` is true:

```typescript
let savedLogicalRange: { from: number; to: number } | null = null
if (hasUserInteractedRef.current) {
  const currentRange = chartRef.current.timeScale().getVisibleLogicalRange()
  if (currentRange) {
    savedLogicalRange = { from: currentRange.from, to: currentRange.to }
  }
}
```

---

## 4. Full Patch (Unified Diff)

**DO NOT APPLY THIS PATCH YET** - it is provided for human review only.

```diff
diff --git a/frontend/web/src/components/journal/trade-journal-chart.tsx b/frontend/web/src/components/journal/trade-journal-chart.tsx
--- a/frontend/web/src/components/journal/trade-journal-chart.tsx
+++ b/frontend/web/src/components/journal/trade-journal-chart.tsx
@@ -314,11 +314,10 @@ export function TradeJournalChart({
   const orderLevelSeriesRefs = useRef<Map<number, ISeriesApi<'Line'>>>(new Map())

   // Viewport preservation: track user interaction and initial load state
   const hasUserInteractedRef = useRef(false)
-  const isFirstDataLoadRef = useRef(true)
+  // Track programmatic viewport changes to avoid marking them as user interaction
+  const isProgrammaticViewportChangeRef = useRef(false)
   // Track the current interval to detect timeframe changes
   const lastIntervalRef = useRef(interval)
-  // Track candle time range to detect when data range changes (e.g., lookback/forward changes)
-  const lastCandleRangeRef = useRef<{ first: number; last: number } | null>(null)

   // Snapshot state
   const [isSnapshotting, setIsSnapshotting] = useState(false)
@@ -423,6 +422,28 @@ export function TradeJournalChart({
     }).format(date)
   }

+  /**
+   * Fit chart content with a right-hand margin for breathing room.
+   * Sets isProgrammaticViewportChangeRef to prevent this from being detected as user interaction.
+   *
+   * @param chart - The chart instance
+   * @param marginBars - Number of bars of empty space to add on the right (default: 5)
+   */
+  const fitContentWithMargin = (chart: IChartApi, marginBars = 5) => {
+    isProgrammaticViewportChangeRef.current = true
+    chart.timeScale().fitContent()
+    const range = chart.timeScale().getVisibleLogicalRange()
+    if (range) {
+      chart.timeScale().setVisibleLogicalRange({
+        from: range.from,
+        to: range.to + marginBars,
+      })
+    }
+    // Reset flag after current event loop to catch all triggered range change events
+    requestAnimationFrame(() => {
+      isProgrammaticViewportChangeRef.current = false
+    })
+  }
+
   useEffect(() => {
     if (!chartContainerRef.current) return

@@ -525,10 +546,9 @@ export function TradeJournalChart({

     // Subscribe to visible range changes to detect user pan/zoom interaction
     // This allows us to preserve the user's viewport on subsequent data refreshes
     const handleVisibleRangeChange = () => {
-      // Mark that user has interacted once any viewport change occurs
-      // (after the initial fitContent which happens on first data load)
-      if (!isFirstDataLoadRef.current) {
+      // Only mark as user interaction if this wasn't a programmatic change
+      if (!isProgrammaticViewportChangeRef.current) {
         hasUserInteractedRef.current = true
       }
     }
@@ -545,8 +565,6 @@ export function TradeJournalChart({
       }
       fillsSeriesRef.current = null
       // Reset interaction tracking on unmount
       hasUserInteractedRef.current = false
-      isFirstDataLoadRef.current = true
-      lastCandleRangeRef.current = null
     }
   }, [])

@@ -556,38 +574,15 @@ export function TradeJournalChart({
     console.log('Chart data update - candles:', candles.length, 'legs:', legs.length)

     // Detect if interval (timeframe) changed - if so, reset viewport tracking
+    // Note: We track this for logging purposes but do NOT reset hasUserInteractedRef
     const intervalChanged = lastIntervalRef.current !== interval
     if (intervalChanged) {
-      console.log('Interval changed from', lastIntervalRef.current, 'to', interval, '- will fit content')
+      console.log('Interval changed from', lastIntervalRef.current, 'to', interval)
       lastIntervalRef.current = interval
-      hasUserInteractedRef.current = false // Reset so we fit content for new timeframe
-      lastCandleRangeRef.current = null // Reset range tracking for new interval
-    }
-
-    // Detect if candle time range changed significantly (e.g., lookback/forward settings changed)
-    // This catches cases where the user adjusts the lookback/forward sliders
-    let candleRangeChanged = false
-    if (candles.length > 0) {
-      const currentRange = { first: candles[0].time, last: candles[candles.length - 1].time }
-      const prevRange = lastCandleRangeRef.current
-
-      if (prevRange) {
-        // Check if either end of the range changed significantly (more than 1 candle)
-        const candleDurationCheck = getCandleDurationSeconds(interval)
-        const firstChanged = Math.abs(currentRange.first - prevRange.first) > candleDurationCheck
-        const lastChanged = Math.abs(currentRange.last - prevRange.last) > candleDurationCheck
-
-        if (firstChanged || lastChanged) {
-          console.log('Candle range changed - first:', prevRange.first, '→', currentRange.first,
-            'last:', prevRange.last, '→', currentRange.last, '- will fit content')
-          candleRangeChanged = true
-          hasUserInteractedRef.current = false // Reset so we fit content for new range
-        }
-      }
-
-      lastCandleRangeRef.current = currentRange
     }

     // Capture current visible range BEFORE updating data (for viewport preservation)
+    // Always capture if user has interacted, regardless of what changed
     let savedLogicalRange: { from: number; to: number } | null = null
-    if (hasUserInteractedRef.current && !intervalChanged && !candleRangeChanged) {
+    if (hasUserInteractedRef.current) {
       const currentRange = chartRef.current.timeScale().getVisibleLogicalRange()
       if (currentRange) {
         savedLogicalRange = { from: currentRange.from, to: currentRange.to }
@@ -839,41 +834,22 @@ export function TradeJournalChart({
       console.log(`Order Levels: ${orderLevelSeriesRefs.current.size} series rendered`)
     }

-    // Viewport handling: preserve user's view on polling updates, fit on first load/interval/range change
-    if (savedLogicalRange && hasUserInteractedRef.current) {
-      // User has panned/zoomed - restore their viewport
+    // Viewport handling: simple two-branch logic
+    // Branch A: User has interacted - restore their viewport exactly
+    if (hasUserInteractedRef.current && savedLogicalRange) {
       console.log('Restoring user viewport:', savedLogicalRange)
+      isProgrammaticViewportChangeRef.current = true
       chartRef.current.timeScale().setVisibleLogicalRange(savedLogicalRange)
-    } else if (isFirstDataLoadRef.current || intervalChanged || candleRangeChanged) {
-      // First load, interval changed, or candle range changed - fit content to show all data
-      // Use double requestAnimationFrame for initial load to ensure chart is fully ready
-      // (chart needs extra time on first render to set up all internal state)
-      console.log('Scheduling fitContent (first load, interval change, or range change)')
-      const chart = chartRef.current
-      const isInitial = isFirstDataLoadRef.current
       requestAnimationFrame(() => {
-        if (!chart) return
-        if (isInitial) {
-          // Double RAF for initial load - chart needs extra frame to fully initialize
-          requestAnimationFrame(() => {
-            if (chart) {
-              console.log('Executing fitContent (initial load, double RAF)')
-              chart.timeScale().fitContent()
-            }
-          })
-        } else {
-          console.log('Executing fitContent (interval/range change)')
-          chart.timeScale().fitContent()
-        }
+        isProgrammaticViewportChangeRef.current = false
       })
-      // Mark first load as complete so future updates preserve viewport
-      isFirstDataLoadRef.current = false
-    } else if (!hasUserInteractedRef.current) {
-      // User hasn't interacted yet - always fit content to ensure proper initial view
-      // This catches edge cases where data changes but none of the above flags are set
-      const chart = chartRef.current
-      requestAnimationFrame(() => {
-        if (chart) {
-          chart.timeScale().fitContent()
-        }
-      })
+    }
+    // Branch B: User has NOT interacted - auto-fit with right margin
+    else if (!hasUserInteractedRef.current) {
+      console.log('Auto-fitting with right margin (user has not interacted)')
+      fitContentWithMargin(chartRef.current)
     }
-    // On background polling updates where user HAS interacted:
-    // Don't call fitContent - preserve user's custom viewport
+    // Branch C (implicit): User has interacted but savedLogicalRange is null
+    // This shouldn't happen, but if it does, do nothing - preserve current view
   }, [candles, legs, interval, showOrderLevels, showWaepWaxp, legVisibility])

   const handleResetView = () => {
     if (chartRef.current) {
-      chartRef.current.timeScale().fitContent()
-      // Reset interaction tracking so we don't try to restore a stale viewport
+      fitContentWithMargin(chartRef.current)
       hasUserInteractedRef.current = false
     }
   }
```

---

## 5. Notes and Risks

### Potential Regressions

| Area | Risk | Mitigation |
|------|------|------------|
| **WAEP/WAXP Lines** | These extend 50 candles beyond the last real candle. The new right margin of ~5 bars is much smaller, so these lines will still be visible and extend beyond the visible area. | No change needed - extensions are independent of viewport. |
| **Order Level Lines** | Same as WAEP/WAXP - unfilled orders extend to `extendedEndTime`. | No change needed. |
| **Fill Markers** | Markers use `fillsSeriesRef` which has invisible extension points. | No change needed - markers are positioned by time, not viewport. |
| **Polling Refresh** | If user has interacted, we now preserve their viewport even when new candles arrive. The user may not see new candles if they've zoomed in on old data. | This is the intended behaviour per requirements. User can click Reset View. |
| **Interval Change** | Previously, changing interval would force auto-fit. Now it preserves user viewport. The user's logical range may show "empty" space if the new timeframe has fewer candles in that range. | This is the intended behaviour. User can click Reset View. |
| **Range Change** | Same as interval change - user's viewport is preserved even when lookback/forward changes. | Same as above. |

### Assumptions about Lightweight Charts API

1. **`fitContent()`** fits all data points into the visible area with minimal padding. This is confirmed behaviour.

2. **`getVisibleLogicalRange()`** returns logical bar indices (`from` and `to`), not timestamps. Adding to `to` shifts the viewport to show more empty space on the right. Confirmed.

3. **`setVisibleLogicalRange()`** triggers the `subscribeVisibleLogicalRangeChange` callback. This is why we need the `isProgrammaticViewportChangeRef` guard.

4. **`requestAnimationFrame`** callback fires before the next paint, which is sufficient time for Lightweight Charts to process the viewport change and trigger its internal callbacks.

### Alternative Approaches Considered

1. **Use `rightOffset` in timeScale options**: Lightweight Charts supports `timeScale: { rightOffset: 10 }` which adds permanent right-side space. However, this affects the chart at ALL times, not just during auto-fit. If the user zooms in manually, they may not want the extra space. The manual `setVisibleLogicalRange` approach gives us more control.

2. **Use `scrollToPosition` after `fitContent`**: Another approach is `chart.timeScale().scrollToPosition(-5, false)` which scrolls the viewport. However, this is less predictable than directly setting the visible range.

3. **Keep interval/range change resetting interaction**: The original code reset `hasUserInteractedRef` on interval/range change to force auto-fit. This could be kept as an option, but the user feedback suggests they want their viewport preserved. The Reset View button provides an explicit way to re-fit.

### Testing Checklist

After applying the patch, test the following scenarios:

- [ ] Expand a trade row → chart shows all data with right margin
- [ ] Wait 5+ seconds → viewport does NOT change
- [ ] Pan the chart left → wait 5 seconds → viewport preserved at panned position
- [ ] Change interval from 15m to 1h → viewport preserved (user interacted)
- [ ] Click Reset View → auto-fit with right margin, subsequent polling re-fits
- [ ] Change lookback from 200 to 500 → viewport preserved (user interacted)
- [ ] Fresh load (no prior interaction) → change interval → auto-fit with margin
- [ ] Toggle WAEP/WAXP checkbox → viewport unchanged
- [ ] Toggle Order Levels checkbox → viewport unchanged
- [ ] Take snapshot → captures current viewport correctly

---

**This document is for review only. No code changes have been applied.**
