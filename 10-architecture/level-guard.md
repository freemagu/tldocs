# Level Guard — Complete Implementation Writeup

> See also: [[breach-decision-glossary]] (breach terminology), [[40-research/breach-decision/INDEX|breach-decision index]] (research corpus)

## 1. Overview & Purpose

**Level Guard** is a guard layer for conditional exit orders that prevents execution on liquidity sweeps and wick hunts. Instead of placing a conditional order on the exchange (where it can be triggered by a wick), Level Guard:

1. Creates a **synthetic, locally-monitored order** (exchange_order_id = `LG-{uuid}`)
2. Watches price action against a reference level
3. Only executes a **market order** when guard conditions are satisfied (price breach + sustained duration, or emergency ATR threshold)

Previously named "WickGuard" — renamed in migration 049.

---

## 2. State Machine

### States (`GuardState`)

| State | Description |
|-------|-------------|
| **ARMED** | Initial state, watching for breach |
| **BREACHED** | Price breached the reference level, reclaim window active |
| **COOLDOWN** | After reclaim, ignoring triggers temporarily (prevents thrashing) |
| **EXECUTED** | Market order sent, guard completed |
| **CANCELLED** | Guard was cancelled externally |

### Decision Reasons (`DecisionReason`)

| Reason | Description |
|--------|-------------|
| **TIMEOUT_EXECUTE** | Reclaim window expired without recovery — execute |
| **RECLAIMED** | Price recovered within window — enter cooldown |

> **Note:** Displacement (ATR override) no longer uses a DecisionReason enum value.
> It produces `classification=ACCEPT` with `response_json.evidence = "displacement"`.
> The daemon writes the evidence string verbatim to the audit table.

### Level Classification (`LevelClassification`)

Classification is the primary output signal from LevelMind. It is **mode-agnostic** — the classification describes *what happened*, while the `execute_when` mode determines the *action*.

| Classification | Meaning |
|---------------|---------|
| **REJECT** | Level held — price probed but bounced (touch detection), or price is far/safe |
| **ACCEPT** | Level failed — breach timeout expired, or displacement detected |
| **RECLAIM** | Price recovered — breached then returned to safe side within window |
| **INCONCLUSIVE** | Insufficient data — observation in progress, need more time |

#### Classification → Action Mapping

| Classification | `execute_when=fails` | `execute_when=holds` |
|---|---|---|
| **ACCEPT** | execute | update_state (re-arm) |
| **REJECT** (touch bounce) | update_state (clear obs) | execute |
| **REJECT** (idle, no touch) | none | none |
| **RECLAIM** | update_state (cooldown) | execute |
| **INCONCLUSIVE** | none (schedule next) | none (schedule next) |

### Breach & Reclaim Logic

**Long exits (below):**
- Breach: `price < (level - tick_buffer)`
- Reclaim: `price > (level + tick_buffer)`
- Adverse direction: downward

**Short exits (above):**
- Breach: `price > (level + tick_buffer)`
- Reclaim: `price < (level - tick_buffer)`
- Adverse direction: upward

### Displacement Detection

- Calculates ATR over configurable period (default: 14 candles on 1m timeframe)
- Two modes:
  - **"freeze"**: Captures ATR at breach time, uses frozen value
  - **"live"**: Recalculates ATR each cycle
- Triggers if: `price <= level - (k × ATR)` for longs, or `price >= level + (k × ATR)` for shorts
- Classification: `ACCEPT` (level failed due to volatility)
- No `DecisionReason` enum value — evidence stored in `response_json`:
  ```json
  {"evidence": "displacement", "volatility_multiple": 1.5, "confidence": 1.0}
  ```
- Daemon reads `response_json.evidence` and writes it verbatim as the audit `decision_reason`

---

## 3. Database Schema

### Modified Table: `order_leg_live`

```sql
guard_enabled        TINYINT NULL          -- 1 = guard active
guard_state_json     TEXT NULL             -- Serialized GuardStateData
```

### Audit Table: `level_guard_attempt`

```sql
id                  NUMERIC(18,0) IDENTITY PRIMARY KEY
order_leg_id        NUMERIC(18,0) NOT NULL
account_id          INT NOT NULL
symbol              VARCHAR(32) NOT NULL
exchange_order_id   VARCHAR(64) NOT NULL        -- "LG-xxxxx"
trade_side          VARCHAR(10) NOT NULL        -- "long" or "short"
reference_level     NUMERIC(38,10) NOT NULL
tick_size           NUMERIC(38,10) NOT NULL
breach_price        NUMERIC(38,10) NOT NULL
breach_time         DATETIME NOT NULL
reclaim_price       NUMERIC(38,10) NULL
reclaim_time        DATETIME NULL
execute_price       NUMERIC(38,10) NULL
execute_time        DATETIME NULL
decision_reason     VARCHAR(32) NOT NULL        -- 'reclaimed', 'timeout_execute', 'displacement'
atr_value           NUMERIC(38,10) NULL
atr_mode            VARCHAR(16) NULL            -- 'freeze' or 'live'
cooldown_until      DATETIME NULL
created_at          DATETIME NOT NULL
```

Indexes: `order_leg_id`, `(symbol, breach_time)`, `(decision_reason, created_at)`

Migrations: `046_wick_guard.sql` (initial), `049_rename_wick_guard_to_level_guard.sql` (rename)

---

## 4. Configuration (`etc/config.yml`)

```yaml
level_guard:
  atr_timeframe: "1m"          # Candle timeframe for ATR calculation
  atr_period: 14               # Number of candles
  atr_k: 1.0                   # Multiplier: execute if price > L ± (k × ATR)
  atr_mode: "freeze"           # "freeze" = capture at breach; "live" = recompute
  reclaim_window_sec: 5        # Seconds after breach to allow recovery
  cooldown_sec: 10             # Seconds to ignore new breaches after reclaim
  tick_buffer_ticks: 0         # Tick hysteresis to prevent flapping (breach/reclaim only)
  touch_buffer_ticks: 1        # Ticks for touch detection zone (0 = disabled)
  touch_confirm_count: 2       # Safe evaluations to confirm bounce → REJECT
  obs_max_wait_sec: 120        # Max seconds for touch observation before reset
  price_source: "last_trade"   # Price source (v1: last_trade only)
  eval_interval_ms: 500        # Daemon polling interval
  enabled: true                # Master switch
```

---

## 5. Architecture & Key Files

### Backend

| File | Purpose |
|------|---------|
| `lib/tradelens/services/level_guard.py` | Data model — enums, dataclasses, serialization |
| `lib/tradelens/services/level_mind_core.py` | Decision engine — all evaluation logic (touch, classification, scheduling) |
| `bin/server/level_guard_daemon.py` | Daemon — lifecycle orchestration, market order execution, scheduling |
| `bin/server/level_mind_worker.py` | Worker — polls requests, runs LevelMindCore, writes responses |
| `lib/tradelens/api/open_orders.py` | API integration — create/amend/cancel guarded orders |

### Frontend

| File | Purpose |
|------|---------|
| `frontend/web/src/components/shared/level-guard-toggle.tsx` | Reusable toggle component (cyan icon when enabled) |
| `frontend/web/src/components/journal/add-order-panel.tsx` | Toggle shown for conditional close orders |
| `frontend/web/src/components/journal/amend-order-panel.tsx` | Guard toggle on amend |
| `frontend/web/src/lib/api.ts` | Type definitions (`GuardConfig`, request/response types) |

### CLI & Service Management

| File | Purpose |
|------|---------|
| `bin/level-guard` | Bash wrapper (start/stop/status/run/restart/pause/resume) |
| `bin/tl` | Unified service manager (includes level-guard) |

### Tests

| File | Purpose |
|------|---------|
| `tests/unit/test_level_guard.py` | Data classes, serialization, config helpers, enum values |
| `tests/unit/test_level_mind_core.py` | Decision engine — touch detection, classification, scheduling, displacement |

---

## 6. Core Engine (`level_guard.py`)

### Key Data Structures

```python
@dataclass
class GuardConfig:
    reference_level: Decimal    # Price level being guarded
    reference_type: str         # "static" or "vwap"
    qty: Decimal
    tick_size: Decimal
    trade_side: str             # "long" or "short"
    exit_direction: str         # "below" or "above"
    vwap_slot: Optional[str]
    vwap_sigma: Optional[float]

@dataclass
class GuardStateData:
    state: GuardState           # Current FSM state
    config: GuardConfig
    breach_time: Optional[datetime]
    breach_price: Optional[Decimal]
    breach_atr: Optional[Decimal]
    cooldown_until: Optional[datetime]
    attempt_id: Optional[int]
    executed_at: Optional[datetime]
    execution_order_id: Optional[str]
    # Touch observation fields (Phase 2)
    obs_started_at: Optional[datetime]
    obs_last_checked_at: Optional[datetime]
    obs_max_wait_sec: float         # Default: 120.0
    obs_safe_count: int             # Default: 0
    next_mind_request_at: Optional[datetime]

@dataclass
class EvaluationResult:
    action: str                 # "none", "update_state", "execute"
    new_state: GuardStateData
    decision_reason: Optional[DecisionReason]
    classification: Optional[LevelClassification]
    confidence: Optional[Decimal]
    response_json: Optional[dict]
    next_check_ms: Optional[int]
    log_message: str
```

### Evaluation Method

```python
def evaluate(
    state_data: GuardStateData,
    last_price: Decimal,
    current_atr: Optional[Decimal] = None,
    now: Optional[datetime] = None
) -> EvaluationResult
```

Returns:
- `action="none"` — No change, continue monitoring
- `action="update_state"` — State transition (breach, reclaim, cooldown expiry)
- `action="execute"` — Execute market order immediately

---

## 7. Daemon (`level_guard_daemon.py`)

### Main Loop (every 500ms)

1. Query `order_leg_live WHERE guard_enabled = 1`
2. For each leg:
   - Fetch last traded price from Bybit ticker
   - Fetch ATR from Bybit candles (if needed)
   - Call `engine.evaluate(state, price, atr)`
3. Handle result:
   - `action="none"` → log, continue
   - `action="update_state"` → update `guard_state_json` in DB
   - `action="execute"` → place market order (reduce_only), cancel original exchange order, record audit entry, delete from `order_leg_live`

### Signal Handling

| Signal | Action |
|--------|--------|
| `SIGTERM/SIGINT` | Graceful shutdown |
| `SIGUSR1` | Pause (finish current cycle, then wait) |
| `SIGUSR2` | Resume |

### State Files

- `logs/level_guard_daemon.pid` — PID file
- `logs/level_guard_daemon.state` — JSON state (status, cycle count, executions, guarded legs)

---

## 8. API Integration (`open_orders.py`)

### Order Creation

When `guard_enabled=True` on a conditional close order:

1. Generate synthetic ID: `"LG-{16-char-hex}"`
2. Create `GuardConfig` from trigger_price (static or VWAP-linked)
3. Create initial `GuardStateData` in ARMED state
4. Serialize to `guard_state_json`
5. INSERT into `order_leg_live` with `status='guarded'`, `guard_enabled=1`
6. **No exchange order placed**

### Order Cancellation

Guarded orders exist only locally — cancel directly without exchange interaction.

### Order Amendment

Can amend price/qty while maintaining guard state. If trigger_price changes, reference_level updates and state resets to ARMED.

### Refresh Pipeline

`refresh_order_leg_live.py` excludes guarded orders: `AND (guard_enabled IS NULL OR guard_enabled = 0)`

---

## 9. Order Lifecycle

```
User creates conditional close with guard_enabled=True
    │
    ▼
API generates synthetic "LG-{uuid}" order
    │
    ▼
INSERT into order_leg_live (status='guarded', guard_enabled=1)
    │  ← NO exchange order placed
    ▼
Daemon picks up in next 500ms cycle
    │
    ├─ [ARMED] → price below level → BREACHED (start reclaim window)
    │     │
    │     ├─ [Path A] Price reclaims within window → COOLDOWN → re-ARMED
    │     │
    │     ├─ [Path B] Window expires, no reclaim → EXECUTE (timeout_execute)
    │     │
    │     └─ [Path C] Price crashes through volatility threshold → EXECUTE (displacement)
    │
    └─ On EXECUTE:
         1. Place market order on Bybit (reduce_only=True)
         2. Record audit entry in level_guard_attempt
         3. Delete from order_leg_live
```

---

## 10. State Persistence & Restart Safety

All state is serialized to `guard_state_json` in the database. On daemon restart:

1. Queries `order_leg_live WHERE guard_enabled = 1`
2. Parses `guard_state_json` for each leg
3. Resumes evaluation from current state

This ensures:
- No double execution (EXECUTED state prevents re-execution)
- No lost guards (state survives restarts)
- Cooldown periods maintained across restarts

---

## 11. CLI Usage

```bash
# Start/stop/manage
tl level-guard start [--debug]
tl level-guard stop
tl level-guard status
tl level-guard pause      # SIGUSR1
tl level-guard resume     # SIGUSR2

# Or directly:
./bin/level-guard start
./bin/level-guard run     # Foreground for debugging
```

---

## 12. Configuration Profiles

**Aggressive** (low tolerance for wicks):
```yaml
atr_k: 0.5, reclaim_window_sec: 2, cooldown_sec: 5, tick_buffer_ticks: 2
```

**Conservative** (allows more reclaims):
```yaml
atr_k: 2.0, reclaim_window_sec: 10, cooldown_sec: 30, tick_buffer_ticks: 0
```

---

## 13. Touch Detection (Phase 2)

Touch detection identifies price probing a level without breaching it — a "touch and bounce."

### Touch Band Geometry

The touch band extends on the **safe side** of the reference level:

- **Longs** (exit_direction=below): touch band = `price ≤ level + touch_buffer`
- **Shorts** (exit_direction=above): touch band = `price ≥ level - touch_buffer`

Where `touch_buffer = tick_size × touch_buffer_ticks`.

The touch band is **separate** from `tick_buffer_ticks` (which controls breach/reclaim hysteresis only). Setting `touch_buffer_ticks=0` disables touch detection entirely.

### Observation Session

When price enters the touch band:

1. **Start observation** — set `obs_started_at`, `obs_safe_count=0`
2. **Continue observation** — while in band, `obs_safe_count` resets to 0
3. **Safe reading** — price leaves band to safe side, `obs_safe_count` increments
4. **Confirm bounce** — when `obs_safe_count ≥ touch_confirm_count`, classify as REJECT
5. **Breach during obs** — if price breaches level during observation, obs fields clear and normal BREACHED flow takes over
6. **Timeout** — if observation runs longer than `obs_max_wait_sec`, obs fields clear and normal ARMED evaluation resumes

### Touch REJECT Action by Mode

| Mode | REJECT (touch bounce) | Description |
|------|----------------------|-------------|
| `execute_when=fails` | `update_state` (clear obs) | Level held, no action needed |
| `execute_when=holds` | `execute` | Level held = trigger for holds mode |

---

## 14. Daemon Scheduling (Phase 2)

### next_check_ms

Every LevelMind response includes `next_check_ms` — scheduling guidance telling the daemon when to submit the next request for this leg.

| Scenario | next_check_ms |
|----------|--------------|
| Idle REJECT (far from level) | 2000 |
| Active observation / breach window | 500 |
| Cooldown | min(remaining_cooldown_ms, 2000) |
| Terminal (execute) | None |

### next_mind_request_at

The daemon persists `next_mind_request_at` in `GuardStateData`. Before submitting a request for any leg, the daemon checks:

```python
if state_data.next_mind_request_at and now < state_data.next_mind_request_at:
    return  # Too early, skip this cycle
```

This prevents request churn — idle legs are checked every ~2 seconds instead of every 500ms.

### INCONCLUSIVE Handling

When LevelMind returns `classification=INCONCLUSIVE` with `action=none`:
- The daemon **persists** the new state (which contains updated obs fields)
- Sets `next_mind_request_at` based on `next_check_ms`
- Does NOT restore previous state

When LevelMind returns `classification=REJECT` with `action=none`:
- The daemon **restores** the previous state
- Sets `next_mind_request_at` based on `next_check_ms`

---

## 15. LevelMind Architecture (Phase 2)

### Separation of Concerns

| Component | Responsibility |
|-----------|---------------|
| **LevelGuard daemon** | Pure orchestrator — lifecycle, persistence, execution, scheduling |
| **LevelMind worker** | Request processor — polls DB, runs core, writes responses |
| **LevelMindCore** | Decision engine — ALL evaluation logic (breach, touch, displacement, classification) |

### Request/Response Flow

```
Daemon                     DB Tables                  Worker
  │                                                     │
  ├─ INSERT request ──→ level_mind_request              │
  │                     (status='pending')              │
  │                                                     │
  │                     level_mind_request ←── SELECT pending
  │                                                     │
  │                                      LevelMindCore.evaluate()
  │                                                     │
  │                     level_mind_response ←── INSERT response
  │                                                     │
  ├─ SELECT response ←─ level_mind_response             │
  │                                                     │
  ├─ Apply action (execute/update_state/none)           │
  └─ Set next_mind_request_at                           │
```

### Audit Trail

The daemon writes audit entries to `level_guard_attempt`. The `decision_reason` column receives:
- `'reclaimed'` — from `DecisionReason.RECLAIMED` (still an enum for reclaim/timeout)
- `'timeout_execute'` — from `DecisionReason.TIMEOUT_EXECUTE`
- `'displacement'` — from `response_json.evidence` (verbatim string, no enum)

The daemon does **not** import or use `DecisionReason` — all audit values are raw strings.

---

## 16. Key Design Decisions

1. **No exchange order placement** — Guards exist only locally, preventing exchange-side wick triggers
2. **Synthetic order IDs** — `LG-{uuid}` format distinguishes from real exchange orders
3. **Two-phase execution** — Daemon detects condition, then places market order + cleanup
4. **Tick buffer hysteresis** — Prevents flapping on orders right at the level
5. **Freeze-mode ATR** — Captures ATR at breach time, preventing "moving goalposts"
6. **Full audit trail** — Every breach/reclaim/execution recorded in `level_guard_attempt`
7. **VWAP integration** — Guards can protect VWAP-linked orders (dynamic reference levels)
8. **Mode-agnostic classification** — LevelClassification describes what happened; action differs by mode
9. **Separate touch buffer** — `touch_buffer_ticks` is independent of `tick_buffer_ticks`
10. **Daemon scheduling** — `next_check_ms` prevents request churn on idle legs
11. **Evidence-based audit** — Displacement uses `response_json.evidence` verbatim, not enum values

*Last reviewed: 2026-05-04 — back-link to breach-decision index added; content verified current.*
