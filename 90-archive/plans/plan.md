# P&L Projection v1 — Design Document

## Scope

### In-Scope

- One-click chart toolbar button that opens a projection modal.
- Curated set of trade outcome scenarios derived from the current working plan.
- Gross P&L, P&L %, R-Multiple, and Capital Deployed per scenario.
- Supports long and short positions, linear and spot markets.
- Reads live plan state (`SmartTradeFormValues` from Zustand) — no save or Preview click required.
- 100% frontend computation via a pure TypeScript module (`projection-engine.ts`).
- Adaptive scenario filtering based on plan complexity (number of DCAs and TPs).

### Out-of-Scope

- Transaction costs (fees, slippage, funding) are explicitly out-of-scope for v1 and may be introduced in a future iteration.
- Net P&L (requires fee modelling).
- Break-even stop scenarios (BE logic exists in the system for leg classification, but the SmartTrade planning form does not expose BE configuration — the user cannot express "move stop to entry after TP1." This is a v2 scenario pending form support). v1 will NOT infer break-even stop behaviour from journal history or stop modifications. BE scenarios require explicit configuration in the SmartTrade planning form before they can be modelled. No implicit BE modelling will occur in v1.
- Inverse contracts.
- New API endpoints or backend computation.
- Database schema changes or migrations.
- Persisting projection results.

---

## Assumptions

1. **Primary context is the Ideas expanded row** (plan editing + chart). Secondary context is the standalone SmartTrade page.
2. **"Current working plan"** means the live `SmartTradeFormValues` in the Zustand store (`smartTradeStore` or the per-idea `SmartTradeFormDraft` in `ideasStore`), not persisted database state.
3. **Position sizing is derivable from form state.** The form contains `sizingMode`, `riskUsd`/`positionQty`/`positionUsd`, `stopLoss`, `entryPct`, and DCA percentages — enough to compute total quantity and per-leg quantities without calling the backend. If a cached `TradePreviewResponse` exists, it may be used as an optimisation to skip re-deriving quantities, but is never a prerequisite.
4. **Entry price** for limit orders is `limitPrice`; for market orders the projection uses `marketRefPrice` as the primary source (the reference price provided by the Ideas context or SmartTrade page). The last-known chart candle close is used as a fallback only if `marketRefPrice` is unavailable. This ordering is deterministic: `marketRefPrice` first, chart fallback second, to avoid mismatches between projection and preview.
5. **TP price resolution** follows existing logic: `type='price'` uses the absolute value; `type='rr'` computes `entry ± (rr × |entry − stop|)`; `type='percent'` computes `entry × (1 ± pct/100)`.
6. **TP size_pct distribution**: if all TPs have blank `size_pct`, they split evenly (100% / N). If all are specified, they must sum to 100%. Mixed blank/specified is invalid and the projection shows a validation warning.
7. **DCA pct distribution**: same logic — `entryPct` plus DCA percentages define the fraction of total quantity at each fill level.
8. **R-Multiple base**: initial risk is defined as `|entryPrice − stopLoss| × entryQty` (entry-only quantity, before any DCA), consistent with how the system defines initial risk elsewhere. R is always anchored to this initial entry-only risk. In scenarios where DCAs fill and the stop hits, the total loss exceeds the initial risk, so R-multiples below -1.0R are expected and correct behaviour (e.g., "All DCAs → Stop" may produce -3.1R).

---

## Scenario Philosophy

A trader planning a trade asks three questions:

1. **Best case** — "What if the trade works perfectly?"
2. **Worst case** — "What's the maximum I can lose?"
3. **Partial outcomes** — "What if it partially works then reverses?"

Every permutation of DCA-fills × TP-fills × stop is exponential. A plan with 3 DCAs and 3 TPs produces dozens of paths. Instead, we model **realistic trade narratives** — sequences that actually happen in markets. Each scenario tells a complete story from position open to position close.

The scenarios are grouped into three categories:

- **Win scenarios**: all TPs hit (with different DCA fill states).
- **Loss scenarios**: stop hits (with different DCA fill states).
- **Partial scenarios**: some TPs hit, then stop hits on the remainder.

This covers the full spectrum from best to worst while staying under 10 rows.

---

## Curated Scenario Table

| # | Scenario | Fills | Exits | Category | Why included |
|---|----------|-------|-------|----------|--------------|
| 1 | **Full Win** | Entry only | All TPs hit | Win | Best case — the plan works, no DCA needed |
| 2 | **DCA1 → Full Win** | Entry + DCA1 | All TPs hit | Win | Common recovery — dipped to DCA1, then ran |
| 3 | **All DCAs → Full Win** | Entry + all DCAs | All TPs hit | Win | Maximum cost basis, full recovery to all TPs |
| 4 | **Clean Stop** | Entry only | Stop on full position | Loss | Quick loss — trade didn't work, moved on |
| 5 | **DCA1 → Stop** | Entry + DCA1 | Stop on full position | Loss | Added to a loser then stopped — common regret |
| 6 | **All DCAs → Stop** | Entry + all DCAs | Stop on full position | Loss | Worst case — maximum capital at risk, full stop |
| 7 | **TP1 → Stop** | Entry only | TP1 partial close, stop on remainder | Partial | Locked some profit, stopped on rest |
| 8 | **TP1+TP2 → Stop** | Entry only | TP1+TP2 partial close, stop on remainder | Partial | More profit locked before reversal |
| 9 | **DCA1 → TP1 → Stop** | Entry + DCA1 | TP1 partial close, stop on remainder | Partial | Messy middle — DCA'd in, got one TP, then lost |

### Adaptive Filtering Rules

| Plan shape | Scenarios shown |
|------------|----------------|
| 0 DCAs, 1 TP | #1, #4, (only 4 rows — no DCA or partial scenarios apply) |
| 0 DCAs, 2+ TPs | #1, #4, #7, #8 |
| 1 DCA, 1 TP | #1, #2, #4, #5 |
| 1 DCA, 2+ TPs | #1, #2, #4, #5, #7, #8, #9 |
| 2+ DCAs, 1 TP | #1, #2, #3, #4, #5, #6 |
| 2+ DCAs, 2+ TPs | All 9 scenarios |
| 3+ TPs | Add **TP1+TP2+TP3 → Stop** row (extends #8 pattern) |

Scenarios that require legs the plan doesn't have are omitted entirely — not shown as disabled or grayed rows.

### v2 Scenarios (Documented for Future)

- **TP1 → BE Stop**: TP1 hits, stop moves to entry (breakeven), then stop triggers at entry. Requires BE configuration in the SmartTrade form (not currently available).
- **Trailing stop scenarios**: TP1 hits, trailing stop activates, locks in variable profit. Requires trailing stop modelling in the projection engine.

---

## Three UX Proposals

### Proposal A: Projection Modal

**Interaction:** A "P&L" button added to the chart toolbar row (between the reset/settings group and the VWAP button area). Click opens a `max-w-5xl` modal dialog. The modal reads the current form state from Zustand and computes instantly — no API call, no prior Preview click needed. Closing the modal returns to the chart. Reopening recomputes from current state.

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│  P&L Projection                                        [X]  │
│  BTCUSDT · Long · Limit Entry @ 95,000 · Stop @ 94,500      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  WIN SCENARIOS                                               │
│  ┌──────────────────┬───────────┬─────────┬───────┬────────┐ │
│  │ Scenario         │ Gross P&L │  P&L %  │   R   │Capital │ │
│  ├──────────────────┼───────────┼─────────┼───────┼────────┤ │
│  │ ▌ Full Win       │  +$2,500  │  +5.0%  │ +5.0R │ $50.0K │ │
│  │ ▌ DCA1 → Win     │  +$3,200  │  +4.3%  │ +6.4R │ $75.0K │ │
│  │ ▌ All DCA → Win  │  +$4,900  │  +3.9%  │ +9.8R │$125.0K │ │
│  └──────────────────┴───────────┴─────────┴───────┴────────┘ │
│                                                              │
│  PARTIAL SCENARIOS                                           │
│  ┌──────────────────┬───────────┬─────────┬───────┬────────┐ │
│  │ ▌ TP1 → Stop     │    +$180  │  +0.4%  │ +0.4R │ $50.0K │ │
│  │ ▌ TP1+2 → Stop   │    +$650  │  +1.3%  │ +1.3R │ $50.0K │ │
│  │ ▌ DCA1→TP1→Stop  │    -$120  │  -0.2%  │ -0.2R │ $75.0K │ │
│  └──────────────────┴───────────┴─────────┴───────┴────────┘ │
│                                                              │
│  LOSS SCENARIOS                                              │
│  ┌──────────────────┬───────────┬─────────┬───────┬────────┐ │
│  │ ▌ Clean Stop     │    -$500  │  -1.0%  │ -1.0R │ $50.0K │ │
│  │ ▌ DCA1 → Stop    │  -$1,025  │  -1.4%  │ -2.1R │ $75.0K │ │
│  │ ▌ All DCA → Stop │  -$1,550  │  -1.2%  │ -3.1R │$125.0K │ │
│  └──────────────────┴───────────┴─────────┴───────┴────────┘ │
│                                                              │
│  Initial Risk: $500 · Reward/Risk (full win): 5.0 : 1       │
├─────────────────────────────────────────────────────────────┤
│  Plan has validation issues:                                 │
│  ⚠ TP size_pct values do not sum to 100%                    │
└─────────────────────────────────────────────────────────────┘
```

**Visual treatment:**
- Left-edge color bar per row: green gradient for wins, yellow/amber for partials, red gradient for losses. Enables instant visual scanning before reading numbers.
- Positive P&L in `text-green-400`, negative in `text-red-400`.
- R-Multiple is the visually dominant column (slightly larger font weight).
- Validation warnings (incomplete plan, missing stop, etc.) shown in a footer band.
- If the plan is too incomplete to compute (no entry price, no stop), the modal body shows a single message explaining what's missing.

**Component structure:**
```
PnlProjectionButton              (chart toolbar — icon + "P&L" label)
└── PnlProjectionModal            (Dialog wrapper, max-w-5xl)
    ├── ProjectionHeader           (symbol · side · entry · stop summary)
    ├── ScenarioSection × 3        ("Win" / "Partial" / "Loss" groups)
    │   ├── SectionLabel           (group heading)
    │   └── ScenarioTable          (<table> with scenario rows)
    │       └── ScenarioRow × N
    ├── ProjectionFooter           (initial risk, reward/risk ratio)
    └── ValidationBanner           (warnings if plan is incomplete)
```

**Pros:**
- Maximum space for the scenario table — 9 rows × 4 columns renders cleanly without truncation or scrolling.
- Clean separation: edit plan → study outcomes → adjust → re-check. Matches the natural analytical workflow.
- Consistent with existing modal patterns (`BatchIdeasModal`, `EditJsonModal`, `Dialog` primitive).
- Works identically on all screen sizes — no layout compression.
- Zero conflicts with existing panels (VWAP, preview, notes, alerts).
- Simplest implementation — the `Dialog` primitive already exists.

**Cons:**
- Chart and form are hidden while the modal is open. Cannot see price levels alongside P&L numbers.
- Open/close cycle required for each plan adjustment.
- Feels "heavy" for a quick glance.

**When to choose:** When data density and readability are the priority. Best when the user finalizes the plan then studies projections, rather than tweaking and checking in rapid alternation.

---

### Proposal B: Slide-Out Side Panel

**Interaction:** Same "P&L" toolbar button. Click opens a right-side slide-out panel (same pattern as `trade-preview-panel.tsx`). The panel sits alongside the chart; the chart compresses horizontally to make room.

**Layout:**

```
┌───────────────────────────────────┬───────────────────────┐
│                                   │ P&L Projection   [X]  │
│                                   │ BTCUSDT · Long        │
│                                   │ Entry 95K · SL 94.5K  │
│          [Chart Area]             ├───────────────────────┤
│          (compressed ~70% width)  │ ▸ WIN                 │
│                                   │  Full Win     +$2,500 │
│                                   │               +5.0R   │
│                                   │  DCA1→Win    +$3,200 │
│                                   │               +6.4R   │
│                                   │  AllDCA→Win  +$4,900 │
│                                   │               +9.8R   │
│                                   ├───────────────────────┤
│                                   │ ▸ PARTIAL             │
│                                   │  TP1→Stop      +$180 │
│                                   │               +0.4R   │
│                                   ├───────────────────────┤
│                                   │ ▸ LOSS                │
│                                   │  Clean Stop    -$500  │
│                                   │              -1.0R    │
│                                   │  AllDCA→Stop -$1,550 │
│                                   │              -3.1R    │
│                                   ├───────────────────────┤
│                                   │ Risk: $500            │
│                                   │ R/R: 5.0:1            │
│                                   └───────────────────────┘
```

**Component structure:**
```
PnlProjectionButton              (chart toolbar toggle)
└── PnlProjectionPanel            (right slide-out, ~300px width)
    ├── PanelHeader                (symbol, side, entry, stop, close btn)
    ├── ScenarioGroup × 3          (collapsible Win / Partial / Loss)
    │   └── ScenarioCard × N       (compact: name + P&L + R stacked)
    └── RiskSummary                (initial risk, R/R)
```

**Pros:**
- Chart remains visible — can cross-reference price levels with P&L numbers.
- Persistent — stays open while editing; no open/close cycle.
- Familiar pattern — users already know the slide-out from the preview panel.
- Can coexist with the form (form is in the bottom-left quadrant in Ideas layout).

**Cons:**
- Limited width (~280-320px) forces a card-based layout. Metrics stack vertically per scenario, reducing at-a-glance comparison across rows. No room for a proper table with column headers.
- Compresses the chart horizontally — problematic on smaller screens or when many order levels are drawn.
- Potential conflict with other right-side panels if added in the future.
- P&L % and Capital Deployed columns must be dropped or moved to tooltips due to width constraints.

**When to choose:** When the user frequently alternates between editing and checking, and the plan is simple enough (1-2 DCAs, 1-2 TPs) that a compact card list is sufficient.

---

### Proposal C: Popover Panel

**Interaction:** Same "P&L" toolbar button. Click opens a floating popover anchored below the button, overlaying the top-right area of the chart. Click-away or button toggle to close. Chart remains full size underneath.

**Layout:**

```
  [1m][5m][15m][1h][4h][1D] [Orders▾] [VWAP▾] [P&L ▾] [⟲][⚙▾]
                                        │
                               ┌────────┴────────────────┐
                               │ P&L Projection          │
                               │ Long · Entry 95K        │
                               ├──────────┬──────┬───────┤
                               │ Scenario │ P&L  │   R   │
                               ├──────────┼──────┼───────┤
                               │ Full Win │+$2.5K│ +5.0R │
                               │ DCA1→Win │+$3.2K│ +6.4R │
                               │ TP1→Stop │ +$180│ +0.4R │
                               │ Clean SL │ -$500│ -1.0R │
                               │ DCA1→SL  │-$1.0K│ -2.1R │
                               │ Max Loss │-$1.6K│ -3.1R │
                               ├──────────┴──────┴───────┤
                               │ Risk: $500  R/R: 5.0:1  │
                               └─────────────────────────┘
```

**Component structure:**
```
PnlProjectionButton              (chart toolbar toggle, tracks open state)
└── PnlProjectionPopover          (absolutely positioned, z-[150])
    ├── CompactHeader              (side, entry — single line)
    ├── CompactTable               (3 columns: scenario, P&L, R)
    └── SummaryRow                 (risk, R/R)
```

**Pros:**
- Chart is fully visible underneath — zero layout displacement.
- Lightweight — feels like a tooltip/dropdown, low cognitive overhead.
- One-click toggle; familiar interaction (same as Settings dropdown, just larger).
- Works well for quick glances during rapid plan iteration.

**Cons:**
- Covers part of the chart (top-right corner, typically ~350×400px).
- Width constraint limits to 3 columns — P&L % and Capital Deployed must be dropped entirely.
- Needs viewport-aware positioning logic (don't overflow off-screen).
- Feels less "serious" — may not convey the analytical weight of the data.
- Harder to group scenarios visually in a compact space (no room for section headers).

**When to choose:** When projections are a quick-reference tool checked frequently, not a detailed analysis artifact. Best for experienced users who just need to glance at R-multiples.

---

## Recommendation: Proposal A (Modal)

**Recommended: Proposal A (Projection Modal).**

**Rationale:**

1. **Data density demands space.** Up to 9 scenarios × 4 metric columns is a real table. Proposals B and C force compromises — stacking metrics, dropping columns, abbreviating scenario names. The modal gives the table room to breathe and be scannable.

2. **Projection is a discrete analytical action.** Traders don't continuously stare at P&L projections while adjusting a stop price pixel by pixel. The natural workflow is: draft the plan → check the math → adjust if needed → check again. The modal's open/close cycle matches this rhythm. The edit→study→edit loop is 2 clicks (open, close) — lightweight enough.

3. **The existing preview panel validates the pattern.** `trade-preview-panel.tsx` already shows a TP × DCA-fill matrix in a panel. The projection modal is the richer, grouped, narrative-based evolution of that same concept. Users will understand it immediately.

4. **No layout conflicts.** The Ideas expanded row already has 4 quadrants (chart, secondary chart, planning form, notes), plus VWAP panels, alert forms, and note editors competing for space. A modal sidesteps all of this.

5. **Simplest implementation path.** The `Dialog` primitive exists. The computation is pure frontend arithmetic. No new layout states, no resize logic, no positioning calculations.

**Refinement:** Add a subtle left-edge color bar on each scenario row — green for wins, amber for partials, red for losses — for instant visual categorisation before the numbers are read.

---

## Data & Compute Approach

### Architecture

```
SmartTradeFormValues (Zustand)
        │
        ▼
┌─────────────────────────┐
│  projection-engine.ts   │  Pure TypeScript, no React
│                         │
│  resolvePlan(form) →    │  Derive entry price, per-leg quantities,
│    ResolvedPlan          │  TP prices from RR/pct/abs
│                         │
│  generateScenarios(     │  Build applicable scenario templates,
│    plan) → Scenario[]   │  filter by plan shape
│                         │
│  computeScenario(       │  WAEP, gross P&L, P&L %, R-multiple,
│    plan, template)      │  capital deployed
│    → ScenarioResult     │
└─────────────────────────┘
        │
        ▼
  PnlProjectionModal (React)
  renders ScenarioResult[]
```

### Inputs

All inputs come from frontend state. No API call required.

| Input | Source | Derivation |
|-------|--------|------------|
| `side` | `SmartTradeFormValues.side` | Direct |
| `entryPrice` | `limitPrice` (limit) or `marketRefPrice` (market) | Form field or Ideas context |
| `entryType` | `SmartTradeFormValues.entryType` | `'market'` or `'limit'` |
| `stopLoss` | `SmartTradeFormValues.stopLoss` | Direct |
| `entryPct` | `SmartTradeFormValues.entryPct` | % of total qty at entry |
| `dcaLevels` | `SmartTradeFormValues.dcaLevels` | `{ price, pct }[]` |
| `tpLevels` | `SmartTradeFormValues.tpLevels` | `{ type, value, size_pct }[]` |
| `sizingMode` | `SmartTradeFormValues.sizingMode` | `'quantity'` / `'usd_value'` / `'risk_amount'` |
| `positionQty` | Form sizing fields | One of `positionQty`, `positionUsd`, `riskUsd` depending on mode |
| Cached preview | `TradePreviewResponse` (optional) | If available, use `computed_qty` and `legs[]` as optimisation |

### Plan Resolution (`resolvePlan`)

This step converts raw form strings into a normalised `ResolvedPlan` with numeric values and computed quantities.

```
1. Parse entry price:
   - Limit: parseFloat(form.limitPrice)
   - Market: use marketRefPrice from context

2. Parse stop loss: parseFloat(form.stopLoss)

3. Compute total quantity based on sizing mode:
   - risk_amount: totalQty = riskUsd / |entryPrice - stopLoss|
   - quantity:    totalQty = parseFloat(form.positionQty)
   - usd_value:   totalQty = positionUsd / entryPrice

4. Distribute quantity across legs using entryPct and dcaPcts:
   - entryQty = totalQty × (entryPct / 100)
   - dca[i].qty = totalQty × (dca[i].pct / 100)
   - If percentages are all blank: distribute evenly across entry + DCAs

5. Resolve TP prices:
   - type='price': tp.price = parseFloat(tp.value)
   - type='rr':    tp.price = entryPrice + (direction × parseFloat(tp.value) × |entryPrice - stopLoss|)
   - type='percent': tp.price = entryPrice × (1 + direction × parseFloat(tp.value) / 100)
   where direction = +1 (long) or -1 (short)

6. Resolve TP size_pct:
   - All blank: each gets 100 / tpCount
   - All specified: validate sum = 100
   - Mixed: validation error

7. Return ResolvedPlan { side, entryPrice, stopLoss, entryQty, dcaLegs[], tpLegs[], totalQty }
```

### Scenario Generation (`generateScenarios`)

```
1. Count DCAs and TPs in the resolved plan.
2. Select applicable scenario templates from the master list using the adaptive filtering table.
3. For each template, bind concrete legs:
   - "Entry only" fills → [entryLeg]
   - "Entry + DCA1" fills → [entryLeg, dcaLegs[0]]
   - "All DCAs" fills → [entryLeg, ...dcaLegs]
   - "All TPs" exits → tpLegs applied sequentially to position
   - "TP1 → Stop" exits → [tpLegs[0], stopOnRemainder]
   - "Stop on full" exits → [stopOnAll]
4. Return ScenarioTemplate[] with bound legs.
```

### Per-Scenario Calculation (`computeScenario`)

```
Given: fillLegs[] (entry + DCAs that fill), exitEvents[] (TPs and/or stop)

─── Position Build ───
1. cumulative_qty = Σ(fillLeg.qty)
2. cumulative_cost = Σ(fillLeg.qty × fillLeg.price)
3. waep = cumulative_cost / cumulative_qty

─── Exit Sequence ───
4. remaining_qty = cumulative_qty
5. gross_pnl = 0

6. For each exit in order:
   if exit is TP:
     exit_qty = cumulative_qty × (exit.size_pct / 100)
   if exit is SL_ON_REMAINDER:
     exit_qty = remaining_qty

   pnl_per_unit = (exit.price - waep) × direction
     where direction = +1 (long) or -1 (short)
   gross_pnl += pnl_per_unit × exit_qty
   remaining_qty -= exit_qty

─── Metrics ───
7. capital_deployed = waep × cumulative_qty
     (gross notional value of the position — NOT margin used and NOT account equity at risk)
8. pnl_pct = (gross_pnl / capital_deployed) × 100
9. initial_risk = |entryPrice - stopLoss| × entryQty
     (entryQty = entry-only quantity, NOT cumulative)
10. r_multiple = gross_pnl / initial_risk
```

### Validation

The engine must handle incomplete plans gracefully:

| Missing input | Behaviour |
|---------------|-----------|
| No entry price | Return `{ valid: false, reason: 'Entry price required' }` |
| No stop loss | Return `{ valid: false, reason: 'Stop loss required' }` |
| No TPs | Show only loss scenarios (stop-only outcomes) |
| No sizing info | Return `{ valid: false, reason: 'Position size required' }` |
| TP size_pct don't sum to 100 | Return `{ valid: false, reason: 'TP size percentages must sum to 100%' }` — hard error, projection will not compute. No auto-normalisation. |
| DCA+entry pcts don't sum to 100 | Compute with provided values, attach warning |

---

## Module & File Layout

```
frontend/web/src/
├── lib/
│   └── projection-engine.ts          # Pure functions, no React
│       ├── resolvePlan()             # Form state → ResolvedPlan
│       ├── generateScenarios()       # ResolvedPlan → ScenarioTemplate[]
│       ├── computeScenario()         # (ResolvedPlan, Template) → ScenarioResult
│       ├── computeAllScenarios()     # Orchestrator: resolve → generate → compute all
│       └── types                     # ResolvedPlan, ScenarioTemplate, ScenarioResult, etc.
│
├── components/
│   └── smart-trade/
│       ├── pnl-projection-button.tsx # Chart toolbar button (icon + "P&L" text)
│       └── pnl-projection-modal.tsx  # Dialog shell, reads Zustand, calls engine, renders table
│           ├── ProjectionHeader      # Symbol · side · entry · stop
│           ├── ScenarioSection       # Group heading + table (Win / Partial / Loss)
│           ├── ScenarioRow           # Single row: color bar + name + metrics
│           ├── ProjectionFooter      # Initial risk, reward/risk
│           └── ValidationBanner      # Warnings for incomplete plans
│
└── lib/
    └── __tests__/
        └── projection-engine.test.ts # Unit tests for the pure engine
```

No new stores required. Fee config store is out of scope for v1.

---

## MVP Checklist

### Engine (`projection-engine.ts`)

- [ ] Define TypeScript types: `ResolvedPlan`, `ResolvedLeg`, `ScenarioTemplate`, `ScenarioResult`, `ProjectionOutput`, `ValidationIssue`
- [ ] Implement `resolvePlan(formValues, marketRefPrice?)` — parse form strings to numeric plan; handle all three sizing modes; resolve TP prices from RR/price/percent
- [ ] Implement `generateScenarios(plan)` — apply adaptive filtering rules; return applicable templates with bound legs
- [ ] Implement `computeScenario(plan, template)` — WAEP calculation, exit sequence with partial closes, gross P&L, P&L %, R-multiple, capital deployed
- [ ] Implement `computeAllScenarios(formValues, marketRefPrice?)` — top-level orchestrator that calls resolve → generate → compute; returns `ProjectionOutput` with results + validations
- [ ] Handle short positions (direction multiplier throughout)
- [ ] Handle edge cases: single TP, no DCAs, all-blank size_pct, stop === entry
- [ ] Return structured validation errors for incomplete plans (no entry, no stop, no sizing)

### Unit Tests (`projection-engine.test.ts`)

- [ ] Long position, no DCAs, 2 TPs: verify Full Win, Clean Stop, TP1→Stop scenarios
- [ ] Long position, 2 DCAs, 3 TPs: verify all 9 scenarios produce correct P&L
- [ ] Short position, 1 DCA, 2 TPs: verify direction handling (short profits when price falls)
- [ ] Risk-amount sizing mode: verify totalQty = riskUsd / |entry - stop|
- [ ] RR-based TP resolution: verify TP price = entry + rr × risk_per_unit
- [ ] Percent-based TP resolution: verify TP price = entry × (1 + pct/100)
- [ ] Blank size_pct on all TPs: verify even distribution
- [ ] Incomplete plan (no stop): verify validation error returned, no crash
- [ ] R-multiple uses entry-only quantity as risk base, not cumulative DCA quantity
- [ ] Adaptive filtering: 0 DCAs plan produces only non-DCA scenarios

### UI (`pnl-projection-button.tsx` + `pnl-projection-modal.tsx`)

- [ ] Add "P&L" button to chart toolbar in `trade-journal-chart.tsx` (Ideas context) and SmartTrade page
- [ ] Button reads Zustand form state and passes to engine on modal open
- [ ] Modal uses existing `Dialog` / `DialogContent` / `DialogHeader` primitives
- [ ] Render three grouped sections: Win / Partial / Loss
- [ ] Each scenario row: left color bar (green/amber/red), scenario name, Gross P&L, P&L %, R-Multiple, Capital Deployed
- [ ] Positive values in `text-green-400`, negative in `text-red-400`
- [ ] Footer: initial risk amount, reward-to-risk ratio (full win gross / initial risk)
- [ ] Validation banner: show warnings when plan is incomplete or has issues
- [ ] Empty state: if plan is too incomplete to compute, show centered message with what's missing
- [ ] Clicking outside or X closes the modal
- [ ] Modal re-computes from current state each time it opens (no stale data)
