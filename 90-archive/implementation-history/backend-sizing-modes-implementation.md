# Backend Position Sizing Modes Implementation

## Overview

This document describes the backend implementation of the three position sizing modes for the Smart Trade feature. The backend now supports `quantity`, `usd_value`, and `risk_amount` modes, translating each mode into the existing risk-based position sizing calculation.

---

## Implementation Summary

### Date
2025-10-13

### Status
✅ **Complete and Tested**

### Changes Made

#### 1. Updated DTO Models (`lib/tradelens/models/dto.py`)

Added new optional fields to `TradePreviewRequest` while maintaining backward compatibility:

```python
class TradePreviewRequest(BaseModel):
    # ... existing fields ...

    # Position sizing mode (new)
    sizing_mode: Optional[str] = Field('risk_amount', description="'quantity', 'usd_value', or 'risk_amount'")
    market_type: Optional[str] = Field(None, description="'spot', 'usdt_perp', or 'inverse'")

    # Position sizing fields (one will be used based on sizing_mode)
    position_qty: Optional[float] = Field(None, description="Position size in quantity (for quantity mode)")
    position_usd: Optional[float] = Field(None, description="Position size in USD (for usd_value mode)")
    risk_usd: Optional[float] = Field(None, description="Risk amount in USD (for risk_amount mode)")

    # Legacy fields for backward compatibility
    stop_loss: Optional[float] = Field(None, description="Stop loss price (optional except in risk_amount mode)")
    desired_risk_usd: Optional[float] = Field(None, description="[DEPRECATED] Use risk_usd instead")
```

**Key Design Decisions**:
- `sizing_mode` defaults to `'risk_amount'` for backward compatibility
- All new sizing fields are optional
- Legacy `desired_risk_usd` field remains for backward compatibility
- `stop_loss` is now optional (required only in risk_amount mode)

#### 2. Updated API Endpoint (`lib/tradelens/api/trades.py`)

Modified the `preview_trade()` endpoint to handle three sizing modes:

```python
@router.post("/trades/preview", response_model=TradePreviewResponse)
async def preview_trade(request: TradePreviewRequest):
    # Determine sizing mode
    sizing_mode = request.sizing_mode or 'risk_amount'

    # Determine entry price for calculations
    if request.entry_type == 'market':
        entry_price = live_price
    else:
        entry_price = request.limit_price if request.limit_price else live_price

    # Calculate desired_risk_usd based on sizing mode
    if sizing_mode == 'quantity':
        # User specified exact quantity
        risk_per_unit = abs(entry_price - request.stop_loss)
        desired_risk_usd = request.position_qty * risk_per_unit

    elif sizing_mode == 'usd_value':
        # User specified position size in USD
        qty = request.position_usd / entry_price
        risk_per_unit = abs(entry_price - request.stop_loss)
        desired_risk_usd = qty * risk_per_unit

    elif sizing_mode == 'risk_amount':
        # User specified risk amount (original behavior)
        desired_risk_usd = request.risk_usd or request.desired_risk_usd

    # Calculate position size using the calculated desired_risk_usd
    sizing_result = calculate_position_size(
        # ... parameters ...
        desired_risk_usd=desired_risk_usd,  # Calculated based on mode
        # ...
    )
```

**Key Design Decisions**:
- The backend translates each sizing mode into a `desired_risk_usd` value
- The existing `calculate_position_size()` function is used without modification
- This maintains backward compatibility and minimizes code changes
- The calculation reverses the risk formula to get the desired position size

---

## Position Sizing Mode Details

### 1. Quantity Mode

**Purpose**: Trader specifies exact position size in units/contracts

**Inputs**:
- `sizing_mode: "quantity"`
- `position_qty: float` (required)
- `stop_loss: float` (required)

**Calculation**:
```python
risk_per_unit = abs(entry_price - stop_loss)
desired_risk_usd = position_qty * risk_per_unit
```

**Example**:
```json
{
  "symbol": "BTCUSDT",
  "side": "long",
  "entry_type": "limit",
  "limit_price": 4000,
  "sizing_mode": "quantity",
  "position_qty": 3,
  "stop_loss": 2000
}
```

**Expected Result**:
- Risk per unit: `|4000 - 2000| = 2000`
- Desired risk USD: `3 * 2000 = 6000`
- Backend calculates: `qty = 6000 / 2000 = 3` ✅

**Test Result**: ✅ Verified - Returns `computed_qty: 3.0`

---

### 2. USD Value Mode

**Purpose**: Trader specifies position size in USD terms

**Inputs**:
- `sizing_mode: "usd_value"`
- `position_usd: float` (required)
- `stop_loss: float` (required)

**Calculation**:
```python
qty = position_usd / entry_price
risk_per_unit = abs(entry_price - stop_loss)
desired_risk_usd = qty * risk_per_unit
```

**Example**:
```json
{
  "symbol": "ETHUSDT",
  "side": "long",
  "entry_type": "limit",
  "limit_price": 3500,
  "sizing_mode": "usd_value",
  "position_usd": 1000,
  "stop_loss": 3400
}
```

**Expected Result**:
- Quantity: `1000 / 3500 = 0.286`
- Risk per unit: `|3500 - 3400| = 100`
- Desired risk USD: `0.286 * 100 = 28.6`
- Backend calculates: `qty = 28.6 / 100 = 0.286` ✅

**Test Result**: ✅ Verified - Returns `computed_qty: 0.28`

---

### 3. Risk Amount Mode

**Purpose**: Trader specifies risk amount, position size auto-calculated

**Inputs**:
- `sizing_mode: "risk_amount"`
- `risk_usd: float` (required)
- `stop_loss: float` (required)

**Calculation**:
```python
desired_risk_usd = risk_usd
# Backend calculates: qty = desired_risk_usd / abs(entry_price - stop_loss)
```

**Example**:
```json
{
  "symbol": "BTCUSDT",
  "side": "long",
  "entry_type": "market",
  "sizing_mode": "risk_amount",
  "risk_usd": 500,
  "stop_loss": 52000
}
```

**Expected Result** (with BTC at ~$114,184):
- Risk per unit: `|114184 - 52000| = 62184.1`
- Backend calculates: `qty = 500 / 62184.1 = 0.008` ✅

**Test Result**: ✅ Verified - Returns `computed_qty: 0.008`

---

## Validation Rules

### Mode-Specific Validation

| Mode | Field | Validation |
|------|-------|------------|
| `quantity` | `position_qty` | Required, must be > 0 |
| `quantity` | `stop_loss` | Required for risk calculation |
| `usd_value` | `position_usd` | Required, must be > 0 |
| `usd_value` | `stop_loss` | Required for risk calculation |
| `risk_amount` | `risk_usd` | Required, must be > 0 |
| `risk_amount` | `stop_loss` | **Required** for position size calculation |

### Error Messages

The backend raises `ValidationError` with clear messages:

```python
# Quantity mode
if not request.position_qty:
    raise ValidationError("position_qty is required for quantity mode")
if not request.stop_loss:
    raise ValidationError("stop_loss is required for quantity mode with risk calculation")

# USD Value mode
if not request.position_usd:
    raise ValidationError("position_usd is required for usd_value mode")
if not request.stop_loss:
    raise ValidationError("stop_loss is required for usd_value mode with risk calculation")

# Risk Amount mode
if not request.stop_loss:
    raise ValidationError("stop_loss is required for risk_amount mode")
desired_risk_usd = request.risk_usd or request.desired_risk_usd
if not desired_risk_usd:
    raise ValidationError("risk_usd or desired_risk_usd is required for risk_amount mode")
```

---

## Backward Compatibility

### Legacy Field Support

The backend continues to support the `desired_risk_usd` field:

1. **Old clients** (without `sizing_mode`):
   - Send `desired_risk_usd` only
   - Backend defaults `sizing_mode` to `'risk_amount'`
   - Uses `desired_risk_usd` directly
   - ✅ Works as before

2. **New clients** (with `sizing_mode`):
   - Send `sizing_mode`, `position_qty`/`position_usd`/`risk_usd`
   - Backend calculates appropriate `desired_risk_usd`
   - May still send legacy `desired_risk_usd` for backward compatibility
   - ✅ New behavior

### Migration Path

**Phase 1** (Current):
- Backend supports both old and new fields
- Frontend sends both new fields and legacy `desired_risk_usd`
- Seamless transition

**Phase 2** (Future):
- Monitor usage of legacy field
- Once all clients upgraded, deprecate `desired_risk_usd`
- Remove legacy field in major version update

---

## Testing

### Manual Testing Performed

All three sizing modes were tested with real API calls:

#### Test 1: Quantity Mode ✅
```bash
curl -X POST "http://localhost:8088/api/v1/trades/preview" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTCUSDT",
    "side": "long",
    "entry_type": "limit",
    "limit_price": 4000,
    "market_type": "usdt_perp",
    "sizing_mode": "quantity",
    "position_qty": 3,
    "stop_loss": 2000,
    "desired_risk_usd": 100
  }'
```

**Result**: `computed_qty: 3.0` ✅

#### Test 2: USD Value Mode ✅
```bash
curl -X POST "http://localhost:8088/api/v1/trades/preview" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "ETHUSDT",
    "side": "long",
    "entry_type": "limit",
    "limit_price": 3500,
    "market_type": "usdt_perp",
    "sizing_mode": "usd_value",
    "position_usd": 1000,
    "stop_loss": 3400,
    "desired_risk_usd": 100
  }'
```

**Result**: `computed_qty: 0.28` ✅

#### Test 3: Risk Amount Mode ✅
```bash
curl -X POST "http://localhost:8088/api/v1/trades/preview" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTCUSDT",
    "side": "long",
    "entry_type": "market",
    "market_type": "usdt_perp",
    "sizing_mode": "risk_amount",
    "risk_usd": 500,
    "stop_loss": 52000,
    "desired_risk_usd": 500
  }'
```

**Result**: `computed_qty: 0.008` (with BTC at $114,184) ✅

### Testing Checklist

- [x] Quantity mode with limit orders
- [x] USD Value mode with limit orders
- [x] Risk Amount mode with market orders
- [x] Backend DTO validation accepts new fields
- [x] Backward compatibility with legacy `desired_risk_usd`
- [x] Error handling for missing required fields
- [x] API server restart picks up changes

---

## Frontend Changes

### Removed Workaround Code

The frontend previously had a workaround that calculated `desired_risk_usd` to trick the backend. This has been removed:

**Before** (lines 218-251):
```typescript
// WORKAROUND: Backend doesn't support sizing_mode yet, so we need to trick it
// by calculating desired_risk_usd that will give us the desired position size
if (sizingMode === 'quantity' && stopLoss) {
  const entryPrice = entryType === 'limit' && limitPrice ? parseFloat(limitPrice) : 0
  if (entryPrice > 0) {
    const stopLossPrice = parseFloat(stopLoss)
    const riskPerUnit = Math.abs(entryPrice - stopLossPrice)
    request.desired_risk_usd = parseFloat(positionQty) * riskPerUnit
  } else {
    request.desired_risk_usd = 100
  }
}
// ... more workaround code ...
```

**After** (lines 218-225):
```typescript
// For backward compatibility with older backend versions, send a default desired_risk_usd
// The new backend will use sizing_mode and position_qty/position_usd/risk_usd instead
if (sizingMode === 'risk_amount') {
  request.desired_risk_usd = parseFloat(riskUsd)
} else {
  // Default value for non-risk modes (backend will ignore this)
  request.desired_risk_usd = 100
}
```

**Result**: Clean, simple code that relies on proper backend implementation

---

## API Contract

### Request Schema

```typescript
interface TradePreviewRequest {
  symbol: string
  side: 'long' | 'short'
  entry_type: 'market' | 'limit'

  // Required for new sizing modes
  market_type: 'spot' | 'usdt_perp' | 'inverse'
  sizing_mode: 'quantity' | 'usd_value' | 'risk_amount'

  // Optional - one will be used based on sizing_mode
  position_qty?: number        // For quantity mode
  position_usd?: number        // For usd_value mode
  risk_usd?: number            // For risk_amount mode

  // Optional fields
  limit_price?: number         // Required if entry_type='limit'
  stop_loss?: number           // Required for risk_amount mode

  // Legacy field
  desired_risk_usd?: number    // Fallback, for backward compatibility

  // DCA and TP fields
  dca_levels?: number[]
  dca1_pct?: number
  dca2_pct?: number
  dca3_pct?: number
  dca4_pct?: number
  entry_pct?: number
  take_profits?: Array<{
    mode: 'rr' | 'price'
    value: number
    size_pct?: number
  }>
}
```

### Response Schema

```typescript
interface TradePreviewResponse {
  preview_id: string
  symbol: string
  side: string
  entry_type: string
  entry_price_used: number
  avg_entry: number
  stop_loss: number
  risk_per_unit: number
  computed_qty: number         // The calculated position size
  resolved_percents: Record<string, number>
  legs: Array<{
    kind: string
    order_kind: string
    price: number
    qty: number
  }>
  take_profit_levels: Array<{
    from: string
    price: number
    size_pct: number
    qty: number
  }>
  validations: string[]
}
```

---

## Files Modified

### Backend

1. **`lib/tradelens/models/dto.py`**
   - Added `sizing_mode`, `market_type` fields
   - Added `position_qty`, `position_usd`, `risk_usd` fields
   - Made `stop_loss` and `desired_risk_usd` optional

2. **`lib/tradelens/api/trades.py`**
   - Updated `preview_trade()` to handle three sizing modes
   - Added mode-specific calculation logic
   - Added validation for required fields per mode

### Frontend

1. **`frontend/web/src/pages/smart-trade.tsx`**
   - Removed workaround code (lines 218-251)
   - Simplified `buildRequest()` function
   - Now relies on backend for correct calculation

### Documentation

1. **`BACKEND_SIZING_MODES_IMPLEMENTATION.md`** (this file)
   - Complete backend implementation documentation

2. **`SIZING_MODES_UPDATE.md`** (already exists)
   - Frontend implementation documentation

---

## Deployment Notes

### Server Restart Required

The backend API server must be restarted to pick up the changes:

```bash
# Kill existing server
ps aux | grep uvicorn | grep -v grep | awk '{print $2}' | xargs kill

# Start new server
source /app/syb/tradesuite/sourceme.sh
nohup uvicorn tradelens.main:app --host 0.0.0.0 --port 8088 --log-level info --access-log > /tmp/tradelens.out 2>&1 &
```

### Verification Steps

1. Check API is running:
   ```bash
   curl http://localhost:8088/
   ```

2. Test each sizing mode:
   ```bash
   # Quantity mode
   curl -X POST "http://localhost:8088/api/v1/trades/preview" -H "Content-Type: application/json" -d '{"symbol":"BTCUSDT","side":"long","entry_type":"limit","limit_price":4000,"market_type":"usdt_perp","sizing_mode":"quantity","position_qty":3,"stop_loss":2000,"desired_risk_usd":100}'

   # USD Value mode
   curl -X POST "http://localhost:8088/api/v1/trades/preview" -H "Content-Type: application/json" -d '{"symbol":"ETHUSDT","side":"long","entry_type":"limit","limit_price":3500,"market_type":"usdt_perp","sizing_mode":"usd_value","position_usd":1000,"stop_loss":3400,"desired_risk_usd":100}'

   # Risk Amount mode
   curl -X POST "http://localhost:8088/api/v1/trades/preview" -H "Content-Type: application/json" -d '{"symbol":"BTCUSDT","side":"long","entry_type":"market","market_type":"usdt_perp","sizing_mode":"risk_amount","risk_usd":500,"stop_loss":52000,"desired_risk_usd":500}'
   ```

3. Verify computed_qty matches expectations in each mode

---

## Known Limitations

1. **Stop Loss Required**: All three modes currently require `stop_loss` for risk calculation. This is intentional for safety, but could be made optional in the future for quantity mode.

2. **Market Orders**: For market orders, the entry price is fetched live from Bybit. This means the calculation happens at request time and may differ slightly from execution time.

3. **DCA/TP Compatibility**: DCA and TP levels work the same way across all sizing modes. The base position size is determined by the sizing mode, then DCA/TP levels are applied proportionally.

---

## Future Enhancements

1. **Make Stop Loss Optional**: In quantity mode, stop loss could be truly optional (just for position sizing, not risk calculation).

2. **Position Size Preview**: Add a new endpoint that provides a quick estimate without full validation (for real-time updates as user types).

3. **Historical Testing**: Add integration tests that verify position sizing calculations against historical trade data.

4. **Performance Optimization**: Cache instrument metadata to avoid repeated Bybit API calls.

5. **Remove Legacy Field**: After monitoring usage, remove `desired_risk_usd` in a major version update.

---

## Support

For questions or issues:
- Review unit tests for usage examples
- Check API logs: `/tmp/tradelens.out`
- See `SIZING_MODES_UPDATE.md` for frontend documentation
- Consult `CLAUDE.md` for general project context

---

**Last Updated**: 2025-10-13
**Version**: 1.0
**Status**: ✅ Complete and Tested
**Author**: Claude Code (AI Assistant)
