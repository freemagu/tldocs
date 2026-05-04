# LevelGuard / LevelMind — Improvement Ideas

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

> [!warning] Triage status: **un-triaged brainstorm** (as of 2026-05-04)
> The ideas below have not been individually triaged into shipped / queued / dropped buckets. Treat this document as a working brainstorm, not as a backlog. When evaluating an idea here against current state:
> 1. Cross-check against [[40-research/breach-decision/INDEX#current-state-facts-not-aspirations|INDEX §Current state]] to see if it has already shipped or moved.
> 2. Cross-check against [[40-research/breach-decision/INDEX#deferred-decisions|INDEX §Deferred decisions]] to see if it has been considered and explicitly set aside.
> 3. Cross-check against [[40-research/breach-decision/INDEX#open-threads--questions-for-the-external-researcher|INDEX §Open threads]] for the questions an external researcher would prioritise.
>
> An eventual triage pass would assign each idea a status tag (`shipped` / `queued` / `deferred` / `dropped`) with a one-line reason. Until then, ideas here may overlap with already-shipped work or with deferred decisions — read with that caveat.

This document captures brainstorming and proposals for making LevelMind smarter at distinguishing genuine level breaks from wick rejections / stop hunts.

**Core principle**: Candle closes alone are too simplistic. Real market structure — volume, CVD, open interest, order flow — tells you *why* price moved through a level. LevelMind should understand the mechanics, not just the price.

---

## Current System Limitations (v1)

1. **Tick-only awareness**: Polls `last_price` every 500ms. No volume, no depth, no flow.
2. **Fixed 5-second reclaim window**: Doesn't adapt to volatility or price direction.
3. **Binary decision**: Execute or don't. No partial responses or graduated confidence.
4. **Blind to microstructure**: Can't distinguish a stop hunt (engineered liquidity grab) from genuine selling pressure.
5. **500ms polling gaps**: Flash wicks can happen and recover between polls.

---

## Data Sources Available from Bybit

### Already available (just not extracted)

| Data | Source | Notes |
|------|--------|-------|
| Open Interest | `get_ticker()` already returns `openInterest` field | Just not being extracted from the response |
| Funding Rate | `get_ticker()` already returns `fundingRate` field | Just not being extracted |

### New REST endpoints needed (all public, no auth, 10 req/s shared limit)

| Data | Endpoint | Granularity | Max |
|------|----------|-------------|-----|
| OI History | `GET /v5/market/open-interest` | 5m intervals | 200 records |
| Recent Trades | `GET /v5/market/recent-trade` | Individual trades with side | 1000 trades |
| Order Book | `GET /v5/market/orderbook` | Snapshot, 1-200 levels | 200 levels (linear) |
| Funding History | `GET /v5/market/funding/history` | Per funding interval | 200 records |

### WebSocket topics (real-time, no rate limit on receive)

| Topic | Data | Update Frequency |
|-------|------|-----------------|
| `tickers.{symbol}` | OI, funding rate, last price, 24h vol | ~100ms |
| `publicTrade.{symbol}` | Every individual trade (price, size, **side**) | Per trade |
| `orderbook.50.{symbol}` | Top 50 bid/ask levels | 100ms deltas |
| `liquidation.{symbol}` | Liquidation events (side, price, size) | Per event |

The `side` field on trades is critical: `"Buy"` = buyer aggressor (hitting ask), `"Sell"` = seller aggressor (hitting bid). This is the raw material for CVD.

---

## Proposal: Microstructure-Aware LevelMind (v2)

### Architecture: Real-Time Data Feeds

LevelMind currently fetches `last_price` via a single REST call per evaluation cycle. The proposal is to give each monitor thread access to a richer, continuously-updated market state.

```
                    WebSocket Connection (per symbol, shared)
                    ├── tickers.{symbol}     → OI, funding rate
                    ├── publicTrade.{symbol}  → trade-by-trade → CVD engine
                    ├── orderbook.50.{symbol} → depth snapshots
                    └── liquidation.{symbol}  → liquidation events
                              │
                              ▼
                    ┌─────────────────────┐
                    │  MarketStateBuffer   │
                    │  (per-symbol,        │
                    │   thread-safe)       │
                    │                     │
                    │  .last_price        │
                    │  .cvd_1s / 5s / 30s │
                    │  .oi_current        │
                    │  .oi_delta_1m / 5m  │
                    │  .bid_depth_near    │
                    │  .ask_depth_near    │
                    │  .liq_events_recent │
                    │  .trade_flow_ratio  │
                    │  .funding_rate      │
                    └────────┬────────────┘
                             │
                             ▼
                    ┌─────────────────────┐
                    │  LevelMindCore v2    │
                    │  evaluate(           │
                    │    state_data,       │
                    │    market_state  <── NEW: rich market context
                    │  )                   │
                    └─────────────────────┘
```

**Alternative (simpler, Phase 1)**: Instead of full WebSocket, use REST polling at 1-2 second intervals during breach windows only. When a breach is detected, LevelMind enters "high-alert mode" and starts polling additional endpoints (recent trades, orderbook) to gather microstructure context. This avoids the complexity of managing persistent WebSocket connections for every guarded symbol.

---

## Signal 1: CVD (Cumulative Volume Delta)

### What it tells us

CVD measures net buying vs selling aggression. During a level breach:

- **CVD dropping sharply** (negative delta): Aggressive sellers dominating → genuine breakdown, sellers are in control
- **CVD flattening or rising** during price drop: Selling is being absorbed by passive buyers → likely a stop hunt / liquidity grab. Price will recover.
- **CVD spike down then sharp reversal up**: Stops were triggered (selling), then immediately bought up → textbook stop hunt

### How to compute in real-time

```python
class CVDTracker:
    """Tracks cumulative volume delta from individual trades."""

    def __init__(self, window_seconds: int = 30):
        self.trades: deque = deque()  # (timestamp, signed_volume)
        self.window = window_seconds

    def add_trade(self, timestamp: float, size: Decimal, side: str):
        """side: 'Buy' (aggressor buy) or 'Sell' (aggressor sell)"""
        signed = size if side == 'Buy' else -size
        self.trades.append((timestamp, signed))
        self._prune()

    def get_cvd_delta(self, last_n_seconds: int = 5) -> Decimal:
        """Net buy-sell volume over the last N seconds."""
        cutoff = time.time() - last_n_seconds
        return sum(v for t, v in self.trades if t >= cutoff)

    def get_cvd_slope(self, window: int = 5) -> float:
        """Direction of CVD: positive = buying pressure increasing."""
        # Linear regression on cumulative CVD over window
        ...
```

### Application to MNTUSDT case

During the breach window (15:47:18 - 15:47:23 UTC), if CVD was flattening or turning positive while price was below the level, that would have been a strong signal that the selling was being absorbed — don't execute.

### Integration with LevelMind

```python
# In _handle_breached_fails():
if not is_reclaimed and window_expired:
    # Before executing, check CVD
    cvd_delta = market_state.get_cvd_delta(last_n_seconds=5)
    cvd_slope = market_state.get_cvd_slope(window=5)

    if cvd_slope > 0:  # Buying pressure increasing during breach
        # Extend patience — this looks like absorption
        # Don't execute yet, give more time
        ...
    elif cvd_delta < -threshold:  # Strong net selling
        # Genuine breakdown — execute
        ...
```

---

## Signal 2: Open Interest Delta

### What it tells us

OI changes tell you whether positions are being opened or closed:

| Price Movement | OI Change | Interpretation |
|---------------|-----------|----------------|
| Price drops below level | OI increases | New shorts being opened → genuine bearish conviction |
| Price drops below level | OI decreases | Longs being stopped out → stop hunt / liquidation flush |
| Price drops below level | OI flat | No new positioning → likely noise / wick |

**The key insight**: A stop hunt causes OI to DROP (stops closing long positions). A genuine breakdown causes OI to RISE (new shorts opening). This is one of the most reliable ways to distinguish the two.

### How to track

```python
class OITracker:
    """Tracks open interest changes from ticker updates."""

    def __init__(self):
        self.snapshots: deque = deque()  # (timestamp, oi_value)

    def update(self, timestamp: float, oi_value: Decimal):
        self.snapshots.append((timestamp, oi_value))
        # Keep last 5 minutes of data
        self._prune(max_age=300)

    def get_oi_delta(self, last_n_seconds: int = 30) -> Decimal:
        """OI change over the last N seconds."""
        cutoff = time.time() - last_n_seconds
        old = next((oi for t, oi in self.snapshots if t >= cutoff), None)
        new = self.snapshots[-1][1] if self.snapshots else None
        if old and new:
            return new - old
        return Decimal(0)

    def get_oi_delta_pct(self, last_n_seconds: int = 30) -> float:
        """OI change as percentage."""
        ...
```

### Practical consideration

The `tickers.{symbol}` WebSocket pushes OI at ~100ms intervals. But OI updates from Bybit can lag the actual position changes by several seconds. For the 5-second breach window, OI delta might not have updated yet. This makes OI more useful for **longer observation windows** (30s+) than for the initial 5-second decision.

**Suggestion**: Use OI as a confirming/denying signal during an extended observation period rather than during the initial breach window.

---

## Signal 3: Order Book Depth Imbalance

### What it tells us

The bid/ask depth near the reference level reveals market intent:

- **Strong bids stacking below the level**: Passive buyers ready to absorb selling → likely rejection. The level has support.
- **Thin bids below, thick asks above**: No buying support, selling pressure building → likely genuine break.
- **Bids getting pulled (depth decreasing rapidly)**: Market makers retreating → danger sign, could accelerate.

### Depth analysis for LevelMind

```python
class DepthAnalyzer:
    """Analyzes order book depth near a reference level."""

    def analyze_near_level(
        self,
        orderbook: dict,  # {bids: [[price, qty], ...], asks: [[price, qty], ...]}
        reference_level: Decimal,
        band_pct: float = 0.005  # 0.5% band around level
    ) -> dict:
        band = reference_level * Decimal(str(band_pct))
        lower = reference_level - band
        upper = reference_level + band

        bid_depth = sum(
            Decimal(qty) for price, qty in orderbook['bids']
            if Decimal(price) >= lower
        )
        ask_depth = sum(
            Decimal(qty) for price, qty in orderbook['asks']
            if Decimal(price) <= upper
        )

        total = bid_depth + ask_depth
        imbalance = float((bid_depth - ask_depth) / total) if total > 0 else 0

        return {
            'bid_depth_near': bid_depth,
            'ask_depth_near': ask_depth,
            'imbalance': imbalance,  # +1.0 = all bids, -1.0 = all asks
        }
```

**Imbalance > +0.3**: Buyers defending the level → higher chance of rejection
**Imbalance < -0.3**: Sellers dominating → higher chance of breakdown

### Caveats

- Spoofing: Large orders can be placed and pulled. Depth can be deceiving.
- Latency: REST snapshots are point-in-time. WebSocket deltas are better.
- Best used as one signal among many, not standalone.

---

## Signal 4: Liquidation Cascade Detection

### What it tells us

A cluster of liquidations near a level is the hallmark of a stop hunt:

1. Price approaches level → stop losses clustered just below
2. Price dips below → stops trigger → forced selling pushes price lower
3. Liquidation selling is temporary → once stops are flushed, buying resumes
4. Price recovers (the "hunt" is complete)

If LevelMind detects liquidation activity during a breach, it should increase the probability that this is a stop hunt rather than genuine selling.

### How to track

```python
class LiquidationTracker:
    """Tracks recent liquidation events from WebSocket."""

    def __init__(self):
        self.events: deque = deque()  # (timestamp, side, price, size)

    def add_event(self, timestamp: float, side: str, price: Decimal, size: Decimal):
        self.events.append((timestamp, side, price, size))
        self._prune(max_age=60)

    def get_recent_liq_volume(self, side: str, last_n_seconds: int = 10) -> Decimal:
        """Total liquidation volume for a side in the last N seconds."""
        cutoff = time.time() - last_n_seconds
        return sum(
            size for t, s, p, size in self.events
            if t >= cutoff and s == side
        )

    def is_liquidation_cascade(self, side: str, threshold: Decimal) -> bool:
        """Detect if a liquidation cascade is happening."""
        recent = self.get_recent_liq_volume(side, last_n_seconds=5)
        return recent > threshold
```

For a long position breach: if `liquidation_tracker.get_recent_liq_volume('Sell', 5)` is elevated, longs are being liquidated → this is a flush, not genuine conviction.

---

## Signal 5: Trade Flow Ratio (Aggressor Imbalance)

### What it tells us

Beyond CVD (which is cumulative), the instantaneous ratio of buy vs sell aggressor trades tells you who's in control RIGHT NOW.

```python
def trade_flow_ratio(trades_last_n_seconds: list) -> float:
    """
    Ratio of buy aggressor volume to total volume.
    > 0.6 = buyers dominating
    < 0.4 = sellers dominating
    0.4-0.6 = balanced
    """
    buy_vol = sum(t.size for t in trades if t.side == 'Buy')
    sell_vol = sum(t.size for t in trades if t.side == 'Sell')
    total = buy_vol + sell_vol
    if total == 0:
        return 0.5
    return float(buy_vol / total)
```

During a breach:
- `trade_flow_ratio < 0.3` → heavy selling, genuine break
- `trade_flow_ratio > 0.5` → buyers already stepping in, likely absorption/rejection
- `trade_flow_ratio` rising over the window → selling exhaustion, rejection building

---

## Signal 6: Price Momentum / Recovery Velocity

### What it tells us (no new data source needed)

Track the direction and speed of price movement during the breach window using the tick data LevelMind already collects.

```python
def recovery_score(price_readings: List[Tuple[float, Decimal]]) -> float:
    """
    Analyze price trajectory during breach.
    Returns -1.0 (accelerating away) to +1.0 (strong recovery).
    """
    if len(price_readings) < 3:
        return 0.0

    # Linear regression slope
    times = [t for t, p in price_readings]
    prices = [float(p) for t, p in price_readings]

    n = len(times)
    t_mean = sum(times) / n
    p_mean = sum(prices) / n

    numerator = sum((t - t_mean) * (p - p_mean) for t, p in zip(times, prices))
    denominator = sum((t - t_mean) ** 2 for t in times)

    if denominator == 0:
        return 0.0

    slope = numerator / denominator

    # Normalize: positive slope = recovering (for long exit below)
    # Scale by ATR to make comparable across symbols
    return slope
```

This is the simplest signal to add — no new data sources, just track what LevelMind already sees.

---

## Composite Decision Framework

Rather than any single signal gating the decision, combine signals into a weighted **breach confidence score**:

```python
class BreachConfidenceScorer:
    """
    Combines multiple microstructure signals into a single
    confidence score for whether a breach is genuine.

    Score range: 0.0 (certainly a wick/rejection) to 1.0 (certainly genuine)
    Execute threshold: configurable (e.g., 0.65)
    """

    def score(self, market_state: MarketStateBuffer, config: GuardConfig) -> float:
        signals = {}
        weights = {}

        # 1. CVD direction (highest weight — most direct measure of intent)
        cvd_slope = market_state.get_cvd_slope(window=5)
        signals['cvd'] = self._normalize_cvd(cvd_slope, config.exit_direction)
        weights['cvd'] = 0.30

        # 2. OI delta (strong confirming signal)
        oi_delta = market_state.get_oi_delta(last_n_seconds=30)
        signals['oi'] = self._normalize_oi(oi_delta, config.exit_direction)
        weights['oi'] = 0.20

        # 3. Price momentum / recovery (no extra data needed)
        recovery = market_state.get_recovery_score()
        signals['momentum'] = self._normalize_momentum(recovery, config.exit_direction)
        weights['momentum'] = 0.20

        # 4. Trade flow ratio (who's aggressing)
        flow = market_state.get_trade_flow_ratio(window=5)
        signals['flow'] = self._normalize_flow(flow, config.exit_direction)
        weights['flow'] = 0.15

        # 5. Depth imbalance (supporting signal)
        imbalance = market_state.get_depth_imbalance()
        signals['depth'] = self._normalize_depth(imbalance, config.exit_direction)
        weights['depth'] = 0.10

        # 6. Liquidation activity (confirming signal)
        liq = market_state.get_recent_liq_volume(config.exit_direction, 10)
        signals['liq'] = self._normalize_liq(liq)
        weights['liq'] = 0.05

        # Weighted average
        score = sum(signals[k] * weights[k] for k in signals)

        return score

    def _normalize_cvd(self, cvd_slope, exit_dir):
        """
        For long exit (below): negative CVD slope = genuine (→ 1.0)
        Positive CVD slope = absorption (→ 0.0)
        """
        if exit_dir == 'below':
            # Negative slope means selling pressure = genuine break
            return max(0, min(1, 0.5 - cvd_slope * scale_factor))
        else:
            return max(0, min(1, 0.5 + cvd_slope * scale_factor))
```

### Decision flow with composite scoring

```
BREACH DETECTED
    │
    ▼
Start collecting microstructure data
(CVD, OI, depth, trades, liquidations)
    │
    ▼ (collect for minimum_observation_sec, e.g. 3-5s)
    │
    ▼
Calculate breach_confidence_score
    │
    ├── score >= execute_threshold (e.g. 0.65) → EXECUTE
    │       High confidence this is genuine
    │
    ├── score <= reject_threshold (e.g. 0.35) → RECLAIM / extend patience
    │       High confidence this is a rejection
    │
    └── score between thresholds → INCONCLUSIVE
            │
            ├── Continue observing (extend window)
            ├── Re-score every N seconds
            └── Eventually: max_observation timeout → fall back to score
                (if still inconclusive after max time, use best available score)
```

### Configuration

```yaml
level_guard:
  # Composite scoring
  breach_score_min_observation_sec: 3   # Minimum time to collect data before scoring
  breach_score_execute_threshold: 0.65  # Score above this → execute
  breach_score_reject_threshold: 0.35   # Score below this → reclaim
  breach_score_max_observation_sec: 30  # Max time before forced decision
  breach_score_rescore_interval_sec: 2  # Re-evaluate score every N seconds

  # Individual signal weights (must sum to 1.0)
  signal_weight_cvd: 0.30
  signal_weight_oi: 0.20
  signal_weight_momentum: 0.20
  signal_weight_flow: 0.15
  signal_weight_depth: 0.10
  signal_weight_liq: 0.05

  # Displacement override still active (safety net)
  # If price moves > k * ATR from level, execute regardless of score
```

---

## Implementation Phases

### Phase 0: Groundwork (no behavior change)
- Add `get_recent_trades()` and `get_orderbook()` to `bybit_client.py`
- Extract OI and funding rate from existing `get_ticker()` responses
- Create `MarketStateBuffer` class (collects and aggregates data)
- Create `CVDTracker`, `OITracker` classes
- Add logging/recording of these signals during existing guard operations for backtesting

### Phase 1: Price Momentum (quick win, no new data sources)
- Track price readings during breach in a rolling buffer
- Calculate recovery score (slope of price during breach)
- If recovery score is strongly positive → extend observation window
- This alone would have helped the MNTUSDT case

### Phase 2: CVD Integration (highest-value new signal)
- Poll `GET /v5/market/recent-trade` during breach (every 1-2s)
- Compute CVD delta and slope from recent trades
- Integrate into breach decision: positive CVD slope during breach → extend patience

### Phase 3: Full Composite Scoring
- Add OI delta tracking, depth analysis, liquidation detection
- Implement `BreachConfidenceScorer` with configurable weights
- Replace fixed reclaim_window with score-based decision framework
- Consider WebSocket feeds for real-time data (vs REST polling during breach)

### Phase 4: WebSocket Architecture (longer term)
- Persistent WebSocket connections for actively guarded symbols
- Real-time `MarketStateBuffer` maintained continuously
- Sub-second reaction to market microstructure changes
- Possibly shared WebSocket manager across multiple guards on same symbol

---

## Backtesting Considerations

Before deploying any changes, we should:

1. **Record microstructure data during live guard operations** — even before using it for decisions, log what the signals WOULD have said
2. **Replay against historical guard cases** — both good executions (guard 29) and bad ones (guard 37) to verify the signals differentiate correctly
3. **Paper-trade mode** — run the new scoring alongside the old system, log disagreements, review manually

---

## Open Questions

1. **Rate limiting**: During a breach, LevelMind polls at 500ms. Adding `recent-trade` + `orderbook` polls doubles/triples the API calls. Is the 10 req/s public limit sufficient for concurrent guards on multiple symbols?

2. **WebSocket vs REST**: For Phase 2-3, is REST polling during breach sufficient? Or do we need persistent WebSocket connections for the data to be meaningful? (CVD slope over 5 seconds needs several data points — polling at 1-2s gives 3-5 points vs WebSocket giving hundreds of trades.)

3. **Which timeframe for OI?**: Bybit OI history has 5-minute minimum granularity. Real-time OI from tickers updates faster but is noisy. What smoothing makes sense?

4. **Signal weight tuning**: Initial weights are educated guesses. How do we tune them? Manual review of cases? Backtesting optimization?

5. **Latency**: From breach detection to data collection to scoring takes time. Is 3-5 seconds of data collection acceptable, or do we need faster decisions?

---

*Last updated: 2026-03-20*
*Arising from: Case 001 (MNTUSDT wick execution)*
