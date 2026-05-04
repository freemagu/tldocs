# Stop Loss Auto-Cancel Investigation (ROBOUSDT SHORT, 2026-03-03)

## Issue

User reported stop loss "disappeared" after entry filled for ROBOUSDT SHORT (Idea #249, trade_intent 203).

## Findings

### The Stop Was Still There (As a Conditional Order)

The conditional stop at $0.052 was **not cancelled** — it was still present as an open conditional order (`stopOrderType=Stop`, `qty=0`, `closeOnTrigger=true`). However, it was **not visible as a position-linked stop** because it was placed via `POST /v5/order/create` (independent conditional order) rather than `POST /v5/position/trading-stop` (position-linked stop).

When checking the position on Bybit, the `stopLoss` field showed empty — making it appear the stop was missing.

### Bybit Order Types: Conditional vs Position-Linked

| Aspect | Conditional Stop (`order/create`) | Position-Linked Stop (`set_trading_stop`) |
|--------|-----------------------------------|------------------------------------------|
| API | `POST /v5/order/create` with `orderFilter=StopOrder` | `POST /v5/position/trading-stop` |
| Bybit `stopOrderType` | `Stop` | `StopLoss` |
| Shows on position details | No (`stopLoss` field empty) | Yes (`stopLoss` field populated) |
| Requires existing position | No (can pre-place before entry) | Yes |
| Subject to reduce-only auto-cancel | **Yes** | **No** |

### Ticking Time Bomb: Auto-Cancel When TPs Trigger

The conditional TPs (trigger at $0.04751, `triggerDirection=1`) hadn't triggered yet at time of investigation. But when they do trigger (price rises to $0.04751), they become **active reduce-only orders** covering 100% of the position.

Bybit rule: *"If position qty ≤ sum of active reduce-only qty, remaining conditional reduce-only orders are auto-cancelled."*

At that point:
- Active reduce-only (from triggered TPs): 111,110 (100% of position)
- Conditional stop: would cover another 111,110 (200% total)
- **Bybit auto-cancels the conditional stop** → position unprotected

### Order Placement Timeline (from api.log)

```
19:18:31 - Trade intent 203 created
19:18:31 - Hedge mode detected (positionIdx=2)
19:18:31 - Leverage check passed: ROBOUSDT at 10.0x
19:18:32 - Stop-loss placed: $0.052 (order leg 876, conditional StopOrder)
19:18:32 - Entry limit placed: Sell @ $0.0475 (order leg 877)
19:18:32 - Conditional TPs placed (4x, trigger at $0.04751)
19:18:33 - Trade intent submitted
19:18:33 - Fast-track refresh scheduled (10s delay)
```

### Position State at Investigation Time

```
Position: Sell 111,110 ROBOUSDT @ $0.04730427, positionIdx=2
stopLoss: (empty)  ← not position-linked

Open orders (5):
  Buy Market qty=0     trigger=0.052   stopOrderType=Stop     ← conditional stop (still active)
  Buy Limit  qty=27770 trigger=0.04751 stopOrderType=Stop     ← conditional TP1
  Buy Limit  qty=27770 trigger=0.04751 stopOrderType=Stop     ← conditional TP2
  Buy Limit  qty=27770 trigger=0.04751 stopOrderType=Stop     ← conditional TP3
  Buy Limit  qty=27800 trigger=0.04751 stopOrderType=Stop     ← conditional TP4
```

### Manual Fix Applied

Set position-linked stop via `set_trading_stop`:
```python
bybit.set_trading_stop(category='linear', symbol='ROBOUSDT', stop_loss='0.052', position_idx=2)
```

After fix:
```
stopLoss: 0.052  ← now position-linked

Open orders (6):
  Buy Market qty=111110 trigger=0.052 stopOrderType=StopLoss  ← NEW position-linked stop
  Buy Market qty=0      trigger=0.052 stopOrderType=Stop       ← old conditional stop (redundant)
  (4x conditional TPs unchanged)
```

## Proposed Code Fix (Not Applied — Rolled Back)

### 1. submit_trade safeguard (trades.py ~line 1799)

After placing all orders (stop + entry + TPs), attempt `set_trading_stop` to create a position-linked stop. If entry hasn't filled (no position), the call fails harmlessly.

```python
# After the main order placement loop, before trade intent status update:
if stop_loss_placed and category != 'spot':
    has_tps = any(
        leg.get('leg_type') in ('conditional_tp', 'tp') and leg.get('status') == 'submitted'
        for leg in order_legs
    )
    if has_tps:
        try:
            bybit.set_trading_stop(
                category=category,
                symbol=preview_response['symbol'].upper(),
                stop_loss=str(preview_response['stop_loss']),
                position_idx=sl_position_idx
            )
            logger.info(f"Set position-linked stop-loss at {preview_response['stop_loss']}")
        except Exception as e:
            # Expected if position doesn't exist yet (entry hasn't filled)
            logger.debug(f"Could not set position-linked stop (position may not exist yet): {e}")
```

### 2. Pipeline safeguard (refresh_trade_journal.py)

New helper function `reestablish_position_stop_loss()` that:
1. Reads `stop_loss` from `trade_intent` table
2. Looks up `account_name` from `accounts` table
3. Creates a temporary `BybitClient`
4. Calls `set_trading_stop`

Called at two points in `upsert_trade_journal()`:
- When existing trade transitions `pending_entry → open` (entry just filled)
- When new trade is created as `open` from a `pending_position_context`

```python
def reestablish_position_stop_loss(conn, trade_intent_id, account_id, symbol, side, category, position_idx):
    # Get stop_loss from trade_intent
    cursor = conn.cursor()
    cursor.execute(f"SELECT stop_loss FROM trade_intent WHERE id = {trade_intent_id}")
    row = cursor.fetchone()
    cursor.close()
    if not row or not row[0]:
        return
    stop_loss = float(row[0])

    # Get account name
    cursor = conn.cursor()
    cursor.execute(f"SELECT name FROM accounts WHERE account_id = {account_id}")
    acct_row = cursor.fetchone()
    cursor.close()
    if not acct_row:
        return

    # Set position-linked stop
    bybit = BybitClient(account_name=acct_row[0])
    try:
        bybit.set_trading_stop(
            category=category, symbol=symbol.upper(),
            stop_loss=str(stop_loss), position_idx=position_idx
        )
    except Exception as e:
        logger.warning(f"Could not re-establish stop for {symbol} {side}: {e}")
    finally:
        bybit.close()
```

## Key Takeaway

The current approach of placing the stop via `order/create` with `closeOnTrigger=true` and `qty=0` works but has two issues:
1. **Visibility**: Not shown as position-linked stop in Bybit UI
2. **Durability**: Auto-cancelled when conditional TPs trigger and active reduce-only qty ≥ position qty

Using `set_trading_stop` solves both but requires an existing position (can't pre-place before entry).
