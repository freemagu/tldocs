# Risk, Reward, and R-Ratio in TradeLens

TradeLens treats **Risk** and **Reward** as two different questions, calculated in two different ways, and then combines them into **R-Ratio (RR)**.

This separation is intentional and essential to understanding trades correctly.

---

# 1. RISK

## "What is the worst that can still happen?"

### What Risk Means

Risk measures **downside exposure**.

It answers:

> "If price moves against me from here, what is the worst possible final outcome of this trade?"

Risk:

- Ignores exits on the profitable side of pWAEP
- Ignores intent
- Assumes the **worst-case price path**
- Accounts for defensive exits that reduce exposure on the way to the stop

---

## 1A. Initial Net Trade Risk (locked at cutoff)

This is the **primary risk metric** used for journaling and performance analysis.

It is calculated at the **Initial RR Cutoff** (default: 10 minutes after trade open).

### What It Includes

- Filled entries and their actual fill prices
- Unfilled DCAs that exist at cutoff (assumed to fill in the worst case)
- The stop price at cutoff
- Defensive exits between pWAEP and stop (layered risk)
- All realised P&L (profit or loss) from exits filled before cutoff

### Orders Excluded

- Orders cancelled or deactivated before the cutoff are excluded from all calculations
- The cancellation time is determined from `exchange_updated_at`

### Worst-Case Assumption

From the cutoff onward, TradeLens assumes:

1. Price fills all remaining DCAs (moving pWAEP)
2. Defensive exits fire as price passes through them (reducing qty)
3. Remaining qty hits the stop at full loss

### Layered Risk

Not all remaining quantity hits the stop at the full pWAEP-to-stop distance.

**Defensive exits** are exits positioned between pWAEP and the stop. In the worst case, as price moves from entry toward the stop, these exits fire along the way, each removing quantity at a smaller loss than the full stop distance.

For a **long trade**:
- Defensive exit = any exit where `stop < exit_price < pWAEP`
- These exits fire as price drops toward the stop
- Each removes some qty at loss = `|pWAEP - exit_price|` (less than full stop loss)

For a **short trade**:
- Defensive exit = any exit where `pWAEP < exit_price < stop`
- These exits fire as price rises toward the stop

Exits on the **profitable side** of pWAEP (e.g., TPs above entry for longs) do not fire in the worst case, so they have no effect on Risk.

### Numeric Example: Layered Risk

**Long BTC trade**

- pWAEP: 95,000 (1 BTC entry @ 100k + 1 BTC DCA @ 90k)
- Stop: 80,000
- Defensive exit: 0.5 BTC BE @ 92,000

Worst-case path:

| Step | What happens | Qty lost | Loss per unit | Loss |
|------|-------------|----------|---------------|------|
| 1 | BE fires at 92,000 | 0.5 BTC | 95,000 - 92,000 = 3,000 | 1,500 |
| 2 | Stop hits at 80,000 | 1.5 BTC | 95,000 - 80,000 = 15,000 | 22,500 |
| | **Forward loss** | | | **24,000** |

Without layered risk (naive calculation): 2 × 15,000 = 30,000.
With layered risk: 24,000 — the BE saved 6,000 of exposure.

### Realised P&L Offset

Any exits that filled **before** the cutoff have already happened. Their P&L permanently affects the outcome:

- Realised profit reduces risk
- Realised loss increases risk

**Initial Net Trade Risk** = max(0, forward_loss − realised_pnl)

### Simple Numeric Example

**Long BTC trade, no defensive exits**

- Entry: 1 BTC @ 100,000
- DCA: 1 BTC @ 90,000
- Stop: 80,000
- Cutoff reached

Worst case after cutoff:

- Both BTC filled (pWAEP = 95,000)
- Stop hit at 80,000
- Forward loss = (95,000 − 80,000) × 2 = **30,000**

If you had already realised +5,000 before cutoff:

- Initial Net Trade Risk = max(0, 30,000 − 5,000) = **25,000**

---

## 1B. Live Position Risk (planned — not yet implemented)

Live Position Risk is a planned **real-time exposure metric**.

It will answer:

> "How much can the remaining open position still lose if the stop is hit right now?"

### Planned Characteristics

- Uses **current remaining position size** (not projected)
- Uses **current WAEP** (not projected)
- Ignores realised P&L (forward-only)
- Used for execution safety, alerts, and exposure monitoring

### Numeric Example: Live Position Risk

- Remaining position: 1 BTC
- Average entry: 100,000
- Stop: 80,000

Live Position Risk = (100,000 − 80,000) × 1 = **20,000**

This value may be non-zero even when Initial Net Trade Risk is already zero.

---

# 2. REWARD

## "What profit can still realistically happen?"

### What Reward Means

Reward measures **reachable upside**, not plans or hopes.

It answers:

> "From the current market price, what profit exits can realistically be reached *without price first moving against me*?"

Reward is **conservative by design**.

---

## Market Price at Cutoff

To determine which exits are reachable, TradeLens looks up the **market price at the cutoff time** from candle data:

1. First tries the most recent **1-minute candle close** at or before cutoff
2. Falls back to **5-minute candle close** if 1m data is unavailable
3. If no candle data exists at all, all exits are included in Reward (conservative fallback)

---

## Reward Inclusion Rules

### Core Principle

> **If an exit cannot be reached from the current price without requiring an adverse move, it is excluded from Reward.**

There is no special-casing by leg type (TP, BE, trailing, etc.). The price-side and trigger-side rules are sufficient to correctly classify all exits.

---

## Long Trades: Reward Rules

For **long positions**, an exit contributes to Reward only if:

1. **Exit price ≥ current market price**

   - Exits below price are defensive and excluded

2. **If the exit is conditional** (COND-LIMIT or COND-MARKET):

   - Exclude if `trigger_price < current market price`
   - Include if `trigger_price ≥ current market price`

---

### Numeric Example: Valid Reward Exit (Long)

- Current price: 100,000
- TP: 110,000

Reward distance = 110,000 − 100,000 = **10,000**

This exit is included in Reward.

---

### Numeric Example: Excluded Conditional Exit (Long)

- Current price: 100,000
- Conditional TP: trigger 90,000, limit 110,000

This exit requires price to dip to 90,000 first (the DCA level).

**Result:** Excluded from Reward until triggered.

---

### Numeric Example: Excluded Defensive Exit (Long)

- Current price: 100,000
- BE exit: 95,000

Exit price (95,000) < market price (100,000). This is a defensive exit.

**Result:** Excluded from Reward. This exit contributes to Risk (layered risk) instead.

---

## Short Trades: Mirror Logic

For **short positions**, include an exit only if:

1. **Exit price ≤ current market price**
2. **If conditional**:
   - Exclude if `trigger_price > current market price`
   - Include if `trigger_price ≤ current market price`

---

## What Reward Effectively Excludes

The price-side and trigger-side rules naturally exclude:

- **Defensive exits** — exits below market (for longs) or above market (for shorts)
- **Break-even exits** — typically near entry price, which is below market for profitable longs
- **Conditional exits requiring adverse moves** — trigger below market for longs (e.g., DCA-linked TPs)
- **Already-filled exits** — handled separately via realised P&L before cutoff

These exits affect **Risk** (through layered risk), not Reward.

---

## How Reward Is Calculated

1. Filter exits using the inclusion rules above

2. Convert each valid exit into **R-units**:

```
Exit R = (exit_price − pWAEP) × direction / |pWAEP − stop|

where direction = +1 for long, −1 for short
```

3. Weight by quantity

4. Average across all valid exits

The result is the trade's **Initial RR (in R)**.

---

## Projected WAXP

**pWAXP (Projected Weighted Average Exit Price)** is the qty-weighted average price of all reward-eligible exits.

It is calculated from the same filtered exit set used for RR. Defensive and unreachable exits do not affect pWAXP.

---

# 3. R-RATIO (RR)

## "How much reward am I targeting relative to risk?"

### Definition

RR expresses:

> "How many units of reward (R) are achievable for each unit of risk."

Risk defines the size of **1R**.
Reward defines how many **R-units** are reachable.

---

### Numeric Example: RR

- pWAEP: 100,000
- Stop: 80,000 → 1R = 20,000
- Valid reward exit: 110,000

Reward R = (110,000 − 100,000) / 20,000 = **0.5R**

RR = **0.5**

---

# 4. DCA-Linked Conditional Orders (Diagram)

### Scenario

```
Price ↑

110k ───────────── TP (active only after DCA)

100k ── Entry (market)

 90k ── DCA limit ──┐
        Conditional TP triggers here

 80k ── Stop

Price ↓
```

### At Trade Open (price = 100k)

- Position size: 1 BTC
- Active TP: 1 BTC @ 110k
- DCA TP: **inactive** (trigger below price)

Reward counts **only the active TP**.

---

### After DCA Fills (price = 90k)

- Position size: 2 BTC
- Both TPs active

Reward now includes **both exits**.

---

# 5. Final Mental Model

- **Risk** asks: *What can still go wrong?* (uses all exits, layered worst-case)
- **Reward** asks: *What can still go right?* (uses only reachable exits)
- **RR** compares the two honestly

If an exit needs price to hurt you first, it does not belong in Reward.
If an exit can reduce loss in the worst case, it belongs in Risk.

---

# 6. pWAEP (Projected Weighted Average Entry Price)

### Definition

**pWAEP (Projected Weighted Average Entry Price)** is the *expected average entry price of the position in a worst-case scenario*, used as the reference price for both Risk and Reward calculations.

Unlike a simple average entry price, pWAEP can include **orders that have not filled yet**.

### Why pWAEP exists

TradeLens assumes a **worst-case path** when measuring risk:

- If DCAs exist below the current price (for longs), they may fill before the stop is hit
- Risk should reflect the position *you could end up with*, not just the position you have right now

pWAEP answers:

> "If all planned entries fill before the stop, what will my true average entry price be?"

### What pWAEP includes

At the time of calculation, pWAEP may include:

- All **filled entry orders** (market or limit) before cutoff
- All **unfilled DCA limit orders** that exist at cutoff (not cancelled before cutoff)

Each entry is weighted by its quantity.

### What pWAEP does NOT include

- Exit orders (TPs, stops, BE, trailing exits)
- Conditional exits that have not become entries
- Orders cancelled or deactivated before the cutoff
- Any realised P&L

pWAEP is a *price reference*, not a P&L measure.

### Numeric Example: pWAEP

**Long trade**

- Entry: 1 BTC @ 100,000 (filled)
- DCA: 1 BTC @ 90,000 (unfilled)

Projected position if DCA fills:

- Total size: 2 BTC
- pWAEP = (100,000 + 90,000) / 2 = **95,000**

This pWAEP is used for:

- Defining 1R (distance to stop)
- Measuring forward loss (layered risk)
- Measuring reward exits in R-units

### Why TradeLens uses pWAEP instead of current average

Using only the current average entry would **understate risk** whenever DCAs exist.

pWAEP ensures:

- Risk matches the worst-case exchange outcome
- RR remains consistent before and after DCAs fill
- Trades are evaluated conservatively and honestly
