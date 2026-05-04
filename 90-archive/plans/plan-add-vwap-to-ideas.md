# Plan: Add VWAP Support to Ideas Chart

## Overview

Add VWAP functionality to the Ideas chart, including the VWAP panel UI and VWAP alerting. This leverages the existing VWAP infrastructure which already supports both ideas and trades.

## Current State

### Already Working
- **VwapPanel component** (`components/journal/vwap-panel.tsx`) - Already supports dual-mode with `ideaId` OR `tradeId`
- **Backend API** - Already has `/vwap/{idea_id}` endpoints for ideas
- **Frontend API** (`lib/api.ts`) - Has `vwapApi.getConfig(ideaId)`, `saveConfig()`, `deleteConfig()`
- **VWAP calculation** (`lib/vwap-calculator.ts`) - Pure functions, fully reusable
- **VWAP types** (`lib/vwap-types.ts`) - Already shared
- **TradeJournalChart** - Has all VWAP props, used by both journal and ideas

### Missing in Ideas
- Ideas expanded row doesn't pass VWAP props to `TradeJournalChart`
- No VWAP state management in ideas component
- No VWAP panel button/toggle in ideas UI
- No VWAP alert leg synthesis for chart display

## Implementation Steps

### Step 1: Add VWAP State to Ideas Store

**File:** `frontend/web/src/stores/ideasStore.ts`

Add per-idea VWAP UI state (similar to journal's per-trade state):

```typescript
// Add to IdeaUIState interface:
isVwapPanelOpen: boolean
vwapActiveSlot: VwapSlotId
vwapCustomSelectingSlot: VwapSlotId | null
```

With defaults:
```typescript
isVwapPanelOpen: false,
vwapActiveSlot: 'A',
vwapCustomSelectingSlot: null,
```

### Step 2: Fetch VWAP Config in Ideas Expanded Row

**File:** `frontend/web/src/components/ideas/trade-idea-expanded-row.tsx`

Add VWAP config fetching (similar to journal):

```typescript
// Add query for VWAP config
const { data: vwapConfigData } = useQuery({
  queryKey: ['vwap-config', 'idea', idea.id],
  queryFn: () => vwapApi.getConfig(idea.id),
  staleTime: 30000,
})

// State for VWAP config (controlled)
const [vwapConfig, setVwapConfig] = useState<VwapConfig>(DEFAULT_VWAP_CONFIG)

// Sync from server
useEffect(() => {
  if (vwapConfigData?.slots) {
    setVwapConfig(vwapConfigData.slots)
  }
}, [vwapConfigData])
```

### Step 3: Add VWAP State Management Hooks

**File:** `frontend/web/src/components/ideas/trade-idea-expanded-row.tsx`

Add state from ideasStore:

```typescript
// Get VWAP UI state from store
const isVwapPanelOpen = useIdeasStore(s => s.getIdeaUIState(idea.id).isVwapPanelOpen)
const vwapActiveSlot = useIdeasStore(s => s.getIdeaUIState(idea.id).vwapActiveSlot)
const vwapCustomSelectingSlot = useIdeasStore(s => s.getIdeaUIState(idea.id).vwapCustomSelectingSlot)

// VWAP preview times (from chart visible range)
const [vwapAutoPreviewTime, setVwapAutoPreviewTime] = useState<{low: number | null, high: number | null}>({low: null, high: null})

// Handlers
const handleVwapPanelToggle = () => {
  useIdeasStore.getState().setIdeaUIField(idea.id, 'isVwapPanelOpen', !isVwapPanelOpen)
}

const handleVwapActiveSlotChange = (slot: VwapSlotId) => {
  useIdeasStore.getState().setIdeaUIField(idea.id, 'vwapActiveSlot', slot)
}

const handleStartCustomSelect = (slot: VwapSlotId) => {
  useIdeasStore.getState().setIdeaUIField(idea.id, 'vwapCustomSelectingSlot', slot)
}

const handleCancelCustomSelect = () => {
  useIdeasStore.getState().setIdeaUIField(idea.id, 'vwapCustomSelectingSlot', null)
}

const handleVwapCustomAnchorSelect = (time: number) => {
  // Update config with custom anchor time
  if (vwapCustomSelectingSlot) {
    const newConfig = {
      ...vwapConfig,
      [vwapCustomSelectingSlot]: {
        ...vwapConfig[vwapCustomSelectingSlot],
        customTime: time,
      }
    }
    setVwapConfig(newConfig)
    handleCancelCustomSelect()
  }
}
```

### Step 4: Build VWAP Alerts Map

**File:** `frontend/web/src/components/ideas/trade-idea-expanded-row.tsx`

Build the `vwapAlerts` map from idea alerts (similar to journal):

```typescript
// Build VWAP alerts map from combinedAlerts
const vwapAlerts = useMemo(() => {
  const map = new Map<string, boolean>()
  if (!combinedAlerts) return map

  combinedAlerts.forEach(alert => {
    if (alert.level_type === 'vwap' && alert.level_index !== null) {
      const slotIdx = Math.floor(alert.level_index / 10)
      const sigma = alert.level_index % 10
      const slotId = ['A', 'B', 'C'][slotIdx] || 'A'
      map.set(`${slotId}-${sigma}`, true)
    }
  })
  return map
}, [combinedAlerts])
```

### Step 5: Pass VWAP Props to TradeJournalChart

**File:** `frontend/web/src/components/ideas/trade-idea-expanded-row.tsx`

Update the `TradeJournalChart` component to receive all VWAP props:

```typescript
<TradeJournalChart
  // ... existing props ...

  // VWAP props - ADD THESE
  showVwapToggle={true}
  isVwapPanelOpen={isVwapPanelOpen}
  onVwapPanelToggle={handleVwapPanelToggle}
  vwapConfig={vwapConfig}
  onVwapAutoPreviewUpdate={setVwapAutoPreviewTime}
  vwapCustomSelectingSlot={vwapCustomSelectingSlot}
  onVwapCustomAnchorSelect={handleVwapCustomAnchorSelect}
  vwapAlerts={vwapAlerts}
  vwapAlertPreview={alertPreview?.vwapSlot ? {
    vwapSlot: alertPreview.vwapSlot,
    vwapSigma: alertPreview.vwapSigma,
  } : null}
/>
```

### Step 6: Render VwapPanel Overlay

**File:** `frontend/web/src/components/ideas/trade-idea-expanded-row.tsx`

Add VwapPanel next to the chart (similar to journal layout):

```typescript
import { VwapPanel } from '@/components/journal/vwap-panel'

// In the JSX, add panel overlay:
{isVwapPanelOpen && (
  <VwapPanel
    ideaId={idea.id}
    legs={allLegs}  // idea legs for anchor dropdown
    activeSlot={vwapActiveSlot}
    onActiveSlotChange={handleVwapActiveSlotChange}
    customSelectingSlot={vwapCustomSelectingSlot}
    onClose={handleVwapPanelToggle}
    config={vwapConfig}
    onConfigChange={setVwapConfig}
    autoPreviewTime={vwapAutoPreviewTime}
    onStartCustomSelect={handleStartCustomSelect}
    onCancelCustomSelect={handleCancelCustomSelect}
  />
)}
```

### Step 7: Update Alert Preview for VWAP

**File:** `frontend/web/src/components/ideas/trade-idea-expanded-row.tsx`

Ensure `alertPreview` includes VWAP fields when editing VWAP alerts:

```typescript
// When building alertPreview, include vwap fields from the alert form
const alertPreview = useMemo(() => {
  if (!editingAlert) return null
  return {
    price: editingAlert.custom_price ?? 0,
    zoneMode: editingAlert.zone_mode ?? 'none',
    zoneValue: editingAlert.zone_value ?? null,
    name: editingAlert.name ?? null,
    // VWAP fields
    vwapSlot: editingAlert.vwapSlot,
    vwapSigma: editingAlert.vwapSigma,
  }
}, [editingAlert])
```

### Step 8: Update Ideas Store Types

**File:** `frontend/web/src/stores/ideasStore.ts`

Add VWAP-related fields to IdeaUIState:

```typescript
import type { VwapSlotId } from '../lib/vwap-types'

interface IdeaUIState {
  // ... existing fields ...

  // VWAP panel state
  isVwapPanelOpen: boolean
  vwapActiveSlot: VwapSlotId
  vwapCustomSelectingSlot: VwapSlotId | null
}

const defaultIdeaUIState: IdeaUIState = {
  // ... existing defaults ...

  isVwapPanelOpen: false,
  vwapActiveSlot: 'A',
  vwapCustomSelectingSlot: null,
}
```

## Files to Modify

| File | Changes |
|------|---------|
| `stores/ideasStore.ts` | Add VWAP UI state fields |
| `components/ideas/trade-idea-expanded-row.tsx` | Add VWAP state, fetch config, pass props, render panel |

## Files Already Supporting Ideas (No Changes Needed)

| File | Reason |
|------|--------|
| `components/journal/vwap-panel.tsx` | Already has `ideaId` prop support |
| `components/journal/trade-journal-chart.tsx` | Already has all VWAP props |
| `lib/api.ts` | Already has `vwapApi.getConfig(ideaId)` |
| `lib/vwap-calculator.ts` | Pure functions, no entity awareness |
| `lib/vwap-types.ts` | Generic types |
| `lib/tradelens/api/vwap.py` | Already has idea endpoints |

## Testing Checklist

- [ ] VWAP button appears in Ideas chart toolbar
- [ ] Clicking VWAP button opens panel
- [ ] Slot tabs (A/B/C) work correctly
- [ ] Enable toggle shows/hides VWAP lines
- [ ] Anchor types work: visible_low, visible_high, fill, custom
- [ ] Custom anchor click-to-select works
- [ ] Commit/Revert works for auto anchors
- [ ] Band presets display correctly (±1σ, ±2σ, ±3σ)
- [ ] Config persists after refresh (saved to DB)
- [ ] VWAP alerts can be created from alert form
- [ ] VWAP alert lines show on chart with bells
- [ ] Display toggles work (Show lines, Bold alerts)
- [ ] Global "Hide VWAP Lines" menu option works

## Notes

- No code duplication - VwapPanel is reused as-is
- VWAP config is stored per-idea in the same `vwap_config` table
- When trade is created from idea, VWAP config is already copied (via `copy_vwap_config_from_idea_to_trade`)
- Alert engine already supports VWAP alerts for ideas (via `trade_idea_id`)
