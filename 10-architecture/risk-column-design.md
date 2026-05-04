# Risk Column Design Analysis

## Executive Summary

This document analyzes the current R-metrics and risk calculation system in TradeLens, identifies inconsistencies, and proposes solutions for adding Initial Risk and Live Risk columns to the Trade Journal.

**User Requirements:**
1. Add **Initial Risk** column - uses initial stop from 10-minute window
2. Add **Live Risk** column - uses current/live stop loss
3. Both must use **WAEP including all DCAs** (not original entry price)
4. Rationale: DCAs fill before stop is hit, so true risk exposure is the full DCA'd position

---

## 1. Current Implementation

### 1.1 Data Sources

| Location | Field | Description |
|----------|-------|-------------|
| `trade_journal` table | `entry_price` | Final WAEP (after all DCAs) |
| `trade_journal` table | `initial_stop_price` | Stop from first 10 minutes |
| `trade_journal` table | `running_qty` | Current qty (open) or final qty (closed) |
| `trade_journal` table | `peak_qty` | Maximum position size during trade |
| Portfolio API | `stop_loss` | Current/live stop loss price |
| Portfolio API | `entry_price` | Current WAEP from Bybit |

### 1.2 Current R-Metrics Calculations

Located in `bin/pipeline/refresh_trade_journal.py`:

| Metric | Entry Price Used | Stop Price Used | Notes |
|--------|------------------|-----------------|-------|
| `get_risk_per_unit()` | `get_entry_waep()` (final WAEP) | `get_initial_10m_stop_price()` | Used for exit_r |
| `calculate_init_r()` | `get_original_entry_price()` (first fill) | `get_initial_10m_stop_price()` | Original entry only |
| `calculate_mfe_mae_time_to_1r()` | `get_original_entry_price()` (first fill) | `get_initial_10m_stop_price()` | Original entry only |
| `get_exit_r()` | `get_entry_waep()` (final WAEP) | via `get_risk_per_unit()` | Final WAEP |

### 1.3 Portfolio Page Risk Calculations

Located in `lib/tradelens/services/portfolio.py`:

| Column | Formula | Entry Price | Stop Price |
|--------|---------|-------------|------------|
| Stop Risk (E) | `\|entry - stop\| × qty` | Current WAEP (Bybit avgPrice) | **Live stop** |
| Stop Risk (L) | `\|mark - stop\| × qty` | Mark price | **Live stop** |

**Key observation:** Portfolio uses **live stop** for both, not initial stop.

---

## 2. Identified Issues & Inconsistencies

### 2.1 Mixed Entry Price References

The current code uses **different entry prices** for different metrics:

```
┌─────────────────────┬──────────────────────┬─────────────────────┐
│ Metric              │ Entry Price          │ Consistent?         │
├─────────────────────┼──────────────────────┼─────────────────────┤
│ exit_r              │ Final WAEP           │ ✓                   │
│ init_r              │ Original entry only  │ ✗ Different!        │
│ mfe_r / mae_r       │ Original entry only  │ ✗ Different!        │
│ Portfolio Risk (E)  │ Current WAEP         │ ✓                   │
└─────────────────────┴──────────────────────┴─────────────────────┘
```

**Problem:** `init_r` uses original entry price while `exit_r` uses final WAEP. This means:
- A trade with DCAs will have `init_r` calculated from a different base than `exit_r`
- The "R" unit is inconsistent between metrics

### 2.2 The DCA Problem

Consider this scenario:
```
Entry:  Buy 10 @ $50,000  (original entry)
DCA 1:  Buy 5  @ $48,000
DCA 2:  Buy 5  @ $46,000
Stop:   $44,000

Original Entry: $50,000
Final WAEP:     $48,000 = (10×50000 + 5×48000 + 5×46000) / 20

Risk per unit (original): |$50,000 - $44,000| = $6,000
Risk per unit (WAEP):     |$48,000 - $44,000| = $4,000
```

**Current behavior:**
- `init_r` uses $6,000 risk (original entry)
- `exit_r` uses $4,000 risk (WAEP)

**User's expectation:**
- All risk calculations should use WAEP because DCAs **will fill** before stop is hit
- The actual $ at risk is `|WAEP - Stop| × total_qty`, not `|original - Stop| × original_qty`

### 2.3 No "WAEP at 10 Minutes" Snapshot

Currently we don't capture WAEP at the 10-minute mark. We only have:
- Original entry price (first fill)
- Final WAEP (after all fills)

This matters because:
- Some DCAs may fill within the first 10 minutes
- Some DCAs may fill after 10 minutes
- The "initial risk" concept is ambiguous without this snapshot

### 2.4 Live Stop Not Available in Journal

The Trade Journal only stores `initial_stop_price`. To show "Live Risk":
- Open trades: Need to fetch from Portfolio API
- Closed trades: No live stop (position closed)

---

## 3. What We Need for the Risk Columns

### 3.1 Initial Risk Column

**Definition:** Dollar risk at entry, based on initial stop and WAEP

**Formula:** `|WAEP - initial_stop_price| × qty`

**Data required:**
- `entry_price` (WAEP) - already in journal
- `initial_stop_price` - already in journal
- `running_qty` or `peak_qty` - already in journal

**Question:** Which quantity to use?
- `running_qty`: Current position (changes with partial closes)
- `peak_qty`: Maximum position size (shows max risk exposure)

**Recommendation:** Use `peak_qty` for Initial Risk (shows planned max exposure)

### 3.2 Live Risk Column

**Definition:** Current dollar risk, based on current stop and WAEP

**Formula:** `|WAEP - live_stop| × qty`

**Data required:**
- `entry_price` (WAEP) - from journal or portfolio
- Live stop price - from Portfolio API (open trades only)
- `running_qty` - current position size

**Behavior by status:**
| Status | Live Risk |
|--------|-----------|
| `open` | Calculate from portfolio data |
| `closed` | Show "-" (no active risk) |
| `seeded` | Show "-" (entry not filled) |
| `pending_entry` | Show "-" (no position) |
| `cancelled` | Show "-" (no position) |

---

## 4. Options for Implementation

### Option A: Use Existing Data (Simplest)

**Initial Risk:**
- Formula: `|entry_price - initial_stop_price| × peak_qty`
- Source: All from `trade_journal` table
- Uses final WAEP (after all DCAs)

**Live Risk:**
- For open trades: Fetch from portfolio API (`stop_risk_entry` already calculated)
- For closed trades: Show "-"

**Pros:**
- No schema changes needed
- Portfolio already calculates stop_risk_entry
- Quick to implement

**Cons:**
- Initial Risk uses final WAEP, not WAEP-at-10-minutes
- Live Risk requires portfolio lookup (already happening for uPnL)

### Option B: Add WAEP Snapshot at 10 Minutes

**Schema change:** Add `waep_at_10m` column to `trade_journal`

**Initial Risk:**
- Formula: `|waep_at_10m - initial_stop_price| × qty_at_10m`
- Captures the exact state at the 10-minute mark

**Live Risk:**
- Same as Option A

**Pros:**
- Perfectly consistent with 10-minute snapshot rule
- Init R and Initial Risk use same reference point

**Cons:**
- Requires new column and backfill logic
- More complex pipeline changes
- What qty to use? (qty at 10m vs peak qty)

### Option C: Always Use Final WAEP (Pragmatic)

**Rationale:** DCAs will fill before stop, so final WAEP represents true average cost.

**Initial Risk:**
- Formula: `|final_waep - initial_stop_price| × peak_qty`

**Live Risk:**
- Formula: `|final_waep - live_stop| × running_qty`

**Also fix R-metrics:**
- Change `init_r` to use final WAEP instead of original entry
- Change `mfe_r`/`mae_r` to use final WAEP

**Pros:**
- Consistent entry price across all metrics
- Matches user's mental model (DCAs fill before stop)
- No new columns needed

**Cons:**
- Changes R-metric behavior (may affect historical data)
- init_r semantics change (was "RR of original entry" → "RR of full position")

### Option D: Hybrid Approach

Keep R-metrics as-is (for backward compatibility), but use final WAEP for Risk columns:

**Initial Risk:** `|final_waep - initial_stop_price| × peak_qty`
**Live Risk:** `|final_waep - live_stop| × running_qty`

**Pros:**
- No breaking changes to existing R-metrics
- Risk columns show practical $ exposure
- Clear separation: R-metrics = ratios, Risk = dollars

**Cons:**
- Conceptual inconsistency remains (R-metrics use different base)

---

## 5. Recommended Approach

**Recommendation: Option D (Hybrid) for now, Option C later**

### Phase 1: Add Risk Columns (Option D)

1. **Initial Risk column:**
   - Formula: `|entry_price - initial_stop_price| × peak_qty`
   - Uses final WAEP from journal
   - Show for: `open`, `closed`
   - Show "-" for: `seeded`, `pending_entry`, `cancelled`

2. **Live Risk column:**
   - For open trades: Use portfolio's `stop_risk_entry` (already calculated)
   - For closed/other: Show "-"
   - Tooltip: "Current risk based on live stop"

3. **Implementation:**
   - Add helper function `getInitialRisk(trade)` using journal data
   - Add helper function `getLiveRisk(trade, position)` using portfolio data
   - Add columns to header and data rows

### Phase 2: Fix R-Metrics Consistency (Option C) - Future

1. Update `calculate_init_r()` to use `get_entry_waep()` instead of `get_original_entry_price()`
2. Update `calculate_mfe_mae_time_to_1r()` similarly
3. Document the change and reasoning
4. Consider adding migration to recalculate historical R-metrics

---

## 6. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Trade Journal Page                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     │
│  │ Journal API  │     │ Portfolio API│     │   Combine    │     │
│  │              │     │              │     │              │     │
│  │ entry_price  │     │ stop_loss    │     │ Initial Risk │     │
│  │ initial_stop │────▶│ entry_price  │────▶│ Live Risk    │     │
│  │ peak_qty     │     │ mark_price   │     │              │     │
│  │ running_qty  │     │ qty          │     │              │     │
│  └──────────────┘     └──────────────┘     └──────────────┘     │
│                                                                  │
│  Initial Risk = |journal.entry_price - journal.initial_stop|    │
│                 × journal.peak_qty                               │
│                                                                  │
│  Live Risk = |portfolio.entry_price - portfolio.stop_loss|       │
│              × portfolio.qty                                     │
│              (or use portfolio.stop_risk_entry directly)         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Column Specifications

### Initial Risk Column

| Aspect | Specification |
|--------|---------------|
| Header | "Risk (I)" or "Init Risk" |
| Tooltip | "Initial Risk: (Entry WAEP - Initial Stop) × Peak Qty. Shows planned $ risk based on stop set within first 10 minutes." |
| Width | `w-20` (80px) |
| Position | After Entry, before PnL columns |
| Format | Currency, 2 decimals (e.g., "$1,234.56") |
| Color | White/neutral (informational) |

**Display by status:**
| Status | Value |
|--------|-------|
| `open` | Calculate from journal |
| `closed` | Calculate from journal |
| `seeded` | "-" |
| `pending_entry` | "-" |
| `cancelled` | "-" |

### Live Risk Column

| Aspect | Specification |
|--------|---------------|
| Header | "Risk (L)" or "Live Risk" |
| Tooltip | "Live Risk: (Entry WAEP - Current Stop) × Qty. Shows current $ risk based on current stop position." |
| Width | `w-20` (80px) |
| Position | After Initial Risk, before PnL columns |
| Format | Currency, 2 decimals |
| Color | White/neutral |

**Display by status:**
| Status | Value |
|--------|-------|
| `open` | From portfolio (stop_risk_entry) |
| `closed` | "-" |
| `seeded` | "-" |
| `pending_entry` | "-" |
| `cancelled` | "-" |

---

## 8. Questions to Resolve

1. **Quantity for Initial Risk:** Use `peak_qty` (max exposure) or `running_qty` (current/final)?
   - Recommendation: `peak_qty` for Initial Risk (shows planned max exposure)

2. **What if initial_stop_price is NULL?** (No stop set within 10 minutes)
   - Show "-" (same as R-metrics behavior)

3. **Should closed trades show Initial Risk?**
   - Yes - it's historical info about what the planned risk was

4. **Column naming:**
   - Option A: "Risk (I)" / "Risk (L)" - compact
   - Option B: "Init Risk" / "Live Risk" - clearer
   - Option C: "$ Risk" / "$ Risk (L)" - emphasizes dollars

5. **Should we also show Risk in R units?**
   - Current: Already have init_r, exit_r, mfe_r, mae_r
   - These are the R-unit versions of risk/reward

---

## 9. Implementation Checklist

### Frontend Changes (`trade-journal.tsx`)

- [ ] Add `getInitialRisk(trade: JournalListItem): number | null` helper
- [ ] Add `getLiveRisk(trade: JournalListItem, position: Position | null): number | null` helper
- [ ] Add header column for Initial Risk (after Entry)
- [ ] Add header column for Live Risk (after Initial Risk)
- [ ] Add data cells for both columns
- [ ] Add tooltips explaining each calculation
- [ ] Handle null/"-" display for non-applicable statuses

### Expanded Row Changes (`trade-journal-expanded-row.tsx`)

- [ ] Add Initial Risk to trade header info
- [ ] Add Live Risk to trade header info (if open)

### Backend Changes (if needed)

- [ ] Verify `initial_stop_price` is populated correctly
- [ ] Verify `peak_qty` is populated correctly
- [ ] Consider adding `stop_risk_initial` pre-calculated field (optional optimization)

---

## 10. Appendix: Code References

### Current R-Metric Calculations

```python
# refresh_trade_journal.py

def get_risk_per_unit(self) -> Optional[Decimal]:
    """Uses final WAEP"""
    entry_price = self.get_entry_waep()  # ← Final WAEP
    stop_price = self.get_initial_10m_stop_price()
    return abs(entry_price - stop_price)

def calculate_init_r(self) -> Optional[Decimal]:
    """Uses original entry price (inconsistent!)"""
    original_entry = self.get_original_entry_price()  # ← First fill only
    stop_price = self.get_initial_10m_stop_price()
    risk_per_unit = abs(original_entry - stop_price)
    # ... calculate weighted RR of TPs

def calculate_mfe_mae_time_to_1r(self, candles) -> Tuple:
    """Uses original entry price (inconsistent!)"""
    entry_price = self.get_original_entry_price()  # ← First fill only
    stop_price = self.get_initial_10m_stop_price()
    risk_per_unit = abs(entry_price - stop_price)
    # ... calculate MFE/MAE from candles
```

### Portfolio Risk Calculation

```python
# services/portfolio.py

# Stop Risk (Entry) = (Entry - Stop) * Qty
if side.lower() == 'long':
    stop_risk_entry = (entry_price - stop_loss) * qty
else:  # short
    stop_risk_entry = (stop_loss - entry_price) * qty

position['stop_risk_entry'] = float(abs(stop_risk_entry))
```

---

*Document created: 2026-02-07*
*Author: Claude Code Assistant*
