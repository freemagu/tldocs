# Trade Journal Chart UI - Implementation Summary

## Overview

This document describes the Phase 1 implementation of the Trade Journal chart UI with TMM-style expanded view, complete with chart visualization, order leg tracking, and notes/tags system.

**Status**: ✅ Complete
**Date**: 2025-11-19
**Phase**: 1 of 2 (Chart UI and WAEP visualization)

## What Was Implemented

### Backend Components

#### 1. Journal API Endpoints (`lib/tradelens/api/journal.py`)

Complete REST API for trade journal operations:

**GET /api/v1/journal** - Paginated trade list
- Query params: `account_name`, `symbol`, `status`, `page`, `page_size`
- Returns: List of trades with metadata + aggregated tags
- Features: Filtering by symbol/status, multi-account support

**GET /api/v1/journal/{trade_id}** - Full trade details
- Query params: `account_name` (optional)
- Returns: Complete trade data including:
  - Trade metadata (symbol, side, PnL, WAEP, status)
  - Order legs with WAEP progression (from `order_leg_hist` via `trade_leg_map`)
  - OHLC candles from Bybit (15-minute default, fetched in real-time)
  - Notes and tags from `trade_journal_notes`

**POST /api/v1/journal/{trade_id}/notes** - Create note or tag
- Body: `{ event_type: "note" | "tag", content: string }`
- Validation: event_type, content length (max 1024 chars), trade ownership

**PUT /api/v1/journal/{trade_id}/notes/{note_id}** - Update note/tag
- Body: `{ content: string }`
- Validation: Ownership, content length, cross-trade tampering prevention

**DELETE /api/v1/journal/{trade_id}/notes/{note_id}** - Delete note/tag
- Validation: Ownership verification via JOIN with `trade_journal`

#### 2. API Integration (`lib/tradelens/main.py`)

- Registered `journal` router with `/api/v1` prefix
- Added to FastAPI app with proper CORS and tags

#### 3. Database Migration (`migrations/009_add_account_id_to_trade_journal.sql`)

- Added `account_id` column to `trade_journal` table (if missing)
- Backfilled `account_id` from `order_leg_hist` via `trade_leg_map`
- Created index: `idx_trade_journal_account_id`

**Note**: The `setup_database.py` already includes `account_id` in the `trade_journal` schema, so this migration is for existing databases only.

---

### Frontend Components

#### 1. Main Trade Journal Page (`pages/trade-journal.tsx`)

**Features**:
- Paginated trade list with 50 trades per page
- Filters: symbol (text search), status (all/open/closed)
- Expandable rows with smooth animation
- Trade summary table showing:
  - Trade ID, Symbol, Side (LONG/SHORT with color coding)
  - Status badge (Open/Closed)
  - Opened/Closed timestamps
  - Quantity, Entry Price, Realized PnL (color-coded)
  - Tag badges (first 2 tags + count)
- Multi-account support via `useAccountStore`

**UI/UX**:
- Clean dark theme matching existing TradeLens design
- Responsive grid layout (12 columns)
- Loading states with spinners
- Error states with helpful messages
- Empty state guidance

#### 2. Expanded Row Component (`components/journal/trade-journal-expanded-row.tsx`)

**Layout**:
- Two-column responsive layout:
  - Left panel (60%): Chart
  - Right panel (40%): Order legs + Notes/Tags
- Lazy data fetching (only when row is expanded)
- Automatic refresh when notes/tags are updated

#### 3. Trade Journal Chart (`components/journal/trade-journal-chart.tsx`)

Implements TradingView Lightweight Charts with:

**Chart Features**:
- Candlestick chart with OHLC data from Bybit
- WAEP line (blue) plotted from `waep_after_leg` values
  - Step-like rendering (duplicates points for visual clarity)
  - Only shows legs with non-NULL `waep_after_leg`
- Stop-loss line (red, dashed horizontal)
  - Uses most recent stop leg
  - Horizontal line at trigger price
- Interactive markers for order legs:
  - **Entry**: Green arrow (↑ below bar for buy, ↓ above bar for sell)
  - **DCA**: Emerald circle (below/above bar)
  - **TP**: Purple arrow (↓ above bar for sell, ↑ below bar for buy)
  - **SL**: Red square (above/below bar)
- Crosshair with price/time tracking

**Controls**:
- Timeframe selector: 1m, 5m, 15m, 60m, 1D (UI only, backend uses 15m)
- Reset view button (fits content to viewport)

**Legend**:
- Visual guide for all markers and lines
- Color-coded and labeled

**Theming**:
- Dark theme (#1a1a1a background)
- Consistent with TradeLens palette

#### 4. Order Legs Table (`components/journal/order-legs-table.tsx`)

**Columns**:
- Time (formatted timestamp from `filled_at`)
- Type (Entry/DCA/TP/SL with color coding)
- Side (Buy/Sell with color coding)
- Qty (4 decimal precision)
- Price (2 decimal precision)
- WAEP (2 decimal precision, blue highlight)
- Status (badge: Filled/Cancelled/etc.)

**Features**:
- Hover highlighting per row
- Empty state for trades with no legs
- Responsive table with horizontal scroll

#### 5. Notes & Tags Panel (`components/journal/notes-tags-panel.tsx`)

**Add New**:
- Toggle between "Note" and "Tag" mode
- Note: Multi-line textarea (max 1024 chars)
- Tag: Single-line input (max 1024 chars)
- Add button with validation

**Tags Section**:
- Displayed as chips/badges (purple background)
- Hover to reveal edit/delete icons
- Inline editing with save/cancel
- Confirmation dialog for delete

**Notes Section**:
- Card-based layout with timestamp
- Multi-line display with whitespace preservation
- Hover to reveal edit/delete icons
- Edit mode: Textarea with save/cancel buttons
- Confirmation dialog for delete

**Error Handling**:
- Validation errors displayed inline
- API errors shown with helpful messages

#### 6. Routing & Navigation

- Added `/journal` route to `app.tsx`
- Added "Journal" link to sidebar (📄 icon, between Trade and Audit)
- Route path: `/journal`

---

## Dependencies Added

### Frontend
- **lightweight-charts** (^4.1.3) - TradingView Lightweight Charts library

Added to `frontend/web/package.json`.

---

## Data Flow

### 1. Journal List Flow

```
User → /journal page
  ↓
GET /api/v1/journal?account_name=X&symbol=Y&status=Z&page=1&page_size=50
  ↓
Backend:
  - Resolve account_name → account_id
  - Query trade_journal with filters (account_id, symbol, status)
  - For each trade, fetch tags from trade_journal_notes
  - Return paginated list with tags
  ↓
Frontend:
  - Render collapsed rows with summary
  - Show tags as badges
  - Expandable on click
```

### 2. Expanded Row Flow

```
User clicks trade row
  ↓
GET /api/v1/journal/{trade_id}?account_name=X
  ↓
Backend:
  - Fetch trade_meta from trade_journal
  - Fetch legs from order_leg_hist JOIN trade_leg_map (ordered by filled_at)
  - Fetch candles from Bybit API (15m interval, trade time window + buffer)
  - Fetch notes WHERE event_type = 'note'
  - Fetch tags WHERE event_type = 'tag'
  - Return JournalDetailsResponse
  ↓
Frontend:
  - TradeJournalExpandedRow component
  - TradeJournalChart: Plot candles, WAEP line, stop line, markers
  - OrderLegsTable: Render legs with WAEP column
  - NotesTagsPanel: Render notes/tags with CRUD controls
```

### 3. Notes/Tags CRUD Flow

```
Create:
  POST /api/v1/journal/{trade_id}/notes
  Body: { event_type: "note"|"tag", content: "..." }
  ↓
  INSERT INTO trade_journal_notes
  ↓
  Return new ID + success message
  ↓
  Frontend: Refresh trade details

Update:
  PUT /api/v1/journal/{trade_id}/notes/{note_id}
  Body: { content: "..." }
  ↓
  UPDATE trade_journal_notes SET content, updated_at
  ↓
  Frontend: Refresh trade details

Delete:
  DELETE /api/v1/journal/{trade_id}/notes/{note_id}
  ↓
  DELETE FROM trade_journal_notes
  ↓
  Frontend: Refresh trade details
```

---

## WAEP Semantics (Authoritative)

All WAEP values come from the `waep_after_leg` column in `order_leg_hist` and `order_leg_live`, populated by the existing pipeline scripts:
- `bin/pipeline/refresh_order_leg_hist.py`
- `bin/pipeline/refresh_order_leg_live.py`

**Semantics**:
- `waep_after_leg` = WAEP of the position immediately AFTER that leg is applied
- Only legs that change the position (executed qty > 0) have non-NULL `waep_after_leg`
- For entry/DCA legs: WAEP is calculated using weighted average formula
- For reduce/TP/SL legs: WAEP remains unchanged (position is being reduced, not added to)
- For full close legs: `waep_after_leg` stores the WAEP of the position that was just closed
- Pending/cancelled legs keep `waep_after_leg = NULL`

**Frontend Responsibility**:
- The frontend MUST treat `waep_after_leg` as authoritative
- The frontend MUST NOT re-calculate WAEP from scratch
- The frontend only reads and displays WAEP values from the backend

---

## Expand/Collapse Animation

**Implementation**:
- Uses CSS transitions on the expanded row container
- Smooth height transition from 0 to auto
- Tailwind classes handle the animation
- No per-candle or per-leg animation in Phase 1

**Animation Details**:
- Duration: ~200ms (browser default)
- Easing: ease-in-out
- Only the container opening/closing is animated

---

## Testing

### Manual Testing Checklist

**Backend**:
- [ ] GET /api/v1/journal returns trades for selected account
- [ ] GET /api/v1/journal filters by symbol correctly
- [ ] GET /api/v1/journal filters by status (open/closed) correctly
- [ ] GET /api/v1/journal/{trade_id} returns full details with legs, candles, notes, tags
- [ ] POST /api/v1/journal/{trade_id}/notes creates note
- [ ] POST /api/v1/journal/{trade_id}/notes creates tag
- [ ] PUT /api/v1/journal/{trade_id}/notes/{note_id} updates content
- [ ] DELETE /api/v1/journal/{trade_id}/notes/{note_id} removes note/tag
- [ ] Cross-account validation prevents access to other accounts' trades

**Frontend**:
- [ ] /journal page loads and displays trades
- [ ] Symbol filter works
- [ ] Status filter works (all/open/closed)
- [ ] Pagination works (Next/Previous buttons)
- [ ] Clicking row expands/collapses smoothly
- [ ] Chart loads with candles, WAEP line, stop line, and markers
- [ ] Timeframe selector buttons highlight correctly (UI only)
- [ ] Reset view button refits chart
- [ ] Order legs table displays all legs with correct WAEP values
- [ ] Notes/Tags panel displays existing notes/tags
- [ ] Adding note works
- [ ] Adding tag works
- [ ] Editing note/tag works
- [ ] Deleting note/tag works with confirmation
- [ ] Error messages display correctly for validation errors

### Automated Testing

**Backend Tests** (TODO):
- Unit tests for each endpoint in `tests/api/test_journal.py`
- Test account resolution and filtering
- Test CRUD validation (empty content, max length, ownership)
- Test cross-account access prevention

**Frontend Tests** (TODO):
- Component tests for TradeJournal, TradeJournalChart, OrderLegsTable, NotesTagsPanel
- Integration tests for data fetching and rendering
- E2E tests for full user flow (expand row, view chart, add note, etc.)

---

## Phase 2 Enhancements (Not Implemented Yet)

The following features are planned for Phase 2 but NOT included in this implementation:

1. **Replay/Playback**:
   - Time-scrubbing slider to replay the trade chronologically
   - Animate WAEP line and markers as time progresses
   - Sync screenshot timeline with trade progress

2. **MFE/MAE Lines**:
   - Maximum Favorable Excursion (highest unrealized profit)
   - Maximum Adverse Excursion (worst unrealized loss)
   - Plotted as horizontal lines on chart

3. **Screenshot Timeline**:
   - Vertical timeline of screenshots taken during trade
   - Click to view screenshot in modal
   - Sync with replay scrubber

4. **Multiple Stop Levels**:
   - Support for stacked stop losses (initial SL, DCA SL, etc.)
   - Display all active stops on chart

5. **Advanced Timeframe Switching**:
   - Backend support for 1m, 5m, 60m, 1D candles
   - Dynamic candle fetching based on selected timeframe

6. **Trade Statistics**:
   - Trade duration
   - Average hold time per leg
   - Risk/reward ratio
   - Win/loss streaks

---

## File Structure

```
tradelens/
├── lib/tradelens/
│   ├── main.py                          # ✅ Updated (added journal router)
│   └── api/
│       └── journal.py                   # ✅ New (complete API endpoints)
│
├── frontend/web/
│   ├── package.json                     # ✅ Updated (added lightweight-charts)
│   ├── src/
│   │   ├── app.tsx                      # ✅ Updated (added /journal route)
│   │   ├── pages/
│   │   │   └── trade-journal.tsx        # ✅ New (main journal page)
│   │   └── components/
│   │       ├── layout/
│   │       │   └── sidebar.tsx          # ✅ Updated (added Journal link)
│   │       └── journal/
│   │           ├── trade-journal-expanded-row.tsx   # ✅ New
│   │           ├── trade-journal-chart.tsx          # ✅ New
│   │           ├── order-legs-table.tsx             # ✅ New
│   │           └── notes-tags-panel.tsx             # ✅ New
│
└── migrations/
    └── 009_add_account_id_to_trade_journal.sql      # ✅ New (backfill migration)
```

---

## Configuration Changes

### Frontend (`frontend/web/package.json`)

Added dependency:
```json
"lightweight-charts": "^4.1.3"
```

Install with:
```bash
cd /app/syb/tradesuite/tradelens/frontend/web
npm install
```

---

## Running the Implementation

### 1. Install Frontend Dependencies

```bash
cd /app/syb/tradesuite/tradelens/frontend/web
npm install
```

### 2. Run Migration (If Needed)

If your database doesn't have `account_id` in `trade_journal`:

```bash
cd /app/syb/tradesuite/tradelens
source /app/syb/tradesuite/sourceme.sh
./bin/setup/run_migration.py migrations/009_add_account_id_to_trade_journal.sql
```

### 3. Refresh Trade Journal Data

Ensure trade_journal is populated:

```bash
cd /app/syb/tradesuite/tradelens
source /app/syb/tradesuite/sourceme.sh
./bin/pipeline/refresh_trade_journal.py --days 30
```

### 4. Restart API Server

```bash
cd /app/syb/tradesuite/tradelens
./bin/api restart
```

### 5. Start Frontend Dev Server

```bash
cd /app/syb/tradesuite/tradelens/frontend/web
npm run dev
```

### 6. Access Trade Journal

Navigate to: `http://localhost:5173/journal`

---

## API Documentation

Full API documentation available at: `http://localhost:8088/docs#/journal`

Endpoints:
- `GET /api/v1/journal` - List trades
- `GET /api/v1/journal/{trade_id}` - Get trade details
- `POST /api/v1/journal/{trade_id}/notes` - Create note/tag
- `PUT /api/v1/journal/{trade_id}/notes/{note_id}` - Update note/tag
- `DELETE /api/v1/journal/{trade_id}/notes/{note_id}` - Delete note/tag

---

## Known Limitations

1. **Timeframe Selection**: UI buttons exist but backend always fetches 15-minute candles
2. **Candle Caching**: Candles are fetched from Bybit on every request (no caching)
3. **WAEP Calculation**: Frontend relies entirely on backend `waep_after_leg` values
4. **Stop Line**: Only shows the most recent stop, not multiple stacked stops
5. **Marker Hover**: Hovering legs table doesn't highlight chart markers (Phase 2)

---

## Security Considerations

1. **Account Isolation**: All endpoints verify trade ownership via `account_id` JOIN
2. **Input Validation**: Content length limits (1024 chars), event_type whitelist
3. **SQL Injection**: Uses proper escaping via `escape_sql()` helper
4. **Cross-Trade Tampering**: Update/Delete endpoints verify `trade_id` matches
5. **Error Messages**: Generic errors to avoid information leakage

---

## Performance Considerations

1. **Pagination**: Journal list uses LIMIT/OFFSET for large datasets
2. **Lazy Loading**: Trade details only fetched when row is expanded
3. **Candle Buffering**: Fetches candles with 1-hour buffer before/after trade window
4. **Chart Cleanup**: Properly disposes chart instance on unmount to prevent memory leaks
5. **Tag Aggregation**: Tags are fetched via JOIN, not N+1 queries

---

## Troubleshooting

### Chart Not Rendering

- Check browser console for Lightweight Charts errors
- Verify `lightweight-charts` is installed: `npm ls lightweight-charts`
- Ensure chart container has non-zero dimensions

### No Trades in List

- Verify `trade_journal` is populated: `SELECT COUNT(*) FROM trade_journal`
- Run refresh pipeline: `./bin/pipeline/refresh_trade_journal.py --days 30`
- Check account filter is correct

### WAEP Line Missing

- Verify legs have non-NULL `waep_after_leg` values
- Run WAEP pipelines: `./bin/pipeline/refresh_order_leg_hist.py`
- Check `filled_at` timestamps are valid

### Notes/Tags CRUD Failing

- Check API server logs: `tail -f logs/api.log`
- Verify `trade_journal_notes` table exists
- Ensure `account_id` is in `trade_journal` table

---

## Contributors

- **Claude Code** (Anthropic)
- **TradeLens Development Team**

---

## License

Internal project - Not for redistribution

---

## Changelog

### 2025-11-19 - Phase 1 Release

- ✅ Implemented complete backend API for trade journal
- ✅ Implemented frontend with Lightweight Charts
- ✅ Added WAEP line visualization from existing pipeline data
- ✅ Added order legs table with WAEP column
- ✅ Added notes/tags CRUD panel
- ✅ Added expand/collapse animation
- ✅ Integrated with multi-account system
- ✅ Added migration for account_id backfill

---

**End of Document**
