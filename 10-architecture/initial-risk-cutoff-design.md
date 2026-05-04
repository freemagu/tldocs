# Initial RR Cutoff Override - Solution Design

## 1. Overview

### 1.1 Feature Summary

Add a user-editable "Initial RR Cutoff" that controls when initial RR and initial dollar risk are locked in for a trade. The default remains `opened_at + 10 minutes`, but users can override this by dragging a vertical line on the trade execution chart.

### 1.2 Terminology

| Term | Definition |
|------|------------|
| **Initial RR Cutoff** | The timestamp at which initial RR and initial $ risk are locked in |
| **Cutoff** | Short form of Initial RR Cutoff |
| **Lock in** | The act of finalizing/freezing the initial risk metrics at cutoff |
| **Projected WAEP** | WAEP assuming all unfilled DCAs present at cutoff will fill at their limit prices |

### 1.3 Key Concepts

**Projected WAEP** (new concept):
- Not just realized WAEP from fills, but includes unfilled DCAs
- Rationale: If stop is hit, all DCAs between entry and stop would have filled first
- Deterministic: Reproducible from order state at cutoff timestamp

---

## 2. Database Schema

### 2.1 New Table: `initial_rr_cutoff_override`

```sql
CREATE TABLE initial_rr_cutoff_override (
    override_id     INT IDENTITY PRIMARY KEY,
    trade_id        INT NOT NULL,
    cutoff_time     DATETIME NOT NULL,
    cutoff_reason   VARCHAR(255) NULL,      -- Optional user note
    cutoff_tf       VARCHAR(10) NULL,       -- Timeframe used for snapping ("1m", "5m", etc.)
    created_at      DATETIME DEFAULT getdate(),
    updated_at      DATETIME DEFAULT getdate(),

    CONSTRAINT uq_cutoff_trade_id UNIQUE (trade_id),
    CONSTRAINT fk_cutoff_trade FOREIGN KEY (trade_id)
        REFERENCES trade_journal(trade_id) ON DELETE CASCADE
)
```

**Design decisions:**
- One row per trade (unique constraint on trade_id)
- No row = use default (opened_at + 10m)
- CASCADE delete: If trade is deleted, override is deleted
- `cutoff_tf` is metadata only (for UI display), not used in calculations

### 2.2 Migration Script

Location: `migrations/XXX_initial_rr_cutoff_override.sql`

```sql
-- Create initial_rr_cutoff_override table
IF NOT EXISTS (SELECT 1 FROM sysobjects WHERE name = 'initial_rr_cutoff_override' AND type = 'U')
BEGIN
    CREATE TABLE initial_rr_cutoff_override (
        override_id     INT IDENTITY PRIMARY KEY,
        trade_id        INT NOT NULL,
        cutoff_time     DATETIME NOT NULL,
        cutoff_reason   VARCHAR(255) NULL,
        cutoff_tf       VARCHAR(10) NULL,
        created_at      DATETIME DEFAULT getdate(),
        updated_at      DATETIME DEFAULT getdate()
    )

    CREATE UNIQUE INDEX ix_cutoff_trade_id ON initial_rr_cutoff_override(trade_id)

    ALTER TABLE initial_rr_cutoff_override
        ADD CONSTRAINT fk_cutoff_trade FOREIGN KEY (trade_id)
        REFERENCES trade_journal(trade_id) ON DELETE CASCADE
END
go
```

---

## 3. Backend Changes

### 3.1 Current Implementation Analysis

**Current 10-minute cutoff logic** in `refresh_trade_journal.py`:

```python
# TradeSession.get_initial_10m_stop_price()
def get_initial_10m_stop_price(self) -> Optional[Decimal]:
    """
    Get the stop-loss price set within the first 10 minutes of trade activation.
    Uses r_metric_start_time (opened_at or activated_at for seeded trades).
    """
    r_start = self.get_r_metric_start_time()
    cutoff_time = r_start + timedelta(minutes=10)
    # Find earliest SL created within [r_start, cutoff_time]
    ...
```

**Current InitR calculation** uses:
- `get_original_entry_price()` - first fill price (NOT WAEP)
- `get_initial_10m_stop_price()` - stop within 10 minutes

**Portfolio page** uses:
- Current WAEP from Bybit `avgPrice`
- Current live stop
- Formula: `|entry - stop| × qty`

### 3.2 New Computation Module

Create: `lib/tradelens/utils/initial_risk_calculator.py`

This module consolidates all initial risk calculations to avoid duplication.

```python
"""
Initial Risk Calculator

Computes initial RR and initial $ risk at a given cutoff timestamp.
Used by:
- Backend pipeline (refresh_trade_journal.py)
- Frontend preview (API endpoint)
- Portfolio page (for consistency)
"""

from dataclasses import dataclass
from decimal import Decimal
from datetime import datetime
from typing import Optional, List

@dataclass
class ProjectedWAEP:
    """Result of projected WAEP calculation"""
    waep: Decimal
    total_qty: Decimal
    filled_qty: Decimal
    projected_qty: Decimal  # From unfilled DCAs
    dca_orders_included: int

@dataclass
class InitialRiskResult:
    """Complete initial risk calculation result"""
    cutoff_time: datetime
    projected_waep: Decimal
    stop_price: Decimal
    total_qty: Decimal
    initial_risk_usd: Decimal
    initial_rr: Optional[Decimal]  # None if no TPs at cutoff
    waep_breakdown: ProjectedWAEP
    stop_source: str  # "filled" or "pending" or "live"


def calculate_projected_waep_at_cutoff(
    trade_id: int,
    cutoff_time: datetime,
    conn
) -> Optional[ProjectedWAEP]:
    """
    Calculate Projected WAEP at cutoff timestamp.

    Includes:
    - Entry fills before cutoff (actual prices)
    - DCA fills before cutoff (actual prices)
    - Unfilled DCAs that existed at cutoff (projected at limit price)

    Excludes:
    - DCAs created after cutoff
    - DCAs cancelled before cutoff
    """
    ...


def get_stop_at_cutoff(
    trade_id: int,
    cutoff_time: datetime,
    conn
) -> Optional[Decimal]:
    """
    Get the stop-loss price effective at cutoff timestamp.

    Priority:
    1. Filled SL before cutoff (actual trigger price)
    2. Active/pending SL at cutoff (trigger price)

    Returns None if no stop existed at cutoff.
    """
    ...


def calculate_initial_risk_at_cutoff(
    trade_id: int,
    cutoff_time: datetime,
    conn
) -> Optional[InitialRiskResult]:
    """
    Main entry point: Calculate initial RR and $ risk at cutoff.

    Returns None if:
    - No stop at cutoff
    - No entry fills at cutoff
    """
    ...
```

### 3.3 Changes to `refresh_trade_journal.py`

**Modify `get_initial_10m_stop_price()` → `get_stop_at_cutoff()`**

```python
def get_cutoff_time(self) -> datetime:
    """
    Get the cutoff time for this trade.

    Returns:
    - Override cutoff if exists in initial_rr_cutoff_override
    - Else: r_metric_start_time + 10 minutes (default)
    """
    # Check for override (loaded during session initialization)
    if hasattr(self, '_cutoff_override') and self._cutoff_override:
        return self._cutoff_override

    # Default: opened_at + 10 minutes
    r_start = self.get_r_metric_start_time()
    if r_start is None:
        return None
    return r_start + timedelta(minutes=10)
```

**Load overrides during session building:**

```python
def load_cutoff_overrides(trade_ids: List[int], conn) -> Dict[int, datetime]:
    """Load any cutoff overrides for the given trade IDs."""
    if not trade_ids:
        return {}

    ids_str = ','.join(str(tid) for tid in trade_ids)
    sql = f"""
    SELECT trade_id, cutoff_time
    FROM initial_rr_cutoff_override
    WHERE trade_id IN ({ids_str})
    """
    cursor = conn.cursor()
    cursor.execute(sql)
    return {row[0]: row[1] for row in cursor.fetchall()}
```

### 3.4 API Endpoints

#### 3.4.1 Get Cutoff Override

```
GET /api/journal/{trade_id}/cutoff-override
```

Response:
```json
{
  "trade_id": 389,
  "has_override": true,
  "cutoff_time": "2026-02-07T14:35:00Z",
  "cutoff_tf": "5m",
  "cutoff_reason": "Adjusted for late SL placement",
  "default_cutoff_time": "2026-02-07T14:30:00Z"
}
```

#### 3.4.2 Preview Initial Risk at Cutoff

```
POST /api/journal/{trade_id}/cutoff-preview
```

Request:
```json
{
  "cutoff_time": "2026-02-07T14:35:00Z"
}
```

Response:
```json
{
  "valid": true,
  "cutoff_time": "2026-02-07T14:35:00Z",
  "projected_waep": 48500.25,
  "stop_price": 46000.00,
  "total_qty": 0.5,
  "initial_risk_usd": 1250.13,
  "initial_rr": 2.5,
  "breakdown": {
    "filled_qty": 0.3,
    "projected_qty": 0.2,
    "dca_orders_included": 2
  },
  "error": null
}
```

Error response (no stop at cutoff):
```json
{
  "valid": false,
  "error": "No stop at cutoff time, cannot compute initial RR/risk",
  "cutoff_time": "2026-02-07T14:35:00Z"
}
```

#### 3.4.3 Save Cutoff Override

```
PUT /api/journal/{trade_id}/cutoff-override
```

Request:
```json
{
  "cutoff_time": "2026-02-07T14:35:00Z",
  "cutoff_tf": "5m",
  "cutoff_reason": "Adjusted for late SL placement"
}
```

Response:
```json
{
  "success": true,
  "trade_id": 389,
  "cutoff_time": "2026-02-07T14:35:00Z",
  "initial_risk_usd": 1250.13,
  "initial_rr": 2.5,
  "recalculated": true
}
```

**Behavior:**
1. Validate cutoff time (>= opened_at, stop exists)
2. Upsert override row in `initial_rr_cutoff_override`
3. **Immediately recalculate** R-metrics by calling `recalculate_single_trade()`
4. Return updated values

Validation errors:
- 400: Cutoff before opened_at
- 400: No stop at cutoff time
- 404: Trade not found

#### 3.4.4 Delete Cutoff Override (Reset to Default)

```
DELETE /api/journal/{trade_id}/cutoff-override
```

Response:
```json
{
  "success": true,
  "trade_id": 389,
  "message": "Reset to default cutoff (opened_at + 10 minutes)"
}
```

### 3.5 Immediate Recalculation Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Save Cutoff Override Flow                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Frontend                API                     Pipeline Logic      │
│  ────────                ───                     ──────────────      │
│                                                                      │
│  Drag line ──────────▶ PUT /cutoff-override                         │
│  (snapped)                    │                                      │
│                               ▼                                      │
│                         Validate cutoff                              │
│                         (stop exists?)                               │
│                               │                                      │
│                               ▼                                      │
│                         Upsert override ──────▶ initial_risk_        │
│                         row in DB               cutoff_override      │
│                               │                                      │
│                               ▼                                      │
│                         recalculate_single_trade()                   │
│                               │                                      │
│                               ├──▶ Load legs from order_leg_hist     │
│                               ├──▶ Build TradeSession                │
│                               ├──▶ Apply cutoff override             │
│                               ├──▶ Calculate Projected WAEP          │
│                               ├──▶ Calculate init_r, mfe_r, mae_r    │
│                               ├──▶ UPDATE trade_journal              │
│                               │                                      │
│                               ▼                                      │
│  ◀──────────────────── Return updated values                        │
│  Update UI                                                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key point:** The `recalculate_single_trade()` function is the same code path used by the nightly pipeline, just called for one trade instead of all trades. No duplication.

### 3.6 API Route Registration

Add to `lib/tradelens/api/journal.py` (or create `cutoff.py`):

```python
from fastapi import APIRouter, HTTPException
from ..utils.initial_risk_calculator import (
    calculate_initial_risk_at_cutoff,
    get_stop_at_cutoff
)

router = APIRouter(prefix="/journal", tags=["journal"])

@router.get("/{trade_id}/cutoff-override")
async def get_cutoff_override(trade_id: int):
    ...

@router.post("/{trade_id}/cutoff-preview")
async def preview_cutoff(trade_id: int, request: CutoffPreviewRequest):
    ...

@router.put("/{trade_id}/cutoff-override")
async def save_cutoff_override(trade_id: int, request: CutoffOverrideRequest):
    ...

@router.delete("/{trade_id}/cutoff-override")
async def delete_cutoff_override(trade_id: int):
    ...
```

---

## 4. Frontend Changes

### 4.1 Component Structure

```
src/components/journal/
├── trade-journal-expanded-row.tsx      # Existing - add cutoff line
├── initial-risk-cutoff-line.tsx        # NEW - draggable vertical line
├── cutoff-tooltip.tsx                  # NEW - tooltip during drag
└── hooks/
    └── use-cutoff-override.ts          # NEW - API + state management
```

### 4.2 Cutoff Line Component

**File:** `initial-risk-cutoff-line.tsx`

```typescript
interface InitialRiskCutoffLineProps {
  tradeId: number
  openedAt: Date
  closedAt: Date | null
  defaultCutoffTime: Date          // opened_at + 10m
  overrideCutoffTime: Date | null  // From DB, null = use default
  chartTimeframe: string           // "1m", "5m", "15m", etc.
  chartXScale: d3.ScaleTime        // For positioning
  chartHeight: number
  onCutoffChange: (time: Date) => void
  onCutoffSave: (time: Date) => Promise<void>
  onCutoffReset: () => Promise<void>
}

export function InitialRiskCutoffLine({
  tradeId,
  openedAt,
  closedAt,
  defaultCutoffTime,
  overrideCutoffTime,
  chartTimeframe,
  chartXScale,
  chartHeight,
  onCutoffChange,
  onCutoffSave,
  onCutoffReset
}: InitialRiskCutoffLineProps) {
  const [isDragging, setIsDragging] = useState(false)
  const [dragPosition, setDragPosition] = useState<Date | null>(null)
  const [previewData, setPreviewData] = useState<CutoffPreview | null>(null)

  const currentCutoff = overrideCutoffTime || defaultCutoffTime
  const displayCutoff = isDragging ? dragPosition : currentCutoff

  // Debounced preview fetch during drag
  const debouncedPreview = useDebouncedCallback(
    async (time: Date) => {
      const preview = await fetchCutoffPreview(tradeId, time)
      setPreviewData(preview)
    },
    150  // 150ms debounce
  )

  const handleDragStart = () => {
    setIsDragging(true)
    setDragPosition(currentCutoff)
  }

  const handleDrag = (x: number) => {
    const time = chartXScale.invert(x)

    // Clamp to valid range
    const clampedTime = clampToRange(time, openedAt, closedAt)
    setDragPosition(clampedTime)

    // Trigger preview calculation
    debouncedPreview(clampedTime)
    onCutoffChange(clampedTime)
  }

  const handleDragEnd = async () => {
    if (!dragPosition) return

    // Snap to nearest candle boundary
    const snappedTime = snapToCandleBoundary(dragPosition, chartTimeframe)

    // Save override
    await onCutoffSave(snappedTime)

    setIsDragging(false)
    setDragPosition(null)
    setPreviewData(null)
  }

  return (
    <g className="cutoff-line-group">
      {/* Vertical line */}
      <line
        x1={chartXScale(displayCutoff)}
        y1={0}
        x2={chartXScale(displayCutoff)}
        y2={chartHeight}
        stroke={isDragging ? "#fbbf24" : "#60a5fa"}  // Yellow when dragging, blue otherwise
        strokeWidth={isDragging ? 3 : 2}
        strokeDasharray={overrideCutoffTime ? "none" : "5,5"}  // Dashed if default
        style={{ cursor: 'ew-resize' }}
        onMouseDown={handleDragStart}
      />

      {/* Label */}
      <text
        x={chartXScale(displayCutoff) + 5}
        y={15}
        fill="#60a5fa"
        fontSize={11}
        fontWeight={500}
      >
        Initial RR Cutoff
        {overrideCutoffTime && " (custom)"}
      </text>

      {/* Tooltip during drag */}
      {isDragging && previewData && (
        <CutoffTooltip
          x={chartXScale(displayCutoff)}
          y={50}
          data={previewData}
        />
      )}

      {/* Reset button (only shown if override exists) */}
      {overrideCutoffTime && !isDragging && (
        <foreignObject x={chartXScale(displayCutoff) + 5} y={20} width={60} height={20}>
          <button
            onClick={onCutoffReset}
            className="text-xs text-gray-400 hover:text-white underline"
          >
            Reset
          </button>
        </foreignObject>
      )}
    </g>
  )
}
```

### 4.3 Tooltip Component

**File:** `cutoff-tooltip.tsx`

```typescript
interface CutoffTooltipProps {
  x: number
  y: number
  data: {
    cutoff_time: string
    projected_waep: number
    stop_price: number
    initial_risk_usd: number
    initial_rr: number | null
    valid: boolean
    error: string | null
  }
}

export function CutoffTooltip({ x, y, data }: CutoffTooltipProps) {
  return (
    <foreignObject x={x + 10} y={y} width={220} height={140}>
      <div className="bg-gray-900 border border-gray-700 rounded-lg p-3 shadow-xl text-sm">
        <div className="font-medium text-white mb-2">
          Cutoff: {formatDateTime(data.cutoff_time)}
        </div>

        {data.valid ? (
          <div className="space-y-1 text-gray-300">
            <div className="flex justify-between">
              <span>WAEP (projected):</span>
              <span className="text-white">${formatNumber(data.projected_waep)}</span>
            </div>
            <div className="flex justify-between">
              <span>Stop:</span>
              <span className="text-white">${formatNumber(data.stop_price)}</span>
            </div>
            <div className="flex justify-between">
              <span>Initial Risk:</span>
              <span className="text-red-400">${formatNumber(data.initial_risk_usd)}</span>
            </div>
            {data.initial_rr !== null && (
              <div className="flex justify-between">
                <span>Initial RR:</span>
                <span className="text-green-400">{data.initial_rr.toFixed(2)}R</span>
              </div>
            )}
          </div>
        ) : (
          <div className="text-red-400 text-xs">
            {data.error || "Cannot compute initial risk"}
          </div>
        )}
      </div>
    </foreignObject>
  )
}
```

### 4.4 Hook for State Management

**File:** `hooks/use-cutoff-override.ts`

```typescript
import { useState, useEffect, useCallback } from 'react'
import { journalApi } from '../../lib/api'

interface UseCutoffOverrideResult {
  // State
  overrideCutoffTime: Date | null
  defaultCutoffTime: Date
  isLoading: boolean
  error: string | null

  // Actions
  previewCutoff: (time: Date) => Promise<CutoffPreview>
  saveCutoff: (time: Date, tf: string, reason?: string) => Promise<void>
  resetCutoff: () => Promise<void>
}

export function useCutoffOverride(
  tradeId: number,
  openedAt: Date
): UseCutoffOverrideResult {
  const [overrideCutoffTime, setOverrideCutoffTime] = useState<Date | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const defaultCutoffTime = useMemo(
    () => new Date(openedAt.getTime() + 10 * 60 * 1000),
    [openedAt]
  )

  // Load existing override on mount
  useEffect(() => {
    const loadOverride = async () => {
      try {
        const response = await journalApi.getCutoffOverride(tradeId)
        if (response.has_override) {
          setOverrideCutoffTime(new Date(response.cutoff_time))
        }
      } catch (err) {
        console.error('Failed to load cutoff override:', err)
      } finally {
        setIsLoading(false)
      }
    }
    loadOverride()
  }, [tradeId])

  const previewCutoff = useCallback(async (time: Date) => {
    return journalApi.previewCutoff(tradeId, time.toISOString())
  }, [tradeId])

  const saveCutoff = useCallback(async (time: Date, tf: string, reason?: string) => {
    setError(null)
    try {
      await journalApi.saveCutoffOverride(tradeId, {
        cutoff_time: time.toISOString(),
        cutoff_tf: tf,
        cutoff_reason: reason
      })
      setOverrideCutoffTime(time)
    } catch (err: any) {
      setError(err.message || 'Failed to save cutoff')
      throw err
    }
  }, [tradeId])

  const resetCutoff = useCallback(async () => {
    try {
      await journalApi.deleteCutoffOverride(tradeId)
      setOverrideCutoffTime(null)
    } catch (err: any) {
      setError(err.message || 'Failed to reset cutoff')
      throw err
    }
  }, [tradeId])

  return {
    overrideCutoffTime,
    defaultCutoffTime,
    isLoading,
    error,
    previewCutoff,
    saveCutoff,
    resetCutoff
  }
}
```

### 4.5 Snapping Logic

```typescript
/**
 * Snap a timestamp to the nearest candle boundary for the given timeframe.
 */
export function snapToCandleBoundary(time: Date, timeframe: string): Date {
  const ms = time.getTime()

  // Convert timeframe to milliseconds
  const tfMs = timeframeToMs(timeframe)

  // Snap to nearest boundary
  const snapped = Math.round(ms / tfMs) * tfMs

  return new Date(snapped)
}

function timeframeToMs(tf: string): number {
  const match = tf.match(/^(\d+)([mhd])$/)
  if (!match) return 60000 // Default 1m

  const [, value, unit] = match
  const n = parseInt(value)

  switch (unit) {
    case 'm': return n * 60 * 1000
    case 'h': return n * 60 * 60 * 1000
    case 'd': return n * 24 * 60 * 60 * 1000
    default: return 60000
  }
}
```

### 4.6 Integration with Trade Execution Chart

In `trade-journal-expanded-row.tsx`, add the cutoff line to the chart:

```typescript
// Inside the chart SVG, after drawing candles and order markers
{showCutoffLine && (
  <InitialRiskCutoffLine
    tradeId={trade.trade_id}
    openedAt={new Date(trade.opened_at)}
    closedAt={trade.closed_at ? new Date(trade.closed_at) : null}
    defaultCutoffTime={defaultCutoff}
    overrideCutoffTime={cutoffOverride}
    chartTimeframe={selectedTimeframe}
    chartXScale={xScale}
    chartHeight={chartHeight}
    onCutoffChange={handleCutoffChange}
    onCutoffSave={handleCutoffSave}
    onCutoffReset={handleCutoffReset}
  />
)}
```

---

## 5. Projected WAEP Calculation Details

### 5.1 Algorithm

```python
def calculate_projected_waep_at_cutoff(trade_id, cutoff_time, conn):
    """
    Calculate Projected WAEP at cutoff.

    Algorithm:
    1. Get all ENTRY/DCA legs for trade
    2. For each leg, determine state at cutoff:
       - Filled before cutoff: use actual fill price × qty
       - Partially filled: actual price for filled, limit price for remainder
       - Unfilled but existed: use limit price × order qty
       - Created after cutoff: EXCLUDE
       - Cancelled before cutoff: EXCLUDE
    3. Compute weighted average
    """

    # Query order legs with relevant timestamps
    sql = """
    SELECT
        ol.order_leg_id,
        ol.leg_type,
        ol.price,                    -- limit price
        ol.qty,                      -- order qty
        ol.filled_qty,               -- filled qty (for partial fills)
        ol.avg_fill_price,           -- actual fill price
        ol.exchange_created_at,      -- when order was placed
        ol.exchange_filled_at,       -- when fully filled (NULL if pending)
        ol.status,                   -- 'filled', 'new', 'cancelled', etc.
        ol.cancelled_at              -- when cancelled (NULL if not cancelled)
    FROM order_leg_hist ol
    JOIN trade_journal tj ON ol.trade_id = tj.trade_id
    WHERE ol.trade_id = ?
      AND ol.leg_type IN ('entry', 'dca')
      AND ol.exchange_created_at <= ?  -- Created at or before cutoff
      AND (ol.cancelled_at IS NULL OR ol.cancelled_at > ?)  -- Not cancelled before cutoff
    ORDER BY ol.exchange_created_at
    """

    cursor.execute(sql, [trade_id, cutoff_time, cutoff_time])
    legs = cursor.fetchall()

    total_cost = Decimal('0')
    total_qty = Decimal('0')

    for leg in legs:
        created_at = leg['exchange_created_at']
        filled_at = leg['exchange_filled_at']

        if filled_at and filled_at <= cutoff_time:
            # Fully filled before cutoff: use actual fill price
            price = leg['avg_fill_price']
            qty = leg['filled_qty']
        elif leg['filled_qty'] > 0:
            # Partially filled: actual for filled part, limit for remainder
            filled_part_cost = leg['avg_fill_price'] * leg['filled_qty']
            remaining_qty = leg['qty'] - leg['filled_qty']
            unfilled_part_cost = leg['price'] * remaining_qty

            total_cost += filled_part_cost + unfilled_part_cost
            total_qty += leg['qty']
            continue
        else:
            # Unfilled but existed at cutoff: project at limit price
            price = leg['price']
            qty = leg['qty']

        total_cost += price * qty
        total_qty += qty

    if total_qty == 0:
        return None

    return total_cost / total_qty
```

### 5.2 Key Considerations

1. **Order source:** Must query both `order_leg_live` (pending) and `order_leg_hist` (filled/cancelled)
2. **Timestamp accuracy:** Use `exchange_created_at`, not internal `created_at`
3. **Cancelled orders:** Check `cancelled_at > cutoff_time` (existed at cutoff)
4. **Partial fills:** Split calculation between filled and unfilled portions

---

## 6. Edge Cases

### 6.1 Seeded/Pending Trades

| Scenario | Behavior |
|----------|----------|
| Seeded trade (entry not filled) | Cannot set cutoff - no opened_at yet |
| Pending entry | Cannot set cutoff - no opened_at yet |
| Seeded → promoted | Use `activated_at` as opened_at (existing logic) |

### 6.2 Missing Stop at Cutoff

```typescript
// Frontend: Show error, prevent saving
if (!preview.valid && preview.error?.includes('No stop')) {
  showError("No stop at cutoff time, cannot compute initial RR/risk")
  // Don't allow drag release to save
  return
}
```

### 6.3 Trade Closed Before Default Cutoff

| Scenario | Behavior |
|----------|----------|
| Trade closed at T+5m | Default cutoff = T+10m, but use closed_at as max |
| Cutoff line | Clamp drag range to [opened_at, closed_at] |
| Calculation | Use stop at time of close (likely the SL that closed it) |

### 6.4 Missing Candle Data

```typescript
// Snap to available data boundary
const handleDrag = (x: number) => {
  const time = chartXScale.invert(x)

  // Clamp to chart's visible data range
  const [minTime, maxTime] = chartXScale.domain()
  const clampedTime = clamp(time, minTime, maxTime)

  setDragPosition(clampedTime)
}
```

### 6.5 DCA Timing Edge Cases

| Scenario | Projected WAEP Handling |
|----------|-------------------------|
| DCA created at exact cutoff time | Include (created_at <= cutoff) |
| DCA cancelled at exact cutoff time | Exclude (cancelled_at <= cutoff) |
| DCA filled at exact cutoff time | Include as filled (filled_at <= cutoff) |
| DCA partially filled, then cancelled after cutoff | Include full order qty at projected prices |

### 6.6 No TPs at Cutoff

- `initial_rr` = NULL (cannot calculate RR without TP)
- `initial_risk_usd` = still calculable from WAEP and stop
- UI shows "-" for Initial RR

---

## 7. Implementation Plan

### Phase 1: Database & Backend Core (Day 1-2)

1. **Create migration script**
   - Add `initial_rr_cutoff_override` table
   - Run migration on dev

2. **Create initial_risk_calculator.py**
   - Implement `calculate_projected_waep_at_cutoff()`
   - Implement `get_stop_at_cutoff()`
   - Implement `calculate_initial_risk_at_cutoff()`
   - Unit tests for each function

3. **Update refresh_trade_journal.py**
   - Add `load_cutoff_overrides()` function
   - Modify `get_cutoff_time()` to check overrides
   - **Switch `calculate_init_r()` to use Projected WAEP**
   - **Switch `calculate_mfe_mae_time_to_1r()` to use Projected WAEP**
   - Extract `recalculate_single_trade()` function for API reuse
   - Update R-metric calculation to use new cutoff

### Phase 2: API Endpoints (Day 2-3)

4. **Create API routes**
   - GET `/journal/{trade_id}/cutoff-override`
   - POST `/journal/{trade_id}/cutoff-preview`
   - PUT `/journal/{trade_id}/cutoff-override`
   - DELETE `/journal/{trade_id}/cutoff-override`

5. **Add to dto.py**
   - `CutoffPreviewRequest`
   - `CutoffPreviewResponse`
   - `CutoffOverrideRequest`
   - `CutoffOverrideResponse`

6. **Integration tests**
   - Test preview calculation
   - Test save/delete flow
   - Test edge cases (no stop, closed trade, etc.)

### Phase 3: Frontend Implementation (Day 3-5)

7. **Create hook and utilities**
   - `use-cutoff-override.ts`
   - `snapToCandleBoundary()`
   - API client methods

8. **Create cutoff line component**
   - `initial-risk-cutoff-line.tsx`
   - Drag handling
   - Visual styling

9. **Create tooltip component**
   - `cutoff-tooltip.tsx`
   - Preview data display

10. **Integrate with chart**
    - Add cutoff line to trade execution chart
    - Wire up handlers
    - Add "Reset to default" button

### Phase 4: Testing & Polish (Day 5-6)

11. **Manual testing**
    - Test drag/drop on various trades
    - Test edge cases (seeded, closed, no stop)
    - Test responsiveness

12. **Accessibility**
    - High contrast line colors
    - Keyboard support (optional)
    - Screen reader labels

13. **Documentation**
    - Update CLAUDE.md with new feature
    - Add inline code comments

---

## 8. Suggested Tests

### 8.1 Unit Tests (Backend)

```python
# tests/unit/test_initial_risk_calculator.py

class TestProjectedWAEP:
    def test_single_entry_no_dcas(self):
        """Entry only, no DCAs - WAEP = entry price"""

    def test_entry_plus_filled_dca(self):
        """Entry + filled DCA - WAEP = weighted average"""

    def test_entry_plus_unfilled_dca(self):
        """Entry + unfilled DCA - project DCA at limit price"""

    def test_partial_fill_dca(self):
        """Partially filled DCA - split actual/projected"""

    def test_dca_created_after_cutoff_excluded(self):
        """DCAs created after cutoff should not be included"""

    def test_dca_cancelled_before_cutoff_excluded(self):
        """DCAs cancelled before cutoff should not be included"""


class TestStopAtCutoff:
    def test_stop_filled_before_cutoff(self):
        """Stop that was hit before cutoff - use trigger price"""

    def test_stop_pending_at_cutoff(self):
        """Stop pending at cutoff - use trigger price"""

    def test_no_stop_at_cutoff(self):
        """No stop existed at cutoff - return None"""

    def test_stop_amended_after_cutoff(self):
        """Stop amended after cutoff - use price at cutoff time"""


class TestInitialRiskCalculation:
    def test_basic_calculation(self):
        """Basic initial risk = |WAEP - stop| × qty"""

    def test_with_override_cutoff(self):
        """Use override cutoff time instead of default"""

    def test_no_stop_returns_none(self):
        """Return None if no stop at cutoff"""
```

### 8.2 Integration Tests (API)

```python
# tests/integration/test_cutoff_api.py

class TestCutoffOverrideAPI:
    def test_get_no_override(self):
        """GET returns has_override=false when no override"""

    def test_save_and_get_override(self):
        """PUT creates override, GET returns it"""

    def test_delete_override(self):
        """DELETE removes override, GET shows has_override=false"""

    def test_preview_valid_cutoff(self):
        """POST preview returns valid calculation"""

    def test_preview_no_stop_error(self):
        """POST preview returns error when no stop at cutoff"""

    def test_save_cutoff_before_opened_fails(self):
        """PUT with cutoff before opened_at returns 400"""
```

### 8.3 Frontend Tests

```typescript
// __tests__/initial-risk-cutoff-line.test.tsx

describe('InitialRiskCutoffLine', () => {
  it('renders at default position when no override', () => {})
  it('renders at override position when override exists', () => {})
  it('shows dashed line for default, solid for override', () => {})
  it('shows tooltip during drag', () => {})
  it('snaps to candle boundary on drag end', () => {})
  it('shows reset button only when override exists', () => {})
  it('clamps drag to valid range', () => {})
})

describe('snapToCandleBoundary', () => {
  it('snaps to 1m boundary', () => {})
  it('snaps to 5m boundary', () => {})
  it('snaps to 1h boundary', () => {})
  it('rounds to nearest boundary', () => {})
})
```

---

## 9. Design Decisions (Confirmed)

### 9.1 Immediate Recalculation on Save

**Decision:** Yes - recalculate immediately when saving override.

**Implementation approach:** Reuse existing pipeline logic, don't duplicate.

```python
# In api/cutoff.py (or journal.py)

from ..pipeline.trade_journal_calculator import recalculate_single_trade

@router.put("/{trade_id}/cutoff-override")
async def save_cutoff_override(trade_id: int, request: CutoffOverrideRequest):
    # 1. Validate cutoff (stop exists, etc.)
    preview = calculate_initial_risk_at_cutoff(trade_id, request.cutoff_time, conn)
    if not preview or preview.stop_price is None:
        raise HTTPException(400, "No stop at cutoff time")

    # 2. Save override to DB
    upsert_cutoff_override(trade_id, request.cutoff_time, request.cutoff_tf, conn)

    # 3. Recalculate R-metrics for this single trade (reuse pipeline logic)
    recalculate_single_trade(trade_id, conn)

    # 4. Return updated values
    return {
        "success": True,
        "trade_id": trade_id,
        "initial_risk_usd": float(preview.initial_risk_usd),
        "initial_rr": float(preview.initial_rr) if preview.initial_rr else None
    }
```

**Extract from pipeline:**

Create a reusable function in `refresh_trade_journal.py`:

```python
def recalculate_single_trade(trade_id: int, conn) -> bool:
    """
    Recalculate R-metrics for a single trade.

    Reuses existing sessionization and R-metric calculation logic.
    Called by:
    - API when cutoff override is saved/deleted
    - Pipeline during normal refresh

    Returns True if successful.
    """
    # 1. Load the trade's legs from order_leg_hist
    legs = fetch_legs_for_trade(trade_id, conn)

    # 2. Build a TradeSession (existing logic)
    session = build_session_from_legs(trade_id, legs, conn)

    # 3. Load cutoff override if exists
    override = load_cutoff_override(trade_id, conn)
    if override:
        session._cutoff_override = override.cutoff_time

    # 4. Calculate R-metrics (existing logic)
    calculate_r_metrics_for_session(session, conn)

    # 5. Update trade_journal with new values
    update_trade_r_metrics(trade_id, session, conn)

    return True
```

This keeps the logic in one place - the API just calls the same function the pipeline uses.

### 9.2 Switch init_r to Projected WAEP

**Decision:** Yes - use Projected WAEP for consistency across all R-metrics.

**Changes required in `refresh_trade_journal.py`:**

```python
# BEFORE (current):
def calculate_init_r(self) -> Optional[Decimal]:
    original_entry = self.get_original_entry_price()  # First fill only
    ...

# AFTER (new):
def calculate_init_r(self) -> Optional[Decimal]:
    projected_waep = self.get_projected_waep_at_cutoff()  # Includes DCAs
    ...
```

**Metrics consistency after change:**

| Metric | Entry Price Used | Stop Used |
|--------|------------------|-----------|
| `init_r` | Projected WAEP | Stop at cutoff |
| `exit_r` | Final WAEP | Stop at cutoff |
| `mfe_r` | Projected WAEP | Stop at cutoff |
| `mae_r` | Projected WAEP | Stop at cutoff |
| `initial_risk_usd` | Projected WAEP | Stop at cutoff |

All metrics now use consistent Projected WAEP reference.

### 9.3 Other Decisions

| Question | Decision |
|----------|----------|
| Audit trail for cutoff changes? | No - just current override. Keep it simple. |
| Bulk operations? | Not in v1. Single-trade focus. |
| Backfill historical trades? | Yes - run pipeline once after deployment to recalculate all R-metrics with Projected WAEP |

### 9.4 Impact of Projected WAEP Change

**What changes:**
- `init_r` values will change for trades that had DCAs
- Trades with only a single entry (no DCAs) will be unchanged
- The change makes R-metrics more accurate (reflects true risk exposure)

**Backfill approach:**
```bash
# After deploying the WAEP change, run a one-time recalculation
./bin/pipeline/refresh_trade_journal.py --recalculate-all-r-metrics
```

This flag would:
1. Load all trades from `trade_journal`
2. For each trade, call `recalculate_single_trade()`
3. Update `init_r`, `mfe_r`, `mae_r`, `initial_stop_price` with new values

**Example impact:**

| Trade | Before (Original Entry) | After (Projected WAEP) |
|-------|-------------------------|------------------------|
| Entry $50k, DCA $48k, Stop $44k | Risk = $6k (50-44) | Risk = $4k (48-44 WAEP) |
| InitR = 2.0R (TP at $62k) | InitR = 3.0R (same TP, smaller risk base) |

Trades with DCAs will show **higher InitR** (because the projected WAEP is closer to the stop, so the same TP represents more R)

---

## 10. Summary

This design provides a complete solution for the Initial RR Cutoff feature:

- **Minimal schema changes:** One new table, no changes to `trade_journal`
- **Reuses existing logic:** Portfolio page calculations, existing R-metric framework
- **Clean separation:** Calculation logic in shared module, UI in dedicated components
- **Robust edge case handling:** Seeded trades, missing stops, partial fills
- **Good UX:** Draggable line, live preview, clear feedback

The implementation can be done in approximately 5-6 days, with clear phases and testable milestones.

---

*Document created: 2026-02-07*
*Author: Claude Code Assistant*
