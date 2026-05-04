# Plan: Auto-Review on Trade Close (Option 4)

## Overview

When a trade closes, automatically generate an AI trade review and store it so it's
waiting in the Journal detail view when the user opens the trade.

## Architecture

```
Pipeline Step 4 (refresh_trade_journal.py)
    │
    │  detects trade closure (status: open → closed)
    │
    ▼
notify_trade_closure()              ← NEW (journal_notification.py)
    │
    │  fire-and-forget background thread
    │
    ▼
POST /api/v1/internal/auto-review   ← NEW endpoint (ai_feedback.py)
    │
    ├─ build_trade_snapshot()        ← EXISTING (ai_snapshot.py)
    ├─ build_review_prompt()         ← NEW (review prompt template)
    ├─ call AI API                   ← EXISTING (OpenAI Responses API)
    │
    ▼
INSERT INTO trade_ai_chat            ← EXISTING table
    (trade_id, msg_role='system', content=review_text)
    │
    ▼
AI Assistant tab shows review automatically
```

## Implementation Steps

### Step 1: Add `notify_trade_closure()` to journal_notification.py

**File**: `lib/tradelens/utils/journal_notification.py`

Add a new function alongside the existing `notify_new_journal_entry()`:

```python
def notify_trade_closure(trade_id: int, symbol: str, side: str, account_name: str,
                         realized_pnl: float, exit_r: float):
    """
    Notify the API that a trade has closed, triggering auto-review.
    Fire-and-forget — failures don't block the pipeline.
    """
    thread = threading.Thread(
        target=_send_closure_notification,
        args=(trade_id, symbol, side, account_name, realized_pnl, exit_r),
        daemon=True
    )
    thread.start()


def _send_closure_notification(trade_id, symbol, side, account_name, realized_pnl, exit_r):
    try:
        response = requests.post(
            'http://localhost:8088/api/v1/internal/auto-review',
            json={
                'trade_id': int(trade_id),
                'symbol': symbol,
                'side': side,
                'account_name': account_name,
                'realized_pnl': float(realized_pnl) if realized_pnl else 0,
                'exit_r': float(exit_r) if exit_r else None,
            },
            timeout=60  # AI call can take a while
        )
        if response.status_code == 200:
            logger.info(f"Auto-review triggered: {symbol} {side} (trade_id={trade_id})")
        else:
            logger.warning(f"Auto-review failed: HTTP {response.status_code}")
    except Exception as e:
        logger.warning(f"Auto-review error: {e}")
```

### Step 2: Call `notify_trade_closure()` from the Pipeline

**File**: `bin/pipeline/refresh_trade_journal.py` (around line 2822)

The key detection point: when `upsert_trade_journal()` returns `is_new=False` (UPDATE),
we need to check if the trade just transitioned to 'closed'. The pipeline currently only
notifies on `is_new=True`.

**Approach**: Track status transitions in `upsert_trade_journal()`.

Currently `upsert_trade_journal()` returns `(trade_id, is_new)`. Change to return
`(trade_id, is_new, old_status)` so the caller knows when a trade flipped to closed.

Then in the persistence loop (~line 2821):

```python
for session in sessions:
    trade_id, is_new, old_status = upsert_trade_journal(session, db, conn, dry_run)

    if trade_id:
        if is_new:
            stats['sessions_created'] += 1
            if account_name and not dry_run:
                notify_new_journal_entry(...)
        else:
            stats['sessions_updated'] += 1

            # NEW: Detect closure transition
            if (session.status == 'closed'
                    and old_status in ('open', 'seeded', 'pending_entry')
                    and account_name
                    and not dry_run):
                notify_trade_closure(
                    trade_id=trade_id,
                    symbol=session.symbol,
                    side=session.side,
                    account_name=account_name,
                    realized_pnl=session.get_realized_pnl(),
                    exit_r=None  # R-metrics computed after this point
                )
```

**Note on timing**: R-metrics (`exit_r`, `mfe_r`) are computed AFTER `upsert_trade_journal()`
by `recalculate_trade_initial_risk()` (line 2857). The auto-review endpoint should
re-read these from the DB rather than relying on the notification payload.

### Step 3: New API Endpoint — `/api/v1/internal/auto-review`

**File**: `lib/tradelens/api/ai_feedback.py`

Add a new internal endpoint that:
1. Receives the closure notification
2. Checks if a review already exists (idempotency)
3. Waits briefly for R-metrics to be computed (they're calculated right after upsert)
4. Builds the trade snapshot using existing `build_trade_snapshot()`
5. Calls the AI with a review-specific system prompt
6. Stores the result in `trade_ai_chat`

```python
class AutoReviewRequest(BaseModel):
    trade_id: int
    symbol: str
    side: str
    account_name: str
    realized_pnl: float = 0
    exit_r: Optional[float] = None


@router.post("/internal/auto-review")
async def auto_review_trade(request: AutoReviewRequest, background_tasks: BackgroundTasks):
    """
    Automatically generate a trade review when a trade closes.
    Called by the pipeline via journal_notification.py.
    Runs the actual AI call in a background task to return immediately.
    """
    # Check if review already exists (idempotency)
    existing = _get_existing_auto_review(request.trade_id)
    if existing:
        return {"status": "already_reviewed", "trade_id": request.trade_id}

    # Run in background so pipeline isn't blocked
    background_tasks.add_task(_generate_auto_review, request)

    return {"status": "queued", "trade_id": request.trade_id}


async def _generate_auto_review(request: AutoReviewRequest):
    """Background task that generates and stores the auto-review."""
    try:
        # Small delay to let R-metrics finish computing
        await asyncio.sleep(5)

        account_name, account_id = resolve_account(request.account_name)

        # Build snapshot (reuses existing infrastructure)
        snapshot = build_trade_snapshot(request.trade_id, account_id, account_name)
        context_text = format_snapshot_as_text(snapshot)

        # Also fetch 1m candles and post-trade hourly candles
        candle_context = _build_candle_context(request.trade_id, request.symbol)

        # Build the review prompt
        review_prompt = AUTO_REVIEW_SYSTEM_PROMPT
        user_message = f"""Generate a post-trade review for this closed trade.

{context_text}

{candle_context}

Follow the review structure exactly as specified in the system prompt."""

        # Call AI
        ai_client = get_ai_client(purpose="reasoning", logger_instance=logger)
        response = ai_client.chat.completions.create(
            model="gpt-5",
            messages=[
                {"role": "system", "content": review_prompt},
                {"role": "user", "content": user_message}
            ],
            temperature=0.3,
            max_tokens=4000
        )

        review_text = response.choices[0].message.content

        # Store as system message in trade_ai_chat
        _save_chat_message(
            entity_type="trade",
            entity_id=request.trade_id,
            account_id=account_id,
            role="system",
            content=review_text,
            model=response.model,
            cost_usd=_estimate_cost(response.usage),
            response_id=response.id if hasattr(response, 'id') else None,
        )

        logger.info(f"Auto-review saved for trade {request.trade_id}")

    except Exception as e:
        logger.error(f"Auto-review failed for trade {request.trade_id}: {e}", exc_info=True)
```

### Step 4: Candle Context Helper

**File**: `lib/tradelens/api/ai_feedback.py` (new helper function)

```python
def _build_candle_context(trade_id: int, symbol: str) -> str:
    """Build candle price context for trade review."""
    with get_db_connection() as conn:
        cursor = conn.cursor()

        # Get trade open/close times
        cursor.execute("""
            SELECT opened_at, closed_at FROM trade_journal WHERE trade_id = %s
        """, (trade_id,))
        row = cursor.fetchone()
        if not row or not row[0]:
            return ""

        opened_at, closed_at = row

        # Determine candle timeframe based on duration
        if closed_at:
            duration_min = (closed_at - opened_at).total_seconds() / 60
        else:
            duration_min = 60  # default for open trades

        if duration_min > 2880:  # > 2 days
            tf = '1h'
        elif duration_min > 360:  # > 6 hours
            tf = '5m'
        else:
            tf = '1m'

        # Fetch candles: 30min before open to 30min after close
        cursor.execute("""
            SELECT open_time, c_open, c_high, c_low, c_close
            FROM market_candle
            WHERE symbol = %s AND timeframe = %s AND market_type = 'linear'
              AND open_time BETWEEN %s - INTERVAL '30 minutes'
                                AND COALESCE(%s, CURRENT_TIMESTAMP) + INTERVAL '30 minutes'
            ORDER BY open_time
        """, (symbol, tf, opened_at, closed_at))
        candles = cursor.fetchall()

        # Fetch post-trade hourly candles (12h after close)
        post_candles = []
        if closed_at:
            cursor.execute("""
                SELECT open_time, c_open, c_high, c_low, c_close
                FROM market_candle
                WHERE symbol = %s AND timeframe = '1h' AND market_type = 'linear'
                  AND open_time BETWEEN %s AND %s + INTERVAL '12 hours'
                ORDER BY open_time
            """, (symbol, closed_at, closed_at))
            post_candles = cursor.fetchall()

        cursor.close()

    # Format as text
    lines = [f"\n## Price Action ({tf} candles during trade)\n"]
    lines.append("| Time | Open | High | Low | Close |")
    lines.append("|------|------|------|-----|-------|")
    for c in candles:
        lines.append(f"| {c[0]} | {c[1]} | {c[2]} | {c[3]} | {c[4]} |")

    if post_candles:
        lines.append(f"\n## Post-Trade Price Action (1h candles, 12h after close)\n")
        lines.append("| Time | Open | High | Low | Close |")
        lines.append("|------|------|------|-----|-------|")
        for c in post_candles:
            lines.append(f"| {c[0]} | {c[1]} | {c[2]} | {c[3]} | {c[4]} |")

    return "\n".join(lines)
```

### Step 5: Review System Prompt

**File**: `lib/tradelens/api/ai_feedback.py` (new constant)

```python
AUTO_REVIEW_SYSTEM_PROMPT = """You are a trade review analyst. Generate a concise,
honest post-trade review.

## Output Structure

### Summary
One-line result: symbol, side, P&L ($, R), duration, MFE/MAE

### Leg Timeline
Chronological list of filled legs with brief commentary.
Note unfilled legs separately (they reveal intent — planned TPs/stops that weren't reached).

### Price Action
What did price do during the trade? When/where was MFE? What caused the exit?

### MFE Capture
How much of the favorable move was captured? If MFE > 1R but trade lost money, explain why.

### Exit Efficiency
Rate: exit near MAE (bad) vs near MFE (good).

### Level Guard Analysis
Would Level Guard have changed the outcome? Only if the trade was stopped out.

### Post-Trade
What happened after exit? Would holding have been better or worse?

### What Went Well (bullets)
### What Could Improve (bullets, actionable)
### Key Takeaway (one sentence)

## Rules
- Use actual numbers. Never estimate.
- Be direct. Bad trades need honest feedback.
- Keep total output under 800 words.
- Focus on actionable insights, not hindsight wisdom.
"""
```

### Step 6: Idempotency Check

```python
def _get_existing_auto_review(trade_id: int) -> bool:
    """Check if an auto-review already exists for this trade."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(*) FROM trade_ai_chat
            WHERE trade_id = %s AND msg_role = 'system'
              AND content LIKE '### Summary%'
        """, (trade_id,))
        count = cursor.fetchone()[0]
        cursor.close()
        return count > 0
```

### Step 7: Frontend — Display Auto-Review

The AI Assistant tab already loads from `trade_ai_chat` via `GET /ai/chat/trade/{trade_id}`.
System-role messages may already be displayed, but verify:

**File**: Check `dashboard/src/` for the AI chat component to ensure `msg_role='system'`
messages are rendered (possibly with a different styling — e.g., a banner or highlighted card
to distinguish auto-reviews from user-initiated chats).

If system messages aren't rendered, add a simple check:
```jsx
{msg.role === 'system' && (
  <div className="bg-blue-900/30 border border-blue-700 rounded p-3 mb-2">
    <div className="text-xs text-blue-400 mb-1">Auto-Review (generated on close)</div>
    <div className="prose prose-invert prose-sm">{renderMarkdown(msg.content)}</div>
  </div>
)}
```

## Files Changed Summary

| File | Change |
|------|--------|
| `lib/tradelens/utils/journal_notification.py` | Add `notify_trade_closure()` + `_send_closure_notification()` |
| `bin/pipeline/refresh_trade_journal.py` | Return `old_status` from `upsert_trade_journal()`, call `notify_trade_closure()` on close transition |
| `lib/tradelens/api/ai_feedback.py` | Add `/internal/auto-review` endpoint, `_generate_auto_review()`, `_build_candle_context()`, `AUTO_REVIEW_SYSTEM_PROMPT`, `_get_existing_auto_review()` |
| `lib/tradelens/services/ai_snapshot.py` | No changes (reuse existing `build_trade_snapshot()`) |
| Dashboard frontend (TBD) | Render `system` role messages in AI chat tab |

## Configuration

Add to `etc/config.yml`:

```yaml
auto_review:
  enabled: true              # Master switch
  min_duration_minutes: 5    # Skip reviews for trades shorter than this (noise trades)
  min_risk_usd: 10           # Skip reviews for tiny trades
  model: "gpt-5"             # AI model to use
  max_tokens: 4000           # Max response length
  temperature: 0.3           # Lower = more focused
```

## Edge Cases

1. **Pipeline restart**: If the pipeline restarts and re-processes trades, the idempotency
   check prevents duplicate reviews.

2. **R-metrics not yet computed**: The 5-second delay in `_generate_auto_review()` allows
   `recalculate_trade_initial_risk()` to finish. The snapshot reads from DB, so it gets
   the latest values.

3. **API server down**: The notification is fire-and-forget. If the API is down, the review
   is simply not generated. No data loss, no pipeline blockage. The user can still run
   `/review-trade <id>` manually.

4. **Very long trades**: Candle context adapts timeframe (1m → 5m → 1h) based on duration.

5. **Spot trades**: `build_trade_snapshot()` already handles spot. No special handling needed.

## Cost Estimate

- ~2000 input tokens (snapshot + candles) + ~1000 output tokens per review
- At GPT-5 pricing: ~$0.02-0.05 per review
- At 5-10 trades/day: ~$0.10-0.50/day

## Testing Plan

1. **Unit test**: Mock `build_trade_snapshot()` and verify review prompt construction
2. **Integration test**: Close a trade in test account, verify auto-review appears in `trade_ai_chat`
3. **Idempotency test**: Trigger auto-review twice for same trade, verify only one review stored
4. **Edge case**: Trade with no candle data, trade with missing R-metrics
5. **Frontend**: Open closed trade in journal, verify auto-review appears in AI Assistant tab
