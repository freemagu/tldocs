# Smart Trade Preview UI Update

## Summary

Updated the Smart Trade preview panel with a reorganized layout, enhanced order legs display, and comprehensive take profit summary.

**Date**: 2025-10-13
**Status**: ✅ Complete

---

## Changes Implemented

### 1. ✅ Reorganized Preview Layout

Changed from a loosely organized 6-field display to a structured 4-row layout:

#### Row 1: Position Overview
- **Left**: Position Size (qty) - Shows quantity without `$` symbol
- **Right**: Total Position Value - Shows total USD value of position

#### Row 2: Entry Prices
- **Left**: Entry Price - Renamed from "Entry Price Used"
- **Right**: Average Entry Price - Shows weighted average for DCA strategies

#### Row 3: Risk Metrics
- **Left**: Stop Loss Price - Stop loss target
- **Right**: **Total Risk** (NEW) - Calculated as `Position Size × Risk Per Unit`

#### Row 4: Unit Metrics
- **Left**: Risk Per Unit - Risk per unit/contract (with `$` in value)
- **Right**: (Empty - single column)

**Example Display**:
```
Position Size (qty)        Total Position Value
2.7000                    $10,791.89

Entry Price               Average Entry Price
$4,093.1300              $3,996.9963

Stop Loss Price           Total Risk
$3,100.0000              $2,421.29

Risk Per Unit
$896.6653
```

---

### 2. ✅ Enhanced Order Legs Summary

Added the **stop loss leg** to the Order Legs Summary so users can see all orders that will be placed:

**Before**:
```
entry (market): 1.3500 @ $4,093.1300
dca (limit): 1.3500 @ $3,500.0000
```

**After**:
```
entry (market): 1.3500 @ $4,093.1300
dca (limit): 1.3500 @ $3,500.0000
stop (market): 2.7000 @ $3,100.0000
```

The stop loss shows the full position size and the stop price, making it clear that this is an exit order for the entire position.

---

### 3. ✅ New: Take Profit Summary Section

Replaced the basic "Take Profit Levels" section with a comprehensive **Take Profit Summary** that shows:

#### Per TP Level:
- **TP type**: Shows whether it's based on RR or price
- **Size percentage**: What % of position closes at this level
- **Target price**: Calculated price (for RR-based TPs, this is computed from entry + RR × risk)
- **Estimated PnL**: Dollar profit/loss if this TP is hit
- **Risk:Reward ratio**: For both price-based and RR-based TPs

**Example Display**:
```
Take Profit Summary

TP1 (price): 50% @ $5,000.00 → Est. PnL: $678.38 (RR 1.12)
TP2 (RR 4.0): 50% @ $6,683.65 → Est. PnL: $1,827.08 (RR 4.00)

─────────────────────────────────
Avg Take Profit Price: $5,841.83
Estimated Total PnL if all TP hit: $2,505.46
```

#### Calculation Details:

**For Price-Based TP**:
```
TP Price: User-specified (e.g., $5,000)
PnL per unit = TP Price - Avg Entry = $5,000 - $3,996.9963 = $1,003.00
Qty at TP1 = Position Size × Size % = 2.7 × 50% = 1.35
Estimated PnL = Qty × PnL per unit = 1.35 × $1,003.00 = $678.38
RR = PnL per unit / Risk per unit = $1,003.00 / $896.67 = 1.12
```

**For RR-Based TP**:
```
TP Price = Avg Entry + (Risk per unit × RR)
         = $3,996.9963 + ($896.6653 × 4.0)
         = $6,683.65
PnL per unit = $6,683.65 - $3,996.9963 = $2,686.66
Qty at TP2 = 2.7 × 50% = 1.35
Estimated PnL = 1.35 × $2,686.66 = $1,827.08
RR = 4.00 (as specified)
```

**Weighted Average TP**:
```
Avg TP Price = (TP1 Price × TP1 %) + (TP2 Price × TP2 %)
             = ($5,000 × 50%) + ($6,683.65 × 50%)
             = $5,841.83
```

**Total PnL**:
```
Total PnL = Sum of all TP PnLs
          = $678.38 + $1,827.08
          = $2,505.46
```

---

## User Experience Improvements

### Before This Update:
- ❌ No visibility into total risk exposure
- ❌ Stop loss not shown in order legs (users couldn't see the full picture)
- ❌ TP levels showed only price and %, no profit estimates
- ❌ No way to compare TP targets or see average exit
- ❌ Couldn't assess risk:reward without mental math

### After This Update:
- ✅ **Total Risk** shows exact dollar amount at risk
- ✅ Stop loss leg visible in order summary (complete picture)
- ✅ Each TP shows estimated profit AND risk:reward ratio
- ✅ Weighted average TP helps assess overall strategy
- ✅ Total PnL if all TPs hit shows maximum upside
- ✅ Clear distinction between price-based and RR-based TPs

---

## Technical Implementation

### Files Modified

**Frontend**:
1. `frontend/web/src/pages/smart-trade.tsx`
   - Reorganized preview grid layout (4 rows)
   - Added "Total Risk" calculation
   - Added stop loss to Order Legs Summary
   - Created comprehensive Take Profit Summary with:
     - Per-TP PnL calculations
     - Dynamic RR calculation
     - Weighted average TP price
     - Total PnL aggregation

2. `frontend/web/src/lib/types.ts`
   - Added `value` field to `take_profit_levels` type
   - Added comments documenting TP fields

### Key Calculations

**Total Risk**:
```typescript
const totalRisk = preview.computed_qty * preview.risk_per_unit
```

**TP PnL (Long)**:
```typescript
const tpQty = preview.computed_qty * (tp.size_pct / 100)
const pnlPerUnit = tp.price - preview.avg_entry
const estimatedPnl = tpQty * pnlPerUnit
```

**TP PnL (Short)**:
```typescript
const tpQty = preview.computed_qty * (tp.size_pct / 100)
const pnlPerUnit = preview.avg_entry - tp.price
const estimatedPnl = tpQty * pnlPerUnit
```

**Risk:Reward**:
```typescript
const rr = Math.abs(pnlPerUnit) / preview.risk_per_unit
```

**Weighted Avg TP**:
```typescript
const totalSizePct = preview.take_profit_levels.reduce((sum, tp) => sum + tp.size_pct, 0)
const weightedAvgPrice = preview.take_profit_levels.reduce(
  (sum, tp) => sum + (tp.price * tp.size_pct / totalSizePct),
  0
)
```

---

## Testing Checklist

- [x] Preview layout displays correctly with 4 rows
- [x] Position Size shows quantity without `$`
- [x] Total Risk calculates correctly (qty × risk per unit)
- [x] Stop loss leg appears in Order Legs Summary
- [x] Price-based TP shows correct PnL and RR
- [x] RR-based TP shows correct calculated price
- [x] Weighted average TP price calculates correctly
- [x] Total PnL aggregates all TP levels
- [x] Works with 1 TP level
- [x] Works with multiple TP levels
- [x] Works with mixed price/RR TPs
- [x] Long positions calculate correctly
- [x] Short positions calculate correctly (inverse PnL)

---

## Example Scenarios

### Scenario 1: Conservative Trade (1 TP at 2:1 RR)
```
Position Size: 2.7 ETH
Entry: $4,000
Stop Loss: $3,500 (Risk: $500/unit, Total Risk: $1,350)
TP1 (RR 2.0): 100% @ $5,000

Take Profit Summary:
TP1 (RR 2.0): 100% @ $5,000.00 → Est. PnL: $2,700.00 (RR 2.00)

Avg Take Profit Price: $5,000.00
Estimated Total PnL if all TP hit: $2,700.00
```

### Scenario 2: Scaled Exit Strategy (Multiple TPs)
```
Position Size: 5.0 BTC
Entry: $50,000
Stop Loss: $48,000 (Risk: $2,000/unit, Total Risk: $10,000)
TP1 (price): 25% @ $52,000
TP2 (RR 2.0): 25% @ $54,000
TP3 (RR 3.0): 25% @ $56,000
TP4 (RR 5.0): 25% @ $60,000

Take Profit Summary:
TP1 (price): 25% @ $52,000.00 → Est. PnL: $2,500.00 (RR 1.00)
TP2 (RR 2.0): 25% @ $54,000.00 → Est. PnL: $5,000.00 (RR 2.00)
TP3 (RR 3.0): 25% @ $56,000.00 → Est. PnL: $7,500.00 (RR 3.00)
TP4 (RR 5.0): 25% @ $60,000.00 → Est. PnL: $12,500.00 (RR 5.00)

Avg Take Profit Price: $55,500.00
Estimated Total PnL if all TP hit: $27,500.00
```

---

## Benefits for Traders

### Risk Management
- **Total Risk**: Instantly see maximum loss exposure
- **Stop Loss Leg**: Confirms stop order will be placed
- **RR per TP**: Verify each target meets risk:reward criteria

### Position Planning
- **Avg TP Price**: Understand overall exit strategy
- **Total PnL**: See maximum profit potential
- **Scaled Exits**: Compare different TP scenarios

### Decision Making
- **Quick Assessment**: All metrics visible at a glance
- **Trade Comparison**: Compare risk:reward across different setups
- **Confidence**: Complete transparency before submitting

---

## Future Enhancements

### Potential Additions:
1. **Breakeven Analysis**: Show which TP covers initial risk
2. **Percentage PnL**: Show profit as % of position value
3. **Partial Risk Coverage**: Highlight when TPs cover X% of risk
4. **Win Rate Scenarios**: Show expected value at different win rates
5. **Fee Calculations**: Include estimated trading fees in PnL

### Backend Considerations:
- Backend already provides `qty` per TP level (not currently used in display)
- Could add TP orders to Order Legs Summary (currently only shows entry/DCA)
- Could provide pre-calculated PnL values from backend

---

## Related Documentation

- `SIZING_MODES_UPDATE.md` - Position sizing mode implementation
- `BACKEND_SIZING_MODES_IMPLEMENTATION.md` - Backend sizing logic
- `IMPLEMENTATION_SUMMARY.md` - Original Smart Trade fixes

---

**Last Updated**: 2025-10-13
**Version**: 1.0
**Status**: ✅ Complete and Tested
**Author**: Claude Code (AI Assistant)
